-- ============================================================================
-- TYREVIBES - Database Schema PostgreSQL
-- ============================================================================
-- Versione ottimizzata per PostgreSQL 12+
-- ============================================================================

-- Abilita estensione UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- 1. TABELLA: users
-- ============================================================================

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255),
    full_name VARCHAR(255),
    phone VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT TRUE,
    is_premium BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_active ON users(is_active);

-- ============================================================================
-- 2. TABELLA: vehicles
-- ============================================================================

CREATE TABLE IF NOT EXISTS vehicles (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    brand VARCHAR(100) NOT NULL,
    model VARCHAR(100) NOT NULL,
    year INTEGER,
    plate_number VARCHAR(20),
    vin VARCHAR(17),
    current_mileage INTEGER CHECK (current_mileage IS NULL OR current_mileage >= 0),

    insurance_expiry DATE,
    revision_expiry DATE,
    bollo_expiry DATE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_vehicles_user ON vehicles(user_id);
CREATE INDEX idx_vehicles_plate ON vehicles(plate_number);

-- ============================================================================
-- 3. TABELLA: completed_maintenance
-- ============================================================================

CREATE TABLE IF NOT EXISTS completed_maintenance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vehicle_id INTEGER NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,

    title VARCHAR(255) NOT NULL,
    note TEXT,
    maintenance_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    mileage INTEGER CHECK (mileage IS NULL OR mileage >= 0),
    source VARCHAR(20) NOT NULL DEFAULT 'manual' CHECK (source IN ('manual', 'partner', 'automatic')),
    partner_appointment_id VARCHAR(120),
    maintenance_type VARCHAR(50),              -- MaintenanceType raw value
    cost DECIMAL(10,2) CHECK (cost IS NULL OR cost >= 0),  -- Actual cost in EUR
    workshop_name VARCHAR(255),                -- Workshop/mechanic name
    workshop_id VARCHAR(120),                  -- Partner workshop ID

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_completed_maintenance_vehicle ON completed_maintenance(vehicle_id);
CREATE INDEX idx_completed_maintenance_date ON completed_maintenance(maintenance_date DESC);
CREATE INDEX idx_completed_maintenance_source ON completed_maintenance(source);
CREATE INDEX idx_completed_maintenance_type ON completed_maintenance(maintenance_type);
CREATE UNIQUE INDEX uq_completed_maintenance_partner_appointment
    ON completed_maintenance(vehicle_id, partner_appointment_id)
    WHERE partner_appointment_id IS NOT NULL;

-- ============================================================================
-- 3b. TABELLA: maintenance_intervals
-- ============================================================================

CREATE TABLE IF NOT EXISTS maintenance_intervals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vehicle_id INTEGER REFERENCES vehicles(id) ON DELETE CASCADE,
    maintenance_type VARCHAR(50) NOT NULL,
    km_interval INTEGER CHECK (km_interval IS NULL OR km_interval > 0),
    months_interval INTEGER CHECK (months_interval IS NULL OR months_interval > 0),
    is_custom BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_maintenance_intervals_vehicle ON maintenance_intervals(vehicle_id);
CREATE INDEX idx_maintenance_intervals_type ON maintenance_intervals(maintenance_type);

-- ============================================================================
-- 4. TABELLA: tyres_vehicles
-- ============================================================================

CREATE TABLE IF NOT EXISTS tyres_vehicles (
    id SERIAL PRIMARY KEY,
    vehicle_id INTEGER NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,

    brand VARCHAR(100) NOT NULL,
    model VARCHAR(100) NOT NULL,
    size VARCHAR(50) NOT NULL,
    dot VARCHAR(10) NOT NULL,
    load_index VARCHAR(10),
    speed_rating VARCHAR(5),
    season VARCHAR(20),

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_tyres_vehicle ON tyres_vehicles(vehicle_id);

-- ============================================================================
-- 5. TABELLA: tyre_analyses
-- ============================================================================

CREATE TABLE IF NOT EXISTS tyre_analyses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tyre_id INTEGER NOT NULL REFERENCES tyres_vehicles(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    vehicle_id INTEGER NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,

    analysis_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    analysis_type VARCHAR(50) DEFAULT 'manual',

    depth_front_left DECIMAL(4,2) CHECK (depth_front_left >= 0 AND depth_front_left <= 15),
    depth_front_right DECIMAL(4,2) CHECK (depth_front_right >= 0 AND depth_front_right <= 15),
    depth_rear_left DECIMAL(4,2) CHECK (depth_rear_left >= 0 AND depth_rear_left <= 15),
    depth_rear_right DECIMAL(4,2) CHECK (depth_rear_right >= 0 AND depth_rear_right <= 15),
    depth_average DECIMAL(4,2),
    depth_minimum DECIMAL(4,2),

    remaining_life_percentage DECIMAL(5,2),
    remaining_life_km INTEGER,
    remaining_life_months INTEGER,
    confidence_score DECIMAL(3,2) CHECK (confidence_score >= 0 AND confidence_score <= 1),

    condition_front_left INTEGER CHECK (condition_front_left >= 0 AND condition_front_left <= 100),
    condition_front_right INTEGER CHECK (condition_front_right >= 0 AND condition_front_right <= 100),
    condition_rear_left INTEGER CHECK (condition_rear_left >= 0 AND condition_rear_left <= 100),
    condition_rear_right INTEGER CHECK (condition_rear_right >= 0 AND condition_rear_right <= 100),

    wear_pattern VARCHAR(50),
    wear_severity VARCHAR(50),

    notes TEXT,
    technician_name VARCHAR(100),

    location_latitude DECIMAL(10,8),
    location_longitude DECIMAL(11,8),
    location_address TEXT,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_analyses_tyre ON tyre_analyses(tyre_id);
CREATE INDEX idx_analyses_user ON tyre_analyses(user_id);
CREATE INDEX idx_analyses_vehicle ON tyre_analyses(vehicle_id);
CREATE INDEX idx_analyses_date ON tyre_analyses(analysis_date DESC);

-- ============================================================================
-- 5. TABELLA: tread_depth_measurements
-- ============================================================================

CREATE TABLE IF NOT EXISTS tread_depth_measurements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    analysis_id UUID NOT NULL REFERENCES tyre_analyses(id) ON DELETE CASCADE,

    tyre_position VARCHAR(10) NOT NULL CHECK (tyre_position IN ('FL', 'FR', 'RL', 'RR')),
    measurement_x DECIMAL(5,4),
    measurement_y DECIMAL(5,4),
    zone VARCHAR(50),

    depth_mm DECIMAL(4,2) NOT NULL CHECK (depth_mm >= 0 AND depth_mm <= 15),
    confidence DECIMAL(3,2) CHECK (confidence >= 0 AND confidence <= 1),
    measurement_method VARCHAR(50),

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_measurements_analysis ON tread_depth_measurements(analysis_id);
CREATE INDEX idx_measurements_position ON tread_depth_measurements(tyre_position);

-- ============================================================================
-- 7. TABELLA: tyre_lifecycle_projections
-- ============================================================================

CREATE TABLE IF NOT EXISTS tyre_lifecycle_projections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    analysis_id UUID NOT NULL REFERENCES tyre_analyses(id) ON DELETE CASCADE,

    kilometers_from_now INTEGER NOT NULL,
    projected_depth DECIMAL(4,2) NOT NULL CHECK (projected_depth >= 0 AND projected_depth <= 15),
    confidence DECIMAL(3,2) CHECK (confidence >= 0 AND confidence <= 1),
    is_projected BOOLEAN DEFAULT TRUE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_projections_analysis ON tyre_lifecycle_projections(analysis_id);
CREATE INDEX idx_projections_km ON tyre_lifecycle_projections(kilometers_from_now);

-- ============================================================================
-- 8. TABELLA: tyre_recommendations
-- ============================================================================

CREATE TABLE IF NOT EXISTS tyre_recommendations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    analysis_id UUID NOT NULL REFERENCES tyre_analyses(id) ON DELETE CASCADE,

    priority VARCHAR(20) NOT NULL CHECK (priority IN ('critical', 'high', 'medium', 'low')),
    category VARCHAR(50) NOT NULL,
    urgency VARCHAR(50) NOT NULL,

    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    action_required TEXT NOT NULL,

    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'acknowledged', 'completed', 'dismissed')),
    completed_at TIMESTAMP WITH TIME ZONE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_recommendations_analysis ON tyre_recommendations(analysis_id);
CREATE INDEX idx_recommendations_priority ON tyre_recommendations(priority);
CREATE INDEX idx_recommendations_status ON tyre_recommendations(status);

-- ============================================================================
-- 8. TABELLA: image_uploads
-- ============================================================================

CREATE TABLE IF NOT EXISTS image_uploads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    analysis_id UUID NOT NULL REFERENCES tyre_analyses(id) ON DELETE CASCADE,

    filename VARCHAR(255) NOT NULL,
    file_path TEXT NOT NULL,
    file_url TEXT,
    file_size INTEGER,
    mime_type VARCHAR(100),
    image_type VARCHAR(50),

    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_images_analysis ON image_uploads(analysis_id);

-- ============================================================================
-- 9. FUNZIONI E TRIGGER
-- ============================================================================

-- Funzione per aggiornare updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger per tyre_analyses
CREATE TRIGGER tyre_analyses_update_timestamp
    BEFORE UPDATE ON tyre_analyses
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger per tyre_recommendations
CREATE TRIGGER tyre_recommendations_update_timestamp
    BEFORE UPDATE ON tyre_recommendations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger per vehicles
CREATE TRIGGER vehicles_update_timestamp
    BEFORE UPDATE ON vehicles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger per completed_maintenance
CREATE TRIGGER completed_maintenance_update_timestamp
    BEFORE UPDATE ON completed_maintenance
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger per users
CREATE TRIGGER users_update_timestamp
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- 10. VISTE
-- ============================================================================

CREATE OR REPLACE VIEW latest_tyre_analyses AS
SELECT DISTINCT ON (tyre_id)
    *
FROM tyre_analyses
ORDER BY tyre_id, analysis_date DESC;

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

CREATE OR REPLACE VIEW critical_tyre_analyses AS
SELECT ta.*, tv.brand as tyre_brand, tv.model as tyre_model
FROM tyre_analyses ta
JOIN tyres_vehicles tv ON ta.tyre_id = tv.id
WHERE ta.wear_severity IN ('severe', 'critical')
   OR ta.depth_minimum < 2.0
ORDER BY ta.analysis_date DESC;

-- ============================================================================
-- 11. INDICI FULL-TEXT (PostgreSQL tsquery)
-- ============================================================================

-- Crea indice GIN per ricerca full-text su note
CREATE INDEX idx_analyses_notes_fts ON tyre_analyses USING GIN(to_tsvector('italian', notes));

-- Crea indice GIN per raccomandazioni
CREATE INDEX idx_recommendations_fts ON tyre_recommendations
    USING GIN(to_tsvector('italian', title || ' ' || description));

-- ============================================================================
-- FINE SCHEMA PostgreSQL
-- ============================================================================
