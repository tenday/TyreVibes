//
//  TyreAnalysisService.swift
//  TyreVibes
//
//  Service per gestire le analisi dei pneumatici nel database
//

import Foundation
import Supabase

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

struct TreadDepthMeasurement: Codable, Identifiable {
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

// MARK: - Service

@MainActor
class TyreAnalysisService {
    static let shared = TyreAnalysisService()

    private let supabase = SupabaseManager.client

    private init() {}

    // MARK: - Analyses CRUD

    /// Salva una nuova analisi
    func saveAnalysis(_ input: TyreAnalysisInput) async throws -> TyreAnalysisRecord {
        print("💾 [TyreAnalysisService] Saving analysis for tyre \(input.tyreId)")

        let response: TyreAnalysisRecord = try await supabase
            .from("tyre_analyses")
            .insert(input)
            .select()
            .single()
            .execute()
            .value

        print("✅ [TyreAnalysisService] Analysis saved with ID: \(response.id)")
        return response
    }

    /// Recupera l'ultima analisi per un pneumatico
    func getLatestAnalysis(forTyreId tyreId: Int) async throws -> TyreAnalysisRecord? {
        print("🔍 [TyreAnalysisService] Fetching latest analysis for tyre \(tyreId)")

        let analyses: [TyreAnalysisRecord] = try await supabase
            .from("tyre_analyses")
            .select()
            .eq("tyre_id", value: tyreId)
            .order("analysis_date", ascending: false)
            .limit(1)
            .execute()
            .value

        if let analysis = analyses.first {
            print("✅ [TyreAnalysisService] Found analysis from \(analysis.analysisDate)")
            return analysis
        } else {
            print("⚠️ [TyreAnalysisService] No analysis found for tyre \(tyreId)")
            return nil
        }
    }

    /// Recupera tutte le analisi per un pneumatico (storico)
    func getAnalysisHistory(forTyreId tyreId: Int) async throws -> [TyreAnalysisRecord] {
        print("🔍 [TyreAnalysisService] Fetching analysis history for tyre \(tyreId)")

        let analyses: [TyreAnalysisRecord] = try await supabase
            .from("tyre_analyses")
            .select()
            .eq("tyre_id", value: tyreId)
            .order("analysis_date", ascending: false)
            .execute()
            .value

        print("✅ [TyreAnalysisService] Found \(analyses.count) analyses")
        return analyses
    }

    /// Recupera tutte le analisi per un veicolo
    func getAnalyses(forVehicleId vehicleId: Int) async throws -> [TyreAnalysisRecord] {
        print("🔍 [TyreAnalysisService] Fetching analyses for vehicle \(vehicleId)")

        let analyses: [TyreAnalysisRecord] = try await supabase
            .from("tyre_analyses")
            .select()
            .eq("vehicle_id", value: vehicleId)
            .order("analysis_date", ascending: false)
            .execute()
            .value

        print("✅ [TyreAnalysisService] Found \(analyses.count) analyses")
        return analyses
    }

    /// Elimina un'analisi
    func deleteAnalysis(id: UUID) async throws {
        print("🗑️ [TyreAnalysisService] Deleting analysis \(id)")

        try await supabase
            .from("tyre_analyses")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()

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
            [
                "analysis_id": analysisId.uuidString,
                "tyre_position": measurement.position,
                "depth_mm": measurement.depth,
                "measurement_x": measurement.x as Any,
                "measurement_y": measurement.y as Any,
                "zone": measurement.zone as Any,
                "measurement_method": "calculated"
            ] as [String: Any]
        }

        try await supabase
            .from("tread_depth_measurements")
            .insert(records)
            .execute()

        print("✅ [TyreAnalysisService] Tread measurements saved")
    }

    /// Recupera misurazioni per un'analisi
    func getTreadMeasurements(forAnalysisId analysisId: UUID) async throws -> [TreadDepthMeasurement] {
        print("🔍 [TyreAnalysisService] Fetching tread measurements for analysis \(analysisId)")

        let measurements: [TreadDepthMeasurement] = try await supabase
            .from("tread_depth_measurements")
            .select()
            .eq("analysis_id", value: analysisId.uuidString)
            .execute()
            .value

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
            [
                "analysis_id": analysisId.uuidString,
                "kilometers_from_now": projection.km,
                "projected_depth": projection.depth,
                "confidence": projection.confidence,
                "is_projected": projection.isProjected
            ] as [String: Any]
        }

        try await supabase
            .from("tyre_lifecycle_projections")
            .insert(records)
            .execute()

        print("✅ [TyreAnalysisService] Lifecycle projections saved")
    }

    /// Recupera proiezioni per un'analisi
    func getLifecycleProjections(forAnalysisId analysisId: UUID) async throws -> [LifecycleProjection] {
        print("🔍 [TyreAnalysisService] Fetching lifecycle projections for analysis \(analysisId)")

        let projections: [LifecycleProjection] = try await supabase
            .from("tyre_lifecycle_projections")
            .select()
            .eq("analysis_id", value: analysisId.uuidString)
            .order("kilometers_from_now", ascending: true)
            .execute()
            .value

        print("✅ [TyreAnalysisService] Found \(projections.count) projections")
        return projections
    }

    // MARK: - Statistics

    /// Calcola statistiche per un utente
    func getUserStatistics() async throws -> UserAnalysisStats? {
        guard let userId = try? await supabase.auth.session.user.id else {
            print("⚠️ [TyreAnalysisService] No user ID available")
            return nil
        }

        print("📊 [TyreAnalysisService] Fetching statistics for user \(userId)")

        let stats: [UserAnalysisStats] = try await supabase
            .from("user_analysis_stats")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

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
