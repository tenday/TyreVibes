# Configurazione Cron per Background Jobs

## Job Schedulati

### 1. update-insurance-expiry
**Frequenza**: Ogni giorno alle 08:00 (ora italiana)
**Cron**: `0 8 * * *`
**Descrizione**: Controlla le scadenze delle assicurazioni RCA e invia notifiche

### 2. update-bollo-status
**Frequenza**: Ogni giorno alle 09:00 (ora italiana)
**Cron**: `0 9 * * *`
**Descrizione**: Verifica lo stato del pagamento del bollo auto

### 3. update-revision-status
**Frequenza**: Ogni giorno alle 10:00 (ora italiana)
**Cron**: `0 10 * * *`
**Descrizione**: Controlla le scadenze delle revisioni periodiche

### 4. run-all-jobs (Orchestratore)
**Frequenza**: Ogni giorno alle 07:00 (ora italiana) - esegue tutti i job in sequenza
**Cron**: `0 7 * * *`
**Descrizione**: Esegue tutti i job di aggiornamento in parallelo

## Configurazione Supabase

Per configurare lo scheduling automatico su Supabase, eseguire:

```bash
# Installare Supabase CLI
npm install -g supabase

# Login a Supabase
supabase login

# Link al progetto
supabase link --project-ref jbcbrnegmqraivdfmlsn

# Deploy delle functions
supabase functions deploy update-insurance-expiry
supabase functions deploy update-bollo-status
supabase functions deploy update-revision-status
supabase functions deploy run-all-jobs
```

## Configurazione Cron con pg_cron (PostgreSQL)

Aggiungere al database Supabase:

```sql
-- Abilita estensione pg_cron
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Job giornaliero alle 07:00 per eseguire tutti i job
SELECT cron.schedule(
  'run-all-background-jobs',
  '0 7 * * *',
  $$
  SELECT
    net.http_post(
      url := 'https://jbcbrnegmqraivdfmlsn.supabase.co/functions/v1/run-all-jobs',
      headers := '{"Content-Type": "application/json", "x-cron-secret": "YOUR_BACKGROUND_JOBS_SECRET"}'::jsonb,
      body := '{}'::jsonb
    ) AS request_id;
  $$
);

-- Job separati (opzionale, se preferisci eseguirli separatamente)
SELECT cron.schedule(
  'update-insurance-expiry-job',
  '0 8 * * *',
  $$
  SELECT
    net.http_post(
      url := 'https://jbcbrnegmqraivdfmlsn.supabase.co/functions/v1/update-insurance-expiry',
      headers := '{"Content-Type": "application/json", "x-cron-secret": "YOUR_BACKGROUND_JOBS_SECRET"}'::jsonb,
      body := '{}'::jsonb
    ) AS request_id;
  $$
);

SELECT cron.schedule(
  'update-bollo-status-job',
  '0 9 * * *',
  $$
  SELECT
    net.http_post(
      url := 'https://jbcbrnegmqraivdfmlsn.supabase.co/functions/v1/update-bollo-status',
      headers := '{"Content-Type": "application/json", "x-cron-secret": "YOUR_BACKGROUND_JOBS_SECRET"}'::jsonb,
      body := '{}'::jsonb
    ) AS request_id;
  $$
);

SELECT cron.schedule(
  'update-revision-status-job',
  '0 10 * * *',
  $$
  SELECT
    net.http_post(
      url := 'https://jbcbrnegmqraivdfmlsn.supabase.co/functions/v1/update-revision-status',
      headers := '{"Content-Type": "application/json", "x-cron-secret": "YOUR_BACKGROUND_JOBS_SECRET"}'::jsonb,
      body := '{}'::jsonb
    ) AS request_id;
  $$
);
```

## Monitoraggio Jobs

Verificare l'esecuzione dei job:

```sql
-- Visualizza i job schedulati
SELECT * FROM cron.job;

-- Visualizza la history delle esecuzioni
SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;

-- Elimina un job
SELECT cron.unschedule('run-all-background-jobs');
```

## Tabelle Database Necessarie

Creare le seguenti tabelle se non esistono:

```sql
-- Tabella per stato bollo
CREATE TABLE IF NOT EXISTS bollo_status (
  id BIGSERIAL PRIMARY KEY,
  vehicle_id BIGINT REFERENCES vehicles(id) ON DELETE CASCADE,
  plate_id BIGINT REFERENCES plates(id) ON DELETE CASCADE,
  expiry_date TIMESTAMP WITH TIME ZONE,
  amount DECIMAL(10,2),
  is_paid BOOLEAN DEFAULT false,
  last_checked TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(vehicle_id)
);

-- Tabella per stato revisioni
CREATE TABLE IF NOT EXISTS revision_status (
  id BIGSERIAL PRIMARY KEY,
  vehicle_id BIGINT REFERENCES vehicles(id) ON DELETE CASCADE,
  plate_id BIGINT REFERENCES plates(id) ON DELETE CASCADE,
  last_revision_date TIMESTAMP WITH TIME ZONE,
  next_revision_date TIMESTAMP WITH TIME ZONE,
  last_revision_km VARCHAR(50),
  is_expired BOOLEAN DEFAULT false,
  last_checked TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(vehicle_id)
);

-- Indici per performance
CREATE INDEX IF NOT EXISTS idx_bollo_status_vehicle_id ON bollo_status(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_bollo_status_expiry_date ON bollo_status(expiry_date);
CREATE INDEX IF NOT EXISTS idx_revision_status_vehicle_id ON revision_status(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_revision_status_next_revision ON revision_status(next_revision_date);
```

## Test Manuale

Testare le funzioni manualmente:

```bash
# Test update-insurance-expiry
curl -X POST https://jbcbrnegmqraivdfmlsn.supabase.co/functions/v1/update-insurance-expiry \
  -H "x-cron-secret: YOUR_BACKGROUND_JOBS_SECRET" \
  -H "Content-Type: application/json"

# Test update-bollo-status
curl -X POST https://jbcbrnegmqraivdfmlsn.supabase.co/functions/v1/update-bollo-status \
  -H "x-cron-secret: YOUR_BACKGROUND_JOBS_SECRET" \
  -H "Content-Type: application/json"

# Test update-revision-status
curl -X POST https://jbcbrnegmqraivdfmlsn.supabase.co/functions/v1/update-revision-status \
  -H "x-cron-secret: YOUR_BACKGROUND_JOBS_SECRET" \
  -H "Content-Type: application/json"

# Test run-all-jobs
curl -X POST https://jbcbrnegmqraivdfmlsn.supabase.co/functions/v1/run-all-jobs \
  -H "x-cron-secret: YOUR_BACKGROUND_JOBS_SECRET" \
  -H "Content-Type: application/json"
```
