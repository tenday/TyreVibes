import SwiftUI
import UIKit

// Helper function to extract clean model name
private func extractCleanModel(from model: String?) -> String {
    guard let model = model else { return "" }

    let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)

    // If the model is only digits (like "500"), return it as is
    if trimmed.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil {
        return trimmed
    }

    // Otherwise, extract only the first word/segment before any digit
    let components = trimmed.components(separatedBy: CharacterSet.decimalDigits)
    let cleanModel = components.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmed

    return cleanModel.isEmpty ? trimmed : cleanModel
}

private func normalizedGarageSearchValue(_ value: String) -> String {
    value
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
}

private func condensedGarageSearchValue(_ value: String) -> String {
    normalizedGarageSearchValue(value)
        .replacingOccurrences(of: " ", with: "")
}

private func trimmingLeadingGarageSearchWhitespace(_ value: String) -> String {
    let trimmed = value.drop(while: { $0.isWhitespace || $0.isNewline })
    return String(trimmed)
}

struct GarageScreen: View {
    @StateObject private var viewModelLogin = LoginViewModel()
    @StateObject private var paywallManager = PaywallManager.shared
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @State private var searchText = ""
    @State private var isPresentingSheet = false
    @State private var showScanPlate = false
    @State private var showEnterPlate = false
    @State private var showPremiumScreen = false
    @State private var showDeveloperSettings = false
    @State private var tapCount = 0
    @State private var showProfileScreen: Bool = false
    @State private var showNotificationScreen: Bool = false


    private let sheetSpacing: CGFloat = 20
    
    @StateObject private var viewModel = GarageViewModel()
    
    var filteredCars: [VehicleResponse] {
        let normalizedQuery = normalizedGarageSearchValue(searchText)
        let condensedQuery = condensedGarageSearchValue(searchText)
        guard !normalizedQuery.isEmpty else { return viewModel.vehicles }

        return Array(viewModel.vehicles).filter { vehicle in
            let haystacks: [String] = [
                vehicle.plate?.plateNumber,
                vehicle.vehicle.make,
                vehicle.vehicle.model,
                vehicle.vehicle.smartModelDescription,
                vehicle.vehicle.modelDetail,
                vehicle.plate?.registrationDate,
                vehicle.vehicle.gearbox,
                vehicle.vehicle.version,
                vehicle.vehicle.fuelType,
                vehicle.vehicle.color,
            ].compactMap { $0 }

            return haystacks.contains { candidate in
                let normalizedCandidate = normalizedGarageSearchValue(candidate)
                let condensedCandidate = condensedGarageSearchValue(candidate)

                return normalizedCandidate.contains(normalizedQuery)
                    || condensedCandidate.contains(condensedQuery)
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color.customBackgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.garage.localized)
                            .font(.customFont(size: 36, weight: .semibold))
                            .foregroundColor(.white)
                            .onTapGesture(count: 5) {
                                // Tap 5 volte su "Garage" per aprire developer settings
                                showDeveloperSettings = true
                            }

                        // Mostra badge premium o limite
                        if paywallManager.isPremium {
                            PremiumBadge(size: .small)
                        } else {
                            let vehicleCount = viewModel.vehicles.count
                            if vehicleCount >= PaywallManager.FreeLimits.maxVehicles {
                                LimitReachedBadge(
                                    current: vehicleCount,
                                    max: PaywallManager.FreeLimits.maxVehicles
                                )
                            }
                        }
                    }

                    Spacer()
                    
                    HStack(spacing: 12) {
                        HStack(alignment: .center) {
                            Button(action: {
                                showNotificationScreen = true
                            }) {
                                Image(systemName: "bell")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(
                                        ZStack {
                                            Circle()
                                                .fill(Color.customBackgroundColor)
                                            Circle()
                                                .stroke(Color.white.opacity(0.22), lineWidth: 1.5)
                                                .blur(radius: 1)
                                                .offset(x: 0.3, y: 1)
                                                .mask(
                                                    Circle().fill(LinearGradient(
                                                        gradient: Gradient(colors: [.black, .black]),
                                                        startPoint: .top,
                                                        endPoint: .bottom)
                                                    )
                                                )
                                            VisualEffectBlur(blurStyle:.systemUltraThinMaterial)
                                                .clipShape(Circle())
                                                .padding(12)
                                                .blur(radius: 40)
                                                .opacity(0.8)
                                        }
                                    )
                            }
                            .accessibilityLabel("Notifiche")
                            .accessibilityHint("Apri il centro notifiche")
                        }
                        .frame(width: 48, height: 48)
                        
                        HStack(alignment: .center) {
                            Button(action: {
                                showProfileScreen = true
                            }) {
                                Image("UsernameIcon")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(
                                        ZStack {
                                            Circle()
                                                .fill(Color.customBackgroundColor)

                                            Circle()
                                                .stroke(Color.white.opacity(0.22), lineWidth: 1.5)
                                                .blur(radius: 1)
                                                .offset(x: 0.3, y: 1)
                                                .mask(
                                                    Circle().fill(LinearGradient(
                                                        gradient: Gradient(colors: [.black, .black]),
                                                        startPoint: .top,
                                                        endPoint: .bottom)
                                                    )
                                                )

                                            VisualEffectBlur(blurStyle:.systemUltraThinMaterial)
                                                .clipShape(Circle())
                                                .padding(12)
                                                .blur(radius: 40)
                                                .opacity(0.8)
                                        }
                                    )


                            }
                            .accessibilityLabel("Profilo")
                            .accessibilityHint("Apri il tuo profilo utente")
                        }
                        .frame(width: 48, height: 48)
                        
                        
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                
                HStack(spacing: 10) {
                    
                    HStack (spacing: 12 ) {
                        Image("searchIcon")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(.white)
                            .frame(height: 20)
                            .offset(x: 16)
                            .accessibilityHidden(true)
                        TextField("Search...",  text: $searchText)
                            .frame(maxHeight: .infinity)
                            .font(.customFont(size: 16, weight: .semibold))
                            .disableAutocorrection(true)
                            .foregroundColor(.white.opacity(0.6))
                            .offset(x: 16)
                            .autocapitalization(.none)
                            .onChange(of: searchText) { _, newValue in
                                let sanitized = trimmingLeadingGarageSearchWhitespace(newValue)
                                if sanitized != newValue {
                                    searchText = sanitized
                                }
                            }
                            .accessibilityLabel("Cerca veicoli")
                            .accessibilityHint("Inserisci marca, modello o targa per cercare")

                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white)
                                    .frame(height: 20)
                                    .padding(10)
                            }
                            .accessibilityLabel("Cancella ricerca")
                            .accessibilityHint("Rimuovi il testo di ricerca")
                        }

                    }
                    
                    .background(Color.customFieldColor)
                    .cornerRadius(35)
                    .frame(height: 48)
                    
                    
                    HStack {
                        Button(action: {
                            // Verifica se l'utente può aggiungere un altro veicolo
                            let vehicleCount = viewModel.vehicles.count
                            if paywallManager.canAddVehicle(currentCount: vehicleCount) {
                                isPresentingSheet = true
                            } else {
                                paywallManager.showPaywall(for: .unlimitedVehicles)
                            }
                        }) {
                            Image("plusIcon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                                .shadow(color: Color.black.opacity(0.22), radius: 2 , x: 0 , y: 4)

                        }
                        .accessibilityLabel("Aggiungi veicolo")
                        .accessibilityHint("Aggiungi un nuovo veicolo al garage")
                    }
                    .frame(width: 80, height: 48)
                    .background(Color.customFieldColor)
                    .cornerRadius(35)
                    
                    
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .sheet(isPresented: $isPresentingSheet) {
                    VStack(spacing: sheetSpacing) {
                        Capsule()
                            .fill(Color(red: 0.85, green: 0.85, blue: 0.85))
                            .frame(width: 88, height: 4)
                        
                        
                        Spacer().frame(height: 15)
                        
                        VStack(spacing: sheetSpacing) {
                            Button(action: {
                                isPresentingSheet = false
                                showScanPlate = true
                            }) {
                                HStack {
                                    Image(systemName: "camera")
                                        .foregroundColor(.cyan)
                                        .font(.system(size: 20))
                                    Spacer().frame(width: 14)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(L10n.scanLicensePlate.localized)
                                            .foregroundColor(.white)
                                            .font(.customFont(size: 16, weight: .semibold))
                                        Text(L10n.autoFillVehicleDetails.localized)
                                            .foregroundColor(.white.opacity(0.8))
                                            .font(.customFont(size: 12, weight: .regular))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(
                                            LinearGradient(
                                                stops: [
                                                    Gradient.Stop(color: Color(red: 0.18, green: 0.72, blue: 1), location: 0.00),
                                                    Gradient.Stop(color: Color(red: 0.62, green: 0.92, blue: 0.85), location: 1.00),
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .frame(width: 24, height: 24)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            LinearGradient(
                                                stops: [
                                                    Gradient.Stop(color: Color(red: 0.18, green: 0.72, blue: 1), location: 0.00),
                                                    Gradient.Stop(color: Color(red: 0.62, green: 0.92, blue: 0.85), location: 1.00),
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 1
                                        )
                                        .frame(height: 94)
                                )
                            }
                            .padding(.bottom, sheetSpacing + 11)
                            
                            HStack {
                                Rectangle()
                                    .fill(Color.white.opacity(0.4))
                                    .frame(height: 1)
                                Text("Or")
                                    .foregroundColor(.white)
                                    .font(.customFont(size: 12, weight: .regular))
                                Rectangle()
                                    .fill(Color.white.opacity(0.4))
                                    .frame(height: 1)
                            }
                            .padding(.bottom, sheetSpacing + 21)
                            
                            
                            Button(action: {
                                isPresentingSheet = false
                                showEnterPlate = true
                                
                            }) {
                                HStack {
                                    Text(L10n.enterLicensePlateManually.localized)
                                        .foregroundColor(.white)
                                        .font(.customFont(size: 16, weight: .semibold))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(
                                            LinearGradient(
                                                stops: [
                                                    Gradient.Stop(color: Color(red: 0.18, green: 0.72, blue: 1), location: 0.00),
                                                    Gradient.Stop(color: Color(red: 0.62, green: 0.92, blue: 0.85), location: 1.00),
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            LinearGradient(
                                                stops: [
                                                    Gradient.Stop(color: Color(red: 0.18, green: 0.72, blue: 1), location: 0.00),
                                                    Gradient.Stop(color: Color(red: 0.62, green: 0.92, blue: 0.85), location: 1.00),
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 1
                                        )
                                        .frame(height: 94)
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        
                        //Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    //.background(Color.customBackgroundColor)
                    .presentationDetents([.fraction(0.45)])
                }
                NavigationStack {
                    List {
                        if viewModel.isLoading {
                            ForEach(0..<2, id: \.self) { _ in
                                CarCardShimmer()
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                
                            }
                            
                        }
                        else if viewModel.vehicles.isEmpty {
                            Text(L10n.noVehiclesFound.localized)
                                .font(.customFont(size: 18, weight: .bold))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 24)
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        else {
                            ForEach(Array(filteredCars.enumerated()), id: \.element.vehicle.id) { index, car in
                                SwipeableCarRow(
                                    vehicle: car,
                                    thumbnail: viewModel.vehicleThumbnails[car.vehicle.id],
                                    appearanceDelay: Double(index) * 0.04,
                                    onShowDetails: {
                                        viewModel.showDetails(for: car)
                                    },
                                    onShare: {
                                        shareVehicle(car)
                                    },
                                    onDelete: {
                                        delete(car)
                                    }
                                )
                                .swipeActions(allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        delete(car)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button {
                                        shareVehicle(car)
                                    } label: {
                                        Label("Share", systemImage: "square.and.arrow.up")
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 18, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        
                        
                    }
                    .listStyle(.plain)
                    .scrollIndicators(.hidden)
                    .scrollContentBackground(.hidden)
                    .padding(.top,16)
                    .frame(maxHeight: .infinity)
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: 60)
                    }
                    .navigationDestination(isPresented: $viewModel.showCarDetails) {
                        if let selectedVehicle = viewModel.selectedVehicle {
                            CarDetailsView(vehicle: selectedVehicle)
                        }
                    }
                    .fullScreenCover(isPresented: $showProfileScreen) {
                        ProfileView(
                            onFullScreenDismiss: {
                                showProfileScreen = false
                            }
                        )
                    }
                    .fullScreenCover(isPresented: $showNotificationScreen) {
                        NotificationScreen()
                    }
                    
                    
                }
                .refreshable {
                    await viewModel.fetchCars()
                }
                
            }
            .fullScreenCover(isPresented: $showScanPlate) {
                ScanPlateView(
                    onFullScreenDismiss: {
                        showScanPlate = false
                        Task { await viewModel.fetchCars() }
                    }
                )
            }
            
            .fullScreenCover(isPresented: $showEnterPlate, onDismiss: {
            }) {
                EnterLicensePlateView(
                    onFullScreenDismiss: {
                        showEnterPlate = false
                        Task { await viewModel.fetchCars() }
                    }
                )
            }
            .fullScreenCover(isPresented: $showPremiumScreen) {
                PremiumSubscriptionScreen()
            }
            .sheet(isPresented: $showDeveloperSettings) {
                DeveloperSettingsScreen()
            }
            .edgesIgnoringSafeArea(.bottom)
            .onAppear {
                Task {
                    await viewModel.fetchCars()
                    paywallManager.updatePremiumStatus()
                }
            }
            .overlay(
                Group {
                    if paywallManager.showPaywall, let feature = paywallManager.paywallFeature {
                        PaywallView(
                            feature: feature,
                            onDismiss: {
                                withAnimation {
                                    paywallManager.showPaywall = false
                                }
                            },
                            onUpgrade: {
                                withAnimation {
                                    paywallManager.showPaywall = false
                                }
                                showPremiumScreen = true
                            }
                        )
                        .transition(.opacity)
                    }
                }
            )
        }
        
      
    }
    
    func delete(_ v: VehicleResponse) {
        viewModel.deleteCar(v.vehicle)
    }

    func deleteVehicles(at offsets: IndexSet) {
        let vehiclesToDelete = offsets.map { filteredCars[$0] }
        for vehicle in vehiclesToDelete {
            viewModel.deleteCar(vehicle.vehicle)
        }
    }

    func shareVehicle(_ vehicle: VehicleResponse) {
        // Prepara i dati da condividere
        let vehicleInfo = """
        🚗 My Vehicle - TyreVibes

        📋 Details:
        • Make: \(vehicle.vehicle.make ?? "N/A")
        • Model: \(vehicle.vehicle.smartModelDescription ?? vehicle.vehicle.model ?? "N/A")
        • Year: \(vehicle.plate?.year.map { "\($0)" } ?? "N/A")
        • License Plate: \(vehicle.plate?.plateNumber ?? "N/A")
        • Engine: \(vehicle.vehicle.smartEngineDescription ?? "N/A")
        • Fuel Type: \(vehicle.vehicle.fuelType ?? "N/A")
        • Color: \(localizedVehicleColorName(vehicle.vehicle.color, fallback: "N/A"))

        📱 Shared from TyreVibes App
        """

        // Crea gli elementi da condividere
        var itemsToShare: [Any] = [vehicleInfo]

        // Aggiungi l'immagine se disponibile (con targa offuscata per privacy)
        if let image = viewModel.vehicleThumbnails[vehicle.vehicle.id] {
            let blurredImage = LicensePlateBlurHelper.blurLicensePlate(in: image)
            itemsToShare.append(blurredImage)
        } else if let base64String = vehicle.image?.imageBase64,
           let data = Data(base64Encoded: base64String),
           let image = UIImage(data: data) {
            let trimmedImage = image.trimmedTransparentPixels(threshold: 5)
            // Offusca la targa prima di condividere l'immagine
            let blurredImage = LicensePlateBlurHelper.blurLicensePlate(in: trimmedImage)
            itemsToShare.append(blurredImage)
        }

        // Presenta il sheet di condivisione
        let activityViewController = UIActivityViewController(
            activityItems: itemsToShare,
            applicationActivities: nil
        )

        // Configura per iPad
        if let popover = activityViewController.popoverPresentationController {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                popover.sourceView = window
            }
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        // Escludi alcune attività non necessarie
        activityViewController.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .openInIBooks
        ]

        // Presenta il controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
    }

    struct CarCardView: View {
        let v: VehicleResponse
        let thumbnail: UIImage?
        let onShowDetails: () -> Void
        let onShare: () -> Void
        
        private var engineDisplay: String {
            v.vehicle.smartEngineDescription ?? ""
        }
        
        
        var body: some View {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack {
                    // Card background fills the available size responsively
                    ZStack(alignment: .leading) {
                        Image("CardModel")
                            .resizable()
                            .scaledToFill()
                            .frame(width: w, height: h)
                            .clipped()
                            .shadow(color: Color(red: 0.36, green: 0.92, blue: 1), radius: 0, x: 10, y: 0)
                            .shadow(color: .black.opacity(0.25), radius: 2, x: 2, y: 0)
                            .accessibilityHidden(true)
                    }
                    
                    VStack(alignment: .leading, spacing: h * 0.05) {
                        HStack {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: 12) {
                                    Text(v.vehicle.smartModelDescription ?? v.vehicle.model ?? "")
                                        .foregroundColor(.black)
                                        .font(.customFont(size: 16, weight: .semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .truncationMode(.tail)
                                    
                                    Text(v.plate?.plateNumber ?? "")
                                        .font(.customFont(size: 12, weight: .semibold))
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .truncationMode(.tail)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .clipped()
                            
                            HStack(spacing: 6) {
                                Button(action: {
                                    onShare()
                                }) {
                                    Image("shareIcon")
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Condividi veicolo")
                                .accessibilityHint("Condividi le informazioni del veicolo")

                                Button(action: {
                                    onShowDetails()
                                }) {
                                    Image("detailsIcon")
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Dettagli veicolo")
                                .accessibilityHint("Visualizza i dettagli completi del veicolo")
                            }
                        }
                        .padding(.horizontal, w * 0.04)
                        .padding(.top, w * -0.07 )
                        
                        GeometryReader { imageGeo in
                            HStack(alignment: .center, spacing: 0) {
                                // Image container with fixed width
                                if let thumbnail {
                                    Image(uiImage: thumbnail)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: w * 0.50, height: h * 0.55)
                                        .clipped()
                                        .fixedSize(horizontal: true, vertical: true)
                                } else if let rawBase64 = v.image?.imageBase64,
                                   let data = Data(base64Encoded: rawBase64),
                                   let rawImage = UIImage(data: data) {

                                    let trimmed = rawImage.trimmedTransparentPixels(threshold: 5)

                                    Image(uiImage: trimmed)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: w * 0.50, height: h * 0.55)
                                        .clipped()
                                        .fixedSize(horizontal: true, vertical: true)
                                }

                                Spacer().frame(width: w * 0.03)

                                // Technical Specs section with fixed position
                                VStack(alignment: .leading, spacing: 12) {

                                    Text(L10n.technicalSpecs.localized)
                                        .font(.customFont(size: 12, weight: .semibold))
                                        .foregroundColor(Color.black)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.9)
                                        .truncationMode(.tail)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    VStack(alignment: .leading, spacing: 7) {
                                        SpecRow(label: "\(String(localized: "Make")):", value: v.vehicle.make ?? "")
                                        SpecRow(label: "\(String(localized: "Model")):", value: v.vehicle.smartModelDescription ?? v.vehicle.model ?? "")
                                        SpecRow(label: "\(String(localized: "Year")):", value: v.plate?.year.map { String($0) } ?? "")
                                        SpecRow(label: "\(String(localized: "Engine")):", value: engineDisplay, isMarquee: true)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .clipped()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.trailing, w * 0.08)
                                .clipped()
                                .layoutPriority(1)
                            }
                        }
                        .frame(height: h * 0.55)
                    }
                    
                }
            }
            .aspectRatio(2.05, contentMode: .fit)
        }
    }
    
    // Custom swipeable row for car card, swipes left but does not reveal delete or trigger deletion
    struct SwipeableCarRow: View {
        let vehicle: VehicleResponse
        let thumbnail: UIImage?
        var appearanceDelay: Double = 0
        let onShowDetails: () -> Void
        let onShare: () -> Void
        let onDelete: () -> Void

        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var offsetX: CGFloat = 0
        @State private var hasAppeared = false
        @State private var isDragging = false
        @State private var offsetStart: CGFloat = 0
        @State private var shouldHandleGesture = false
        @State private var deletionFeedbackTriggered = false

        private let revealWidth: CGFloat = 120.0
        private let deleteTriggerThreshold: CGFloat = 0.6

        private var swipeProgress: CGFloat {
            min(max(-offsetX / revealWidth, 0), 1)
        }

        var body: some View {
            GeometryReader { geo in
                let cardHeight = geo.size.height
                let cardWidth = geo.size.width
                let progress = swipeProgress

                ZStack(alignment: .trailing) {
                    // Background delete area - premium design
                    ZStack(alignment: .trailing) {
                        // Gradient background with dynamic intensity based on swipe
                        let deleteColor = Color(red: 1.0, green: 0.27, blue: 0.23)
                        LinearGradient(
                            gradient: Gradient(colors: [
                                deleteColor.opacity(0.15 + 0.45 * progress),
                                deleteColor.opacity(0.7 + 0.3 * progress)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: cardWidth, height: cardHeight)
                        .cornerRadius(12)
                        .overlay(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    deleteColor.opacity(0.1 + 0.2 * progress),
                                    deleteColor.opacity(0.4 + 0.4 * progress),
                                    deleteColor.opacity(0.1)
                                ]),
                                center: .trailing
                            )
                            .opacity(Double(progress) * 0.4)
                            .blur(radius: 16)
                        )
                        .overlay(
                            Circle()
                                .fill(Color.white.opacity(0.12 + 0.25 * progress))
                                .frame(width: 92 + (progress * 34), height: cardHeight + 12)
                                .offset(x: -40 + (-10 * progress))
                                .blur(radius: 24)
                                .opacity(Double(progress))
                        )

                        // Delete action button
                        Button(action: {
                            performDelete()
                        }) {
                            ZStack {
                                // Glass morphism effect
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.12 + 0.15 * progress))
                                    .frame(width: 88, height: cardHeight - 20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(Color.white.opacity(0.25 + 0.25 * progress), lineWidth: 1)
                                    )
                                    .shadow(color: deleteColor.opacity(0.3 * progress), radius: 10 * progress, x: -6 * progress, y: 12 * progress)

                                VStack(spacing: 8) {
                                    // Animated trash icon
                                    ZStack {
                                        Circle()
                                            .fill(deleteColor.opacity(0.18 + 0.25 * progress))
                                            .frame(width: 46 + (progress * 4), height: 46 + (progress * 4))

                                        Image(systemName: "trash.fill")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(.white)
                                            .scaleEffect(0.95 + 0.25 * progress)
                                            .rotationEffect(.degrees(Double(progress) * -12))
                                    }

                                    Text("Delete")
                                        .font(.customFont(size: 13, weight: .bold))
                                        .foregroundColor(.white.opacity(0.9))
                                        .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 2)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityLabel("Elimina veicolo")
                        .accessibilityHint("Elimina questo veicolo dal garage")
                        .padding(.trailing, 10)
                        .scaleEffect(0.85 + 0.2 * progress)
                        .opacity(progress > 0.05 ? 0.4 + 0.6 * progress : 0)
                        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: progress)
                    }
                    .opacity(progress > 0.02 ? 1 : 0)

                    // Car card with shadow when swiped
                    CarCardView(v: vehicle, thumbnail: thumbnail, onShowDetails: onShowDetails, onShare: onShare)
                        .offset(x: offsetX)
                        .rotation3DEffect(
                            .degrees(Double(progress) * -6),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: .trailing,
                            anchorZ: 0,
                            perspective: 0.5
                        )
                        .scaleEffect(x: 1.0 - (progress * 0.04), y: 1.0)
                        .shadow(
                            color: Color.black.opacity(progress > 0.05 ? 0.25 * Double(progress) : 0),
                            radius: 12 * progress,
                            x: -6 * progress,
                            y: 8 * progress
                        )
                        .contentShape(Rectangle())
                        .id(vehicle.vehicle.id)
                        .onAppear {
                            offsetX = 0
                        }
                }
            }
            .aspectRatio(2.05, contentMode: .fit)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared || reduceMotion ? 0 : 18)
            .onAppear {
                withAnimation(reduceMotion ? nil : AppMotion.smooth.delay(appearanceDelay)) {
                    hasAppeared = true
                }
            }
                .onTapGesture {
                    // Se la card è aperta (swipe), chiudila
                    if offsetX != 0 {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            offsetX = 0
                        }
                    } else {
                        // Altrimenti naviga ai dettagli
                        onShowDetails()
                    }
                }
        }

        private func handleHapticsIfNeeded() {
            let progress = swipeProgress
            if progress >= deleteTriggerThreshold, !deletionFeedbackTriggered {
                let generator = UIImpactFeedbackGenerator(style: .rigid)
                generator.impactOccurred()
                deletionFeedbackTriggered = true
            } else if progress < 0.6 {
                deletionFeedbackTriggered = false
            }
        }

        private func performDelete() {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                onDelete()
            }
            offsetX = 0
            deletionFeedbackTriggered = false
        }
    }
    
    struct SpecRow: View {
        let label: String
        let value: String
        var maxLines: Int? = 1
        var minScaleFactor: CGFloat = 0.85
        var isMarquee: Bool = false

        private let valueFont = Font.customFont(size: 12, weight: .semibold)
        private let valueUIFont = UIFont(name: "Sora-SemiBold", size: 12) ?? .systemFont(ofSize: 12, weight: .semibold)
        
        var body: some View {
            HStack(alignment: .top, spacing: 4) {
                Text(label)
                    .font(.customFont(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .truncationMode(.tail)
                    .frame(width: 62, alignment: .leading)
                
                if isMarquee {
                    MarqueeText(
                        text: value,
                        displayFont: valueFont,
                        measureFont: valueUIFont,
                        color: .black,
                        delay: 0.6,
                        speed: 24,
                        spacing: 24
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipped()
                    .layoutPriority(1)
                } else {
                    Text(value)
                        .font(valueFont)
                        .foregroundColor(.black)
                        .lineLimit(maxLines)
                        .minimumScaleFactor(0.82)
                        .allowsTightening(true)
                        .multilineTextAlignment(.leading)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .clipped()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 15, alignment: .leading)
            .clipped()
        }
    }

    struct MarqueeText: View {
        let text: String
        let displayFont: Font
        let measureFont: UIFont
        let color: Color
        let delay: Double
        let speed: CGFloat
        let spacing: CGFloat

        @State private var textWidth: CGFloat = 0
        @State private var offset: CGFloat = 0

        var body: some View {
            GeometryReader { geo in
                let containerWidth = geo.size.width
                let shouldScroll = textWidth > containerWidth && !text.isEmpty

                ZStack(alignment: .leading) {
                    if shouldScroll {
                        HStack(spacing: spacing) {
                            Text(text)
                                .font(displayFont)
                                .foregroundColor(color)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .fixedSize(horizontal: true, vertical: false)
                            Text(text)
                                .font(displayFont)
                                .foregroundColor(color)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .offset(x: offset)
                        .onAppear { startAnimation(containerWidth: containerWidth) }
                        .onChange(of: containerWidth) { _ in
                            startAnimation(containerWidth: containerWidth)
                        }
                        .onChange(of: text) { _ in
                            measureText()
                            startAnimation(containerWidth: containerWidth)
                        }
                    } else {
                        Text(text)
                            .font(displayFont)
                            .foregroundColor(color)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .fixedSize(horizontal: true, vertical: false)
                            .onAppear { offset = 0 }
                    }
                }
                .clipped()
                .onAppear {
                    measureText()
                    startAnimation(containerWidth: containerWidth)
                }
            }
            .frame(height: measureFont.lineHeight)
        }

        private func measureText() {
            guard !text.isEmpty else {
                textWidth = 0
                return
            }

            let attributes: [NSAttributedString.Key: Any] = [.font: measureFont]
            textWidth = (text as NSString).size(withAttributes: attributes).width.rounded(.up)
        }

        private func startAnimation(containerWidth: CGFloat) {
            guard containerWidth > 0, textWidth > containerWidth else {
                offset = 0
                return
            }

            let travel = textWidth + spacing
            let duration = Double(travel / speed)
            offset = 0

            withAnimation(.linear(duration: duration).delay(delay).repeatForever(autoreverses: false)) {
                offset = -travel
            }
        }
    }
    
    
    
    struct TabBarItem: View {
        let icon: String
        let isSelected: Bool
        
        var body: some View {
            Button(action: {}) {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.orange)
                            .frame(width: 60, height: 40)
                    }
                    
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .white : .gray)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    struct GarageScreen_Previews: PreviewProvider {
        static var previews: some View {
            GarageScreen()
                .preferredColorScheme(.dark)
        }
    }
    
}
