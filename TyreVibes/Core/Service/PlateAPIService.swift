import Foundation
import SwiftUI

struct PlateAPIRequest: Codable {
    let plate: String
    let make: String?
    let model: String?
    let color: String?
    let fuelType: String?
    let powerKW: String?
    let powerCV: String?
    let modelDetails: String?
    let displacementCC: String?
    let registrationDate: String?
    let year: Int?
    let month: Int?
    let vin: String?

    let userId: String
    let imagesBase64: [String]?
    let imagesMime: [String]?
    let imagesAngle: [Int]?
    let imagesColor: [String]

    // RCA/Assicurazione
    let insuranceCompany: String?
    let insurancePolicyNumber: String?
    let insuranceExpiry: Date?
    let insurancePresent: Bool?

    let emissionClass: String?
    let tyres: [[String: String]]?

    // --- campi da /dettagli ---
    let view: String?
    let saleStart: String?
    let saleEnd: String?
    let gearbox: String?
    let maxSpeed: String?
    let bodyType: String?
    let doors: String?
    let seats: String?
    let consumption: String?
    let traction: String?

    let revisioni: [Revisione]?

    // Bollo
    let bolloAmount: Double?
    let bolloSuper: Double?
    let bolloTotal: Double?
    let bolloEmissionClass: String?
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
    case alreadyInGarage
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
    
    static let apiConfig: NSDictionary = {
        if let path = Bundle.main.path(forResource: "Api", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) {
            return dict
        }
        return [:]
    }()
    
    private let savePlateURL = URL(string: (PlateAPIService.apiConfig["SavePlateURL"] as? String) ?? "")
    private let checkPlateBaseURL = (PlateAPIService.apiConfig["CheckPlateBaseURL"] as? String) ?? ""
    
    private func convertRegistrationDate(_ dateStr: String?) -> String {
        guard let dateStr = dateStr else { return "-" }
        let formatterInput = DateFormatter()
        formatterInput.dateFormat = "MM/yyyy"
        formatterInput.locale = Locale(identifier: "it_IT_POSIX")
        if let date = formatterInput.date(from: dateStr) {
            let formatterOutput = DateFormatter()
            formatterOutput.dateFormat = "yyyy-MM-dd"
            formatterOutput.locale = Locale(identifier: "it_IT_POSIX")
            return formatterOutput.string(from: date)
        }
        return "-"
    }

    func extractYear(_ dateStr: String?) -> Int? {
        guard let dateStr = dateStr else { return nil }
        let formatterInput = DateFormatter()
        formatterInput.dateFormat = "MM/yyyy"
        formatterInput.locale = Locale(identifier: "it_IT_POSIX")
        if let date = formatterInput.date(from: dateStr) {
            let calendar = Calendar.current
            return calendar.component(.year, from: date)
        }
        return nil
    }

    private func extractMonth(_ dateStr: String?) -> Int? {
        guard let dateStr = dateStr else { return nil }
        let formatterInput = DateFormatter()
        formatterInput.dateFormat = "MM/yyyy"
        formatterInput.locale = Locale(identifier: "it_IT_POSIX")
        if let date = formatterInput.date(from: dateStr) {
            let calendar = Calendar.current
            return calendar.component(.month, from: date)
        }
        return nil
    }
    
    
    
    
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
    
    func savePlate(plateData: PlateData, color: String, userId: String, images: [UIImage?], imagesColor: [String]) async throws {
        guard let url = savePlateURL else {
            throw PlateAPIError.invalidURL
        }
        
        var imagesBase64: [String] = []
        var imagesMime: [String] = []
        for image in images {
            if let uiImage = image {
                if imageHasAlpha(uiImage), let data = uiImage.pngData() {
                    imagesBase64.append(data.base64EncodedString())
                    imagesMime.append("image/png")
                } else if let data = uiImage.jpegData(compressionQuality: 0.9) {
                    imagesBase64.append(data.base64EncodedString())
                    imagesMime.append("image/jpeg")
                }
            }
        }
        
        let requestBody = PlateAPIRequest(
            plate: plateData.plate.uppercased(),
            make: plateData.make ?? "-",
            model: plateData.model ?? "-",
            color: color.lowercased(),
            fuelType: plateData.fuelType ?? "-",
            powerKW: plateData.powerKW ?? "-",
            powerCV: plateData.powerCV ?? "-",
            modelDetails: plateData.modelDetails ?? "-",
            displacementCC: plateData.displacementCC ?? "-",
            registrationDate: convertRegistrationDate(plateData.registrationDate),
            year: extractYear(plateData.registrationDate),
            month: extractMonth(plateData.registrationDate),
            vin: plateData.vin ?? "-",
            userId: userId,
            imagesBase64: imagesBase64,
            imagesMime: imagesMime,
            imagesAngle: [23,23,12,12],
            imagesColor: imagesColor,
            insuranceCompany: plateData.insuranceCompany,
            insurancePolicyNumber: plateData.insurancePolicyNumber,
            insuranceExpiry: plateData.insuranceExpiry,
            insurancePresent: plateData.insurancePresent,
            emissionClass: plateData.emissionClass,
            tyres: plateData.tyres,
            view: plateData.view,
            saleStart : plateData.saleStart,
            saleEnd: plateData.saleEnd,
            gearbox: plateData.gearbox,
            maxSpeed: plateData.maxSpeed,
            bodyType: plateData.bodyType,
            doors: plateData.doors,
            seats: plateData.seats,
            consumption: plateData.consumption,
            traction: plateData.traction,
            revisioni: plateData.revisioni ?? [],
            bolloAmount: plateData.bollo?.baseBollo,
            bolloSuper: plateData.bollo?.superBollo,
            bolloTotal: plateData.bollo?.total,
            bolloEmissionClass: plateData.bollo?.emissionClassDescription
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(requestBody)
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
    
    func associateVehicle2User(vehicleId: Int, userId: String) async throws -> (imageBase64: String?, mimeType: String?) {
        guard let baseURLString = PlateAPIService.apiConfig["BASE_URL"] as? String else {
            throw PlateAPIError.invalidURL
        }
        // Remove trailing slash if present
        let urlString = "\(baseURLString)/v1/vehicles/\(vehicleId)/user/\(userId)"
        
        guard let url = URL(string: urlString) else {
            throw PlateAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlateAPIError.invalidResponse
        }
        
        if (200...299).contains(httpResponse.statusCode) {
            struct AssociationResponse: Codable {
                let message: String
                let image_base64: String?
                let mime_type: String?
            }
            let decoded = try JSONDecoder().decode(AssociationResponse.self, from: data)
            return (decoded.image_base64, "image/png")
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw PlateAPIError.serverError(httpResponse.statusCode, errorMessage)
        }
    }
}
