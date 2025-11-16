# TyreVibes - Build Guide

## Quick Start

### Build Script (Raccomandato)

Usa lo script `build.sh` per lanciare facilmente la build:

```bash
# Build Debug APK (più veloce)
./build.sh debug

# Build Release APK
./build.sh release

# Build completa (Debug + Release)
./build.sh build

# Pulire e ricostruire
./build.sh rebuild

# Installare su dispositivo/emulatore
./build.sh install

# Build + Install
./build.sh run

# Verificare errori di compilazione
./build.sh compile

# Mostra errori
./build.sh errors

# Mostra tutti i comandi disponibili
./build.sh help
```

### Comandi Gradle Diretti

Se preferisci usare Gradle direttamente:

```bash
cd android

# Build Debug
./gradlew assembleDebug

# Build Release
./gradlew assembleRelease

# Build completa
./gradlew build

# Pulire
./gradlew clean

# Installare
./gradlew installDebug

# Test
./gradlew test

# Compilare solo Kotlin
./gradlew compileDebugKotlin
```

## Output della Build

### Debug APK
- **Posizione**: `android/app/build/outputs/apk/debug/app-debug.apk`
- **Uso**: Testing e sviluppo
- **Firma**: Debug keystore (automatico)

### Release APK
- **Posizione**: `android/app/build/outputs/apk/release/app-release-unsigned.apk`
- **Uso**: Produzione
- **Firma**: Richiede configurazione keystore

## Stato Attuale del Progetto

### ✅ Risolto
- Gradle Wrapper ricreato (8.9)
- Android Gradle Plugin aggiornato (8.7.3)
- Kotlin aggiornato (2.2.21)
- SDK aggiornato (35)
- Compose Compiler Plugin configurato
- Supabase SDK aggiornato (3.2.6)
- API Auth principali corrette

### ⚠️ In Corso
Il progetto ha circa **120 errori di compilazione** che devono essere risolti:

1. **ML Kit OCR** (~10 errori) - API Google ML Kit
2. **Modelli dati** (~30 errori) - PlateData, Vehicle models
3. **Compose UI** (~10 errori) - HorizontalDivider, componenti
4. **NetworkManager** (~20 errori) - Ktor Logging API
5. **Altri** (~50 errori) - Vari service e viewmodel

## Requisiti Sistema

- **Java**: 17 o superiore
- **Android SDK**: 26 (min) - 35 (target)
- **Gradle**: 8.9 (incluso nel wrapper)
- **Kotlin**: 2.2.21

## Troubleshooting

### Errore: Permission denied
```bash
chmod +x ./build.sh
chmod +x android/gradlew
```

### Errore: JAVA_HOME non impostato
```bash
export JAVA_HOME=/path/to/java/17
```

### Errore: Gradle daemon issues
```bash
cd android
./gradlew --stop
./gradlew clean
```

### Vedere tutti gli errori di compilazione
```bash
./build.sh errors
# oppure
cd android && ./gradlew compileDebugKotlin 2>&1 | grep "^e:"
```

## Configurazione IDE

### Android Studio
1. Apri `TyreVibes/android` come progetto Android
2. Attendi il sync di Gradle
3. Seleziona Build > Make Project

### IntelliJ IDEA
1. Apri `TyreVibes/android`
2. Seleziona "Import Gradle Project"
3. Usa Gradle wrapper

## Prossimi Passi

Per completare la build del progetto:

1. Correggere errori ML Kit OCR
2. Correggere modelli di dati (PlateData, Vehicle)
3. Aggiornare componenti Compose UI
4. Sistemare NetworkManager (Ktor Logging)
5. Risolvere errori rimanenti

## Supporto

Per problemi con la build:
- Controlla i log: `android/app/build/outputs/logs/`
- Verifica dipendenze: `./gradlew dependencies`
- Pulisci cache: `./gradlew clean --refresh-dependencies`
