import express from "express";
import mysql from "mysql2/promise";
import crypto from "crypto";
import sharp from "sharp";
import jwt from "jsonwebtoken";
// Helper ottimizzato per comprimere immagini con qualità adattiva
async function compressImage(base64, mimeType) {
  const imageBuffer = Buffer.from(base64, "base64");
  const originalSize = imageBuffer.length;

  let sharpInstance = sharp(imageBuffer);
  const metadata = await sharpInstance.metadata();

  // Ridimensiona se troppo grande (max 1920px larghezza)
  if (metadata.width > 1920) {
    sharpInstance = sharpInstance.resize(1920, null, {
      withoutEnlargement: true,
      fit: 'inside'
    });
  }

  // Qualità adattiva basata sulla dimensione originale
  let quality = 70;
  if (originalSize > 2 * 1024 * 1024) { // > 2MB
    quality = 60;
  } else if (originalSize < 500 * 1024) { // < 500KB
    quality = 80;
  }

  if (mimeType === "image/png") {
    // PNG: usa compressione migliore ma converti in JPEG se troppo grande
    if (originalSize > 1.5 * 1024 * 1024) {
      return await sharpInstance.jpeg({ quality: quality, mozjpeg: true }).toBuffer();
    }
    return await sharpInstance.png({ quality: 80, compressionLevel: 9, adaptiveFiltering: true }).toBuffer();
  } else {
    // JPEG: usa mozjpeg per compressione migliore
    return await sharpInstance.jpeg({ quality: quality, mozjpeg: true, progressive: true }).toBuffer();
  }
}

  const app = express();
  app.use(express.json({ limit: "10mb" }));

// Supabase JWT Secret (prendere dal dashboard Supabase -> Settings -> API -> JWT Secret)
const SUPABASE_JWT_SECRET = process.env.SUPABASE_JWT_SECRET || process.env.JWT_SECRET;

if (!SUPABASE_JWT_SECRET) {
  console.warn("⚠️  ATTENZIONE: SUPABASE_JWT_SECRET non configurato! Usa una variabile d'ambiente.");
}

const parseBoolEnv = (value, fallback = false) => {
  if (value == null) return fallback;
  const normalized = String(value).trim().toLowerCase();
  if (["1", "true", "yes", "on"].includes(normalized)) return true;
  if (["0", "false", "no", "off"].includes(normalized)) return false;
  return fallback;
};

const parseCsvSet = (value) => {
  if (!value) return new Set();
  return new Set(
    String(value)
      .split(",")
      .map((entry) => entry.trim())
      .filter(Boolean)
  );
};

const SECNEO_CONFIG = {
  enabled: parseBoolEnv(process.env.SECNEO_ENABLED, false),
  strict: parseBoolEnv(process.env.SECNEO_STRICT, false),
  verifyUrl: process.env.SECNEO_VERIFY_URL || "",
  verifyTimeoutMs: Number(process.env.SECNEO_VERIFY_TIMEOUT_MS || 3500),
  allowedAppKeys: parseCsvSet(process.env.SECNEO_ALLOWED_APP_KEYS),
  allowedTokens: parseCsvSet(process.env.SECNEO_ALLOWED_TOKENS),
  sharedSecret: process.env.SECNEO_SHARED_SECRET || ""
};

const verifySecNeoRemotely = async (payload) => {
  if (!SECNEO_CONFIG.verifyUrl) {
    return { valid: true, mode: "local-only" };
  }

  if (typeof fetch !== "function") {
    return { valid: false, reason: "fetch-non-disponibile" };
  }

  const controller = new AbortController();
  const timeoutHandle = setTimeout(() => controller.abort(), SECNEO_CONFIG.verifyTimeoutMs);
  try {
    const response = await fetch(SECNEO_CONFIG.verifyUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
      signal: controller.signal
    });

    if (!response.ok) {
      return { valid: false, reason: `verify-http-${response.status}` };
    }

    const json = await response.json().catch(() => null);
    const valid = json?.valid === true || json?.ok === true || json?.result === "pass";
    return valid ? { valid: true, mode: "remote-verified" } : { valid: false, reason: "verify-negative" };
  } catch (error) {
    return { valid: false, reason: error?.name === "AbortError" ? "verify-timeout" : "verify-exception" };
  } finally {
    clearTimeout(timeoutHandle);
  }
};

const authenticateSecNeo = async (req, res, next) => {
  if (!SECNEO_CONFIG.enabled) {
    return next();
  }

  if (req.path === "/v1" || req.path === "/v1/health") {
    return next();
  }

  const appKey = (req.headers["x-secneo-app-key"] || "").toString().trim();
  const token = (req.headers["x-secneo-token"] || "").toString().trim();
  const timestamp = (req.headers["x-secneo-timestamp"] || "").toString().trim();
  const nonce = (req.headers["x-secneo-nonce"] || "").toString().trim();
  const signature = (req.headers["x-secneo-signature"] || "").toString().trim();

  const enforceFailure = (message) => {
    if (SECNEO_CONFIG.strict) {
      return res.status(403).json({ error: "SecNeo verification failed", reason: message });
    }
    console.warn(`[SECNEO] Warning: ${message} ${req.method} ${req.originalUrl}`);
    return null;
  };

  if (!appKey) {
    const fail = enforceFailure("missing-app-key");
    if (fail) return fail;
    return next();
  }

  if (!token) {
    const fail = enforceFailure("missing-token");
    if (fail) return fail;
    return next();
  }

  if (SECNEO_CONFIG.allowedAppKeys.size > 0 && !SECNEO_CONFIG.allowedAppKeys.has(appKey)) {
    const fail = enforceFailure("invalid-app-key");
    if (fail) return fail;
    return next();
  }

  if (SECNEO_CONFIG.allowedTokens.size > 0 && !SECNEO_CONFIG.allowedTokens.has(token)) {
    const fail = enforceFailure("invalid-token");
    if (fail) return fail;
    return next();
  }

  if (SECNEO_CONFIG.sharedSecret) {
    if (!timestamp || !nonce || !signature) {
      const fail = enforceFailure("missing-signature-headers");
      if (fail) return fail;
      return next();
    }

    const requestTimestamp = Number(timestamp);
    if (!Number.isFinite(requestTimestamp)) {
      const fail = enforceFailure("invalid-timestamp");
      if (fail) return fail;
      return next();
    }

    const skewMs = Math.abs(Date.now() - requestTimestamp);
    if (skewMs > 5 * 60 * 1000) {
      const fail = enforceFailure("timestamp-skew");
      if (fail) return fail;
      return next();
    }

    const canonicalPaths = new Set([
      req.path,
      (req.originalUrl || "").split("?")[0]
    ]);
    const expectedSignatures = Array.from(canonicalPaths)
      .filter(Boolean)
      .map((path) =>
        crypto
          .createHmac("sha256", SECNEO_CONFIG.sharedSecret)
          .update(`${req.method}|${path}|${timestamp}|${nonce}`)
          .digest("hex")
      );
    const providedBuffer = Buffer.from(signature, "utf8");
    const isSignatureValid = expectedSignatures.some((expected) => {
      const expectedBuffer = Buffer.from(expected, "utf8");
      return expectedBuffer.length === providedBuffer.length &&
        crypto.timingSafeEqual(expectedBuffer, providedBuffer);
    });

    if (!isSignatureValid) {
      const fail = enforceFailure("invalid-signature");
      if (fail) return fail;
      return next();
    }
  }

  const remoteVerification = await verifySecNeoRemotely({
    appKey,
    token,
    timestamp,
    nonce,
    method: req.method,
    path: req.originalUrl,
    ip: req.ip,
    userAgent: req.headers["user-agent"] || null
  });

  if (!remoteVerification.valid) {
    const fail = enforceFailure(remoteVerification.reason || "remote-verification-failed");
    if (fail) return fail;
  }

  req.secneo = {
    valid: remoteVerification.valid,
    mode: remoteVerification.mode || "fallback",
    appKey
  };

  return next();
};

// Middleware per verificare JWT token di Supabase
const authenticateJWT = (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).json({ error: "Token mancante o formato non valido" });
  }

  const token = authHeader.substring(7); // Rimuove "Bearer "

  jwt.verify(token, SUPABASE_JWT_SECRET, (err, decoded) => {
    if (err) {
      console.error("[JWT ERROR]", err.message);
      return res.status(403).json({ error: "Token non valido o scaduto" });
    }

    // Supabase JWT contiene: sub (user id), email, role, ecc.
    req.user = {
      id: decoded.sub,
      email: decoded.email,
      role: decoded.role,
      ...decoded
    };
    next();
  });
};

const parseToDate = (value) => {
  if (!value) return null;

  // Caso: timestamp numerico (epoch in ms)
  if (/^\d+$/.test(value)) {
    const ts = parseInt(value, 10);
    return isNaN(ts) ? null : new Date(ts);
  }

  // Caso: formato completo ISO con ore e timezone
  if (/^\d{4}-\d{2}-\d{2}T/.test(value)) {
    const d = new Date(value);
    return isNaN(d.getTime()) ? null : d;
  }

  // Caso: formato solo YYYY-MM-DD
  if (/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    const [y, m, d] = value.split("-").map(Number);
    return new Date(y, m - 1, d); // forza in locale, no timezone shift
  }

  // Caso: solo YYYY-MM
  if (/^\d{4}-\d{2}$/.test(value)) {
    const [y, m] = value.split("-").map(Number);
    return new Date(y, m - 1, 1); // primo giorno del mese
  }

  // Fallback: lascia il parser nativo
  const ts = Date.parse(value);
  return isNaN(ts) ? null : new Date(ts);
};

  const bufferToBase64 = (buffer) => (buffer ? buffer.toString("base64") : null);

  const monthYearLabel = (value) => {
    const date = value instanceof Date ? value : parseToDate(value);
    if (!date) {
      return null;
    }
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const year = date.getFullYear();
    return `${month}/${year}`;
  };

    const extractEngineFromModelDetail = (description = "") => {
    if (!description || typeof description !== "string") {
      return null;
    }

    // Lista di parole chiave valide che identificano motori / alimentazioni
    const validEngineTokens = new Set([
      // Benzina
      "BZ", "BENZINA", "TSI", "TFSI", "MPI", "GDI", "VTEC", "FSI", "DOHC",
      "TURBO", "ETSI", "ECOTEC", "ECOBOOST", "PURETECH", "MULTIAIR", "T-JET", "DIG-T",
      "BOOSTERJET", "IG-T", "CVVT", "VVTI", "GSE", "BVA", "MIVEC", "SKYACTIV", "I-VTEC",
      "I4", "I3", "BOXER", "TCE", "PHEV", "MHEV", "HEV", "HYBRID", "MHYBRID",

      // Diesel
      "DIESEL", "TDI", "CDTI", "DCI", "JTD", "MULTIJET", "CRDI", "HDI", "BLUEHDI", "D4D",
      "SDI", "DID", "IDTEC", "TD4", "TDV6", "DTEC", "CDI", "BTDI", "DTH", "DTI",
      "BLUE", "BLUEDCI", "MJET", "DI-D", "D", "JTDM",

      // GPL / Metano / Alternative
      "GPL", "CNG", "METANO", "ECOFUEL", "BIFUEL", "LPG", "NGT", "G-TEC", "ECOGPL",
      "ECO", "ECOFLEX", "ECOPOWER", "TGI",

      // Elettrici / Ibridi plug-in
      "EV", "ELETTRICO", "BEV", "EPOWER", "E-TECH", "EQ", "EQS", "EQA", "EQB", "EQE",
      "EHYBRID", "PLUG-IN", "PLUG", "HYBRID4", "HYBRID2", "RECHARGE", "MOTORELETTRICO",

      // Serie specifiche
      "TS", "GDI", "GTI", "RS", "AMG", "M", "VTI", "TFSIE", "SKYACTIV-G", "SKYACTIV-D",
      "MULTIAIR2", "BLUECORE", "BOOSTHYBRID", "DCAT", "TURBODIESEL"
    ]);

    // Pattern 1: Formato BMW/Mercedes "30d", "220d", "xdrive30d" ecc.
    // Cattura: (opzionale testo)(numero)(lettera singola diesel/benzina)
    const bmwPattern = /(?:xdrive|sdrive)?(\d+)([di])\b/gi;
    let match = bmwPattern.exec(description);
    if (match) {
      const displacement = match[1];
      const fuelType = match[2].toLowerCase();
      // Converti: d->diesel, i->benzina
      const fuelLabel = fuelType === 'd' ? 'd' : 'i';
      return `${displacement}${fuelLabel}`;
    }

    // Pattern 2: Formato standard "1.6 JTDm", "2.0 TDI", "1.5 eTSI" ecc.
    // Cattura: (numero decimale) + (sigla motore con possibili trattini)
    const standardPattern = /(\d+(?:\.\d+)?)\s*(e?[a-zA-Z]+(?:-[a-zA-Z]+)?)/g;

    while ((match = standardPattern.exec(description)) !== null) {
      const cilindrata = match[1];
      const sigla = match[2];

      if (validEngineTokens.has(sigla.toUpperCase())) {
        return `${cilindrata} ${sigla}`;
      }
    }

    return null;
  };

  const normaliseTyreValue = value => (value == null ? "" : String(value).trim().toLowerCase());

  const hashStringToPositiveInt = (input) => {
    if (!input || typeof input !== "string") {
      return null;
    }
    let hash = 0;
    for (let i = 0; i < input.length; i += 1) {
      hash = (hash << 5) - hash + input.charCodeAt(i);
      hash |= 0; // Convert to 32bit integer
    }
    return Math.abs(hash);
  };

  const detectSetPositionFromName = (setName) => {
    if (!setName) return null;
    const lower = setName.toLowerCase();
    if (lower.includes("post")) return "rear";
    if (lower.includes("anter") || lower.includes("front") || lower.includes("avant")) return "front";
    if (lower.includes("rear") || lower.includes("dieter") || lower.includes("achter")) return "rear";
    return null;
  };

  const extractSetInfoFromLabel = (label) => {
    if (!label || typeof label !== "string") {
      return { setName: null, normalized: null, position: null };
    }
    const match = label.match(/\(([^)]+)\)/);
    if (match && match[1]) {
      const setName = match[1].trim();
      return {
        setName,
        normalized: setName.toLowerCase(),
        position: detectSetPositionFromName(setName)
      };
    }
    const lower = label.toLowerCase();
    if (lower.includes("anteriore")) {
      return { setName: "Anteriore", normalized: "anteriore", position: "front" };
    }
    if (lower.includes("posteriore")) {
      return { setName: "Posteriore", normalized: "posteriore", position: "rear" };
    }
    if (lower.includes("front")) {
      return { setName: "Front", normalized: "front", position: "front" };
    }
    if (lower.includes("rear")) {
      return { setName: "Rear", normalized: "rear", position: "rear" };
    }
    return { setName: null, normalized: null, position: null };
  };

  const computeSetIdentifier = (vehicleId, setName, fallbackKey = "") => {
    const normalizedSet = setName ? setName.trim().toLowerCase() : null;
    const baseKey = normalizedSet
      ? `${vehicleId}:${normalizedSet}`
      : fallbackKey
        ? `${vehicleId}:${fallbackKey}`
        : null;
    return baseKey ? hashStringToPositiveInt(baseKey) : null;
  };

  const normalizeSeasonLabel = (season) => {
    if (!season || typeof season !== "string") {
      return null;
    }
    const lower = season.toLowerCase();
    if (lower.includes("winter") || lower.includes("invern")) {
      return "Winter";
    }
    if (lower.includes("summer") || lower.includes("estiv")) {
      return "Summer";
    }
    if (lower.includes("all")) {
      return "All Season";
    }
    if (lower.includes("four") || lower.includes("4 stagioni")) {
      return "All Season";
    }
    return season.trim().length > 0
      ? season.trim().charAt(0).toUpperCase() + season.trim().slice(1)
      : null;
  };

  const parseSeasonDescriptor = (seasonRaw) => {
    if (seasonRaw == null) {
      return { baseSeason: null, setName: null, position: null };
    }
    const seasonString = typeof seasonRaw === "string" ? seasonRaw : String(seasonRaw);
    const parts = seasonString.split(" - ").map(part => part.trim()).filter(Boolean);

    if (parts.length >= 3) {
      const baseSeason = normalizeSeasonLabel(parts[0]);
      const setName = parts[1];
      const remainder = parts.slice(2).join(" - ");
      const inferredPosition =
        detectSetPositionFromName(remainder) ||
        detectSetPositionFromName(setName) ||
        detectSetPositionFromName(seasonString);
      return { baseSeason, setName, position: inferredPosition };
    }

    if (parts.length === 2) {
      const baseSeason = normalizeSeasonLabel(parts[0]);
      const setName = parts[1];
      const inferredPosition =
        detectSetPositionFromName(setName) ||
        detectSetPositionFromName(seasonString);
      return { baseSeason, setName, position: inferredPosition };
    }

    const baseSeason = normalizeSeasonLabel(parts[0]);
    return {
      baseSeason,
      setName: null,
      position: detectSetPositionFromName(seasonString)
    };
  };

  const buildRegisteredTyreFallbackKey = (row) => {
    const components = [
      normaliseTyreValue(row.size_label),
      normaliseTyreValue(row.brand),
      normaliseTyreValue(row.model),
      row.id ?? ""
    ];
    return `reg:${components.join("|")}`;
  };

  const formatRegisteredTyreRow = (row) => {
    const seasonInfo = parseSeasonDescriptor(row.season);
    const storedSetName = row.set_name || seasonInfo.setName;
    const storedSetPosition = row.set_position || seasonInfo.position;
    const fallbackKey = storedSetName
      ? null
      : buildRegisteredTyreFallbackKey(row);
    const setId = computeSetIdentifier(
      row.vehicle_id,
      storedSetName,
      fallbackKey
    );
    const inferredPosition =
      storedSetPosition ||
      detectSetPositionFromName(row.size_label) ||
      detectSetPositionFromName(storedSetName);

    const createdAt = row.created_at instanceof Date ? row.created_at.toISOString() : row.created_at;
    const updatedAt = row.updated_at instanceof Date ? row.updated_at.toISOString() : row.updated_at;

    return {
      id: row.id,
      vehicle_id: row.vehicle_id,
      brand: row.brand,
      model: row.model,
      size: row.size_label,
      dot: row.dot,
      loadIndex: row.load_index,
      speedRating: row.speed_rating,
      season: row.season,
      seasonBase: seasonInfo.baseSeason,
      setName: storedSetName,
      setPosition: inferredPosition,
      setId,
      createdAt,
      updatedAt
    };
  };

  const fetchRegisteredTyres = async (conn, vehicleId) => {
    const [rows] = await conn.execute(
      `SELECT id, vehicle_id, brand, model, size_label, dot, load_index, speed_rating, season, set_name, set_position, created_at, updated_at
      FROM tyres_vehicles
      WHERE vehicle_id = ?
      ORDER BY created_at DESC`,
      [vehicleId]
    );
    return rows.map(formatRegisteredTyreRow);
  };

  const toNumberOrNull = (value) => {
    if (value === null || value === undefined || value === "") {
      return null;
    }
    const numberValue = Number(value);
    return Number.isNaN(numberValue) ? null : numberValue;
  };

  const toISODate = (value) => (value instanceof Date ? value.toISOString() : value ?? null);

  const parseJsonArray = (value) => {
    if (!value) return null;
    if (Array.isArray(value)) return value;
    if (typeof value === "string") {
      try {
        const parsed = JSON.parse(value);
        return Array.isArray(parsed) ? parsed : null;
      } catch {
        return null;
      }
    }
    return null;
  };

  const formatTyreAnalysisRow = (row) => ({
    id: row.id,
    tyre_id: row.tyre_id,
    user_id: row.user_id,
    vehicle_id: row.vehicle_id,
    analysis_date: toISODate(row.analysis_date),
    analysis_type: row.analysis_type,
    depth_front_left: toNumberOrNull(row.depth_front_left),
    depth_front_right: toNumberOrNull(row.depth_front_right),
    depth_rear_left: toNumberOrNull(row.depth_rear_left),
    depth_rear_right: toNumberOrNull(row.depth_rear_right),
    depth_average: toNumberOrNull(row.depth_average),
    depth_minimum: toNumberOrNull(row.depth_minimum),
    remaining_life_percentage: toNumberOrNull(row.remaining_life_percentage),
    remaining_life_km: toNumberOrNull(row.remaining_life_km),
    remaining_life_months: toNumberOrNull(row.remaining_life_months),
    confidence_score: toNumberOrNull(row.confidence_score),
    condition_front_left: toNumberOrNull(row.condition_front_left),
    condition_front_right: toNumberOrNull(row.condition_front_right),
    condition_rear_left: toNumberOrNull(row.condition_rear_left),
    condition_rear_right: toNumberOrNull(row.condition_rear_right),
    wear_pattern: row.wear_pattern,
    wear_severity: row.wear_severity,
    notes: row.notes,
    technician_name: row.technician_name,
    location_latitude: toNumberOrNull(row.location_latitude),
    location_longitude: toNumberOrNull(row.location_longitude),
    location_address: row.location_address,
    image_urls: parseJsonArray(row.image_urls),
    created_at: toISODate(row.created_at),
    updated_at: toISODate(row.updated_at)
  });

  const formatTreadMeasurementRow = (row) => ({
    id: row.id,
    analysis_id: row.analysis_id,
    tyre_position: row.tyre_position,
    measurement_x: toNumberOrNull(row.measurement_x),
    measurement_y: toNumberOrNull(row.measurement_y),
    zone: row.zone,
    depth_mm: toNumberOrNull(row.depth_mm),
    confidence: toNumberOrNull(row.confidence),
    measurement_method: row.measurement_method,
    created_at: toISODate(row.created_at)
  });

  const formatLifecycleProjectionRow = (row) => ({
    id: row.id,
    analysis_id: row.analysis_id,
    kilometers_from_now: toNumberOrNull(row.kilometers_from_now),
    projected_depth: toNumberOrNull(row.projected_depth),
    confidence: toNumberOrNull(row.confidence),
    is_projected: row.is_projected === 1 || row.is_projected === true,
    created_at: toISODate(row.created_at)
  });

  const formatUserAnalysisStatsRow = (row) => ({
    user_id: row.user_id,
    total_analyses: toNumberOrNull(row.total_analyses),
    tyres_analyzed: toNumberOrNull(row.tyres_analyzed),
    avg_depth: toNumberOrNull(row.avg_depth),
    avg_remaining_life: toNumberOrNull(row.avg_remaining_life),
    last_analysis_date: toISODate(row.last_analysis_date)
  });

  const tyreKeyFromPayload = tyre => {
    const sizeLabel = tyre?.["size-label"] ?? tyre?.size_label ?? tyre?.sizeLabel;
    const { normalized: setKey } = extractSetInfoFromLabel(sizeLabel);
    return [
      normaliseTyreValue(tyre?.["data-width"] ?? tyre?.width),
      normaliseTyreValue(tyre?.["data-diameter"] ?? tyre?.diameter),
      normaliseTyreValue(tyre?.["data-ratio"] ?? tyre?.ratio),
      normaliseTyreValue(tyre?.["data-speedindex"] ?? tyre?.speed_index ?? tyre?.speedIndex),
      normaliseTyreValue(tyre?.["data-loadindex"] ?? tyre?.load_index ?? tyre?.loadIndex),
      normaliseTyreValue(sizeLabel),
      setKey || ""
    ].join("|");
  };

  const tyreKeyFromRow = row => {
    const { normalized: setKey } = extractSetInfoFromLabel(row.size_label);
    return [
      normaliseTyreValue(row.width),
      normaliseTyreValue(row.diameter),
      normaliseTyreValue(row.ratio),
      normaliseTyreValue(row.speed_index),
      normaliseTyreValue(row.load_index),
      normaliseTyreValue(row.size_label),
      setKey || ""
    ].join("|");
  };

  const buildInClause = (values) => {
    if (!Array.isArray(values) || values.length === 0) {
      return { clause: "(NULL)", params: [] };
    }
    const placeholders = values.map(() => "?").join(", ");
    return { clause: `(${placeholders})`, params: values };
  };

  // log utile per capire che path arriva davvero all'app
  app.use((req, _res, next) => {
    console.log("[REQ]", req.method, req.originalUrl);
    next();
  });

  // --- DB con configurazione ottimizzata ---
  const pool = mysql.createPool({
    host: process.env.DB_HOST || "localhost",
    user: process.env.DB_USER,
    password: process.env.DB_PASS,
    database: process.env.DB_NAME,
    connectionLimit: 20, // Aumentato per gestire più richieste concorrenti
    queueLimit: 0,
    waitForConnections: true,
    enableKeepAlive: true,
    keepAliveInitialDelay: 0,
    maxIdle: 10, // Mantieni max 10 connessioni idle
    idleTimeout: 60000, // Timeout idle connessioni: 60s
    multipleStatements: false, // Sicurezza
    namedPlaceholders: false
  });


  // ===== Router comune =====
  const router = express.Router();
  router.use("/v1", authenticateSecNeo);

  // GET v1
  router.get("/v1", (_req, res) => {
    res.json({ message: "API TyreVibes v1 attiva" });
  });

  // GET v1/health - Endpoint di diagnostica performance
  router.get("/v1/health", async (_req, res) => {
    try {
      const poolState = pool.pool;
      const health = {
        status: "healthy",
        timestamp: new Date().toISOString(),
        database: {
          connectionLimit: poolState._allConnections.length,
          freeConnections: poolState._freeConnections.length,
          activeConnections: poolState._allConnections.length - poolState._freeConnections.length,
          queuedRequests: poolState._connectionQueue.length
        },
        uptime: process.uptime(),
        memory: {
          used: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
          total: Math.round(process.memoryUsage().heapTotal / 1024 / 1024),
          external: Math.round(process.memoryUsage().external / 1024 / 1024)
        }
      };
      res.status(200).json(health);
    } catch (err) {
      res.status(500).json({ status: "unhealthy", error: err.message });
    }
  });

  // POST v1/manual_plate - Inserimento manuale targa con validazione
  router.post("/v1/manual_plate", authenticateJWT, async (req, res) => {
    const data = req.body;

    // Validazione campi obbligatori
    if (!data.userId) {
      return res.status(400).json({ message: "userId è obbligatorio" });
    }
    if (!data.plate || data.plate.trim().length === 0) {
      return res.status(400).json({ message: "plate_number è obbligatorio" });
    }

    // Normalizza targa (uppercase, rimuovi spazi)
    const plateNumber = data.plate.trim().toUpperCase();

    // Validazione formato targa italiana (opzionale ma consigliato)
    const italianPlateRegex = /^[A-Z]{2}[0-9]{3}[A-Z]{2}$/;
    if (!italianPlateRegex.test(plateNumber)) {
      return res.status(400).json({
        message: "Formato targa non valido. Usa formato italiano: AA000AA",
        plate_provided: plateNumber
      });
    }

    const registrationDate = parseToDate(data.registrationDate);
    const createdAt = new Date();

    let conn;
    try {
      conn = await pool.getConnection();
      await conn.beginTransaction();

      // Verifica se la targa esiste già
      const [existingPlate] = await conn.execute(
        `SELECT p.id, p.vehicle_id, v.make, v.model
         FROM plates p
         INNER JOIN vehicles v ON p.vehicle_id = v.id
         WHERE p.plate_number = ?
         LIMIT 1`,
        [plateNumber]
      );

      if (existingPlate.length > 0) {
        // Targa esistente: associa al garage dell'utente
        const vehicleId = existingPlate[0].vehicle_id;

        const [userVehicleCheck] = await conn.execute(
          `SELECT 1 FROM user_vehicles WHERE user_id = ? AND vehicle_id = ? LIMIT 1`,
          [data.userId, vehicleId]
        );

        if (userVehicleCheck.length > 0) {
          await conn.rollback();
          return res.status(409).json({
            message: "Targa già presente nel tuo garage",
            vehicle_id: vehicleId,
            plate: plateNumber
          });
        }

        await conn.execute(
          `INSERT INTO user_vehicles (user_id, vehicle_id) VALUES (?, ?)`,
          [data.userId, vehicleId]
        );

        await conn.commit();
        return res.status(200).json({
          message: "Targa aggiunta al garage",
          vehicle_id: vehicleId,
          plate: plateNumber,
          make: existingPlate[0].make,
          model: existingPlate[0].model,
          already_existed: true
        });
      }

      // Targa nuova: crea veicolo con dati minimi
      const [vehicleResult] = await conn.execute(
        `INSERT INTO vehicles
        (model_detail, make, model, fuel_type, displacement_cc,
         power_cv, power_kw, emission_class, gearbox, max_speed,
         body_type, doors, seats, consumption, traction,
         sale_start, sale_end, color, vin)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          data.modelDetails || "",
          data.make || "",
          data.model || "",
          data.fuelType || "",
          data.displacementCC || null,
          data.powerCV || null,
          data.powerKW || null,
          data.emissionClass || "",
          data.gearbox || "",
          data.maxSpeed || null,
          data.bodyType || "",
          data.doors || null,
          data.seats || null,
          data.consumption || null,
          data.traction || "",
          data.saleStart || null,
          data.saleEnd || null,
          data.color || "",
          data.vin || ""
        ]
      );
      const vehicleId = vehicleResult.insertId;

      // Crea la targa
      const [plateResult] = await conn.execute(
        `INSERT INTO plates (plate_number, vehicle_id, created_at, registration_date)
         VALUES (?, ?, ?, ?)`,
        [plateNumber, vehicleId, createdAt, registrationDate]
      );
      const plateId = plateResult.insertId;

      // Associa veicolo all'utente
      await conn.execute(
        `INSERT INTO user_vehicles (user_id, vehicle_id) VALUES (?, ?)`,
        [data.userId, vehicleId]
      );

      // Inserisci assicurazione se fornita
      if (data.insuranceCompany || data.insurancePolicyNumber || data.insuranceExpiry) {
        await conn.execute(
          `INSERT INTO plate_insurance
           (plate_id, rca_company, rca_policy_number, rca_expiry, rca_insurance_present)
           VALUES (?, ?, ?, ?, ?)`,
          [
            plateId,
            data.insuranceCompany || null,
            data.insurancePolicyNumber || null,
            data.insuranceExpiry || null,
            data.insurancePresent ? 1 : 0
          ]
        );
      }

      await conn.commit();

      res.status(201).json({
        message: "Targa inserita manualmente con successo",
        vehicle_id: vehicleId,
        plate_id: plateId,
        plate: plateNumber,
        created_new_vehicle: true
      });

    } catch (err) {
      if (conn) {
        try {
          await conn.rollback();
        } catch (rollbackErr) {
          console.error("Rollback fallita:", rollbackErr);
        }
      }
      console.error("Errore manual_plate:", err);
      res.status(500).json({ message: "Errore server", error: err.message });
    } finally {
      if (conn) {
        conn.release();
      }
    }
  });

  // POST v1/save_plate
  router.post("/v1/save_plate", authenticateJWT, async (req, res) => {
    const data = req.body;

    if (data.userId == null) {
      return res.status(400).json({ message: "Utente non esistente" });
    }

    const registrationDate = parseToDate(data.registrationDate);

    const createdAt = new Date();
    const imagesBase64 = Array.isArray(data.imagesBase64) ? data.imagesBase64 : [];
    const imagesMime = Array.isArray(data.imagesMime) ? data.imagesMime : [];
    const imagesAngle = Array.isArray(data.imagesAngle) ? data.imagesAngle : [];
    const imagesColor = Array.isArray(data.imagesColor) ? data.imagesColor : [];

    let conn;
    try {
      conn = await pool.getConnection();
      await conn.beginTransaction();

      const plateNumber = (data.plate || "").toUpperCase();
      const [existingPlateRows] = await conn.execute(
        `SELECT vehicle_id FROM plates WHERE plate_number = ? LIMIT 1`,
        [plateNumber]
      );

      if (existingPlateRows.length > 0) {
        const existingVehicleId = existingPlateRows[0].vehicle_id;

        const [existingImageColors] = await conn.execute(
          `SELECT DISTINCT LOWER(COALESCE(color, '')) AS color FROM vehicle_images WHERE vehicle_id = ?`,
          [existingVehicleId]
        );
        const existingColorSet = new Set(existingImageColors.map(row => row.color || ""));

        const collectedImages = [];

        let willInsertPrimary = false;

        if (imagesBase64.length > 0) {
          const imagePromises = imagesBase64.map(async (base64, i) => {
            if (!base64) return null;
            const rawColor = imagesColor[i] || "";
            const normalizedColor = rawColor.trim().toLowerCase();
            const colorKey = normalizedColor;
            if (existingColorSet.has(colorKey)) {
              return null;
            }
            const mimeType = imagesMime[i] || "image/jpeg";
            const compressedBuffer = await compressImage(base64, mimeType);
            const fileExt = mimeType === "image/png" ? "png" : "jpg";
            const fileName = `${(data.model || "vehicle").replace(/\s+/g, "_")}_${normalizedColor || "default"}.${fileExt}`;
            const fileSize = compressedBuffer.length;
            const angle = imagesAngle[i] || "";
            const isPrimary = normalizedColor !== "" && String(angle) === "23" ? 1 : 0;
            if (isPrimary === 1) {
              willInsertPrimary = true;
            }
            // Se l'immagine è primaria, il colore deve essere vuoto
            const finalColor = normalizedColor
            const sha256 = crypto
              .createHash("sha256")
              .update(Buffer.concat([compressedBuffer, Buffer.from(finalColor, "utf8")]))
              .digest("hex");
            existingColorSet.add(colorKey);
            return [
              existingVehicleId,
              compressedBuffer,
              mimeType,
              angle,
              finalColor,
              fileName,
              fileSize,
              sha256,
              0
            ];
          });

          const processed = await Promise.all(imagePromises);
          collectedImages.push(...processed.filter(Boolean));
        } else if (data.imageBase64) {
          const rawColor = data.color || "";
          const normalizedColor = rawColor.trim().toLowerCase();
          if (!existingColorSet.has(normalizedColor)) {
            const mimeType = data.imageMime || "image/jpeg";
            const compressedBuffer = await compressImage(data.imageBase64, mimeType);
            const fileExt = mimeType === "image/png" ? "png" : "jpg";
            const fileName = `${data.model || "vehicle"}.${fileExt}`;
            const fileSize = compressedBuffer.length;
            willInsertPrimary = true;
            // Se l'immagine è primaria, il colore deve essere vuoto
            const finalColor = normalizedColor
            const sha256 = crypto
              .createHash("sha256")
              .update(Buffer.concat([compressedBuffer, Buffer.from(rawColor || "", "utf8")]))
              .digest("hex");
            collectedImages.push([
              existingVehicleId,
              compressedBuffer,
              mimeType,
              "",
              finalColor,
              fileName,
              fileSize,
              sha256,
              0
            ]);
            existingColorSet.add(normalizedColor);
          }
        }

        if (collectedImages.length > 0) {
          const placeholders = collectedImages.map(() => "(?, ?, ?, ?, ?, ?, ?, ?, ?)").join(", ");
          const flatValues = collectedImages.flat();
          await conn.execute(
            `INSERT INTO vehicle_images (vehicle_id, image_data, mime_type, angle, color, file_name, file_size, sha256, is_primary)
             VALUES ${placeholders}`,
            flatValues
          );
        }

        await conn.execute(
          `INSERT INTO user_vehicles (user_id, vehicle_id, color) VALUES (?, ?, ?)
           ON DUPLICATE KEY UPDATE color = VALUES(color)`,
          [data.userId, existingVehicleId, data.color || ""]
        );

        await conn.commit();
        return res.status(200).json({
          message: "Targa già esistente, immagini aggiunte",
          vehicle_id: existingVehicleId
        });
      }

      // TARGA NUOVA - Crea veicolo, targa e immagini
      const [vehicleResult] = await conn.execute(
        `INSERT INTO vehicles
        (model_detail, make, model, fuel_type, displacement_cc,
          power_cv, power_kw,
          emission_class, gearbox, max_speed, body_type, doors, seats,
          consumption, traction, sale_start, sale_end, color, vin)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          data.modelDetails || "",
          data.make || "",
          data.model || "",
          data.fuelType || "",
          data.displacementCC || "",
          data.powerCV || "",
          data.powerKW || "",
          data.emissionClass || "",
          data.gearbox || "",
          data.maxSpeed || "",
          data.bodyType || "",
          data.doors || "",
          data.seats || "",
          data.consumption || "",
          data.traction || "",
          data.saleStart || "",
          data.saleEnd || "",
          data.color || "",
          data.vin || ""
        ]
      );
      const vehicleId = vehicleResult.insertId;

      const [plateResult] = await conn.execute(
        `INSERT INTO plates (plate_number, vehicle_id, created_at, registration_date) VALUES (?, ?, ?, ?)`,
        [plateNumber, vehicleId, createdAt, registrationDate]
      );
      const plateId = plateResult.insertId;

      // OTTIMIZZAZIONE: Batch insert per immagini con compressione parallela
    if (imagesBase64.length > 0) {
      // Controllo condizioni globali del batch
      const totalImages = imagesBase64.length;
      const colorList = imagesColor.map(c => (c || "").trim());
      const allColored = colorList.every(c => c !== "");
      const bothColored = totalImages === 2 && allColored; // Caso specifico richiesto
      const hasNeutralImage = colorList.some(c => c === "");

      const imagePromises = imagesBase64.map(async (base64, i) => {
        if (!base64) return null;

        const mimeType = imagesMime[i] || "image/jpeg";
        const compressedBuffer = await compressImage(base64, mimeType);
        const fileExt = mimeType === "image/png" ? "png" : "jpg";

        const modelName = (data.model || "vehicle").replace(/\s+/g, "_");
        const rawColor = Array.isArray(imagesColor) && imagesColor[i] ? imagesColor[i] : "";
        let colorName = rawColor.trim().toLowerCase().replace(/\s+/g, "_");
        if (colorName === "_") {
          colorName = "";
        }
        const angle = imagesAngle[i] || "";
        const fileName = `${modelName}_${colorName}_${angle || i}.${fileExt}`;
        const fileSize = compressedBuffer.length;

        const sha256 = crypto
          .createHash("sha256")
          .update(Buffer.concat([compressedBuffer, Buffer.from(colorName, "utf8")]))
          .digest("hex");

        // ---- LOGICA PRIMARIA MIGLIORATA ----
        let isPrimary = 0;

        if (bothColored) {
          // Entrambe colorate -> nessuna primaria
          isPrimary = 0;
        } else if (hasNeutralImage) {
          // Esiste almeno una senza colore -> quella sarà primaria
          isPrimary = colorList[i] === "" ? 1 : 0;
        } else {
          // Tutte senza colore -> la prima è primaria
          isPrimary = i === 0 ? 1 : 0;
        }

        return [
          vehicleId,
          compressedBuffer,
          mimeType,
          angle,
          colorName,
          fileName,
          fileSize,
          sha256,
          isPrimary
        ];
      });

      const imageData = (await Promise.all(imagePromises)).filter(Boolean);

      if (imageData.length > 0) {
        const placeholders = imageData.map(() => "(?, ?, ?, ?, ?, ?, ?, ?, ?)").join(", ");
        const flatValues = imageData.flat();

        await conn.execute(
          `INSERT INTO vehicle_images
           (vehicle_id, image_data, mime_type, angle, color, file_name, file_size, sha256, is_primary)
           VALUES ${placeholders}`,
          flatValues
        );
      }
    } else if (data.imageBase64) {
        const mimeType = data.imageMime || "image/jpeg";
        const compressedBuffer = await compressImage(data.imageBase64, mimeType);
        const fileExt = mimeType === "image/png" ? "png" : "jpg";
        const fileName = `${data.model || "vehicle"}.${fileExt}`;
        const fileSize = compressedBuffer.length;
        const sha256 = crypto.createHash("sha256").update(compressedBuffer).digest("hex");

        await conn.execute(
          `INSERT INTO vehicle_images (vehicle_id, image_data, mime_type, color, file_name, file_size, sha256, is_primary)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
          [vehicleId, compressedBuffer, mimeType, data.color || null, fileName, fileSize, sha256, (data.color || "") === "" ? 1 : 0]
        );
      }

      await conn.execute(
        `INSERT IGNORE INTO user_vehicles (user_id, vehicle_id, color) VALUES (?, ?, ?)`,
        [data.userId, vehicleId, data.color.trim().toLowerCase() || ""]
      );

      await conn.execute(
              `INSERT INTO plate_insurance (plate_id, rca_company, rca_policy_number, rca_expiry, rca_insurance_present)
              VALUES (?, ?, ?, ?, ?)
              ON DUPLICATE KEY UPDATE 
                rca_company = VALUES(rca_company),
                rca_policy_number = VALUES(rca_policy_number),
                rca_expiry = VALUES(rca_expiry),
                rca_insurance_present = VALUES(rca_insurance_present)`,
              [
                plateId,
                data.insuranceCompany || null,
                data.insurancePolicyNumber || null,
                data.insuranceExpiry || null,
                data.insurancePresent ? data.insurancePresent : 0
              ]
            );

            // OTTIMIZZAZIONE: Batch insert per pneumatici
            if (Array.isArray(data.tyres) && data.tyres.length > 0) {
              const [existingTyres] = await conn.execute(
                `SELECT width, diameter, ratio, speed_index, load_index, size_label
                FROM vehicle_tyres_supported
                WHERE vehicle_id = ?`,
                [vehicleId]
              );

              const existingKeys = new Set(existingTyres.map(tyreKeyFromRow));
              const tyresToInsert = [];

              for (const tyre of data.tyres) {
                if (!tyre || typeof tyre !== "object") {
                  continue;
                }

                const tyreKey = tyreKeyFromPayload(tyre);
                if (!tyreKey || existingKeys.has(tyreKey)) {
                  continue;
                }

                tyresToInsert.push([
                  vehicleId,
                  tyre["data-width"] || tyre.width || null,
                  tyre["data-diameter"] || tyre.diameter || null,
                  tyre["data-ratio"] || tyre.ratio || null,
                  tyre["data-speedindex"] || tyre.speed_index || tyre.speedIndex || null,
                  tyre["data-loadindex"] || tyre.load_index || tyre.loadIndex || null,
                  tyre["size-label"] || tyre.size_label || tyre.sizeLabel || null
                ]);

                existingKeys.add(tyreKey);
              }

              if (tyresToInsert.length > 0) {
                const placeholders = tyresToInsert.map(() => "(?, ?, ?, ?, ?, ?, ?)").join(", ");
                const flatValues = tyresToInsert.flat();
                await conn.execute(
                  `INSERT INTO vehicle_tyres_supported
                  (vehicle_id, width, diameter, ratio, speed_index, load_index, size_label)
                  VALUES ${placeholders}`,
                  flatValues
                );
              }
            }

            // OTTIMIZZAZIONE: Batch insert per revisioni
            if (Array.isArray(data.revisioni) && data.revisioni.length > 0) {
              const revisionsToInsert = data.revisioni.map(revision => [
                plateId,
                revision.kmRevisione || null,
                revision.dataRevisione || null,
                revision.esitoRevisione || null
              ]);

              if (revisionsToInsert.length > 0) {
                const placeholders = revisionsToInsert.map(() => "(?, ?, ?, ?)").join(", ");
                const flatValues = revisionsToInsert.flat();
                await conn.execute(
                  `INSERT INTO vehicle_revisions (plate_id, kmRevision, dateRevision, outcomeRevision)
                  VALUES ${placeholders}`,
                  flatValues
                );
              }
            }

      await conn.commit();
      res.status(201).json({ message: "Veicolo e targa salvati correttamente", vehicle_id: vehicleId });
    } catch (err) {
      if (conn) {
        try {
          await conn.rollback();
        } catch (rollbackErr) {
          console.error("Rollback fallita:", rollbackErr);
        }
      }
      console.error("Errore:", err);
      res.status(500).json({ message: "Errore server", error: err.message });
    } finally {
      if (conn) {
        conn.release();
      }
    }
  });




  // verifica targa
  const handleCheckPlate = async (plate, userId) => {
    if (!plate) {
      return { status: 400, body: { message: "Il numero di targa è richiesto." } };
    }

    const conn = await pool.getConnection();
    try {
      const [rows] = await conn.execute(
        `SELECT
            p.id AS plate_id,
            p.plate_number AS plate,
            p.registration_date,
            p.created_at,
            v.id AS vehicle_id,
            v.model_detail,
            v.make,
            v.model,
            v.fuel_type,
            v.displacement_cc AS displacement,
            v.power_kw,
            v.power_cv,
            v.emission_class,
            v.gearbox,
            v.max_speed,
            v.body_type,
            v.doors,
            v.seats,
            v.consumption,
            v.traction,
            v.sale_start,
            v.sale_end,
            v.color,
            v.vin,
            uv.user_id,
            vi.image_data,
            vi.mime_type,
            pi.rca_company,
            pi.rca_policy_number,
            pi.rca_expiry,
            pi.rca_insurance_present
        FROM plates p
        INNER JOIN vehicles v ON p.vehicle_id = v.id
        LEFT JOIN user_vehicles uv ON uv.vehicle_id = v.id
        LEFT JOIN vehicle_images vi ON vi.vehicle_id = v.id
        LEFT JOIN plate_insurance pi ON pi.plate_id = p.id
        WHERE p.plate_number = ? and vi.is_primary = 1 and vi.angle = '23'
        LIMIT 1`,
        [plate]
      );

      if (userId && rows.length > 0) {
        const [userVehicleRows] = await conn.execute(
          `SELECT 1 FROM user_vehicles WHERE user_id = ? AND vehicle_id = ? LIMIT 1`,
          [userId, rows[0].vehicle_id]
        );
        if (userVehicleRows.length > 0) {
        conn.release();
        return {
          status: 200,
          body: {
            message: "Targa già presente nel garage dell'utente.",
            already_in_garage: true,
              vehicle_id: rows[0].vehicle_id
          }
        };
      }
      }

      if (rows.length === 0) {
        conn.release();
        return { status: 404, body: { message: "Targa non trovata nel database." } };
      }

      const row = rows[0];
      const image_base64 = bufferToBase64(row.image_data);
      const registrationDate = parseToDate(row.registration_date);
      const formattedRegistrationDate = monthYearLabel(registrationDate) || row.registration_date;
      const registrationYear = registrationDate ? registrationDate.getFullYear() : null;

      const response = {
        plate_id: row.plate_id,
        plate: row.plate,
        make: row.make,
        model: row.model,
        model_detail: row.model_detail,
        fuel_type: row.fuel_type,
        displacement: row.displacement,
        power_kw: row.power_kw,
        power_cv: row.power_cv,
        emission_class: row.emission_class,
        gearbox: row.gearbox,
        max_speed: row.max_speed,
        body_type: row.body_type,
        doors: row.doors,
        seats: row.seats,
        consumption: row.consumption,
        traction: row.traction,
        sale_start: row.sale_start,
        sale_end: row.sale_end,
        color: row.color,
        vin: row.vin || null,
        user_id: row.user_id,
        created_at: row.created_at,
        registration_date: formattedRegistrationDate,
        vehicle_id: row.vehicle_id,
        year: registrationYear,
        insurance: {
          company: row.rca_company,
          policy_number: row.rca_policy_number,
          expiry: row.rca_expiry,
          insurance_present: row.rca_insurance_present
        },
        image_base64
      };

      conn.release();
      return { status: 200, body: response };
    } catch (err) {
      console.error("Errore check_plate:", err);
      conn.release();
      return { status: 500, body: { message: "Errore server", error: err.message } };
    }
  };

  router.post("/v1/check_plate", authenticateJWT, async (req, res) => {
    const { plate, userId } = req.body;
    const result = await handleCheckPlate((plate || "").toUpperCase(), userId);
    res.status(result.status).json(result.body);
  });

  router.get("/v1/check_plate", authenticateJWT, async (req, res) => {
    const plate = (req.query.plate || "").toUpperCase();
    const userId = req.query.userId ? Number(req.query.userId) : undefined;
    const result = await handleCheckPlate(plate, userId);
    res.status(result.status).json(result.body);
  });

  router.get("/v1/vehicles/:userId", authenticateJWT, async (req, res) => {
    const userId = req.params.userId;

    if (!userId) {
      return res.status(400).json({ message: "userId è richiesto." });
    }

    const conn = await pool.getConnection();
    try {
      const [vehicles] = await conn.execute(
        `SELECT v.*
        FROM vehicles v
        INNER JOIN user_vehicles uv ON uv.vehicle_id = v.id
        WHERE uv.user_id = ?`,
        [userId]
      );

      if (vehicles.length === 0) {
        return res.status(200).json([]);
      }

      const vehicleIds = vehicles.map(v => v.id);

      const plateIn = buildInClause(vehicleIds);
      const [plateRows] = await conn.execute(
        `SELECT id, vehicle_id, plate_number, registration_date, created_at
        FROM plates
        WHERE vehicle_id IN ${plateIn.clause}
        ORDER BY created_at DESC`,
        plateIn.params
      );

      const platesByVehicle = new Map();
      const plateIds = [];
      for (const row of plateRows) {
        if (!platesByVehicle.has(row.vehicle_id)) {
          const registrationDate = parseToDate(row.registration_date);
          platesByVehicle.set(row.vehicle_id, {
            id: row.id,
            plate_number: row.plate_number,
            registration_date: row.registration_date,
            created_at: row.created_at,
            year: registrationDate ? registrationDate.getFullYear() : null,
            month: registrationDate ? registrationDate.getMonth() : null
          });
          plateIds.push(row.id);
        }
      }

      const imageIn = buildInClause(vehicleIds);
      const [imageRows] = vehicleIds.length > 0 ? await conn.execute(
        `SELECT vi.id, vi.vehicle_id, vi.mime_type, vi.color, vi.file_name, vi.file_size, vi.image_data
        FROM vehicle_images vi
        INNER JOIN user_vehicles uv ON uv.vehicle_id = vi.vehicle_id
        WHERE vi.vehicle_id IN ${imageIn.clause} AND vi.is_primary = 0 AND vi.angle = '12' and LOWER(uv.color) = LOWER(vi.color)
        ORDER BY vi.id`,
        imageIn.params
      ) : [[], []];

      const imagesByVehicle = new Map();
      for (const row of imageRows) {
        if (!imagesByVehicle.has(row.vehicle_id)) {
          imagesByVehicle.set(row.vehicle_id, {
            id: row.id,
            mime_type: row.mime_type,
            color: row.color,
            file_name: row.file_name,
            file_size: row.file_size,
            image_base64: bufferToBase64(row.image_data)
          });
        }
      }

      const tyresIn = buildInClause(vehicleIds);
      const [tyreRows] = await conn.execute(
        `SELECT id, vehicle_id, width, diameter, ratio, speed_index, load_index, size_label
        FROM vehicle_tyres_supported
        WHERE vehicle_id IN ${tyresIn.clause}`,
        tyresIn.params
      );

      const tyresByVehicle = new Map();
      for (const row of tyreRows) {
        const setInfo = extractSetInfoFromLabel(row.size_label);
        const fallbackKey = `size:${normaliseTyreValue(row.size_label)}:${row.id ?? ""}`;
        const setId = computeSetIdentifier(row.vehicle_id, setInfo.setName, fallbackKey);
        const formattedRow = {
          id: row.id,
          vehicle_id: row.vehicle_id,
          width: row.width,
          diameter: row.diameter,
          ratio: row.ratio,
          speed_index: row.speed_index,
          load_index: row.load_index,
          size_label: row.size_label,
          set_id: setId,
          set_name: setInfo.setName,
          set_position: setInfo.position || detectSetPositionFromName(row.size_label)
        };
        if (!tyresByVehicle.has(row.vehicle_id)) {
          tyresByVehicle.set(row.vehicle_id, []);
        }
        tyresByVehicle.get(row.vehicle_id).push(formattedRow);
      }

      const revisionsByPlateId = new Map();
      if (plateIds.length > 0) {
        const revisionsIn = buildInClause(plateIds);
        const [revisionRows] = await conn.execute(
          `SELECT id, plate_id, kmRevision AS kmRevisione, dateRevision AS dataRevisione, outcomeRevision AS esitoRevisione
          FROM vehicle_revisions
          WHERE plate_id IN ${revisionsIn.clause}
          ORDER BY dateRevision DESC`,
          revisionsIn.params
        );

        for (const row of revisionRows) {
          if (!revisionsByPlateId.has(row.plate_id)) {
            revisionsByPlateId.set(row.plate_id, []);
          }
          revisionsByPlateId.get(row.plate_id).push(row);
        }
      }

      const insurancesByPlateId = new Map();
      if (plateIds.length > 0) {
        const insuranceIn = buildInClause(plateIds);
        const [insuranceRows] = await conn.execute(
          `SELECT id, plate_id, rca_company, rca_policy_number, rca_expiry, rca_insurance_present
          FROM plate_insurance
          WHERE plate_id IN ${insuranceIn.clause}`,
          insuranceIn.params
        );

        for (const row of insuranceRows) {
          if (!insurancesByPlateId.has(row.plate_id)) {
            insurancesByPlateId.set(row.plate_id, []);
          }
          insurancesByPlateId.get(row.plate_id).push(row);
        }
      }

      const vehiclesWithDetails = vehicles.map(vehicle => {
        const engine = extractEngineFromModelDetail(vehicle.model_detail);
        const plate = platesByVehicle.get(vehicle.id) || null;
        const plateId = plate ? plate.id : null;

        return {
          vehicle: { ...vehicle, engine },
          plate,
          image: imagesByVehicle.get(vehicle.id) || null,
          tyres: tyresByVehicle.get(vehicle.id) || [],
          revisions: plateId ? revisionsByPlateId.get(plateId) || [] : [],
          insurances: plateId ? insurancesByPlateId.get(plateId) || [] : []
        };
      });

      res.status(200).json(vehiclesWithDetails);
    } catch (err) {
      console.error("Errore GET /v1/vehicles/:userId:", err);
      res.status(500).json({ message: "Errore server", error: err.message });
    } finally {
      conn.release();
    }
  });

  router.delete("/v1/vehicles/:id/user/:userId", authenticateJWT, async (req, res) => {
    const { id, userId } = req.params;

    if (!id || !userId) {
      return res.status(400).json({ message: "vehicleId e userId sono richiesti." });
    }

    const conn = await pool.getConnection();
    try {
      const [result] = await conn.execute(
        "DELETE FROM user_vehicles WHERE vehicle_id = ? AND user_id = ?",
        [id, userId]
      );

      if (result.affectedRows === 0) {
        return res.status(404).json({ message: "Associazione non trovata." });
      }

      res.status(200).json({ message: "Associazione veicolo-utente rimossa con successo" });
    } catch (err) {
      console.error("Errore DELETE /v1/vehicles/:id/user/:userId:", err);
      res.status(500).json({ message: "Errore server", error: err.message });
    } finally {
      conn.release();
    }
  });

router.patch("/v1/vehicles/:id/user/:userId/mileage", authenticateJWT, async (req, res) => {
  const { id, userId } = req.params;
  const { currentMileage } = req.body || {};

  if (!id || !userId) {
    return res.status(400).json({ message: "vehicleId e userId sono richiesti." });
  }

  if (currentMileage !== null && currentMileage !== undefined) {
    const parsedMileage = Number(currentMileage);
    if (!Number.isInteger(parsedMileage) || parsedMileage < 0) {
      return res.status(400).json({ message: "currentMileage deve essere un intero maggiore o uguale a 0." });
    }
  }

  const conn = await pool.getConnection();
  try {
    const [associationRows] = await conn.execute(
      `SELECT 1 FROM user_vehicles WHERE vehicle_id = ? AND user_id = ? LIMIT 1`,
      [id, userId]
    );

    if (associationRows.length === 0) {
      return res.status(404).json({ message: "Associazione veicolo-utente non trovata." });
    }

    const normalizedMileage = currentMileage === undefined ? null : currentMileage;

    const [result] = await conn.execute(
      `UPDATE vehicles
       SET current_mileage = ?
       WHERE id = ?`,
      [normalizedMileage, id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Veicolo non trovato." });
    }

    res.status(200).json({
      message: "Chilometraggio veicolo aggiornato con successo",
      currentMileage: normalizedMileage
    });
  } catch (err) {
    console.error("Errore PATCH /v1/vehicles/:id/user/:userId/mileage:", err);
    res.status(500).json({ message: "Errore server", error: err.message });
  } finally {
    conn.release();
  }
});

router.post("/v1/vehicles/:id/user/:userId", authenticateJWT, async (req, res) => {
  const { id, userId } = req.params;
  // Extract color and potential image data from the body
  const { color, imagesBase64, imagesMime, imagesAngle } = req.body || {};

  console.log(`[DEBUG] POST /v1/vehicles/${id}/user/${userId}`);
  console.log(`[DEBUG] color extracted:`, color);

  if (!id || !userId) {
    return res.status(400).json({ message: "vehicleId e userId sono richiesti." });
  }
  
  if (!color) {
      return res.status(400).json({ message: "Il colore è richiesto." });
  }

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction(); // Use a transaction for this multi-step operation

    const normalizedColor = color.trim().toLowerCase();
    console.log(`[DEBUG] normalizedColor to check and save:`, normalizedColor);

    // 1. Check if an image for this color already exists
    const [existingImages] = await conn.execute(
      `SELECT image_data, mime_type FROM vehicle_images WHERE vehicle_id = ? AND LOWER(color) = ? LIMIT 1`,
      [id, normalizedColor]
    );

    let image_base64;

    if (existingImages.length === 0) {
      // Image for this color does not exist, so we must create it.
      console.log(`[DEBUG] No image found for color '${normalizedColor}'. Attempting to create new image.`);
      
      const imagesToProcess = Array.isArray(imagesBase64) ? imagesBase64 : [];
      if (imagesToProcess.length === 0) {
        await conn.rollback();
        return res.status(400).json({ message: `Il colore '${color}' è nuovo per questo veicolo, ma non è stata fornita un'immagine.` });
      }

      // Process ALL images provided for the new color (parallelize compression)
      const imagePromises = imagesToProcess.map(async (base64, i) => {
        if (!base64) return null;
        const mimeType = (Array.isArray(imagesMime) && imagesMime[i]) ? imagesMime[i] : 'image/jpeg';
        const angle = (Array.isArray(imagesAngle) && imagesAngle[i]) ? String(imagesAngle[i]) : '';

        const compressedBuffer = await compressImage(base64, mimeType);
        const fileExt = mimeType === "image/png" ? "png" : "jpg";
        const fileName = `vehicle_${id}_${normalizedColor}_${angle || i}.${fileExt}`;
        const fileSize = compressedBuffer.length;
        const sha256 = crypto.createHash("sha256").update(compressedBuffer).digest("hex");

        // The first image (index 0) is the primary one
        const is_primary = i === 0 ? 1 : 0;

        return [id, compressedBuffer, mimeType, angle, color, fileName, fileSize, sha256, is_primary];
      });

      const imageData = (await Promise.all(imagePromises)).filter(Boolean);

      if (imageData.length > 0) {
        const placeholders = imageData.map(() => "(?, ?, ?, ?, ?, ?, ?, ?, ?)").join(", ");
        const flatValues = imageData.flat();
        await conn.execute(
          `INSERT INTO vehicle_images (vehicle_id, image_data, mime_type, angle, color, file_name, file_size, sha256, is_primary)
           VALUES ${placeholders}`,
          flatValues
        );

        console.log(`[DEBUG] ${imageData.length} new image(s) for color '${color}' inserted for vehicle ${id}.`);
        // Return the first image as base64 for display
        image_base64 = imageData[0][1].toString('base64');
      }

    } else {
      // Image for this color already exists.
      console.log(`[DEBUG] Image found for color '${normalizedColor}'.`);
      image_base64 = existingImages[0].image_data.toString('base64');
    }

    // 2. Update or insert the user's color choice in user_vehicles
    await conn.execute(
      "INSERT INTO user_vehicles (user_id, vehicle_id, color) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE color = VALUES(color)",
      [userId, id, normalizedColor]
    );
    console.log(`[DEBUG] user_vehicles updated for user ${userId}, vehicle ${id} with color '${normalizedColor}'`);

    await conn.commit(); // Commit the transaction

    res.status(200).json({ message: "Colore del veicolo aggiornato con successo", image_base64 });

  } catch (err) {
    if (conn) await conn.rollback(); // Rollback on error
    console.error("Errore POST /v1/vehicles/:id/user/:userId:", err);
    res.status(500).json({ message: "Errore server", error: err.message });
  } finally {
    if (conn) conn.release();
  }
});

// POST v1/tyres_vehicles
router.post("/v1/tyres_vehicles", authenticateJWT, async (req, res) => {
  const {
    vehicle_id,
    brand,
    model,
    size,
    size_label,
    dot,
    loadIndex,
    speedRating,
    season,
    set_name,
    setName,
    set_position,
    setPosition
  } = req.body;
  const resolvedSetName = set_name ?? setName ?? null;
  const resolvedSetPosition = set_position ?? setPosition ?? (resolvedSetName ? detectSetPositionFromName(resolvedSetName) : null);
  const resolvedSizeLabel = size_label ?? size;

  // Validazione: vehicle_id e model obbligatori
  if (
    vehicle_id == null ||
    vehicle_id === "" ||
    model == null ||
    model === ""
  ) {
    return res.status(400).json({ message: "vehicle_id e model sono obbligatori." });
  }

  let conn;
  try {
    conn = await pool.getConnection();
    await conn.beginTransaction();
    const [result] = await conn.execute(
      `INSERT INTO tyres_vehicles (vehicle_id, brand, model, size_label, dot, load_index, speed_rating, season, set_name, set_position, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())`,
      [
        vehicle_id,
        brand || null,
        model,
        resolvedSizeLabel || null,
        dot || null,
        loadIndex || null,
        speedRating || null,
        season || null,
        resolvedSetName,
        resolvedSetPosition
      ]
    );
    await conn.commit();
    res.status(201).json({ message: "Pneumatico salvato correttamente", tyre_id: result.insertId });
  } catch (err) {
    if (conn) {
      try {
        await conn.rollback();
      } catch (rollbackErr) {
        console.error("Rollback fallita su /v1/tyres_vehicles:", rollbackErr);
      }
    }
    console.error("Errore POST /v1/tyres_vehicles:", err);
    res.status(500).json({ message: "Errore server", error: err.message });
  } finally {
    if (conn) {
      conn.release();
    }
  }
});

// GET v1/tyres_vehicles/vehicle/:vehicleId
router.get("/v1/tyres_vehicles/vehicle/:vehicleId", authenticateJWT, async (req, res) => {
  const { vehicleId } = req.params;

  if (!vehicleId) {
    return res.status(400).json({ message: "vehicleId è richiesto." });
  }

  const conn = await pool.getConnection();
  try {
    const tyresFormatted = await fetchRegisteredTyres(conn, vehicleId);
    res.status(200).json(tyresFormatted);
  } catch (err) {
    console.error("Errore GET /v1/tyres_vehicles/vehicle/:vehicleId:", err);
    res.status(500).json({ message: "Errore server", error: err.message });
  } finally {
    conn.release();
  }
});

// GET v1/tyres_vehicles/vehicle/:vehicleId/sets
router.get("/v1/tyres_vehicles/vehicle/:vehicleId/sets", authenticateJWT, async (req, res) => {
  const { vehicleId } = req.params;

  if (!vehicleId) {
    return res.status(400).json({ message: "vehicleId è richiesto." });
  }

  const conn = await pool.getConnection();
  try {
    const tyres = await fetchRegisteredTyres(conn, vehicleId);
    const groups = new Map();

    for (const tyre of tyres) {
      const key = tyre.setName
        ? `named:${tyre.setName.toLowerCase()}`
        : `single:${tyre.setId ?? tyre.id}`;

      if (!groups.has(key)) {
        groups.set(key, {
          setId: tyre.setId ?? hashStringToPositiveInt(`${vehicleId}:${key}`),
          setName: tyre.setName ?? null,
          setPosition: tyre.setPosition ?? null,
          seasonBase: tyre.seasonBase ?? normalizeSeasonLabel(tyre.season),
          tyres: []
        });
      }

      groups.get(key).tyres.push(tyre);
    }

    const sets = Array.from(groups.values()).map(group => {
      const seasons = Array.from(
        new Set(
          group.tyres
            .map(t => t.seasonBase || normalizeSeasonLabel(t.season))
            .filter(Boolean)
        )
      );

      const createdAt = group.tyres
        .map(t => (t.createdAt ? new Date(t.createdAt) : null))
        .filter(Boolean)
        .sort((a, b) => a - b)[0];

      const updatedAt = group.tyres
        .map(t => (t.updatedAt ? new Date(t.updatedAt) : null))
        .filter(Boolean)
        .sort((a, b) => b - a)[0];

      return {
        setId: group.setId,
        setName: group.setName,
        setPosition: group.setPosition,
        seasonBase: group.seasonBase || seasons[0] || null,
        seasons,
        tyreCount: group.tyres.length,
        tyres: group.tyres,
        createdAt: createdAt ? createdAt.toISOString() : null,
        updatedAt: updatedAt ? updatedAt.toISOString() : null
      };
    });

    res.status(200).json(sets);
  } catch (err) {
    console.error("Errore GET /v1/tyres_vehicles/vehicle/:vehicleId/sets:", err);
    res.status(500).json({ message: "Errore server", error: err.message });
  } finally {
    conn.release();
  }
});

// DELETE v1/tyres_vehicles/vehicle/:vehicleId/set
router.delete("/v1/tyres_vehicles/vehicle/:vehicleId/set", authenticateJWT, async (req, res) => {
  const { vehicleId } = req.params;
  const { setName, setId } = req.body || {};

  if (!vehicleId) {
    return res.status(400).json({ message: "vehicleId è richiesto." });
  }

  const normalizedSetName =
    typeof setName === "string" && setName.trim().length > 0
      ? setName.trim().toLowerCase()
      : null;
  const numericSetId =
    setId !== undefined && setId !== null && !Number.isNaN(Number(setId))
      ? Number(setId)
      : null;

  if (!normalizedSetName && numericSetId === null) {
    return res.status(400).json({ message: "setName o setId sono richiesti." });
  }

  const conn = await pool.getConnection();
  try {
    const tyres = await fetchRegisteredTyres(conn, vehicleId);
    const idsToDelete = tyres
      .filter(tyre => {
        const matchByName =
          normalizedSetName &&
          tyre.setName &&
          tyre.setName.toLowerCase() === normalizedSetName;
        const matchById =
          numericSetId !== null &&
          tyre.setId !== null &&
          tyre.setId === numericSetId;
        return matchByName || matchById;
      })
      .map(tyre => tyre.id);

    if (idsToDelete.length === 0) {
      return res.status(404).json({ message: "Set pneumatici non trovato." });
    }

    const placeholders = idsToDelete.map(() => "?").join(", ");
    await conn.execute(
      `DELETE FROM tyres_vehicles WHERE vehicle_id = ? AND id IN (${placeholders})`,
      [vehicleId, ...idsToDelete]
    );

    res.status(200).json({
      message: "Set pneumatici rimosso con successo",
      removed: idsToDelete.length
    });
  } catch (err) {
    console.error("Errore DELETE /v1/tyres_vehicles/vehicle/:vehicleId/set:", err);
    res.status(500).json({ message: "Errore server", error: err.message });
  } finally {
    conn.release();
  }
});

// DELETE v1/tyres_vehicles/:tyreId - Elimina un singolo pneumatico per ID
router.delete("/v1/tyres_vehicles/:tyreId", authenticateJWT, async (req, res) => {
  const { tyreId } = req.params;

  if (!tyreId) {
    return res.status(400).json({ message: "tyreId è richiesto." });
  }

  const conn = await pool.getConnection();
  try {
    const [result] = await conn.execute(
      `DELETE FROM tyres_vehicles WHERE id = ?`,
      [tyreId]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Pneumatico non trovato." });
    }

    res.status(200).json({
      message: "Pneumatico rimosso con successo",
      tyre_id: tyreId
    });
  } catch (err) {
    console.error("Errore DELETE /v1/tyres_vehicles/:tyreId:", err);
    res.status(500).json({ message: "Errore server", error: err.message });
  } finally {
    conn.release();
  }
});

// POST v1/tyre_analyses - Crea una nuova analisi
router.post("/v1/tyre_analyses", authenticateJWT, async (req, res) => {
  const data = req.body || {};
  const tyreId = data.tyre_id ?? data.tyreId;
  const vehicleId = data.vehicle_id ?? data.vehicleId;
  const tokenUserId = req.user?.id;
  const bodyUserId = data.user_id ?? data.userId;
  const userId = tokenUserId ?? bodyUserId;

  if (!tyreId || !vehicleId || !userId) {
    return res.status(400).json({ message: "tyre_id, vehicle_id e user_id sono obbligatori." });
  }

  if (bodyUserId && tokenUserId && bodyUserId !== tokenUserId) {
    return res.status(403).json({ message: "user_id non valido per il token fornito." });
  }

  const analysisDate = parseToDate(data.analysis_date ?? data.analysisDate) || new Date();
  const analysisType = data.analysis_type ?? data.analysisType ?? "manual";
  const imageUrls = Array.isArray(data.image_urls) ? JSON.stringify(data.image_urls) : null;

  const analysisId = crypto.randomUUID();

  let conn;
  try {
    conn = await pool.getConnection();
    await conn.beginTransaction();

    await conn.execute(
      `INSERT INTO tyre_analyses (
        id,
        tyre_id,
        user_id,
        vehicle_id,
        analysis_date,
        analysis_type,
        depth_front_left,
        depth_front_right,
        depth_rear_left,
        depth_rear_right,
        depth_average,
        depth_minimum,
        remaining_life_percentage,
        remaining_life_km,
        remaining_life_months,
        confidence_score,
        condition_front_left,
        condition_front_right,
        condition_rear_left,
        condition_rear_right,
        wear_pattern,
        wear_severity,
        notes,
        technician_name,
        location_latitude,
        location_longitude,
        location_address,
        image_urls,
        created_at,
        updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())`,
      [
        analysisId,
        tyreId,
        userId,
        vehicleId,
        analysisDate,
        analysisType,
        data.depth_front_left ?? data.depthFrontLeft ?? null,
        data.depth_front_right ?? data.depthFrontRight ?? null,
        data.depth_rear_left ?? data.depthRearLeft ?? null,
        data.depth_rear_right ?? data.depthRearRight ?? null,
        data.depth_average ?? data.depthAverage ?? null,
        data.depth_minimum ?? data.depthMinimum ?? null,
        data.remaining_life_percentage ?? data.remainingLifePercentage ?? null,
        data.remaining_life_km ?? data.remainingLifeKm ?? null,
        data.remaining_life_months ?? data.remainingLifeMonths ?? null,
        data.confidence_score ?? data.confidenceScore ?? null,
        data.condition_front_left ?? data.conditionFrontLeft ?? null,
        data.condition_front_right ?? data.conditionFrontRight ?? null,
        data.condition_rear_left ?? data.conditionRearLeft ?? null,
        data.condition_rear_right ?? data.conditionRearRight ?? null,
        data.wear_pattern ?? data.wearPattern ?? null,
        data.wear_severity ?? data.wearSeverity ?? null,
        data.notes ?? null,
        data.technician_name ?? data.technicianName ?? null,
        data.location_latitude ?? data.locationLatitude ?? null,
        data.location_longitude ?? data.locationLongitude ?? null,
        data.location_address ?? data.locationAddress ?? null,
        imageUrls
      ]
    );

    const [rows] = await conn.execute(
      `SELECT * FROM tyre_analyses WHERE id = ? LIMIT 1`,
      [analysisId]
    );

    await conn.commit();

    if (!rows.length) {
      return res.status(500).json({ message: "Analisi salvata ma non recuperata." });
    }

    return res.status(201).json(formatTyreAnalysisRow(rows[0]));
  } catch (err) {
    if (conn) await conn.rollback();
    console.error("Errore POST /v1/tyre_analyses:", err);
    return res.status(500).json({ message: "Errore server", error: err.message });
  } finally {
    if (conn) conn.release();
  }
});

// GET v1/tyre_analyses/tyre/:tyreId/latest
router.get("/v1/tyre_analyses/tyre/:tyreId/latest", authenticateJWT, async (req, res) => {
  const { tyreId } = req.params;

  if (!tyreId) {
    return res.status(400).json({ message: "tyreId è richiesto." });
  }

  const conn = await pool.getConnection();
  try {
    const [rows] = await conn.execute(
      `SELECT * FROM tyre_analyses
       WHERE tyre_id = ? AND user_id = ?
       ORDER BY analysis_date DESC, created_at DESC
       LIMIT 1`,
      [tyreId, req.user.id]
    );

    if (!rows.length) {
      return res.status(404).json({ message: "Nessuna analisi trovata." });
    }

    return res.status(200).json(formatTyreAnalysisRow(rows[0]));
  } catch (err) {
    console.error("Errore GET /v1/tyre_analyses/tyre/:tyreId/latest:", err);
    return res.status(500).json({ message: "Errore server", error: err.message });
  } finally {
    conn.release();
  }
});

// GET v1/tyre_analyses/tyre/:tyreId
router.get("/v1/tyre_analyses/tyre/:tyreId", authenticateJWT, async (req, res) => {
  const { tyreId } = req.params;

  if (!tyreId) {
    return res.status(400).json({ message: "tyreId è richiesto." });
  }

  const conn = await pool.getConnection();
  try {
    const [rows] = await conn.execute(
      `SELECT * FROM tyre_analyses
       WHERE tyre_id = ? AND user_id = ?
       ORDER BY analysis_date DESC, created_at DESC`,
      [tyreId, req.user.id]
    );
    return res.status(200).json(rows.map(formatTyreAnalysisRow));
  } catch (err) {
    console.error("Errore GET /v1/tyre_analyses/tyre/:tyreId:", err);
    return res.status(500).json({ message: "Errore server", error: err.message });
  } finally {
    conn.release();
  }
});

// GET v1/tyre_analyses/vehicle/:vehicleId
router.get("/v1/tyre_analyses/vehicle/:vehicleId", authenticateJWT, async (req, res) => {
  const { vehicleId } = req.params;

  if (!vehicleId) {
    return res.status(400).json({ message: "vehicleId è richiesto." });
  }

  const conn = await pool.getConnection();
  try {
    const [rows] = await conn.execute(
      `SELECT * FROM tyre_analyses
       WHERE vehicle_id = ? AND user_id = ?
       ORDER BY analysis_date DESC, created_at DESC`,
      [vehicleId, req.user.id]
    );
    return res.status(200).json(rows.map(formatTyreAnalysisRow));
  } catch (err) {
    console.error("Errore GET /v1/tyre_analyses/vehicle/:vehicleId:", err);
    return res.status(500).json({ message: "Errore server", error: err.message });
  } finally {
    conn.release();
  }
});

// DELETE v1/tyre_analyses/:analysisId
router.delete("/v1/tyre_analyses/:analysisId", authenticateJWT, async (req, res) => {
  const { analysisId } = req.params;

  if (!analysisId) {
    return res.status(400).json({ message: "analysisId è richiesto." });
  }

  const conn = await pool.getConnection();
  try {
    const [result] = await conn.execute(
      `DELETE FROM tyre_analyses WHERE id = ? AND user_id = ?`,
      [analysisId, req.user.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Analisi non trovata." });
    }

    return res.status(200).json({ message: "Analisi eliminata con successo." });
  } catch (err) {
    console.error("Errore DELETE /v1/tyre_analyses/:analysisId:", err);
    return res.status(500).json({ message: "Errore server", error: err.message });
  } finally {
    conn.release();
  }
});

// POST v1/tread_depth_measurements
router.post("/v1/tread_depth_measurements", authenticateJWT, async (req, res) => {
  const measurements = Array.isArray(req.body?.measurements) ? req.body.measurements : [];

  if (measurements.length === 0) {
    return res.status(400).json({ message: "measurements è obbligatorio." });
  }

  const normalized = measurements.map((measurement) => ({
    analysisId: measurement.analysis_id ?? measurement.analysisId,
    tyrePosition: measurement.tyre_position ?? measurement.tyrePosition,
    measurementX: measurement.measurement_x ?? measurement.measurementX ?? null,
    measurementY: measurement.measurement_y ?? measurement.measurementY ?? null,
    zone: measurement.zone ?? null,
    depthMm: measurement.depth_mm ?? measurement.depthMm,
    confidence: measurement.confidence ?? null,
    measurementMethod: measurement.measurement_method ?? measurement.measurementMethod ?? null
  }));

  if (normalized.some((item) => !item.analysisId || !item.tyrePosition || item.depthMm == null)) {
    return res.status(400).json({ message: "analysis_id, tyre_position e depth_mm sono obbligatori." });
  }

  const analysisIds = Array.from(new Set(normalized.map((item) => item.analysisId)));

  let conn;
  try {
    conn = await pool.getConnection();
    const placeholders = analysisIds.map(() => "?").join(", ");
    const [allowed] = await conn.execute(
      `SELECT id FROM tyre_analyses WHERE user_id = ? AND id IN (${placeholders})`,
      [req.user.id, ...analysisIds]
    );

    if (allowed.length !== analysisIds.length) {
      return res.status(403).json({ message: "Accesso non autorizzato alle analisi." });
    }

    const values = normalized.flatMap((item) => [
      item.analysisId,
      item.tyrePosition,
      item.measurementX,
      item.measurementY,
      item.zone,
      item.depthMm,
      item.confidence,
      item.measurementMethod
    ]);

    const rowsPlaceholder = normalized.map(() => "(?, ?, ?, ?, ?, ?, ?, ?)").join(", ");
    await conn.execute(
      `INSERT INTO tread_depth_measurements
       (analysis_id, tyre_position, measurement_x, measurement_y, zone, depth_mm, confidence, measurement_method)
       VALUES ${rowsPlaceholder}`,
      values
    );

    return res.status(201).json({ message: "Misurazioni salvate con successo." });
  } catch (err) {
    console.error("Errore POST /v1/tread_depth_measurements:", err);
    return res.status(500).json({ message: "Errore server", error: err.message });
  } finally {
    if (conn) conn.release();
  }
});

// GET v1/tread_depth_measurements/analysis/:analysisId
router.get("/v1/tread_depth_measurements/analysis/:analysisId", authenticateJWT, async (req, res) => {
  const { analysisId } = req.params;

  if (!analysisId) {
    return res.status(400).json({ message: "analysisId è richiesto." });
  }

  const conn = await pool.getConnection();
  try {
    const [rows] = await conn.execute(
      `SELECT tdm.*
       FROM tread_depth_measurements tdm
       INNER JOIN tyre_analyses ta ON ta.id = tdm.analysis_id
       WHERE tdm.analysis_id = ? AND ta.user_id = ?
       ORDER BY tdm.created_at ASC`,
      [analysisId, req.user.id]
    );

    return res.status(200).json(rows.map(formatTreadMeasurementRow));
  } catch (err) {
    console.error("Errore GET /v1/tread_depth_measurements/analysis/:analysisId:", err);
    return res.status(500).json({ message: "Errore server", error: err.message });
  } finally {
    conn.release();
  }
});

// POST v1/tyre_lifecycle_projections
router.post("/v1/tyre_lifecycle_projections", authenticateJWT, async (req, res) => {
  const projections = Array.isArray(req.body?.projections) ? req.body.projections : [];

  if (projections.length === 0) {
    return res.status(400).json({ message: "projections è obbligatorio." });
  }

  const normalized = projections.map((projection) => ({
    analysisId: projection.analysis_id ?? projection.analysisId,
    kilometersFromNow: projection.kilometers_from_now ?? projection.kilometersFromNow,
    projectedDepth: projection.projected_depth ?? projection.projectedDepth,
    confidence: projection.confidence ?? null,
    isProjected: projection.is_projected ?? projection.isProjected ?? true
  }));

  if (normalized.some((item) => !item.analysisId || item.kilometersFromNow == null || item.projectedDepth == null)) {
    return res.status(400).json({ message: "analysis_id, kilometers_from_now e projected_depth sono obbligatori." });
  }

  const analysisIds = Array.from(new Set(normalized.map((item) => item.analysisId)));

  let conn;
  try {
    conn = await pool.getConnection();
    const placeholders = analysisIds.map(() => "?").join(", ");
    const [allowed] = await conn.execute(
      `SELECT id FROM tyre_analyses WHERE user_id = ? AND id IN (${placeholders})`,
      [req.user.id, ...analysisIds]
    );

    if (allowed.length !== analysisIds.length) {
      return res.status(403).json({ message: "Accesso non autorizzato alle analisi." });
    }

    const values = normalized.flatMap((item) => [
      item.analysisId,
      item.kilometersFromNow,
      item.projectedDepth,
      item.confidence,
      item.isProjected ? 1 : 0
    ]);

    const rowsPlaceholder = normalized.map(() => "(?, ?, ?, ?, ?)").join(", ");
    await conn.execute(
      `INSERT INTO tyre_lifecycle_projections
       (analysis_id, kilometers_from_now, projected_depth, confidence, is_projected)
       VALUES ${rowsPlaceholder}`,
      values
    );

    return res.status(201).json({ message: "Proiezioni salvate con successo." });
  } catch (err) {
    console.error("Errore POST /v1/tyre_lifecycle_projections:", err);
    return res.status(500).json({ message: "Errore server", error: err.message });
  } finally {
    if (conn) conn.release();
  }
});

// GET v1/tyre_lifecycle_projections/analysis/:analysisId
router.get("/v1/tyre_lifecycle_projections/analysis/:analysisId", authenticateJWT, async (req, res) => {
  const { analysisId } = req.params;

  if (!analysisId) {
    return res.status(400).json({ message: "analysisId è richiesto." });
  }

  const conn = await pool.getConnection();
  try {
    const [rows] = await conn.execute(
      `SELECT tlp.*
       FROM tyre_lifecycle_projections tlp
       INNER JOIN tyre_analyses ta ON ta.id = tlp.analysis_id
       WHERE tlp.analysis_id = ? AND ta.user_id = ?
       ORDER BY tlp.kilometers_from_now ASC`,
      [analysisId, req.user.id]
    );

    return res.status(200).json(rows.map(formatLifecycleProjectionRow));
  } catch (err) {
    console.error("Errore GET /v1/tyre_lifecycle_projections/analysis/:analysisId:", err);
    return res.status(500).json({ message: "Errore server", error: err.message });
  } finally {
    conn.release();
  }
});

// GET v1/user_analysis_stats/:userId
router.get("/v1/user_analysis_stats/:userId", authenticateJWT, async (req, res) => {
  const { userId } = req.params;

  if (!userId) {
    return res.status(400).json({ message: "userId è richiesto." });
  }

  if (req.user?.id && req.user.id !== userId) {
    return res.status(403).json({ message: "Accesso non autorizzato." });
  }

  const conn = await pool.getConnection();
  try {
    const [rows] = await conn.execute(
      `SELECT * FROM user_analysis_stats WHERE user_id = ?`,
      [userId]
    );
    return res.status(200).json(rows.map(formatUserAnalysisStatsRow));
  } catch (err) {
    console.error("Errore GET /v1/user_analysis_stats/:userId:", err);
    return res.status(500).json({ message: "Errore server", error: err.message });
  } finally {
    conn.release();
  }
});

// POST v1/bug-reports - Segnalazione bug da parte degli utenti
router.post("/v1/bug-reports", authenticateJWT, async (req, res) => {
  const { user_id, description, screenshot, device_info, timestamp } = req.body;

  // Validazione: description è obbligatorio
  if (!description || description.trim().length === 0) {
    return res.status(400).json({ message: "La descrizione del bug è obbligatoria." });
  }

  // Validazione lunghezza descrizione (max 2000 caratteri)
  if (description.length > 2000) {
    return res.status(400).json({ message: "La descrizione è troppo lunga (massimo 2000 caratteri)." });
  }

  let conn;
  try {
    conn = await pool.getConnection();
    await conn.beginTransaction();

    // Prepara i dati del dispositivo (JSON string o null)
    const deviceInfoJson = device_info ? JSON.stringify(device_info) : null;

    // Gestione screenshot (opzionale)
    let screenshotBuffer = null;
    let screenshotSize = null;
    let screenshotHash = null;

    if (screenshot && screenshot.trim().length > 0) {
      try {
        // Decodifica base64 e comprimi screenshot
        screenshotBuffer = Buffer.from(screenshot, "base64");

        // Comprimi screenshot con Sharp (max 800px width, quality 60)
        const compressedScreenshot = await sharp(screenshotBuffer)
          .resize(800, null, { withoutEnlargement: true, fit: 'inside' })
          .jpeg({ quality: 60, mozjpeg: true })
          .toBuffer();

        screenshotBuffer = compressedScreenshot;
        screenshotSize = compressedScreenshot.length;
        screenshotHash = crypto.createHash("sha256").update(compressedScreenshot).digest("hex");
      } catch (imageErr) {
        console.error("Errore compressione screenshot:", imageErr);
        // Non blocchiamo la segnalazione se lo screenshot fallisce
        screenshotBuffer = null;
      }
    }

    // Inserisci bug report nel database
    const [result] = await conn.execute(
      `INSERT INTO bug_reports
       (user_id, description, screenshot_data, screenshot_size, screenshot_hash,
        device_info, report_timestamp, status, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())`,
      [
        user_id || null,
        description.trim(),
        screenshotBuffer,
        screenshotSize,
        screenshotHash,
        deviceInfoJson,
        timestamp || new Date().toISOString(),
        'pending' // Status iniziale
      ]
    );

    const bugReportId = result.insertId;

    await conn.commit();

    console.log(`[BUG-REPORT] Nuova segnalazione #${bugReportId} da user ${user_id || 'anonimo'}`);

    res.status(201).json({
      id: bugReportId,
      message: "Segnalazione bug ricevuta con successo. Grazie per il tuo feedback!",
      created_at: new Date().toISOString()
    });

  } catch (err) {
    if (conn) {
      try {
        await conn.rollback();
      } catch (rollbackErr) {
        console.error("Rollback fallita su /v1/bug-reports:", rollbackErr);
      }
    }
    console.error("Errore POST /v1/bug-reports:", err);
    res.status(500).json({ message: "Errore server durante l'invio della segnalazione", error: err.message });
  } finally {
    if (conn) {
      conn.release();
    }
  }
});

// GET v1/bug-reports - Lista segnalazioni bug (admin only - opzionale)
router.get("/v1/bug-reports", authenticateJWT, async (req, res) => {
  // Verifica se l'utente è admin (aggiungi questa logica se necessario)
  const isAdmin = req.user.role === 'admin' || req.user.role === 'service_role';

  if (!isAdmin) {
    return res.status(403).json({ message: "Accesso negato. Solo gli amministratori possono visualizzare le segnalazioni." });
  }

  const { status, limit = 50, offset = 0 } = req.query;

  let conn;
  try {
    conn = await pool.getConnection();

    // Query base
    let query = `
      SELECT
        id,
        user_id,
        description,
        screenshot_size,
        device_info,
        report_timestamp,
        status,
        created_at,
        resolved_at
      FROM bug_reports
    `;

    const params = [];

    // Filtra per status se fornito
    if (status && ['pending', 'in_progress', 'resolved', 'dismissed'].includes(status)) {
      query += ` WHERE status = ?`;
      params.push(status);
    }

    query += ` ORDER BY created_at DESC LIMIT ? OFFSET ?`;
    params.push(parseInt(limit, 10), parseInt(offset, 10));

    const [reports] = await conn.execute(query, params);

    // Parse device_info JSON
    const reportsFormatted = reports.map(report => ({
      ...report,
      device_info: report.device_info ? JSON.parse(report.device_info) : null,
      has_screenshot: report.screenshot_size > 0
    }));

    res.status(200).json({
      reports: reportsFormatted,
      count: reports.length,
      limit: parseInt(limit, 10),
      offset: parseInt(offset, 10)
    });

  } catch (err) {
    console.error("Errore GET /v1/bug-reports:", err);
    res.status(500).json({ message: "Errore server", error: err.message });
  } finally {
    if (conn) {
      conn.release();
    }
  }
});

  // monta il router sia su "/" sia su "/api"
  app.use("/", router);
  app.use("/api", router);

  // 404 JSON chiaro (qualsiasi altro path)
  app.use((_req, res) => res.status(404).json({ message: "Route non trovata" }));

  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => console.log(`TyreVibes API su porta ${PORT}`));
