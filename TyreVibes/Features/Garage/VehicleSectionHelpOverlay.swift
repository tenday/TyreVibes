import SwiftUI

struct VehicleSectionHelpOverlay: View {
    let selectedIndex: Int
    let onClose: () -> Void
    let onDisable: () -> Void

    private var tip: VehicleSectionHelpTip {
        VehicleSectionHelpTip.tips[safe: selectedIndex] ?? VehicleSectionHelpTip.tips[0]
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: tip.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(tip.color)
                .frame(width: 38, height: 38)
                .background(Circle().fill(tip.color.opacity(0.16)))

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(tip.title)
                        .font(.customFont(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.65))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }

                Text(tip.message)
                    .font(.customFont(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)

                Button(action: onDisable) {
                    Text("Non mostrare piu")
                        .font(.customFont(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.58))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(tip.color.opacity(0.25), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.28), radius: 22, x: 0, y: 12)
        .padding(.horizontal, 16)
        .padding(.bottom, 18)
    }
}

private struct VehicleSectionHelpTip {
    let title: String
    let message: String
    let icon: String
    let color: Color

    static let tips: [VehicleSectionHelpTip] = [
        VehicleSectionHelpTip(
            title: "Specifiche",
            message: "Qui trovi dati tecnici, targa, immatricolazione e chilometraggio: aggiorna i km per rendere piu precise manutenzioni e stime.",
            icon: "info.circle.fill",
            color: .blue
        ),
        VehicleSectionHelpTip(
            title: "Revisioni",
            message: "Controlla esito, data e km delle revisioni. Le previsioni aiutano a capire quando prepararti alla prossima scadenza.",
            icon: "checkmark.seal.fill",
            color: .green
        ),
        VehicleSectionHelpTip(
            title: "Pneumatici",
            message: "Confronta le misure supportate con i set registrati. Entra nel dettaglio gomma per analisi, usura e dati stagionali.",
            icon: "circle.circle.fill",
            color: .orange
        ),
        VehicleSectionHelpTip(
            title: "Assicurazioni",
            message: "Usa questa sezione per leggere storico e copertura RCA. Le date ti aiutano a tenere sotto controllo rinnovi e scadenze.",
            icon: "shield.lefthalf.filled",
            color: .purple
        ),
        VehicleSectionHelpTip(
            title: "Manutenzione",
            message: "Qui registri interventi, costi, ricevute e piani futuri. Il sistema usa km e storico per proporre scadenze piu sensate.",
            icon: "wrench.and.screwdriver.fill",
            color: .indigo
        ),
        VehicleSectionHelpTip(
            title: "Bollo",
            message: "La stima usa potenza, alimentazione, classe ambientale e data immatricolazione. Verifica i dati se il calcolo sembra incompleto.",
            icon: "eurosign.circle.fill",
            color: .teal
        ),
        VehicleSectionHelpTip(
            title: "Archivio",
            message: "Salva libretto, ricevute, fatture, certificati e garanzie. Aggiungi una scadenza quando il documento richiede un promemoria.",
            icon: "folder.fill",
            color: .cyan
        )
    ]
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
