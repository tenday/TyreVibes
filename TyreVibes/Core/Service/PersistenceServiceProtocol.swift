import Foundation

protocol PersistenceServiceProtocol {
    func saveTyre(_ tyre: TyreModel) async throws -> TyreModel
    func saveAnalysis(_ analysis: TyreAnalysisModel) async throws -> TyreAnalysisModel
}
