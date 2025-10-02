import Foundation

// MARK: - Cache Manager
class TyreCacheManager {
    static let shared = TyreCacheManager()
    private let defaults = UserDefaults.standard
    private let cachePrefix = "tyres_cache_vehicle_"
    private let timestampPrefix = "tyres_timestamp_vehicle_"
    private let cacheValidityDuration: TimeInterval = 300 // 5 minuti

    private init() {}

    func saveTyres(_ tyres: [TyreRegistered], forVehicleId vehicleId: Int) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(tyres) {
            defaults.set(encoded, forKey: cachePrefix + "\(vehicleId)")
            defaults.set(Date().timeIntervalSince1970, forKey: timestampPrefix + "\(vehicleId)")
            print("💾 Cache salvata per veicolo \(vehicleId): \(tyres.count) pneumatici")
        }
    }

    func getTyres(forVehicleId vehicleId: Int) -> [TyreRegistered]? {
        // Verifica se la cache è ancora valida
        guard let timestamp = defaults.double(forKey: timestampPrefix + "\(vehicleId)") as Double?,
              Date().timeIntervalSince1970 - timestamp < cacheValidityDuration else {
            print("⏰ Cache scaduta per veicolo \(vehicleId)")
            return nil
        }

        // Recupera i dati dalla cache
        guard let data = defaults.data(forKey: cachePrefix + "\(vehicleId)") else {
            print("❌ Nessuna cache trovata per veicolo \(vehicleId)")
            return nil
        }

        let decoder = JSONDecoder()
        if let tyres = try? decoder.decode([TyreRegistered].self, from: data) {
            print("✅ Cache caricata per veicolo \(vehicleId): \(tyres.count) pneumatici")
            return tyres
        }

        return nil
    }

    func invalidateCache(forVehicleId vehicleId: Int) {
        defaults.removeObject(forKey: cachePrefix + "\(vehicleId)")
        defaults.removeObject(forKey: timestampPrefix + "\(vehicleId)")
        print("🗑️ Cache invalidata per veicolo \(vehicleId)")
    }

    func clearAllCache() {
        let keys = Array(defaults.dictionaryRepresentation().keys)
        keys.filter { $0.hasPrefix(cachePrefix) || $0.hasPrefix(timestampPrefix) }
            .forEach { defaults.removeObject(forKey: $0) }
        print("🗑️ Tutta la cache eliminata")
    }
}

struct TyreRegistered: Codable, Identifiable {
    let id: Int
    let vehicleId: Int
    let brand: String
    let model: String
    let size: String
    let dot: String
    let loadIndex: String
    let speedRating: String
    let season: String

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId = "vehicle_id"
        case brand
        case model
        case size
        case dot
        case loadIndex
        case speedRating
        case season
    }
}

class TyreViewModel: ObservableObject {
    @Published var brand: String = ""
    @Published var model: String = ""
    @Published var size: String = ""
    @Published var dot: String = ""
    @Published var loadIndex: String = ""
    @Published var speedRating: String = ""
    @Published var season: String = "Winter"

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var success: Bool = false

    @Published var registeredTyres: [TyreRegistered] = []

    // Computed property per retrocompatibilità
    var tyres: [TyreRegistered] {
        return registeredTyres
    }

    func insertTyre(vehicleId: Int) {

        guard let baseURLString = PlateAPIService.apiConfig["BASE_URL"] as? String else {
            errorMessage = "Base URL non configurato"
            return
        }

        guard let url = URL(string: baseURLString + "/v1/tyres_vehicles") else {
            errorMessage = "URL non valido"
            return
        }

        let record: [String: Any] = [
            "vehicle_id": vehicleId,
            "brand": brand,
            "model": model.trimmingCharacters(in: .whitespacesAndNewlines),
            "size": size,
            "dot": dot,
            "loadIndex": loadIndex,
            "speedRating": speedRating,
            "season": season
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: record, options: [])
        } catch {
            errorMessage = "Errore JSON: \(error.localizedDescription)"
            return
        }

        isLoading = true
        errorMessage = nil
        success = false

        print("🔄 Inviando richiesta insertTyre per vehicleId: \(vehicleId)")
        print("📦 Dati: \(record)")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    print("❌ Errore network: \(error.localizedDescription)")
                    self?.errorMessage = error.localizedDescription
                    return
                }
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 Status code: \(httpResponse.statusCode)")
                    if !(200...299).contains(httpResponse.statusCode) {
                        if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                            print("📄 Response body: \(responseBody)")
                        }
                        self?.errorMessage = "Errore server: \(httpResponse.statusCode)"
                        return
                    }
                }
                if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                    print("✅ Response: \(responseBody)")
                }
                print("✅ Inserimento completato con successo")
                self?.success = true
                // Invalida la cache dopo l'inserimento
                TyreCacheManager.shared.invalidateCache(forVehicleId: vehicleId)
            }
        }.resume()
    }

    func fetchTyres(vehicleId: Int, forceRefresh: Bool = false) {
        // Controlla prima la cache se non è richiesto un refresh forzato
        if !forceRefresh, let cachedTyres = TyreCacheManager.shared.getTyres(forVehicleId: vehicleId) {
            print("📦 Uso cache per veicolo \(vehicleId)")
            self.registeredTyres = cachedTyres
            return
        }

        guard let baseURLString = PlateAPIService.apiConfig["BASE_URL"] as? String else {
            errorMessage = "Base URL non configurato"
            return
        }

        guard let url = URL(string: baseURLString + "/v1/tyres_vehicles/vehicle/\(vehicleId)") else {
            errorMessage = "URL non valido"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        isLoading = true
        errorMessage = nil

        print("🌐 Fetch da server per veicolo \(vehicleId)")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }

                if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                    self?.errorMessage = "Errore server: \(httpResponse.statusCode)"
                    return
                }

                guard let data = data else {
                    self?.errorMessage = "Nessun dato ricevuto"
                    return
                }

                do {
                    let tyres = try JSONDecoder().decode([TyreRegistered].self, from: data)
                    self?.registeredTyres = tyres
                    // Salva in cache
                    TyreCacheManager.shared.saveTyres(tyres, forVehicleId: vehicleId)
                } catch {
                    self?.errorMessage = "Errore nella decodifica: \(error.localizedDescription)"
                }
            }
        }.resume()
    }

}
