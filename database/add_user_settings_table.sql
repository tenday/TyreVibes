-- Aggiunge la tabella user_settings al database API TyreVibes (MySQL/MariaDB)
-- Compatibile con schema.sql

CREATE TABLE IF NOT EXISTS user_settings (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    background_sync BOOLEAN NOT NULL DEFAULT TRUE,
    battery_optimization BOOLEAN NOT NULL DEFAULT TRUE,
    image_quality DOUBLE NOT NULL DEFAULT 0.8,
    cache_management BOOLEAN NOT NULL DEFAULT TRUE,
    biometric_auth BOOLEAN NOT NULL DEFAULT FALSE,
    privacy_level ENUM('basic', 'balanced', 'strict') NOT NULL DEFAULT 'strict',
    language ENUM('en', 'it') NOT NULL DEFAULT 'it',
    notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    promotion_notifications BOOLEAN NOT NULL DEFAULT TRUE,
    update_notifications BOOLEAN NOT NULL DEFAULT FALSE,
    analysis_notifications BOOLEAN NOT NULL DEFAULT TRUE,
    selected_theme ENUM('system', 'light', 'dark') NOT NULL DEFAULT 'system',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY user_settings_user_id_unique (user_id),
    INDEX idx_user_settings_user_id (user_id),
    INDEX idx_user_settings_updated_at (updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
