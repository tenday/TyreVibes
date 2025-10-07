//
//  TireAnalysisSelectionView.swift
//  TyreVibes
//
//  Created by Matteo La Manna on 06/10/25.
//

import SwiftUI

struct TireAnalysisSelectionView: View {
    @StateObject private var garageViewModel = GarageViewModel()
    @State private var selectedVehicle: VehicleResponse?
    @State private var selectedTyre: VehicleTyre?
    @State private var navigateToAnalysis = false
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                Color.customBackgroundColor
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Header
                        HStack {
                            Text(LocalizedStringKey("Tire Analysis"))
                                .font(.customFont(size: 28, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                        // Vehicle Selection Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text(LocalizedStringKey("Select Vehicle"))
                                .font(.customFont(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(garageViewModel.vehicles, id: \.vehicle.id) { vehicle in
                                        VehicleCard(
                                            vehicle: vehicle,
                                            isSelected: selectedVehicle?.vehicle.id == vehicle.vehicle.id
                                        ) {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                selectedVehicle = vehicle
                                                selectedTyre = nil // Reset tyre selection when vehicle changes
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }

                        // Tyre Selection Section
                        if let vehicle = selectedVehicle {
                            VStack(alignment: .leading, spacing: 16) {
                                Text(LocalizedStringKey("Select Tire"))
                                    .font(.customFont(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)

                                if let tyres = vehicle.tyres, !tyres.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(tyres, id: \.id) { tyre in
                                                TyreCard(
                                                    tyre: tyre,
                                                    isSelected: selectedTyre?.id == tyre.id
                                                ) {
                                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                        selectedTyre = tyre
                                                    }
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 24)
                                    }
                                } else {
                                    Text(LocalizedStringKey("No data available"))
                                        .font(.customFont(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))
                                        .padding(.horizontal, 24)
                                }
                            }
                        }

                        Spacer()
                            .frame(height: 80)
                    }
                }

                // Start Button (Fixed at bottom)
                VStack {
                    Spacer()

                    Button(action: {
                        if selectedVehicle != nil && selectedTyre != nil {
                            navigateToAnalysis = true
                        }
                    }) {
                        Text(LocalizedStringKey("Start"))
                            .font(.customFont(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(
                                        LinearGradient(
                                            colors: selectedVehicle != nil && selectedTyre != nil
                                                ? [Color(hex: "FF6B6B"), Color(hex: "FF8E53")]
                                                : [Color.gray.opacity(0.5), Color.gray.opacity(0.3)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .shadow(color: (selectedVehicle != nil && selectedTyre != nil
                                ? Color(hex: "FF6B6B") : Color.clear).opacity(0.4),
                                    radius: 20, x: 0, y: 10)
                    }
                    .disabled(selectedVehicle == nil || selectedTyre == nil)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToAnalysis) {
                TireAnalysisView()
            }
        }
        .task {
            await garageViewModel.fetchCars()
        }
    }
}

// MARK: - Vehicle Card Component
struct VehicleCard: View {
    let vehicle: VehicleResponse
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Vehicle Image
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.customFieldColor)
                        .frame(width: 120, height: 120)

                    if let imageBase64 = vehicle.image?.imageBase64,
                       let uiImage = imageBase64.toUIImage() {
                        Image(uiImage: uiImage.trimmedTransparentPixels(threshold: 5))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 110, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Image(systemName: "car.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected
                                ? LinearGradient(
                                    colors: [Color(hex: "FF6B6B"), Color(hex: "FF8E53")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [Color.clear, Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                            lineWidth: isSelected ? 3 : 0
                        )
                )

                // Vehicle Name
                Text("\(vehicle.vehicle.make ?? "") \(vehicle.vehicle.model ?? "")")
                    .font(.customFont(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(width: 120)
            }
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Tyre Card Component
struct TyreCard: View {
    let tyre: VehicleTyre
    let isSelected: Bool
    let action: () -> Void

    private var displaySize: String {
        if let sizeLabel = tyre.sizeLabel {
            return sizeLabel
        }

        // Fallback: costruisci la stringa dalla larghezza, ratio e diametro
        var components: [String] = []
        if let width = tyre.width {
            components.append("\(width)")
        }
        if let ratio = tyre.ratio {
            components.append("\(ratio)")
        }
        if let diameter = tyre.diameter {
            components.append("R\(diameter)")
        }

        return components.isEmpty ? "N/A" : components.joined(separator: "/")
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Tyre Image
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.customFieldColor)
                        .frame(width: 120, height: 120)

                    // Placeholder tire image
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.7))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected
                                ? LinearGradient(
                                    colors: [Color(hex: "FF6B6B"), Color(hex: "FF8E53")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [Color.clear, Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                            lineWidth: isSelected ? 3 : 0
                        )
                )

                // Tyre Name/Size
                Text(displaySize)
                    .font(.customFont(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(width: 120)
            }
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Preview
struct TireAnalysisSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        TireAnalysisSelectionView()
    }
}
