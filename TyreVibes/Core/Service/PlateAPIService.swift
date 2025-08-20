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

struct PlateAPIResponse: Codable {
    let plate_id: Int
    let plate: String
    let make: String?
    let model: String?
    let year: String?
    let fuel_type: String?
    let power_kw: String?
    let displacement: String?
    let color: String?
    let vin: String?
    let created_at: String
}

enum PlateAPIError: Error {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case serverError(Int, String)
    case plateNotFound
}

class PlateAPIService {

    private static let apiConfig: NSDictionary = {
        if let path = Bundle.main.path(forResource: "Api", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) {
            return dict
        }
        return [:]
    }()

    private let savePlateURL = URL(string: (PlateAPIService.apiConfig["SavePlateURL"] as? String) ?? "")
    private let checkPlateBaseURL = (PlateAPIService.apiConfig["CheckPlateBaseURL"] as? String) ?? ""

    func checkPlate(plateNumber: String) async throws -> PlateData? {
        guard var components = URLComponents(string: checkPlateBaseURL) else {
            throw PlateAPIError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "plate", value: plateNumber)]

        guard let url = components.url else {
            throw PlateAPIError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlateAPIError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            return nil // Plate not found is not an error, it's a valid outcome.
        }

        if (200...299).contains(httpResponse.statusCode) {
            do {
                let apiResponse = try JSONDecoder().decode(PlateAPIResponse.self, from: data)
                return PlateData(
                    plate: apiResponse.plate,
                    make: apiResponse.make,
                    model: apiResponse.model,
                    year: apiResponse.year,
                    color: apiResponse.color,
                   // fuel: apiResponse.fuel_type,
                    powerKW: apiResponse.power_kw,
                    displacementCC: apiResponse.displacement,
                    vin: apiResponse.vin
                )
            } catch {
                throw PlateAPIError.requestFailed(error) // JSON decoding error
            }
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw PlateAPIError.serverError(httpResponse.statusCode, errorMessage)
        }
    }

    func savePlate(plateData: PlateData, color: Color) async throws {
        guard let url = savePlateURL else {
            throw PlateAPIError.invalidURL
        }

        let requestBody = PlateAPIRequest(
            plate: plateData.plate.uppercased(),
            make: plateData.make ?? "-",
            model: plateData.model ?? "-",
            year: plateData.year ?? "-",
            fuel_type: plateData.fuelType ?? "-",
            power_kw: plateData.powerKW ?? "-",
            displacement: plateData.displacementCC ?? "-",
            color: color.toHex() ?? "-",
            vin: plateData.vin ?? "-"
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
