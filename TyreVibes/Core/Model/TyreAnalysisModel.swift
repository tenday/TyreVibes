import Foundation

struct TyreAnalysisModel: Identifiable, Codable, Equatable {
    let id: String
    let tyreId: Int
    let userId: String
    let vehicleId: Int
    let analysisDate: Date
    let analysisType: String
    
    // Depth readings
    let depthFrontLeft: Double?
    let depthFrontRight: Double?
    let depthRearLeft: Double?
    let depthRearRight: Double?
    let depthAverage: Double?
    let depthMinimum: Double?
    
    // Life expectancy
    let remainingLifePercentage: Double?
    let remainingLifeKm: Int?
    let remainingLifeMonths: Int?
    
    let confidenceScore: Double?
    
    // Condition ratings (0-10 or similar)
    let conditionFrontLeft: Double?
    let conditionFrontRight: Double?
    let conditionRearLeft: Double?
    let conditionRearRight: Double?
    
    let wearPattern: String?
    let wearSeverity: String?
    let notes: String?
    let technicianName: String?
    
    // Location
    let locationLatitude: Double?
    let locationLongitude: Double?
    let locationAddress: String?
    
    let imageUrls: [String]?
    
    let createdAt: Date?
    let updatedAt: Date?
    
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
