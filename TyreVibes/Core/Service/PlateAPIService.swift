import Foundation
import SwiftUI

struct PlateAPIRequest: Codable {
    let plate: String
    let make: String?
    let model: String?
    let modelDetail : String?
    let fuel_type: String?
    let power_kw: String?
    let power_cv: String?
    let cilindrata: String?
    let color: String?
    let vin: String?
    let user_id: String
    let registration_date: String?
    let image_base64: String?
    let image_mime: String?
    
    let rcaCompany: String?
    let rcaPolicyNumber: String?
    let rcaExpiry: Date?
    let rcaInsurancePresent: Bool?
    let classeAmbientale: String?
    let tyres: [[String: String]]?
}

struct PlateAPIResponse: Codable {
    let plate_id: Int
    let plate: String
    let make: String?
    let model: String?
    let modelDetail : String?
    let fuel_type: String?
    let power_kw: String?
    let cilindrata: String?
    let color: String?
    let vin: String?
    let created_at: String
    let user_id: String?
    let registration_date: String?
    let image_base64: String?
    
    let rcaCompany: String?
    let rcaPolicyNumber: String?
    let rcaExpiry: Date?
    let rcaInsurancePresent: Bool?
    let classeAmbientale: String?
}

enum PlateAPIError: Error {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case serverError(Int, String)
    case plateNotFound
}

private func imageHasAlpha(_ image: UIImage) -> Bool {
    guard let alpha = image.cgImage?.alphaInfo else { return false }
    switch alpha {
    case .first, .last, .premultipliedFirst, .premultipliedLast:
        return true
    default:
        return false
    }
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
                    color: apiResponse.color,
                   // fuel: apiResponse.fuel_type,
                    powerKW: apiResponse.power_kw,
                    displacementCC: apiResponse.cilindrata,
                    vin: apiResponse.vin,
                    
                )
            } catch {
                throw PlateAPIError.requestFailed(error) // JSON decoding error
            }
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw PlateAPIError.serverError(httpResponse.statusCode, errorMessage)
        }
    }

    func savePlate(plateData: PlateData, color: String, userId: String, image: UIImage?) async throws {
        guard let url = savePlateURL else {
            throw PlateAPIError.invalidURL
        }

        // Prepara immagine come PNG (se alpha) o JPEG (altrimenti). iOS non esporta WEBP nativamente.
        var imageBase64: String? = nil
        var imageMime: String? = nil
        if let uiImage = image {
            if imageHasAlpha(uiImage), let data = uiImage.pngData() {
                imageBase64 = data.base64EncodedString()
                imageMime = "image/png"
            } else if let data = uiImage.jpegData(compressionQuality: 0.9) {
                imageBase64 = data.base64EncodedString()
                imageMime = "image/jpeg"
            }
        }

        let requestBody = PlateAPIRequest(
            plate: plateData.plate.uppercased(),
            make: plateData.make ?? "-",
            model: plateData.model ?? "-",
            modelDetail: plateData.modelDetails ?? "-",
            fuel_type: plateData.fuelType ?? "-",
            power_kw: plateData.powerKW ?? "-",
            power_cv: plateData.powerCV ?? "-",
            cilindrata: plateData.displacementCC ?? "-",
            color: color,
            vin: plateData.vin ?? "-",
            user_id: userId,
            registration_date: plateData.registrationDate ?? "-",
            image_base64: imageBase64,
            image_mime: imageMime,
            rcaCompany : plateData.insuranceCompany ?? "",
            rcaPolicyNumber: plateData.insuranceCompany ?? "",
            rcaExpiry : plateData.insuranceExpiry,
            rcaInsurancePresent: plateData.insurancePresent ?? false,
            classeAmbientale : plateData.emissionClass ?? "",
            tyres: plateData.tyres
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
