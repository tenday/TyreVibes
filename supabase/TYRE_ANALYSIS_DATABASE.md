# 📊 Database Analisi Pneumatici - TyreVibes

> ⚠️ **NOTA**: Questa documentazione è specifica per **Supabase**.
>
> **Per database SQL standard** (MySQL, PostgreSQL, SQLite), consulta: `/database/README_DATABASE.md`

Documentazione completa delle tabelle per memorizzare le analisi dettagliate dei pneumatici.

## 📋 Indice

1. [Panoramica](#panoramica)
2. [Schema Tabelle](#schema-tabelle)
3. [Utilizzo](#utilizzo)
4. [API Service](#api-service)
5. [Esempi](#esempi)

---

## 🎯 Panoramica

Il sistema di analisi pneumatici permette di:

- ✅ Memorizzare misurazioni dettagliate della profondità del battistrada
- ✅ Calcolare e salvare la vita rimanente stimata
- ✅ Tracciare lo storico delle condizioni dei pneumatici
- ✅ Generare proiezioni future di usura
- ✅ Fornire raccomandazioni di manutenzione

### Architettura

```
┌─────────────────────┐
│  tyre_analyses      │  ← Tabella principale: analisi complete
└──────┬──────────────┘
       │
       ├─► tread_depth_measurements     (misurazioni dettagliate)
       ├─► tyre_lifecycle_projections   (proiezioni future)
       └─► tyre_recommendations         (raccomandazioni)
```

---

## 📊 Schema Tabelle

### 1. `tyre_analyses` - Analisi Complete

**Descrizione**: Memorizza le analisi complete dei pneumatici con tutti i dati aggregati.

**Campi Principali**:

| Campo | Tipo | Descrizione |
|-------|------|-------------|
| `id` | UUID | ID univoco analisi |
| `tyre_id` | INTEGER | Riferimento al pneumatico (FK → `tyres_vehicles`) |
| `user_id` | UUID | Riferimento all'utente (FK → `auth.users`) |
| `vehicle_id` | INTEGER | ID veicolo associato |
| `analysis_date` | TIMESTAMP | Data/ora dell'analisi |
| `analysis_type` | VARCHAR(50) | Tipo: `manual`, `ai_scan`, `automatic` |

**Profondità Battistrada** (in mm):
- `depth_front_left` - Anteriore sinistro
- `depth_front_right` - Anteriore destro
- `depth_rear_left` - Posteriore sinistro
- `depth_rear_right` - Posteriore destro
- `depth_average` - Media
- `depth_minimum` - Minimo

**Vita Rimanente**:
- `remaining_life_percentage` (0-100%)
- `remaining_life_km` (kilometri stimati)
- `remaining_life_months` (mesi stimati)
- `confidence_score` (0-1, confidenza della stima)

**Condizioni** (0-100%):
- `condition_front_left`
- `condition_front_right`
- `condition_rear_left`
- `condition_rear_right`

**Pattern Usura**:
- `wear_pattern`: `uniform`, `center_wear`, `edge_wear`, `patchy_wear`
- `wear_severity`: `minimal`, `moderate`, `significant`, `severe`, `critical`

**Metadati**:
- `notes` - Note aggiuntive
- `technician_name` - Nome tecnico (opzionale)
- `location_latitude` / `longitude` / `address` - Geolocalizzazione
- `image_urls` - Array di URL immagini
- `created_at` / `updated_at` - Timestamp creazione/modifica

**Vincoli**:
```sql
CHECK (depth_* >= 0 AND depth_* <= 15)
CHECK (condition_* >= 0 AND condition_* <= 100)
```

---

### 2. `tread_depth_measurements` - Misurazioni Dettagliate

**Descrizione**: Memorizza misurazioni punto per punto della profondità del battistrada.

| Campo | Tipo | Descrizione |
|-------|------|-------------|
| `id` | UUID | ID misurazione |
| `analysis_id` | UUID | Riferimento all'analisi (FK) |
| `tyre_position` | VARCHAR(10) | `FL`, `FR`, `RL`, `RR` |
| `measurement_x` | DECIMAL(5,4) | Posizione X normalizzata (0-1) |
| `measurement_y` | DECIMAL(5,4) | Posizione Y normalizzata (0-1) |
| `zone` | VARCHAR(50) | `center`, `inner_edge`, `outer_edge`, `shoulder` |
| `depth_mm` | DECIMAL(4,2) | Profondità in mm |
| `confidence` | DECIMAL(3,2) | Confidenza misurazione (0-1) |
| `measurement_method` | VARCHAR(50) | `manual`, `ai_vision`, `calibrated_tool` |

**Uso**: Per visualizzazioni dettagliate tipo heatmap o analisi avanzate.

---

### 3. `tyre_lifecycle_projections` - Proiezioni Lifecycle

**Descrizione**: Memorizza proiezioni future e dati storici della vita del pneumatico.

| Campo | Tipo | Descrizione |
|-------|------|-------------|
| `id` | UUID | ID proiezione |
| `analysis_id` | UUID | Riferimento all'analisi (FK) |
| `kilometers_from_now` | INTEGER | Km dal presente (negativo = storico) |
| `projected_depth` | DECIMAL(4,2) | Profondità prevista (mm) |
| `confidence` | DECIMAL(3,2) | Confidenza proiezione (0-1) |
| `is_projected` | BOOLEAN | `true` = futuro, `false` = storico |

**Esempio**:
```
km = -20000  → 20.000 km fa (storico)
km = 0       → Adesso
km = 15000   → Tra 15.000 km (futuro)
```

---

### 4. `tyre_recommendations` - Raccomandazioni

**Descrizione**: Raccomandazioni di manutenzione e sicurezza.

| Campo | Tipo | Descrizione |
|-------|------|-------------|
| `id` | UUID | ID raccomandazione |
| `analysis_id` | UUID | Riferimento all'analisi (FK) |
| `priority` | VARCHAR(20) | `critical`, `high`, `medium`, `low` |
| `category` | VARCHAR(50) | `safety`, `maintenance`, `performance`, `cost`, `legal` |
| `urgency` | VARCHAR(50) | `immediate`, `within_week`, `within_month`, `routine` |
| `title` | VARCHAR(200) | Titolo raccomandazione |
| `description` | TEXT | Descrizione dettagliata |
| `action_required` | TEXT | Azione da intraprendere |
| `status` | VARCHAR(20) | `pending`, `acknowledged`, `completed`, `dismissed` |
| `completed_at` | TIMESTAMP | Data completamento |

---

## 🔒 Row Level Security (RLS)

Tutte le tabelle hanno **RLS abilitato** con policy che garantiscono:

✅ Gli utenti vedono **solo le proprie analisi**
✅ Inserimento/modifica solo per dati propri
✅ Eliminazione solo dei propri record

**Policy Esempio**:
```sql
CREATE POLICY "Users can view their own tyre analyses"
    ON public.tyre_analyses
    FOR SELECT
    USING (auth.uid() = user_id);
```

---

## 💾 Utilizzo

### Eseguire la Migration

```bash
# 1. Accedi a Supabase Dashboard
https://supabase.com/dashboard/project/jbcbrnegmqraivdfmlsn

# 2. SQL Editor → New Query
# 3. Copia il contenuto di: supabase/migrations/add_tyre_analysis_tables.sql
# 4. Run
```

### Verificare Installazione

```sql
-- Verifica tabelle create
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name LIKE 'tyre_%';

-- Output atteso:
-- tyre_analyses
-- tread_depth_measurements
-- tyre_lifecycle_projections
-- tyre_recommendations

-- Verifica RLS attivo
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename LIKE 'tyre_%';
```

---

## 🔧 API Service

### TyreAnalysisService.swift

Il service Swift fornisce metodi per interagire con le tabelle.

#### Metodi Principali

```swift
let service = TyreAnalysisService.shared

// ✅ Salva una nuova analisi
let analysis = try await service.saveAnalysis(input)

// 📖 Recupera l'ultima analisi per un pneumatico
let latest = try await service.getLatestAnalysis(forTyreId: tyreId)

// 📚 Recupera storico analisi
let history = try await service.getAnalysisHistory(forTyreId: tyreId)

// 💾 Salva proiezioni lifecycle
try await service.saveLifecycleProjections(
    analysisId: analysisId,
    projections: [(km: Int, depth: Double, confidence: Double, isProjected: Bool)]
)

// 🗑️ Elimina analisi
try await service.deleteAnalysis(id: analysisId)
```

---

## 📝 Esempi

### Esempio 1: Salvare una Nuova Analisi

```swift
let input = TyreAnalysisInput(
    tyreId: 123,
    userId: currentUserId,
    vehicleId: 456,
    analysisType: "automatic",
    depthFrontLeft: 7.2,
    depthFrontRight: 7.0,
    depthRearLeft: 5.8,
    depthRearRight: 5.5,
    depthAverage: 6.375,
    depthMinimum: 5.5,
    remainingLifePercentage: 75.0,
    remainingLifeKm: 12000,
    remainingLifeMonths: 10,
    confidenceScore: 0.85,
    conditionFrontLeft: 90,
    conditionFrontRight: 88,
    conditionRearLeft: 75,
    conditionRearRight: 72,
    wearPattern: "uniform",
    wearSeverity: "moderate",
    notes: "Analisi automatica generata dall'app",
    technicianName: nil
)

let savedAnalysis = try await TyreAnalysisService.shared.saveAnalysis(input)
print("✅ Analisi salvata con ID: \(savedAnalysis.id)")
```

### Esempio 2: Recuperare Dati dal Database

```swift
// Carica l'ultima analisi
if let analysis = try await service.getLatestAnalysis(forTyreId: tyreId) {
    print("📊 Profondità media: \(analysis.depthAverage ?? 0) mm")
    print("🚗 Km rimanenti: \(analysis.remainingLifeKm ?? 0)")
    print("📅 Mesi rimanenti: \(analysis.remainingLifeMonths ?? 0)")

    // Carica proiezioni
    let projections = try await service.getLifecycleProjections(
        forAnalysisId: analysis.id
    )
    print("📈 Proiezioni: \(projections.count) punti")
}
```

### Esempio 3: Query SQL Dirette

```sql
-- Ultima analisi per ogni pneumatico
SELECT * FROM latest_tyre_analyses;

-- Statistiche utente
SELECT * FROM user_analysis_stats
WHERE user_id = 'uuid-utente';

-- Analisi con profondità critica
SELECT * FROM tyre_analyses
WHERE depth_minimum < 2.0
ORDER BY analysis_date DESC;

-- Storico analisi per un veicolo
SELECT
    ta.analysis_date,
    ta.depth_average,
    ta.remaining_life_km,
    tv.brand || ' ' || tv.model as tyre_name
FROM tyre_analyses ta
JOIN tyres_vehicles tv ON ta.tyre_id = tv.id
WHERE ta.vehicle_id = 123
ORDER BY ta.analysis_date DESC;
```

---

## 📈 Viste Predefinite

### `latest_tyre_analyses`
Mostra l'ultima analisi per ogni pneumatico.

```sql
SELECT * FROM latest_tyre_analyses
WHERE user_id = auth.uid();
```

### `user_analysis_stats`
Statistiche aggregate per utente.

```sql
SELECT
    total_analyses,        -- Totale analisi effettuate
    tyres_analyzed,        -- Numero pneumatici analizzati
    avg_depth,             -- Profondità media
    avg_remaining_life,    -- % vita media rimanente
    last_analysis_date     -- Data ultima analisi
FROM user_analysis_stats
WHERE user_id = auth.uid();
```

---

## 🔄 Workflow Applicazione

### Caricamento Dati in TyreDetailView

```swift
// 1. ViewModel inizializza
init(tyre: TyreRegistered) {
    self.tyre = tyre
}

// 2. View carica dati
.task {
    await viewModel.loadTyreData()
}

// 3. ViewModel controlla database
func loadTyreData() async {
    // Prova a caricare dal DB
    if let saved = try await service.getLatestAnalysis(forTyreId: tyre.id) {
        // Usa dati salvati
        loadFromSavedAnalysis(saved)
    } else {
        // Genera nuovi dati e salva
        generateAndSaveNewAnalysis()
    }
}
```

---

## 🚀 Best Practices

### ✅ DO

- Salvare sempre un'analisi completa quando disponibile
- Includere proiezioni lifecycle per grafici accurati
- Usare `analysis_type` per distinguere fonti dati
- Aggiornare `wear_pattern` e `wear_severity` per insights
- Salvare coordinate GPS se disponibili

### ❌ DON'T

- Non modificare analisi esistenti (crea sempre nuove)
- Non eliminare analisi storiche (utili per trend)
- Non salvare dati incompleti (almeno profondità)
- Non dimenticare di settare `confidence_score`

---

## 📊 Metriche e Monitoring

### Query Utili

```sql
-- Analisi per giorno (ultimi 30 giorni)
SELECT
    DATE(analysis_date) as day,
    COUNT(*) as analyses_count,
    AVG(depth_average) as avg_depth
FROM tyre_analyses
WHERE analysis_date > NOW() - INTERVAL '30 days'
GROUP BY DATE(analysis_date)
ORDER BY day DESC;

-- Pneumatici critici
SELECT
    ta.*,
    tv.brand || ' ' || tv.model as tyre
FROM tyre_analyses ta
JOIN tyres_vehicles tv ON ta.tyre_id = tv.id
WHERE ta.wear_severity IN ('severe', 'critical')
  AND ta.id IN (
      SELECT DISTINCT ON (tyre_id) id
      FROM tyre_analyses
      ORDER BY tyre_id, analysis_date DESC
  );
```

---

## 🆘 Troubleshooting

### Problema: RLS blocca le query

**Soluzione**: Verifica che `auth.uid()` corrisponda a `user_id`

```sql
-- Test identity
SELECT auth.uid();

-- Verifica policy
SELECT * FROM tyre_analyses WHERE user_id = auth.uid();
```

### Problema: Dati non salvati

**Soluzione**: Controlla log del service

```swift
// Abilita debug logging
print("💾 [TyreAnalysisService] Saving analysis...")
```

### Problema: Migration failed

**Soluzione**: Verifica dipendenze

```sql
-- Controlla che esista tyres_vehicles
SELECT * FROM information_schema.tables
WHERE table_name = 'tyres_vehicles';
```

---

## 📚 Riferimenti

- **Migration SQL**: `/supabase/migrations/add_tyre_analysis_tables.sql`
- **Service Swift**: `/TyreVibes/Core/Service/TyreAnalysisService.swift`
- **ViewModel**: `/TyreVibes/Core/ViewModel/TyreDetailViewModel.swift`
- **Supabase Dashboard**: https://supabase.com/dashboard

---

**Versione**: 1.0
**Data**: 2025-11-17
**Autore**: TyreVibes Team
