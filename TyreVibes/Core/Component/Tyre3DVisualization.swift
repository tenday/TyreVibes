//
//  Tyre3DVisualization.swift
//  TyreVibes
//
//  3D visualization component for tyre analysis
//

import SwiftUI
import ARKit
import RealityKit
import ModelIO

// MARK: - 3D Tyre Model Component
struct Tyre3DVisualization: View {
    @StateObject private var viewModel = Tyre3DViewModel()
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    viewModel.rotateLeft()
                }) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.blue.opacity(0.3))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Button(action: {
                    viewModel.rotateRight()
                }) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.blue.opacity(0.3))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
            
            ARViewContainer(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            HStack {
                Button(action: {
                    viewModel.zoomIn()
                }) {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.green.opacity(0.3))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Button(action: {
                    viewModel.zoomOut()
                }) {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.orange.opacity(0.3))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
        }
        .background(Color.black)
    }
}

// MARK: - AR View Container
struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: Tyre3DViewModel
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        arView.delegate = context.coordinator
        arView.autoenablesDefaultLighting = true
        arView.automaticallyUpdatesLighting = true
        arView.scene.lightingEnvironment.intensity = 2
        
        // Create tyre model
        setupTyreModel(in: arView)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Update camera position based on zoom level
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        
        // Adjust camera distance based on zoom level
        let zoomFactor = 1.0 + (viewModel.zoomLevel * 0.5)
        cameraNode.position = SCNVector3(0, 0, 5 * zoomFactor)
        
        uiView.pointOfView?.removeFromParentNode()
        uiView.scene.rootNode.addChildNode(cameraNode)
        uiView.pointOfView = cameraNode
        
        // Rotate the tyre based on rotation state
        uiView.scene.rootNode.enumerateChildNodes { (node, _) in
            if node.name == "tyreModel" {
                let rotation = simd_float4x4(SCNMatrix4MakeRotation(Float(viewModel.rotationAngle), 0, 1, 0))
                node.simdTransform = rotation
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    class Coordinator: NSObject, ARSCNViewDelegate {
        let viewModel: Tyre3DViewModel
        
        init(viewModel: Tyre3DViewModel) {
            self.viewModel = viewModel
        }
        
        func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
            // Handle anchor additions if needed
        }
    }
    
    private func setupTyreModel(in arView: ARSCNView) {
        // Create a simple tyre geometry as placeholder
        // In a real implementation, you would load an actual tyre model
        let tyreGeometry = SCNTorus(ringRadius: 0.5, pipeRadius: 0.15)
        tyreGeometry.firstMaterial?.diffuse.contents = UIColor.darkGray
        tyreGeometry.firstMaterial?.specular.contents = UIColor.white
        tyreGeometry.firstMaterial?.emission.contents = UIColor(white: 0.1, alpha: 1.0)
        
        let tyreNode = SCNNode(geometry: tyreGeometry)
        tyreNode.name = "tyreModel"
        tyreNode.position = SCNVector3(0, 0, 0)
        
        // Add wear visualization by changing color based on wear zones
        addWearVisualization(to: tyreNode)
        
        arView.scene.rootNode.addChildNode(tyreNode)
    }
    
    private func addWearVisualization(to node: SCNNode) {
        // Add wear indicators based on zones
        let zones = ["inner", "center", "outer"]
        let colors = [UIColor.red, UIColor.yellow, UIColor.green] // Representing different wear levels
        
        for (index, zone) in zones.enumerated() {
            let indicatorGeometry = SCNCylinder(radius: 0.02, height: 0.1)
            indicatorGeometry.firstMaterial?.diffuse.contents = colors[index]
            
            let indicatorNode = SCNNode(geometry: indicatorGeometry)
            indicatorNode.name = "wearIndicator_\(zone)"
            
            // Position the indicator around the tyre
            let angle = Float(index) * .pi * 2 / Float(zones.count)
            let radius: Float = 0.5
            indicatorNode.position = SCNVector3(
                radius * cos(angle),
                0,
                radius * sin(angle)
            )
            
            node.addChildNode(indicatorNode)
        }
    }
}

// MARK: - 3D View Model
class Tyre3DViewModel: ObservableObject {
    @Published var rotationAngle: Double = 0
    @Published var zoomLevel: Double = 0
    
    func rotateLeft() {
        rotationAngle -= Double.pi / 4
    }
    
    func rotateRight() {
        rotationAngle += Double.pi / 4
    }
    
    func zoomIn() {
        if zoomLevel > -3 {
            zoomLevel -= 0.5
        }
    }
    
    func zoomOut() {
        if zoomLevel < 3 {
            zoomLevel += 0.5
        }
    }
}

// MARK: - Basic 3D Visualization for SwiftUI (fallback)
struct Basic3DVisualization: View {
    @State private var rotation: Double = 0
    @State private var scale: Double = 1.0
    
    let tyreCondition: Double // 0.0 to 1.0 scale representing condition
    
    var body: some View {
        VStack(spacing: 20) {
            Text("3D Tyre Visualization")
                .font(.customFont(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            ZStack {
                // Outer tyre circle
                Circle()
                    .stroke(lineWidth: 20)
                    .foregroundColor(tyreConditionColor)
                    .frame(width: 200 * scale, height: 200 * scale)
                
                // Inner tyre circle
                Circle()
                    .stroke(lineWidth: 10)
                    .foregroundColor(.gray)
                    .frame(width: 150 * scale, height: 150 * scale)
                
                // Tread pattern
                treadPattern
            }
            .rotation3DEffect(
                .degrees(rotation),
                axis: (x: 0.0, y: 1.0, z: 0.0)
            )
            .onAppear {
                // Animate rotation
                withAnimation(Animation.linear(duration: 10).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
            
            HStack(spacing: 20) {
                Button(action: {
                    withAnimation {
                        scale = max(0.5, scale - 0.1)
                    }
                }) {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.blue.opacity(0.3))
                        .clipShape(Circle())
                }
                
                Button(action: {
                    withAnimation {
                        rotation += 45
                    }
                }) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.green.opacity(0.3))
                        .clipShape(Circle())
                }
                
                Button(action: {
                    withAnimation {
                        scale = min(1.5, scale + 0.1)
                    }
                }) {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.blue.opacity(0.3))
                        .clipShape(Circle())
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(12)
    }
    
    private var tyreConditionColor: Color {
        switch tyreCondition {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .blue
        case 0.4..<0.6: return .yellow
        case 0.2..<0.4: return .orange
        default: return .red
        }
    }
    
    private var treadPattern: some View {
        ZStack {
            ForEach(0..<12) { index in
                let angle = Double(index) * 30.0
                treadBlock(angle: angle)
            }
        }
    }
    
    private func treadBlock(angle: Double) -> some View {
        Rectangle()
            .fill(tyreConditionColor)
            .frame(width: 10, height: 30)
            .rotationEffect(.degrees(angle))
            .offset(y: -100 * scale)
    }
}