import Foundation

struct AddressResponse: Codable {
    let status: String
    let resp: [AddressSuggestion]
    let time: Int
}

struct AddressSuggestion: Codable, Identifiable {
    let iso3: String
    let level: String
    let id: Int
    let score: Double
    let country: String
    let region: String
    let province: String
    let city: String
    let district1: String?
    let zipcode: String
    let street: String
    let chk: String
}