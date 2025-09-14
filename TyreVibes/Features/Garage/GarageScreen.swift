
import SwiftUI
import UIKit



struct GarageScreen: View {
    @State private var searchText = ""
    @State private var isPresentingSheet = false
    @State private var showScanPlate = false
    @State private var showEnterPlate = false

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
                    Text("Garage")
                        .font(.customFont(size: 36, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        HStack(alignment: .center) {
                            Button(action: {}) {
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
                            Button(action: {}) {
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
                            isPresentingSheet = true
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
                                        Text("Scan License Plate")
                                            .foregroundColor(.white)
                                            .font(.customFont(size: 16, weight: .semibold))
                                        Text("Auto fill vehicles details")
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
                                Text("OR")
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
                                    Text("Enter License Plate Manually")
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
                        Text("No veichles found,pls add a new one")
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
                            SwipeableCarRow(vehicle: car) {
                                delete(car)
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
            .edgesIgnoringSafeArea(.bottom)
            .onAppear {
                // fetchCars is async but already launches its own Task internally.
                // If you refactor fetchCars to not spawn a Task, consider using:
                // Task { await viewModel.fetchCars() }
                Task { await viewModel.fetchCars()}
            }
        }
    
    private func delete(_ v: VehicleResponse) {
        viewModel.deleteCar(v.vehicle)
    }
}
   



struct CarCardView: View {
    let v: VehicleResponse
    @State private var showDetails = false

    
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
                            Button(action: {}) {
                                Image("shareIcon")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                showDetails = true
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

                    HStack(alignment: .center, spacing: w * 0.04) {
                        if let rawBase64 = v.image?.imageBase64,
                           let data = Data(base64Encoded: rawBase64),
                           let rawImage = UIImage(data: data) {
                            
                            let trimmed = rawImage.trimmedTransparentPixels(threshold: 5)

                            Image(uiImage: trimmed)
                                .resizable()
                                .scaledToFit()
                                .frame(width: w * 0.57)
                        }

                        // Technical Specs section
                        VStack(alignment: .leading, spacing: 12) {
                            
                            Text("Technical Specs")
                                .font(.customFont(size: 12, weight: .semibold))
                                .foregroundColor(Color.black)

                            VStack(alignment: .leading, spacing: 8) {
                                SpecRow(label: "Make:", value: v.vehicle.make ?? "")
                                SpecRow(
                                    label: "Model",
                                    value: v.vehicle.model?
                                        .components(separatedBy: CharacterSet.decimalDigits)
                                        .first?
                                        .uppercased() ?? ""
                                )
                                SpecRow(label: "Year:", value: v.plate?.year.map { String($0) } ?? "")
                                SpecRow(label: "Engine:", value: v.vehicle.engine ?? "")
                            }
                        }
                        .padding(.trailing, w * 0.04)
                    }
                }

            }
            .navigationDestination(isPresented: $showDetails) {
                CarDetailsView(vehicle: v)
                    .navigationBarBackButtonHidden(true)
                    .background(InteractivePopGestureEnabler())
            }
        }
        .aspectRatio(2.05, contentMode: .fit)
    }
}

// Custom swipeable row for car card, swipes left but does not reveal delete or trigger deletion
struct SwipeableCarRow: View {
    let vehicle: VehicleResponse
    let onDelete: () -> Void

    @State private var offsetX: CGFloat = 0
    @State private var isDragging = false
    @State private var offsetStart: CGFloat = 0

    private let revealWidth: CGFloat = 180.0   // quanto resta aperto dopo lo swipe
    private let deleteTrigger: CGFloat = 180.0 // soglia per eliminazione con full swipe

    var body: some View {
        // Only the card, no background or delete button
        CarCardView(v: vehicle)
            .offset(x: offsetX)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 8, coordinateSpace: .local)
                    .onChanged { value in
                        // Handle only horizontal drag; let verticals go to List
                        let isHorizontal = abs(value.translation.width) > abs(value.translation.height)
                        guard isHorizontal else { return }
                        if !isDragging { isDragging = true; offsetStart = offsetX }
                        let proposed = offsetStart + value.translation.width
                        // constrain between 0 and -revealWidth
                        offsetX = min(0, max(-revealWidth, proposed))
                    }
                    .onEnded { value in
                        let isHorizontal = abs(value.translation.width) > abs(value.translation.height)
                        guard isHorizontal else { isDragging = false; return }
                        let dx = value.translation.width
                        let opened = -min(0, max(-revealWidth, offsetStart + dx))
                        if opened >= deleteTrigger {
                            withAnimation(.spring()) {
                                onDelete()
                            }
                        } else if opened > revealWidth * 0.6 {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { offsetX = -revealWidth }
                        } else {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { offsetX = 0 }
                        }
                        isDragging = false
                    }
            )
            .simultaneousGesture(
                TapGesture().onEnded {
                    // If open, tap closes the card
                    if offsetX != 0 {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { offsetX = 0 }
                    }
                }
            )
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
