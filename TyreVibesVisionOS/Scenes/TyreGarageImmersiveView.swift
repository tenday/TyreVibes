#if os(visionOS)
import RealityKit
import SwiftUI

struct TyreGarageImmersiveView: View {
    @EnvironmentObject private var garageStore: VisionGarageStore

    var body: some View {
        RealityView { content in
            let anchor = AnchorEntity(.head)
            anchor.position = [0, -0.35, -1.4]

            let tyreEntity = makeTyreEntity()
            tyreEntity.name = "SelectedTyre"
            anchor.addChild(tyreEntity)

            content.add(anchor)
        } update: { content in
            guard let tyreEntity = content.entities.first?.findEntity(named: "SelectedTyre") else {
                return
            }

            tyreEntity.transform.scale = SIMD3<Float>(repeating: selectedTyreScale)
        }
    }

    private var selectedTyreScale: Float {
        switch garageStore.selectedTyre.healthState {
        case .optimal:
            return 1.0
        case .monitor:
            return 0.94
        case .critical:
            return 0.88
        }
    }

    private func makeTyreEntity() -> Entity {
        let root = Entity()

        let treadBlockMesh = MeshResource.generateBox(size: [0.12, 0.08, 0.04])
        let tyreMaterial = SimpleMaterial(color: .darkGray, roughness: 0.7, isMetallic: false)

        for index in 0..<16 {
            let angle = Float(index) * (2 * .pi / 16)
            let block = ModelEntity(mesh: treadBlockMesh, materials: [tyreMaterial])
            block.position = [cos(angle) * 0.28, sin(angle) * 0.28, 0]
            block.orientation = simd_quatf(angle: angle, axis: [0, 0, 1])
            root.addChild(block)
        }

        let hubMesh = MeshResource.generateSphere(radius: 0.14)
        let hubMaterial = SimpleMaterial(color: .lightGray, roughness: 0.35, isMetallic: true)
        let hub = ModelEntity(mesh: hubMesh, materials: [hubMaterial])

        root.addChild(hub)

        return root
    }
}
#endif
