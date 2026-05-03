-- ==============================================================================
-- CONFIGURAZIONE JOB SCHEDULATI (CRON) PER TYREVIBES
-- ==============================================================================
-- Questo script configura l'estensione pg_cron e imposta i job automatici
-- che devono essere eseguiti ogni giorno per aggiornare assicurazioni, bolli e revisioni.

-- 1. Abilita l'estensione pg_cron (se non già abilitata)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- ==============================================================================
-- JOB 1: ORCHESTRATORE GLOBALE (Esegue tutti i check)
-- ==============================================================================
-- Frequenza: Ogni giorno alle 07:00 UTC (adeguare per fuso orario locale se necessario)
-- Descrizione: Chiama la funzione 'run-all-jobs' che lancia in parallelo gli aggiornamenti.
--              Questa è la soluzione raccomandata per gestire tutto con una sola chiamata.

SELECT cron.schedule(
  'run-all-background-jobs', -- Nome univoco del job
  '0 7 * * *',               -- Espressione Cron (Ogni giorno alle 07:00)
  $$
  SELECT
    net.http_post(
      -- URL della Edge Function (Sostituisci con il tuo URL di progetto reale se diverso)
      url := 'https://jbcbrnegmqraivdfmlsn.supabase.co/functions/v1/run-all-jobs',
      
      -- Headers necessari per l'autenticazione (Sostituisci YOUR_BACKGROUND_JOBS_SECRET con il valore configurato nelle Edge Functions)
      -- NOTA: In un ambiente di produzione, il secret dovrebbe essere gestito in modo sicuro
      headers := '{"Content-Type": "application/json", "x-cron-secret": "YOUR_BACKGROUND_JOBS_SECRET"}'::jsonb,
      
      -- Body vuoto
      body := '{}'::jsonb
    ) AS request_id;
  $$
);

-- ==============================================================================
-- JOB ALTERNATIVI (Opzionali - Da usare solo se NON si usa l'orchestratore sopra)
-- ==============================================================================
-- Se preferisci schedulare i job singolarmente in orari diversi, decommenta le sezioni sotto.
-- Assicurati di rimuovere il job 'run-all-background-jobs' se attivi questi, per evitare doppi controlli.

/*
-- Job Assicurazioni (Ore 08:00)
SELECT cron.schedule(
  'update-insurance-expiry-job',
  '0 8 * * *',
  $$
  SELECT net.http_post(
      url := 'https://jbcbrnegmqraivdfmlsn.supabase.co/functions/v1/update-insurance-expiry',
      headers := '{"Content-Type": "application/json", "x-cron-secret": "YOUR_BACKGROUND_JOBS_SECRET"}'::jsonb,
      body := '{}'::jsonb
  ) AS request_id;
  $$
);

-- Job Bollo (Ore 09:00)
SELECT cron.schedule(
  'update-bollo-status-job',
  '0 9 * * *',
  $$
  SELECT net.http_post(
      url := 'https://jbcbrnegmqraivdfmlsn.supabase.co/functions/v1/update-bollo-status',
      headers := '{"Content-Type": "application/json", "x-cron-secret": "YOUR_BACKGROUND_JOBS_SECRET"}'::jsonb,
      body := '{}'::jsonb
  ) AS request_id;
  $$
);

-- Job Revisioni (Ore 10:00)
SELECT cron.schedule(
  'update-revision-status-job',
  '0 10 * * *',
  $$
  SELECT net.http_post(
      url := 'https://jbcbrnegmqraivdfmlsn.supabase.co/functions/v1/update-revision-status',
      headers := '{"Content-Type": "application/json", "x-cron-secret": "YOUR_BACKGROUND_JOBS_SECRET"}'::jsonb,
      body := '{}'::jsonb
  ) AS request_id;
  $$
);
*/

-- ==============================================================================
-- UTILITY PER GESTIONE JOB
-- ==============================================================================

-- Visualizza tutti i job attivi
-- SELECT * FROM cron.job;

-- Visualizza lo storico delle esecuzioni (per debug)
-- SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 20;

-- Rimuovere un job schedulato (se necessario in futuro)
-- SELECT cron.unschedule('run-all-background-jobs');
