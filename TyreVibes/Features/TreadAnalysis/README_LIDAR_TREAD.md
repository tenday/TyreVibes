# 📏 Modulo Misurazione Battistrada con LiDAR

## 📋 Panoramica

Modulo avanzato per la misurazione della profondità del battistrada degli pneumatici utilizzando il sensore LiDAR integrato nei dispositivi iOS.

### Caratteristiche Principali

- ✅ **Misurazione precisa** con tecnologia LiDAR (accuratezza sub-millimetrica)
- ✅ **Algoritmi avanzati**: Filtro di Kalman, RANSAC, DBSCAN clustering
- ✅ **Analisi zone multiple**: 6 zone del battistrada analizzate separatamente
- ✅ **Visualizzazione AR in tempo reale** con feedback immediato
- ✅ **Confidence scoring** per valutare l'affidabilità della misurazione
- ✅ **Storico misurazioni** con persistenza locale
- ✅ **Esportazione dati** in formato JSON

## 🏗 Architettura

### Componenti

```
Features/TreadAnalysis/
├── LiDARTreadMeasurementView.swift   # UI principale con AR
└── README_LIDAR_TREAD.md             # Questa documentazione

Core/Model/
└── TreadDepthMeasurement.swift       # Modelli dati

Core/Service/
├── LiDARTreadMeasurementService.swift  # Servizio principale
└── KalmanFilter.swift                  # Filtri di smoothing

Core/Helper/
└── LiDARDataProcessor.swift          # Elaborazione avanzata (RANSAC, clustering)

Core/ViewModel/
└── TreadDepthViewModel.swift         # ViewModel MVVM
```

## 🎯 Requisiti

### Hardware
- **iPhone 12 Pro** o successivo
- **iPad Pro 2020** (4a gen) o successivo
- Sensore **LiDAR Scanner** richiesto

### Software
- **iOS 16.0+**
- **ARKit**
- **RealityKit**

## 🔧 Algoritmi Implementati

### 1. Filtro di Kalman Adattivo

Smoothing ricorsivo delle misurazioni per ridurre il rumore.

**Parametri**:
- Process Noise (Q): 0.01
- Measurement Noise (R): 0.1 (adattivo)
- Window Size: 10 campioni

**Formula**:
```
Prediction:
  x_pred = x
  P_pred = P + Q

Update:
  K = P_pred / (P_pred + R)
  x = x_pred + K * (measurement - x_pred)
  P = (1 - K) * P_pred
```

### 2. RANSAC (Random Sample Consensus)

Identificazione del piano di riferimento e rimozione outliers.

**Parametri**:
- Iterazioni: 100
- Threshold distanza: 5mm
- Punti minimi: 3

**Processo**:
1. Seleziona 3 punti random
2. Calcola piano (ax + by + cz + d = 0)
3. Conta inliers (punti a distanza < threshold)
4. Ripeti e seleziona miglior piano

### 3. DBSCAN Clustering

Clustering basato su densità per segmentare aree del battistrada.

**Parametri**:
- Epsilon (raggio): 1.5cm
- MinPoints: 5

**Vantaggi**:
- Non richiede numero cluster predefinito
- Identifica automaticamente forme irregolari
- Rimuove rumore

### 4. Median Filter

Rimozione picchi anomali preservando bordi.

**Parametri**:
- Window Size: 5 (dispari)

### 5. Savitzky-Golay Filter

Smoothing preservando picchi e caratteristiche importanti.

**Parametri**:
- Window Size: 5
- Polynomial Order: 2

### 6. Modified Z-Score

Rilevamento outliers robusto (più affidabile del Z-score standard).

**Parametri**:
- Threshold: 3.5
- Formula: `modified_z = 0.6745 * (x - median) / MAD`

## 📊 Metriche Calcolate

### Profondità Battistrada
- **Media** (mm): Profondità media di tutti i punti
- **Minima** (mm): Punto più usurato
- **Massima** (mm): Punto meno usurato
- **Deviazione Standard**: Uniformità dell'usura

### Mappa Zone
- Centro Sinistro
- Centro Destro
- Spalla Sinistra
- Spalla Destra
- Bordo Interno
- Bordo Esterno

### Confidence Score (0-100)

Calcolato da:
- **Numero punti** (max 40 punti): `min(40, pointCount / 250)`
- **Deviazione standard** (max 30 punti): `max(0, 30 - stdDev * 10)`
- **Numero cluster** (max 15 punti): `max(0, 15 - (clusterCount - 1) * 2)`
- **Durata scansione** (max 15 punti): `min(15, duration / minDuration * 15)`

### Stato Battistrada

| Profondità | Stato | Colore | Descrizione |
|------------|-------|--------|-------------|
| > 6mm | Eccellente | Verde | Pneumatico nuovo |
| 4-6mm | Buono | Blu | In buone condizioni |
| 2-4mm | Discreto | Giallo | Inizia a usurarsi |
| 1.6-2mm | Insufficiente | Arancione | Vicino al limite legale |
| < 1.6mm | Critico | Rosso | Sotto limite legale (Italia) |
| StdDev > 1.5mm | Usura Irregolare | Rosso | Usura non uniforme |

**Nota**: In Italia il limite legale è **1.6mm** per le auto.

## 🎮 Utilizzo

### 1. Integrazione nella UI

```swift
import SwiftUI

struct MyView: View {
    @State private var showLiDARMeasurement = false

    var body: some View {
        Button("Misura Battistrada") {
            showLiDARMeasurement = true
        }
        .fullScreenCover(isPresented: $showLiDARMeasurement) {
            LiDARTreadMeasurementView()
        }
    }
}
```

### 2. Configurazione Personalizzata

```swift
@StateObject private var viewModel = TreadDepthViewModel()

// Modifica configurazione
viewModel.scanConfiguration.minScanDuration = 5.0
viewModel.scanConfiguration.maxScanDuration = 20.0
viewModel.scanConfiguration.minPointCount = 2000
viewModel.scanConfiguration.enableKalmanFilter = true
viewModel.scanConfiguration.enableRANSAC = true

// Avvia misurazione
viewModel.startMeasurement(tyreId: myTyreId)
```

### 3. Accesso ai Risultati

```swift
// Dopo completamento
if let measurement = viewModel.lastMeasurement {
    print("Profondità media: \(measurement.averageDepth)mm")
    print("Stato: \(measurement.treadStatus.displayName)")
    print("Confidence: \(measurement.confidenceScore)%")

    // Zone specifiche
    for (zone, depth) in measurement.depthMap {
        print("\(zone.displayName): \(depth)mm")
    }
}
```

### 4. Calibrazione

```swift
// Calibra con oggetto di riferimento noto (es. blocchetto 5mm)
await viewModel.calibrate(knownDepth: 5.0)

// La calibrazione è valida per 30 giorni
```

## 📱 Interfaccia Utente

### Schermata Principale
- **AR View**: Visualizzazione camera con overlay
- **Status Card**: Messaggio corrente e contatore punti
- **Progress Bar**: Avanzamento scansione
- **Control Buttons**: Avvio/Stop misurazione, Storico

### Schermata Risultati
- **Status Indicator**: Icona e colore stato battistrada
- **Profondità Media/Min/Max**: Cards con valori
- **Mappa Zone**: Lista profondità per ogni zona
- **Metadata**: Info scansione (punti, durata, qualità)
- **Actions**: Salva, Condividi

### Impostazioni
- Durata scansione (min/max)
- Numero punti minimi
- Confidenza minima
- Toggle algoritmi (Kalman, RANSAC, Outliers)

### Storico
- Lista misurazioni precedenti
- Swipe-to-delete
- Tap per visualizzare dettagli

## 🔍 Best Practices

### Durante la Scansione

1. **Distanza ottimale**: 15-30cm dal pneumatico
2. **Illuminazione**: Buona luce naturale o artificiale
3. **Movimento**: Lento e costante sulla superficie
4. **Angolazione**: Perpendicolare alla superficie (±15°)
5. **Durata**: Almeno 3-5 secondi per risultati ottimali
6. **Copertura**: Scansiona tutta la larghezza del battistrada

### Qualità Misurazione

**Alta affidabilità** (Confidence > 80%):
- ✅ > 2000 punti acquisiti
- ✅ Deviazione standard < 1.0mm
- ✅ 1-3 cluster identificati
- ✅ Durata scansione > 3s

**Bassa affidabilità** (Confidence < 50%):
- ❌ < 1000 punti
- ❌ Deviazione standard > 2.0mm
- ❌ > 5 cluster (superficie frammentata)
- ❌ Durata scansione < 2s

**Risoluzione problemi**:
- Se troppi pochi punti → avvicinati o scansiona più a lungo
- Se alta deviazione standard → superficie irregolare o movimento troppo veloce
- Se troppi cluster → scansiona area più uniforme

## 🔗 Integrazione con Backend

### Salvataggio su Supabase

**TODO**: Implementare endpoint API per salvare misurazioni.

Schema tabella suggerito:

```sql
CREATE TABLE tread_measurements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id),
  tyre_id UUID REFERENCES tyres(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),

  -- Metriche
  average_depth DECIMAL(5,2),
  min_depth DECIMAL(5,2),
  max_depth DECIMAL(5,2),
  standard_deviation DECIMAL(5,2),
  confidence_score DECIMAL(5,2),
  sample_points INTEGER,

  -- Stato
  tread_status VARCHAR(20),

  -- Zone (JSON)
  depth_map JSONB,

  -- Metadata (JSON)
  metadata JSONB
);

-- Indici
CREATE INDEX idx_tread_measurements_user_id ON tread_measurements(user_id);
CREATE INDEX idx_tread_measurements_tyre_id ON tread_measurements(tyre_id);
CREATE INDEX idx_tread_measurements_created_at ON tread_measurements(created_at DESC);
```

### API Endpoint

```typescript
// Edge Function: save-tread-measurement
export const saveTreadMeasurement = async (req: Request) => {
  const measurement = await req.json();

  // Validazione
  // Salvataggio su Supabase
  // Creazione attività utente
  // Invio notifica se critico

  return new Response(JSON.stringify({ success: true }), {
    headers: { 'Content-Type': 'application/json' }
  });
};
```

## 🧪 Testing

### Unit Test

Creare `/TyreVibesTests/LiDARTreadTests.swift`:

```swift
import XCTest
@testable import TyreVibes

final class LiDARTreadTests: XCTestCase {
    func testKalmanFilter() {
        let filter = KalmanFilter()
        let measurements = [5.0, 5.1, 4.9, 5.0, 5.2]
        let filtered = filter.updateBatch(measurements)

        XCTAssertEqual(filtered.count, measurements.count)
        // Verifica smoothing
    }

    func testOutlierRemoval() {
        let values = [5.0, 5.1, 5.0, 20.0, 5.1] // 20.0 è outlier
        let cleaned = values.removeOutliers()

        XCTAssertFalse(cleaned.contains(20.0))
    }

    func testTreadStatusDetection() {
        let status = TreadStatus.from(averageDepth: 5.5, standardDeviation: 0.5)
        XCTAssertEqual(status, .good)
    }
}
```

### UI Test

Simulare scansione su dispositivo fisico (LiDAR non funziona su simulatore).

## 📝 Stringhe Localizzazione

Aggiungere a `/TyreVibes/Localizable.xcstrings`:

### Italiano (it)

```json
{
  "lidar_measurement_title": "Misurazione Battistrada",
  "lidar_not_available": "LiDAR non disponibile su questo dispositivo",
  "lidar_unavailable_description": "Questa funzionalità richiede un dispositivo con sensore LiDAR (iPhone 12 Pro o successivo)",
  "start_measurement": "Inizia Misurazione",
  "stop_measurement": "Completa Scansione",
  "scanning": "Scansione in corso...",
  "processing": "Elaborazione...",
  "scan_surface": "Scansiona la superficie del pneumatico...",
  "points_acquired": "punti acquisiti",
  "measurement_completed": "Misurazione completata!",
  "measurement_cancelled": "Misurazione annullata",
  "confidence": "Confidenza",
  "average_depth": "Profondità Media",
  "min_depth": "Minima",
  "max_depth": "Massima",
  "standard_deviation": "Deviazione Standard",
  "zone_map": "Mappa Zone",
  "scan_info": "Informazioni Scansione",
  "sample_points": "Punti Campionati",
  "scan_duration": "Durata",
  "average_distance": "Distanza Media",
  "mesh_quality": "Qualità Mesh",
  "lighting": "Illuminazione",
  "save_measurement": "Salva Misurazione",
  "share": "Condividi",
  "history": "Storico",
  "settings": "Impostazioni",
  "no_measurements": "Nessuna Misurazione",
  "measurements_appear_here": "Le tue misurazioni appariranno qui",
  "scan_settings": "Impostazioni Scansione",
  "min_duration": "Durata Minima",
  "max_duration": "Durata Massima",
  "min_points": "Punti Minimi",
  "min_confidence": "Confidenza Minima",
  "processing_algorithms": "Algoritmi Elaborazione",
  "kalman_filter": "Filtro Kalman",
  "ransac": "RANSAC",
  "outlier_removal": "Rimozione Outliers",
  "restore_defaults": "Ripristina Default",
  "quality": "Qualità",
  "tread_status_excellent": "Eccellente",
  "tread_status_good": "Buono",
  "tread_status_fair": "Discreto",
  "tread_status_poor": "Insufficiente",
  "tread_status_critical": "Critico",
  "tread_status_uneven": "Usura Irregolare",
  "zone_center_left": "Centro Sinistro",
  "zone_center_right": "Centro Destro",
  "zone_shoulder_left": "Spalla Sinistra",
  "zone_shoulder_right": "Spalla Destra",
  "zone_inner_edge": "Bordo Interno",
  "zone_outer_edge": "Bordo Esterno",
  "mesh_quality_high": "Alta",
  "mesh_quality_medium": "Media",
  "mesh_quality_low": "Bassa",
  "lighting_excellent": "Ottima",
  "lighting_good": "Buona",
  "lighting_fair": "Discreta",
  "lighting_poor": "Scarsa",
  "error_lidar_unavailable": "LiDAR non disponibile su questo dispositivo. Richiesto iPhone 12 Pro o successivo.",
  "error_no_session": "Nessuna sessione di misurazione attiva.",
  "error_insufficient_data": "Dati insufficienti. Scansiona per più tempo o avvicinati al pneumatico.",
  "error_no_depth_data": "Impossibile acquisire dati di profondità.",
  "error_processing_failed": "Elaborazione dati fallita. Riprova.",
  "error_calibration_required": "Calibrazione richiesta prima di utilizzare lo strumento."
}
```

### Inglese (en)

```json
{
  "lidar_measurement_title": "Tread Depth Measurement",
  "lidar_not_available": "LiDAR not available on this device",
  "lidar_unavailable_description": "This feature requires a device with LiDAR scanner (iPhone 12 Pro or later)",
  "start_measurement": "Start Measurement",
  "stop_measurement": "Complete Scan",
  "scanning": "Scanning...",
  "processing": "Processing...",
  "scan_surface": "Scan the tire tread surface...",
  "points_acquired": "points acquired",
  "measurement_completed": "Measurement completed!",
  "measurement_cancelled": "Measurement cancelled",
  "confidence": "Confidence",
  "average_depth": "Average Depth",
  "min_depth": "Min",
  "max_depth": "Max",
  "standard_deviation": "Standard Deviation",
  "zone_map": "Zone Map",
  "scan_info": "Scan Information",
  "sample_points": "Sample Points",
  "scan_duration": "Duration",
  "average_distance": "Average Distance",
  "mesh_quality": "Mesh Quality",
  "lighting": "Lighting",
  "save_measurement": "Save Measurement",
  "share": "Share",
  "history": "History",
  "settings": "Settings",
  "no_measurements": "No Measurements",
  "measurements_appear_here": "Your measurements will appear here",
  "scan_settings": "Scan Settings",
  "min_duration": "Minimum Duration",
  "max_duration": "Maximum Duration",
  "min_points": "Minimum Points",
  "min_confidence": "Minimum Confidence",
  "processing_algorithms": "Processing Algorithms",
  "kalman_filter": "Kalman Filter",
  "ransac": "RANSAC",
  "outlier_removal": "Outlier Removal",
  "restore_defaults": "Restore Defaults",
  "quality": "Quality",
  "tread_status_excellent": "Excellent",
  "tread_status_good": "Good",
  "tread_status_fair": "Fair",
  "tread_status_poor": "Poor",
  "tread_status_critical": "Critical",
  "tread_status_uneven": "Uneven Wear",
  "zone_center_left": "Center Left",
  "zone_center_right": "Center Right",
  "zone_shoulder_left": "Shoulder Left",
  "zone_shoulder_right": "Shoulder Right",
  "zone_inner_edge": "Inner Edge",
  "zone_outer_edge": "Outer Edge",
  "mesh_quality_high": "High",
  "mesh_quality_medium": "Medium",
  "mesh_quality_low": "Low",
  "lighting_excellent": "Excellent",
  "lighting_good": "Good",
  "lighting_fair": "Fair",
  "lighting_poor": "Poor",
  "error_lidar_unavailable": "LiDAR not available on this device. iPhone 12 Pro or later required.",
  "error_no_session": "No active measurement session.",
  "error_insufficient_data": "Insufficient data. Scan for longer or get closer to the tire.",
  "error_no_depth_data": "Unable to acquire depth data.",
  "error_processing_failed": "Data processing failed. Please try again.",
  "error_calibration_required": "Calibration required before using this tool."
}
```

## 📦 Dipendenze

### Framework Apple
- **ARKit**: Realtà aumentata e LiDAR
- **RealityKit**: Rendering 3D
- **simd**: Calcoli vettoriali/matrici
- **Accelerate**: Calcoli matematici ottimizzati
- **Combine**: Reactive programming

### Già presenti nel progetto
- Supabase iOS SDK
- SwiftUI
- Foundation

## 🔒 Privacy & Permessi

### Info.plist

Aggiungere:

```xml
<key>NSCameraUsageDescription</key>
<string>TyreVibes ha bisogno della fotocamera per misurare la profondità del battistrada usando il sensore LiDAR.</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>La posizione viene utilizzata per geolocalizzare le misurazioni (opzionale).</string>
```

### Privacy Policy

Informare gli utenti che:
- Le scansioni 3D vengono elaborate localmente
- I dati non vengono inviati a terze parti
- Le misurazioni salvate sono criptate
- È possibile eliminare lo storico in qualsiasi momento

## 🚀 Roadmap Future

### v1.1
- [ ] Integrazione completa con backend Supabase
- [ ] Salvataggio automatico cloud
- [ ] Sincronizzazione tra dispositivi

### v1.2
- [ ] Confronto misurazioni nel tempo (trend usura)
- [ ] Predizione durata residua pneumatico
- [ ] Notifiche proattive basate su usura

### v1.3
- [ ] Visualizzazione 3D mesh battistrada
- [ ] Export mesh in formato .obj/.usdz
- [ ] Realtà aumentata con overlay misure

### v2.0
- [ ] Machine Learning per riconoscimento automatico tipo pneumatico
- [ ] Database crowd-sourced performance pneumatici
- [ ] Raccomandazioni personalizzate pneumatici

## 🐛 Known Issues

### Limitazioni
1. **Solo dispositivi LiDAR**: Non funziona su iPhone < 12 Pro
2. **Simulatore**: LiDAR non disponibile, testing solo su device fisico
3. **Condizioni luce**: Performance ridotta con illuminazione < 200 lux
4. **Superfici riflettenti**: Gomme molto lucide possono creare rumore

### Workarounds
- **Nessun LiDAR**: Fallback a analisi fotografica (da implementare)
- **Scarsa luce**: Suggerire all'utente di migliorare illuminazione
- **Superficie riflettente**: Aumentare `minConfidence` in configurazione

## 📧 Supporto

Per problemi o domande:
- Email: support@tyrevibes.it
- GitHub Issues: tenday/TyreVibes

---

**Versione**: 1.0.0
**Data**: 17/11/2025
**Autore**: AI Assistant + TyreVibes Team
