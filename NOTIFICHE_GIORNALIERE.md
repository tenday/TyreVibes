# 🔔 Notifiche Giornaliere e Auto-Refresh

Documentazione delle nuove funzionalità implementate per gestire le scadenze in modo proattivo.

---

## 🎯 Nuove Funzionalità

### 1. ✅ Notifiche GIORNALIERE per Scadenze

**Problema risolto**: Prima le notifiche venivano inviate una sola volta. Se l'utente non rinnovava, non riceveva più avvisi.

**Soluzione**: Ora il sistema invia **una notifica al giorno** per ogni scadenza imminente o scaduta, fino al rinnovo effettivo.

**Come funziona**:
- Il sistema controlla se ha già inviato una notifica oggi
- Se è passato almeno 1 giorno dall'ultima notifica E la scadenza è vicina (≤30 giorni), invia una nuova notifica
- Quando l'utente rinnova, il sistema smette di inviare notifiche per quella scadenza

### 2. ✅ Auto-Refresh Dati tramite License Plate Reader

**Problema risolto**: I dati nel database potevano essere obsoleti, specialmente dopo un rinnovo.

**Soluzione**: Quando una scadenza viene superata, il sistema **chiama automaticamente** l'API del license plate reader per aggiornare i dati.

**Come funziona**:
- Quando assicurazione/bollo/revisione scade, viene richiamata l'API `/v1/check_plate`
- L'API restituisce i dati aggiornati (inclusi eventuali rinnovi)
- I dati vengono salvati nel database
- Se l'utente ha rinnovato, le notifiche si fermano automaticamente

### 3. ✅ Tracking Completo delle Notifiche

**Problema risolto**: Non c'era modo di sapere quante volte era stata notificata una scadenza.

**Soluzione**: Nuova tabella `notification_tracking` che registra ogni notifica inviata.

**Cosa traccia**:
- Data ultima notifica
- Numero totale di notifiche inviate
- Se la scadenza è stata risolta (rinnovata)
- Tipo di scadenza (insurance/bollo/revision)

---

## 📊 Schema Database Aggiornato

### Nuove Tabelle

#### `notification_tracking`

Traccia le notifiche giornaliere inviate.

```sql
CREATE TABLE notification_tracking (
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
```

#### `auto_refresh_log`

Log dei refresh automatici dei dati.

```sql
CREATE TABLE auto_refresh_log (
    id BIGSERIAL PRIMARY KEY,
    vehicle_id BIGINT NOT NULL,
    plate TEXT NOT NULL,
    refresh_type VARCHAR(50) NOT NULL,
    refresh_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    success BOOLEAN DEFAULT false,
    error_message TEXT,
    data_updated BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Nuove Funzioni SQL

#### `should_notify_today()`

Determina se deve essere inviata una notifica oggi.

```sql
SELECT should_notify_today(
    vehicle_id := 123,
    notification_type := 'insurance',
    expiry_date := '2025-12-31'
);
-- Restituisce: true/false
```

**Logica**:
- Se non esiste record → notifica subito
- Se `is_resolved = true` → NON notificare
- Se è passato < 1 giorno → NON notificare (già notificato oggi)
- Se è passato ≥ 1 giorno E scadenza ≤ 30 giorni → notifica

#### `track_notification()`

Registra l'invio di una notifica.

```sql
SELECT track_notification(
    p_user_id := 'user_123',
    p_vehicle_id := 456,
    p_plate := 'AB123CD',
    p_notification_type := 'bollo',
    p_expiry_date := '2025-12-31'
);
```

**Effetto**:
- Prima notifica → crea record con `notification_count = 1`
- Notifiche successive → incrementa `notification_count`
- Aggiorna `last_notification_date` a NOW()

#### `mark_notification_resolved()`

Marca una scadenza come risolta (rinnovata).

```sql
SELECT mark_notification_resolved(
    p_vehicle_id := 456,
    p_notification_type := 'insurance'
);
```

**Effetto**:
- Imposta `is_resolved = true`
- Le notifiche giornaliere si fermano automaticamente

### Nuova Vista

#### `daily_notifications_due`

Mostra tutte le scadenze che richiedono notifica oggi.

```sql
SELECT * FROM daily_notifications_due;
```

**Restituisce**:
- `vehicle_id`, `plate`, `make`, `model`
- `notification_type` ('insurance', 'bollo', 'revision')
- `expiry_date`
- `days_until_expiry`
- `notification_count` (quante notifiche già inviate)
- `last_notification_date`

---

## 🔄 Flusso Operativo

### Scenario 1: Assicurazione in Scadenza

```
Giorno -30: Prima notifica (medium priority)
Giorno -15: Seconda notifica (high priority)
Giorno -7:  Notifica GIORNALIERA (critical priority)
Giorno -6:  Notifica GIORNALIERA
Giorno -5:  Notifica GIORNALIERA
...
Giorno 0:   Scadenza! Notifica GIORNALIERA
Giorno +1:  Scaduta! AUTO-REFRESH dati + Notifica GIORNALIERA
Giorno +2:  AUTO-REFRESH + Notifica GIORNALIERA
...
Utente rinnova → AUTO-REFRESH rileva il rinnovo → STOP notifiche
```

### Scenario 2: Bollo Scaduto ma Poi Pagato

```
Giorno 0:   Bollo scade
Giorno +1:  Job esegue:
            1. Rileva scadenza
            2. Chiama /v1/check_plate
            3. API restituisce dati aggiornati
            4. Se pagato → aggiorna DB con is_paid=true
            5. Marca notifica come resolved
            6. STOP notifiche

Giorno +2:  Job verifica:
            - is_resolved = true
            - SKIP notifica
```

### Scenario 3: Revisione da Rinnovare

```
Giorno -60: Prima notifica (medium)
Giorno -30: Seconda notifica (high)
Giorno -7:  Notifica GIORNALIERA (critical)
...
Giorno +5:  Scaduta da 5 giorni
            - AUTO-REFRESH dati
            - Se non trovata nuova revisione → notifica GIORNALIERA
            - Se trovata nuova revisione → STOP notifiche
```

---

## 🎨 Priorità Notifiche

### Assicurazione RCA

| Giorni alla Scadenza | Priorità | Frequenza Notifica |
|---------------------|----------|-------------------|
| 30 giorni           | Medium   | Una volta         |
| 15 giorni           | High     | Una volta         |
| 7 giorni            | Critical | **Giornaliera**   |
| Scaduta             | Critical | **Giornaliera**   |

### Bollo Auto

| Giorni alla Scadenza | Priorità | Frequenza Notifica |
|---------------------|----------|-------------------|
| 60 giorni           | Low      | Una volta         |
| 30 giorni           | Medium   | Una volta         |
| 15 giorni           | High     | Una volta         |
| 7 giorni            | Critical | **Giornaliera**   |
| Scaduto             | Critical | **Giornaliera**   |

### Revisione Periodica

| Giorni alla Scadenza | Priorità | Frequenza Notifica |
|---------------------|----------|-------------------|
| 60 giorni           | Medium   | Una volta         |
| 30 giorni           | High     | Una volta         |
| 15 giorni           | High     | Una volta         |
| 7 giorni            | Critical | **Giornaliera**   |
| Scaduta             | Critical | **Giornaliera**   |

---

## 🛠️ API Auto-Refresh

### Endpoint Chiamato

```
GET https://www.tyrevibes.com/api/v1/check_plate?plate=AB123CD
```

### Headers

```
Authorization: Bearer {SUPABASE_SERVICE_ROLE_KEY}
Content-Type: application/json
```

### Quando Viene Chiamato

L'API viene chiamata automaticamente quando:
1. Assicurazione scaduta (`daysUntilExpiry < 0`)
2. Bollo scaduto (`daysUntilExpiry < 0`)
3. Revisione scaduta (`daysUntilRevision < 0`)

### Cosa Succede

1. **Edge Function** rileva scadenza superata
2. Chiama `refreshVehicleData(plate, userId)`
3. Funzione fa richiesta HTTP a `/v1/check_plate`
4. Se successo (200):
   - API restituisce dati aggiornati
   - Backend aggiorna automaticamente il database
   - Se rinnovato → notifiche si fermano
5. Log salvato in `auto_refresh_log`

---

## 📝 Setup

### 1. Esegui lo Script SQL

Apri Supabase Dashboard → SQL Editor:

```bash
# Copia il contenuto di:
/supabase/update-daily-notifications.sql

# E incollalo nell'editor, poi clicca "Run"
```

**Questo crea**:
- Tabella `notification_tracking`
- Tabella `auto_refresh_log`
- Funzioni `should_notify_today()`, `track_notification()`, `mark_notification_resolved()`
- Vista `daily_notifications_due`

### 2. Rideploy delle Edge Functions

Le Edge Functions sono state aggiornate con la nuova logica:

```bash
# Via Supabase Dashboard:
# 1. Edge Functions → update-insurance-expiry → Edit
# 2. Copia il contenuto da /supabase/functions/update-insurance-expiry/index.ts
# 3. Deploy

# Ripeti per:
# - update-bollo-status
# - update-revision-status
```

### 3. Test

```sql
-- Verifica che le funzioni siano state create
SELECT routine_name FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN ('should_notify_today', 'track_notification', 'mark_notification_resolved');

-- Testa la vista
SELECT * FROM daily_notifications_due LIMIT 5;

-- Simula una notifica
SELECT track_notification(
    'user_test',
    1,
    'AB123CD',
    'insurance',
    '2025-12-31'::timestamp
);

-- Verifica tracking
SELECT * FROM notification_tracking;
```

---

## 📊 Monitoraggio

### Query Utili

```sql
-- Notifiche inviate oggi
SELECT notification_type, COUNT(*) as total
FROM notification_tracking
WHERE DATE(last_notification_date) = CURRENT_DATE
GROUP BY notification_type;

-- Veicoli con più notifiche
SELECT plate, notification_type, notification_count
FROM notification_tracking
WHERE notification_count > 5
ORDER BY notification_count DESC;

-- Auto-refresh eseguiti
SELECT refresh_type, success, COUNT(*) as total
FROM auto_refresh_log
WHERE DATE(refresh_date) = CURRENT_DATE
GROUP BY refresh_type, success;

-- Scadenze non risolte
SELECT *
FROM notification_tracking
WHERE is_resolved = false
AND expiry_date < NOW()
ORDER BY expiry_date ASC;
```

---

## 🎉 Benefici

### Per l'Utente

✅ **Non perde mai una scadenza** - notifiche giornaliere fino al rinnovo
✅ **Dati sempre aggiornati** - auto-refresh automatico
✅ **Nessuna notifica inutile** - si fermano automaticamente dopo il rinnovo
✅ **Priorità chiare** - capisce subito cosa è urgente

### Per il Sistema

✅ **Dati accurati** - refresh automatico mantiene il DB sincronizzato
✅ **Tracciabilità completa** - ogni notifica viene loggata
✅ **Performance ottimizzate** - notifica solo quando necessario
✅ **Scalabilità** - gestisce migliaia di veicoli senza problemi

---

## 🔧 Configurazione Avanzata

### Modificare Frequenza Notifiche

Edita la funzione `should_notify_today` per cambiare la logica:

```sql
-- Esempio: notifica ogni 2 giorni invece di ogni giorno
v_days_since_last := EXTRACT(DAY FROM NOW() - v_last_notification);

-- Cambia da >= 1 a >= 2
IF v_days_since_last >= 2 AND p_expiry_date <= NOW() + INTERVAL '30 days' THEN
    RETURN TRUE;
END IF;
```

### Modificare Soglie Notifiche

Edita le Edge Functions per cambiare quando notificare:

```typescript
// In update-insurance-expiry/index.ts
else if (daysUntilExpiry <= 30) {  // Cambia da 30 a 45 giorni
  shouldSendNotification = true
  priority = 'medium'
  message = `📅 ...`
}
```

---

## 🎯 Best Practices

1. **Monitora i logs** - controlla `auto_refresh_log` per vedere se i refresh funzionano
2. **Pulisci vecchi record** - elimina tracking risolti dopo 90 giorni
3. **Testa regolarmente** - simula scadenze per verificare che le notifiche arrivino
4. **Ottimizza query** - usa indici se hai molti veicoli

---

**Implementato**: 2025-11-14
**Versione**: 2.0.0
**Autore**: Claude Code
