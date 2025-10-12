//
//  TireAnalysisSelectionView.swift
//  TyreVibes
//
//  Created by Matteo La Manna on 06/10/25.
//

import SwiftUI

struct TireAnalysisSelectionView: View {
    @StateObject private var garageViewModel = GarageViewModel()
    @StateObject private var tyreViewModel = TyreViewModel()
    @State private var selectedVehicle: VehicleResponse?
    @State private var selectedTyre: TyreRegistered?
    @State private var navigateToAnalysis = false
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationStack {
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
                                .padding(.top, 4)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(garageViewModel.vehicles, id: \.vehicle.id) { vehicle in
                                        VehicleCard(
                                            vehicle: vehicle,
                                            isSelected: selectedVehicle?.vehicle.id == vehicle.vehicle.id
                                        ) {
                                            selectVehicle(vehicle)
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

                                if tyreViewModel.isLoading {
                                    HStack {
                                        ProgressView()
                                            .tint(.white)
                                        Text(LocalizedStringKey("Loading registered tires..."))
                                            .font(.customFont(size: 14, weight: .medium))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    .padding(.horizontal, 24)
                                } else if let error = tyreViewModel.errorMessage {
                                    Text(error)
                                        .font(.customFont(size: 13, weight: .medium))
                                        .foregroundColor(.red.opacity(0.8))
                                        .padding(.horizontal, 24)
                                } else if tyreViewModel.registeredTyres.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(LocalizedStringKey("No registered tires found for this vehicle."))
                                            .font(.customFont(size: 14, weight: .medium))
                                            .foregroundColor(.white.opacity(0.7))
                                        Text(LocalizedStringKey("You can add a set from the vehicle details screen."))
                                            .font(.customFont(size: 13, weight: .regular))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    .padding(.horizontal, 24)
                                } else {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 18) {
                                            ForEach(tyreViewModel.registeredTyres) { tyre in
                                                RegisteredTyreCard(
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
                if let vehicle = selectedVehicle, let tyre = selectedTyre {
                    TireAnalysisView(vehicle: vehicle, tyre: tyre)
                } else {
                    EmptyView()
                }
            }
        }
        .task {
            await garageViewModel.fetchCars()
            if selectedVehicle == nil, let firstVehicle = garageViewModel.vehicles.first {
                selectVehicle(firstVehicle, animated: false)
            }
        }
        .onChange(of: garageViewModel.vehicles) { _, newVehicles in
            if selectedVehicle == nil, let firstVehicle = newVehicles.first {
                selectVehicle(firstVehicle, animated: false)
            }
        }
    }

    private func selectVehicle(_ vehicle: VehicleResponse, animated: Bool = true) {
        let selection = {
            selectedVehicle = vehicle
            selectedTyre = nil
            tyreViewModel.registeredTyres = []
            tyreViewModel.errorMessage = nil
            tyreViewModel.fetchTyres(vehicleId: vehicle.vehicle.id, forceRefresh: true)
        }

        if animated {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selection()
            }
        } else {
            selection()
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
struct RegisteredTyreCard: View {
    let tyre: TyreRegistered
    let isSelected: Bool
    let action: () -> Void

    private var displaySize: String {
        tyre.size.isEmpty ? "N/A" : tyre.size
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.customFieldColor)
                        .frame(width: 140, height: 140)

                    VStack(spacing: 10) {
                        Image(systemName: "circle.grid.3x3.fill")
                            .font(.system(size: 40, weight: .regular))
                            .foregroundColor(.white.opacity(0.75))

                        Text(displaySize)
                            .font(.customFont(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .frame(maxWidth: 120)
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

                VStack(spacing: 4) {
                    Text(tyre.brand)
                        .font(.customFont(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(tyre.model)
                        .font(.customFont(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)

                    if !tyre.season.isEmpty {
                        Text(tyre.season.uppercased())
                            .font(.customFont(size: 11, weight: .bold))
                            .foregroundColor(.black.opacity(0.8))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(seasonColor(for: tyre.season))
                            )
                    }
                }
                .frame(width: 140)
            }
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    private func seasonColor(for season: String) -> Color {
        let lower = season.lowercased()
        if lower.contains("winter") || lower.contains("invern") { return Color.blue.opacity(0.6) }
        if lower.contains("summer") || lower.contains("estiv") { return Color.orange.opacity(0.7) }
        if lower.contains("all") || lower.contains("4") { return Color.green.opacity(0.6) }
        return Color.white.opacity(0.7)
    }
}

// MARK: - Preview
struct TireAnalysisSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        TireAnalysisSelectionView()
    }
}
