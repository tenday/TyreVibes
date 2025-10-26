import Foundation
import SwiftUI
import Supabase

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
    private let manualPlateURL = URL(string: (PlateAPIService.apiConfig["ManualPlateURL"] as? String) ?? "")

    // MARK: - Get Supabase JWT Token
    private func getAuthToken() async -> String? {
        do {
            let session = try await SupabaseManager.client.auth.session
            return session.accessToken
        } catch {
            print("⚠️ [PlateAPIService] Failed to get auth token: \(error.localizedDescription)")
            return nil
        }
    }

    static var currentUserToken: String? {
        get async {
            do {
                let session = try await SupabaseManager.client.auth.session
                return session.accessToken
            } catch {
                return nil
            }
        }
    }
    
    private func convertRegistrationDate(_ dateStr: String?) -> String {
        guard let dateStr = dateStr else { return "-" }
        let comps = dateStr.split(separator: "/")
        if comps.count == 2, let month = comps.first, let year = comps.last {
            return "\(year)-\(month)-01"
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
    
    
    
    
    func checkPlate(plateNumber: String) async throws -> Int? {
        guard var components = URLComponents(string: checkPlateBaseURL) else {
            throw PlateAPIError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "plate", value: plateNumber)]

        guard let url = components.url else {
            throw PlateAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Add JWT token
        if let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlateAPIError.invalidResponse
        }
        
        if httpResponse.statusCode == 404 {
            return nil // Plate not found is not an error, it's a valid outcome.
        }
        
        if (200...299).contains(httpResponse.statusCode) {
            do {
                let apiResponse = try JSONDecoder().decode(PlateAPIResponse.self, from: data)
                return apiResponse.plate_id
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

        let angles: [Int]
        if imagesBase64.count == 2 {
            angles = Array([23, 12])
        } else {
            angles = Array([23,23,12,12])
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
            imagesAngle: angles,
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

        // Add JWT token
        if let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

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
    
    func savePlateManually(
        plate: String,
        make: String = "",
        model: String = "",
        registrationDate: String = "",
        fuelType: String = "",
        powerKW: String = "",
        powerCV: String = "",
        displacementCC: String = "",
        emissionClass: String = "",
        gearbox: String = "",
        maxSpeed: String = "",
        bodyType: String = "",
        doors: String = "",
        seats: String = "",
        consumption: String = "",
        traction: String = "",
        saleStart: String = "",
        saleEnd: String = "",
        color: String = "",
        vin: String = "",
        modelDetails: String = "",
        insuranceCompany: String? = nil,
        insurancePolicyNumber: String? = nil,
        insuranceExpiry: Date? = nil,
        insurancePresent: Bool? = nil,
        userId: String
    ) async throws -> (vehicleId: Int, plateId: Int) {
        guard let url = manualPlateURL else {
            throw PlateAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add JWT token
        if let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let requestBody: [String: Any] = [
            "plate": plate.uppercased(),
            "make": make.isEmpty ? "" : make,
            "model": model.isEmpty ? "" : model,
            "modelDetails": modelDetails.isEmpty ? "" : modelDetails,
            "registrationDate": registrationDate.isEmpty ? "" : registrationDate,
            "fuelType": fuelType.isEmpty ? "" : fuelType,
            "powerKW": powerKW.isEmpty ? "" : powerKW,
            "powerCV": powerCV.isEmpty ? "" : powerCV,
            "displacementCC": displacementCC.isEmpty ? "" : displacementCC,
            "emissionClass": emissionClass.isEmpty ? "" : emissionClass,
            "gearbox": gearbox.isEmpty ? "" : gearbox,
            "maxSpeed": maxSpeed.isEmpty ? "" : maxSpeed,
            "bodyType": bodyType.isEmpty ? "" : bodyType,
            "doors": doors.isEmpty ? "" : doors,
            "seats": seats.isEmpty ? "" : seats,
            "consumption": consumption.isEmpty ? "" : consumption,
            "traction": traction.isEmpty ? "" : traction,
            "saleStart": saleStart.isEmpty ? "" : saleStart,
            "saleEnd": saleEnd.isEmpty ? "" : saleEnd,
            "color": color.isEmpty ? "" : color,
            "vin": vin.isEmpty ? "" : vin,
            "insuranceCompany": insuranceCompany ?? NSNull(),
            "insurancePolicyNumber": insurancePolicyNumber ?? NSNull(),
            "insuranceExpiry": insuranceExpiry ?? NSNull(),
            "insurancePresent": insurancePresent ?? NSNull(),
            "userId": userId
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            throw PlateAPIError.requestFailed(error)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlateAPIError.invalidResponse
        }

        if (200...299).contains(httpResponse.statusCode) {
            struct ManualPlateResponse: Codable {
                let vehicle_id: Int
                let plate_id: Int
                let message: String
            }

            do {
                let decoded = try JSONDecoder().decode(ManualPlateResponse.self, from: data)
                return (decoded.vehicle_id, decoded.plate_id)
            } catch {
                throw PlateAPIError.requestFailed(error)
            }
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw PlateAPIError.serverError(httpResponse.statusCode, errorMessage)
        }
    }

    func associateVehicle2User(vehicleId: Int, userId: String, color: String = "", images: [UIImage]? = nil) async throws -> (message: String, imageBase64: String?) {
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

        // Add JWT token
        if let token = await getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Prepara il body della richiesta
        struct RequestBody: Encodable {
            let color: String
            let imagesBase64: [String]?
            let imagesMime: [String]?
            let imagesAngle: [Int]?
        }

        var imagesBase64: [String]? = nil
        var imagesMime: [String]? = nil
        var imagesAngle: [Int]? = nil

        // Se ci sono immagini, convertile in base64
        if let images = images {
            var base64Images: [String] = []
            var mimeTypes: [String] = []

            for image in images {
                if imageHasAlpha(image), let data = image.pngData() {
                    base64Images.append(data.base64EncodedString())
                    mimeTypes.append("image/png")
                } else if let data = image.jpegData(compressionQuality: 0.9) {
                    base64Images.append(data.base64EncodedString())
                    mimeTypes.append("image/jpeg")
                }
            }

            imagesBase64 = base64Images
            imagesMime = mimeTypes
            imagesAngle = [23, 23, 12, 12] // angoli fissi per le 4 immagini
        }

        let body = RequestBody(
            color: color,
            imagesBase64: imagesBase64,
            imagesMime: imagesMime,
            imagesAngle: imagesAngle
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlateAPIError.invalidResponse
        }

        if (200...299).contains(httpResponse.statusCode) {
            struct AssociationResponse: Codable {
                let message: String
                let image_base64: String?
            }
            let decoded = try JSONDecoder().decode(AssociationResponse.self, from: data)
            return (decoded.message, decoded.image_base64)
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw PlateAPIError.serverError(httpResponse.statusCode, errorMessage)
        }
    }
}
