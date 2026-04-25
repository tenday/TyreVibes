import Foundation

// MARK: - Vehicle Service Errors
enum VehicleServiceError: LocalizedError {
    case vehicleNotFound
    case fetchFailed(String)
    case deleteFailed(String)
    case associationFailed(String)
    case mileageUpdateFailed(String)
    case invalidUserId

    var errorDescription: String? {
        switch self {
        case .vehicleNotFound:
            return "Veicolo non trovato"
        case .fetchFailed(let message):
            return "Errore nel recupero dei veicoli: \(message)"
        case .deleteFailed(let message):
            return "Errore nell'eliminazione del veicolo: \(message)"
        case .associationFailed(let message):
            return "Errore nell'associazione del veicolo: \(message)"
        case .mileageUpdateFailed(let message):
            return "Errore nell'aggiornamento del chilometraggio: \(message)"
        case .invalidUserId:
            return "ID utente non valido"
        }
    }
}

// MARK: - Vehicle Service
class VehicleService {
    static let shared = VehicleService()
    private let networkManager = NetworkManager.shared

    private init() {}

    // MARK: - Fetch Vehicles
    /// Recupera tutti i veicoli associati a un utente
    /// - Parameter userId: ID dell'utente
    /// - Returns: Array di VehicleResponse
    func fetchVehicles(for userId: String) async throws -> [VehicleResponse] {
        do {
            let vehicles: [VehicleResponse] = try await networkManager.get(
                endpoint: "/v1/vehicles/\(userId)"
            )
            print("✅ [VehicleService] Fetched \(vehicles.count) vehicles for user \(userId)")
            return vehicles
        } catch {
            print("❌ [VehicleService] Failed to fetch vehicles: \(error.localizedDescription)")
            throw VehicleServiceError.fetchFailed(error.localizedDescription)
        }
    }

    // MARK: - Delete Vehicle
    /// Elimina l'associazione tra un veicolo e un utente
    /// - Parameters:
    ///   - vehicleId: ID del veicolo
    ///   - userId: ID dell'utente
    func deleteVehicle(vehicleId: Int, userId: String) async throws {
        do {
            try await networkManager.delete(
                endpoint: "/v1/vehicles/\(vehicleId)/user/\(userId)"
            )
            print("✅ [VehicleService] Deleted vehicle \(vehicleId) for user \(userId)")
        } catch {
            print("❌ [VehicleService] Failed to delete vehicle: \(error.localizedDescription)")
            throw VehicleServiceError.deleteFailed(error.localizedDescription)
        }
    }

    // MARK: - Associate Vehicle to User
    /// Associa un veicolo a un utente, specificando un colore ed eventualmente una nuova immagine per quel colore.
    /// - Parameters:
    ///   - vehicleId: ID del veicolo
    ///   - userId: ID dell'utente
    ///   - color: Il colore da associare
    ///   - imageData: I dati dell'immagine (opzionale, solo se è un nuovo colore)
    /// - Returns: Tupla con immagine base64 e MIME type
    func associateVehicleToUser(
        vehicleId: Int,
        userId: String,
        color: String,
        imageData: Data?
    ) async throws -> (imageBase64: String?, mimeType: String?) {
        
        // Corpo della richiesta
        struct RequestBody: Encodable {
            let color: String
            let imagesBase64: [String]?
            let imagesMime: [String]?
            let imagesAngle: [String]? // Attualmente non usato, ma previsto dal backend
        }

        // Risposta attesa
        struct ResponseBody: Decodable {
            let message: String
            let imageBase64: String?
            let mimeType: String? // Opzionale, per compatibilità
        }

        var imagesBase64: [String]?
        var imagesMime: [String]?

        if let imageData = imageData {
            imagesBase64 = [imageData.base64EncodedString()]
            // NOTA: Assumiamo JPEG. Una implementazione migliore deriverebbe il MimeType dall'UIImage.
            imagesMime = ["image/jpeg"]
        }

        let requestBody = RequestBody(
            color: color,
            imagesBase64: imagesBase64,
            imagesMime: imagesMime,
            imagesAngle: nil
        )

        do {
            let response: ResponseBody = try await networkManager.post(
                endpoint: "/v1/vehicles/\(vehicleId)/user/\(userId)",
                body: requestBody
            )
            print("✅ [VehicleService] Associated vehicle \(vehicleId) to user \(userId) with color \(color)")
            return (response.imageBase64, response.mimeType)
        } catch {
            print("❌ [VehicleService] Failed to associate vehicle: \(error.localizedDescription)")
            throw VehicleServiceError.associationFailed(error.localizedDescription)
        }
    }

    // MARK: - Get Vehicle Details
    /// Recupera i dettagli di un veicolo specifico
    /// - Parameters:
    ///   - vehicleId: ID del veicolo
    ///   - userId: ID dell'utente
    /// - Returns: VehicleResponse con tutti i dettagli
    func getVehicleDetails(vehicleId: Int, userId: String) async throws -> VehicleResponse? {
        let vehicles = try await fetchVehicles(for: userId)
        return vehicles.first(where: { $0.vehicle.id == vehicleId })
    }

    // MARK: - Update Vehicle Mileage
    func updateVehicleMileage(vehicleId: Int, userId: String, mileage: Int?) async throws {
        struct RequestBody: Encodable {
            let currentMileage: Int?
        }

        do {
            try await networkManager.requestWithoutResponse(
                endpoint: "/v1/vehicles/\(vehicleId)/user/\(userId)/mileage",
                method: .patch,
                body: try JSONEncoder().encode(RequestBody(currentMileage: mileage))
            )
            print("✅ [VehicleService] Updated mileage for vehicle \(vehicleId): \(mileage.map(String.init) ?? "nil")")
        } catch {
            print("❌ [VehicleService] Failed to update mileage: \(error.localizedDescription)")
            throw VehicleServiceError.mileageUpdateFailed(error.localizedDescription)
        }
    }

    // MARK: - Cache Management
    /// Salva i veicoli in cache locale
    /// - Parameter vehicles: Array di VehicleResponse da cachare
    func cacheVehicles(_ vehicles: [VehicleResponse]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(vehicles)
            UserDefaults.standard.set(data, forKey: "cachedVehicles")
            print("✅ [VehicleService] Cached \(vehicles.count) vehicles")
        } catch {
            print("⚠️ [VehicleService] Failed to cache vehicles: \(error.localizedDescription)")
        }
    }

    /// Recupera i veicoli dalla cache locale
    /// - Returns: Array di VehicleResponse cachati o nil se non disponibili
    func getCachedVehicles() -> [VehicleResponse]? {
        guard let data = UserDefaults.standard.data(forKey: "cachedVehicles") else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            let vehicles = try decoder.decode([VehicleResponse].self, from: data)
            print("✅ [VehicleService] Retrieved \(vehicles.count) vehicles from cache")
            return vehicles
        } catch {
            print("⚠️ [VehicleService] Failed to decode cached vehicles: \(error.localizedDescription)")
            return nil
        }
    }

    /// Pulisce la cache dei veicoli
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: "cachedVehicles")
        print("🧹 [VehicleService] Cache cleared")
    }

    // MARK: - Health Check
    /// Verifica lo stato del servizio backend
    /// - Returns: true se il servizio è attivo, false altrimenti
    func healthCheck() async -> Bool {
        struct HealthResponse: Codable {
            let status: String
            let database: String?
        }

        do {
            let response: HealthResponse = try await networkManager.get(endpoint: "/v1/health")
            let isHealthy = response.status == "OK" || response.status == "ok"
            print(isHealthy ? "✅ [VehicleService] Backend is healthy" : "⚠️ [VehicleService] Backend is unhealthy")
            return isHealthy
        } catch {
            print("❌ [VehicleService] Health check failed: \(error.localizedDescription)")
            return false
        }
    }
}
