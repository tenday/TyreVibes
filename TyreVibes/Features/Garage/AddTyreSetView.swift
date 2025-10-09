import SwiftUI

struct AddTyreSetView: View {
    let vehicleId: Int
    @ObservedObject var tyreViewModel: TyreViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var setName: String = ""
    @State private var setType: TyreSetType = .frontRear
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""

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
            case .frontRear: return "Per veicoli con misure diverse davanti e dietro"
            case .summer: return "Pneumatici estivi ad alte prestazioni"
            case .winter: return "Pneumatici invernali per sicurezza"
            case .track: return "Pneumatici specifici per uso in pista"
            case .custom: return "Crea un set personalizzato"
            }
        }
    }

    var body: some View {
        NavigationView {
            mainContent
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        closeButton
                    }
                }
        }
        .alert("Errore", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var mainContent: some View {
        ZStack {
            Color.customBackgroundColor.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    typeSelectionSection

                    if setType == .custom {
                        customNameSection
                    }

                    infoSection
                    Spacer()
                    createButton
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aggiungi nuovo set")
                .font(.customFont(size: 28, weight: .bold))
                .foregroundColor(.white)

            Text("Configura un set di misure pneumatici per veicoli ad alte prestazioni")
                .font(.customFont(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private var typeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tipo di set")
                .font(.customFont(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)

            ForEach(TyreSetType.allCases) { type in
                typeButton(for: type)
            }
        }
    }

    private func typeButton(for type: TyreSetType) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                setType = type
                if type != .custom {
                    setName = type.rawValue
                }
            }
        }) {
            HStack(spacing: 16) {
                typeIcon(for: type)
                typeText(for: type)
                Spacer()
                selectionIndicator(for: type)
            }
            .padding(16)
            .background(typeBackground(for: type))
            .overlay(typeOverlay(for: type))
        }
        .padding(.horizontal, 20)
    }

    private func typeIcon(for type: TyreSetType) -> some View {
        Image(systemName: type.icon)
            .font(.system(size: 24, weight: .medium))
            .foregroundColor(setType == type ? .orange : .white.opacity(0.6))
            .frame(width: 40, height: 40)
            .background(
                Circle()
                    .fill(setType == type ? Color.orange.opacity(0.2) : Color.white.opacity(0.1))
            )
    }

    private func typeText(for type: TyreSetType) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(type.rawValue)
                .font(.customFont(size: 15, weight: .semibold))
                .foregroundColor(.white)

            Text(type.description)
                .font(.customFont(size: 12, weight: .regular))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(2)
        }
    }

    private func selectionIndicator(for type: TyreSetType) -> some View {
        Image(systemName: setType == type ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 24, weight: setType == type ? .semibold : .regular))
            .foregroundColor(setType == type ? .orange : .white.opacity(0.3))
    }

    private func typeBackground(for type: TyreSetType) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(setType == type ? Color.orange.opacity(0.15) : Color.white.opacity(0.05))
    }

    private func typeOverlay(for type: TyreSetType) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(setType == type ? Color.orange.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
    }

    private var customNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nome del set")
                .font(.customFont(size: 16, weight: .semibold))
                .foregroundColor(.white)

            TextField("Es. Set Racing", text: $setName)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.customFont(size: 15, weight: .medium))
                .foregroundColor(.white)
                .padding(16)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
        }
        .padding(.horizontal, 20)
    }

    private var infoSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.blue)

            Text("Dopo aver creato il set, potrai associare le misure specifiche per ciascuna posizione del veicolo")
                .font(.customFont(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.blue.opacity(0.15))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }

    private var createButton: some View {
        Button(action: createTyreSet) {
            Text("Crea Set")
                .font(.customFont(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(createButtonGradient)
                .cornerRadius(12)
        }
        .disabled(setType == .custom && setName.isEmpty)
        .opacity((setType == .custom && setName.isEmpty) ? 0.5 : 1.0)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private var createButtonGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [Color.orange, Color.orange.opacity(0.8)]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var closeButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    private func createTyreSet() {
        errorMessage = "Funzionalità in sviluppo: sarà disponibile con il prossimo aggiornamento del backend"
        showingError = true
    }
}
