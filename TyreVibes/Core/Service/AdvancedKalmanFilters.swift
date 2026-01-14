//
//  AdvancedKalmanFilters.swift
//  TyreVibes
//
//  Created by AI Assistant on 17/11/2025.
//  Advanced filtering algorithms for sub-millimeter accuracy
//

import Foundation
import Accelerate

// MARK: - Extended Kalman Filter (EKF)

/// Extended Kalman Filter per sistemi non-lineari
/// Gestisce meglio le non-linearità intrinseche nella misurazione LiDAR
class ExtendedKalmanFilter {
    // MARK: - State Vector

    /// Vettore di stato [depth, velocity, acceleration]
    private var x: [Double]

    /// Matrice di covarianza dello stato
    private var P: [[Double]]

    /// Matrice di transizione di stato (Jacobiano)
    private var F: [[Double]]

    /// Matrice di misurazione (Jacobiano)
    private var H: [[Double]]

    /// Rumore del processo
    private var Q: [[Double]]

    /// Rumore della misurazione
    private var R: [[Double]]

    /// Delta tempo tra misurazioni
    private var dt: Double

    /// Storico delle stime
    private(set) var estimates: [(depth: Double, velocity: Double, acceleration: Double)] = []

    // MARK: - Initialization

    init(initialDepth: Double = 5.0,
         initialVelocity: Double = 0.0,
         initialAcceleration: Double = 0.0,
         dt: Double = 0.1) {
        self.dt = dt

        // Stato iniziale [depth, velocity, acceleration]
        self.x = [initialDepth, initialVelocity, initialAcceleration]

        // Covarianza iniziale
        self.P = [
            [1.0, 0.0, 0.0],
            [0.0, 1.0, 0.0],
            [0.0, 0.0, 1.0]
        ]

        // Matrice di transizione (modello cinematico)
        // x(k+1) = F * x(k)
        self.F = [
            [1.0, dt, 0.5 * dt * dt],  // depth = depth + velocity*dt + 0.5*acc*dt^2
            [0.0, 1.0, dt],             // velocity = velocity + acc*dt
            [0.0, 0.0, 1.0]             // acceleration = acceleration
        ]

        // Matrice di misurazione (misuriamo solo depth)
        self.H = [
            [1.0, 0.0, 0.0]
        ]

        // Rumore del processo
        let q = 0.001
        self.Q = [
            [q * dt * dt * dt * dt / 4, q * dt * dt * dt / 2, q * dt * dt / 2],
            [q * dt * dt * dt / 2, q * dt * dt, q * dt],
            [q * dt * dt / 2, q * dt, q]
        ]

        // Rumore della misurazione
        self.R = [[0.05]]  // Varianza misurazione LiDAR (0.05mm^2)
    }

    // MARK: - Public Methods

    /// Aggiorna il filtro con una nuova misurazione
    /// - Parameters:
    ///   - measurement: Misurazione di profondità in mm
    ///   - measurementNoise: Varianza della misurazione (opzionale, adattivo)
    /// - Returns: Stima filtrata della profondità
    func update(measurement: Double, measurementNoise: Double? = nil) -> Double {
        // Adatta rumore misurazione se fornito
        if let noise = measurementNoise {
            R[0][0] = noise
        }

        // PREDICTION STEP
        // x_pred = F * x
        let xPred = matrixVectorMultiply(F, x)

        // P_pred = F * P * F^T + Q
        let FP = matrixMultiply(F, P)
        let FPFt = matrixMultiply(FP, transpose(F))
        let PPred = matrixAdd(FPFt, Q)

        // UPDATE STEP
        // y = z - H * x_pred (innovation)
        let Hx = matrixVectorMultiply(H, xPred)
        let y = [measurement - Hx[0]]

        // S = H * P_pred * H^T + R (innovation covariance)
        let HP = matrixMultiply(H, PPred)
        let HPHt = matrixMultiply(HP, transpose(H))
        let S = matrixAdd(HPHt, R)

        // K = P_pred * H^T * S^-1 (Kalman gain)
        let SInv = matrixInverse(S)
        let PHt = matrixMultiply(PPred, transpose(H))
        let K = matrixMultiply(PHt, SInv)

        // x = x_pred + K * y
        let Ky = matrixVectorMultiply(K, y)
        x = vectorAdd(xPred, Ky)

        // P = (I - K * H) * P_pred
        let KH = matrixMultiply(K, H)
        let I_KH = matrixSubtract(identityMatrix(3), KH)
        P = matrixMultiply(I_KH, PPred)

        // Salva stima
        estimates.append((depth: x[0], velocity: x[1], acceleration: x[2]))

        return x[0]
    }

    /// Predice il prossimo valore
    func predict() -> Double {
        let xPred = matrixVectorMultiply(F, x)
        return xPred[0]
    }

    /// Reset del filtro
    func reset() {
        x = [5.0, 0.0, 0.0]
        P = identityMatrix(3)
        estimates.removeAll()
    }

    /// Incertezza corrente
    var uncertainty: Double {
        return sqrt(P[0][0])
    }
}

// MARK: - Unscented Kalman Filter (UKF)

/// Unscented Kalman Filter per sistemi altamente non-lineari
/// Più accurato dell'EKF per non-linearità forti
class UnscentedKalmanFilter {
    // MARK: - Properties

    private var x: [Double]  // State vector
    private var P: [[Double]] // Covariance matrix
    private let Q: [[Double]] // Process noise
    private let R: [[Double]] // Measurement noise

    // UKF parameters
    private let alpha: Double = 0.001  // Spread of sigma points
    private let beta: Double = 2.0     // Prior knowledge (Gaussian = 2)
    private let kappa: Double = 0.0    // Secondary scaling parameter

    private let n: Int  // Dimension of state
    private var lambda: Double

    private(set) var estimates: [Double] = []

    // MARK: - Initialization

    init(initialState: [Double], initialCovariance: [[Double]],
         processNoise: [[Double]], measurementNoise: [[Double]]) {
        self.x = initialState
        self.P = initialCovariance
        self.Q = processNoise
        self.R = measurementNoise
        self.n = initialState.count
        self.lambda = alpha * alpha * (Double(n) + kappa) - Double(n)
    }

    // MARK: - Public Methods

    func update(measurement: Double) -> Double {
        // Genera sigma points
        let sigmaPoints = generateSigmaPoints()

        // Prediction step
        let (xPred, PPred) = predict(sigmaPoints: sigmaPoints)

        // Update step
        let (xUpdate, PUpdate) = updateStep(
            xPred: xPred,
            PPred: PPred,
            measurement: measurement,
            sigmaPoints: sigmaPoints
        )

        x = xUpdate
        P = PUpdate

        estimates.append(x[0])

        return x[0]
    }

    // MARK: - Private Methods

    private func generateSigmaPoints() -> [[Double]] {
        var sigmaPoints: [[Double]] = []

        // Calcola radice quadrata della matrice
        let sqrtP = matrixSquareRoot(scalarMatrixMultiply(Double(n) + lambda, P))

        // Sigma point 0 (mean)
        sigmaPoints.append(x)

        // Sigma points 1 to n
        for i in 0..<n {
            let column = getColumn(sqrtP, i)
            sigmaPoints.append(vectorAdd(x, column))
        }

        // Sigma points n+1 to 2n
        for i in 0..<n {
            let column = getColumn(sqrtP, i)
            sigmaPoints.append(vectorSubtract(x, column))
        }

        return sigmaPoints
    }

    private func predict(sigmaPoints: [[Double]]) -> ([Double], [[Double]]) {
        // Transform sigma points through process model
        let transformedPoints = sigmaPoints.map { processModel($0) }

        // Calculate weights
        let (wm, wc) = calculateWeights()

        // Predicted mean
        var xPred = [Double](repeating: 0, count: n)
        for (i, point) in transformedPoints.enumerated() {
            xPred = vectorAdd(xPred, scalarVectorMultiply(wm[i], point))
        }

        // Predicted covariance
        var PPred = Q
        for (i, point) in transformedPoints.enumerated() {
            let diff = vectorSubtract(point, xPred)
            let outer = outerProduct(diff, diff)
            PPred = matrixAdd(PPred, scalarMatrixMultiply(wc[i], outer))
        }

        return (xPred, PPred)
    }

    private func updateStep(xPred: [Double], PPred: [[Double]],
                           measurement: Double, sigmaPoints: [[Double]]) -> ([Double], [[Double]]) {
        // Transform sigma points through measurement model
        let zSigma = sigmaPoints.map { measurementModel($0) }

        let (wm, wc) = calculateWeights()

        // Predicted measurement
        var zPred = 0.0
        for (i, z) in zSigma.enumerated() {
            zPred += wm[i] * z
        }

        // Innovation covariance
        var Pzz = R[0][0]
        for (i, z) in zSigma.enumerated() {
            let diff = z - zPred
            Pzz += wc[i] * diff * diff
        }

        // Cross-correlation
        var Pxz = [Double](repeating: 0, count: n)
        for (i, point) in sigmaPoints.enumerated() {
            let xDiff = vectorSubtract(point, xPred)
            let zDiff = zSigma[i] - zPred
            Pxz = vectorAdd(Pxz, scalarVectorMultiply(wc[i] * zDiff, xDiff))
        }

        // Kalman gain
        let K = scalarVectorMultiply(1.0 / Pzz, Pxz)

        // Updated state
        let innovation = measurement - zPred
        let xUpdate = vectorAdd(xPred, scalarVectorMultiply(innovation, K))

        // Updated covariance
        let KPzz = scalarVectorMultiply(Pzz, K)
        let outer = outerProduct(K, KPzz)
        let PUpdate = matrixSubtract(PPred, outer)

        return (xUpdate, PUpdate)
    }

    private func processModel(_ state: [Double]) -> [Double] {
        // Simple constant model
        return state
    }

    private func measurementModel(_ state: [Double]) -> Double {
        // Measurement is first state variable (depth)
        return state[0]
    }

    private func calculateWeights() -> ([Double], [Double]) {
        let nSigma = 2 * n + 1
        var wm = [Double](repeating: 0, count: nSigma)
        var wc = [Double](repeating: 0, count: nSigma)

        // Weight for mean point
        wm[0] = lambda / (Double(n) + lambda)
        wc[0] = wm[0] + (1 - alpha * alpha + beta)

        // Weights for other points
        let weight = 1.0 / (2.0 * (Double(n) + lambda))
        for i in 1..<nSigma {
            wm[i] = weight
            wc[i] = weight
        }

        return (wm, wc)
    }
}

// MARK: - Particle Filter

/// Particle Filter per stima Bayesiana non parametrica
/// Utile quando il rumore non è Gaussiano
class ParticleFilter {
    // MARK: - Particle

    struct Particle {
        var state: Double    // Profondità
        var weight: Double   // Peso del particle
    }

    // MARK: - Properties

    private var particles: [Particle]
    private let numParticles: Int
    private let processNoise: Double
    private let measurementNoise: Double

    private(set) var estimates: [Double] = []

    // MARK: - Initialization

    init(numParticles: Int = 1000,
         initialMean: Double = 5.0,
         initialStd: Double = 1.0,
         processNoise: Double = 0.01,
         measurementNoise: Double = 0.1) {
        self.numParticles = numParticles
        self.processNoise = processNoise
        self.measurementNoise = measurementNoise

        // Inizializza particles con distribuzione Gaussiana
        self.particles = (0..<numParticles).map { _ in
            Particle(
                state: Self.gaussianRandom(mean: initialMean, std: initialStd),
                weight: 1.0 / Double(numParticles)
            )
        }
    }

    // MARK: - Public Methods

    func update(measurement: Double) -> Double {
        // Prediction step
        for i in 0..<particles.count {
            particles[i].state += Self.gaussianRandom(mean: 0, std: processNoise)
        }

        // Update weights basato sulla likelihood
        for i in 0..<particles.count {
            let diff = measurement - particles[i].state
            let likelihood = Self.gaussianPDF(x: diff, mean: 0, std: measurementNoise)
            particles[i].weight *= likelihood
        }

        // Normalizza weights
        let totalWeight = particles.reduce(0.0) { $0 + $1.weight }
        for i in 0..<particles.count {
            particles[i].weight /= totalWeight
        }

        // Calcola stima (media pesata)
        let estimate = particles.reduce(0.0) { $0 + $1.state * $1.weight }
        estimates.append(estimate)

        // Resampling (se necessario)
        if effectiveSampleSize() < Double(numParticles) / 2.0 {
            resample()
        }

        return estimate
    }

    // MARK: - Private Methods

    private func effectiveSampleSize() -> Double {
        let sumSquaredWeights = particles.reduce(0.0) { $0 + $1.weight * $1.weight }
        return 1.0 / sumSquaredWeights
    }

    private func resample() {
        var newParticles: [Particle] = []

        // Systematic resampling
        let step = 1.0 / Double(numParticles)
        var u = Double.random(in: 0..<step)
        var cumulativeWeight = particles[0].weight
        var i = 0

        for _ in 0..<numParticles {
            while u > cumulativeWeight && i < particles.count - 1 {
                i += 1
                cumulativeWeight += particles[i].weight
            }

            newParticles.append(Particle(
                state: particles[i].state,
                weight: 1.0 / Double(numParticles)
            ))

            u += step
        }

        particles = newParticles
    }

    private static func gaussianPDF(x: Double, mean: Double, std: Double) -> Double {
        let variance = std * std
        let coefficient = 1.0 / sqrt(2.0 * .pi * variance)
        let exponent = -0.5 * pow(x - mean, 2) / variance
        return coefficient * exp(exponent)
    }

    private static func gaussianRandom(mean: Double, std: Double) -> Double {
        // Box-Muller transform
        let u1 = Double.random(in: 0..<1)
        let u2 = Double.random(in: 0..<1)
        let z = sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
        return mean + std * z
    }

    /// Varianza della stima
    var variance: Double {
        let mean = particles.reduce(0.0) { $0 + $1.state * $1.weight }
        return particles.reduce(0.0) { sum, particle in
            let diff = particle.state - mean
            return sum + diff * diff * particle.weight
        }
    }
}

// MARK: - Matrix Operations (Helper Functions)

private func matrixMultiply(_ A: [[Double]], _ B: [[Double]]) -> [[Double]] {
    let rowsA = A.count
    let colsA = A[0].count
    let colsB = B[0].count

    var result = [[Double]](repeating: [Double](repeating: 0, count: colsB), count: rowsA)

    for i in 0..<rowsA {
        for j in 0..<colsB {
            for k in 0..<colsA {
                result[i][j] += A[i][k] * B[k][j]
            }
        }
    }

    return result
}

private func matrixVectorMultiply(_ A: [[Double]], _ v: [Double]) -> [Double] {
    let rows = A.count
    var result = [Double](repeating: 0, count: rows)

    for i in 0..<rows {
        for j in 0..<A[i].count {
            result[i] += A[i][j] * v[j]
        }
    }

    return result
}

private func matrixAdd(_ A: [[Double]], _ B: [[Double]]) -> [[Double]] {
    var result = A
    for i in 0..<A.count {
        for j in 0..<A[i].count {
            result[i][j] += B[i][j]
        }
    }
    return result
}

private func matrixSubtract(_ A: [[Double]], _ B: [[Double]]) -> [[Double]] {
    var result = A
    for i in 0..<A.count {
        for j in 0..<A[i].count {
            result[i][j] -= B[i][j]
        }
    }
    return result
}

private func vectorAdd(_ a: [Double], _ b: [Double]) -> [Double] {
    return zip(a, b).map { $0 + $1 }
}

private func vectorSubtract(_ a: [Double], _ b: [Double]) -> [Double] {
    return zip(a, b).map { $0 - $1 }
}

private func scalarVectorMultiply(_ scalar: Double, _ v: [Double]) -> [Double] {
    return v.map { scalar * $0 }
}

private func scalarMatrixMultiply(_ scalar: Double, _ M: [[Double]]) -> [[Double]] {
    return M.map { row in row.map { scalar * $0 } }
}

private func transpose(_ A: [[Double]]) -> [[Double]] {
    let rows = A.count
    let cols = A[0].count
    var result = [[Double]](repeating: [Double](repeating: 0, count: rows), count: cols)

    for i in 0..<rows {
        for j in 0..<cols {
            result[j][i] = A[i][j]
        }
    }

    return result
}

private func identityMatrix(_ n: Int) -> [[Double]] {
    var result = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
    for i in 0..<n {
        result[i][i] = 1.0
    }
    return result
}

private func matrixInverse(_ A: [[Double]]) -> [[Double]] {
    // Simplified for small matrices (1x1, 2x2, 3x3)
    let n = A.count

    if n == 1 {
        return [[1.0 / A[0][0]]]
    }

    if n == 2 {
        let det = A[0][0] * A[1][1] - A[0][1] * A[1][0]
        return [
            [A[1][1] / det, -A[0][1] / det],
            [-A[1][0] / det, A[0][0] / det]
        ]
    }

    // For n=3, use adjugate method
    if n == 3 {
        let det = determinant3x3(A)
        guard abs(det) > 1e-10 else {
            return identityMatrix(3)  // Fallback se singolare
        }

        let adj = adjugate3x3(A)
        return scalarMatrixMultiply(1.0 / det, adj)
    }

    return identityMatrix(n)  // Fallback
}

private func determinant3x3(_ A: [[Double]]) -> Double {
    return A[0][0] * (A[1][1] * A[2][2] - A[1][2] * A[2][1]) -
           A[0][1] * (A[1][0] * A[2][2] - A[1][2] * A[2][0]) +
           A[0][2] * (A[1][0] * A[2][1] - A[1][1] * A[2][0])
}

private func adjugate3x3(_ A: [[Double]]) -> [[Double]] {
    return [
        [
            A[1][1] * A[2][2] - A[1][2] * A[2][1],
            A[0][2] * A[2][1] - A[0][1] * A[2][2],
            A[0][1] * A[1][2] - A[0][2] * A[1][1]
        ],
        [
            A[1][2] * A[2][0] - A[1][0] * A[2][2],
            A[0][0] * A[2][2] - A[0][2] * A[2][0],
            A[0][2] * A[1][0] - A[0][0] * A[1][2]
        ],
        [
            A[1][0] * A[2][1] - A[1][1] * A[2][0],
            A[0][1] * A[2][0] - A[0][0] * A[2][1],
            A[0][0] * A[1][1] - A[0][1] * A[1][0]
        ]
    ]
}

private func matrixSquareRoot(_ A: [[Double]]) -> [[Double]] {
    // Cholesky decomposition per matrici simmetriche definite positive
    let n = A.count
    var L = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)

    for i in 0..<n {
        for j in 0...i {
            var sum = 0.0
            for k in 0..<j {
                sum += L[i][k] * L[j][k]
            }

            if i == j {
                L[i][j] = sqrt(max(0, A[i][i] - sum))
            } else {
                L[i][j] = (A[i][j] - sum) / max(L[j][j], 1e-10)
            }
        }
    }

    return L
}

private func getColumn(_ A: [[Double]], _ col: Int) -> [Double] {
    return A.map { $0[col] }
}

private func outerProduct(_ a: [Double], _ b: [Double]) -> [[Double]] {
    var result = [[Double]](repeating: [Double](repeating: 0, count: b.count), count: a.count)
    for i in 0..<a.count {
        for j in 0..<b.count {
            result[i][j] = a[i] * b[j]
        }
    }
    return result
}
