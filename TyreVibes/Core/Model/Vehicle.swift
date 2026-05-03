import Foundation

struct Vehicle: Identifiable, Codable, Hashable {
    let id: Int
    let modelDetail: String?
    let engine: String?
    let make: String?
    let model: String?
    let version: String?
    let fuelType: String?
    let displacementCC: Int?
    let powerCV: Int?
    let powerKW: String?
    let emissionClass: String?
    let gearbox: String?
    let maxSpeed: String?
    let bodyType: String?
    let doors: String?
    let seats: String?
    let consumption: String?
    let traction: String?
    let saleStart: String?
    let saleEnd: String?
    let color: String?
    let vin: String?
    let currentMileage: Int?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case modelDetail = "model_detail"
        case engine
        case make
        case model
        case version
        case fuelType = "fuel_type"
        case displacementCC = "displacement_cc"
        case powerCV = "power_cv"
        case powerKW = "power_kw"
        case emissionClass = "emission_class"
        case gearbox
        case maxSpeed = "max_speed"
        case bodyType = "body_type"
        case doors
        case seats
        case consumption
        case traction
        case saleStart = "sale_start"
        case saleEnd = "sale_end"
        case color
        case vin
        case currentMileage = "current_mileage"
        case createdAt = "created_at"
    }
}

struct Plate: Codable, Identifiable, Hashable {
    let id: Int
    let plateNumber: String
    let registrationDate: String?
    let year: Int?
    let month :Int?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case plateNumber = "plate_number"
        case registrationDate = "registration_date"
        case year
        case month
        case createdAt = "created_at"
    }
    
}

struct VehicleImage: Codable, Identifiable, Hashable {
    let id: Int
    let mimeType: String?
    let color: String?
    let fileName: String?
    let fileSize: Int?
    let sha256: String?
    let imageBase64: String?

    enum CodingKeys: String, CodingKey {
        case id
        case mimeType = "mime_type"
        case color
        case fileName = "file_name"
        case fileSize = "file_size"
        case sha256
        case imageBase64 = "image_base64"
    }
}

struct VehicleTyre: Codable, Identifiable, Hashable {
    let id: Int
    let width: Int?
    let diameter: Int?
    let ratio: Int?
    let speedIndex: String?
    let loadIndex: String?
    let sizeLabel: String?
    let season: String?
    let setId: Int? // Per identificare il set di appartenenza (es. 1 = anteriore, 2 = posteriore)
    let setName: String? // Nome del set (es. "Anteriore", "Posteriore", "Set Standard")

    enum CodingKeys: String, CodingKey {
        case id
        case width
        case diameter
        case ratio
        case speedIndex = "speed_index"
        case loadIndex = "load_index"
        case sizeLabel = "size_label"
        case season
        case setId = "set_id"
        case setName = "set_name"
    }
}

struct VehicleRevision: Codable, Identifiable, Hashable {
    let id: Int
    let plateId: Int
    let kmRevisione: String?
    let dataRevisione: String?
    let esitoRevisione: String?

    enum CodingKeys: String, CodingKey {
        case id
        case plateId = "plate_id"
        case kmRevisione
        case dataRevisione
        case esitoRevisione
    }
}

struct VehicleInsurance: Codable, Identifiable, Hashable {
    let id: Int
    let plateId: Int
    let rcaCompany: String?
    let rcaPolicyNumber: String?
    let rcaExpiry: String?
    let rcaInsurancePresent: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case plateId = "plate_id"
        case rcaCompany = "rca_company"
        case rcaPolicyNumber = "rca_policy_number"
        case rcaExpiry = "rca_expiry"
        case rcaInsurancePresent = "rca_insurance_present"
    }
}

// MARK: - Tyre Size Set
struct TyreSizeSet: Identifiable, Hashable {
    let id: Int
    let name: String
    let tyres: [VehicleTyre]
    let isDefault: Bool

    init(id: Int, name: String, tyres: [VehicleTyre], isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.tyres = tyres
        self.isDefault = isDefault
    }
}

// MARK: - Derived Info
extension Vehicle {
    /// Descrizione "intelligente" del motore quando il campo engine è mancante.
    /// Combina cilindrata e alimentazione compatta come fallback.
    var smartEngineDescription: String? {
        if let engine = Vehicle.cleanEngineDescription(engine, allowsShortFallback: true) {
            return engine
        }

        if let modelDetailEngine = Vehicle.cleanEngineDescription(modelDetail, allowsShortFallback: false) {
            return modelDetailEngine
        }

        var parts: [String] = []

        if let displacement = displacementCC, displacement > 0 {
            parts.append(Vehicle.formattedLiters(fromCC: Double(displacement)))
        }

        if let fuel = Vehicle.compactFuelLabel(fuelType) {
            parts.append(fuel)
        }

        if !parts.isEmpty {
            return parts.joined(separator: " ")
        }

        if let version = Vehicle.cleanedVehicleValue(version)?.uppercased() ?? Vehicle.cleanedVehicleValue(modelDetail)?.uppercased() {
            return version
        }

        return nil
    }

    private static let validEngineTokens: Set<String> = [
        "BZ", "BENZINA", "TSI", "TFSI", "MPI", "GDI", "VTEC", "FSI", "DOHC",
        "TURBO", "ETSI", "ECOTEC", "ECOBOOST", "PURETECH", "MULTIAIR", "T-JET", "DIG-T",
        "BOOSTERJET", "IG-T", "CVVT", "VVTI", "GSE", "BVA", "MIVEC", "SKYACTIV", "I-VTEC",
        "I4", "I3", "BOXER", "TCE", "PHEV", "MHEV", "HEV", "HYBRID", "MHYBRID",
        "DIESEL", "TDI", "CDTI", "DCI", "JTD", "MULTIJET", "CRDI", "HDI", "BLUEHDI", "D4D",
        "SDI", "DID", "IDTEC", "TD4", "TDV6", "DTEC", "CDI", "BTDI", "DTH", "DTI",
        "BLUE", "BLUEDCI", "MJET", "DI-D", "D", "JTDM",
        "GPL", "CNG", "METANO", "BIFUEL", "LPG", "NGT", "G-TEC", "ECOGPL", "TGI",
        "EV", "ELETTRICO", "BEV", "EPOWER", "E-TECH", "EHYBRID", "PLUG-IN", "HYBRID4", "RECHARGE",
        "GTI", "RS", "AMG", "VTI", "TFSIE", "SKYACTIV-G", "SKYACTIV-D", "MULTIAIR2"
    ]

    private static func cleanedVehicleValue(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }

        let lowercased = trimmed.lowercased()
        guard lowercased != "null", lowercased != "n/a", lowercased != "na", lowercased != "-" else {
            return nil
        }

        return trimmed
    }

    private static func cleanEngineDescription(_ value: String?, allowsShortFallback: Bool) -> String? {
        guard let raw = cleanedVehicleValue(value) else { return nil }
        var normalized = raw
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "cm³", with: "cc", options: .caseInsensitive)
            .replacingOccurrences(of: "cm3", with: "cc", options: .caseInsensitive)
            .replacingOccurrences(of: "c.c.", with: "cc", options: .caseInsensitive)
            .replacingOccurrences(of: #"[\n\r\t]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        normalized = normalized
            .replacingOccurrences(of: #"(?i)\be\s+tsi\b"#, with: "ETSI", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\bm\s+hybrid\b"#, with: "MHYBRID", options: .regularExpression)

        if let compact = firstMatch(in: normalized, pattern: #"(?i)\b(?:xdrive|sdrive)?\s*(\d{2,3})([di])\b"#) {
            return "\(compact[1])\(compact[2].lowercased())"
        }

        if let literEngine = cleanLiterEngine(from: normalized) {
            return literEngine
        }

        if let ccEngine = cleanCubicCentimeterEngine(from: normalized) {
            return ccEngine
        }

        if allowsShortFallback,
           raw.count <= 24,
           raw.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) != nil {
            return Vehicle.compactFuelLabel(raw) ?? raw.uppercased()
        }

        return nil
    }

    private static func cleanLiterEngine(from value: String) -> String? {
        let pattern = #"(?i)\b(\d{1,2}(?:\.\d)?)\s*(?:l|lt|litri)?\s*([a-z][a-z0-9]*(?:[-+][a-z0-9]+)?)\b"#
        for match in allMatches(in: value, pattern: pattern) where match.count >= 3 {
            let displacement = match[1]
            let token = normalizedEngineToken(match[2])
            if validEngineTokens.contains(token) {
                return "\(displacement) \(compactEngineToken(token))"
            }
        }
        return nil
    }

    private static func cleanCubicCentimeterEngine(from value: String) -> String? {
        let pattern = #"(?i)\b(\d{3,5})\s*(?:cc)\b.{0,32}?\b([a-z][a-z0-9]*(?:[-+][a-z0-9]+)?)\b"#
        for match in allMatches(in: value, pattern: pattern) where match.count >= 3 {
            guard let cc = Double(match[1]) else { continue }
            let token = normalizedEngineToken(match[2])
            if validEngineTokens.contains(token) {
                return "\(formattedLiters(fromCC: cc)) \(compactEngineToken(token))"
            }
        }
        return nil
    }

    private static func normalizedEngineToken(_ token: String) -> String {
        token
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
    }

    private static func compactFuelLabel(_ value: String?) -> String? {
        guard let value = cleanedVehicleValue(value) else { return nil }
        return compactEngineToken(normalizedEngineToken(value))
    }

    private static func compactEngineToken(_ token: String) -> String {
        switch token {
        case "DIESEL":
            return "D"
        case "MULTIJET":
            return "MJET"
        case "BENZINA", "BZ":
            return "B"
        case "ELETTRICO", "BEV", "MOTORELETTRICO":
            return "EV"
        case "METANO", "NGT", "G-TEC", "TGI":
            return "CNG"
        case "LPG":
            return "GPL"
        case "HYBRID":
            return "HYB"
        case "PLUG":
            return "PHEV"
        default:
            return token
        }
    }

    private static func formattedLiters(fromCC cc: Double) -> String {
        let liters = cc / 1000.0
        let rounded = (liters * 10).rounded() / 10
        return String(format: "%.1f", rounded)
    }

    private static func firstMatch(in value: String, pattern: String) -> [String]? {
        allMatches(in: value, pattern: pattern).first
    }

    private static func allMatches(in value: String, pattern: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.matches(in: value, range: nsRange).map { match in
            (0..<match.numberOfRanges).compactMap { index in
                guard let range = Range(match.range(at: index), in: value) else { return nil }
                return String(value[range])
            }
        }
    }

    /// Descrizione "intelligente" del modello quando `model` è mancante.
    /// Pulisce il nome rimuovendo il brand e le indicazioni di serie/generazione numerica.
    /// Usa model -> version -> modelDetail come fallback.
    var smartModelDescription: String? {
        func cleaned(_ value: String?) -> String? {
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
                return nil
            }
            return trimmed
        }

        func normalizedModel(_ raw: String, make: String?) -> String? {
            var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }

            // Rimuovi il brand se è prefisso
            if let make = make?.trimmingCharacters(in: .whitespacesAndNewlines), !make.isEmpty {
                let lowerText = text.lowercased()
                let makeLower = make.lowercased()
                if lowerText.hasPrefix(makeLower + " ") {
                    text = String(text.dropFirst(make.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            // Normalizza spazi
            text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

            // Rimuovi indicazioni di serie/generazione numerica (ma mantieni "SERIE A" o simili)
            let patterns = [
                #"(?i)\b\d+\s*(?:a|ª)?\s*serie\b"#,      // "4a serie"
                #"(?i)\bserie\s*\d+(?:a|ª)?\b"#,         // "serie 4"
                #"(?i)\bserie\s*[ivx]+\b"#,              // "serie iv"
                #"(?i)\b[ivx]+\s*serie\b"#,              // "iv serie"
                #"(?i)\bmk\s*\d+\b"#                     // "mk4"
            ]
            for pattern in patterns {
                text = text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
            }

            text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else { return nil }
            return text.uppercased()
        }

        if let model = cleaned(model), let normalized = normalizedModel(model, make: make) {
            return normalized
        }
        if let version = cleaned(version), let normalized = normalizedModel(version, make: make) {
            return normalized
        }
        if let detail = cleaned(modelDetail), let normalized = normalizedModel(detail, make: make) {
            return normalized
        }
        return nil
    }

    var summaryName: String {
        let candidates = [make, model, version, modelDetail]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !candidates.isEmpty else {
            return "Veicolo"
        }

        return candidates.joined(separator: " ")
    }
}
