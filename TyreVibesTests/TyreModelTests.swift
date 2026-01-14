import XCTest
@testable import TyreVibes

class TyreModelTests: XCTestCase {

    func testTyreModelInitialization() {
        let tyre = TyreModel(
            id: 1,
            vehicleId: 10,
            brand: "Michelin",
            model: "Pilot Sport 4",
            sizeLabel: "225/45 R17",
            dot: "1223",
            loadIndex: "91",
            speedRating: "Y",
            season: "Summer",
            setName: "Summer Set",
            setPosition: "Front"
        )
        
        XCTAssertEqual(tyre.brand, "Michelin")
        XCTAssertEqual(tyre.vehicleId, 10)
    }

    func testTyreAnalysisModelInitialization() {
        let analysis = TyreAnalysisModel(
            id: "uuid-123",
            tyreId: 1,
            userId: "user-456",
            vehicleId: 10,
            analysisDate: Date(),
            analysisType: "manual",
            depthAverage: 5.5,
            confidenceScore: 0.95,
            notes: "Good condition"
        )
        
        XCTAssertEqual(analysis.tyreId, 1)
        XCTAssertEqual(analysis.depthAverage, 5.5)
        XCTAssertEqual(analysis.analysisType, "manual")
    }
}
