-- ============================================
-- AGGIORNAMENTO: Notifiche Giornaliere e Auto-Refresh
-- ============================================
--
-- NUOVE FUNZIONALITÀ:
-- 1. Tracking notifiche giornaliere per scadenze
-- 2. Auto-refresh dati tramite license plate reader
-- 3. Stop notifiche solo al rinnovo effettivo
-- ============================================

-- ==================================
-- TABELLA PER TRACKING NOTIFICHE
-- ==================================

-- Traccia quando è stata inviata l'ultima notifica per ogni scadenza
CREATE TABLE IF NOT EXISTS notification_tracking (
    id BIGSERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    vehicle_id BIGINT NOT NULL,
    plate TEXT NOT NULL,
    notification_type VARCHAR(50) NOT NULL, -- 'insurance', 'bollo', 'revision'
    last_notification_date TIMESTAMP WITH TIME ZONE NOT NULL,
    notification_count INTEGER DEFAULT 1,
    expiry_date TIMESTAMP WITH TIME ZONE,
    is_resolved BOOLEAN DEFAULT false, -- true quando rinnovato
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(vehicle_id, notification_type)
);

CREATE INDEX IF NOT EXISTS idx_notification_tracking_user_id ON notification_tracking(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_tracking_vehicle_id ON notification_tracking(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_notification_tracking_type ON notification_tracking(notification_type);
CREATE INDEX IF NOT EXISTS idx_notification_tracking_last_date ON notification_tracking(last_notification_date);
CREATE INDEX IF NOT EXISTS idx_notification_tracking_resolved ON notification_tracking(is_resolved);

COMMENT ON TABLE notification_tracking IS 'Traccia le notifiche giornaliere inviate per ogni scadenza';
COMMENT ON COLUMN notification_tracking.notification_type IS 'Tipo: insurance, bollo, revision';
COMMENT ON COLUMN notification_tracking.last_notification_date IS 'Data ultima notifica inviata';
COMMENT ON COLUMN notification_tracking.notification_count IS 'Numero totale di notifiche inviate';
COMMENT ON COLUMN notification_tracking.is_resolved IS 'true quando l\'utente ha rinnovato';

-- ==================================
-- TABELLA PER AUTO-REFRESH LOG
-- ==================================

-- Traccia i refresh automatici dei dati tramite license plate reader
CREATE TABLE IF NOT EXISTS auto_refresh_log (
    id BIGSERIAL PRIMARY KEY,
    vehicle_id BIGINT NOT NULL,
    plate TEXT NOT NULL,
    refresh_type VARCHAR(50) NOT NULL, -- 'insurance_expired', 'bollo_expired', 'revision_expired'
    refresh_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    success BOOLEAN DEFAULT false,
    error_message TEXT,
    data_updated BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_auto_refresh_vehicle_id ON auto_refresh_log(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_auto_refresh_date ON auto_refresh_log(refresh_date);
CREATE INDEX IF NOT EXISTS idx_auto_refresh_type ON auto_refresh_log(refresh_type);

COMMENT ON TABLE auto_refresh_log IS 'Log dei refresh automatici tramite license plate reader';

-- ==================================
-- TRIGGER PER UPDATED_AT
-- ==================================

DROP TRIGGER IF EXISTS update_notification_tracking_updated_at ON notification_tracking;
CREATE TRIGGER update_notification_tracking_updated_at
    BEFORE UPDATE ON notification_tracking
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ==================================
-- FUNZIONE HELPER: Deve Notificare Oggi?
-- ==================================

-- Determina se deve essere inviata una notifica oggi
CREATE OR REPLACE FUNCTION should_notify_today(
    p_vehicle_id BIGINT,
    p_notification_type VARCHAR(50),
    p_expiry_date TIMESTAMP WITH TIME ZONE
) RETURNS BOOLEAN AS $$
DECLARE
    v_last_notification TIMESTAMP WITH TIME ZONE;
    v_is_resolved BOOLEAN;
    v_days_since_last INT;
BEGIN
    -- Recupera info ultima notifica
    SELECT last_notification_date, is_resolved
    INTO v_last_notification, v_is_resolved
    FROM notification_tracking
    WHERE vehicle_id = p_vehicle_id
      AND notification_type = p_notification_type;

    -- Se non esiste record, notifica subito
    IF v_last_notification IS NULL THEN
        RETURN TRUE;
    END IF;

    -- Se già risolto, non notificare
    IF v_is_resolved THEN
        RETURN FALSE;
    END IF;

    -- Calcola giorni dall'ultima notifica
    v_days_since_last := EXTRACT(DAY FROM NOW() - v_last_notification);

    -- Notifica se è passato almeno 1 giorno E la scadenza è imminente/scaduta
    IF v_days_since_last >= 1 AND p_expiry_date <= NOW() + INTERVAL '30 days' THEN
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION should_notify_today IS 'Determina se inviare notifica giornaliera per una scadenza';

-- ==================================
-- FUNZIONE HELPER: Registra Notifica
-- ==================================

-- Registra l'invio di una notifica
CREATE OR REPLACE FUNCTION track_notification(
    p_user_id TEXT,
    p_vehicle_id BIGINT,
    p_plate TEXT,
    p_notification_type VARCHAR(50),
    p_expiry_date TIMESTAMP WITH TIME ZONE
) RETURNS VOID AS $$
BEGIN
    INSERT INTO notification_tracking (
        user_id,
        vehicle_id,
        plate,
        notification_type,
        last_notification_date,
        notification_count,
        expiry_date,
        is_resolved
    ) VALUES (
        p_user_id,
        p_vehicle_id,
        p_plate,
        p_notification_type,
        NOW(),
        1,
        p_expiry_date,
        false
    )
    ON CONFLICT (vehicle_id, notification_type)
    DO UPDATE SET
        last_notification_date = NOW(),
        notification_count = notification_tracking.notification_count + 1,
        expiry_date = p_expiry_date,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION track_notification IS 'Registra l\'invio di una notifica giornaliera';

-- ==================================
-- FUNZIONE HELPER: Marca Come Risolto
-- ==================================

-- Marca una scadenza come risolta (rinnovata)
CREATE OR REPLACE FUNCTION mark_notification_resolved(
    p_vehicle_id BIGINT,
    p_notification_type VARCHAR(50)
) RETURNS VOID AS $$
BEGIN
    UPDATE notification_tracking
    SET is_resolved = true,
        updated_at = NOW()
    WHERE vehicle_id = p_vehicle_id
      AND notification_type = p_notification_type;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION mark_notification_resolved IS 'Marca scadenza come risolta - stop notifiche';

-- ==================================
-- VISTA: Scadenze che Richiedono Notifica Oggi
-- ==================================

CREATE OR REPLACE VIEW daily_notifications_due AS
SELECT
    v.id as vehicle_id,
    v.make,
    v.model,
    v.plate,
    v.user_id,
    'insurance' as notification_type,
    vi.rca_expiry::timestamp as expiry_date,
    EXTRACT(DAY FROM vi.rca_expiry::timestamp - NOW()) as days_until_expiry,
    nt.notification_count,
    nt.last_notification_date
FROM vehicles v
INNER JOIN vehicle_insurances vi ON vi.plate_id = v.id
LEFT JOIN notification_tracking nt ON nt.vehicle_id = v.id AND nt.notification_type = 'insurance'
WHERE vi.rca_expiry IS NOT NULL
  AND vi.rca_expiry::timestamp <= NOW() + INTERVAL '30 days'
  AND should_notify_today(v.id, 'insurance', vi.rca_expiry::timestamp)
  AND (nt.is_resolved IS NULL OR nt.is_resolved = false)

UNION ALL

SELECT
    v.id as vehicle_id,
    v.make,
    v.model,
    v.plate,
    v.user_id,
    'bollo' as notification_type,
    bs.expiry_date,
    EXTRACT(DAY FROM bs.expiry_date - NOW()) as days_until_expiry,
    nt.notification_count,
    nt.last_notification_date
FROM vehicles v
INNER JOIN bollo_status bs ON bs.vehicle_id = v.id
LEFT JOIN notification_tracking nt ON nt.vehicle_id = v.id AND nt.notification_type = 'bollo'
WHERE bs.expiry_date IS NOT NULL
  AND bs.expiry_date <= NOW() + INTERVAL '30 days'
  AND NOT bs.is_paid
  AND should_notify_today(v.id, 'bollo', bs.expiry_date)
  AND (nt.is_resolved IS NULL OR nt.is_resolved = false)

UNION ALL

SELECT
    v.id as vehicle_id,
    v.make,
    v.model,
    v.plate,
    v.user_id,
    'revision' as notification_type,
    rs.next_revision_date,
    EXTRACT(DAY FROM rs.next_revision_date - NOW()) as days_until_expiry,
    nt.notification_count,
    nt.last_notification_date
FROM vehicles v
INNER JOIN revision_status rs ON rs.vehicle_id = v.id
LEFT JOIN notification_tracking nt ON nt.vehicle_id = v.id AND nt.notification_type = 'revision'
WHERE rs.next_revision_date IS NOT NULL
  AND rs.next_revision_date <= NOW() + INTERVAL '30 days'
  AND should_notify_today(v.id, 'revision', rs.next_revision_date)
  AND (nt.is_resolved IS NULL OR nt.is_resolved = false);

COMMENT ON VIEW daily_notifications_due IS 'Scadenze che richiedono notifica oggi';

-- ==================================
-- ROW LEVEL SECURITY
-- ==================================

ALTER TABLE notification_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE auto_refresh_log ENABLE ROW LEVEL SECURITY;

-- Policy per notification_tracking
DROP POLICY IF EXISTS notification_tracking_select_policy ON notification_tracking;
CREATE POLICY notification_tracking_select_policy ON notification_tracking
    FOR SELECT
    USING (user_id::text = auth.uid()::text);

DROP POLICY IF EXISTS notification_tracking_service_policy ON notification_tracking;
CREATE POLICY notification_tracking_service_policy ON notification_tracking
    FOR ALL
    USING (auth.jwt() ->> 'role' = 'service_role')
    WITH CHECK (auth.jwt() ->> 'role' = 'service_role');

-- Policy per auto_refresh_log (solo service role può scrivere)
DROP POLICY IF EXISTS auto_refresh_log_service_policy ON auto_refresh_log;
CREATE POLICY auto_refresh_log_service_policy ON auto_refresh_log
    FOR ALL
    USING (auth.jwt() ->> 'role' = 'service_role')
    WITH CHECK (auth.jwt() ->> 'role' = 'service_role');

-- ==================================
-- GRANT PERMISSIONS
-- ==================================

GRANT SELECT ON notification_tracking TO authenticated;
GRANT SELECT ON auto_refresh_log TO authenticated;
GRANT SELECT ON daily_notifications_due TO authenticated;

-- ==================================
-- VERIFICA
-- ==================================

SELECT
    '✅ Aggiornamento completato!' as message,
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_name IN ('notification_tracking', 'auto_refresh_log')) as new_tables_created;

-- Test query
SELECT * FROM daily_notifications_due LIMIT 5;

-- ============================================
-- PROSSIMI PASSI:
-- 1. Aggiorna le Edge Functions con nuova logica
-- 2. Testa notifiche giornaliere
-- 3. Verifica auto-refresh dati
-- ============================================
