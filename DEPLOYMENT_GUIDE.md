# 🚀 Guida Deployment Manuale - TyreVibes Background Jobs

Guida passo-passo per attivare il sistema di background jobs senza CLI.

---

## 📋 PARTE 1: Setup Database (5 minuti)

### Step 1: Accedi a Supabase Dashboard

1. Vai su: https://supabase.com/dashboard/project/jbcbrnegmqraivdfmlsn
2. Fai login se necessario
3. Clicca su **"SQL Editor"** nel menu laterale sinistro

### Step 2: Esegui lo Script SQL

1. Apri il file `/supabase/setup-database-ready.sql` (è già pronto con le tue credenziali!)
2. **Copia TUTTO il contenuto** del file
3. Incollalo nell'editor SQL di Supabase
4. Clicca **"Run"** (o premi CMD+Enter / CTRL+Enter)
5. Aspetta che appaia: ✅ "Success. No rows returned"

### Step 3: Verifica Tabelle Create

Nell'SQL Editor, esegui:

```sql
-- Verifica tabelle
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN ('bollo_status', 'revision_status', 'job_execution_log');
```

**Risultato atteso**: 3 righe (le 3 tabelle)

### Step 4: Verifica Cron Job

```sql
-- Verifica cron attivo
SELECT jobname, schedule, active
FROM cron.job
WHERE jobname = 'run-all-background-jobs';
```

**Risultato atteso**:
- jobname: `run-all-background-jobs`
- schedule: `0 7 * * *`
- active: `true`

✅ **Database setup completato!**

---

## 📦 PARTE 2: Deploy Edge Functions (10 minuti)

Le Edge Functions vanno deployate manualmente tramite Supabase Dashboard.

### Step 1: Vai a Edge Functions

1. Nella dashboard Supabase, clicca su **"Edge Functions"** nel menu laterale
2. Clicca **"Create a new function"**

### Step 2: Deploy Funzione 1 - update-insurance-expiry

1. **Nome**: `update-insurance-expiry`
2. Copia il codice da: `/supabase/functions/update-insurance-expiry/index.ts`
3. Incolla nell'editor
4. Clicca **"Deploy function"**

**⚠️ IMPORTANTE**: Prima di deployare, assicurati che la funzione importi correttamente i tipi. Se l'import `../shared/supabase.ts` dà errore, sostituisci la sezione import con:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? 'https://jbcbrnegmqraivdfmlsn.supabase.co'
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
})

// Poi continua con il resto del codice...
```

### Step 3: Deploy Funzione 2 - update-bollo-status

1. Clicca **"Create a new function"**
2. **Nome**: `update-bollo-status`
3. Copia il codice da: `/supabase/functions/update-bollo-status/index.ts`
4. Applica la stessa modifica agli import se necessario
5. Clicca **"Deploy function"**

### Step 4: Deploy Funzione 3 - update-revision-status

1. Clicca **"Create a new function"**
2. **Nome**: `update-revision-status`
3. Copia il codice da: `/supabase/functions/update-revision-status/index.ts`
4. Applica la stessa modifica agli import se necessario
5. Clicca **"Deploy function"**

### Step 5: Deploy Funzione 4 - run-all-jobs (Orchestrator)

1. Clicca **"Create a new function"**
2. **Nome**: `run-all-jobs`
3. Copia il codice da: `/supabase/functions/run-all-jobs/index.ts`
4. Clicca **"Deploy function"**

✅ **Tutte le Edge Functions deployate!**

---

## 🧪 PARTE 3: Test Funzioni (5 minuti)

### Test 1: Test Singola Funzione

Nell'SQL Editor di Supabase:

```sql
-- Test update-insurance-expiry
SELECT
    extensions.http_post(
        url := 'https://jbcbrnegmqraivdfmlsn.supabase.co/functions/v1/update-insurance-expiry',
        headers := '{"Content-Type": "application/json", "Authorization": "Bearer sb_publishable_j45ieNq6Q9Tyz0qyib5PPA_pEuCNzDc"}'::jsonb,
        body := '{}'::jsonb
    ) AS request_id;
```

**Risultato atteso**: Un ID di richiesta HTTP

### Test 2: Test Orchestrator (Tutti i Job)

```sql
-- Test run-all-jobs
SELECT
    extensions.http_post(
        url := 'https://jbcbrnegmqraivdfmlsn.supabase.co/functions/v1/run-all-jobs',
        headers := '{"Content-Type": "application/json", "Authorization": "Bearer sb_publishable_j45ieNq6Q9Tyz0qyib5PPA_pEuCNzDc"}'::jsonb,
        body := '{}'::jsonb
    ) AS request_id;
```

### Test 3: Verifica Logs

1. Vai su **Edge Functions** → Seleziona una funzione
2. Clicca su **"Logs"**
3. Dovresti vedere:
   - `🔍 Controllo scadenze...`
   - `✅ Job completato`

### Test 4: Verifica Dati

```sql
-- Controlla se sono stati inseriti dati
SELECT COUNT(*) FROM bollo_status;
SELECT COUNT(*) FROM revision_status;

-- Vedi scadenze imminenti
SELECT * FROM upcoming_expirations LIMIT 10;
```

✅ **Funzioni testate e funzionanti!**

---

## 📱 PARTE 4: Configurazione iOS (10 minuti)

### Step 1: Aggiungi Background Modes in Xcode

1. Apri il progetto **TyreVibes** in Xcode
2. Seleziona il target principale
3. Vai su **Signing & Capabilities**
4. Clicca **+ Capability**
5. Aggiungi **"Background Modes"**
6. Spunta:
   - ✅ **Background fetch**
   - ✅ **Remote notifications**

### Step 2: Aggiungi Background Task Identifiers

Nel `Info.plist` (o nella tab Info), aggiungi:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.tyrevibes.backgroundrefresh</string>
</array>
```

Oppure copia il contenuto da `/TyreVibes/Info-BackgroundModes.plist` e incollalo nel tuo `Info.plist` principale.

### Step 3: Inizializza BackgroundTaskManager

Trova il file principale dell'app (probabilmente `TyreVibesApp.swift` o `AppDelegate.swift`).

**Se usi SwiftUI** (`TyreVibesApp.swift`):

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
                    // Schedula il primo refresh
                    BackgroundTaskManager.shared.scheduleBackgroundRefresh()
                }
        }
    }
}
```

**Se usi UIKit** (`AppDelegate.swift`):

```swift
import UIKit
import BackgroundTasks

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Registra i background tasks
        BackgroundTaskManager.shared.registerBackgroundTasks()

        // Schedula il primo refresh
        BackgroundTaskManager.shared.scheduleBackgroundRefresh()

        return true
    }
}
```

### Step 4: Build e Test

1. **Build** il progetto (CMD+B)
2. **Run** su simulatore o device reale (CMD+R)
3. Nell'app, fai un pull-to-refresh in una lista per testare il refresh manuale

### Step 5: Test Background Refresh (Simulatore)

In Xcode, con l'app in esecuzione:

1. Metti l'app in background (Home button)
2. In Xcode: **Debug** → **Simulate Background Fetch**
3. Controlla i logs di Xcode, dovresti vedere:
   - `🔄 Background refresh task avviato`
   - `✅ Background refresh completato`

✅ **App iOS configurata!**

---

## 🎯 PARTE 5: Verifica Sistema Completo

### Checklist Finale

```
✅ Database setup completato
✅ Tabelle create (bollo_status, revision_status)
✅ Cron job attivo (run-all-background-jobs)
✅ Edge Functions deployate (4/4)
✅ Test funzioni eseguiti con successo
✅ Background Modes configurati in Xcode
✅ BackgroundTaskManager inizializzato
✅ App buildata senza errori
```

### Test End-to-End

1. **Aspetta le 07:00** (o esegui manualmente il cron)
2. Verifica che il job sia stato eseguito:

```sql
-- Vedi le ultime esecuzioni del cron
SELECT * FROM cron.job_run_details
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'run-all-background-jobs')
ORDER BY start_time DESC
LIMIT 5;
```

3. Controlla le notifiche generate:

```sql
-- Vedi notifiche recenti
SELECT * FROM notifications
WHERE created_at >= NOW() - INTERVAL '1 day'
ORDER BY created_at DESC;
```

4. Apri l'app iOS e verifica che le notifiche siano sincronizzate

---

## 🎉 Completato!

Il sistema è ora **completamente operativo**:

- ✅ **Server**: Job automatici ogni giorno alle 07:00
- ✅ **Client**: Background refresh ogni 6 ore
- ✅ **Notifiche**: Prioritizzate e sincronizzate

---

## 🐛 Troubleshooting Rapido

### Problema: Cron non si esegue

**Soluzione**: Verifica che pg_cron sia attivo:

```sql
SELECT * FROM cron.job WHERE jobname = 'run-all-background-jobs';
-- Se active = false, esegui:
SELECT cron.alter_job('run-all-background-jobs', active := true);
```

### Problema: Edge Function dà errore 500

**Soluzione**: Controlla i logs nella dashboard:
- Edge Functions → Seleziona funzione → Logs
- Cerca errori e correggi il codice

### Problema: Background refresh non parte su iOS

**Soluzione**:
1. Verifica che `Info.plist` abbia `BGTaskSchedulerPermittedIdentifiers`
2. Disabilita Low Power Mode sul device
3. Prova con simulatore: Debug → Simulate Background Fetch

### Problema: RLS blocca le query

**Soluzione**: Verifica che le policy RLS siano corrette:

```sql
-- Lista policy attive
SELECT * FROM pg_policies
WHERE tablename IN ('bollo_status', 'revision_status');
```

---

## 📞 Supporto

Per problemi o domande:
- 📖 Leggi: `/supabase/README.md` (documentazione completa)
- 🔍 Controlla: Logs di Supabase Dashboard
- 🐛 Debug: Usa `console.log` nelle Edge Functions

---

**Fatto! Il sistema è pronto all'uso! 🚀**
