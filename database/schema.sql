-- ============================================================================
-- TYREVIBES - Database Schema SQL Standard
-- ============================================================================
-- Compatibile con: PostgreSQL, MySQL 8.0+, MariaDB 10.5+
-- NON richiede Supabase o altre dipendenze specifiche
-- ============================================================================

-- ============================================================================
-- 1. TABELLA: users
-- Gestione utenti (se non usi un sistema auth esterno)
-- ============================================================================

CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(36) PRIMARY KEY,  -- UUID come stringa
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255),  -- BCrypt hash
    full_name VARCHAR(255),
    phone VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_login TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    is_premium BOOLEAN DEFAULT FALSE,

    INDEX idx_users_email (email),
    INDEX idx_users_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- 2. TABELLA: vehicles
-- Veicoli degli utenti
-- ============================================================================

CREATE TABLE IF NOT EXISTS vehicles (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,

    -- Dati veicolo
    brand VARCHAR(100) NOT NULL,
    model VARCHAR(100) NOT NULL,
    year INT,
    plate_number VARCHAR(20),
    vin VARCHAR(17),
    current_mileage INT,

    -- Dati assicurazione e revisione
    insurance_expiry DATE,
    revision_expiry DATE,
    bollo_expiry DATE,

    -- Metadati
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_vehicles_user (user_id),
    INDEX idx_vehicles_plate (plate_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- 3. TABELLA: completed_maintenance
-- Storico manutenzioni completate per veicolo
-- ============================================================================

CREATE TABLE IF NOT EXISTS completed_maintenance (
    id VARCHAR(36) PRIMARY KEY,  -- UUID
    vehicle_id INT NOT NULL,

    title VARCHAR(255) NOT NULL,
    note TEXT,
    maintenance_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    mileage INT,
    source VARCHAR(20) NOT NULL DEFAULT 'manual', -- manual | partner | automatic
    partner_appointment_id VARCHAR(120),
    maintenance_type VARCHAR(50),              -- MaintenanceType raw value
    cost DECIMAL(10,2),                        -- Actual cost in EUR
    workshop_name VARCHAR(255),                -- Workshop/mechanic name
    workshop_id VARCHAR(120),                  -- Partner workshop ID

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE,
    CONSTRAINT chk_completed_maintenance_mileage CHECK (mileage IS NULL OR mileage >= 0),
    CONSTRAINT chk_completed_maintenance_source CHECK (source IN ('manual', 'partner', 'automatic')),
    CONSTRAINT chk_completed_maintenance_cost CHECK (cost IS NULL OR cost >= 0),
    UNIQUE KEY uq_completed_maintenance_partner_appointment (vehicle_id, partner_appointment_id),
    INDEX idx_completed_maintenance_vehicle (vehicle_id),
    INDEX idx_completed_maintenance_date (maintenance_date),
    INDEX idx_completed_maintenance_source (source),
    INDEX idx_completed_maintenance_type (maintenance_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- 3b. TABELLA: maintenance_intervals
-- Intervalli programmati per manutenzione veicolo
-- ============================================================================

CREATE TABLE IF NOT EXISTS maintenance_intervals (
    id VARCHAR(36) PRIMARY KEY,
    vehicle_id INT,
    maintenance_type VARCHAR(50) NOT NULL,
    km_interval INT,
    months_interval INT,
    is_custom BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE,
    CONSTRAINT chk_interval_km CHECK (km_interval IS NULL OR km_interval > 0),
    CONSTRAINT chk_interval_months CHECK (months_interval IS NULL OR months_interval > 0),
    INDEX idx_maintenance_intervals_vehicle (vehicle_id),
    INDEX idx_maintenance_intervals_type (maintenance_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- 4. TABELLA: tyres_vehicles
-- Pneumatici registrati per i veicoli
-- ============================================================================

CREATE TABLE IF NOT EXISTS tyres_vehicles (
    id INT AUTO_INCREMENT PRIMARY KEY,
    vehicle_id INT NOT NULL,

    -- Dati pneumatico
    brand VARCHAR(100) NOT NULL,
    model VARCHAR(100) NOT NULL,
    size VARCHAR(50) NOT NULL,  -- es. "225/40R18"
    dot VARCHAR(10) NOT NULL,    -- es. "1221" (week/year)
    load_index VARCHAR(10),      -- es. "92"
    speed_rating VARCHAR(5),     -- es. "Y"
    season VARCHAR(20),          -- "Summer", "Winter", "All-Season"
    set_name VARCHAR(100),       -- Nome del set (es. "Anteriore", "Posteriore")
    set_position VARCHAR(20),    -- "front", "rear"

    -- Metadati
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE,
    INDEX idx_tyres_vehicle (vehicle_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- 5. TABELLA: tyre_analyses
-- Analisi complete dei pneumatici
-- ============================================================================

CREATE TABLE IF NOT EXISTS tyre_analyses (
    id VARCHAR(36) PRIMARY KEY,  -- UUID
    tyre_id INT NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    vehicle_id INT NOT NULL,

    -- Metadata analisi
    analysis_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    analysis_type VARCHAR(50) DEFAULT 'manual',  -- 'manual', 'ai_scan', 'automatic'

    -- Profondità battistrada (in mm)
    depth_front_left DECIMAL(4,2),
    depth_front_right DECIMAL(4,2),
    depth_rear_left DECIMAL(4,2),
    depth_rear_right DECIMAL(4,2),
    depth_average DECIMAL(4,2),
    depth_minimum DECIMAL(4,2),

    -- Vita rimanente
    remaining_life_percentage DECIMAL(5,2),  -- 0-100
    remaining_life_km INT,
    remaining_life_months INT,
    confidence_score DECIMAL(3,2),  -- 0-1

    -- Condizioni pneumatici (0-100)
    condition_front_left INT CHECK (condition_front_left >= 0 AND condition_front_left <= 100),
    condition_front_right INT CHECK (condition_front_right >= 0 AND condition_front_right <= 100),
    condition_rear_left INT CHECK (condition_rear_left >= 0 AND condition_rear_left <= 100),
    condition_rear_right INT CHECK (condition_rear_right >= 0 AND condition_rear_right <= 100),

    -- Pattern usura
    wear_pattern VARCHAR(50),     -- 'uniform', 'center_wear', 'edge_wear', 'patchy_wear'
    wear_severity VARCHAR(50),    -- 'minimal', 'moderate', 'significant', 'severe', 'critical'

    -- Note e osservazioni
    notes TEXT,
    technician_name VARCHAR(100),

    -- Geolocalizzazione
    location_latitude DECIMAL(10,8),
    location_longitude DECIMAL(11,8),
    location_address VARCHAR(500),

    -- Metadati
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (tyre_id) REFERENCES tyres_vehicles(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE,

    INDEX idx_analyses_tyre (tyre_id),
    INDEX idx_analyses_user (user_id),
    INDEX idx_analyses_vehicle (vehicle_id),
    INDEX idx_analyses_date (analysis_date DESC),

    CONSTRAINT check_depth_values CHECK (
        depth_front_left >= 0 AND depth_front_left <= 15 AND
        depth_front_right >= 0 AND depth_front_right <= 15 AND
        depth_rear_left >= 0 AND depth_rear_left <= 15 AND
        depth_rear_right >= 0 AND depth_rear_right <= 15
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- 5. TABELLA: tread_depth_measurements
-- Misurazioni dettagliate punto per punto
-- ============================================================================

CREATE TABLE IF NOT EXISTS tread_depth_measurements (
    id VARCHAR(36) PRIMARY KEY,  -- UUID
    analysis_id VARCHAR(36) NOT NULL,

    -- Posizione pneumatico
    tyre_position VARCHAR(10) NOT NULL,  -- 'FL', 'FR', 'RL', 'RR'

    -- Coordinate misurazione (normalizzate 0-1)
    measurement_x DECIMAL(5,4),
    measurement_y DECIMAL(5,4),

    -- Zona
    zone VARCHAR(50),  -- 'center', 'inner_edge', 'outer_edge', 'shoulder'

    -- Misurazione
    depth_mm DECIMAL(4,2) NOT NULL,
    confidence DECIMAL(3,2),  -- 0-1
    measurement_method VARCHAR(50),  -- 'manual', 'ai_vision', 'calibrated_tool'

    -- Metadati
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (analysis_id) REFERENCES tyre_analyses(id) ON DELETE CASCADE,

    INDEX idx_measurements_analysis (analysis_id),
    INDEX idx_measurements_position (tyre_position),

    CONSTRAINT check_position CHECK (tyre_position IN ('FL', 'FR', 'RL', 'RR')),
    CONSTRAINT check_depth CHECK (depth_mm >= 0 AND depth_mm <= 15),
    CONSTRAINT check_confidence CHECK (confidence >= 0 AND confidence <= 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- 6. TABELLA: tyre_lifecycle_projections
-- Proiezioni future e storiche
-- ============================================================================

CREATE TABLE IF NOT EXISTS tyre_lifecycle_projections (
    id VARCHAR(36) PRIMARY KEY,  -- UUID
    analysis_id VARCHAR(36) NOT NULL,

    -- Proiezione
    kilometers_from_now INT NOT NULL,  -- Negativo = storico, positivo = futuro
    projected_depth DECIMAL(4,2) NOT NULL,
    confidence DECIMAL(3,2),  -- 0-1
    is_projected BOOLEAN DEFAULT TRUE,

    -- Metadati
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (analysis_id) REFERENCES tyre_analyses(id) ON DELETE CASCADE,

    INDEX idx_projections_analysis (analysis_id),
    INDEX idx_projections_km (kilometers_from_now),

    CONSTRAINT check_projected_depth CHECK (projected_depth >= 0 AND projected_depth <= 15)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- 7. TABELLA: tyre_recommendations
-- Raccomandazioni manutenzione
-- ============================================================================

CREATE TABLE IF NOT EXISTS tyre_recommendations (
    id VARCHAR(36) PRIMARY KEY,  -- UUID
    analysis_id VARCHAR(36) NOT NULL,

    -- Tipo e priorità
    priority VARCHAR(20) NOT NULL,  -- 'critical', 'high', 'medium', 'low'
    category VARCHAR(50) NOT NULL,  -- 'safety', 'maintenance', 'performance', 'cost', 'legal'
    urgency VARCHAR(50) NOT NULL,   -- 'immediate', 'within_week', 'within_month', 'routine'

    -- Contenuto
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    action_required TEXT NOT NULL,

    -- Stato
    status VARCHAR(20) DEFAULT 'pending',  -- 'pending', 'acknowledged', 'completed', 'dismissed'
    completed_at TIMESTAMP NULL,

    -- Metadati
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (analysis_id) REFERENCES tyre_analyses(id) ON DELETE CASCADE,

    INDEX idx_recommendations_analysis (analysis_id),
    INDEX idx_recommendations_priority (priority),
    INDEX idx_recommendations_status (status),

    CONSTRAINT check_priority CHECK (priority IN ('critical', 'high', 'medium', 'low')),
    CONSTRAINT check_status CHECK (status IN ('pending', 'acknowledged', 'completed', 'dismissed'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- 8. TABELLA: image_uploads
-- Immagini associate alle analisi
-- ============================================================================

CREATE TABLE IF NOT EXISTS image_uploads (
    id VARCHAR(36) PRIMARY KEY,  -- UUID
    analysis_id VARCHAR(36) NOT NULL,

    -- Dati immagine
    filename VARCHAR(255) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    file_url VARCHAR(500),
    file_size INT,  -- bytes
    mime_type VARCHAR(100),

    -- Tipo immagine
    image_type VARCHAR(50),  -- 'tread_scan', 'sidewall', 'general', 'damage'

    -- Metadati
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (analysis_id) REFERENCES tyre_analyses(id) ON DELETE CASCADE,

    INDEX idx_images_analysis (analysis_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- 9. VISTE
-- ============================================================================

-- Vista: ultima analisi per ogni pneumatico
CREATE OR REPLACE VIEW latest_tyre_analyses AS
SELECT ta.*
FROM tyre_analyses ta
INNER JOIN (
    SELECT tyre_id, MAX(analysis_date) as max_date
    FROM tyre_analyses
    GROUP BY tyre_id
) latest ON ta.tyre_id = latest.tyre_id AND ta.analysis_date = latest.max_date;

-- Vista: statistiche utente
CREATE OR REPLACE VIEW user_analysis_stats AS
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
CREATE OR REPLACE VIEW critical_tyre_analyses AS
SELECT ta.*, tv.brand as tyre_brand, tv.model as tyre_model
FROM tyre_analyses ta
JOIN tyres_vehicles tv ON ta.tyre_id = tv.id
WHERE ta.wear_severity IN ('severe', 'critical')
   OR ta.depth_minimum < 2.0
ORDER BY ta.analysis_date DESC;

-- ============================================================================
-- 10. TRIGGER per auto-update timestamp
-- ============================================================================

DELIMITER //

-- Trigger per tyre_analyses
CREATE TRIGGER tyre_analyses_update_timestamp
BEFORE UPDATE ON tyre_analyses
FOR EACH ROW
BEGIN
    SET NEW.updated_at = CURRENT_TIMESTAMP;
END//

-- Trigger per tyre_recommendations
CREATE TRIGGER tyre_recommendations_update_timestamp
BEFORE UPDATE ON tyre_recommendations
FOR EACH ROW
BEGIN
    SET NEW.updated_at = CURRENT_TIMESTAMP;
END//

-- Trigger per vehicles
CREATE TRIGGER vehicles_update_timestamp
BEFORE UPDATE ON vehicles
FOR EACH ROW
BEGIN
    SET NEW.updated_at = CURRENT_TIMESTAMP;
END//

-- Trigger per completed_maintenance
CREATE TRIGGER completed_maintenance_update_timestamp
BEFORE UPDATE ON completed_maintenance
FOR EACH ROW
BEGIN
    SET NEW.updated_at = CURRENT_TIMESTAMP;
END//

-- Trigger per users
CREATE TRIGGER users_update_timestamp
BEFORE UPDATE ON users
FOR EACH ROW
BEGIN
    SET NEW.updated_at = CURRENT_TIMESTAMP;
END//

DELIMITER ;

-- ============================================================================
-- 11. STORED PROCEDURES
-- ============================================================================

DELIMITER //

-- Procedura: Ottieni ultima analisi per pneumatico
CREATE PROCEDURE GetLatestAnalysis(IN p_tyre_id INT)
BEGIN
    SELECT *
    FROM tyre_analyses
    WHERE tyre_id = p_tyre_id
    ORDER BY analysis_date DESC
    LIMIT 1;
END//

-- Procedura: Statistiche veicolo
CREATE PROCEDURE GetVehicleStats(IN p_vehicle_id INT)
BEGIN
    SELECT
        v.brand,
        v.model,
        COUNT(DISTINCT ta.id) as total_analyses,
        AVG(ta.depth_average) as avg_depth,
        MIN(ta.depth_minimum) as min_depth,
        COUNT(DISTINCT CASE WHEN ta.wear_severity IN ('severe', 'critical') THEN ta.id END) as critical_tyres
    FROM vehicles v
    LEFT JOIN tyre_analyses ta ON v.id = ta.vehicle_id
    WHERE v.id = p_vehicle_id
    GROUP BY v.id, v.brand, v.model;
END//

-- Procedura: Elimina analisi vecchie (data retention)
CREATE PROCEDURE CleanupOldAnalyses(IN days_to_keep INT)
BEGIN
    DELETE FROM tyre_analyses
    WHERE analysis_date < DATE_SUB(CURRENT_DATE, INTERVAL days_to_keep DAY);

    SELECT ROW_COUNT() as deleted_count;
END//

DELIMITER ;

-- ============================================================================
-- 12. INDICI FULL-TEXT per ricerca
-- ============================================================================

ALTER TABLE tyre_analyses
ADD FULLTEXT INDEX idx_notes_fulltext (notes);

ALTER TABLE tyre_recommendations
ADD FULLTEXT INDEX idx_recommendation_fulltext (title, description);

-- ============================================================================
-- 13. DATI DI ESEMPIO (opzionale - commentato)
-- ============================================================================

/*
-- Utente di test
INSERT INTO users (id, email, full_name, is_active) VALUES
('550e8400-e29b-41d4-a716-446655440000', 'test@tyrevibes.com', 'Test User', TRUE);

-- Veicolo di test
INSERT INTO vehicles (user_id, brand, model, year, plate_number) VALUES
('550e8400-e29b-41d4-a716-446655440000', 'Tesla', 'Model 3', 2022, 'AB123CD');

-- Pneumatico di test
INSERT INTO tyres_vehicles (vehicle_id, brand, model, size, dot, season) VALUES
(1, 'Michelin', 'Pilot Sport 4', '225/40R18', '1221', 'Summer');
*/

-- ============================================================================
-- FINE SCHEMA
-- ============================================================================

-- Verifica installazione
SELECT 'Schema created successfully!' as status;
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME LIKE 'tyre%'
ORDER BY TABLE_NAME;
