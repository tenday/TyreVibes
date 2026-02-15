import Foundation

// MARK: - API Response Models

struct OEMMaintenanceResponse: Codable {
    let data: [OEMMaintenanceItem]?
    let error: String?
}

struct OEMMaintenanceItem: Codable {
    let desc: String?
    let dueMileage: Int?
    let dueMonths: Int?
    let isOem: Bool?
    let repair: OEMRepairInfo?
    let parts: [OEMPartInfo]?

    enum CodingKeys: String, CodingKey {
        case desc
        case dueMileage = "due_mileage"
        case dueMonths = "due_months"
        case isOem = "is_oem"
        case repair
        case parts
    }
}

struct OEMRepairInfo: Codable {
    let laborCost: Double?
    let totalCost: Double?

    enum CodingKeys: String, CodingKey {
        case laborCost = "labor_cost"
        case totalCost = "total_cost"
    }
}

struct OEMPartInfo: Codable {
    let name: String?
    let partNumber: String?
    let cost: Double?

    enum CodingKeys: String, CodingKey {
        case name
        case partNumber = "part_number"
        case cost
    }
}

// MARK: - Service Errors

enum ManufacturerMaintenanceError: LocalizedError {
    case noApiKey
    case noVin
    case networkError(String)
    case decodingError(String)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .noApiKey: return "Chiave API Vehicle Databases non configurata."
        case .noVin: return "VIN del veicolo non disponibile."
        case .networkError(let msg): return "Errore di rete: \(msg)"
        case .decodingError(let msg): return "Errore nel parsing della risposta: \(msg)"
        case .apiError(let msg): return "Errore API: \(msg)"
        }
    }
}

// MARK: - Manufacturer Maintenance Service

@MainActor
final class ManufacturerMaintenanceService: ObservableObject {
    static let shared = ManufacturerMaintenanceService()

    @Published var isLoading = false
    @Published var lastError: String?

    private init() {}

    // MARK: - Public

    /// Fetches OEM maintenance intervals from Vehicle Databases API and applies them to the interval store.
    /// Returns the number of intervals applied, or throws on failure.
    @discardableResult
    func fetchAndApplyOEMIntervals(vin: String, vehicleId: Int) async throws -> Int {
        guard !vin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ManufacturerMaintenanceError.noVin
        }

        guard hasOEMBeenFetched(for: vehicleId) == false else {
            return 0
        }

        guard let apiKey = loadApiKey(), !apiKey.isEmpty else {
            throw ManufacturerMaintenanceError.noApiKey
        }

        isLoading = true
        lastError = nil

        defer { isLoading = false }

        let items = try await fetchOEMItems(vin: vin, apiKey: apiKey)
        let count = applyToIntervalStore(items: items, vehicleId: vehicleId)
        markOEMFetched(for: vehicleId)
        return count
    }

    /// Whether OEM intervals have already been fetched for this vehicle.
    func hasOEMBeenFetched(for vehicleId: Int) -> Bool {
        UserDefaults.standard.bool(forKey: "oem_intervals_fetched_\(vehicleId)")
    }

    /// Reset the OEM fetch flag for a vehicle (useful for re-fetching).
    func resetOEMFlag(for vehicleId: Int) {
        UserDefaults.standard.removeObject(forKey: "oem_intervals_fetched_\(vehicleId)")
    }

    // MARK: - Network

    private func fetchOEMItems(vin: String, apiKey: String) async throws -> [OEMMaintenanceItem] {
        let cleanVin = vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let urlString = "https://api.vehicledatabases.com/vehicle-maintenance/v2/\(cleanVin)"

        guard let url = URL(string: urlString) else {
            throw ManufacturerMaintenanceError.networkError("URL non valido.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-AuthKey")
        request.timeoutInterval = 15

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ManufacturerMaintenanceError.networkError(error.localizedDescription)
        }

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw ManufacturerMaintenanceError.apiError("HTTP \(httpResponse.statusCode)")
        }

        do {
            let decoded = try JSONDecoder().decode(OEMMaintenanceResponse.self, from: data)
            if let error = decoded.error {
                throw ManufacturerMaintenanceError.apiError(error)
            }
            return decoded.data ?? []
        } catch let error as ManufacturerMaintenanceError {
            throw error
        } catch {
            throw ManufacturerMaintenanceError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - Mapping & Applying

    private func applyToIntervalStore(items: [OEMMaintenanceItem], vehicleId: Int) -> Int {
        var applied = 0

        for item in items {
            guard let desc = item.desc else { continue }
            guard let type = mapDescriptionToType(desc) else { continue }

            let kmInterval = item.dueMileage
            let monthsInterval = item.dueMonths

            guard kmInterval != nil || monthsInterval != nil else { continue }

            MaintenanceIntervalStore.shared.setOEMInterval(
                type: type,
                kmInterval: kmInterval,
                monthsInterval: monthsInterval,
                vehicleId: vehicleId
            )
            applied += 1
        }

        return applied
    }

    /// Maps an English maintenance description from the API to our MaintenanceType.
    private func mapDescriptionToType(_ description: String) -> MaintenanceSchedule.MaintenanceType? {
        let lower = description.lowercased()

        let keywordMap: [(keywords: [String], type: MaintenanceSchedule.MaintenanceType)] = [
            // Filters (before engine to match "oil filter" before "oil")
            (["air filter", "air cleaner"], .airFilter),
            (["oil filter"], .oilFilter),
            (["fuel filter"], .fuelFilter),
            (["cabin filter", "cabin air", "pollen filter", "hvac filter"], .cabinFilter),
            // Tyres
            (["tire rotation", "tyre rotation", "rotate tire", "rotate tyre"], .rotation),
            (["tire replacement", "tyre replacement", "replace tire", "replace tyre", "new tire", "new tyre"], .replacement),
            (["tire pressure", "tyre pressure", "check pressure", "inflate"], .pressureCheck),
            (["wheel alignment", "alignment"], .alignment),
            (["seasonal tire", "seasonal tyre", "winter tire", "summer tire", "winter tyre", "summer tyre"], .seasonalChange),
            (["wheel balance", "tire balance", "tyre balance", "balancing"], .balancing),
            // Engine
            (["oil change", "engine oil", "change oil", "motor oil", "replace oil"], .oilChange),
            (["spark plug"], .sparkPlugs),
            (["timing belt", "timing chain", "drive belt", "serpentine belt", "accessory belt"], .timingBelt),
            (["clutch"], .clutch),
            (["general service", "full service", "scheduled service", "major service", "minor service", "tune-up", "tune up", "maintenance service"], .generalService),
            // Brakes
            (["brake pad", "brake shoe", "front brake", "rear brake"], .brakePads),
            (["brake disc", "brake rotor", "brake disk"], .brakeDiscs),
            // Fluids
            (["brake fluid"], .brakeFluid),
            (["coolant", "antifreeze", "cooling fluid", "radiator fluid"], .coolant),
            (["washer fluid", "windshield fluid", "wiper fluid"], .washerFluid),
            // Other
            (["battery", "starter battery"], .battery),
            (["shock absorber", "strut", "suspension", "damper"], .shockAbsorbers),
        ]

        for entry in keywordMap {
            for keyword in entry.keywords {
                if lower.contains(keyword) {
                    return entry.type
                }
            }
        }

        return nil
    }

    // MARK: - Local VIN Storage

    /// Returns the VIN for a vehicle: first checks local storage, then falls back to the model's VIN.
    func resolvedVIN(for vehicleId: Int, modelVin: String?) -> String? {
        if let local = localVIN(for: vehicleId), !local.isEmpty {
            return local
        }
        if let model = modelVin, !model.isEmpty {
            return model
        }
        return nil
    }

    /// Get locally stored VIN for a vehicle.
    func localVIN(for vehicleId: Int) -> String? {
        UserDefaults.standard.string(forKey: "vehicle_vin_\(vehicleId)")
    }

    /// Save a VIN locally for a vehicle.
    func saveVIN(_ vin: String, for vehicleId: Int) {
        let cleaned = vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleaned.isEmpty else { return }
        UserDefaults.standard.set(cleaned, forKey: "vehicle_vin_\(vehicleId)")
    }

    // MARK: - Helpers

    private func loadApiKey() -> String? {
        guard let path = Bundle.main.path(forResource: "Api", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            return nil
        }
        return dict["VEHICLE_DATABASES_API_KEY"] as? String
    }

    private func markOEMFetched(for vehicleId: Int) {
        UserDefaults.standard.set(true, forKey: "oem_intervals_fetched_\(vehicleId)")
    }
}
