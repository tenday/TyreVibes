//
//  KalmanFilter.swift
//  TyreVibes
//
//  Created by AI Assistant on 17/11/2025.
//

import Foundation
import Accelerate

// MARK: - Kalman Filter

/// Filtro di Kalman per smoothing delle misurazioni di profondità
///
/// Il filtro di Kalman è un algoritmo ricorsivo che stima lo stato di un sistema dinamico
/// da una serie di misurazioni rumorose. Utilizzato qui per:
/// - Ridurre il rumore delle misurazioni LiDAR
/// - Prevedere valori futuri
/// - Aumentare l'accuratezza delle stime
class KalmanFilter {
    // MARK: - Properties

    /// Stima corrente dello stato (profondità in mm)
    private var x: Double

    /// Incertezza della stima
    private var P: Double

    /// Rumore del processo (quanto il sistema può cambiare)
    private let Q: Double

    /// Rumore della misurazione (quanto sono rumorose le misure)
    private let R: Double

    /// Guadagno di Kalman
    private var K: Double = 0.0

    /// Storico delle stime
    private(set) var estimates: [Double] = []

    /// Storico delle misurazioni raw
    private(set) var measurements: [Double] = []

    // MARK: - Initialization

    /// Inizializza il filtro di Kalman
    /// - Parameters:
    ///   - initialEstimate: Stima iniziale dello stato (profondità in mm)
    ///   - initialUncertainty: Incertezza iniziale
    ///   - processNoise: Rumore del processo (Q)
    ///   - measurementNoise: Rumore della misurazione (R)
    init(initialEstimate: Double = 5.0,
         initialUncertainty: Double = 1.0,
         processNoise: Double = 0.01,
         measurementNoise: Double = 0.1) {
        self.x = initialEstimate
        self.P = initialUncertainty
        self.Q = processNoise
        self.R = measurementNoise
    }

    // MARK: - Public Methods

    /// Aggiorna il filtro con una nuova misurazione
    /// - Parameter measurement: Nuova misurazione di profondità in mm
    /// - Returns: Stima filtrata della profondità
    func update(measurement: Double) -> Double {
        measurements.append(measurement)

        // PREDICTION STEP
        // x_pred = x (nessun modello di movimento)
        // P_pred = P + Q
        let xPred = x
        let PPred = P + Q

        // UPDATE STEP
        // K = P_pred / (P_pred + R)
        K = PPred / (PPred + R)

        // x = x_pred + K * (measurement - x_pred)
        x = xPred + K * (measurement - xPred)

        // P = (1 - K) * P_pred
        P = (1 - K) * PPred

        estimates.append(x)

        return x
    }

    /// Aggiorna il filtro con un batch di misurazioni
    /// - Parameter measurements: Array di misurazioni
    /// - Returns: Array di stime filtrate
    func updateBatch(_ measurements: [Double]) -> [Double] {
        return measurements.map { update(measurement: $0) }
    }

    /// Reset del filtro allo stato iniziale
    func reset(initialEstimate: Double = 5.0, initialUncertainty: Double = 1.0) {
        x = initialEstimate
        P = initialUncertainty
        K = 0.0
        estimates.removeAll()
        measurements.removeAll()
    }

    /// Predice il prossimo valore senza aggiornare lo stato
    /// - Returns: Predizione del prossimo valore
    func predict() -> Double {
        return x
    }

    /// Calcola l'incertezza attuale
    var uncertainty: Double {
        return P
    }

    /// Calcola la deviazione standard dell'incertezza
    var standardDeviation: Double {
        return sqrt(P)
    }
}

// MARK: - Adaptive Kalman Filter

/// Filtro di Kalman adattivo che regola automaticamente i parametri
/// basandosi sulle caratteristiche del segnale
class AdaptiveKalmanFilter: KalmanFilter {
    /// Finestra per calcolo statistiche adattive
    private let windowSize: Int

    /// Buffer circolare per misurazioni recenti
    private var recentMeasurements: [Double] = []

    init(initialEstimate: Double = 5.0,
         initialUncertainty: Double = 1.0,
         windowSize: Int = 10) {
        self.windowSize = windowSize
        super.init(
            initialEstimate: initialEstimate,
            initialUncertainty: initialUncertainty,
            processNoise: 0.01,
            measurementNoise: 0.1
        )
    }

    override func update(measurement: Double) -> Double {
        // Aggiungi al buffer circolare
        recentMeasurements.append(measurement)
        if recentMeasurements.count > windowSize {
            recentMeasurements.removeFirst()
        }

        // Adatta i parametri se abbiamo abbastanza dati
        if recentMeasurements.count >= windowSize {
            adaptParameters()
        }

        return super.update(measurement: measurement)
    }

    /// Adatta i parametri del filtro basandosi sulle statistiche recenti
    private func adaptParameters() {
        guard recentMeasurements.count >= 2 else { return }

        // Adatta R (rumore misurazione) basato sulla varianza osservata
        // Maggiore varianza = maggiore rumore = maggiore R
        // Il fattore 0.5 è un peso empirico per bilanciare la risposta
        // self.R = max(0.05, min(1.0, variance * 0.5))
    }
}

// MARK: - Multi-Dimensional Kalman Filter

/// Filtro di Kalman multidimensionale per filtrare posizioni 3D
class KalmanFilter3D {
    // MARK: - Properties

    /// Filtri indipendenti per X, Y, Z
    private let filterX: KalmanFilter
    private let filterY: KalmanFilter
    private let filterZ: KalmanFilter

    // MARK: - Initialization

    init(processNoise: Double = 0.01, measurementNoise: Double = 0.1) {
        self.filterX = KalmanFilter(
            initialEstimate: 0.0,
            initialUncertainty: 1.0,
            processNoise: processNoise,
            measurementNoise: measurementNoise
        )
        self.filterY = KalmanFilter(
            initialEstimate: 0.0,
            initialUncertainty: 1.0,
            processNoise: processNoise,
            measurementNoise: measurementNoise
        )
        self.filterZ = KalmanFilter(
            initialEstimate: 0.0,
            initialUncertainty: 1.0,
            processNoise: processNoise,
            measurementNoise: measurementNoise
        )
    }

    // MARK: - Public Methods

    /// Aggiorna con una nuova posizione 3D
    /// - Parameter position: Tupla (x, y, z)
    /// - Returns: Posizione filtrata
    func update(position: (x: Double, y: Double, z: Double)) -> (x: Double, y: Double, z: Double) {
        let filteredX = filterX.update(measurement: position.x)
        let filteredY = filterY.update(measurement: position.y)
        let filteredZ = filterZ.update(measurement: position.z)

        return (filteredX, filteredY, filteredZ)
    }

    /// Reset di tutti i filtri
    func reset() {
        filterX.reset()
        filterY.reset()
        filterZ.reset()
    }

    /// Incertezza totale (somma delle incertezze)
    var totalUncertainty: Double {
        return filterX.uncertainty + filterY.uncertainty + filterZ.uncertainty
    }
}

// MARK: - Kalman Smoother

/// Implementa il Rauch-Tung-Striebel (RTS) smoother
/// per elaborazione offline di batch di dati
class KalmanSmoother {
    // MARK: - Properties

    private let processNoise: Double
    private let measurementNoise: Double

    // MARK: - Initialization

    init(processNoise: Double = 0.01, measurementNoise: Double = 0.1) {
        self.processNoise = processNoise
        self.measurementNoise = measurementNoise
    }

    // MARK: - Public Methods

    /// Esegue smoothing RTS su un batch di misurazioni
    /// - Parameter measurements: Array di misurazioni
    /// - Returns: Array di valori smoothed
    func smooth(measurements: [Double]) -> [Double] {
        guard !measurements.isEmpty else { return [] }

        // FORWARD PASS (Kalman Filter)
        var forwardEstimates: [Double] = []
        var forwardUncertainties: [Double] = []

        let filter = KalmanFilter(
            initialEstimate: measurements[0],
            initialUncertainty: 1.0,
            processNoise: processNoise,
            measurementNoise: measurementNoise
        )

        for measurement in measurements {
            let estimate = filter.update(measurement: measurement)
            forwardEstimates.append(estimate)
            forwardUncertainties.append(filter.uncertainty)
        }

        // BACKWARD PASS (RTS Smoother)
        var smoothedEstimates = forwardEstimates
        var smoothedUncertainty = forwardUncertainties[forwardUncertainties.count - 1]

        for i in stride(from: measurements.count - 2, through: 0, by: -1) {
            let PPred = forwardUncertainties[i] + processNoise
            let C = forwardUncertainties[i] / PPred

            // Smoothed estimate
            smoothedEstimates[i] = forwardEstimates[i] +
                C * (smoothedEstimates[i + 1] - forwardEstimates[i])

            // Smoothed uncertainty
            smoothedUncertainty = forwardUncertainties[i] +
                C * C * (smoothedUncertainty - PPred)
        }

        return smoothedEstimates
    }
}

// MARK: - Statistics Extensions

extension Array where Element == Double {
    /// Calcola la media dell'array
    var mean: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }

    /// Calcola la varianza dell'array
    var variance: Double {
        guard count > 1 else { return 0 }
        let m = mean
        return map { pow($0 - m, 2) }.reduce(0, +) / Double(count - 1)
    }

    /// Calcola la deviazione standard dell'array
    var standardDeviation: Double {
        return sqrt(variance)
    }

    /// Calcola la mediana dell'array
    var median: Double {
        guard !isEmpty else { return 0 }
        let sorted = self.sorted()
        let mid = count / 2
        if count % 2 == 0 {
            return (sorted[mid - 1] + sorted[mid]) / 2
        } else {
            return sorted[mid]
        }
    }

    /// Rimuove outliers usando l'IQR method
    /// - Parameter multiplier: Moltiplicatore per IQR (default 1.5)
    /// - Returns: Array senza outliers
    func removeOutliers(multiplier: Double = 1.5) -> [Double] {
        guard count > 3 else { return self }

        let sorted = self.sorted()
        let q1Index = count / 4
        let q3Index = (count * 3) / 4

        let q1 = sorted[q1Index]
        let q3 = sorted[q3Index]
        let iqr = q3 - q1

        let lowerBound = q1 - multiplier * iqr
        let upperBound = q3 + multiplier * iqr

        return filter { $0 >= lowerBound && $0 <= upperBound }
    }
}
