import SwiftUI
import Foundation

// MARK: - 1. Enhanced Data Visualization

struct RevisionTimelineView: View {
    let revisions: [VehicleRevision]
    @State private var selectedRevision: VehicleRevision?
    @State private var animateTimeline = false
    @State private var hoveredIndex: Int? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Cronologia Revisioni")
                .font(.customFont(size: 18, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(revisions.enumerated()), id: \.offset) { index, revision in
                        TimelineNode(
                            revision: revision,
                            index: index,
                            isFirst: index == 0,
                            isLast: index == revisions.count - 1,
                            isSelected: selectedRevision?.id == revision.id,
                            isHovered: hoveredIndex == index,
                            animationDelay: Double(index) * 0.1
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedRevision = revision
                            }
                        }
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                hoveredIndex = hovering ? index : nil
                            }
                        }
                        
                        if index < revisions.count - 1 {
                            TimelineConnector(
                                status: getConnectionStatus(revision, revisions[index + 1]),
                                animationDelay: Double(index) * 0.15
                            )
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 40)
            }
            
            // Selected revision detail card
            if let selected = selectedRevision {
                RevisionDetailCard(revision: selected)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
            }
        }
        .onAppear {
            animateTimeline = true
        }
    }
    
    func getConnectionStatus(_ current: VehicleRevision, _ next: VehicleRevision) -> ConnectionStatus {
        guard let currentResult = current.esitoRevisione?.lowercased(),
              let nextResult = next.esitoRevisione?.lowercased() else {
            return .neutral
        }
        
        let currentPositive = currentResult.contains("positive") || currentResult.contains("pass")
        let nextPositive = nextResult.contains("positive") || nextResult.contains("pass")
        
        if currentPositive && nextPositive {
            return .good
        } else if !currentPositive || !nextPositive {
            return .warning
        }
        return .neutral
    }
}

enum ConnectionStatus {
    case good, warning, neutral
    
    var color: Color {
        switch self {
        case .good: return .green
        case .warning: return .orange
        case .neutral: return .gray
        }
    }
}

struct TimelineNode: View {
    let revision: VehicleRevision
    let index: Int
    let isFirst: Bool
    let isLast: Bool
    let isSelected: Bool
    let isHovered: Bool
    let animationDelay: Double
    
    @State private var appear = false
    @State private var pulseAnimation = false
    
    var statusColor: Color {
        guard let esito = revision.esitoRevisione?.lowercased() else { return .gray }
        if esito.contains("positive") || esito.contains("pass") {
            return .green
        } else if esito.contains("negative") || esito.contains("fail") {
            return .red
        }
        return .orange
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Date label
            Text(formatDate(revision.dataRevisione))
                .font(.customFont(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : -10)
            
            // Node circle with animations
            ZStack {
                // Outer pulse ring
                Circle()
                    .stroke(statusColor.opacity(0.3), lineWidth: 2)
                    .frame(width: 60, height: 60)
                    .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                    .opacity(pulseAnimation ? 0 : 0.6)
                
                // Main node
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                statusColor.opacity(0.8),
                                statusColor.opacity(0.4)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 25
                        )
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(statusColor, lineWidth: 3)
                            .scaleEffect(isSelected ? 1.1 : 1.0)
                    )
                    .shadow(color: statusColor.opacity(0.6), radius: isSelected ? 15 : 5)
                
                // Icon
                Image(systemName: statusIcon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(appear ? 1 : 0.5)
            }
            .scaleEffect(isHovered ? 1.2 : (isSelected ? 1.1 : 1.0))
            .opacity(appear ? 1 : 0)
            
            // KM badge
            if let km = revision.kmRevisione, !km.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 8))
                    Text("\(km) km")
                        .font(.customFont(size: 9, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.3))
                )
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 10)
            }
        }
        .frame(width: 100)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(animationDelay)) {
                appear = true
            }
            
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false).delay(animationDelay + 0.5)) {
                pulseAnimation = true
            }
        }
    }
    
    var statusIcon: String {
        guard let esito = revision.esitoRevisione?.lowercased() else { return "questionmark" }
        if esito.contains("positive") || esito.contains("pass") {
            return "checkmark"
        } else if esito.contains("negative") || esito.contains("fail") {
            return "xmark"
        }
        return "exclamationmark"
    }
    
    func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "" }
        // Simplified date formatting
        let components = dateString.split(separator: "-")
        if components.count >= 2 {
            return "\(components[1])/\(String(components[0]).suffix(2))"
        }
        return ""
    }
}

struct TimelineConnector: View {
    let status: ConnectionStatus
    let animationDelay: Double
    @State private var appear = false
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        status.color.opacity(0.6),
                        status.color.opacity(0.3)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: appear ? 50 : 0, height: 3)
            .overlay(
                // Animated dash effect
                Rectangle()
                    .fill(status.color)
                    .frame(width: 15, height: 3)
                    .offset(x: appear ? 25 : -25)
                    .animation(
                        .linear(duration: 1).repeatForever(autoreverses: false).delay(animationDelay),
                        value: appear
                    )
            )
            .onAppear {
                withAnimation(.easeOut(duration: 0.5).delay(animationDelay)) {
                    appear = true
                }
            }
    }
}

struct RevisionDetailCard: View {
    let revision: VehicleRevision
    @State private var appear = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.green)
                
                Text("Dettagli Revisione")
                    .font(.customFont(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                InfoBlock(
                    icon: "calendar",
                    label: "Data",
                    value: formatVehicleInfoDate(revision.dataRevisione)
                )
                
                InfoBlock(
                    icon: "checkmark.seal",
                    label: "Esito",
                    value: revision.esitoRevisione ?? "N/A"
                )
                
                InfoBlock(
                    icon: "speedometer",
                    label: "Chilometraggio",
                    value: (revision.kmRevisione ?? "N/A") + " km"
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
        .scaleEffect(appear ? 1 : 0.9)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appear = true
            }
        }
    }
}

struct InfoBlock: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                Text(label)
                    .font(.customFont(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            Text(value)
                .font(.customFont(size: 13, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - 2. Interactive 3D Tyre Visualization

struct Tyre3DView: View {
    let tyre: VehicleTyre
    @State private var rotation: Double = 0
    @State private var showWearIndicator = false
    @State private var selectedDetail: TyreDetail? = nil
    @State private var particleAnimation = false
    
    var body: some View {
        VStack(spacing: 20) {
            GeometryReader { geometry in
                ZStack {
                    // Background gradient
                    RadialGradient(
                        colors: [
                            Color.blue.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: geometry.size.width / 2
                    )
                    
                    // 3D Tyre
                    ZStack {
                        // Outer tyre ring
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.black,
                                        Color.gray.opacity(0.8),
                                        Color.black
                                    ],
                                    center: .center,
                                    startRadius: geometry.size.width * 0.2,
                                    endRadius: geometry.size.width * 0.5
                                )
                            )
                            .rotation3DEffect(
                                .degrees(rotation),
                                axis: (x: 0, y: 1, z: 0),
                                perspective: 0.5
                            )
                            .overlay(
                                TreadPatternView(
                                    wearLevel: calculateWearLevel(),
                                    isAnimating: rotation != 0
                                )
                                .rotation3DEffect(
                                    .degrees(rotation),
                                    axis: (x: 0, y: 1, z: 0),
                                    perspective: 0.5
                                )
                            )
                        
                        // Inner rim
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.gray.opacity(0.9),
                                        Color.white.opacity(0.8),
                                        Color.gray.opacity(0.9)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(
                                width: geometry.size.width * 0.4,
                                height: geometry.size.width * 0.4
                            )
                            .rotation3DEffect(
                                .degrees(rotation * 1.5),
                                axis: (x: 0, y: 1, z: 0),
                                perspective: 0.3
                            )
                        
                        // Central specifications
                        VStack(spacing: 4) {
                            Text("\(tyre.width ?? 0)/\(tyre.ratio ?? 0)")
                                .font(.customFont(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("R\(tyre.diameter ?? 0)")
                                .font(.customFont(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            HStack(spacing: 8) {
                                Text(tyre.speedIndex ?? "N/A")
                                    .font(.customFont(size: 14, weight: .semibold))
                                    .foregroundColor(.blue)
                                
                                Text(tyre.loadIndex ?? "N/A")
                                    .font(.customFont(size: 14, weight: .semibold))
                                    .foregroundColor(.green)
                            }
                        }
                        .scaleEffect(showWearIndicator ? 0.8 : 1.0)
                        
                        // Particle effects
                        if particleAnimation {
                            ForEach(0..<8, id: \.self) { index in
                                ParticleView(
                                    delay: Double(index) * 0.1,
                                    radius: geometry.size.width * 0.5
                                )
                            }
                        }
                    }
                    
                    // Interactive points
                    TyreInteractivePoints(
                        selectedDetail: $selectedDetail,
                        tyreSize: geometry.size.width
                    )
                }
                .frame(width: geometry.size.width, height: geometry.size.width)
            }
            .aspectRatio(1, contentMode: .fit)
            .onAppear {
                withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
                
                withAnimation(.easeInOut(duration: 1).delay(0.5)) {
                    particleAnimation = true
                }
            }
            
            // Control panel
            TyreControlPanel(
                showWearIndicator: $showWearIndicator,
                tyre: tyre,
                selectedDetail: selectedDetail
            )
        }
        .padding()
    }
    
    func calculateWearLevel() -> Double {
        // Mock calculation - in real app would be based on actual data
        return 0.7
    }
}

struct TreadPatternView: View {
    let wearLevel: Double
    let isAnimating: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<12, id: \.self) { index in
                TreadLine(
                    angle: Double(index) * 30,
                    wearLevel: wearLevel,
                    size: geometry.size
                )
            }
        }
    }
}

struct TreadLine: View {
    let angle: Double
    let wearLevel: Double
    let size: CGSize
    
    var treadColor: Color {
        if wearLevel > 0.7 {
            return .green
        } else if wearLevel > 0.4 {
            return .orange
        } else {
            return .red
        }
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(treadColor.opacity(0.8))
            .frame(width: 4, height: size.height * 0.15 * wearLevel)
            .offset(y: -size.height * 0.35)
            .rotationEffect(.degrees(angle))
            .position(x: size.width / 2, y: size.height / 2)
    }
}

struct ParticleView: View {
    let delay: Double
    let radius: CGFloat
    @State private var offset = CGSize.zero
    @State private var opacity: Double = 1
    
    var body: some View {
        Circle()
            .fill(Color.blue)
            .frame(width: 4, height: 4)
            .offset(offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 2).delay(delay).repeatForever(autoreverses: false)) {
                    offset = CGSize(
                        width: CGFloat.random(in: -radius...radius),
                        height: CGFloat.random(in: -radius...radius)
                    )
                    opacity = 0
                }
            }
    }
}

struct TyreInteractivePoints: View {
    @Binding var selectedDetail: TyreDetail?
    let tyreSize: CGFloat
    
    let details = [
        TyreDetail(id: 1, title: "Battistrada", description: "Profondità: 6mm", angle: 0),
        TyreDetail(id: 2, title: "Pressione", description: "2.4 bar", angle: 90),
        TyreDetail(id: 3, title: "Temperatura", description: "Ottimale", angle: 180),
        TyreDetail(id: 4, title: "Usura", description: "30%", angle: 270)
    ]
    
    var body: some View {
        ForEach(details) { detail in
            InteractivePoint(
                detail: detail,
                isSelected: selectedDetail?.id == detail.id,
                radius: tyreSize * 0.35
            )
            .onTapGesture {
                withAnimation(.spring()) {
                    selectedDetail = selectedDetail?.id == detail.id ? nil : detail
                }
            }
        }
    }
}

struct InteractivePoint: View {
    let detail: TyreDetail
    let isSelected: Bool
    let radius: CGFloat
    @State private var pulse = false
    
    var position: CGPoint {
        let angleInRadians = detail.angle * .pi / 180
        return CGPoint(
            x: CGFloat(cos(angleInRadians)) * radius,
            y: CGFloat(sin(angleInRadians)) * radius
        )
    }
    
    var body: some View {
        ZStack {
            // Pulse effect
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 30, height: 30)
                .scaleEffect(pulse ? 1.5 : 1.0)
                .opacity(pulse ? 0 : 0.6)
            
            // Main point
            Circle()
                .fill(Color.blue)
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .scaleEffect(isSelected ? 1.3 : 1.0)
            
            // Detail popup
            if isSelected {
                VStack(spacing: 2) {
                    Text(detail.title)
                        .font(.customFont(size: 10, weight: .bold))
                        .foregroundColor(.white)
                    Text(detail.description)
                        .font(.customFont(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.8))
                )
                .offset(y: -40)
            }
        }
        .offset(x: position.x, y: position.y)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

struct TyreDetail: Identifiable {
    let id: Int
    let title: String
    let description: String
    let angle: Double
}

struct TyreControlPanel: View {
    @Binding var showWearIndicator: Bool
    let tyre: VehicleTyre
    let selectedDetail: TyreDetail?
    
    var body: some View {
        VStack(spacing: 16) {
            // Wear indicator toggle
            Toggle(isOn: $showWearIndicator) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Mostra indicatore usura")
                        .font(.customFont(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .orange))
            
            // Quick specs
            HStack(spacing: 20) {
                QuickSpec(label: "Larghezza", value: "\(tyre.width ?? 0)mm", color: .blue)
                QuickSpec(label: "Rapporto", value: "\(tyre.ratio ?? 0)%", color: .green)
                QuickSpec(label: "Diametro", value: "R\(tyre.diameter ?? 0)", color: .purple)
            }
            
            // Selected detail info
            if let detail = selectedDetail {
                DetailInfoCard(detail: detail)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.customFieldColor)
        )
    }
}

struct QuickSpec: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.customFont(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            
            Text(value)
                .font(.customFont(size: 14, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

struct DetailInfoCard: View {
    let detail: TyreDetail
    
    var body: some View {
        HStack {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(detail.title)
                    .font(.customFont(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                Text(detail.description)
                    .font(.customFont(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.2))
        )
    }
}

// MARK: - 3. Insurance Health Dashboard

struct InsuranceDashboard: View {
    let insurance: VehicleInsurance
    @State private var animateProgress = false
    @State private var showDetails = false
    @State private var selectedCoverage: Coverage? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                DashboardHeader(insurance: insurance)
                
                // Main circular progress
                CircularProgressView(
                    insurance: insurance,
                    animateProgress: $animateProgress
                )
                
                // Premium tracking
                PremiumTracker(insurance: insurance)
                
                // Coverage grid
                CoverageGrid(
                    insurance: insurance,
                    selectedCoverage: $selectedCoverage
                )
                
                // Selected coverage details
                if let coverage = selectedCoverage {
                    CoverageDetailView(coverage: coverage)
                        .transition(.asymmetric(
                            insertion: .slide.combined(with: .opacity),
                            removal: .slide.combined(with: .opacity)
                        ))
                }
                
                // Action buttons
                ActionButtons(insurance: insurance)
            }
            .padding()
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.3)) {
                animateProgress = true
            }
        }
    }
}

struct DashboardHeader: View {
    let insurance: VehicleInsurance
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Assicurazione")
                    .font(.customFont(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text(insurance.rcaCompany ?? "Compagnia")
                    .font(.customFont(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            StatusBadge(insurance: insurance)
        }
    }
}

struct StatusBadge: View {
    let insurance: VehicleInsurance
    
    var status: InsuranceStatus {
        // Calculate status based on expiry
        if insurance.rcaInsurancePresent == 0 {
            return .inactive
        }
        // Check if expired
        if let expiryDate = insurance.rcaExpiry {
            // Implementation of date check
            return .active // Simplified
        }
        return .inactive
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
            
            Text(status.text)
                .font(.customFont(size: 12, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(status.color.opacity(0.2))
        )
    }
}

struct CircularProgressView: View {
    let insurance: VehicleInsurance
    @Binding var animateProgress: Bool
    @State private var glowAnimation = false
    
    var daysRemaining: Int {
        // Calculate days until expiry
        // This is a simplified implementation
        return 45
    }
    
    var daysRemainingProgress: CGFloat {
        // Calculate progress (0 to 1)
        let totalDays: CGFloat = 365
        return CGFloat(daysRemaining) / totalDays
    }
    
    var progressGradient: [Color] {
        if daysRemaining < 30 {
            return [.red, .orange]
        } else if daysRemaining < 60 {
            return [.orange, .yellow]
        } else {
            return [.green, .mint]
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    .frame(width: 200, height: 200)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: animateProgress ? daysRemainingProgress : 0)
                    .stroke(
                        AngularGradient(
                            colors: progressGradient + [progressGradient.first!],
                            center: .center
                        ),
                        style: StrokeStyle(
                            lineWidth: 20,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: progressGradient.first!.opacity(0.5), radius: 10)
                
                // Glow effect
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: progressGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 220, height: 220)
                    .opacity(glowAnimation ? 0.6 : 0.2)
                    .scaleEffect(glowAnimation ? 1.1 : 1.0)
                
                // Center content
                VStack(spacing: 8) {
                    Text("\(daysRemaining)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("giorni rimanenti")
                        .font(.customFont(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("Scade: \(formatVehicleInfoDate(insurance.rcaExpiry))")
                        .font(.customFont(size: 10, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                // Animated indicator
                Circle()
                    .fill(progressGradient.first!)
                    .frame(width: 10, height: 10)
                    .offset(x: 90 * cos((.pi * 2 * daysRemainingProgress) - .pi/2),
                           y: 90 * sin((.pi * 2 * daysRemainingProgress) - .pi/2))
                    .shadow(color: progressGradient.first!, radius: 5)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowAnimation = true
                }
            }
            
            // Quick stats
            HStack(spacing: 30) {
                QuickStat(
                    icon: "calendar",
                    value: "\(daysRemaining)",
                    label: "Giorni",
                    color: progressGradient.first!
                )
                
                QuickStat(
                    icon: "percent",
                    value: "\(Int(daysRemainingProgress * 100))%",
                    label: "Copertura",
                    color: .blue
                )
                
                QuickStat(
                    icon: "shield.checkered",
                    value: "RCA",
                    label: "Tipo",
                    color: .purple
                )
            }
        }
    }
}

struct QuickStat: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(color)
            
            Text(value)
                .font(.customFont(size: 16, weight: .bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.customFont(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

struct PremiumTracker: View {
    let insurance: VehicleInsurance
    @State private var animateBars = false
    
    // Mock data for premium history
    let monthlyPremiums: [PremiumData] = [
        PremiumData(month: "Gen", amount: 120, isPaid: true),
        PremiumData(month: "Feb", amount: 120, isPaid: true),
        PremiumData(month: "Mar", amount: 120, isPaid: true),
        PremiumData(month: "Apr", amount: 120, isPaid: true),
        PremiumData(month: "Mag", amount: 120, isPaid: true),
        PremiumData(month: "Giu", amount: 120, isPaid: false)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Tracker Premi")
                    .font(.customFont(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("€720 / anno")
                    .font(.customFont(size: 14, weight: .medium))
                    .foregroundColor(.green)
            }
            
            // Premium bars
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(monthlyPremiums.enumerated()), id: \.offset) { index, premium in
                    PremiumBar(
                        premium: premium,
                        maxAmount: 150,
                        animate: animateBars,
                        delay: Double(index) * 0.1
                    )
                }
            }
            .frame(height: 100)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5)) {
                    animateBars = true
                }
            }
            
            // Legend
            HStack(spacing: 20) {
                LegendItem(color: .green, label: "Pagato")
                LegendItem(color: .orange, label: "In attesa")
                LegendItem(color: .red, label: "Scaduto")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct PremiumData {
    let month: String
    let amount: Double
    let isPaid: Bool
}

struct PremiumBar: View {
    let premium: PremiumData
    let maxAmount: Double
    let animate: Bool
    let delay: Double
    
    var barHeight: CGFloat {
        CGFloat(premium.amount / maxAmount) * 100
    }
    
    var barColor: Color {
        premium.isPaid ? .green : .orange
    }
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 40, height: 100)
                
                // Animated bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [barColor, barColor.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 40, height: animate ? barHeight : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(delay), value: animate)
                
                // Amount label
                Text("€\(Int(premium.amount))")
                    .font(.customFont(size: 8, weight: .medium))
                    .foregroundColor(.white)
                    .opacity(animate ? 1 : 0)
                    .animation(.easeIn.delay(delay + 0.3), value: animate)
                    .offset(y: -barHeight - 5)
            }
            
            Text(premium.month)
                .font(.customFont(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(label)
                .font(.customFont(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

struct CoverageGrid: View {
    let insurance: VehicleInsurance
    @Binding var selectedCoverage: Coverage?
    
    let coverages = [
        Coverage(id: 1, name: "RCA", icon: "car.fill", isActive: true, description: "Responsabilità Civile Auto"),
        Coverage(id: 2, name: "Furto", icon: "lock.shield.fill", isActive: true, description: "Protezione furto totale"),
        Coverage(id: 3, name: "Incendio", icon: "flame.fill", isActive: true, description: "Danni da incendio"),
        Coverage(id: 4, name: "Cristalli", icon: "square.stack.3d.up.fill", isActive: false, description: "Rottura cristalli"),
        Coverage(id: 5, name: "Kasko", icon: "shield.fill", isActive: false, description: "Copertura completa"),
        Coverage(id: 6, name: "Assistenza", icon: "wrench.and.screwdriver.fill", isActive: true, description: "Assistenza stradale 24/7")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Coperture")
                .font(.customFont(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(coverages) { coverage in
                    CoverageCard(
                        coverage: coverage,
                        isSelected: selectedCoverage?.id == coverage.id
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedCoverage = selectedCoverage?.id == coverage.id ? nil : coverage
                        }
                    }
                }
            }
        }
    }
}

struct Coverage: Identifiable {
    let id: Int
    let name: String
    let icon: String
    let isActive: Bool
    let description: String
}

struct CoverageCard: View {
    let coverage: Coverage
    let isSelected: Bool
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        coverage.isActive
                            ? LinearGradient(
                                colors: [Color.green.opacity(0.3), Color.green.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: coverage.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(coverage.isActive ? .green : .gray)
                    .scaleEffect(isSelected ? 1.2 : 1.0)
            }
            .overlay(
                Circle()
                    .stroke(
                        coverage.isActive ? Color.green : Color.gray,
                        lineWidth: isSelected ? 3 : 1
                    )
                    .frame(width: 60, height: 60)
            )
            
            Text(coverage.name)
                .font(.customFont(size: 12, weight: .medium))
                .foregroundColor(.white)
            
            Circle()
                .fill(coverage.isActive ? Color.green : Color.gray)
                .frame(width: 6, height: 6)
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
}

struct CoverageDetailView: View {
    let coverage: Coverage
    @State private var appear = false
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: coverage.icon)
                .font(.system(size: 30, weight: .medium))
                .foregroundColor(coverage.isActive ? .green : .gray)
                .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(coverage.name)
                    .font(.customFont(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(coverage.description)
                    .font(.customFont(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Text(coverage.isActive ? "Attiva" : "Non attiva")
                .font(.customFont(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(coverage.isActive ? Color.green.opacity(0.3) : Color.gray.opacity(0.3))
                )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(coverage.isActive ? Color.green.opacity(0.3) : Color.gray.opacity(0.3), lineWidth: 1)
                )
        )
        .scaleEffect(appear ? 1 : 0.9)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appear = true
            }
        }
    }
}

struct ActionButtons: View {
    let insurance: VehicleInsurance
    
    var body: some View {
        HStack(spacing: 16) {
            ActionButton(
                title: "Rinnova",
                icon: "arrow.clockwise",
                color: .green,
                action: { /* Handle renewal */ }
            )
            
            ActionButton(
                title: "Documenti",
                icon: "doc.text.fill",
                color: .blue,
                action: { /* Show documents */ }
            )
            
            ActionButton(
                title: "Contatta",
                icon: "phone.fill",
                color: .purple,
                action: { /* Contact insurance */ }
            )
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.customFont(size: 12, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .shadow(color: color.opacity(0.3), radius: isPressed ? 5 : 10)
        }
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Helper function
fileprivate func formatVehicleInfoDate(_ dateString: String?) -> String {
    guard let rawDate = dateString?.trimmingCharacters(in: .whitespacesAndNewlines), !rawDate.isEmpty else {
        return "N/A"
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")

    let outputFormatter = DateFormatter()
    outputFormatter.dateFormat = "d MMMM yyyy"
    outputFormatter.locale = Locale(identifier: "it_IT")

    let inputFormats = [
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
        "yyyy-MM-dd"
    ]

    for format in inputFormats {
        formatter.dateFormat = format
        if let date = formatter.date(from: rawDate) {
            return outputFormatter.string(from: date)
        }
    }

    return rawDate
}
