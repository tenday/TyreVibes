//
//  LiDARTreadMeasurementView.swift
//  TyreVibes
//
//  Created by AI Assistant on 17/11/2025.
//

import SwiftUI
import RealityKit
import ARKit

// MARK: - LiDAR Tread Measurement View

struct LiDARTreadMeasurementView: View {
    // MARK: - Properties

    @StateObject private var viewModel: TreadDepthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showSettings = false
    @State private var showHistory = false
    @State private var showResults = false
    @State private var didNotifyCompletion = false

    let onCompleted: (() -> Void)?

    init(onCompleted: (() -> Void)? = nil) {
        self.onCompleted = onCompleted
        _viewModel = StateObject(wrappedValue: TreadDepthViewModel())
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // AR View (background)
            if viewModel.isLiDARAvailable {
                LiDARARViewContainer(viewModel: viewModel)
                    .edgesIgnoringSafeArea(.all)
            } else {
                unavailableView
            }

            // Overlay UI
            VStack {
                // Top Bar
                topBar

                Spacer()

                // Status & Controls
                VStack(spacing: 20) {
                    // Status message
                    statusCard

                    // Progress indicator (durante scansione)
                    if viewModel.isScanning {
                        scanProgressView
                    }

                    // Control buttons
                    controlButtons
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showSettings) {
            LiDARSettingsView(configuration: $viewModel.scanConfiguration)
        }
        .sheet(isPresented: $showHistory) {
            MeasurementHistoryView(
                measurements: viewModel.measurementHistory,
                onDelete: { measurement in
                    viewModel.deleteMeasurement(measurement)
                }
            )
        }
        .sheet(isPresented: $showResults) {
            if let measurement = viewModel.lastMeasurement {
                MeasurementResultView(
                    measurement: measurement,
                    history: viewModel.measurementHistory,
                    tyreQualityPrediction: viewModel.tyreQualityPrediction
                )
            }
        }
        .alert("Errore", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "Errore sconosciuto")
        }
        .onChange(of: viewModel.measurementState) { _, newState in
            if newState == .completed {
                showResults = true
                if !didNotifyCompletion {
                    didNotifyCompletion = true
                    onCompleted?()
                }
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Close button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4)
            }

            Spacer()

            // State indicator
            HStack(spacing: 8) {
                Image(systemName: viewModel.measurementState.icon)
                    .foregroundColor(.white)
                Text(viewModel.measurementState.displayName)
                    .font(.customFont(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(stateColor.opacity(0.8))
            )
            .shadow(color: .black.opacity(0.3), radius: 4)

            Spacer()

            // Settings button
            Button(action: { showSettings = true }) {
                Image(systemName: "gear")
                    .font(.title2)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 50)
    }

    private var stateColor: Color {
        switch viewModel.measurementState {
        case .idle, .unavailable:
            return .gray
        case .scanning:
            return .blue
        case .processing:
            return .orange
        case .completed:
            return .green
        case .error:
            return .red
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: 12) {
            // Icon
            Image(systemName: "ruler")
                .font(.system(size: 32))
                .foregroundColor(.customSandyBrown)

            // Status message
            Text(viewModel.statusMessage)
                .font(.customFont(size: 16, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)

            // Point count (durante scansione)
            if viewModel.isScanning {
                Text("\(viewModel.pointCount) punti acquisiti")
                    .font(.customFont(size: 14, weight: .regular))
                    .foregroundColor(.gray)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.customBackgroundColor)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
    }

    // MARK: - Scan Progress

    private var scanProgressView: some View {
        VStack(spacing: 12) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))

                    // Progress
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.customSandyBrown, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(viewModel.scanProgress))
                }
            }
            .frame(height: 8)

            // Progress percentage
            Text("\(Int(viewModel.scanProgress * 100))%")
                .font(.customFont(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        HStack(spacing: 16) {
            // History button
            Button(action: { showHistory = true }) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("Storico")
                        .font(.customFont(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.customFieldColor)
                )
                .foregroundColor(.white)
            }
            .disabled(viewModel.isScanning || viewModel.isProcessing)

            // Main action button
            mainActionButton
        }
    }

    private var mainActionButton: some View {
        Button(action: {
            Task {
                if viewModel.isScanning {
                    await viewModel.stopMeasurement()
                } else {
                    viewModel.startMeasurement()
                }
            }
        }) {
            HStack {
                Image(systemName: buttonIcon)
                    .font(.title3)
                Text(buttonTitle)
                    .font(.customFont(size: 16, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: buttonGradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .disabled(viewModel.isProcessing || !viewModel.isLiDARAvailable)
    }

    private var buttonTitle: String {
        if viewModel.isProcessing {
            return "Elaborazione..."
        } else if viewModel.isScanning {
            return "Completa Scansione"
        } else {
            return "Inizia Misurazione"
        }
    }

    private var buttonIcon: String {
        if viewModel.isProcessing {
            return "hourglass"
        } else if viewModel.isScanning {
            return "stop.circle.fill"
        } else {
            return "play.circle.fill"
        }
    }

    private var buttonGradient: [Color] {
        if viewModel.isScanning {
            return [.orange, .red]
        } else {
            return [.customSandyBrown, .blue]
        }
    }

    // MARK: - Unavailable View

    private var unavailableView: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "iphone.slash")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.orange.opacity(0.9))

                        Text("LiDAR Non Disponibile")
                            .font(.customFont(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Text("Questa funzionalità richiede un dispositivo con sensore LiDAR (iPhone 12 Pro o successivo)")
                        .font(.customFont(size: 15, weight: .regular))
                        .foregroundColor(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .frame(maxWidth: 560)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.customFieldColor.opacity(0.92))
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            )

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 96)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.customBackgroundColor)
    }
}

// MARK: - AR View Container

struct LiDARARViewContainer: UIViewRepresentable {
    let viewModel: TreadDepthViewModel
    private let service = LiDARTreadMeasurementService.shared

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Setup AR session
        do {
            try service.setupARSession(arView)
        } catch {
            print("❌ [ARViewContainer] Setup fallito: \(error)")
        }

        // Aggiungi coaching overlay per guidare l'utente
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coachingOverlay.session = arView.session
        coachingOverlay.goal = .anyPlane
        arView.addSubview(coachingOverlay)

        // Setup frame update delegate
        context.coordinator.arView = arView
        context.coordinator.startFrameUpdates()

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Update se necessario
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject {
        let viewModel: TreadDepthViewModel
        weak var arView: ARView?
        private var frameUpdateTimer: Timer?

        init(viewModel: TreadDepthViewModel) {
            self.viewModel = viewModel
            super.init()
        }

        func startFrameUpdates() {
            // Update frame ogni 100ms durante scansione
            frameUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self,
                      let frame = self.arView?.session.currentFrame else {
                    return
                }

                Task { @MainActor [viewModel = self.viewModel] in
                    guard viewModel.isScanning else { return }
                    LiDARTreadMeasurementService.shared.captureFrame(frame)
                }
            }
        }

        deinit {
            frameUpdateTimer?.invalidate()
        }
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        LiDARTreadMeasurementService.shared.stopARSession()
    }
}

// MARK: - Settings View

struct LiDARSettingsView: View {
    @Binding var configuration: LiDARTreadMeasurementService.ScanConfiguration
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Durata Scansione") {
                    HStack {
                        Text("Minima")
                        Spacer()
                        Text("\(Int(configuration.minScanDuration))s")
                            .foregroundColor(.gray)
                    }
                    Slider(
                        value: $configuration.minScanDuration,
                        in: 1...10,
                        step: 1
                    )

                    HStack {
                        Text("Massima")
                        Spacer()
                        Text("\(Int(configuration.maxScanDuration))s")
                            .foregroundColor(.gray)
                    }
                    Slider(
                        value: $configuration.maxScanDuration,
                        in: 5...30,
                        step: 5
                    )
                }

                Section("Qualità") {
                    HStack {
                        Text("Punti Minimi")
                        Spacer()
                        Text("\(configuration.minPointCount)")
                            .foregroundColor(.gray)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(configuration.minPointCount) },
                            set: { configuration.minPointCount = Int($0) }
                        ),
                        in: 500...5000,
                        step: 500
                    )

                    HStack {
                        Text("Confidenza Minima")
                        Spacer()
                        Text("\(Int(configuration.minConfidence * 100))%")
                            .foregroundColor(.gray)
                    }
                    Slider(
                        value: $configuration.minConfidence,
                        in: 0.3...1.0,
                        step: 0.1
                    )
                }

                Section("Elaborazione") {
                    Toggle("Filtro Kalman", isOn: $configuration.enableKalmanFilter)
                    Toggle("RANSAC", isOn: $configuration.enableRANSAC)
                    Toggle("Rimozione Outliers", isOn: $configuration.enableOutlierRemoval)
                }

                Section {
                    Button("Ripristina Default") {
                        configuration = .default
                    }
                }
            }
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fine") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Measurement Result View

struct MeasurementResultView: View {
    let measurement: TreadDepthMeasurement
    let history: [TreadDepthMeasurement]
    let tyreQualityPrediction: TyreQualityPrediction?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Status indicator
                    statusSection

                    if let tyreQualityPrediction {
                        qualitySection(tyreQualityPrediction)
                    }

                    // Profondità media
                    depthSection

                    // Insight consumo
                    insightSection

                    // Zone map
                    zoneMapSection

                    // Metadata
                    metadataSection

                    // Actions
                    actionButtons
                }
                .padding(20)
            }
            .background(Color.customBackgroundColor)
            .navigationTitle("Risultati Misurazione")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var statusSection: some View {
        VStack(spacing: 12) {
            Image(systemName: measurement.treadStatus.icon)
                .font(.system(size: 64))
                .foregroundColor(statusColor)

            Text(measurement.treadStatus.displayName)
                .font(.customFont(size: 24, weight: .bold))
                .foregroundColor(statusColor)

            Text("Confidenza: \(Int(measurement.confidenceScore))%")
                .font(.customFont(size: 14, weight: .regular))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.customFieldColor)
        )
    }

    private var statusColor: Color {
        switch measurement.treadStatus.color {
        case "green": return .green
        case "blue": return .blue
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }

    private func qualitySection(_ prediction: TyreQualityPrediction) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: prediction.isDefective ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                    .font(.system(size: 28))
                    .foregroundColor(prediction.isDefective ? .orange : .green)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Analisi visiva")
                        .font(.customFont(size: 14, weight: .regular))
                        .foregroundColor(.gray)

                    Text(prediction.displayName)
                        .font(.customFont(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                Text("\(prediction.confidencePercentage)%")
                    .font(.customFont(size: 18, weight: .bold))
                    .foregroundColor(prediction.isDefective ? .orange : .green)
            }

            if let good = prediction.probabilities["good"],
               let defective = prediction.probabilities["defective"] {
                HStack {
                    Text("OK \(Int((good * 100).rounded()))%")
                    Spacer()
                    Text("Difetto \(Int((defective * 100).rounded()))%")
                }
                .font(.customFont(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.75))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.customFieldColor)
        )
    }

    private var depthSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Profondità Battistrada")
                .font(.customFont(size: 18, weight: .bold))

            HStack(spacing: 20) {
                LiDARStatCard(
                    title: "Media",
                    value: String(format: "%.2f mm", measurement.averageDepth),
                    color: .blue
                )

                LiDARStatCard(
                    title: "Min",
                    value: String(format: "%.2f mm", measurement.minDepth),
                    color: .orange
                )

                LiDARStatCard(
                    title: "Max",
                    value: String(format: "%.2f mm", measurement.maxDepth),
                    color: .green
                )
            }

            HStack {
                Text("Deviazione Standard:")
                    .font(.customFont(size: 14, weight: .regular))
                Spacer()
                Text(String(format: "%.2f mm", measurement.standardDeviation))
                    .font(.customFont(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
        }
    }

    private var insightSection: some View {
        let insight = buildInsight()
        return VStack(alignment: .leading, spacing: 10) {
            Text(insight.primary)
                .font(.customFont(size: 16, weight: .semibold))
                .foregroundColor(.white)

            if let secondary = insight.secondary {
                Text(secondary)
                    .font(.customFont(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.75))
            }

            if insight.showCTA {
                Text("Vuoi sapere quando dovrai cambiarle, non solo quanto manca?")
                    .font(.customFont(size: 14, weight: .semibold))
                    .foregroundColor(Color.customBitterSweet)
                    .padding(.top, 6)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.customFieldColor)
        )
    }

    private var zoneMapSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mappa Zone")
                .font(.customFont(size: 18, weight: .bold))

            VStack(spacing: 8) {
                ForEach(Array(measurement.depthMap.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { zone in
                    if let depth = measurement.depthMap[zone] {
                        ZoneRow(zone: zone, depth: depth)
                    }
                }
            }
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Informazioni Scansione")
                .font(.customFont(size: 18, weight: .bold))

            LiDARMetadataRow(label: "Punti Campionati", value: "\(measurement.samplePoints)")
            LiDARMetadataRow(label: "Durata", value: String(format: "%.1fs", measurement.metadata.scanDuration))
            LiDARMetadataRow(label: "Distanza Media", value: String(format: "%.1f cm", measurement.metadata.averageDistance))
            LiDARMetadataRow(label: "Qualità Mesh", value: measurement.metadata.meshQuality.displayName)
            LiDARMetadataRow(label: "Illuminazione", value: measurement.metadata.lightingConditions.displayName)
            LiDARMetadataRow(label: "Data", value: formatDate(measurement.timestamp))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.customFieldColor)
        )
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                                // TODO: Salva su Supabase
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("Salva Misurazione")
                        .font(.customFont(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.customSandyBrown)
                )
                .foregroundColor(.white)
            }

            Button(action: {
                // TODO: Condividi
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Condividi")
                        .font(.customFont(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.customFieldColor)
                )
                .foregroundColor(.white)
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }

    private func buildInsight() -> (primary: String, secondary: String?, showCTA: Bool) {
        let primary = "Sei a \(formatMm(measurement.averageDepth)) mm."
        guard let comparison = comparisonMeasurement() else {
            return (primary, nil, false)
        }

        let days = daysBetween(start: comparison.timestamp, end: measurement.timestamp)
        let delta = measurement.averageDepth - comparison.averageDepth
        let deltaText = formatDelta(delta)
        let secondary = "Negli ultimi \(days) giorni: \(deltaText) mm."
        return (primary, secondary, true)
    }

    private func comparisonMeasurement() -> TreadDepthMeasurement? {
        let minimumDays = 30
        let cutoff = Calendar.current.date(byAdding: .day, value: -minimumDays, to: measurement.timestamp) ?? measurement.timestamp
        let candidates = history.filter { $0.id != measurement.id && $0.timestamp <= cutoff }
        return candidates.sorted { $0.timestamp > $1.timestamp }.first
    }

    private func daysBetween(start: Date, end: Date) -> Int {
        let components = Calendar.current.dateComponents([.day], from: start, to: end)
        return max(1, components.day ?? 0)
    }

    private func formatDelta(_ delta: Double) -> String {
        let sign = delta >= 0 ? "+" : "-"
        return "\(sign)\(formatMm(abs(delta)))"
    }

    private func formatMm(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }
}

// MARK: - Measurement History View

struct MeasurementHistoryView: View {
    let measurements: [TreadDepthMeasurement]
    let onDelete: (TreadDepthMeasurement) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMeasurement: TreadDepthMeasurement?

    var body: some View {
        NavigationStack {
            if measurements.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(measurements) { measurement in
                        Button(action: {
                            selectedMeasurement = measurement
                        }) {
                            MeasurementHistoryRow(measurement: measurement)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                onDelete(measurement)
                            } label: {
                                Label("Elimina", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Storico Misurazioni")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Chiudi") {
                    dismiss()
                }
            }
        }
        .sheet(item: $selectedMeasurement) { measurement in
            MeasurementResultView(
                measurement: measurement,
                history: measurements,
                tyreQualityPrediction: nil
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("Nessuna Misurazione")
                .font(.customFont(size: 18, weight: .semibold))

            Text("Le tue misurazioni appariranno qui")
                .font(.customFont(size: 14, weight: .regular))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Supporting Views

struct LiDARStatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.customFont(size: 12, weight: .regular))
                .foregroundColor(.gray)

            Text(value)
                .font(.customFont(size: 16, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.customFieldColor)
        )
    }
}

struct ZoneRow: View {
    let zone: TreadZone
    let depth: Double

    var body: some View {
        HStack {
            Text(zone.displayName)
                .font(.customFont(size: 14, weight: .regular))

            Spacer()

            Text(String(format: "%.2f mm", depth))
                .font(.customFont(size: 14, weight: .semibold))
                .foregroundColor(depthColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.customFieldColor.opacity(0.5))
        )
    }

    private var depthColor: Color {
        switch depth {
        case 6...: return .green
        case 4..<6: return .blue
        case 2..<4: return .yellow
        case 1.6..<2: return .orange
        default: return .red
        }
    }
}

struct LiDARMetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.customFont(size: 14, weight: .regular))
                .foregroundColor(.gray)

            Spacer()

            Text(value)
                .font(.customFont(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

struct MeasurementHistoryRow: View {
    let measurement: TreadDepthMeasurement

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: measurement.treadStatus.icon)
                .font(.title2)
                .foregroundColor(statusColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "%.2f mm", measurement.averageDepth))
                    .font(.customFont(size: 16, weight: .semibold))

                Text(formatDate(measurement.timestamp))
                    .font(.customFont(size: 12, weight: .regular))
                    .foregroundColor(.gray)
            }

            Spacer()

            Text(measurement.treadStatus.displayName)
                .font(.customFont(size: 12, weight: .medium))
                .foregroundColor(statusColor)
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch measurement.treadStatus.color {
        case "green": return .green
        case "blue": return .blue
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    LiDARTreadMeasurementView()
}
