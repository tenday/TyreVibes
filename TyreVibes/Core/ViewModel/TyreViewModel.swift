import Foundation

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
    
    func insertTyre(vehicleId: Int) {

        guard let baseURLString = PlateAPIService.apiConfig["BASE_URL"] as? String else {
            errorMessage = "Base URL non configurato"
            return
        }

        guard let url = URL(string: baseURLString + "/tyres_vehicles") else {
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
                self?.success = true
            }
        }.resume()
    }

    func fetchTyres(vehicleId: Int) {
        guard let baseURLString = PlateAPIService.apiConfig["BASE_URL"] as? String else {
            errorMessage = "Base URL non configurato"
            return
        }

        guard let url = URL(string: baseURLString + "/tyres_vehicles/vehicle/\(vehicleId)") else {
            errorMessage = "URL non valido"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        isLoading = true
        errorMessage = nil

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
                } catch {
                    self?.errorMessage = "Errore nella decodifica: \(error.localizedDescription)"
                }
            }
        }.resume()
    }

}
