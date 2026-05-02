#if os(visionOS)
import SwiftUI

struct VisionHomeView: View {
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @EnvironmentObject private var garageStore: VisionGarageStore

    @State private var isImmersiveSpaceOpen = false

    var body: some View {
        NavigationSplitView {
            List(garageStore.tyres, selection: $garageStore.selectedTyreID) { tyre in
                TyreRowView(tyre: tyre)
                    .tag(tyre.id)
            }
            .navigationTitle("Garage")
        } detail: {
            TyreInspectionDashboard(tyre: garageStore.selectedTyre)
                .safeAreaInset(edge: .bottom) {
                    immersiveControls
                }
        }
        .onAppear {
            garageStore.selectedTyreID = garageStore.selectedTyreID ?? garageStore.tyres.first?.id
        }
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

#Preview(windowStyle: .automatic) {
    VisionHomeView()
        .environmentObject(VisionGarageStore())
}
#endif
