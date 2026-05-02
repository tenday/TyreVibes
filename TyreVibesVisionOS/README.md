# TyreVibesVisionOS

Modulo iniziale per lo sviluppo visionOS di TyreVibes.

## Struttura

- `App`: entry point SwiftUI della nuova app visionOS.
- `Scenes`: spazi immersivi e viste RealityKit.
- `Features/Garage`: navigazione e selezione pneumatici.
- `Features/Inspection`: dashboard di ispezione e placeholder per LiDAR/scan.
- `Components`: componenti UI riusabili per visionOS.
- `Domain`: modelli leggeri del modulo.
- `Services`: store e adapter temporanei.
- `Support`: identificativi e utility del modulo.

## Prossimi innesti consigliati

1. Sostituire `VisionGarageStore` con adapter verso i dati reali del garage.
2. Spostare modelli condivisi in un package comune se iOS e visionOS devono usarli insieme.
3. Collegare assets 3D Reality Composer Pro nella cartella `Scenes`.
4. Aggiungere un flusso dedicato per LiDAR/scansione battistrada quando l'esperienza spaziale e' definita.
