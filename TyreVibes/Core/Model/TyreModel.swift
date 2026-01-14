import Foundation

struct TyreModel: Identifiable, Codable, Equatable {
    let id: Int
    let vehicleId: Int
    let brand: String?
    let model: String
    let sizeLabel: String?
    let dot: String?
    let loadIndex: String?
    let speedRating: String?
    let season: String?
    let setName: String?
    let setPosition: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId = "vehicle_id"
        case brand
        case model
        case sizeLabel = "size_label"
        case dot
        case loadIndex = "load_index"
        case speedRating = "speed_rating"
        case season
        case setName = "set_name"
        case setPosition = "set_position"
    }
}
