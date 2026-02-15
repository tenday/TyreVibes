-- Setup Database per Background Jobs TyreVibes
-- Autore: Claude Code
-- Descrizione: Crea tabelle e indici necessari per i background jobs

-- Abilita estensioni necessarie
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS http WITH SCHEMA extensions;

-- ==================================
-- TABELLE PER STATO BOLLO
-- ==================================

-- Tabella per tracciare lo stato del bollo auto
CREATE TABLE IF NOT EXISTS bollo_status (
    id BIGSERIAL PRIMARY KEY,
    vehicle_id BIGINT NOT NULL,
    plate_id BIGINT,
    expiry_date TIMESTAMP WITH TIME ZONE,
    amount DECIMAL(10,2),
    is_paid BOOLEAN DEFAULT false,
    payment_date TIMESTAMP WITH TIME ZONE,
    last_checked TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(vehicle_id)
);

-- Commenti per documentazione
COMMENT ON TABLE bollo_status IS 'Stato del pagamento del bollo auto per ogni veicolo';
COMMENT ON COLUMN bollo_status.vehicle_id IS 'ID del veicolo';
COMMENT ON COLUMN bollo_status.expiry_date IS 'Data di scadenza del bollo';
COMMENT ON COLUMN bollo_status.amount IS 'Importo del bollo in euro';
COMMENT ON COLUMN bollo_status.is_paid IS 'Indica se il bollo è stato pagato';
COMMENT ON COLUMN bollo_status.last_checked IS 'Ultima verifica dello stato';

-- ==================================
-- TABELLE PER STATO REVISIONI
-- ==================================

-- Tabella per tracciare lo stato delle revisioni periodiche
CREATE TABLE IF NOT EXISTS revision_status (
    id BIGSERIAL PRIMARY KEY,
    vehicle_id BIGINT NOT NULL,
    plate_id BIGINT,
    last_revision_date TIMESTAMP WITH TIME ZONE,
    next_revision_date TIMESTAMP WITH TIME ZONE,
    last_revision_km VARCHAR(50),
    is_expired BOOLEAN DEFAULT false,
    last_checked TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(vehicle_id)
);

-- Commenti per documentazione
COMMENT ON TABLE revision_status IS 'Stato delle revisioni periodiche per ogni veicolo';
COMMENT ON COLUMN revision_status.vehicle_id IS 'ID del veicolo';
COMMENT ON COLUMN revision_status.last_revision_date IS 'Data dell\'ultima revisione effettuata';
COMMENT ON COLUMN revision_status.next_revision_date IS 'Data della prossima revisione prevista';
COMMENT ON COLUMN revision_status.last_revision_km IS 'Chilometraggio all\'ultima revisione';
COMMENT ON COLUMN revision_status.is_expired IS 'Indica se la revisione è scaduta';

-- ==================================
-- INDICI PER PERFORMANCE
-- ==================================

-- Indici per bollo_status
CREATE INDEX IF NOT EXISTS idx_bollo_status_vehicle_id ON bollo_status(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_bollo_status_expiry_date ON bollo_status(expiry_date);
CREATE INDEX IF NOT EXISTS idx_bollo_status_is_paid ON bollo_status(is_paid);
CREATE INDEX IF NOT EXISTS idx_bollo_status_last_checked ON bollo_status(last_checked);

-- Indici per revision_status
CREATE INDEX IF NOT EXISTS idx_revision_status_vehicle_id ON revision_status(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_revision_status_next_revision ON revision_status(next_revision_date);
CREATE INDEX IF NOT EXISTS idx_revision_status_is_expired ON revision_status(is_expired);
CREATE INDEX IF NOT EXISTS idx_revision_status_last_checked ON revision_status(last_checked);

-- ==================================
-- TRIGGER PER UPDATED_AT AUTOMATICO
-- ==================================

-- Funzione per aggiornare updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger per bollo_status
DROP TRIGGER IF EXISTS update_bollo_status_updated_at ON bollo_status;
CREATE TRIGGER update_bollo_status_updated_at
    BEFORE UPDATE ON bollo_status
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger per revision_status
DROP TRIGGER IF EXISTS update_revision_status_updated_at ON revision_status;
CREATE TRIGGER update_revision_status_updated_at
    BEFORE UPDATE ON revision_status
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ==================================
-- CONFIGURAZIONE CRON JOBS
-- ==================================

-- Rimuovi job esistenti se presenti
SELECT cron.unschedule('run-all-background-jobs') WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'run-all-background-jobs'
);
SELECT cron.unschedule('update-insurance-expiry-job') WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'update-insurance-expiry-job'
);
SELECT cron.unschedule('update-bollo-status-job') WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'update-bollo-status-job'
);
SELECT cron.unschedule('update-revision-status-job') WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'update-revision-status-job'
);

-- Job principale che esegue tutti gli aggiornamenti alle 07:00 ogni giorno
SELECT cron.schedule(
    'run-all-background-jobs',
    '0 7 * * *',  -- Ogni giorno alle 07:00 ora italiana
    $$
    SELECT
        extensions.http_post(
            url := 'https://jbcbrnegmqraivdfmlsn.supabase.co/functions/v1/run-all-jobs',
            headers := '{"Content-Type": "application/json", "Authorization": "Bearer YOUR_SUPABASE_ANON_KEY"}'::jsonb,
            body := '{}'::jsonb
        ) AS request_id;
    $$
);

-- NOTA: Sostituisci YOUR_SUPABASE_ANON_KEY con la chiave effettiva

-- ==================================
-- ROW LEVEL SECURITY (RLS)
-- ==================================

-- Abilita RLS sulle tabelle
ALTER TABLE bollo_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE revision_status ENABLE ROW LEVEL SECURITY;

-- Policy per bollo_status - gli utenti possono vedere solo i propri dati
DROP POLICY IF EXISTS bollo_status_select_policy ON bollo_status;
CREATE POLICY bollo_status_select_policy ON bollo_status
    FOR SELECT
    USING (
        vehicle_id IN (
            SELECT v.id FROM vehicles v
            INNER JOIN plates p ON p.id = v.plate_id
            WHERE p.user_id = auth.uid()
        )
    );

-- Policy per revision_status - gli utenti possono vedere solo i propri dati
DROP POLICY IF EXISTS revision_status_select_policy ON revision_status;
CREATE POLICY revision_status_select_policy ON revision_status
    FOR SELECT
    USING (
        vehicle_id IN (
            SELECT v.id FROM vehicles v
            INNER JOIN plates p ON p.id = v.plate_id
            WHERE p.user_id = auth.uid()
        )
    );

-- Policy per permettere agli Edge Functions di scrivere (service role)
DROP POLICY IF EXISTS bollo_status_service_policy ON bollo_status;
CREATE POLICY bollo_status_service_policy ON bollo_status
    FOR ALL
    USING (auth.jwt() ->> 'role' = 'service_role')
    WITH CHECK (auth.jwt() ->> 'role' = 'service_role');

DROP POLICY IF EXISTS revision_status_service_policy ON revision_status;
CREATE POLICY revision_status_service_policy ON revision_status
    FOR ALL
    USING (auth.jwt() ->> 'role' = 'service_role')
    WITH CHECK (auth.jwt() ->> 'role' = 'service_role');

-- ==================================
-- VISTE PER REPORT E ANALYTICS
-- ==================================

-- Vista per veicoli con scadenze imminenti
CREATE OR REPLACE VIEW upcoming_expirations AS
SELECT
    v.id as vehicle_id,
    v.make,
    v.model,
    p.plate,
    p.user_id,
    CASE
        WHEN bs.expiry_date IS NOT NULL
             AND bs.expiry_date <= NOW() + INTERVAL '30 days'
             AND NOT bs.is_paid
        THEN 'bollo'
        WHEN rs.next_revision_date IS NOT NULL
             AND rs.next_revision_date <= NOW() + INTERVAL '30 days'
        THEN 'revisione'
        WHEN vi.rca_expiry IS NOT NULL
             AND vi.rca_expiry::timestamp <= NOW() + INTERVAL '30 days'
        THEN 'assicurazione'
    END as expiration_type,
    COALESCE(bs.expiry_date, rs.next_revision_date, vi.rca_expiry::timestamp) as expiry_date,
    EXTRACT(DAY FROM COALESCE(bs.expiry_date, rs.next_revision_date, vi.rca_expiry::timestamp) - NOW()) as days_until_expiry
FROM vehicles v
INNER JOIN plates p ON p.id = v.plate_id
LEFT JOIN bollo_status bs ON bs.vehicle_id = v.id
LEFT JOIN revision_status rs ON rs.vehicle_id = v.id
LEFT JOIN vehicle_insurances vi ON vi.plate_id = p.id
WHERE
    (bs.expiry_date IS NOT NULL AND bs.expiry_date <= NOW() + INTERVAL '30 days' AND NOT bs.is_paid)
    OR (rs.next_revision_date IS NOT NULL AND rs.next_revision_date <= NOW() + INTERVAL '30 days')
    OR (vi.rca_expiry IS NOT NULL AND vi.rca_expiry::timestamp <= NOW() + INTERVAL '30 days')
ORDER BY expiry_date ASC;

COMMENT ON VIEW upcoming_expirations IS 'Vista delle scadenze imminenti (prossimi 30 giorni) per bollo, revisioni e assicurazioni';

-- ==================================
-- GRANT PERMISSIONS
-- ==================================

-- Grant necessari per le funzioni
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO authenticated;

-- ==================================
-- STATISTICHE E MONITORAGGIO
-- ==================================

-- Tabella per tracciare l'esecuzione dei job
CREATE TABLE IF NOT EXISTS job_execution_log (
    id BIGSERIAL PRIMARY KEY,
    job_name VARCHAR(255) NOT NULL,
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(50),
    records_processed INTEGER,
    notifications_sent INTEGER,
    error_message TEXT,
    execution_time_ms INTEGER
);

CREATE INDEX IF NOT EXISTS idx_job_log_job_name ON job_execution_log(job_name);
CREATE INDEX IF NOT EXISTS idx_job_log_started_at ON job_execution_log(started_at);

COMMENT ON TABLE job_execution_log IS 'Log delle esecuzioni dei background jobs per monitoraggio';

-- ==================================
-- COMPLETION
-- ==================================

SELECT 'Database setup completato con successo! ✅' as message;
SELECT 'Tabelle create: bollo_status, revision_status, job_execution_log' as tables;
SELECT 'Viste create: upcoming_expirations' as views;
SELECT 'Cron jobs schedulati: run-all-background-jobs' as cron_jobs;
SELECT 'RICORDA: Sostituisci YOUR_SUPABASE_ANON_KEY nel job cron!' as reminder;
