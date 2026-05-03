#if os(visionOS)
import RealityKit
import SwiftUI
import UIKit

struct TyreGarageImmersiveView: View {
    @EnvironmentObject private var garageStore: VisionGarageStore

    var body: some View {
        RealityView { content, attachments in
            let anchor = AnchorEntity(.head)
            anchor.position = [0, -0.95, -2.2]

            anchor.addChild(makeGarageFloor())
            anchor.addChild(makeBackWall())
            syncVehicles(in: anchor, attachments: attachments)

            content.add(anchor)
        } update: { content, attachments in
            guard let anchor = content.entities.first else { return }
            syncVehicles(in: anchor, attachments: attachments)

            for vehicle in garageStore.vehicles {
                guard let entity = anchor.findEntity(named: garageStore.entityName(for: vehicle)) else {
                    continue
                }

                let isSelected = vehicle.id == garageStore.selectedVehicle?.id
                entity.scale = SIMD3<Float>(repeating: isSelected ? 1.08 : 1.0)
                entity.children.first { $0.name == "SelectionHalo" }?.isEnabled = isSelected
            }
        } attachments: {
            ForEach(garageStore.vehicles) { vehicle in
                Attachment(id: vehicle.id) {
                    VisionVehicleBillboardView(vehicle: vehicle)
                }
            }
        }
        .gesture(
            TapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    let entityName = vehicleEntityName(from: value.entity)
                    garageStore.selectVehicle(named: entityName)
                }
        )
    }

    private func syncVehicles(in anchor: Entity, attachments: RealityViewAttachments) {
        let activeEntityNames = Set(garageStore.vehicles.map { garageStore.entityName(for: $0) })

        for child in anchor.children where child.name.hasPrefix("vehicle-") && !activeEntityNames.contains(child.name) {
            child.removeFromParent()
        }

        for (index, vehicle) in garageStore.vehicles.enumerated() {
            let entityName = garageStore.entityName(for: vehicle)
            let entity = anchor.findEntity(named: entityName) ?? makeVehicleEntity(vehicle: vehicle, attachments: attachments)
            entity.name = entityName
            entity.position = lanePosition(for: index, total: garageStore.vehicles.count)

            if entity.parent == nil {
                anchor.addChild(entity)
            }
        }
    }

    private func lanePosition(for index: Int, total: Int) -> SIMD3<Float> {
        let spacing: Float = 1.35
        let offset = Float(index) - Float(total - 1) / 2
        return [offset * spacing, 0, 0]
    }

    private func makeGarageFloor() -> Entity {
        let root = Entity()

        let floor = ModelEntity(
            mesh: .generateBox(size: [5.2, 0.035, 2.4]),
            materials: [SimpleMaterial(color: UIColor(white: 0.08, alpha: 1), roughness: 0.85, isMetallic: false)]
        )
        floor.position = [0, -0.03, 0.05]
        root.addChild(floor)

        let laneMaterial = SimpleMaterial(color: UIColor(white: 0.45, alpha: 1), roughness: 0.7, isMetallic: false)
        for x in stride(from: -2.0 as Float, through: 2.0, by: 1.0) {
            let line = ModelEntity(mesh: .generateBox(size: [0.025, 0.006, 2.1]), materials: [laneMaterial])
            line.position = [x, 0.0, 0.05]
            root.addChild(line)
        }

        return root
    }

    private func makeBackWall() -> Entity {
        let wall = ModelEntity(
            mesh: .generateBox(size: [5.2, 1.2, 0.035]),
            materials: [SimpleMaterial(color: UIColor(white: 0.12, alpha: 1), roughness: 0.75, isMetallic: false)]
        )
        wall.position = [0, 0.56, 0.95]
        return wall
    }

    private func makeVehicleEntity(vehicle: VisionVehicleSnapshot, attachments: RealityViewAttachments) -> Entity {
        let root = Entity()
        root.components.set(InputTargetComponent())
        root.components.set(CollisionComponent(shapes: [.generateBox(size: [0.92, 0.48, 1.28])]))

        if let billboard = attachments.entity(for: vehicle.id), vehicle.imageProfile?.garageImageURL != nil {
            billboard.name = "VehicleBillboard"
            billboard.position = [0, 0.45, -0.02]
            billboard.scale = [0.00155, 0.00155, 0.00155]
            root.addChild(billboard)
        } else {
            addProceduralVehicleBody(to: root, vehicle: vehicle)
        }

        let darkMaterial = SimpleMaterial(color: UIColor(white: 0.02, alpha: 1), roughness: 0.72, isMetallic: false)
        let selectedHalo = ModelEntity(
            mesh: .generateBox(size: [1.04, 0.012, 1.42]),
            materials: [SimpleMaterial(color: UIColor(vehicle.healthState.tint).withAlphaComponent(0.35), roughness: 0.4, isMetallic: false)]
        )
        selectedHalo.name = "SelectionHalo"
        selectedHalo.position = [0, 0.012, 0]
        selectedHalo.isEnabled = vehicle.id == garageStore.selectedVehicle?.id
        root.addChild(selectedHalo)

        addWheelMarkers(to: root, vehicle: vehicle, darkMaterial: darkMaterial)

        return root
    }

    private func addProceduralVehicleBody(to root: Entity, vehicle: VisionVehicleSnapshot) {
        let bodyColor = UIColor(vehicle.bodyColor)
        let bodyMaterial = SimpleMaterial(color: bodyColor, roughness: 0.45, isMetallic: true)
        let glassMaterial = SimpleMaterial(color: UIColor(red: 0.12, green: 0.18, blue: 0.22, alpha: 1), roughness: 0.22, isMetallic: false)

        let body = ModelEntity(mesh: .generateBox(size: [0.82, 0.24, 1.08]), materials: [bodyMaterial])
        body.position = [0, 0.25, 0]
        root.addChild(body)

        let cabin = ModelEntity(mesh: .generateBox(size: [0.58, 0.24, 0.46]), materials: [glassMaterial])
        cabin.position = [0, 0.46, -0.08]
        root.addChild(cabin)

        let hood = ModelEntity(mesh: .generateBox(size: [0.72, 0.09, 0.32]), materials: [bodyMaterial])
        hood.position = [0, 0.36, -0.48]
        root.addChild(hood)

        let plate = ModelEntity(mesh: .generateBox(size: [0.32, 0.055, 0.012]), materials: [SimpleMaterial(color: .white, roughness: 0.35, isMetallic: false)])
        plate.position = [0, 0.27, -0.55]
        root.addChild(plate)
    }

    private func addWheelMarkers(to root: Entity, vehicle: VisionVehicleSnapshot, darkMaterial: SimpleMaterial) {
        for (index, tyre) in vehicle.tyres.enumerated() {
            let wheelRoot = Entity()
            wheelRoot.position = wheelPosition(index)

            let wheel = ModelEntity(mesh: .generateCylinder(height: 0.12, radius: 0.13), materials: [darkMaterial])
            wheel.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
            wheelRoot.addChild(wheel)

            let marker = ModelEntity(
                mesh: .generateSphere(radius: 0.045),
                materials: [SimpleMaterial(color: UIColor(tyre.healthState.tint), roughness: 0.25, isMetallic: false)]
            )
            marker.position = [0, 0.25, 0]
            wheelRoot.addChild(marker)

            root.addChild(wheelRoot)
        }
    }

    private func wheelPosition(_ index: Int) -> SIMD3<Float> {
        switch index {
        case 0:
            return [-0.42, 0.14, -0.38]
        case 1:
            return [0.42, 0.14, -0.38]
        case 2:
            return [-0.42, 0.14, 0.39]
        default:
            return [0.42, 0.14, 0.39]
        }
    }

    private func vehicleEntityName(from entity: Entity) -> String {
        var current: Entity? = entity

        while let entity = current {
            if entity.name.hasPrefix("vehicle-") {
                return entity.name
            }
            current = entity.parent
        }

        return entity.name
    }
}

private struct VisionVehicleBillboardView: View {
    let vehicle: VisionVehicleSnapshot

    var body: some View {
        ZStack {
            if let url = vehicle.imageProfile?.garageImageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        fallbackBody
                    case .empty:
                        ProgressView()
                            .controlSize(.large)
                    @unknown default:
                        fallbackBody
                    }
                }
            } else {
                fallbackBody
            }
        }
        .frame(width: 520, height: 260)
        .background(.clear)
    }

    private var fallbackBody: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(vehicle.bodyColor.gradient)
                .frame(width: 430, height: 112)
                .offset(y: 34)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.black.opacity(0.7))
                .frame(width: 220, height: 82)
                .offset(y: -24)

            HStack(spacing: 238) {
                Circle()
                    .fill(.black)
                    .frame(width: 74, height: 74)

                Circle()
                    .fill(.black)
                    .frame(width: 74, height: 74)
            }
            .offset(y: 82)
        }
    }
}
#endif
