import SwiftUI

struct AddTyreSetView: View {
    let vehicleId: Int
    let vehicleTyres: [VehicleTyre]
    @ObservedObject var tyreViewModel: TyreViewModel
    @Environment(\.dismiss) private var dismiss

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
        let tyres: [VehicleTyre]
    }

    @State private var setType: TyreSetType = .frontRear
    @State private var setName: String = ""
    @State private var includeRearTyre: Bool = true
    @State private var selectedRecommendedSetId: Int?
    @State private var isPresentingScanner = false
    @State private var pendingPositions: [ScanPosition] = []
    @State private var currentPosition: ScanPosition?
    @State private var didCompleteCurrentScan = false
    @State private var completedPositions: [ScanPosition] = []

    private var needsDoubleScan: Bool {
        setType == .frontRear || includeRearTyre
    }

    private var requiredPositions: [ScanPosition] {
        needsDoubleScan ? [.front, .rear] : [.front]
    }

    private var totalSteps: Int {
        requiredPositions.count
    }

    private var scanContext: String? {
        guard let currentPosition else { return nil }
        let stepIndex = totalSteps - pendingPositions.count
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
            let name = tyres.first?.setName ?? "Set \(abs(key))"
            return RecommendedTyreSet(id: key, name: name, tyres: sortedTyres)
        }

        return sets.sorted { $0.name < $1.name }
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

                    if !recommendedSets.isEmpty {
                        suggestedSetsSection
                    }

                    typeSelectionSection

                    if setType == .custom {
                        customNameSection
                    }

                    if setType != .frontRear {
                        doubleMeasureToggle
                    }

                    stepsSection
                    startButton
                }
                .padding(.bottom, 24)
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
            Text("Misure consigliate")
                .font(.customFont(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(recommendedSets) { set in
                        Button {
                            applyRecommendedSet(set)
                        } label: {
                            recommendedSetCard(for: set)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func recommendedSetCard(for set: RecommendedTyreSet) -> some View {
        let isSelected = selectedRecommendedSetId == set.id

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(set.name)
                    .font(.customFont(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.orange)
                }
            }

            ForEach(set.tyres.prefix(2), id: \.id) { tyre in
                VStack(alignment: .leading, spacing: 4) {
                    Text(tyre.setName ?? "Misura")
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
                .fill(Color.white.opacity(isSelected ? 0.25 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.orange.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1)
        )
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
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            }
        }
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
    }

    private func scanStepRow(for position: ScanPosition, index: Int) -> some View {
        HStack(spacing: 14) {
            stepBadge(number: index + 1, isCompleted: completedPositions.contains(position))

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

            if completedPositions.contains(position) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 20, weight: .semibold))
            } else if currentPosition == position && isPresentingScanner {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.customFieldColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func stepBadge(number: Int, isCompleted: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isCompleted ? Color.green.opacity(0.2) : Color.orange.opacity(0.15))
                .frame(width: 40, height: 40)

            Text("\(number)")
                .font(.customFont(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private var startButton: some View {
        Button(action: startScanFlow) {
            HStack {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 18, weight: .semibold))
                Text(needsDoubleScan ? "Avvia doppia scansione" : "Avvia scansione")
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
        .padding(.horizontal, 20)
    }

    private func applyRecommendedSet(_ set: RecommendedTyreSet) {
        selectedRecommendedSetId = set.id
        let usesDouble = set.tyres.count > 1
        includeRearTyre = usesDouble
        if usesDouble {
            setType = .frontRear
        }
    }

    private func startScanFlow() {
        guard !isStartDisabled else { return }
        completedPositions = []
        pendingPositions = requiredPositions
        advanceToNextScan()
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
            completedPositions.append(position)
            currentPosition = nil
            didCompleteCurrentScan = false
            advanceToNextScan()
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
        currentPosition = nil
        pendingPositions = []
        didCompleteCurrentScan = false
        completedPositions = []
    }

    private var isCustomNameValid: Bool {
        !setName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isStartDisabled: Bool {
        isPresentingScanner || (setType == .custom && !isCustomNameValid)
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
