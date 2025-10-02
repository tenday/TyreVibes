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

// Helper function to extract clean engine info (e.g., "1.5 ETSI", "2.0 TDI")
private func extractCleanEngine(from engine: String?) -> String {
    guard let engine = engine else { return "" }

    let trimmed = engine.trimmingCharacters(in: .whitespacesAndNewlines)

    // Extract displacement and engine type (e.g., "1.5 ETSI", "2.0 TDI")
    // Pattern: number (with optional decimal) followed by optional space and letters
    if let range = trimmed.range(of: #"\d+\.?\d*\s*[A-Za-z]+"#, options: .regularExpression) {
        return String(trimmed[range])
    }

    // If no match, try to extract just the displacement
    if let range = trimmed.range(of: #"\d+\.?\d*"#, options: .regularExpression) {
        return String(trimmed[range])
    }

    return trimmed
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


    private let sheetSpacing: CGFloat = 20
    
    @StateObject private var viewModel = GarageViewModel()
    
    var filteredCars: [VehicleResponse] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return viewModel.vehicles }
        return Array(viewModel.vehicles).filter { vehicle in
            let haystacks: [String] = [
                vehicle.plate?.plateNumber,
                vehicle.vehicle.make,
                vehicle.vehicle.model,
                vehicle.vehicle.modelDetail,
                vehicle.plate?.registrationDate,
                vehicle.vehicle.gearbox,
                vehicle.vehicle.version,
                vehicle.vehicle.fuelType,
                vehicle.vehicle.color,
            ].compactMap { $0 }
            return haystacks.contains { $0.localizedCaseInsensitiveContains(q) }
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
                                Task { @MainActor in
                                    do {
                                        try await AuthService().logout()
                                        
                                        // Clear Keychain and UserDefaults
                                        KeychainHelper.delete()
                                        UserDefaults.standard.set(false, forKey: "rememberMe")
                                        UserDefaults.standard.set(false, forKey: "useFaceID")
                                        UserDefaults.standard.removeObject(forKey: "cachedVehicles")
                                        
                                        // Clear any cached data in the view model
                                        viewModel.vehicles.removeAll()
                                        
                                        // Reset login view model state
                                        viewModelLogin.showHomeScreen = false
                                        viewModelLogin.email = ""
                                        viewModelLogin.password = ""
                                        viewModelLogin.rememberMe = false
                                        
                                        // Finally logout
                                        isLoggedIn = false
                                    } catch {
                                        print("Errore durante il logout: \(error.localizedDescription)")
                                    }
                                }
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
                        TextField("Search...",  text: $searchText)
                            .frame(maxHeight: .infinity)
                            .font(.customFont(size: 16, weight: .semibold))
                            .disableAutocorrection(true)
                            .foregroundColor(.white.opacity(0.6))
                            .offset(x: 16)
                            .autocapitalization(.none)
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white)
                                    .frame(height: 20)
                                    .padding(10)
                            }
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
                                Text("O")
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
                            ForEach(filteredCars, id: \.vehicle.id) { car in
                                SwipeableCarRow(
                                    vehicle: car,
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
                                showScanPlate = false
                            }
                        )
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

    func shareVehicle(_ vehicle: VehicleResponse) {
        // Prepara i dati da condividere
        let vehicleInfo = """
        🚗 My Vehicle - TyreVibes

        📋 Details:
        • Make: \(vehicle.vehicle.make ?? "N/A")
        • Model: \(vehicle.vehicle.model ?? "N/A")
        • Year: \(vehicle.plate?.year.map { "\($0)" } ?? "N/A")
        • License Plate: \(vehicle.plate?.plateNumber ?? "N/A")
        • Engine: \(vehicle.vehicle.engine ?? "N/A")
        • Fuel Type: \(vehicle.vehicle.fuelType ?? "N/A")
        • Color: \(vehicle.vehicle.color ?? "N/A")

        📱 Shared from TyreVibes App
        """

        // Crea gli elementi da condividere
        var itemsToShare: [Any] = [vehicleInfo]

        // Aggiungi l'immagine se disponibile
        if let base64String = vehicle.image?.imageBase64,
           let data = Data(base64Encoded: base64String),
           let image = UIImage(data: data) {
            let trimmedImage = image.trimmedTransparentPixels(threshold: 5)
            itemsToShare.append(trimmedImage)
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
        let onShowDetails: () -> Void
        let onShare: () -> Void
        
        
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
                    }
                    
                    VStack(alignment: .leading, spacing: h * 0.05) {
                        HStack {
                            VStack() {
                                HStack(spacing: 12) {
                                    Text(v.vehicle.model ?? "")
                                        .foregroundColor(.black)
                                        .font(.customFont(size: 16, weight: .semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    
                                    Text(v.plate?.plateNumber ?? "")
                                        .font(.customFont(size: 12, weight: .semibold))
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 6) {
                                Button(action: {
                                    onShare()
                                }) {
                                    Image("shareIcon")
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    onShowDetails()
                                }) {
                                    Image("detailsIcon")
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, w * 0.04)
                        .padding(.top, w * -0.07 )
                        
                        GeometryReader { imageGeo in
                            HStack(alignment: .center, spacing: 0) {
                                // Image container with fixed width
                                if let rawBase64 = v.image?.imageBase64,
                                   let data = Data(base64Encoded: rawBase64),
                                   let rawImage = UIImage(data: data) {

                                    let trimmed = rawImage.trimmedTransparentPixels(threshold: 5)

                                    Image(uiImage: trimmed)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: w * 0.57, height: h * 0.55)
                                        .clipped()
                                        .fixedSize(horizontal: true, vertical: true)
                                }

                                Spacer().frame(width: w * 0.04)

                                // Technical Specs section with fixed position
                                VStack(alignment: .leading, spacing: 12) {

                                    Text(L10n.technicalSpecs.localized)
                                        .font(.customFont(size: 12, weight: .semibold))
                                        .foregroundColor(Color.black)
                                        .fixedSize()

                                    VStack(alignment: .leading, spacing: 8) {
                                        SpecRow(label: "Make:", value: v.vehicle.make ?? "")
                                        SpecRow(label: "Model:", value: extractCleanModel(from: v.vehicle.model))
                                        SpecRow(label: "Year:", value: v.plate?.year.map { String($0) } ?? "")
                                        SpecRow(label: "Engine:", value: extractCleanEngine(from: v.vehicle.engine))
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.trailing, w * 0.04)
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
        let onShowDetails: () -> Void
        let onShare: () -> Void
        let onDelete: () -> Void
        
        @State private var offsetX: CGFloat = 0
        @State private var isDragging = false
        @State private var offsetStart: CGFloat = 0
        @State private var shouldHandleGesture = false
        
        private let revealWidth: CGFloat = 180.0
        private let deleteTrigger: CGFloat = 180.0
        
        var body: some View {
            CarCardView(v: vehicle, onShowDetails: onShowDetails, onShare: onShare)
                .offset(x: offsetX)
                .contentShape(Rectangle())
                .id(vehicle.vehicle.id) // Force view identity based on vehicle ID
                .onAppear {
                    // Reset offset when view appears to ensure original position
                    offsetX = 0
                }
                .gesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .onChanged { value in
                            // Determina se il gesture è principalmente orizzontale
                            let isHorizontal = abs(value.translation.width) > abs(value.translation.height) * 2
                            
                            if !isDragging {
                                // Prima volta che il gesture viene rilevato
                                shouldHandleGesture = isHorizontal
                                if shouldHandleGesture {
                                    isDragging = true
                                    offsetStart = offsetX
                                }
                            }
                            
                            // Gestisci solo se è stato determinato come orizzontale
                            if shouldHandleGesture && isDragging {
                                let proposed = offsetStart + value.translation.width
                                offsetX = min(0, max(-revealWidth, proposed))
                            }
                        }
                        .onEnded { value in
                            guard shouldHandleGesture && isDragging else {
                                // Reset per permettere scroll verticale
                                isDragging = false
                                shouldHandleGesture = false
                                return
                            }
                            
                            let dx = value.translation.width
                            let opened = -min(0, max(-revealWidth, offsetStart + dx))
                            
                            if opened >= deleteTrigger {
                                withAnimation(.spring()) {
                                    onDelete()
                                }
                            } else if opened > revealWidth * 0.6 {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                    offsetX = -revealWidth
                                }
                            } else {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                    offsetX = 0
                                }
                            }
                            
                            isDragging = false
                            shouldHandleGesture = false
                        }
                )
                .onTapGesture {
                    // Chiudi se aperta
                    if offsetX != 0 {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            offsetX = 0
                        }
                    }
                }
        }
    }
    
    struct SpecRow: View {
        let label: String
        let value: String
        
        var body: some View {
            HStack(spacing: 4) {
                Text(label)
                    .font(.customFont(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
                
                Text(value)
                    .font(.customFont(size: 12, weight: .semibold))
                    .foregroundColor(.black)
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

