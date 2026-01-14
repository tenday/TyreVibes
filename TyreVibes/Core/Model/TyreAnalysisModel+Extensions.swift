import Foundation

extension TyreAnalysisModel {
    init(
        id: String,
        tyreId: Int,
        userId: String,
        vehicleId: Int,
        analysisDate: Date,
        analysisType: String,
        depthAverage: Double? = nil,
        confidenceScore: Double? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.tyreId = tyreId
        self.userId = userId
        self.vehicleId = vehicleId
        self.analysisDate = analysisDate
        self.analysisType = analysisType
        self.depthAverage = depthAverage
        self.confidenceScore = confidenceScore
        self.notes = notes
        
        // Default nil for others
        self.depthFrontLeft = nil
        self.depthFrontRight = nil
        self.depthRearLeft = nil
        self.depthRearRight = nil
        self.depthMinimum = nil
        self.remainingLifePercentage = nil
        self.remainingLifeKm = nil
        self.remainingLifeMonths = nil
        self.conditionFrontLeft = nil
        self.conditionFrontRight = nil
        self.conditionRearLeft = nil
        self.conditionRearRight = nil
        self.wearPattern = nil
        self.wearSeverity = nil
        self.technicianName = nil
        self.locationLatitude = nil
        self.locationLongitude = nil
        self.locationAddress = nil
        self.imageUrls = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
