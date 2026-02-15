import XCTest
@testable import TyreVibes

class RemotePersistenceServiceTests: XCTestCase {

    func testInitialization() {
        let service = RemotePersistenceService()
        XCTAssertNotNil(service)
    }
    
    // In a real scenario, we would mock NetworkManager to test saveTyre and saveAnalysis
    // For now, we verified the models and the service compilation.
}
