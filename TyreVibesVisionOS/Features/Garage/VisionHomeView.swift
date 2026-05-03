#if os(visionOS)
import SwiftUI

struct VisionHomeView: View {
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @EnvironmentObject private var garageStore: VisionGarageStore

    @State private var isImmersiveSpaceOpen = false

    var body: some View {
        NavigationSplitView {
            Group {
                if garageStore.vehicles.isEmpty {
                    ContentUnavailableView(
                        "Garage vuoto",
                        systemImage: "car.side",
                        description: Text(garageStore.cacheLoadMessage ?? "Nessuna auto disponibile per Vision.")
                    )
                    .padding()
                    .overlay(alignment: .bottom) {
                        if garageStore.isLoading {
                            ProgressView()
                                .padding(.bottom, 24)
                        }
                    }
                } else {
                    List(selection: $garageStore.selectedVehicleID) {
                        ForEach(garageStore.vehicles) { vehicle in
                            VisionVehicleRowView(vehicle: vehicle)
                                .tag(vehicle.id)
                                .onTapGesture {
                                    garageStore.select(vehicle)
                                }
                        }
                    }
                }
            }
            .navigationTitle("Garage virtuale")
        } detail: {
            if garageStore.vehicles.isEmpty {
                emptyGarageDetail
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    selectedVehicleHeader

                    List(garageStore.tyres, selection: $garageStore.selectedTyreID) { tyre in
                        TyreRowView(tyre: tyre)
                            .tag(tyre.id)
                    }
                    .frame(minHeight: 230)

                    if let selectedTyre = garageStore.selectedTyre {
                        TyreInspectionDashboard(tyre: selectedTyre)
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    immersiveControls
                }
            }
        }
        .onAppear {
            garageStore.selectedVehicleID = garageStore.selectedVehicleID ?? garageStore.vehicles.first?.id
            garageStore.selectedTyreID = garageStore.selectedTyreID ?? garageStore.tyres.first?.id
        }
        .onChange(of: garageStore.selectedVehicleID) { _, _ in
            garageStore.selectedTyreID = garageStore.selectedVehicle?.tyres.first?.id
        }
    }

    private var selectedVehicleHeader: some View {
        guard let selectedVehicle = garageStore.selectedVehicle else {
            return AnyView(EmptyView())
        }

        return AnyView(
        HStack(spacing: 14) {
            Image(systemName: "car.side.fill")
                .font(.title2)
                .foregroundStyle(selectedVehicle.healthState.tint)
                .frame(width: 48, height: 48)
                .background(selectedVehicle.healthState.tint.opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(selectedVehicle.name)
                    .font(.title2.weight(.bold))

                Text(headerSubtitle(for: selectedVehicle))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
        )
    }

    private var emptyGarageDetail: some View {
        VStack(spacing: 18) {
            Image(systemName: "visionpro")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Nessuna auto reale da posizionare")
                .font(.title2.weight(.bold))

            Text(garageStore.cacheLoadMessage ?? "Quando il garage utente sara sincronizzato, le auto compariranno qui e nello spazio 3D.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)

            Button {
                Task {
                    await garageStore.reloadFromBackend()
                }
            } label: {
                Label(garageStore.isLoading ? "Caricamento" : "Ricarica garage", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .disabled(garageStore.isLoading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private func headerSubtitle(for vehicle: VisionVehicleSnapshot) -> String {
        guard vehicle.healthState != .unknown else {
            return "\(vehicle.plate) • pneumatici non ancora analizzati"
        }

        return "\(vehicle.plate) • min \(String(format: "%.1f mm", vehicle.minimumTreadDepthMillimeters)) • media \(String(format: "%.1f bar", vehicle.averagePressureBar))"
    }

    private var immersiveControls: some View {
        HStack {
            Button {
                Task {
                    if isImmersiveSpaceOpen {
                        await dismissImmersiveSpace()
                        isImmersiveSpaceOpen = false
                    } else {
                        let result = await openImmersiveSpace(id: VisionSceneID.garageSpace.rawValue)
                        isImmersiveSpaceOpen = result == .opened
                    }
                }
            } label: {
                Label(
                    isImmersiveSpaceOpen ? "Chiudi spazio 3D" : "Apri spazio 3D",
                    systemImage: isImmersiveSpaceOpen ? "xmark.circle" : "visionpro"
                )
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding(24)
        .glassBackgroundEffect()
    }
}

private struct VisionVehicleRowView: View {
    let vehicle: VisionVehicleSnapshot

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "car.side.fill")
                .font(.title3)
                .foregroundStyle(vehicle.healthState.tint)
                .frame(width: 38, height: 38)
                .background(vehicle.healthState.tint.opacity(0.18), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.name)
                    .font(.headline)

                Text("\(vehicle.plate) • \(vehicle.healthState.title)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }
}

#Preview(windowStyle: .automatic) {
    VisionHomeView()
        .environmentObject(VisionGarageStore())
}
#endif
