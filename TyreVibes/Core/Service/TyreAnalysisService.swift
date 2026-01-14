//
//  TyreAnalysisService.swift
//  TyreVibes
//
//  Service per gestire le analisi dei pneumatici nel database
//

import Foundation

// MARK: - Models

struct TyreAnalysisRecord: Codable, Identifiable {
    let id: UUID
    let tyreId: Int
    let userId: UUID
    let vehicleId: Int

    // Metadata
    let analysisDate: Date
    let analysisType: String

    // Profondità battistrada
    let depthFrontLeft: Double?
    let depthFrontRight: Double?
    let depthRearLeft: Double?
    let depthRearRight: Double?
    let depthAverage: Double?
    let depthMinimum: Double?

    // Vita rimanente
    let remainingLifePercentage: Double?
    let remainingLifeKm: Int?
    let remainingLifeMonths: Int?
    let confidenceScore: Double?

    // Condizioni
    let conditionFrontLeft: Int?
    let conditionFrontRight: Int?
    let conditionRearLeft: Int?
    let conditionRearRight: Int?

    // Pattern usura
    let wearPattern: String?
    let wearSeverity: String?

    // Note
    let notes: String?
    let technicianName: String?

    // Geolocalizzazione
    let locationLatitude: Double?
    let locationLongitude: Double?
    let locationAddress: String?

    // Immagini
    let imageUrls: [String]?

    // Metadati
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case tyreId = "tyre_id"
        case userId = "user_id"
        case vehicleId = "vehicle_id"
        case analysisDate = "analysis_date"
        case analysisType = "analysis_type"
        case depthFrontLeft = "depth_front_left"
        case depthFrontRight = "depth_front_right"
        case depthRearLeft = "depth_rear_left"
        case depthRearRight = "depth_rear_right"
        case depthAverage = "depth_average"
        case depthMinimum = "depth_minimum"
        case remainingLifePercentage = "remaining_life_percentage"
        case remainingLifeKm = "remaining_life_km"
        case remainingLifeMonths = "remaining_life_months"
        case confidenceScore = "confidence_score"
        case conditionFrontLeft = "condition_front_left"
        case conditionFrontRight = "condition_front_right"
        case conditionRearLeft = "condition_rear_left"
        case conditionRearRight = "condition_rear_right"
        case wearPattern = "wear_pattern"
        case wearSeverity = "wear_severity"
        case notes
        case technicianName = "technician_name"
        case locationLatitude = "location_latitude"
        case locationLongitude = "location_longitude"
        case locationAddress = "location_address"
        case imageUrls = "image_urls"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct TyreAnalysisInput: Codable {
    let tyreId: Int
    let userId: UUID
    let vehicleId: Int
    let analysisType: String

    // Profondità battistrada
    let depthFrontLeft: Double?
    let depthFrontRight: Double?
    let depthRearLeft: Double?
    let depthRearRight: Double?
    let depthAverage: Double?
    let depthMinimum: Double?

    // Vita rimanente
    let remainingLifePercentage: Double?
    let remainingLifeKm: Int?
    let remainingLifeMonths: Int?
    let confidenceScore: Double?

    // Condizioni
    let conditionFrontLeft: Int?
    let conditionFrontRight: Int?
    let conditionRearLeft: Int?
    let conditionRearRight: Int?

    // Pattern usura
    let wearPattern: String?
    let wearSeverity: String?

    // Note
    let notes: String?
    let technicianName: String?

    enum CodingKeys: String, CodingKey {
        case tyreId = "tyre_id"
        case userId = "user_id"
        case vehicleId = "vehicle_id"
        case analysisType = "analysis_type"
        case depthFrontLeft = "depth_front_left"
        case depthFrontRight = "depth_front_right"
        case depthRearLeft = "depth_rear_left"
        case depthRearRight = "depth_rear_right"
        case depthAverage = "depth_average"
        case depthMinimum = "depth_minimum"
        case remainingLifePercentage = "remaining_life_percentage"
        case remainingLifeKm = "remaining_life_km"
        case remainingLifeMonths = "remaining_life_months"
        case confidenceScore = "confidence_score"
        case conditionFrontLeft = "condition_front_left"
        case conditionFrontRight = "condition_front_right"
        case conditionRearLeft = "condition_rear_left"
        case conditionRearRight = "condition_rear_right"
        case wearPattern = "wear_pattern"
        case wearSeverity = "wear_severity"
        case notes
        case technicianName = "technician_name"
    }
}

struct SupabaseTreadDepthMeasurement: Codable, Identifiable {
    let id: UUID
    let analysisId: UUID
    let tyrePosition: String
    let measurementX: Double?
    let measurementY: Double?
    let zone: String?
    let depthMm: Double
    let confidence: Double?
    let measurementMethod: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case analysisId = "analysis_id"
        case tyrePosition = "tyre_position"
        case measurementX = "measurement_x"
        case measurementY = "measurement_y"
        case zone
        case depthMm = "depth_mm"
        case confidence
        case measurementMethod = "measurement_method"
        case createdAt = "created_at"
    }
}

struct SupabaseTreadDepthMeasurementInsert: Encodable {
    let analysisId: UUID
    let tyrePosition: String
    let measurementX: Double?
    let measurementY: Double?
    let zone: String?
    let depthMm: Double
    let confidence: Double?
    let measurementMethod: String?

    enum CodingKeys: String, CodingKey {
        case analysisId = "analysis_id"
        case tyrePosition = "tyre_position"
        case measurementX = "measurement_x"
        case measurementY = "measurement_y"
        case zone
        case depthMm = "depth_mm"
        case confidence
        case measurementMethod = "measurement_method"
    }
}

struct LifecycleProjection: Codable, Identifiable {
    let id: UUID
    let analysisId: UUID
    let kilometersFromNow: Int
    let projectedDepth: Double
    let confidence: Double?
    let isProjected: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case analysisId = "analysis_id"
        case kilometersFromNow = "kilometers_from_now"
        case projectedDepth = "projected_depth"
        case confidence
        case isProjected = "is_projected"
        case createdAt = "created_at"
    }
}

struct LifecycleProjectionInsert: Encodable {
    let analysisId: UUID
    let kilometersFromNow: Int
    let projectedDepth: Double
    let confidence: Double
    let isProjected: Bool

    enum CodingKeys: String, CodingKey {
        case analysisId = "analysis_id"
        case kilometersFromNow = "kilometers_from_now"
        case projectedDepth = "projected_depth"
        case confidence
        case isProjected = "is_projected"
    }
}

// MARK: - Service

@MainActor
class TyreAnalysisService {
    static let shared = TyreAnalysisService()

    private let networkManager = NetworkManager.shared

    private init() {}

    // MARK: - Analyses CRUD

    /// Salva una nuova analisi
    func saveAnalysis(_ input: TyreAnalysisInput) async throws -> TyreAnalysisRecord {
        print("💾 [TyreAnalysisService] Saving analysis for tyre \(input.tyreId)")

        let response: TyreAnalysisRecord = try await networkManager.post(
            endpoint: "/v1/tyre_analyses",
            body: input
        )

        print("✅ [TyreAnalysisService] Analysis saved with ID: \(response.id)")
        return response
    }

    /// Recupera l'ultima analisi per un pneumatico
    func getLatestAnalysis(forTyreId tyreId: Int) async throws -> TyreAnalysisRecord? {
        print("🔍 [TyreAnalysisService] Fetching latest analysis for tyre \(tyreId)")

        do {
            let analysis: TyreAnalysisRecord = try await networkManager.get(
                endpoint: "/v1/tyre_analyses/tyre/\(tyreId)/latest"
            )
            print("✅ [TyreAnalysisService] Found analysis from \(analysis.analysisDate)")
            return analysis
        } catch let error as NetworkError {
            if case .notFound = error {
                print("⚠️ [TyreAnalysisService] No analysis found for tyre \(tyreId)")
                return nil
            }
            throw error
        }
    }

    /// Recupera tutte le analisi per un pneumatico (storico)
    func getAnalysisHistory(forTyreId tyreId: Int) async throws -> [TyreAnalysisRecord] {
        print("🔍 [TyreAnalysisService] Fetching analysis history for tyre \(tyreId)")

        let analyses: [TyreAnalysisRecord] = try await networkManager.get(
            endpoint: "/v1/tyre_analyses/tyre/\(tyreId)"
        )

        print("✅ [TyreAnalysisService] Found \(analyses.count) analyses")
        return analyses
    }

    /// Recupera tutte le analisi per un veicolo
    func getAnalyses(forVehicleId vehicleId: Int) async throws -> [TyreAnalysisRecord] {
        print("🔍 [TyreAnalysisService] Fetching analyses for vehicle \(vehicleId)")

        let analyses: [TyreAnalysisRecord] = try await networkManager.get(
            endpoint: "/v1/tyre_analyses/vehicle/\(vehicleId)"
        )

        print("✅ [TyreAnalysisService] Found \(analyses.count) analyses")
        return analyses
    }

    /// Elimina un'analisi
    func deleteAnalysis(id: UUID) async throws {
        print("🗑️ [TyreAnalysisService] Deleting analysis \(id)")

        try await networkManager.delete(
            endpoint: "/v1/tyre_analyses/\(id.uuidString)"
        )

        print("✅ [TyreAnalysisService] Analysis deleted")
    }

    // MARK: - Tread Depth Measurements

    /// Salva misurazioni dettagliate
    func saveTreadMeasurements(
        analysisId: UUID,
        measurements: [(position: String, depth: Double, x: Double?, y: Double?, zone: String?)]
    ) async throws {
        print("💾 [TyreAnalysisService] Saving \(measurements.count) tread measurements")

        let records = measurements.map { measurement in
            SupabaseTreadDepthMeasurementInsert(
                analysisId: analysisId,
                tyrePosition: measurement.position,
                measurementX: measurement.x,
                measurementY: measurement.y,
                zone: measurement.zone,
                depthMm: measurement.depth,
                confidence: nil,
                measurementMethod: "calculated"
            )
        }

        struct MeasurementBatch: Encodable {
            let measurements: [SupabaseTreadDepthMeasurementInsert]
        }

        let payload = MeasurementBatch(measurements: records)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        let body = try encoder.encode(payload)

        try await networkManager.requestWithoutResponse(
            endpoint: "/v1/tread_depth_measurements",
            method: .post,
            body: body
        )

        print("✅ [TyreAnalysisService] Tread measurements saved")
    }

    /// Recupera misurazioni per un'analisi
    func getTreadMeasurements(forAnalysisId analysisId: UUID) async throws -> [SupabaseTreadDepthMeasurement] {
        print("🔍 [TyreAnalysisService] Fetching tread measurements for analysis \(analysisId)")

        let measurements: [SupabaseTreadDepthMeasurement] = try await networkManager.get(
            endpoint: "/v1/tread_depth_measurements/analysis/\(analysisId.uuidString)"
        )

        print("✅ [TyreAnalysisService] Found \(measurements.count) measurements")
        return measurements
    }

    // MARK: - Lifecycle Projections

    /// Salva proiezioni lifecycle
    func saveLifecycleProjections(
        analysisId: UUID,
        projections: [(km: Int, depth: Double, confidence: Double, isProjected: Bool)]
    ) async throws {
        print("💾 [TyreAnalysisService] Saving \(projections.count) lifecycle projections")

        let records = projections.map { projection in
            LifecycleProjectionInsert(
                analysisId: analysisId,
                kilometersFromNow: projection.km,
                projectedDepth: projection.depth,
                confidence: projection.confidence,
                isProjected: projection.isProjected
            )
        }

        struct ProjectionBatch: Encodable {
            let projections: [LifecycleProjectionInsert]
        }

        let payload = ProjectionBatch(projections: records)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        let body = try encoder.encode(payload)

        try await networkManager.requestWithoutResponse(
            endpoint: "/v1/tyre_lifecycle_projections",
            method: .post,
            body: body
        )

        print("✅ [TyreAnalysisService] Lifecycle projections saved")
    }

    /// Recupera proiezioni per un'analisi
    func getLifecycleProjections(forAnalysisId analysisId: UUID) async throws -> [LifecycleProjection] {
        print("🔍 [TyreAnalysisService] Fetching lifecycle projections for analysis \(analysisId)")

        let projections: [LifecycleProjection] = try await networkManager.get(
            endpoint: "/v1/tyre_lifecycle_projections/analysis/\(analysisId.uuidString)"
        )

        print("✅ [TyreAnalysisService] Found \(projections.count) projections")
        return projections
    }

    // MARK: - Statistics

    /// Calcola statistiche per un utente
    func getUserStatistics() async throws -> UserAnalysisStats? {
        guard let userId = try? await SupabaseManager.client.auth.session.user.id else {
            print("⚠️ [TyreAnalysisService] No user ID available")
            return nil
        }

        print("📊 [TyreAnalysisService] Fetching statistics for user \(userId)")

        let stats: [UserAnalysisStats] = try await networkManager.get(
            endpoint: "/v1/user_analysis_stats/\(userId.uuidString)"
        )

        return stats.first
    }
}

// MARK: - Supporting Models

struct UserAnalysisStats: Codable {
    let userId: UUID
    let totalAnalyses: Int
    let tyresAnalyzed: Int
    let avgDepth: Double?
    let avgRemainingLife: Double?
    let lastAnalysisDate: Date?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case totalAnalyses = "total_analyses"
        case tyresAnalyzed = "tyres_analyzed"
        case avgDepth = "avg_depth"
        case avgRemainingLife = "avg_remaining_life"
        case lastAnalysisDate = "last_analysis_date"
    }
}
