//
//  TireAnalysisView.swift
//  TyreVibes
//
//  Created by Matteo La Manna on 04/10/25.
//


import SwiftUI

// MARK: - Main Tire Analysis View
struct TireAnalysisView: View {
    let vehicle: VehicleResponse
    let tyre: TyreRegistered
    @State private var selectedTires: Set<TirePosition> = []
    @State private var selectedTire: TirePosition? = .frontLeft
    @State private var navigateToResult = false
    @State private var vehicleImage: UIImage?
    @State private var isLoadingImage = true
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            Color.customBackgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // Back Button
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                    }
                    .padding(.leading, 24)
                    
                    Spacer()
                }
                .padding(.top, 16)

                
                Spacer()

                // Car with Tire Indicators
                ZStack {
                    VStack {
                        Spacer()

                        if let image = vehicleImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 500, maxHeight: 500)
                                .rotationEffect(.degrees(90))
                        } else {
                            Image(systemName: "car.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.white.opacity(0.3))
                        }

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    
                    // Tire selection buttons
                                      // Front Left
                                      TireButton(position: .frontLeft, isSelected: selectedTires.contains(.frontLeft))
                                          .offset(x: -160, y: -120)
                                          .onTapGesture {
                                              toggleTire(.frontLeft)
                                          }
                                      
                                      // Front Right
                                      TireButton(position: .frontRight, isSelected: selectedTires.contains(.frontRight))
                                          .offset(x: 160, y: -120)
                                          .onTapGesture {
                                              toggleTire(.frontRight)
                                          }
                                      
                                      // Rear Left
                                      TireButton(position: .rearLeft, isSelected: selectedTires.contains(.rearLeft))
                                          .offset(x: -160, y: 120)
                                          .onTapGesture {
                                              toggleTire(.rearLeft)
                                          }
                                      
                                      // Rear Right
                                      TireButton(position: .rearRight, isSelected: selectedTires.contains(.rearRight))
                                          .offset(x: 160, y: 120)
                                          .onTapGesture {
                                              toggleTire(.rearRight)
                                          }
                    

                    if isLoadingImage {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)


                NavigationLink(destination: TreadAnalysisResultView(vehicle: vehicle), isActive: $navigateToResult) {
                    EmptyView()
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await loadVehicleImage()
        }
    }
    
    private func toggleTire(_ position: TirePosition) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if selectedTires.contains(position) {
                    selectedTires.remove(position)
                } else {
                    selectedTires.insert(position)
                }
            }
        }
    
    struct TireButton: View {
        let position: TirePosition
        let isSelected: Bool
        
        var body: some View {
            ZStack {
                // Outer circle (border)
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? Color(red: 0.45, green: 0.35, blue: 0.85) : Color.white, lineWidth: 2)
                    .frame(width: 42, height: 72)
                
                // Inner fill when selected
                if isSelected {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(red: 0.45, green: 0.35, blue: 0.85).opacity(0.2))
                        .frame(width: 56, height: 96)
                }
                
                // Tire tread pattern (3 lines)
                VStack(spacing: 6) {
                    ForEach(0..<3) { _ in
                        Rectangle()
                            .fill(isSelected ? Color(red: 0.45, green: 0.35, blue: 0.85) : Color.white)
                            .frame(width: 30, height: 2)
                            .opacity(0.6)
                    }
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
    }

    private func loadVehicleImage() async {
        defer { isLoadingImage = false }

        guard let make = vehicle.vehicle.make,
              let modelFamily = vehicle.vehicle.model,
              let year = vehicle.vehicle.saleStart,
              let color = vehicle.vehicle.color else {
            return
        }

        // Angle 1 = top-down view from imagin.studio
        VehicleImageService.fetchVehicleImage(
            make: make,
            modelFamily: modelFamily,
            year: year,
            paintId: color,
            angle: 33,
            plate: ""
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let image):
                    self.vehicleImage =  image.trimmedTransparentPixels(threshold: 5)
                case .failure(let error):
                    print("⚠️ Errore nel caricamento dell'immagine: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Car Tire Visualization
struct CarTireVisualization: View {
    @Binding var selectedTire: TirePosition?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Car Image (rotated 90 degrees)
                Image("car_top_view")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 460, height: 216)
                    .rotationEffect(.degrees(90))
                    .position(
                        x: geometry.size.width / 2,
                        y: geometry.size.height / 2
                    )
                
                // Front Left Tire Indicator
                TireIndicators(
                    position: .frontLeft,
                    isSelected: selectedTire == .frontLeft
                )
                .position(x: 91, y: geometry.size.height / 2 - 153)
                .onTapGesture {
                    selectedTire = .frontLeft
                }
                
                // Front Right Tire Indicator
                TireIndicators(
                    position: .frontRight,
                    isSelected: selectedTire == .frontRight
                )
                .position(x: geometry.size.width - 61, y: geometry.size.height / 2 - 153)
                .onTapGesture {
                    selectedTire = .frontRight
                }
                
                // Rear Right Tire Indicator
                TireIndicators(
                    position: .rearRight,
                    isSelected: selectedTire == .rearRight
                )
                .position(x: geometry.size.width - 61, y: geometry.size.height / 2 + 117)
                .onTapGesture {
                    selectedTire = .rearRight
                }
                
                // Rear Left Tire Indicator
                TireIndicators(
                    position: .rearLeft,
                    isSelected: selectedTire == .rearLeft
                )
                .position(x: 91, y: geometry.size.height / 2 + 117)
                .onTapGesture {
                    selectedTire = .rearLeft
                }
            }
        }
    }
}

// MARK: - Tire Indicator Component
struct TireIndicators: View {
    let position: TirePosition
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            // Lines indicator (when not selected)
            if !isSelected {
                TireLines()
                    .frame(width: 42.83, height: 61)
                    .offset(x: 0, y: 4)
            }
            
            // Border box
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white, lineWidth: isSelected ? 2 : 1)
                .frame(width: 42, height: 72)
                .opacity(isSelected ? 1.0 : 0.6)
            
            // Selection indicator (optional glow effect)
            if isSelected {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "5CEBFF"), Color(hex: "2FB8FF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 44, height: 74)
                    .blur(radius: 2)
                    .opacity(0.6)
            }
        }
    }
}

// MARK: - Tire Indicator Badge
struct TireIndicatorBadge: View {
    let position: TirePosition
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(position.icon)
                .font(.customFont(size: 14, weight: .bold))
                .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(isSelected ? Color(hex: "FF6B6B") : Color.white.opacity(0.2))
                )
                .overlay(
                    Circle()
                        .stroke(
                            isSelected ? Color(hex: "FF8E53") : Color.white.opacity(0.3),
                            lineWidth: 2
                        )
                )
                .scaleEffect(isSelected ? 1.1 : 1.0)
        }
    }
}

// MARK: - Tire Lines (Indicator Pattern)
struct TireLines: View {
    var body: some View {
        // Questo componente rappresenta le linee di indicazione
        // che mostrano la posizione dello pneumatico
        VStack(spacing: 3) {
            ForEach(0..<5) { _ in
                Rectangle()
                    .fill(Color.white.opacity(0.4))
                    .frame(height: 2)
            }
        }
        .frame(width: 42)
    }
}

// MARK: - Tire Position Enum
enum TirePosition: String, CaseIterable {
    case frontLeft = "Front Left"
    case frontRight = "Front Right"
    case rearLeft = "Rear Left"
    case rearRight = "Rear Right"
    
    var icon: String {
        switch self {
        case .frontLeft: return "FL"
        case .frontRight: return "FR"
        case .rearLeft: return "RL"
        case .rearRight: return "RR"
        }
    }
    
    var detailTitle: String {
        return rawValue + " Tire"
    }
}

// MARK: - Preview
struct TireAnalysisView_Previews: PreviewProvider {
    static var previews: some View {
        TireAnalysisView(
            vehicle: .previewSample,
            tyre: .previewSample
        )
    }
}

extension TyreRegistered {
    static var previewSample: TyreRegistered {
        TyreRegistered(
            id: 1,
            vehicleId: 1,
            brand: "Pirelli",
            model: "P Zero",
            size: "245/35 R19",
            dot: "3522",
            loadIndex: "96",
            speedRating: "Y",
            season: "Summer"
        )
    }
}

extension VehicleResponse {
    static var previewSample: VehicleResponse {
        VehicleResponse(
            vehicle: Vehicle(
                id: 1,
                modelDetail: "GTI",
                engine: "2.0 TSI",
                make: "Volkswagen",
                model: "Golf",
                version: "8",
                fuelType: "Petrol",
                displacementCC: 1984,
                powerCV: 245,
                powerKW: "180",
                emissionClass: "Euro 6",
                gearbox: "DSG",
                maxSpeed: "250 km/h",
                bodyType: "Hatchback",
                doors: "5",
                seats: "5",
                consumption: "7.4 l/100km",
                traction: "Front",
                saleStart: "2020",
                saleEnd: nil,
                color: "Red",
                vin: "WVWZZZAUZLP000001",
                createdAt: "2024-01-01T12:00:00Z"
            ),
            plate: Plate(
                id: 1,
                plateNumber: "AB123CD",
                registrationDate: "2021-05-10",
                year: 2021,
                month: 5,
                createdAt: "2024-01-01T12:00:00Z"
            ),
            image: nil,
            tyres: nil,
            revisions: nil,
            insurances: nil
        )
    }
}

// MARK: - IMPORTANT NOTE
/*
 Per utilizzare questa view, dovrai:
 
 1. **Aggiungere l'immagine dell'auto**:
    - Scarica l'immagine dal link fornito da Figma
    - Aggiungi l'immagine agli Assets con nome "car_top_view"
    
 2. **Personalizzare le posizioni**:
    - Le coordinate dei TireIndicator potrebbero necessitare
      di aggiustamenti in base all'immagine reale dell'auto
    
 3. **Aggiungere interattività**:
    - Quando un pneumatico viene selezionato, puoi mostrare
      un pannello con i dettagli (pressione, temperatura, usura)
    
 4. **Animazioni**:
    - Aggiungi withAnimation{} nei tap gesture per transizioni fluide
    
 Esempio di utilizzo con dettagli pneumatico:
 
 @State private var showTireDetails = false
 
 .sheet(isPresented: $showTireDetails) {
     TireDetailView(tire: selectedTire)
 }
 
 E nel tap gesture:
 .onTapGesture {
     withAnimation {
         selectedTire = .frontLeft
         showTireDetails = true
     }
 }
*/
