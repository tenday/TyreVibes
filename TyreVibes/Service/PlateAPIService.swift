import Foundation
import SwiftUI

struct PlateAPIRequest: Codable {
    let plate: String
    let make: String?
    let model: String?
    let year: String?
    let fuel_type: String?
    let power_kw: String?
    let displacement: String?
    let color: String?
    let vin: String?
}

enum PlateAPIError: Error {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case serverError(Int, String)
}

class PlateAPIService {

    let apiURL = URL(string: "https://www.tyrevibes.com/api/save_plate.php")

    func savePlate(plateData: PlateData, color: Color) async throws {
        guard let url = apiURL else {
            throw PlateAPIError.invalidURL
        }

        let requestBody = PlateAPIRequest(
            plate: plateData.plate,
            make: plateData.make,
            model: plateData.model,
            year: plateData.year,
            fuel_type: plateData.fuel,
            power_kw: plateData.powerKW,
            displacement: plateData.displacementCC,
            color: color.toHex(),
            vin: plateData.vin
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw PlateAPIError.requestFailed(error)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlateAPIError.invalidResponse
        }

        if (200...299).contains(httpResponse.statusCode) {
            // Success
            return
        } else {
            // Server error
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw PlateAPIError.serverError(httpResponse.statusCode, errorMessage)
        }
    }
}
