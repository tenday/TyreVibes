-- Migration: Add Tyre Analysis Tables
-- Created: 2025-11-17
-- Description: Tabelle per memorizzare le analisi dettagliate dei pneumatici

-- ============================================================================
-- 1. TABELLA: tyre_analyses
-- Memorizza le analisi complete dei pneumatici
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.tyre_analyses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tyre_id INTEGER NOT NULL REFERENCES public.tyres_vehicles(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    vehicle_id INTEGER NOT NULL,

    -- Metadata analisi
    analysis_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    analysis_type VARCHAR(50) DEFAULT 'manual', -- 'manual', 'ai_scan', 'automatic'

    -- Dati profondità battistrada (in mm)
    depth_front_left DECIMAL(4,2),
    depth_front_right DECIMAL(4,2),
    depth_rear_left DECIMAL(4,2),
    depth_rear_right DECIMAL(4,2),
    depth_average DECIMAL(4,2),
    depth_minimum DECIMAL(4,2),

    -- Vita rimanente
    remaining_life_percentage DECIMAL(5,2), -- 0-100
    remaining_life_km INTEGER,
    remaining_life_months INTEGER,
    confidence_score DECIMAL(3,2), -- 0-1

    -- Condizioni pneumatici (percentuale 0-100)
    condition_front_left INTEGER CHECK (condition_front_left >= 0 AND condition_front_left <= 100),
    condition_front_right INTEGER CHECK (condition_front_right >= 0 AND condition_front_right <= 100),
    condition_rear_left INTEGER CHECK (condition_rear_left >= 0 AND condition_rear_left <= 100),
    condition_rear_right INTEGER CHECK (condition_rear_right >= 0 AND condition_rear_right <= 100),

    -- Pattern di usura
    wear_pattern VARCHAR(50), -- 'uniform', 'center_wear', 'edge_wear', etc.
    wear_severity VARCHAR(50), -- 'minimal', 'moderate', 'significant', 'severe', 'critical'

    -- Note e osservazioni
    notes TEXT,
    technician_name VARCHAR(100),

    -- Geolocalizzazione (opzionale)
    location_latitude DECIMAL(10,8),
    location_longitude DECIMAL(11,8),
    location_address TEXT,

    -- Immagini associate (array di URL)
    image_urls TEXT[],

    -- Metadati
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Indici per performance
    CONSTRAINT valid_depth_values CHECK (
        depth_front_left >= 0 AND depth_front_left <= 15 AND
        depth_front_right >= 0 AND depth_front_right <= 15 AND
        depth_rear_left >= 0 AND depth_rear_left <= 15 AND
        depth_rear_right >= 0 AND depth_rear_right <= 15
    )
);

-- Indici per query veloci
CREATE INDEX idx_tyre_analyses_tyre_id ON public.tyre_analyses(tyre_id);
CREATE INDEX idx_tyre_analyses_user_id ON public.tyre_analyses(user_id);
CREATE INDEX idx_tyre_analyses_vehicle_id ON public.tyre_analyses(vehicle_id);
CREATE INDEX idx_tyre_analyses_date ON public.tyre_analyses(analysis_date DESC);

-- ============================================================================
-- 2. TABELLA: tread_depth_measurements
-- Memorizza misurazioni dettagliate punto per punto
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.tread_depth_measurements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    analysis_id UUID NOT NULL REFERENCES public.tyre_analyses(id) ON DELETE CASCADE,

    -- Posizione del pneumatico
    tyre_position VARCHAR(10) NOT NULL, -- 'FL', 'FR', 'RL', 'RR'

    -- Coordinate della misurazione (normalizzate 0-1)
    measurement_x DECIMAL(5,4), -- Posizione X sul pneumatico
    measurement_y DECIMAL(5,4), -- Posizione Y sul pneumatico

    -- Zona del pneumatico
    zone VARCHAR(50), -- 'center', 'inner_edge', 'outer_edge', 'shoulder'

    -- Profondità misurata
    depth_mm DECIMAL(4,2) NOT NULL,
    confidence DECIMAL(3,2), -- 0-1, confidenza della misurazione

    -- Metodo di misurazione
    measurement_method VARCHAR(50), -- 'manual', 'ai_vision', 'calibrated_tool'

    -- Timestamp
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Vincoli
    CONSTRAINT valid_tyre_position CHECK (tyre_position IN ('FL', 'FR', 'RL', 'RR')),
    CONSTRAINT valid_depth CHECK (depth_mm >= 0 AND depth_mm <= 15),
    CONSTRAINT valid_confidence CHECK (confidence >= 0 AND confidence <= 1)
);

-- Indici
CREATE INDEX idx_tread_measurements_analysis_id ON public.tread_depth_measurements(analysis_id);
CREATE INDEX idx_tread_measurements_position ON public.tread_depth_measurements(tyre_position);

-- ============================================================================
-- 3. TABELLA: tyre_lifecycle_projections
-- Memorizza proiezioni future della vita del pneumatico
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.tyre_lifecycle_projections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    analysis_id UUID NOT NULL REFERENCES public.tyre_analyses(id) ON DELETE CASCADE,

    -- Punto di proiezione
    kilometers_from_now INTEGER NOT NULL, -- Negativo per storico, positivo per futuro
    projected_depth DECIMAL(4,2) NOT NULL,
    confidence DECIMAL(3,2), -- 0-1

    -- Classificazione
    is_projected BOOLEAN DEFAULT true, -- false per dati storici

    -- Timestamp
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT valid_projected_depth CHECK (projected_depth >= 0 AND projected_depth <= 15)
);

-- Indici
CREATE INDEX idx_lifecycle_projections_analysis_id ON public.tyre_lifecycle_projections(analysis_id);
CREATE INDEX idx_lifecycle_projections_km ON public.tyre_lifecycle_projections(kilometers_from_now);

-- ============================================================================
-- 4. TABELLA: tyre_recommendations
-- Memorizza raccomandazioni per manutenzione
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.tyre_recommendations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    analysis_id UUID NOT NULL REFERENCES public.tyre_analyses(id) ON DELETE CASCADE,

    -- Tipo e priorità
    priority VARCHAR(20) NOT NULL, -- 'critical', 'high', 'medium', 'low'
    category VARCHAR(50) NOT NULL, -- 'safety', 'maintenance', 'performance', 'cost', 'legal'
    urgency VARCHAR(50) NOT NULL, -- 'immediate', 'within_week', 'within_month', 'routine'

    -- Contenuto
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    action_required TEXT NOT NULL,

    -- Stato
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'acknowledged', 'completed', 'dismissed'
    completed_at TIMESTAMP WITH TIME ZONE,

    -- Metadati
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT valid_priority CHECK (priority IN ('critical', 'high', 'medium', 'low')),
    CONSTRAINT valid_status CHECK (status IN ('pending', 'acknowledged', 'completed', 'dismissed'))
);

-- Indici
CREATE INDEX idx_recommendations_analysis_id ON public.tyre_recommendations(analysis_id);
CREATE INDEX idx_recommendations_priority ON public.tyre_recommendations(priority);
CREATE INDEX idx_recommendations_status ON public.tyre_recommendations(status);

-- ============================================================================
-- 5. ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Abilita RLS su tutte le tabelle
ALTER TABLE public.tyre_analyses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tread_depth_measurements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tyre_lifecycle_projections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tyre_recommendations ENABLE ROW LEVEL SECURITY;

-- Policy per tyre_analyses: gli utenti vedono solo le proprie analisi
CREATE POLICY "Users can view their own tyre analyses"
    ON public.tyre_analyses
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own tyre analyses"
    ON public.tyre_analyses
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own tyre analyses"
    ON public.tyre_analyses
    FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own tyre analyses"
    ON public.tyre_analyses
    FOR DELETE
    USING (auth.uid() = user_id);

-- Policy per tread_depth_measurements: accesso tramite analysis_id
CREATE POLICY "Users can view measurements of their analyses"
    ON public.tread_depth_measurements
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.tyre_analyses
            WHERE id = analysis_id AND user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert measurements for their analyses"
    ON public.tread_depth_measurements
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.tyre_analyses
            WHERE id = analysis_id AND user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete measurements of their analyses"
    ON public.tread_depth_measurements
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.tyre_analyses
            WHERE id = analysis_id AND user_id = auth.uid()
        )
    );

-- Policy per tyre_lifecycle_projections
CREATE POLICY "Users can view projections of their analyses"
    ON public.tyre_lifecycle_projections
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.tyre_analyses
            WHERE id = analysis_id AND user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert projections for their analyses"
    ON public.tyre_lifecycle_projections
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.tyre_analyses
            WHERE id = analysis_id AND user_id = auth.uid()
        )
    );

-- Policy per tyre_recommendations
CREATE POLICY "Users can view recommendations of their analyses"
    ON public.tyre_recommendations
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.tyre_analyses
            WHERE id = analysis_id AND user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert recommendations for their analyses"
    ON public.tyre_recommendations
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.tyre_analyses
            WHERE id = analysis_id AND user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update their recommendations"
    ON public.tyre_recommendations
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.tyre_analyses
            WHERE id = analysis_id AND user_id = auth.uid()
        )
    );

-- ============================================================================
-- 6. TRIGGERS per updated_at
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
DROP TRIGGER IF EXISTS update_tyre_analyses_updated_at ON public.tyre_analyses;
CREATE TRIGGER update_tyre_analyses_updated_at
    BEFORE UPDATE ON public.tyre_analyses
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger per tyre_recommendations
DROP TRIGGER IF EXISTS update_tyre_recommendations_updated_at ON public.tyre_recommendations;
CREATE TRIGGER update_tyre_recommendations_updated_at
    BEFORE UPDATE ON public.tyre_recommendations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- 7. VISTE UTILI
-- ============================================================================

-- Vista per ottenere l'ultima analisi per ogni pneumatico
CREATE OR REPLACE VIEW public.latest_tyre_analyses AS
SELECT DISTINCT ON (tyre_id)
    ta.*
FROM public.tyre_analyses ta
ORDER BY tyre_id, analysis_date DESC;

-- Vista per statistiche analisi per utente
CREATE OR REPLACE VIEW public.user_analysis_stats AS
SELECT
    user_id,
    COUNT(*) as total_analyses,
    COUNT(DISTINCT tyre_id) as tyres_analyzed,
    AVG(depth_average) as avg_depth,
    AVG(remaining_life_percentage) as avg_remaining_life,
    MAX(analysis_date) as last_analysis_date
FROM public.tyre_analyses
GROUP BY user_id;

-- ============================================================================
-- 8. COMMENTI SULLE TABELLE
-- ============================================================================

COMMENT ON TABLE public.tyre_analyses IS 'Analisi complete dei pneumatici con profondità battistrada e vita rimanente';
COMMENT ON TABLE public.tread_depth_measurements IS 'Misurazioni dettagliate punto per punto della profondità del battistrada';
COMMENT ON TABLE public.tyre_lifecycle_projections IS 'Proiezioni future e dati storici della vita del pneumatico';
COMMENT ON TABLE public.tyre_recommendations IS 'Raccomandazioni per manutenzione e sicurezza dei pneumatici';

-- ============================================================================
-- FINE MIGRATION
-- ============================================================================
