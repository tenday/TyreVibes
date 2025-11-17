-- ============================================================================
-- TYREVIBES - Database Schema SQLite
-- ============================================================================
-- Versione per SQLite 3.35+
-- Utile per: sviluppo locale, testing, app offline
-- ============================================================================

-- ============================================================================
-- 1. TABELLA: users
-- ============================================================================

CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,  -- UUID come stringa
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT,
    full_name TEXT,
    phone TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_login DATETIME,
    is_active INTEGER DEFAULT 1,  -- 1=true, 0=false
    is_premium INTEGER DEFAULT 0
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_active ON users(is_active);

-- ============================================================================
-- 2. TABELLA: vehicles
-- ============================================================================

CREATE TABLE IF NOT EXISTS vehicles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    brand TEXT NOT NULL,
    model TEXT NOT NULL,
    year INTEGER,
    plate_number TEXT,
    vin TEXT,

    insurance_expiry DATE,
    revision_expiry DATE,
    bollo_expiry DATE,

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_vehicles_user ON vehicles(user_id);
CREATE INDEX idx_vehicles_plate ON vehicles(plate_number);

-- ============================================================================
-- 3. TABELLA: tyres_vehicles
-- ============================================================================

CREATE TABLE IF NOT EXISTS tyres_vehicles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vehicle_id INTEGER NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,

    brand TEXT NOT NULL,
    model TEXT NOT NULL,
    size TEXT NOT NULL,
    dot TEXT NOT NULL,
    load_index TEXT,
    speed_rating TEXT,
    season TEXT,

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_tyres_vehicle ON tyres_vehicles(vehicle_id);

-- ============================================================================
-- 4. TABELLA: tyre_analyses
-- ============================================================================

CREATE TABLE IF NOT EXISTS tyre_analyses (
    id TEXT PRIMARY KEY,  -- UUID
    tyre_id INTEGER NOT NULL REFERENCES tyres_vehicles(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    vehicle_id INTEGER NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,

    analysis_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    analysis_type TEXT DEFAULT 'manual',

    depth_front_left REAL CHECK (depth_front_left >= 0 AND depth_front_left <= 15),
    depth_front_right REAL CHECK (depth_front_right >= 0 AND depth_front_right <= 15),
    depth_rear_left REAL CHECK (depth_rear_left >= 0 AND depth_rear_left <= 15),
    depth_rear_right REAL CHECK (depth_rear_right >= 0 AND depth_rear_right <= 15),
    depth_average REAL,
    depth_minimum REAL,

    remaining_life_percentage REAL,
    remaining_life_km INTEGER,
    remaining_life_months INTEGER,
    confidence_score REAL CHECK (confidence_score >= 0 AND confidence_score <= 1),

    condition_front_left INTEGER CHECK (condition_front_left >= 0 AND condition_front_left <= 100),
    condition_front_right INTEGER CHECK (condition_front_right >= 0 AND condition_front_right <= 100),
    condition_rear_left INTEGER CHECK (condition_rear_left >= 0 AND condition_rear_left <= 100),
    condition_rear_right INTEGER CHECK (condition_rear_right >= 0 AND condition_rear_right <= 100),

    wear_pattern TEXT,
    wear_severity TEXT,

    notes TEXT,
    technician_name TEXT,

    location_latitude REAL,
    location_longitude REAL,
    location_address TEXT,

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_analyses_tyre ON tyre_analyses(tyre_id);
CREATE INDEX idx_analyses_user ON tyre_analyses(user_id);
CREATE INDEX idx_analyses_vehicle ON tyre_analyses(vehicle_id);
CREATE INDEX idx_analyses_date ON tyre_analyses(analysis_date DESC);

-- ============================================================================
-- 5. TABELLA: tread_depth_measurements
-- ============================================================================

CREATE TABLE IF NOT EXISTS tread_depth_measurements (
    id TEXT PRIMARY KEY,  -- UUID
    analysis_id TEXT NOT NULL REFERENCES tyre_analyses(id) ON DELETE CASCADE,

    tyre_position TEXT NOT NULL CHECK (tyre_position IN ('FL', 'FR', 'RL', 'RR')),
    measurement_x REAL,
    measurement_y REAL,
    zone TEXT,

    depth_mm REAL NOT NULL CHECK (depth_mm >= 0 AND depth_mm <= 15),
    confidence REAL CHECK (confidence >= 0 AND confidence <= 1),
    measurement_method TEXT,

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_measurements_analysis ON tread_depth_measurements(analysis_id);
CREATE INDEX idx_measurements_position ON tread_depth_measurements(tyre_position);

-- ============================================================================
-- 6. TABELLA: tyre_lifecycle_projections
-- ============================================================================

CREATE TABLE IF NOT EXISTS tyre_lifecycle_projections (
    id TEXT PRIMARY KEY,  -- UUID
    analysis_id TEXT NOT NULL REFERENCES tyre_analyses(id) ON DELETE CASCADE,

    kilometers_from_now INTEGER NOT NULL,
    projected_depth REAL NOT NULL CHECK (projected_depth >= 0 AND projected_depth <= 15),
    confidence REAL CHECK (confidence >= 0 AND confidence <= 1),
    is_projected INTEGER DEFAULT 1,  -- 1=true, 0=false

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_projections_analysis ON tyre_lifecycle_projections(analysis_id);
CREATE INDEX idx_projections_km ON tyre_lifecycle_projections(kilometers_from_now);

-- ============================================================================
-- 7. TABELLA: tyre_recommendations
-- ============================================================================

CREATE TABLE IF NOT EXISTS tyre_recommendations (
    id TEXT PRIMARY KEY,  -- UUID
    analysis_id TEXT NOT NULL REFERENCES tyre_analyses(id) ON DELETE CASCADE,

    priority TEXT NOT NULL CHECK (priority IN ('critical', 'high', 'medium', 'low')),
    category TEXT NOT NULL,
    urgency TEXT NOT NULL,

    title TEXT NOT NULL,
    description TEXT NOT NULL,
    action_required TEXT NOT NULL,

    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'acknowledged', 'completed', 'dismissed')),
    completed_at DATETIME,

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_recommendations_analysis ON tyre_recommendations(analysis_id);
CREATE INDEX idx_recommendations_priority ON tyre_recommendations(priority);
CREATE INDEX idx_recommendations_status ON tyre_recommendations(status);

-- ============================================================================
-- 8. TABELLA: image_uploads
-- ============================================================================

CREATE TABLE IF NOT EXISTS image_uploads (
    id TEXT PRIMARY KEY,  -- UUID
    analysis_id TEXT NOT NULL REFERENCES tyre_analyses(id) ON DELETE CASCADE,

    filename TEXT NOT NULL,
    file_path TEXT NOT NULL,
    file_url TEXT,
    file_size INTEGER,
    mime_type TEXT,
    image_type TEXT,

    uploaded_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_images_analysis ON image_uploads(analysis_id);

-- ============================================================================
-- 9. TRIGGER per auto-update timestamp
-- ============================================================================

-- Trigger per tyre_analyses
CREATE TRIGGER tyre_analyses_update_timestamp
AFTER UPDATE ON tyre_analyses
FOR EACH ROW
BEGIN
    UPDATE tyre_analyses SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Trigger per tyre_recommendations
CREATE TRIGGER tyre_recommendations_update_timestamp
AFTER UPDATE ON tyre_recommendations
FOR EACH ROW
BEGIN
    UPDATE tyre_recommendations SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Trigger per vehicles
CREATE TRIGGER vehicles_update_timestamp
AFTER UPDATE ON vehicles
FOR EACH ROW
BEGIN
    UPDATE vehicles SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Trigger per users
CREATE TRIGGER users_update_timestamp
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    UPDATE users SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- ============================================================================
-- 10. VISTE
-- ============================================================================

-- Vista: ultima analisi per ogni pneumatico
CREATE VIEW IF NOT EXISTS latest_tyre_analyses AS
SELECT *
FROM tyre_analyses
WHERE (tyre_id, analysis_date) IN (
    SELECT tyre_id, MAX(analysis_date)
    FROM tyre_analyses
    GROUP BY tyre_id
);

-- Vista: statistiche utente
CREATE VIEW IF NOT EXISTS user_analysis_stats AS
SELECT
    user_id,
    COUNT(*) as total_analyses,
    COUNT(DISTINCT tyre_id) as tyres_analyzed,
    AVG(depth_average) as avg_depth,
    AVG(remaining_life_percentage) as avg_remaining_life,
    MAX(analysis_date) as last_analysis_date
FROM tyre_analyses
GROUP BY user_id;

-- Vista: analisi critiche
CREATE VIEW IF NOT EXISTS critical_tyre_analyses AS
SELECT ta.*, tv.brand as tyre_brand, tv.model as tyre_model
FROM tyre_analyses ta
JOIN tyres_vehicles tv ON ta.tyre_id = tv.id
WHERE ta.wear_severity IN ('severe', 'critical')
   OR ta.depth_minimum < 2.0
ORDER BY ta.analysis_date DESC;

-- ============================================================================
-- 11. PRAGMA per ottimizzazioni SQLite
-- ============================================================================

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;  -- Write-Ahead Logging per performance
PRAGMA synchronous = NORMAL;
PRAGMA temp_store = MEMORY;
PRAGMA cache_size = -64000;  -- 64MB cache

-- ============================================================================
-- FINE SCHEMA SQLite
-- ============================================================================

-- Verifica installazione
SELECT 'SQLite Schema created successfully!' as status;
