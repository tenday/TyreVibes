import Foundation

class RemotePersistenceService: PersistenceServiceProtocol {
    
    private let networkManager: NetworkManager
    
    init(networkManager: NetworkManager = .shared) {
        self.networkManager = networkManager
    }
    
    func saveTyre(_ tyre: TyreModel) async throws -> TyreModel {
        struct TyreResponse: Decodable {
            let message: String
            let tyreId: Int
        }
        
        let response: TyreResponse = try await networkManager.post(
            endpoint: "/v1/tyres_vehicles",
            body: tyre
        )
        
        // Return a copy with the new ID
        return TyreModel(
            id: response.tyreId,
            vehicleId: tyre.vehicleId,
            brand: tyre.brand,
            model: tyre.model,
            sizeLabel: tyre.sizeLabel,
            dot: tyre.dot,
            loadIndex: tyre.loadIndex,
            speedRating: tyre.speedRating,
            season: tyre.season,
            setName: tyre.setName,
            setPosition: tyre.setPosition
        )
    }
    
    func saveAnalysis(_ analysis: TyreAnalysisModel) async throws -> TyreAnalysisModel {
        let savedAnalysis: TyreAnalysisModel = try await networkManager.post(
            endpoint: "/v1/tyre_analyses",
            body: analysis
        )
        return savedAnalysis
    }
}
