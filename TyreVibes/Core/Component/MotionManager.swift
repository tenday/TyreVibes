import SwiftUI
import CoreMotion

// MARK: - Motion Manager per rilevare rotazione
class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    @Published var rotationAngle: Double = 0
    @Published var isRotating: Bool = false
    @Published var rotationSpeed: Double = 0
    @Published var totalRotation: Double = 0
    
    private var lastAngle: Double = 0
    private var rotationStartTime = Date()
    
    func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            
            // Calcola rotazione su asse Z (yaw)
            let currentAngle = motion.attitude.yaw * 180 / .pi
            
            // Calcola velocità di rotazione
            let angleDelta = currentAngle - self.lastAngle
            self.rotationSpeed = abs(angleDelta)
            
            // Determina se sta ruotando
            self.isRotating = self.rotationSpeed > 2.0
            
            // Accumula rotazione totale
            if self.isRotating {
                self.totalRotation += abs(angleDelta)
            }
            
            self.rotationAngle = currentAngle
            self.lastAngle = currentAngle
        }
    }
    
    func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
    
    func resetRotation() {
        totalRotation = 0
        rotationStartTime = Date()
    }
    
    var rotationProgress: Double {
        // Considera completata dopo 360 gradi di rotazione totale
        return min(totalRotation / 360.0, 1.0)
    }
}

// MARK: - Vista Guide di Rotazione
struct RotationGuideOverlay: View {
    @StateObject private var motionManager = MotionManager()
    @Binding var isScanning: Bool
    let onRotationComplete: () -> Void
    private let completionFeedbackDelay: Double = 2.8
    
    @State private var pulseAnimation = false
    @State private var arrowRotation: Double = 0
    @State private var showCompletionFeedback = false
    
    // Settori scansionati (divide il cerchio in 8 parti)
    @State private var scannedSectors: Set<Int> = []
    
    private var currentSector: Int {
        let normalized = (motionManager.rotationAngle.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return Int(normalized / 45) // 360/8 = 45 gradi per settore
    }
    
    var body: some View {
        ZStack {
            // Cerchio principale con settori
            ZStack {
                // Cerchio di sfondo
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 3)
                    .frame(width: 360, height: 360)
                
                // Settori scansionati
                ForEach(0..<8) { sector in
                    SectorShape(
                        startAngle: Angle(degrees: Double(sector * 45)),
                        endAngle: Angle(degrees: Double((sector + 1) * 45)),
                        innerRadius: 170,
                        outerRadius: 180
                    )
                    .fill(scannedSectors.contains(sector) ?
                          Color.green.opacity(0.6) :
                          Color.white.opacity(0.1))
                    .animation(.easeInOut(duration: 0.3), value: scannedSectors.contains(sector))
                }
                
                // Indicatore settore corrente
                SectorShape(
                    startAngle: Angle(degrees: Double(currentSector * 45)),
                    endAngle: Angle(degrees: Double((currentSector + 1) * 45)),
                    innerRadius: 170,
                    outerRadius: 180
                )
                .fill(Color.cyan.opacity(0.8))
                .blur(radius: 2)
                .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(), value: pulseAnimation)
            }
            
            // Frecce direzionali animate
            ForEach(0..<4) { index in
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.cyan)
                    .opacity(motionManager.isRotating ? 0.3 : 0.8)
                    .rotationEffect(Angle(degrees: Double(index * 90)))
                    .offset(x: 200 * cos(Double(index) * .pi / 2),
                           y: 200 * sin(Double(index) * .pi / 2))
                    .rotationEffect(Angle(degrees: arrowRotation))
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: arrowRotation)
            }
            
            // Progress Ring
            Circle()
                .trim(from: 0, to: motionManager.rotationProgress)
                .stroke(
                    LinearGradient(
                        colors: [.green, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 340, height: 340)
                .rotationEffect(Angle(degrees: -90))
                .animation(.spring(), value: motionManager.rotationProgress)
            
            // Istruzioni centrali
            VStack(spacing: 16) {
                if !motionManager.isRotating {
                    // Icona animata
                    Image(systemName: "rotate.3d")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                        .rotationEffect(Angle(degrees: arrowRotation))
                        .opacity(0.9)
                }
                
                // Testo istruzioni
                VStack(spacing: 8) {
                    Text(getInstructionText())
                        .font(.customFont(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    if scannedSectors.count > 0 {
                        Text("\(scannedSectors.count)/8 sectors scanned")
                            .font(.customFont(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    // Progress percentage
                    Text("\(Int(motionManager.rotationProgress * 100))%")
                        .font(.customFont(size: 24, weight: .bold))
                        .foregroundColor(progressColor())
                }
                
                // Velocità di rotazione indicator
                if motionManager.isRotating {
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            Rectangle()
                                .fill(speedIndicatorColor(index: index))
                                .frame(width: 20, height: 4)
                                .cornerRadius(2)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .opacity(0.8)
            )
            
            // Feedback di completamento
            if showCompletionFeedback {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Scan Complete!")
                        .font(.customFont(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.regularMaterial)
                )
                .scaleEffect(showCompletionFeedback ? 1 : 0.5)
                .opacity(showCompletionFeedback ? 1 : 0)
                .animation(.spring(dampingFraction: 0.7), value: showCompletionFeedback)
            }
        }
        .onAppear {
            motionManager.startMotionUpdates()
            pulseAnimation = true
            
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                arrowRotation = 360
            }
        }
        .onDisappear {
            motionManager.stopMotionUpdates()
        }
        .onChange(of: currentSector) { _, newSector in
            // Aggiungi settore alla lista dei scansionati
            scannedSectors.insert(newSector)
            
            // Vibrazione leggera quando si entra in un nuovo settore
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
        .onChange(of: scannedSectors.count) { _, count in
            // Controlla se tutti i settori sono stati scansionati
            if count >= 8 && !showCompletionFeedback {
                completeScanning()
            }
        }
        .onChange(of: motionManager.rotationProgress) { _, progress in
            if progress >= 1.0 && !showCompletionFeedback {
                completeScanning()
            }
        }
    }
    
    private func getInstructionText() -> String {
        if showCompletionFeedback {
            return "Perfect! All areas scanned"
        } else if !motionManager.isRotating {
            return "Rotate phone slowly\naround the tire"
        } else if motionManager.rotationSpeed > 10 {
            return "Slow down a bit"
        } else if motionManager.rotationSpeed < 2 {
            return "Keep rotating"
        } else {
            return "Perfect! Keep going"
        }
    }
    
    private func progressColor() -> Color {
        if motionManager.rotationProgress < 0.3 {
            return .white
        } else if motionManager.rotationProgress < 0.7 {
            return .yellow
        } else {
            return .green
        }
    }
    
    private func speedIndicatorColor(index: Int) -> Color {
        let speed = motionManager.rotationSpeed
        if speed < 5 {
            return index == 0 ? .yellow : .white.opacity(0.3)
        } else if speed < 10 {
            return index <= 1 ? .green : .white.opacity(0.3)
        } else {
            return .red
        }
    }
    
    private func completeScanning() {
        showCompletionFeedback = true
        
        // Vibrazione di successo
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
        
        // Lascia il feedback visibile abbastanza a lungo da essere letto.
        DispatchQueue.main.asyncAfter(deadline: .now() + completionFeedbackDelay) {
            onRotationComplete()
        }
    }
}

// MARK: - Forma Settore Personalizzata
struct SectorShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: startAngle - Angle(degrees: 90),
            endAngle: endAngle - Angle(degrees: 90),
            clockwise: false
        )
        
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: endAngle - Angle(degrees: 90),
            endAngle: startAngle - Angle(degrees: 90),
            clockwise: true
        )
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Guide Statiche Alternative (senza Motion)
struct StaticRotationGuide: View {
    @State private var currentStep = 0
    @State private var animateArrows = false
    let steps = ["Top", "Right", "Bottom", "Left"]
    
    var body: some View {
        ZStack {
            // Cerchio con quadranti
            ForEach(0..<4) { quadrant in
                QuadrantView(
                    quadrant: quadrant,
                    isActive: quadrant == currentStep,
                    isCompleted: quadrant < currentStep
                )
            }
            
            // Frecce animate
            ForEach(0..<4) { index in
                Image(systemName: "arrow.right")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(index == currentStep ? .cyan : .white.opacity(0.3))
                    .rotationEffect(Angle(degrees: Double(index * 90)))
                    .offset(
                        x: 190 * cos(Double(index) * .pi / 2 - .pi / 2),
                        y: 190 * sin(Double(index) * .pi / 2 - .pi / 2)
                    )
                    .scaleEffect(index == currentStep && animateArrows ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(), value: animateArrows)
            }
            
            // Istruzioni
            VStack(spacing: 12) {
                Text("Scan \(steps[currentStep]) Side")
                    .font(.customFont(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Tap when ready")
                    .font(.customFont(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<4) { index in
                        Circle()
                            .fill(index <= currentStep ? Color.green : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 8)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            .onTapGesture {
                withAnimation(.spring()) {
                    if currentStep < 3 {
                        currentStep += 1
                    } else {
                        currentStep = 0
                    }
                }
            }
        }
        .onAppear {
            animateArrows = true
        }
    }
}

struct QuadrantView: View {
    let quadrant: Int
    let isActive: Bool
    let isCompleted: Bool
    
    var body: some View {
        SectorShape(
            startAngle: Angle(degrees: Double(quadrant * 90)),
            endAngle: Angle(degrees: Double((quadrant + 1) * 90)),
            innerRadius: 160,
            outerRadius: 180
        )
        .fill(fillColor())
        .animation(.easeInOut(duration: 0.3), value: isActive)
        .animation(.easeInOut(duration: 0.3), value: isCompleted)
    }
    
    private func fillColor() -> Color {
        if isCompleted {
            return Color.green.opacity(0.6)
        } else if isActive {
            return Color.cyan.opacity(0.8)
        } else {
            return Color.white.opacity(0.1)
        }
    }
}
