#if os(visionOS)
import Combine
import Foundation
import Supabase
import SwiftUI

@MainActor
final class VisionGarageStore: ObservableObject {
    @Published var selectedVehicleID: VisionVehicleSnapshot.ID?
    @Published var selectedTyreID: VisionTyreSnapshot.ID?
    @Published private(set) var vehicles: [VisionVehicleSnapshot] = []
    @Published private(set) var cacheLoadMessage: String?
    @Published private(set) var isLoading = false

    private let cacheKey = "cachedVehicles"

    init() {
        reloadFromUserGarageCache()
        Task {
            await reloadFromBackend()
        }
    }

    var selectedVehicle: VisionVehicleSnapshot? {
        vehicles.first { $0.id == selectedVehicleID } ?? vehicles.first
    }

    var tyres: [VisionTyreSnapshot] {
        selectedVehicle?.tyres ?? []
    }

    var selectedTyre: VisionTyreSnapshot? {
        tyres.first { $0.id == selectedTyreID } ?? tyres.first
    }

    func reloadFromUserGarageCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            vehicles = []
            selectedVehicleID = nil
            selectedTyreID = nil
            cacheLoadMessage = "Apri il garage su iPhone per sincronizzare le auto in cache."
            return
        }

        do {
            let cachedVehicles = try decodeVehicles(from: data)
            vehicles = cachedVehicles.map(Self.makeVehicleSnapshot(from:))
            cacheLoadMessage = vehicles.isEmpty ? "Nessuna auto trovata nel garage utente." : nil
            repairSelectionAfterVehicleUpdate()
        } catch {
            vehicles = []
            selectedVehicleID = nil
            selectedTyreID = nil
            cacheLoadMessage = "Cache garage non leggibile: \(error.localizedDescription)"
        }
    }

    func reloadFromBackend() async {
        isLoading = true
        defer { isLoading = false }

        guard let session = try? await Self.supabaseClient.auth.session else {
            cacheLoadMessage = vehicles.isEmpty ? "Accedi su TyreVibes Vision per caricare il garage utente." : nil
            return
        }

        let userId = session.user.id.uuidString
        guard !userId.isEmpty else {
            cacheLoadMessage = vehicles.isEmpty ? "Sessione Vision non valida." : nil
            return
        }

        guard let url = URL(string: "\(Self.apiBaseURL)/v1/vehicles/\(userId)?includeImages=false") else {
            cacheLoadMessage = "Configurazione API Vision non valida."
            return
        }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 18
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                throw NSError(domain: "VisionGarageStore", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
            }

            let fetchedVehicles = try decodeVehicles(from: data)
            UserDefaults.standard.set(data, forKey: cacheKey)
            vehicles = fetchedVehicles.map(Self.makeVehicleSnapshot(from:))
            cacheLoadMessage = vehicles.isEmpty ? "Nessuna auto trovata nel garage utente." : nil
            repairSelectionAfterVehicleUpdate()
        } catch {
            cacheLoadMessage = vehicles.isEmpty ? "Errore caricamento garage: \(error.localizedDescription)" : nil
        }
    }

    func select(_ vehicle: VisionVehicleSnapshot) {
        selectedVehicleID = vehicle.id
        selectedTyreID = vehicle.tyres.first?.id
    }

    func select(_ tyre: VisionTyreSnapshot) {
        selectedTyreID = tyre.id
    }

    func selectVehicle(named selectedEntityName: String) {
        guard let vehicle = vehicles.first(where: { selectedEntityName == entityName(for: $0) }) else {
            return
        }
        select(vehicle)
    }

    func entityName(for vehicle: VisionVehicleSnapshot) -> String {
        "vehicle-\(vehicle.id)"
    }

    private func decodeVehicles(from data: Data) throws -> [CachedVehicleResponse] {
        let decoder = JSONDecoder()

        if let vehicles = try? decoder.decode([CachedVehicleResponse].self, from: data) {
            return vehicles
        }

        let envelope = try decoder.decode(CachedVehiclesEnvelope.self, from: data)
        return envelope.vehicles ?? envelope.data ?? []
    }

    private func repairSelectionAfterVehicleUpdate() {
        if selectedVehicleID == nil || !vehicles.contains(where: { $0.id == selectedVehicleID }) {
            selectedVehicleID = vehicles.first?.id
        }
        if selectedTyreID == nil || !tyres.contains(where: { $0.id == selectedTyreID }) {
            selectedTyreID = tyres.first?.id
        }
    }

    private static func makeVehicleSnapshot(from response: CachedVehicleResponse) -> VisionVehicleSnapshot {
        let vehicle = response.vehicle
        let name = [clean(vehicle.make), clean(vehicle.model)]
            .compactMap { $0 }
            .joined(separator: " ")
        let displayName = name.isEmpty ? clean(vehicle.modelDetail) ?? "Auto \(vehicle.id)" : name
        let plate = clean(response.plate?.plateNumber) ?? "Targa non disponibile"
        let year = response.plate?.year.map(String.init)
            ?? yearPrefix(from: vehicle.saleStart)
            ?? yearPrefix(from: vehicle.createdAt)
            ?? "2024"
        let paintId = clean(vehicle.color) ?? "BLACK"
        let tyres = makeTyreSnapshots(from: response.tyres)

        return VisionVehicleSnapshot(
            id: String(vehicle.id),
            name: displayName,
            plate: plate,
            bodyColor: color(from: paintId),
            imageProfile: makeImageProfile(vehicle: vehicle, year: year, paintId: paintId),
            tyres: tyres
        )
    }

    private static func makeImageProfile(vehicle: CachedVehicle, year: String, paintId: String) -> VisionVehicleImageProfile? {
        guard let make = clean(vehicle.make),
              let modelFamily = clean(vehicle.model) ?? clean(vehicle.modelDetail) else {
            return nil
        }

        return VisionVehicleImageProfile(
            make: make,
            modelFamily: modelFamily,
            year: year,
            paintId: paintId
        )
    }

    private static func makeTyreSnapshots(from tyres: [CachedVehicleTyre]?) -> [VisionTyreSnapshot] {
        let positions = [
            "Anteriore sinistra",
            "Anteriore destra",
            "Posteriore sinistra",
            "Posteriore destra"
        ]
        let fallbackLabel = tyres?.first.flatMap(tyreLabel(from:)) ?? "Pneumatico non configurato"

        return positions.enumerated().map { index, position in
            let source = tyres?.isEmpty == false ? tyres?[index % (tyres?.count ?? 1)] : nil
            return VisionTyreSnapshot(
                position: position,
                model: source.flatMap(tyreLabel(from:)) ?? fallbackLabel,
                treadDepthMillimeters: 0,
                pressureBar: 0,
                healthState: .unknown
            )
        }
    }

    private static func tyreLabel(from tyre: CachedVehicleTyre) -> String? {
        if let sizeLabel = clean(tyre.sizeLabel) {
            return sizeLabel
        }

        guard let width = tyre.width, let ratio = tyre.ratio, let diameter = tyre.diameter else {
            return clean(tyre.setName)
        }

        let loadSpeed = [tyre.loadIndex, tyre.speedIndex].compactMap(clean).joined()
        return loadSpeed.isEmpty ? "\(width)/\(ratio) R\(diameter)" : "\(width)/\(ratio) R\(diameter) \(loadSpeed)"
    }

    private static func clean(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }

        let lowercased = trimmed.lowercased()
        guard lowercased != "null", lowercased != "n/a", lowercased != "na", lowercased != "-" else {
            return nil
        }

        return trimmed
    }

    private static func yearPrefix(from value: String?) -> String? {
        guard let value = clean(value), value.count >= 4 else { return nil }
        let prefix = String(value.prefix(4))
        return prefix.allSatisfy(\.isNumber) ? prefix : nil
    }

    private static func color(from raw: String) -> Color {
        let normalized = raw
            .folding(options: .diacriticInsensitive, locale: .current)
            .uppercased()

        if normalized.contains("WHITE") || normalized.contains("BIANCO") {
            return .white
        }
        if normalized.contains("RED") || normalized.contains("ROSSO") {
            return .red
        }
        if normalized.contains("BLUE") || normalized.contains("BLU") || normalized.contains("AZZURRO") {
            return .blue
        }
        if normalized.contains("GREEN") || normalized.contains("VERDE") {
            return .green
        }
        if normalized.contains("YELLOW") || normalized.contains("GIALLO") {
            return .yellow
        }
        if normalized.contains("ORANGE") || normalized.contains("ARANC") {
            return .orange
        }
        if normalized.contains("GRAY") || normalized.contains("GREY") || normalized.contains("GRIGIO") || normalized.contains("SILVER") {
            return .gray
        }

        return .black
    }

    private static let apiBaseURL: String = {
        if let value = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String, !value.isEmpty {
            return value
        }

        if let path = Bundle.main.path(forResource: "Api", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let value = plist["BASE_URL"] as? String,
           !value.isEmpty {
            return value
        }

        return "https://www.tyrevibes.com/api"
    }()

    private static let supabaseClient: SupabaseClient = {
        let fallbackURL = "https://jbcbrnegmqraivdfmlsn.supabase.co"
        let fallbackKey = "sb_publishable_j45ieNq6Q9Tyz0qyib5PPA_pEuCNzDc"

        let plist: NSDictionary? = {
            guard let path = Bundle.main.path(forResource: "Api", ofType: "plist") else { return nil }
            return NSDictionary(contentsOfFile: path)
        }()

        let urlString = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String)
            ?? plist?["SUPABASE_URL"] as? String
            ?? fallbackURL
        let key = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_KEY") as? String)
            ?? plist?["SUPABASE_KEY"] as? String
            ?? fallbackKey

        return SupabaseClient(
            supabaseURL: URL(string: urlString) ?? URL(string: fallbackURL)!,
            supabaseKey: key,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }()
}

private struct CachedVehiclesEnvelope: Decodable {
    let vehicles: [CachedVehicleResponse]?
    let data: [CachedVehicleResponse]?
}

private struct CachedVehicleResponse: Decodable {
    let vehicle: CachedVehicle
    let plate: CachedPlate?
    let tyres: [CachedVehicleTyre]?
}

private struct CachedVehicle: Decodable {
    let id: Int
    let modelDetail: String?
    let make: String?
    let model: String?
    let color: String?
    let saleStart: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case modelDetail = "model_detail"
        case make
        case model
        case color
        case saleStart = "sale_start"
        case createdAt = "created_at"
    }
}

private struct CachedPlate: Decodable {
    let plateNumber: String?
    let year: Int?

    enum CodingKeys: String, CodingKey {
        case plateNumber = "plate_number"
        case year
    }
}

private struct CachedVehicleTyre: Decodable {
    let width: Int?
    let diameter: Int?
    let ratio: Int?
    let speedIndex: String?
    let loadIndex: String?
    let sizeLabel: String?
    let setName: String?

    enum CodingKeys: String, CodingKey {
        case width
        case diameter
        case ratio
        case speedIndex = "speed_index"
        case loadIndex = "load_index"
        case sizeLabel = "size_label"
        case setName = "set_name"
    }
}
#endif
