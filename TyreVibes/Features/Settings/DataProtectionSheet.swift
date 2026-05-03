import SwiftUI

struct DataProtectionSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showDeletionConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.customBackgroundColor.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "shield.checkered")
                                .font(.system(size: 48))
                                .foregroundColor(Color(hex: "5CEBFF"))
                                .padding(.top, 16)

                            Text("I Tuoi Dati Sono Protetti".localized)
                                .font(.custom("Sora-SemiBold", size: 20))
                                .foregroundColor(.white)

                            Text("Hai il controllo completo sui tuoi dati personali".localized)
                                .font(.custom("Sora-Regular", size: 14))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.bottom, 8)

                        // Dati Personali
                        DataSection(title: "Dati Personali".localized, icon: "person.fill") {
                            DataProtectionRow(
                                label: "Autenticazione Biometrica".localized,
                                value: viewModel.biometricAuth ? "Abilitata".localized : "Disabilitata".localized,
                                icon: "faceid"
                            )
                            DataProtectionRow(
                                label: "Lingua Preferita".localized,
                                value: viewModel.selectedLanguage.name.localized,
                                icon: "globe"
                            )
                            DataProtectionRow(
                                label: "Livello Privacy".localized,
                                value: viewModel.privacyLevel.rawValue.localized,
                                icon: "hand.raised"
                            )
                        }

                        // Notifiche e Preferenze
                        DataSection(title: "Notifiche e Preferenze".localized, icon: "bell.fill") {
                            DataProtectionRow(
                                label: "Notifiche".localized,
                                value: viewModel.notificationsEnabled ? "Abilitate".localized : "Disabilitate".localized,
                                icon: "bell.badge"
                            )
                            DataProtectionRow(
                                label: "Notifiche Promozionali".localized,
                                value: viewModel.promotionNotifications ? "Sì".localized : "No".localized,
                                icon: "megaphone"
                            )
                            DataProtectionRow(
                                label: "Notifiche Aggiornamenti".localized,
                                value: viewModel.updateNotifications ? "Sì".localized : "No".localized,
                                icon: "arrow.down.circle"
                            )
                            DataProtectionRow(
                                label: "Notifiche Analisi".localized,
                                value: viewModel.analysisNotifications ? "Sì".localized : "No".localized,
                                icon: "chart.bar"
                            )
                        }

                        // Attività e Diagnostica
                        DataSection(title: "Attività & Diagnostica".localized, icon: "chart.line.uptrend.xyaxis") {
                            DataProtectionRow(
                                label: "Sincronizzazione Cloud".localized,
                                value: viewModel.backgroundSync ? "Attiva".localized : "Inattiva".localized,
                                icon: "icloud"
                            )
                            DataProtectionRow(
                                label: "Analytics".localized,
                                value: viewModel.privacyLevel == .strict ? "Disabilitato".localized : "Abilitato".localized,
                                icon: "chart.pie"
                            )
                            DataProtectionRow(
                                label: "Ottimizzazione Batteria".localized,
                                value: viewModel.batteryOptimization ? "Attiva".localized : "Inattiva".localized,
                                icon: "battery.100"
                            )
                        }

                        // Performance
                        DataSection(title: "Performance & Storage".localized, icon: "cpu") {
                            DataProtectionRow(label: "Dimensione App".localized, value: viewModel.stats.appSize, icon: "app")
                            DataProtectionRow(label: "Cache Utilizzata".localized, value: viewModel.stats.cacheSize, icon: "internaldrive")
                            DataProtectionRow(label: "Qualità Immagini".localized, value: viewModel.imageQualityLabel.localized, icon: "photo")
                            DataProtectionRow(
                                label: "Gestione Cache Auto".localized,
                                value: viewModel.cacheManagement ? "Abilitata".localized : "Disabilitata".localized,
                                icon: "trash.circle"
                            )
                        }

                        // Permessi
                        DataSection(title: "Permessi di Sistema".localized, icon: "checkmark.shield") {
                            DataProtectionRow(
                                label: "Localizzazione".localized,
                                value: viewModel.locationPermission ? "Consentita".localized : "Negata".localized,
                                icon: "location"
                            )
                            DataProtectionRow(
                                label: "Fotocamera".localized,
                                value: viewModel.cameraPermission ? "Consentita".localized : "Negata".localized,
                                icon: "camera"
                            )
                        }

                        // Info GDPR
                        GlassCard(height: nil, borderColor: Color(hex: "5CEBFF").opacity(0.6)) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(Color(hex: "5CEBFF"))
                                    Text("I Tuoi Diritti GDPR".localized)
                                        .font(.custom("Sora-SemiBold", size: 16))
                                        .foregroundColor(.white)
                                }

                                Text("In conformità con il GDPR, hai il diritto di:".localized)
                                    .font(.custom("Sora-Regular", size: 14))
                                    .foregroundColor(.white.opacity(0.8))

                                VStack(alignment: .leading, spacing: 8) {
                                    BulletPoint(text: "Esportare tutti i tuoi dati in formato JSON".localized)
                                    BulletPoint(text: "Richiedere la cancellazione completa del tuo account".localized)
                                    BulletPoint(text: "Accedere a tutti i dati che abbiamo raccolto su di te".localized)
                                    BulletPoint(text: "Modificare le tue preferenze sulla privacy in qualsiasi momento".localized)
                                }
                                .padding(.leading, 8)
                            }
                            .padding(18)
                        }

                        // Action Buttons
                        VStack(spacing: 12) {
                            Button(action: {
                                viewModel.exportMyData()
                            }) {
                                GlassCard(height: 56, borderColor: Color(hex: "2FB8FF")) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                            .foregroundColor(Color(hex: "5CEBFF"))
                                        Text("Esporta i Miei Dati".localized)
                                            .font(.custom("Sora-SemiBold", size: 16))
                                            .foregroundColor(.white)
                                    }
                                }
                            }

                            Button(action: {
                                showDeletionConfirmation = true
                            }) {
                                GlassCard(height: 56, borderColor: Color.red.opacity(0.4)) {
                                    HStack {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                        Text("Richiedi Cancellazione Dati".localized)
                                            .font(.custom("Sora-SemiBold", size: 16))
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }

                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 24)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Protezione Dati".localized)
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "Elimina account".localized,
                isPresented: $showDeletionConfirmation,
                titleVisibility: .visible
            ) {
                Button("Elimina account".localized, role: .destructive) {
                    viewModel.requestDataDeletion()
                    dismiss()
                }
                Button("Annulla".localized, role: .cancel) {}
            } message: {
                Text("Questa azione eliminerà il tuo account e i dati associati. Non potrà essere annullata.".localized)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi".localized) {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "5CEBFF"))
                }
            }
        }
    }
}

// MARK: - Supporting Views

fileprivate struct DataSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Color(hex: "5CEBFF"))
                    .font(.system(size: 18))
                Text(title)
                    .font(.custom("Sora-SemiBold", size: 18))
                    .foregroundColor(.white)
            }

            GlassCard(height: nil) {
                VStack(spacing: 12) {
                    content
                }
                .padding(16)
            }
        }
    }
}

fileprivate struct DataProtectionRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color(hex: "5CEBFF").opacity(0.7))
                .font(.system(size: 16))
                .frame(width: 24)

            Text(label)
                .font(.custom("Sora-Regular", size: 14))
                .foregroundColor(.white.opacity(0.9))

            Spacer()

            Text(value)
                .font(.custom("Sora-SemiBold", size: 14))
                .foregroundColor(.white)
        }
    }
}

fileprivate struct BulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.custom("Sora-SemiBold", size: 14))
                .foregroundColor(Color(hex: "5CEBFF"))
            Text(text)
                .font(.custom("Sora-Regular", size: 14))
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
