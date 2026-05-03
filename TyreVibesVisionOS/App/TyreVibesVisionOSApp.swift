#if os(visionOS)
import SwiftUI

@main
struct TyreVibesVisionOSApp: App {
    @State private var immersionStyle: ImmersionStyle = .mixed
    @StateObject private var garageStore = VisionGarageStore()

    var body: some Scene {
        WindowGroup(id: VisionSceneID.mainWindow.rawValue) {
            VisionHomeView()
                .environmentObject(garageStore)
        }
        .defaultSize(width: 980, height: 720)

        ImmersiveSpace(id: VisionSceneID.garageSpace.rawValue) {
            TyreGarageImmersiveView()
                .environmentObject(garageStore)
        }
        .immersionStyle(selection: $immersionStyle, in: .mixed)
    }
}
#endif
