import Foundation
import Supabase

struct TyreRegistrationPayload {
    let brand: String
    let model: String
    let size: String
    let dot: String
    let loadIndex: String
    let speedRating: String
    let season: String
    let setName: String?
    let setPosition: String?

    init(
        brand: String,
        model: String,
        size: String,
        dot: String,
        loadIndex: String,
        speedRating: String,
        season: String,
        setName: String? = nil,
        setPosition: String? = nil
    ) {
        self.brand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        self.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        self.size = size.trimmingCharacters(in: .whitespacesAndNewlines)
        self.dot = dot.trimmingCharacters(in: .whitespacesAndNewlines)
        self.loadIndex = loadIndex.trimmingCharacters(in: .whitespacesAndNewlines)
        self.speedRating = speedRating.trimmingCharacters(in: .whitespacesAndNewlines)
        self.season = season.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSetName = setName?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.setName = trimmedSetName?.isEmpty == true ? nil : trimmedSetName
        let trimmedSetPosition = setPosition?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.setPosition = trimmedSetPosition?.isEmpty == true ? nil : trimmedSetPosition
    }

    func toDictionary(vehicleId: Int) -> [String: Any] {
        var payload: [String: Any] = [
            "vehicle_id": vehicleId,
            "brand": brand,
            "model": model,
            "size": size,
            "dot": dot,
            "loadIndex": loadIndex,
            "speedRating": speedRating,
            "season": season
        ]
        if let setName {
            payload["setName"] = setName
        }
        if let setPosition {
            payload["setPosition"] = setPosition
        }
        return payload
    }
}

enum TyreRegistrationError: LocalizedError {
    case missingBaseURL
    case invalidURL
    case encodingFailed
    case server(status: Int, message: String?)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return "Base URL non configurato"
        case .invalidURL:
            return "URL non valido"
        case .encodingFailed:
            return "Errore nella codifica dei dati pneumatico"
        case let .server(status, message):
            if let message = message, !message.isEmpty {
                return "Errore server (\(status)): \(message)"
            }
            return "Errore server (\(status))"
        case .emptyResponse:
            return "Risposta vuota dal server"
        }
    }
}

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
            return nil
        }

        let decoder = JSONDecoder()
        if let tyres = try? decoder.decode([TyreRegistered].self, from: data) {
            return tyres
        }

        return nil
    }

    func invalidateCache(forVehicleId vehicleId: Int) {
        defaults.removeObject(forKey: cachePrefix + "\(vehicleId)")
        defaults.removeObject(forKey: timestampPrefix + "\(vehicleId)")
    }

    func clearAllCache() {
        let keys = Array(defaults.dictionaryRepresentation().keys)
        keys.filter { $0.hasPrefix(cachePrefix) || $0.hasPrefix(timestampPrefix) }
            .forEach { defaults.removeObject(forKey: $0) }
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
    let setId: Int? = nil
    let setName: String? = nil

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
        case setId = "set_id"
        case setName = "set_name"
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
    @Published var setName: String = ""
    @Published var setPosition: String = ""

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var success: Bool = false

    @Published var registeredTyres: [TyreRegistered] = []

    // Computed property per retrocompatibilità
    var tyres: [TyreRegistered] {
        return registeredTyres
    }


    func insertTyre(vehicleId: Int) {
        let payload = TyreRegistrationPayload(
            brand: brand,
            model: model,
            size: size,
            dot: dot,
            loadIndex: loadIndex,
            speedRating: speedRating,
            season: season,
            setName: setName,
            setPosition: setPosition
        )

        registerTyres([payload], vehicleId: vehicleId)
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

        // Get auth token and execute request
        Task {
            await AuthTokenHelper.addAuthHeader(to: &request)

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

    func deleteTyre(tyreId: Int, vehicleId: Int, completion: @escaping (Bool) -> Void) {
        guard let baseURLString = PlateAPIService.apiConfig["BASE_URL"] as? String else {
            errorMessage = "Base URL non configurato"
            completion(false)
            return
        }

        guard let url = URL(string: baseURLString + "/v1/tyres_vehicles/\(tyreId)") else {
            errorMessage = "URL non valido"
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        print("🗑️ Eliminazione pneumatico ID: \(tyreId)")

        // Get auth token and execute request
        Task {
            await AuthTokenHelper.addAuthHeader(to: &request)

            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Errore network: \(error.localizedDescription)")
                    self?.errorMessage = error.localizedDescription
                    completion(false)
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 Status code: \(httpResponse.statusCode)")
                    if (200...299).contains(httpResponse.statusCode) {
                        print("✅ Pneumatico eliminato con successo")
                        // Rimuovi dalla lista locale
                        self?.registeredTyres.removeAll { $0.id == tyreId }
                        // Invalida la cache
                        TyreCacheManager.shared.invalidateCache(forVehicleId: vehicleId)
                        completion(true)
                    } else {
                        if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                            print("📄 Response body: \(responseBody)")
                        }
                        self?.errorMessage = "Errore server: \(httpResponse.statusCode)"
                        completion(false)
                    }
                }
            }
            }.resume()
        }
    }

    func registerTyres(
        _ payloads: [TyreRegistrationPayload],
        vehicleId: Int,
        invalidateCache: Bool = true,
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        guard !payloads.isEmpty else {
            completion?(.success(()))
            return
        }

        isLoading = true
        errorMessage = nil
        success = false

        let sanitizedPayloads = payloads.map {
            TyreRegistrationPayload(
                brand: $0.brand,
                model: $0.model,
                size: $0.size,
                dot: $0.dot.uppercased(),
                loadIndex: $0.loadIndex,
                speedRating: $0.speedRating.uppercased(),
                season: $0.season,
                setName: $0.setName,
                setPosition: $0.setPosition
            )
        }

        func registerNext(at index: Int) {
            performRegistration(payload: sanitizedPayloads[index], vehicleId: vehicleId) { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success:
                    let nextIndex = index + 1
                    if nextIndex < sanitizedPayloads.count {
                        registerNext(at: nextIndex)
                    } else {
                        self.isLoading = false
                        self.success = true
                        if invalidateCache {
                            TyreCacheManager.shared.invalidateCache(forVehicleId: vehicleId)
                        }
                        completion?(.success(()))
                    }
                case .failure(let error):
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    completion?(.failure(error))
                }
            }
        }

        registerNext(at: 0)
    }

    private func performRegistration(
        payload: TyreRegistrationPayload,
        vehicleId: Int,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let baseURLString = PlateAPIService.apiConfig["BASE_URL"] as? String else {
            completion(.failure(TyreRegistrationError.missingBaseURL))
            return
        }

        guard let url = URL(string: baseURLString + "/v1/tyres_vehicles") else {
            completion(.failure(TyreRegistrationError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let body = payload.toDictionary(vehicleId: vehicleId)
            print("🔄 Inviando registrazione pneumatico: \(body)")
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(TyreRegistrationError.encodingFailed))
            return
        }

        // Get auth token and execute request
        Task {
            await AuthTokenHelper.addAuthHeader(to: &request)

            URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Errore network: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 Status code: \(httpResponse.statusCode)")
                    guard (200...299).contains(httpResponse.statusCode) else {
                        var message: String?
                        if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                            print("📄 Response body: \(responseBody)")
                            message = responseBody
                        }
                        completion(.failure(TyreRegistrationError.server(status: httpResponse.statusCode, message: message)))
                        return
                    }
                }

                if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                    print("✅ Response: \(responseBody)")
                }

                print("✅ Registrazione pneumatico completata")
                completion(.success(()))
            }
            }.resume()
        }
    }
}
