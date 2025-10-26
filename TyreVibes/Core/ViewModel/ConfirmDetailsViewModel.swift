import Foundation
import SwiftUI

@MainActor
class ConfirmDetailsViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var alertItem: AlertItem?
    @Published var didSavePlate = false
    @Published var vehicleImage: UIImage?
    @Published var vehicleImageColored: UIImage?
    @Published var vehicleImageOriginal: UIImage?

    private let plateAPIService = PlateAPIService()
    private var activeImageRequestID = UUID()

    private func ensureRenderable(_ image: UIImage) -> UIImage {
        if image.cgImage != nil { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
    
    public func associateVehicleWithUser(vehicleId: Int, vehicleData: PlateData? = nil, color: String = "") async {
        isLoading = true
        let userId = await AuthService.currentUserId
        guard let userId = userId else {
            print("userId not found")
            isLoading = false
            return
        }

        guard let plateData = vehicleData else {
            self.alertItem = AlertItem(title: "Errore", message: "Dati del veicolo mancanti")
            self.isLoading = false
            return
        }

        // Scarica SEMPRE le immagini con il colore selezionato prima di chiamare l'API
        await self.downloadAndAssociateVehicleImages(vehicleId: vehicleId, plateData: plateData, color: color, userId: userId)
    }

    // MARK: - Download and Associate Vehicle Images
    private func downloadAndAssociateVehicleImages(vehicleId: Int, plateData: PlateData, color: String, userId: String) async {
        activeImageRequestID = UUID()
        let requestID = activeImageRequestID

        VehicleImageService.clearCache()

        VehicleImageService.fetchVehicleImage(
            make: plateData.make ?? "",
            modelFamily: plateData.model ?? "",
            year: plateData.year ?? "",
            paintId: color,
            angle: 23,
            plate: plateData.plate
        ) { [weak self] result in
            guard let self = self, self.activeImageRequestID == requestID else { return }

            switch result {
            case .success(let imgColored23):
                Task { @MainActor in
                    guard self.activeImageRequestID == requestID else { return }
                    let safeImageColored23 = self.ensureRenderable(imgColored23)

                    // Scarica l'immagine senza colore (angolo 23)
                    VehicleImageService.fetchVehicleImage(
                        make: plateData.make ?? "",
                        modelFamily: plateData.model ?? "",
                        year: plateData.year ?? "",
                        paintId: "",
                        angle: 23,
                        plate: plateData.plate
                    ) { [weak self] result in
                        guard let self = self, self.activeImageRequestID == requestID else { return }

                        switch result {
                        case .success(let imgOriginal23):
                            Task { @MainActor in
                                guard self.activeImageRequestID == requestID else { return }
                                let safeImageOriginal23 = self.ensureRenderable(imgOriginal23)

                                // Scarica l'immagine colorata (angolo 12)
                                VehicleImageService.fetchVehicleImage(
                                    make: plateData.make ?? "",
                                    modelFamily: plateData.model ?? "",
                                    year: plateData.year ?? "",
                                    paintId: color,
                                    angle: 12,
                                    plate: plateData.plate
                                ) { [weak self] result in
                                    guard let self = self, self.activeImageRequestID == requestID else { return }

                                    switch result {
                                    case .success(let imgColored12):
                                        Task { @MainActor in
                                            guard self.activeImageRequestID == requestID else { return }
                                            let safeImageColored12 = self.ensureRenderable(imgColored12)

                                            // Scarica l'immagine senza colore (angolo 12)
                                            VehicleImageService.fetchVehicleImage(
                                                make: plateData.make ?? "",
                                                modelFamily: plateData.model ?? "",
                                                year: plateData.year ?? "",
                                                paintId: "",
                                                angle: 12,
                                                plate: plateData.plate
                                            ) { [weak self] result in
                                                guard let self = self, self.activeImageRequestID == requestID else { return }

                                                switch result {
                                                case .success(let imgOriginal12):
                                                    Task { @MainActor in
                                                        guard self.activeImageRequestID == requestID else { return }
                                                        let safeImageOriginal12 = self.ensureRenderable(imgOriginal12)

                                                        do {
                                                            try await self.plateAPIService.savePlate(
                                                                plateData: plateData,
                                                                color: color,
                                                                userId: AuthService.currentUserId ?? "",
                                                                images: [safeImageColored23, safeImageColored12],
                                                                imagesColor: [color, color]
                                                            )
                                                            self.vehicleImage = safeImageColored23
                                                            self.didSavePlate = true

                                                            self.vehicleImageColored = safeImageColored23
                                                            self.vehicleImageOriginal = safeImageOriginal23
                                                            self.didSavePlate = true
                                                            self.isLoading = false
                                                        } catch let apiError as PlateAPIError {
                                                            guard self.activeImageRequestID == requestID else { return }
                                                            self.didSavePlate = false
                                                            switch apiError {
                                                            case .invalidURL:
                                                                self.alertItem = AlertItem(title: "Errore", message: "URL API non valido.")
                                                            case .requestFailed:
                                                                self.alertItem = AlertItem(title: "Errore", message: "Richiesta di rete fallita.")
                                                            case .invalidResponse:
                                                                self.alertItem = AlertItem(title: "Errore", message: "Risposta non valida dal server.")
                                                            case .serverError(_, let message):
                                                                self.alertItem = AlertItem(title: "Errore Server", message: message)
                                                            case .plateNotFound:
                                                                self.alertItem = AlertItem(title: "Errore", message: "Targa non trovata.")
                                                            case .alreadyInGarage:
                                                                self.alertItem = AlertItem(title: "Errore", message: "Veicolo già presente nel tuo garage.")
                                                            }
                                                            self.isLoading = false
                                                        } catch {
                                                            self.didSavePlate = false
                                                            self.alertItem = AlertItem(title: "Errore", message: error.localizedDescription)
                                                            self.isLoading = false
                                                        }
                                                    }
                                                case .failure(let err):
                                                    Task { @MainActor in
                                                        guard self.activeImageRequestID == requestID else { return }
                                                        print("Errore nel recupero immagine originale -45: \(err.localizedDescription)")
                                                        self.didSavePlate = false
                                                        self.alertItem = AlertItem(title: "Errore immagine", message: err.localizedDescription)
                                                        self.isLoading = false
                                                    }
                                                }
                                            }
                                        }
                                    case .failure(let err):
                                        Task { @MainActor in
                                            guard self.activeImageRequestID == requestID else { return }
                                            print("Errore nel recupero immagine colorata +45: \(err.localizedDescription)")
                                            self.didSavePlate = false
                                            self.alertItem = AlertItem(title: "Errore immagine", message: err.localizedDescription)
                                            self.isLoading = false
                                        }
                                    }
                                }
                            }
                        case .failure(let err):
                            Task { @MainActor in
                                guard self.activeImageRequestID == requestID else { return }
                                print("Errore nel recupero immagine originale: \(err.localizedDescription)")
                                self.didSavePlate = false
                                self.alertItem = AlertItem(title: "Errore immagine", message: err.localizedDescription)
                                self.isLoading = false
                            }
                        }
                    }
                }
            case .failure(let err):
                Task { @MainActor in
                    guard self.activeImageRequestID == requestID else { return }
                    print("Errore nel recupero immagine colorata: \(err.localizedDescription)")
                    self.didSavePlate = false
                    self.alertItem = AlertItem(title: "Errore immagine", message: err.localizedDescription)
                    self.isLoading = false
                }
            }
        }
    }

    func savePlate(plateData originalPlateData: PlateData, color: String, angle: Int) async {
        let plateData = enrichPlateDataWithBollo(originalPlateData)
        isLoading = true
        activeImageRequestID = UUID()
        let requestID = activeImageRequestID

        VehicleImageService.clearCache()
        Task {
            VehicleImageService.fetchVehicleImage(
                make: plateData.make ?? "",
                modelFamily: plateData.model ?? "",
                year: plateData.year ?? "",
                paintId: color,
                angle: angle,
                plate: plateData.plate
            ) { [weak self] result in
                guard let self = self, self.activeImageRequestID == requestID else { return }
                switch result {
                case .success(let imgColored):
                    Task { @MainActor in
                        guard self.activeImageRequestID == requestID else { return }
                        let safeImageColored = self.ensureRenderable(imgColored)
                        self.vehicleImageColored = safeImageColored
                        VehicleImageService.fetchVehicleImage(
                            make: plateData.make ?? "",
                            modelFamily: plateData.model ?? "",
                            year: plateData.year ?? "",
                            paintId: "",
                            angle: angle,
                            plate: plateData.plate
                        ) { [weak self] result in
                            guard let self = self, self.activeImageRequestID == requestID else { return }
                            switch result {
                            case .success(let imgOriginal):
                                Task { @MainActor in
                                    guard self.activeImageRequestID == requestID else { return }
                                    let safeImageOriginal = self.ensureRenderable(imgOriginal)
                                    self.vehicleImageOriginal = safeImageOriginal
                                    VehicleImageService.fetchVehicleImage(
                                        make: plateData.make ?? "",
                                        modelFamily: plateData.model ?? "",
                                        year: plateData.year ?? "",
                                        paintId: color,
                                        angle: 12,
                                        plate: plateData.plate
                                    ) { [weak self] safeImageColored12 in
                                        guard let self = self, self.activeImageRequestID == requestID else { return }
                                        switch safeImageColored12 {
                                        case .success(let imageColored12Result):
                                            Task { @MainActor in
                                                guard self.activeImageRequestID == requestID else { return }
                                                let imageColored12 = self.ensureRenderable(imageColored12Result)
                                                VehicleImageService.fetchVehicleImage(
                                                    make: plateData.make ?? "",
                                                    modelFamily: plateData.model ?? "",
                                                    year: plateData.year ?? "",
                                                    paintId: "",
                                                    angle: 12,
                                                    plate: plateData.plate
                                                ) { [weak self] imageNoColor12 in
                                                    guard let self = self, self.activeImageRequestID == requestID else { return }
                                                    switch imageNoColor12 {
                                                    case .success(let noColorImage12):
                                                        Task { @MainActor in
                                                            guard self.activeImageRequestID == requestID else { return }
                                                            let ImageNeutral12 = self.ensureRenderable(noColorImage12)
                                                            do {
                                                                try await self.plateAPIService.savePlate(
                                                                    plateData: plateData,
                                                                    color: color,
                                                                    userId: AuthService.currentUserId ?? "",
                                                                    images: [safeImageColored, safeImageOriginal, imageColored12, ImageNeutral12],
                                                                    imagesColor: [color, "", color , ""]
                                                                )
                                                                self.vehicleImage = safeImageColored
                                                                self.didSavePlate = true
                                                            } catch let apiError as PlateAPIError {
                                                                guard self.activeImageRequestID == requestID else { return }
                                                                self.didSavePlate = false
                                                                switch apiError {
                                                                case .invalidURL:
                                                                    self.alertItem = AlertItem(title: "Error", message: "The API URL is invalid.")
                                                                case .requestFailed:
                                                                    self.alertItem = AlertItem(title: "Error", message: "The network request failed.")
                                                                case .invalidResponse:
                                                                    self.alertItem = AlertItem(title: "Error", message: "Received an invalid response from the server.")
                                                                case .serverError(_, let message):
                                                                    self.alertItem = AlertItem(title: "Server Error", message: message)
                                                                case .plateNotFound:
                                                                    self.alertItem = AlertItem(title: "Error", message: "Targa non trovata.")
                                                                case .alreadyInGarage:
                                                                    self.alertItem = AlertItem(title: "Error", message: "Veicolo già presente nel tuo garage.")
                                                                }
                                                            } catch {
                                                                self.didSavePlate = false
                                                                self.alertItem = AlertItem(title: "Error", message: error.localizedDescription)
                                                            }
                                                            guard self.activeImageRequestID == requestID else { return }
                                                            self.isLoading = false
                                                        }
                                                    case .failure(let err):
                                                        Task { @MainActor in
                                                            guard self.activeImageRequestID == requestID else { return }
                                                            print("Errore nel recupero immagine -45: \(err.localizedDescription)")
                                                            self.didSavePlate = false
                                                            self.alertItem = AlertItem(title: "Errore immagine", message: err.localizedDescription)
                                                            self.isLoading = false
                                                        }
                                                    }
                                                }
                                            }
                                        case .failure(let err):
                                            Task { @MainActor in
                                                guard self.activeImageRequestID == requestID else { return }
                                                print("Errore nel recupero immagine +45: \(err.localizedDescription)")
                                                self.didSavePlate = false
                                                self.alertItem = AlertItem(title: "Errore immagine", message: err.localizedDescription)
                                                self.isLoading = false
                                            }
                                        }
                                    }
                                }
                            case .failure(let err):
                                Task { @MainActor in
                                    guard self.activeImageRequestID == requestID else { return }
                                    print("Errore nel recupero immagine originale: \(err.localizedDescription)")
                                    self.vehicleImageOriginal = nil
                                    self.didSavePlate = false
                                    self.alertItem = AlertItem(title: "Errore immagine", message: err.localizedDescription)
                                    self.isLoading = false
                                }
                            }
                        }
                    }
                case .failure(let err):
                    Task { @MainActor in
                        print("Errore nel recupero immagine: \(err.localizedDescription)")
                        self.vehicleImageColored = nil
                        self.didSavePlate = false
                        self.alertItem = AlertItem(title: "Errore immagine", message: err.localizedDescription)
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    
    private func enrichPlateDataWithBollo(_ plateData: PlateData) -> PlateData {
        if plateData.bollo != nil { return plateData }
        
        guard let computed = BolloCalculator.calculateBollo(from: plateData) else {
            return plateData
        }
        
        var enriched = plateData
        enriched.bollo = computed
        return enriched
    }
}
