# 🔄 Sistema Background Jobs - TyreVibes

Sistema completo per aggiornamento automatico di scadenze assicurazioni, bollo auto e revisioni periodiche.

## 📦 Cosa è stato implementato

### ✅ Supabase Edge Functions (Backend)

4 funzioni serverless che girano nel cloud Supabase:

1. **`update-insurance-expiry`** - Controlla scadenze assicurazioni RCA
2. **`update-bollo-status`** - Verifica stato pagamento bollo auto
3. **`update-revision-status`** - Controlla scadenze revisioni periodiche
4. **`run-all-jobs`** - Orchestratore che esegue tutti i job in parallelo

**Posizione**: `/supabase/functions/`

### ✅ BackgroundTaskManager (iOS)

Servizio Swift che gestisce i refresh automatici in background su iOS:

- `BGAppRefreshTask` ogni 6 ore
- Sincronizzazione con Edge Functions
- Integrazione con `NotificationScheduler` esistente
- Gestione notifiche push

**Posizione**: `/TyreVibes/Services/BackgroundTaskManager.swift`

### ✅ Database Setup

- Tabelle `bollo_status` e `revision_status`
- Indici per performance ottimali
- Row Level Security (RLS) configurato
- Vista `upcoming_expirations` per report
- Cron job scheduler con `pg_cron`

**Posizione**: `/supabase/setup-database.sql`

### ✅ Deployment & Configurazione

- Script di deploy automatico
- Documentazione completa
- Configurazione Info.plist per iOS
- Guide per testing e monitoraggio

**Posizione**: `/supabase/deploy.sh` e `/supabase/README.md`

## 🚀 Come Usare

### 1. Setup Iniziale (Una Tantum)

```bash
# 1. Installa Supabase CLI
npm install -g supabase

# 2. Login
supabase login

# 3. Setup database
# Copia il contenuto di supabase/setup-database.sql
# e incollalo nel SQL Editor di Supabase Dashboard

# 4. Deploy delle functions
cd /home/user/TyreVibes/supabase
./deploy.sh
```

### 2. Configurazione iOS

Aggiungi al tuo `Info.plist` (o usa Xcode → Signing & Capabilities):

```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>

<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.tyrevibes.backgroundrefresh</string>
</array>
```

Vedi `/TyreVibes/Info-BackgroundModes.plist` per il template completo.

### 3. Inizializzazione nell'App

Nel tuo `TyreVibesApp.swift`:

```swift
import SwiftUI
import BackgroundTasks

@main
struct TyreVibesApp: App {
    init() {
        // Registra i background tasks
        BackgroundTaskManager.shared.registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    BackgroundTaskManager.shared.scheduleBackgroundRefresh()
                }
        }
    }
}
```

## 📊 Funzionalità Chiave

### Notifiche Intelligenti

Il sistema genera notifiche prioritizzate:

- **🚨 Critical**: Scadenza entro 7 giorni o già scaduta
- **⚠️ High**: Scadenza entro 15 giorni
- **📅 Medium**: Scadenza entro 30 giorni
- **💡 Low**: Scadenza entro 60 giorni

### Sincronizzazione Automatica

- **Server**: Job eseguiti ogni giorno alle 07:00 (pg_cron)
- **Client iOS**: Refresh ogni 6 ore in background
- **Manual**: Pull-to-refresh disponibile

### Calcoli Intelligenti

**Bollo Auto**:
- Tariffe Euro 0-6 automatiche
- Superbollo per potenza > 185 KW
- Sconti per veicoli storici/elettrici/ibridi

**Revisioni**:
- Prima revisione: 4 anni dalla immatricolazione
- Auto private: ogni 2 anni
- Veicoli commerciali: ogni anno

## 📁 Struttura File

```
TyreVibes/
├── supabase/
│   ├── functions/
│   │   ├── _shared/
│   │   │   ├── supabase.ts          # Tipi e client condiviso
│   │   │   └── cron-schedule.md     # Configurazione cron
│   │   ├── update-insurance-expiry/
│   │   │   └── index.ts
│   │   ├── update-bollo-status/
│   │   │   └── index.ts
│   │   ├── update-revision-status/
│   │   │   └── index.ts
│   │   └── run-all-jobs/
│   │       └── index.ts
│   ├── config.toml                  # Config Supabase
│   ├── setup-database.sql           # Setup DB e cron
│   ├── deploy.sh                    # Script deploy
│   └── README.md                    # Documentazione completa
│
└── TyreVibes/
    ├── Services/
    │   ├── BackgroundTaskManager.swift    # NEW! Background tasks iOS
    │   └── NotificationScheduler.swift    # UPDATED! Con sync server
    └── Info-BackgroundModes.plist         # Template configurazione
```

## 🧪 Testing

### Test Edge Functions

```bash
# Test singola funzione
curl -X POST https://jbcbrnegmqraivdfmlsn.supabase.co/functions/v1/update-insurance-expiry \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json"

# Test orchestrator (tutti i job)
curl -X POST https://jbcbrnegmqraivdfmlsn.supabase.co/functions/v1/run-all-jobs \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json"
```

### Test Background iOS

```swift
// Refresh manuale
Task {
    await BackgroundTaskManager.shared.performManualRefresh()
}

// Verifica ultimo refresh
print(BackgroundTaskManager.shared.lastRefreshDescription)
// Output: "2 ore fa"
```

### Simulatore Xcode

```bash
# Simula background fetch
xcrun simctl spawn booted e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.tyrevibes.backgroundrefresh"]
```

## 📈 Monitoraggio

### Query SQL Utili

```sql
-- Scadenze imminenti (prossimi 30 giorni)
SELECT * FROM upcoming_expirations
WHERE days_until_expiry <= 30
ORDER BY days_until_expiry ASC;

-- Notifiche critiche non lette
SELECT * FROM notifications
WHERE priority = 'critical'
  AND read = false
ORDER BY created_at DESC;

-- Log job recenti
SELECT * FROM job_execution_log
ORDER BY started_at DESC
LIMIT 10;

-- Job schedulati attivi
SELECT * FROM cron.job;
```

## ⚙️ Configurazione Avanzata

### Modifica Frequenza Cron

Edita in SQL Editor:

```sql
-- Cambia da 07:00 a 08:00
SELECT cron.unschedule('run-all-background-jobs');
SELECT cron.schedule(
    'run-all-background-jobs',
    '0 8 * * *',  -- Nuova ora
    $$ ... $$
);
```

### Modifica Frequenza iOS Background

In `BackgroundTaskManager.swift:266`:

```swift
// Da 6 ore a 12 ore
request.earliestBeginDate = Date(timeIntervalSinceNow: 12 * 60 * 60)
```

## 🔐 Sicurezza

- ✅ JWT authentication su tutte le API
- ✅ Row Level Security (RLS) abilitato
- ✅ Solo `service_role` può scrivere status
- ✅ Utenti vedono solo i propri dati
- ✅ HTTPS enforced

## 🐛 Troubleshooting

### Job non si eseguono

1. Verifica cron attivo: `SELECT * FROM cron.job;`
2. Controlla logs: `SELECT * FROM cron.job_run_details ORDER BY start_time DESC;`
3. Sostituisci `YOUR_SUPABASE_ANON_KEY` nel cron job

### Background iOS non funziona

1. Verifica `Info.plist` corretto
2. Disabilita Low Power Mode
3. Testa con simulatore: Debug → Simulate Background Fetch
4. Controlla logs: `BackgroundTaskManager` usa `os.log`

### Notifiche non arrivano

1. Verifica device tokens: `SELECT * FROM device_tokens WHERE active = true;`
2. Controlla permessi iOS
3. Verifica inserimenti in `notifications` table

## 📚 Documentazione Completa

Vedi `/supabase/README.md` per:

- Architettura dettagliata
- API reference completa
- Performance tuning
- Esempi avanzati
- Best practices

## 🎯 Prossimi Passi

1. ✅ Implementazione completata
2. ⏳ Deploy in staging per test
3. ⏳ Monitoraggio performance per 1 settimana
4. ⏳ Deploy in production
5. ⏳ Analytics e ottimizzazioni

## 💡 Note Importanti

⚠️ **RICORDA**:
- Sostituire `YOUR_SUPABASE_ANON_KEY` nel cron job dopo il setup
- Testare in staging prima del deploy in production
- Monitorare le prime esecuzioni per verificare performance
- Backup del database prima di modifiche strutturali

---

**Implementato da**: Claude Code
**Data**: 2025-11-14
**Versione**: 1.0.0
