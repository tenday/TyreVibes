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
    private let isLiDARAvailable = LiDARTreadMeasurementService.shared.isLiDARAvailable
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
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                                .layoutPriority(1)

                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                        if !isLiDARAvailable {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(LocalizedStringKey("LiDAR Non Disponibile"))
                                    .font(.customFont(size: 16, weight: .semibold))
                                    .foregroundColor(.white)

                                Text(LocalizedStringKey("Questa funzionalità richiede un dispositivo con sensore LiDAR (iPhone 12 Pro o successivo)"))
                                    .font(.customFont(size: 13, weight: .regular))
                                    .foregroundColor(.white.opacity(0.7))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.customFieldColor)
                            )
                            .padding(.horizontal, 24)
                        }

                        // Vehicle Selection Section
                        VStack(alignment: .leading, spacing: 10) {
                            if !garageViewModel.vehicles.isEmpty {
                                Text(LocalizedStringKey("Select Vehicle"))
                                    .font(.customFont(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.top, 4)
                            }

                            if garageViewModel.isLoading {
                                HStack {
                                    ProgressView()
                                        .tint(.white)
                                    Text(LocalizedStringKey("Loading..."))
                                        .font(.customFont(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                            } else if garageViewModel.vehicles.isEmpty {
                                Text(LocalizedStringKey("No vehicles found, please add a new one"))
                                    .font(.customFont(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 16)
                            } else {
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
                                    .padding(.vertical, 20)
                                }
                            }
                        }

                        // Tyre Selection Section
                        if let vehicle = selectedVehicle {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(LocalizedStringKey("Select Tire"))
                                    .font(.customFont(size: 16, weight: .semibold))
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
                                                let isSelected = selectedTyre?.id == tyre.id
                                                RegisteredTyreCard(
                                                    tyre: tyre,
                                                    isSelected: isSelected
                                                ) {
                                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                        selectedTyre = tyre
                                                    }
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 20)
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
                    Spacer().frame(height: 500)

                    if !garageViewModel.vehicles.isEmpty {
                        Button(action: {
                            if isLiDARAvailable, selectedVehicle != nil && selectedTyre != nil {
                                navigateToAnalysis = true
                            }
                        }) {
                            Text(LocalizedStringKey("Start"))
                                .font(.customFont(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 212, height: 62)
                                .background(Color.customBitterSweet)
                        }
                        .disabled(selectedVehicle == nil || selectedTyre == nil || !isLiDARAvailable)
                        .opacity(selectedVehicle == nil || selectedTyre == nil || !isLiDARAvailable ? 0.5 : 1)
                        .cornerRadius(100)
                        .padding(.horizontal, 24)
                    }
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

    private let cardWidth: CGFloat = 132
    private let cardHeight: CGFloat = 168
    private let imagePanelHeight: CGFloat = 96

    private var vehicleDisplayName: String {
        let make = vehicle.vehicle.make ?? ""
        let modelText = vehicle.vehicle.smartModelDescription ?? vehicle.vehicle.model ?? ""
        let parts = [make, modelText].filter { !$0.isEmpty }
        return parts.joined(separator: " ")
    }

    private var usesCompactLayout: Bool {
        vehicleDisplayName.count > 18
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: usesCompactLayout ? 8 : 10) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.2))
                    .frame(maxWidth: .infinity)
                    .frame(height: imagePanelHeight)
                    .overlay {
                        if let imageBase64 = vehicle.image?.imageBase64,
                           let uiImage = imageBase64.toUIImage() {
                            Image(uiImage: uiImage.trimmedTransparentPixels(threshold: 5))
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                        } else {
                            Image(systemName: "car.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Text(vehicleDisplayName)
                    .font(.customFont(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
            .frame(width: cardWidth, height: cardHeight, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.customFieldColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected
                            ? LinearGradient(
                                colors: [Color(hex: "F36656"), Color(hex: "F36656")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.clear, Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                        lineWidth: isSelected ? 2 : 0
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Tyre Card Component
struct RegisteredTyreCard: View {
    let tyre: TyreRegistered
    let isSelected: Bool
    let action: () -> Void

    private let cardWidth: CGFloat = 124
    private let cardHeight: CGFloat = 174

    var body: some View {
        Button(action: action) {
            cardStack
        }
    }

    private var cardStack: some View {
        ZStack {
            cardBackground
            cardContent
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.customFieldColor)
            .frame(width: cardWidth, height: cardHeight)
            .overlay(cardBorder)
            .scaleEffect(isSelected ? 1.10 : 1.05)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(strokeGradient, lineWidth: isSelected ? 2 : 0)
    }

    private var strokeGradient: LinearGradient {
        isSelected
            ? LinearGradient(
                colors: [Color(hex: "F36656"), Color(hex: "F36656")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            : LinearGradient(
                colors: [Color.clear, Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
    }

    private var cardContent: some View {
        VStack(spacing: 10) {
            tyreImageView
            tyreBrand
            tyreSeason
        }
    }

    private var tyreImageView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.2))
                .frame(width: 116, height: 90)

            Image("tirePortrait")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 80)
                .clipped()
        }
    }

    private var tyreBrand: some View {
        Text(tyre.brand)
            .font(.customFont(size: 16, weight: .semibold))
            .multilineTextAlignment(.center)
            .foregroundColor(.white)
            .lineLimit(1)
    }

    private var tyreSeason: some View {
        Text(localizedSeason)
            .font(.customFont(size: 11, weight: .bold))
            .foregroundColor(.black.opacity(0.8))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                .fill(seasonColor(for: tyre.season))
            )
    }

    private func extractRadius() -> String {
        let parts = tyre.size.components(separatedBy: "R")
        return parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : "-"
    }

    private var localizedSeason: String {
        let lower = tyre.season.lowercased()

        if lower.contains("winter") || lower.contains("invern") {
            return "INVERNALE"
        }

        if lower.contains("summer") || lower.contains("estiv") {
            return "ESTIVO"
        }

        if lower.contains("all") || lower.contains("4") {
            return "QUATTRO\nSTAGIONI"
        }

        return tyre.season.uppercased()
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
#Preview {
    TireAnalysisSelectionView()
        .preferredColorScheme(.dark)
}
