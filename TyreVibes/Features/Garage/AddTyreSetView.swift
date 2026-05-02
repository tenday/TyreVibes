import SwiftUI

struct AddTyreSetView: View {
    let vehicleId: Int
    let vehicleTyres: [VehicleTyre]
    @ObservedObject var tyreViewModel: TyreViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum TyreSetType: String, CaseIterable, Identifiable {
        case frontRear = "Anteriore/Posteriore"
        case summer = "Set Estivo"
        case winter = "Set Invernale"
        case track = "Set Pista"
        case custom = "Personalizzato"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .frontRear: return "car.side.fill"
            case .summer: return "sun.max.fill"
            case .winter: return "snowflake"
            case .track: return "flag.checkered"
            case .custom: return "pencil.circle.fill"
            }
        }

        var description: String {
            switch self {
            case .frontRear:
                return "Per veicoli con misure diverse davanti e dietro"
            case .summer:
                return "Pneumatici estivi ad alte prestazioni"
            case .winter:
                return "Pneumatici invernali per sicurezza"
            case .track:
                return "Pneumatici specifici per uso in pista"
            case .custom:
                return "Configura un set personalizzato"
            }
        }
    }

    private enum ScanPosition: Hashable {
        case front
        case rear

        var label: String {
            switch self {
            case .front:
                return "Pneumatico anteriore"
            case .rear:
                return "Pneumatico posteriore"
            }
        }

        var instructions: String {
            switch self {
            case .front:
                return "Posiziona lo smartphone davanti al pneumatico anteriore e inquadra la spalla per estrarre i dati con l’OCR."
            case .rear:
                return "Ripeti la scansione per il pneumatico posteriore per registrare la misura differenziata."
            }
        }
    }

    private struct RecommendedTyreSet: Identifiable {
        let id: Int
        let name: String
        let category: TyreSetCategory
        let tyres: [VehicleTyre]
    }

    private struct RecommendedTyreGroup: Identifiable {
        let category: TyreSetCategory
        let sets: [RecommendedTyreSet]

        var id: String { category.id }
    }

    private enum TyreSetCategory: String, CaseIterable, Identifiable {
        case summer
        case winter
        case allSeason
        case track
        case standard

        var id: String { rawValue }

        var title: String {
            switch self {
            case .summer: return "Estivi"
            case .winter: return "Invernali"
            case .allSeason: return "Quattro stagioni"
            case .track: return "Pista"
            case .standard: return "Standard"
            }
        }

        var icon: String {
            switch self {
            case .summer: return "sun.max.fill"
            case .winter: return "snowflake"
            case .allSeason: return "cloud.sun.fill"
            case .track: return "flag.checkered"
            case .standard: return "circle.grid.2x2.fill"
            }
        }

        var sortOrder: Int {
            switch self {
            case .summer: return 0
            case .winter: return 1
            case .allSeason: return 2
            case .track: return 3
            case .standard: return 4
            }
        }

        static func infer(from values: [String]) -> TyreSetCategory {
            for rawValue in values {
                let value = rawValue.lowercased()
                if value.contains("winter") || value.contains("invern") || value.contains("snow") {
                    return .winter
                }
                if value.contains("summer") || value.contains("estiv") || value.contains("estate") {
                    return .summer
                }
                if value.contains("all season") || value.contains("all-season") || value.contains("4 stag") || value.contains("quattro stag") {
                    return .allSeason
                }
                if value.contains("track") || value.contains("pista") || value.contains("racing") {
                    return .track
                }
            }

            return .standard
        }
    }

    @State private var setType: TyreSetType = .frontRear
    @State private var setName: String = ""
    @State private var includeRearTyre: Bool = true
    @State private var isPresentingScanner = false
    @State private var pendingPositions: [ScanPosition] = []
    @State private var currentPosition: ScanPosition?
    @State private var didCompleteCurrentScan = false
    @State private var completedPositions: [ScanPosition] = []
    @State private var contentAppeared = false

    private var needsDoubleScan: Bool {
        setType == .frontRear || includeRearTyre
    }

    private var requiredPositions: [ScanPosition] {
        needsDoubleScan ? [.front, .rear] : [.front]
    }

    private var totalSteps: Int {
        requiredPositions.count
    }

    private var isScanFlowInProgress: Bool {
        currentPosition != nil || !pendingPositions.isEmpty || !completedPositions.isEmpty
    }

    private var isScanFlowComplete: Bool {
        !completedPositions.isEmpty && completedPositions.count == totalSteps && pendingPositions.isEmpty && currentPosition == nil
    }

    private var startButtonTitle: String {
        if isScanFlowComplete {
            return "Completa"
        }

        if !pendingPositions.isEmpty {
            return "Continua scansione"
        }

        return needsDoubleScan ? "Avvia doppia scansione" : "Avvia scansione"
    }

    private var scanContext: String? {
        guard let currentPosition else { return nil }
        let stepIndex = min(completedPositions.count + 1, totalSteps)
        var components: [String] = ["Passaggio \(stepIndex) di \(totalSteps)"]

        if setType == .custom, isCustomNameValid {
            components.append(setName.trimmingCharacters(in: .whitespacesAndNewlines))
        } else if setType != .custom {
            components.append(setType.rawValue)
        }

        components.append(currentPosition.label)

        return components.joined(separator: " • ")
    }

    private var activeSetName: String? {
        let trimmed = setName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var activeSetPosition: String? {
        guard let currentPosition else { return nil }
        switch currentPosition {
        case .front:
            return "front"
        case .rear:
            return "rear"
        }
    }

    private var recommendedSetGroups: [RecommendedTyreGroup] {
        let grouped = Dictionary(grouping: recommendedSets) { $0.category }

        return grouped
            .map { category, sets in
                RecommendedTyreGroup(
                    category: category,
                    sets: sets.sorted { $0.name < $1.name }
                )
            }
            .sorted { $0.category.sortOrder < $1.category.sortOrder }
    }

    private var recommendedSets: [RecommendedTyreSet] {
        guard !vehicleTyres.isEmpty else { return [] }

        var grouped: [Int: [VehicleTyre]] = [:]
        var fallbackId = 1

        for tyre in vehicleTyres {
            let key: Int
            if let setId = tyre.setId {
                key = setId
            } else {
                key = -fallbackId
                fallbackId += 1
            }
            grouped[key, default: []].append(tyre)
        }

        let sets = grouped.map { (key, tyres) -> RecommendedTyreSet in
            let sortedTyres = tyres.sorted { ($0.setName ?? "") < ($1.setName ?? "") }
            let name = displayName(for: tyres, fallbackKey: key)
            let category = tyreSetCategory(for: tyres, setName: name)
            return RecommendedTyreSet(id: key, name: name, category: category, tyres: sortedTyres)
        }

        return sets.sorted { $0.name < $1.name }
    }

    private func tyreSetCategory(for tyres: [VehicleTyre], setName: String) -> TyreSetCategory {
        let values = tyres.compactMap(\.season) + tyres.compactMap(\.setName) + [setName]
        return TyreSetCategory.infer(from: values)
    }

    private func displayName(for tyres: [VehicleTyre], fallbackKey: Int) -> String {
        if let name = cleanDisplayName(tyres.first?.setName) {
            return name
        }

        switch fallbackKey {
        case 1:
            return "Misura anteriore"
        case 2:
            return "Misura posteriore"
        default:
            return tyres.count > 1 ? "Misure registrate" : "Misura registrata"
        }
    }

    private func cleanDisplayName(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }

        if trimmed.range(of: #"^Set\s+\d+$"#, options: .regularExpression) != nil {
            return nil
        }

        return trimmed
    }

    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("Nuovo set pneumatici")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
        }
        .onChange(of: setType) { _, newValue in
            switch newValue {
            case .frontRear:
                includeRearTyre = true
                setName = newValue.rawValue
            case .custom:
                includeRearTyre = false
                setName = ""
            default:
                includeRearTyre = false
                setName = newValue.rawValue
            }
        }
        .fullScreenCover(isPresented: $isPresentingScanner, onDismiss: handleScannerDismiss) {
            TyreRegistrationView(
                onConfirmCompletion: {
                    didCompleteCurrentScan = true
                    isPresentingScanner = false
                },
                vehicleid: vehicleId,
                scanContext: scanContext,
                setName: activeSetName,
                setPosition: activeSetPosition
            )
        }
    }

    private var mainContent: some View {
        ZStack {
            Color.customBackgroundColor.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    if !recommendedSetGroups.isEmpty {
                        suggestedSetsSection
                    }

                    typeSelectionSection

                    if setType == .custom {
                        customNameSection
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if setType != .frontRear {
                        doubleMeasureToggle
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    stepsSection
                    startButton
                }
                .padding(.bottom, 24)
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared || reduceMotion ? 0 : 16)
                .animation(reduceMotion ? nil : AppMotion.smooth, value: contentAppeared)
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : AppMotion.smooth) {
                contentAppeared = true
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Registra il tuo set con l’OCR")
                .font(.customFont(size: 28, weight: .bold))
                .foregroundColor(.white)

            Text("Utilizzeremo la scansione per registrare automaticamente le misure dei pneumatici. Se selezioni una doppia misura verrà richiesta una seconda scansione.")
                .font(.customFont(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private var suggestedSetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Set registrati per tipologia")
                .font(.customFont(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)

            ForEach(recommendedSetGroups) { group in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: group.category.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.orange)

                        Text(group.category.title)
                            .font(.customFont(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))

                        Text("\(group.sets.count)")
                            .font(.customFont(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.65))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.08), in: Capsule())
                    }
                    .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(group.sets) { set in
                                recommendedSetCard(for: set)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }

    private func recommendedSetCard(for set: RecommendedTyreSet) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(set.name)
                    .font(.customFont(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "info.circle")
                    .foregroundColor(.white.opacity(0.45))
            }

            ForEach(Array(set.tyres.prefix(2).enumerated()), id: \.element.id) { index, tyre in
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendedTyreLabel(for: tyre, index: index, in: set))
                        .font(.customFont(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))

                    Text(formattedSize(from: tyre))
                        .font(.customFont(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(16)
        .frame(width: 220, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func recommendedTyreLabel(for tyre: VehicleTyre, index: Int, in set: RecommendedTyreSet) -> String {
        if let name = cleanDisplayName(tyre.setName), name != set.name {
            return name
        }

        guard set.tyres.count > 1 else {
            return "Misura registrata"
        }

        return index == 0 ? "Anteriore" : "Posteriore"
    }

    private func formattedSize(from tyre: VehicleTyre) -> String {
        let width = tyre.width.map { "\($0)" } ?? "-"
        let ratio = tyre.ratio.map { "\($0)" } ?? "-"
        let diameter = tyre.diameter.map { "\($0)" } ?? "-"
        let speed = tyre.speedIndex ?? "-"
        let load = tyre.loadIndex ?? "-"

        return "\(width)/\(ratio) R\(diameter) \(load)\(speed)"
    }

    private var typeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tipo di set")
                .font(.customFont(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)

            ForEach(TyreSetType.allCases) { type in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        setType = type
                        if type == .frontRear {
                            includeRearTyre = true
                        }
                    }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: type.icon)
                            .font(.system(size: 24, weight: .medium))
                        .foregroundColor(setType == type ? .orange : .white.opacity(0.6))
                        .frame(width: 40, height: 40)
                        .scaleEffect(setType == type && !reduceMotion ? 1.06 : 1.0)
                        .background(
                            Circle()
                                .fill(setType == type ? Color.orange.opacity(0.2) : Color.white.opacity(0.1))
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(type.rawValue)
                                .font(.customFont(size: 15, weight: .semibold))
                                .foregroundColor(.white)

                            Text(type.description)
                                .font(.customFont(size: 12, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(2)
                        }

                        Spacer()

                        Image(systemName: setType == type ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24, weight: setType == type ? .semibold : .regular))
                            .foregroundColor(setType == type ? .orange : .white.opacity(0.3))
                            .scaleEffect(setType == type && !reduceMotion ? 1.08 : 1.0)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(setType == type ? Color.orange.opacity(0.15) : Color.customFieldColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(setType == type ? Color.orange.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .pressScaleButtonStyle(scale: 0.98)
                .padding(.horizontal, 20)
            }
        }
        .animation(reduceMotion ? nil : AppMotion.smooth, value: setType)
    }

    private var doubleMeasureToggle: some View {
        Toggle(isOn: $includeRearTyre.animation(.spring(response: 0.3, dampingFraction: 0.8))) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Misura posteriore differenziata")
                    .font(.customFont(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Text("Attiva se vuoi registrare una seconda scansione per il set posteriore.")
                    .font(.customFont(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 20)
        .tint(.orange)
    }

    private var customNameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nome del set")
                .font(.customFont(size: 16, weight: .semibold))
                .foregroundColor(.white)

            TextField("Es. Set Neve", text: $setName)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.customFont(size: 15, weight: .medium))
                .foregroundColor(.white)
                .padding(14)
                .background(Color.customFieldColor)
                .cornerRadius(10)
        }
        .padding(.horizontal, 20)
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sequenza scansione")
                .font(.customFont(size: 16, weight: .semibold))
                .foregroundColor(.white)

            ForEach(Array(requiredPositions.enumerated()), id: \.offset) { index, position in
                scanStepRow(for: position, index: index)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }

            Text(needsDoubleScan ? "Al termine della prima scansione ti chiederemo automaticamente di ripetere la procedura per il posteriore." : "Effettua una singola scansione OCR per registrare il set.")
                .font(.customFont(size: 12, weight: .regular))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.customFieldColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .animation(reduceMotion ? nil : AppMotion.smooth, value: requiredPositions.count)
        .animation(reduceMotion ? nil : AppMotion.smooth, value: completedPositions)
    }

    private func scanStepRow(for position: ScanPosition, index: Int) -> some View {
        let isCompleted = completedPositions.contains(position)
        let isNext = !isCompleted && currentPosition == nil && pendingPositions.first == position

        return HStack(spacing: 14) {
            stepBadge(number: index + 1, isCompleted: isCompleted, isActive: isNext)

            VStack(alignment: .leading, spacing: 4) {
                Text(position.label)
                    .font(.customFont(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Text(position.instructions)
                    .font(.customFont(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 20, weight: .semibold))
                    .transition(.scale.combined(with: .opacity))
            } else if currentPosition == position && isPresentingScanner {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .transition(.opacity)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(isNext ? Color.orange.opacity(0.12) : Color.customFieldColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isNext ? Color.orange.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .animation(reduceMotion ? nil : AppMotion.smooth, value: isCompleted)
    }

    private func stepBadge(number: Int, isCompleted: Bool, isActive: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isCompleted ? Color.green.opacity(0.2) : Color.orange.opacity(0.15))
                .frame(width: 40, height: 40)

            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.green)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text("\(number)")
                    .font(.customFont(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .transition(.scale.combined(with: .opacity))
            }

            if isActive && !reduceMotion {
                Circle()
                    .stroke(Color.orange.opacity(0.45), lineWidth: 2)
                    .frame(width: 42, height: 42)
            }
        }
        .animation(reduceMotion ? nil : AppMotion.smooth, value: isCompleted)
    }

    private var startButton: some View {
        Button(action: handlePrimaryScanAction) {
            HStack {
                Image(systemName: isScanFlowComplete ? "checkmark.circle.fill" : "camera.viewfinder")
                    .font(.system(size: 18, weight: .semibold))
                Text(startButtonTitle)
                    .font(.customFont(size: 16, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Color.customBitterSweet
            )
            .cornerRadius(100)
        }
        .disabled(isStartDisabled)
        .opacity(isStartDisabled ? 0.5 : 1.0)
        .pressScaleButtonStyle()
        .padding(.horizontal, 20)
    }

    private func startScanFlow() {
        guard !isStartDisabled else { return }
        AppHaptics.impact(.medium)
        withAnimation(reduceMotion ? nil : AppMotion.smooth) {
            completedPositions = []
            pendingPositions = requiredPositions
        }
        advanceToNextScan()
    }

    private func handlePrimaryScanAction() {
        guard !isStartDisabled else { return }

        if isScanFlowComplete {
            finishFlow()
        } else if !pendingPositions.isEmpty {
            AppHaptics.impact(.medium)
            advanceToNextScan()
        } else {
            startScanFlow()
        }
    }

    private func advanceToNextScan() {
        guard let nextPosition = pendingPositions.first else {
            finishFlow()
            return
        }

        pendingPositions.removeFirst()
        currentPosition = nextPosition
        didCompleteCurrentScan = false
        isPresentingScanner = true
    }

    private func handleScannerDismiss() {
        guard let position = currentPosition else {
            resetFlow()
            return
        }

        if didCompleteCurrentScan {
            AppHaptics.success()
            withAnimation(reduceMotion ? nil : AppMotion.emphasized) {
                completedPositions.append(position)
                currentPosition = nil
                didCompleteCurrentScan = false
            }
        } else {
            resetFlow()
        }
    }

    private func finishFlow() {
        currentPosition = nil
        pendingPositions = []
        didCompleteCurrentScan = false
        tyreViewModel.fetchTyres(vehicleId: vehicleId, forceRefresh: true)
        dismiss()
    }

    private func resetFlow() {
        withAnimation(reduceMotion ? nil : AppMotion.quick) {
            currentPosition = nil
            pendingPositions = []
            didCompleteCurrentScan = false
            completedPositions = []
        }
    }

    private var isCustomNameValid: Bool {
        !setName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isStartDisabled: Bool {
        isPresentingScanner || (!isScanFlowInProgress && setType == .custom && !isCustomNameValid)
    }
}


#if DEBUG
private final class TyreViewModelPreview: TyreViewModel {
    override func fetchTyres(vehicleId: Int, forceRefresh: Bool = false) {
        // No-op in preview
    }
}


#Preview("AddTyreSetView") {

    let vm = TyreViewModelPreview()

    NavigationStack {
        AddTyreSetView(
            vehicleId: 1,
            vehicleTyres: [],
            tyreViewModel: vm
        )
    }
    .preferredColorScheme(.dark)
    .background(Color.customBackgroundColor)
}
#endif
