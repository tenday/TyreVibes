-- ============================================
-- SETUP TABELLE PROFILO UTENTE
-- TyreVibes Profile Management System
-- ============================================
--
-- ISTRUZIONI:
-- 1. Vai su https://supabase.com/dashboard/project/jbcbrnegmqraivdfmlsn
-- 2. Clicca su "SQL Editor" nel menu laterale
-- 3. Copia TUTTO questo file e incollalo nell'editor
-- 4. Clicca "Run" (o CMD+Enter / CTRL+Enter)
-- 5. Verifica che tutto sia eseguito senza errori
-- ============================================

-- ==================================
-- AGGIORNA TABELLA USERS
-- ==================================

-- Aggiungi colonna per l'URL dell'immagine profilo se non esiste
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'users' AND column_name = 'profile_image_url'
    ) THEN
        ALTER TABLE users ADD COLUMN profile_image_url TEXT;
    END IF;
END $$;

COMMENT ON COLUMN users.profile_image_url IS 'URL dell''immagine profilo salvata su Supabase Storage';

-- ==================================
-- TABELLA PREFERENZE UTENTE
-- ==================================

CREATE TABLE IF NOT EXISTS user_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    email_notifications BOOLEAN DEFAULT true,
    product_updates BOOLEAN DEFAULT true,
    sms_notifications BOOLEAN DEFAULT false,
    security_alerts BOOLEAN DEFAULT true,
    marketing_emails BOOLEAN DEFAULT false,
    profile_visible BOOLEAN DEFAULT true,
    data_collection BOOLEAN DEFAULT true,
    activity_history BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id)
);

COMMENT ON TABLE user_preferences IS 'Preferenze di comunicazione e privacy per ogni utente';
COMMENT ON COLUMN user_preferences.user_id IS 'ID dell''utente (riferimento a auth.users)';
COMMENT ON COLUMN user_preferences.email_notifications IS 'Ricevi notifiche email';
COMMENT ON COLUMN user_preferences.product_updates IS 'Ricevi aggiornamenti prodotto';
COMMENT ON COLUMN user_preferences.sms_notifications IS 'Ricevi notifiche SMS';
COMMENT ON COLUMN user_preferences.security_alerts IS 'Ricevi avvisi di sicurezza';
COMMENT ON COLUMN user_preferences.marketing_emails IS 'Ricevi email di marketing';
COMMENT ON COLUMN user_preferences.profile_visible IS 'Profilo visibile ad altri utenti';
COMMENT ON COLUMN user_preferences.data_collection IS 'Permetti raccolta dati per migliorare il servizio';
COMMENT ON COLUMN user_preferences.activity_history IS 'Salva cronologia attività';

-- ==================================
-- TABELLA ATTIVITÀ UTENTE
-- ==================================

CREATE TABLE IF NOT EXISTS user_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    activity_type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    subtitle TEXT,
    icon VARCHAR(100),
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE user_activities IS 'Log delle attività utente per visualizzazione nel profilo';
COMMENT ON COLUMN user_activities.user_id IS 'ID dell''utente';
COMMENT ON COLUMN user_activities.activity_type IS 'Tipo di attività (login, settings_changed, password_changed, ecc.)';
COMMENT ON COLUMN user_activities.title IS 'Titolo dell''attività';
COMMENT ON COLUMN user_activities.subtitle IS 'Descrizione dettagliata dell''attività';
COMMENT ON COLUMN user_activities.icon IS 'Nome dell''icona SF Symbol da visualizzare';
COMMENT ON COLUMN user_activities.metadata IS 'Dati aggiuntivi in formato JSON';

-- ==================================
-- INDICI PER PERFORMANCE
-- ==================================

CREATE INDEX IF NOT EXISTS idx_user_preferences_user_id ON user_preferences(user_id);
CREATE INDEX IF NOT EXISTS idx_user_activities_user_id ON user_activities(user_id);
CREATE INDEX IF NOT EXISTS idx_user_activities_created_at ON user_activities(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_activities_type ON user_activities(activity_type);

-- ==================================
-- TRIGGER PER UPDATED_AT AUTOMATICO
-- ==================================

-- Trigger per user_preferences
DROP TRIGGER IF EXISTS update_user_preferences_updated_at ON user_preferences;
CREATE TRIGGER update_user_preferences_updated_at
    BEFORE UPDATE ON user_preferences
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ==================================
-- ROW LEVEL SECURITY (RLS)
-- ==================================

-- Abilita RLS sulle tabelle
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_activities ENABLE ROW LEVEL SECURITY;

-- Policy per user_preferences - gli utenti possono vedere e modificare solo le proprie preferenze
DROP POLICY IF EXISTS user_preferences_select_policy ON user_preferences;
CREATE POLICY user_preferences_select_policy ON user_preferences
    FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS user_preferences_insert_policy ON user_preferences;
CREATE POLICY user_preferences_insert_policy ON user_preferences
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS user_preferences_update_policy ON user_preferences;
CREATE POLICY user_preferences_update_policy ON user_preferences
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Policy per user_activities - gli utenti possono vedere solo le proprie attività
DROP POLICY IF EXISTS user_activities_select_policy ON user_activities;
CREATE POLICY user_activities_select_policy ON user_activities
    FOR SELECT
    USING (auth.uid() = user_id);

-- Policy per permettere all'app di inserire attività
DROP POLICY IF EXISTS user_activities_insert_policy ON user_activities;
CREATE POLICY user_activities_insert_policy ON user_activities
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- ==================================
-- FUNZIONI HELPER
-- ==================================

-- Funzione per creare preferenze di default per nuovi utenti
CREATE OR REPLACE FUNCTION create_default_user_preferences()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_preferences (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger per creare preferenze automaticamente quando si crea un nuovo utente
DROP TRIGGER IF EXISTS create_user_preferences_on_signup ON auth.users;
CREATE TRIGGER create_user_preferences_on_signup
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION create_default_user_preferences();

-- Funzione per registrare attività di login
CREATE OR REPLACE FUNCTION log_user_login()
RETURNS void AS $$
BEGIN
    INSERT INTO user_activities (
        user_id,
        activity_type,
        title,
        subtitle,
        icon,
        metadata
    ) VALUES (
        auth.uid(),
        'login',
        'Accesso all''account',
        'Accesso effettuato da iOS',
        'arrow.right.circle.fill',
        jsonb_build_object('platform', 'iOS', 'timestamp', NOW())
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================================
-- STORAGE BUCKET PER IMMAGINI PROFILO
-- ==================================

-- Crea bucket per le immagini profilo se non esiste
INSERT INTO storage.buckets (id, name, public)
VALUES ('profile-images', 'profile-images', true)
ON CONFLICT (id) DO NOTHING;

-- Policy per permettere agli utenti di leggere tutte le immagini profilo
DROP POLICY IF EXISTS "Public profile images are accessible" ON storage.objects;
CREATE POLICY "Public profile images are accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'profile-images');

-- Policy per permettere agli utenti di caricare solo la propria immagine profilo
DROP POLICY IF EXISTS "Users can upload their own profile image" ON storage.objects;
CREATE POLICY "Users can upload their own profile image"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'profile-images' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

-- Policy per permettere agli utenti di aggiornare solo la propria immagine profilo
DROP POLICY IF EXISTS "Users can update their own profile image" ON storage.objects;
CREATE POLICY "Users can update their own profile image"
ON storage.objects FOR UPDATE
USING (
    bucket_id = 'profile-images' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

-- Policy per permettere agli utenti di eliminare solo la propria immagine profilo
DROP POLICY IF EXISTS "Users can delete their own profile image" ON storage.objects;
CREATE POLICY "Users can delete their own profile image"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'profile-images' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

-- ==================================
-- GRANT PERMISSIONS
-- ==================================

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE ON user_preferences TO authenticated;
GRANT SELECT, INSERT ON user_activities TO authenticated;

-- ==================================
-- VERIFICA FINALE
-- ==================================

SELECT
    '✅ Setup tabelle profilo completato con successo!' as message,
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_name IN ('user_preferences', 'user_activities')) as tables_created,
    (SELECT COUNT(*) FROM storage.buckets WHERE id = 'profile-images') as storage_buckets_created;

-- Mostra le tabelle create
SELECT
    table_name,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = t.table_name) as column_count
FROM information_schema.tables t
WHERE table_name IN ('user_preferences', 'user_activities')
ORDER BY table_name;
