import SwiftUI

struct VehicleInfoTutorialSheet: View {
    let onSelectSection: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    private let sections: [VehicleInfoTutorialSection] = [
        VehicleInfoTutorialSection(
            title: "Specifiche",
            subtitle: "Identita, dati tecnici e chilometraggio attuale del veicolo.",
            icon: "info.circle.fill",
            color: .blue
        ),
        VehicleInfoTutorialSection(
            title: "Revisioni",
            subtitle: "Storico controlli, esiti e previsioni sulla prossima revisione.",
            icon: "checkmark.seal.fill",
            color: .green
        ),
        VehicleInfoTutorialSection(
            title: "Pneumatici",
            subtitle: "Misure supportate, set registrati e stato degli pneumatici.",
            icon: "circle.circle.fill",
            color: .orange
        ),
        VehicleInfoTutorialSection(
            title: "Assicurazioni",
            subtitle: "Copertura RCA, storico polizze e prossima scadenza stimata.",
            icon: "shield.lefthalf.filled",
            color: .purple
        ),
        VehicleInfoTutorialSection(
            title: "Manutenzione",
            subtitle: "Piano smart, interventi completati, costi e ricevute collegate.",
            icon: "wrench.and.screwdriver.fill",
            color: .indigo
        ),
        VehicleInfoTutorialSection(
            title: "Bollo",
            subtitle: "Stima del pagamento, parametri fiscali e dettagli di calcolo.",
            icon: "eurosign.circle.fill",
            color: .teal
        ),
        VehicleInfoTutorialSection(
            title: "Archivio",
            subtitle: "Libretto, certificati, fatture, ricevute e garanzie del veicolo.",
            icon: "folder.fill",
            color: .cyan
        )
    ]

    private var isLastPage: Bool {
        currentPage == sections.count - 1
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TabView(selection: $currentPage) {
                    ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                        VehicleInfoTutorialPage(section: section)
                            .tag(index)
                            .padding(.horizontal, 20)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageDots

                VStack(spacing: 10) {
                    Button {
                        onSelectSection(currentPage)
                        dismiss()
                    } label: {
                        Text("Apri \(sections[currentPage].title)")
                            .font(.customFont(size: 15, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(Color.white))
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 10) {
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                currentPage = max(currentPage - 1, 0)
                            }
                        } label: {
                            Label("Indietro", systemImage: "chevron.left")
                                .font(.customFont(size: 13, weight: .semibold))
                                .foregroundColor(currentPage == 0 ? .white.opacity(0.35) : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        .disabled(currentPage == 0)

                        Button {
                            if isLastPage {
                                dismiss()
                            } else {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                    currentPage += 1
                                }
                            }
                        } label: {
                            Label(isLastPage ? "Fine" : "Avanti", systemImage: isLastPage ? "checkmark" : "chevron.right")
                                .font(.customFont(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(sections[currentPage].color.opacity(0.38)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color.customBackgroundColor,
                        Color.customBackgroundColor.opacity(0.92),
                        sections[currentPage].color.opacity(0.18)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Tour sezioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }

    private var pageDots: some View {
        HStack(spacing: 7) {
            ForEach(sections.indices, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? Color.white : Color.white.opacity(0.25))
                    .frame(width: index == currentPage ? 22 : 7, height: 7)
                    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: currentPage)
            }
        }
    }
}

private struct VehicleInfoTutorialSection {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
}

private struct VehicleInfoTutorialPage: View {
    let section: VehicleInfoTutorialSection

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 24)

            ZStack {
                Circle()
                    .fill(section.color.opacity(0.18))
                    .frame(width: 132, height: 132)

                Circle()
                    .stroke(section.color.opacity(0.34), lineWidth: 1)
                    .frame(width: 132, height: 132)

                Image(systemName: section.icon)
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundColor(section.color)
            }

            VStack(spacing: 10) {
                Text(section.title)
                    .font(.customFont(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(section.subtitle)
                    .font(.customFont(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 8)
            }

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
