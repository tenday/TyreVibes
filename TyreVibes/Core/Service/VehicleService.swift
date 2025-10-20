import Foundation

// MARK: - Vehicle Service Errors
enum VehicleServiceError: LocalizedError {
    case vehicleNotFound
    case fetchFailed(String)
    case deleteFailed(String)
    case associationFailed(String)
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
    /// Associa un veicolo a un utente
    /// - Parameters:
    ///   - vehicleId: ID del veicolo
    ///   - userId: ID dell'utente
    /// - Returns: Tupla con immagine base64 e MIME type
    func associateVehicleToUser(vehicleId: Int, userId: String) async throws -> (imageBase64: String?, mimeType: String?) {
        struct AssociationResponse: Codable {
            let message: String
            let imageBase64: String?
            let mimeType: String?

            enum CodingKeys: String, CodingKey {
                case message
                case imageBase64 = "image_base64"
                case mimeType = "mime_type"
            }
        }

        do {
            let response: AssociationResponse = try await networkManager.post(
                endpoint: "/v1/vehicles/\(vehicleId)/user/\(userId)"
            )
            print("✅ [VehicleService] Associated vehicle \(vehicleId) to user \(userId)")
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
