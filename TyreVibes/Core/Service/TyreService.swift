import Foundation

// MARK: - Tyre Service Errors
enum TyreServiceError: LocalizedError {
    case tyreNotFound
    case fetchFailed(String)
    case saveFailed(String)
    case deleteFailed(String)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .tyreNotFound:
            return "Pneumatico non trovato"
        case .fetchFailed(let message):
            return "Errore nel recupero dei pneumatici: \(message)"
        case .saveFailed(let message):
            return "Errore nel salvataggio del pneumatico: \(message)"
        case .deleteFailed(let message):
            return "Errore nell'eliminazione del pneumatico: \(message)"
        case .invalidData:
            return "Dati pneumatico non validi"
        }
    }
}

// MARK: - Tyre Data Models
struct TyreSetRequest: Codable {
    let vehicleId: Int
    let tyres: [TyreData]
    let setName: String?
    let season: String?

    enum CodingKeys: String, CodingKey {
        case vehicleId = "vehicle_id"
        case tyres
        case setName = "set_name"
        case season
    }
}

struct TyreData: Codable {
    let sizeLabel: String
    let brand: String?
    let model: String?
    let season: String?
    let dot: String?
    let loadIndex: String?
    let speedIndex: String?
    let width: Int?
    let ratio: Int?
    let diameter: Int?

    enum CodingKeys: String, CodingKey {
        case sizeLabel = "size_label"
        case brand
        case model
        case season
        case dot
        case loadIndex = "load_index"
        case speedIndex = "speed_index"
        case width
        case ratio
        case diameter
    }
}

struct TyreSetInfo: Codable, Identifiable {
    let id: Int
    let name: String
    let season: String?
    let position: String?
    let tyreCount: Int

    enum CodingKeys: String, CodingKey {
        case id = "set_id"
        case name = "set_name"
        case season
        case position
        case tyreCount = "tyre_count"
    }
}

struct TyreSetResponse: Codable {
    let sets: [TyreSetInfo]
}

// MARK: - Tyre Service
class TyreService {
    static let shared = TyreService()
    private let networkManager = NetworkManager.shared

    private init() {}

    // MARK: - Fetch Tyres for Vehicle
    /// Recupera tutti i pneumatici associati a un veicolo
    /// - Parameter vehicleId: ID del veicolo
    /// - Returns: Array di VehicleTyre
    func fetchTyres(for vehicleId: Int) async throws -> [VehicleTyre] {
        do {
            let tyres: [VehicleTyre] = try await networkManager.get(
                endpoint: "/v1/tyres_vehicles/vehicle/\(vehicleId)"
            )
            print("✅ [TyreService] Fetched \(tyres.count) tyres for vehicle \(vehicleId)")
            return tyres
        } catch {
            print("❌ [TyreService] Failed to fetch tyres: \(error.localizedDescription)")
            throw TyreServiceError.fetchFailed(error.localizedDescription)
        }
    }

    // MARK: - Fetch Tyre Sets
    /// Recupera i set di pneumatici (anteriori, posteriori, ecc.) per un veicolo
    /// - Parameter vehicleId: ID del veicolo
    /// - Returns: Array di TyreSetInfo
    func fetchTyreSets(for vehicleId: Int) async throws -> [TyreSetInfo] {
        do {
            let response: TyreSetResponse = try await networkManager.get(
                endpoint: "/v1/tyres_vehicles/vehicle/\(vehicleId)/sets"
            )
            print("✅ [TyreService] Fetched \(response.sets.count) tyre sets for vehicle \(vehicleId)")
            return response.sets
        } catch {
            print("❌ [TyreService] Failed to fetch tyre sets: \(error.localizedDescription)")
            throw TyreServiceError.fetchFailed(error.localizedDescription)
        }
    }

    // MARK: - Save Tyres
    /// Salva un set di pneumatici per un veicolo
    /// - Parameters:
    ///   - vehicleId: ID del veicolo
    ///   - tyres: Array di dati pneumatici
    ///   - setName: Nome del set (es. "Anteriore", "Posteriore")
    ///   - season: Stagione (es. "Summer", "Winter", "All Season")
    func saveTyres(
        vehicleId: Int,
        tyres: [TyreData],
        setName: String? = nil,
        season: String? = nil
    ) async throws {
        guard !tyres.isEmpty else {
            throw TyreServiceError.invalidData
        }

        let request = TyreSetRequest(
            vehicleId: vehicleId,
            tyres: tyres,
            setName: setName,
            season: season
        )

        do {
            struct SaveResponse: Codable {
                let message: String
                let insertedCount: Int

                enum CodingKeys: String, CodingKey {
                    case message
                    case insertedCount = "inserted_count"
                }
            }

            let _: SaveResponse = try await networkManager.post(
                endpoint: "/v1/tyres_vehicles",
                body: request
            )
            print("✅ [TyreService] Saved \(tyres.count) tyres for vehicle \(vehicleId)")
        } catch {
            print("❌ [TyreService] Failed to save tyres: \(error.localizedDescription)")
            throw TyreServiceError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - Delete Tyre Set
    /// Elimina un set di pneumatici
    /// - Parameters:
    ///   - vehicleId: ID del veicolo
    ///   - setName: Nome del set da eliminare
    ///   - setId: ID del set da eliminare (opzionale)
    func deleteTyreSet(vehicleId: Int, setName: String? = nil, setId: Int? = nil) async throws {
        guard setName != nil || setId != nil else {
            throw TyreServiceError.invalidData
        }

        var parameters: [String: Any] = [:]
        if let setName = setName {
            parameters["setName"] = setName
        }
        if let setId = setId {
            parameters["setId"] = setId
        }

        do {
            try await networkManager.delete(
                endpoint: "/v1/tyres_vehicles/vehicle/\(vehicleId)/set",
                parameters: parameters
            )
            print("✅ [TyreService] Deleted tyre set for vehicle \(vehicleId)")
        } catch {
            print("❌ [TyreService] Failed to delete tyre set: \(error.localizedDescription)")
            throw TyreServiceError.deleteFailed(error.localizedDescription)
        }
    }

    // MARK: - Helper Methods
    /// Raggruppa i pneumatici per set
    /// - Parameter tyres: Array di VehicleTyre
    /// - Returns: Dizionario con setId come chiave e array di pneumatici come valore
    func groupTyresBySets(_ tyres: [VehicleTyre]) -> [Int: [VehicleTyre]] {
        var grouped: [Int: [VehicleTyre]] = [:]

        for tyre in tyres {
            let setId = tyre.setId ?? 0
            if grouped[setId] == nil {
                grouped[setId] = []
            }
            grouped[setId]?.append(tyre)
        }

        return grouped
    }

    /// Crea oggetti TyreSizeSet dai pneumatici
    /// - Parameter tyres: Array di VehicleTyre
    /// - Returns: Array di TyreSizeSet
    func createTyreSizeSets(from tyres: [VehicleTyre]) -> [TyreSizeSet] {
        let grouped = groupTyresBySets(tyres)

        return grouped.map { setId, setTyres in
            let setName = setTyres.first?.setName ?? "Set \(setId)"
            let isDefault = setTyres.contains(where: { $0.setId == 1 })

            return TyreSizeSet(
                id: setId,
                name: setName,
                tyres: setTyres,
                isDefault: isDefault
            )
        }.sorted { $0.id < $1.id }
    }

    // MARK: - Tyre Size Validation
    /// Valida i dati di un pneumatico
    /// - Parameter tyre: Dati pneumatico da validare
    /// - Returns: true se valido, false altrimenti
    func validateTyreData(_ tyre: TyreData) -> Bool {
        // Verifica size label obbligatorio
        guard !tyre.sizeLabel.isEmpty else {
            return false
        }

        // Verifica formato size label (es. "225/45 R17")
        let sizePattern = #"^\d{3}/\d{2}\s*R\d{2}$"#
        let regex = try? NSRegularExpression(pattern: sizePattern)
        let range = NSRange(location: 0, length: tyre.sizeLabel.utf16.count)

        return regex?.firstMatch(in: tyre.sizeLabel, range: range) != nil
    }

    /// Parsa una size label in componenti
    /// - Parameter sizeLabel: Stringa size label (es. "225/45 R17")
    /// - Returns: Tupla con width, ratio e diameter
    func parseSizeLabel(_ sizeLabel: String) -> (width: Int?, ratio: Int?, diameter: Int?)? {
        let pattern = #"(\d{3})/(\d{2})\s*R(\d{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: sizeLabel, range: NSRange(sizeLabel.startIndex..., in: sizeLabel)) else {
            return nil
        }

        guard match.numberOfRanges == 4,
              let widthRange = Range(match.range(at: 1), in: sizeLabel),
              let ratioRange = Range(match.range(at: 2), in: sizeLabel),
              let diameterRange = Range(match.range(at: 3), in: sizeLabel) else {
            return nil
        }

        let width = Int(sizeLabel[widthRange])
        let ratio = Int(sizeLabel[ratioRange])
        let diameter = Int(sizeLabel[diameterRange])

        return (width, ratio, diameter)
    }
}
