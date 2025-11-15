-- Migration: Aggiungi tabella user_settings per sincronizzazione impostazioni cloud
-- Created: 2025-11-15

-- Crea tabella user_settings
CREATE TABLE IF NOT EXISTS user_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    background_sync BOOLEAN NOT NULL DEFAULT true,
    battery_optimization BOOLEAN NOT NULL DEFAULT true,
    image_quality DOUBLE PRECISION NOT NULL DEFAULT 0.8,
    cache_management BOOLEAN NOT NULL DEFAULT true,
    biometric_auth BOOLEAN NOT NULL DEFAULT false,
    privacy_level TEXT NOT NULL DEFAULT 'strict',
    language TEXT NOT NULL DEFAULT 'it',
    notifications_enabled BOOLEAN NOT NULL DEFAULT true,
    promotion_notifications BOOLEAN NOT NULL DEFAULT true,
    update_notifications BOOLEAN NOT NULL DEFAULT false,
    analysis_notifications BOOLEAN NOT NULL DEFAULT true,
    selected_theme TEXT NOT NULL DEFAULT 'system',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT user_settings_user_id_unique UNIQUE (user_id),
    CONSTRAINT user_settings_privacy_level_check CHECK (privacy_level IN ('basic', 'balanced', 'strict')),
    CONSTRAINT user_settings_language_check CHECK (language IN ('en', 'it')),
    CONSTRAINT user_settings_theme_check CHECK (selected_theme IN ('system', 'light', 'dark')),
    CONSTRAINT user_settings_image_quality_check CHECK (image_quality >= 0 AND image_quality <= 1)
);

-- Crea indice per user_id
CREATE INDEX IF NOT EXISTS idx_user_settings_user_id ON user_settings(user_id);

-- Crea indice per updated_at (per ordinamento)
CREATE INDEX IF NOT EXISTS idx_user_settings_updated_at ON user_settings(updated_at DESC);

-- Abilita RLS (Row Level Security)
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

-- Policy: Gli utenti possono leggere solo le proprie impostazioni
CREATE POLICY "Users can read own settings"
    ON user_settings
    FOR SELECT
    USING (auth.uid() = user_id);

-- Policy: Gli utenti possono inserire solo le proprie impostazioni
CREATE POLICY "Users can insert own settings"
    ON user_settings
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policy: Gli utenti possono aggiornare solo le proprie impostazioni
CREATE POLICY "Users can update own settings"
    ON user_settings
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Policy: Gli utenti possono eliminare solo le proprie impostazioni
CREATE POLICY "Users can delete own settings"
    ON user_settings
    FOR DELETE
    USING (auth.uid() = user_id);

-- Funzione per aggiornare automaticamente updated_at
CREATE OR REPLACE FUNCTION update_user_settings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger per aggiornare updated_at automaticamente
DROP TRIGGER IF EXISTS trigger_update_user_settings_updated_at ON user_settings;
CREATE TRIGGER trigger_update_user_settings_updated_at
    BEFORE UPDATE ON user_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_user_settings_updated_at();

-- Commento sulla tabella
COMMENT ON TABLE user_settings IS 'Memorizza le impostazioni utente sincronizzate tra dispositivi';
COMMENT ON COLUMN user_settings.user_id IS 'ID dell''utente proprietario delle impostazioni';
COMMENT ON COLUMN user_settings.background_sync IS 'Abilita sincronizzazione in background';
COMMENT ON COLUMN user_settings.battery_optimization IS 'Abilita ottimizzazione batteria';
COMMENT ON COLUMN user_settings.image_quality IS 'Qualità immagini (0-1)';
COMMENT ON COLUMN user_settings.cache_management IS 'Abilita gestione automatica cache';
COMMENT ON COLUMN user_settings.biometric_auth IS 'Abilita autenticazione biometrica';
COMMENT ON COLUMN user_settings.privacy_level IS 'Livello privacy: basic, balanced, strict';
COMMENT ON COLUMN user_settings.language IS 'Lingua interfaccia: en, it';
COMMENT ON COLUMN user_settings.notifications_enabled IS 'Abilita tutte le notifiche';
COMMENT ON COLUMN user_settings.promotion_notifications IS 'Abilita notifiche promozionali';
COMMENT ON COLUMN user_settings.update_notifications IS 'Abilita notifiche aggiornamenti';
COMMENT ON COLUMN user_settings.analysis_notifications IS 'Abilita notifiche completamento analisi';
COMMENT ON COLUMN user_settings.selected_theme IS 'Tema selezionato: system, light, dark';
COMMENT ON COLUMN user_settings.updated_at IS 'Timestamp ultimo aggiornamento';
COMMENT ON COLUMN user_settings.created_at IS 'Timestamp creazione';
