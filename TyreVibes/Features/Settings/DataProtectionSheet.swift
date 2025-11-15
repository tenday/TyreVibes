import SwiftUI

struct DataProtectionSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

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

                            Text("I Tuoi Dati Sono Protetti")
                                .font(.custom("Sora-SemiBold", size: 20))
                                .foregroundColor(.white)

                            Text("Hai il controllo completo sui tuoi dati personali")
                                .font(.custom("Sora-Regular", size: 14))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.bottom, 8)

                        // Dati Personali
                        DataSection(title: "Dati Personali", icon: "person.fill") {
                            DataRow(label: "Autenticazione Biometrica", value: viewModel.biometricAuth ? "Abilitata" : "Disabilitata", icon: "faceid")
                            DataRow(label: "Lingua Preferita", value: viewModel.selectedLanguage.name, icon: "globe")
                            DataRow(label: "Livello Privacy", value: viewModel.privacyLevel.rawValue, icon: "hand.raised")
                            DataRow(label: "Tema Selezionato", value: viewModel.selectedTheme.rawValue, icon: "paintbrush")
                        }

                        // Notifiche e Preferenze
                        DataSection(title: "Notifiche e Preferenze", icon: "bell.fill") {
                            DataRow(label: "Notifiche", value: viewModel.notificationsEnabled ? "Abilitate" : "Disabilitate", icon: "bell.badge")
                            DataRow(label: "Notifiche Promozionali", value: viewModel.promotionNotifications ? "Sì" : "No", icon: "megaphone")
                            DataRow(label: "Notifiche Aggiornamenti", value: viewModel.updateNotifications ? "Sì" : "No", icon: "arrow.down.circle")
                            DataRow(label: "Notifiche Analisi", value: viewModel.analysisNotifications ? "Sì" : "No", icon: "chart.bar")
                        }

                        // Attività e Diagnostica
                        DataSection(title: "Attività & Diagnostica", icon: "chart.line.uptrend.xyaxis") {
                            DataRow(label: "Sincronizzazione Cloud", value: viewModel.backgroundSync ? "Attiva" : "Inattiva", icon: "icloud")
                            DataRow(label: "Analytics", value: viewModel.privacyLevel == .strict ? "Disabilitato" : "Abilitato", icon: "chart.pie")
                            DataRow(label: "Ottimizzazione Batteria", value: viewModel.batteryOptimization ? "Attiva" : "Inattiva", icon: "battery.100")
                        }

                        // Performance
                        DataSection(title: "Performance & Storage", icon: "cpu") {
                            DataRow(label: "Dimensione App", value: viewModel.stats.appSize, icon: "app")
                            DataRow(label: "Cache Utilizzata", value: viewModel.stats.cacheSize, icon: "internaldrive")
                            DataRow(label: "Qualità Immagini", value: viewModel.imageQualityLabel, icon: "photo")
                            DataRow(label: "Gestione Cache Auto", value: viewModel.cacheManagement ? "Abilitata" : "Disabilitata", icon: "trash.circle")
                        }

                        // Permessi
                        DataSection(title: "Permessi di Sistema", icon: "checkmark.shield") {
                            DataRow(label: "Localizzazione", value: viewModel.locationPermission ? "Consentita" : "Negata", icon: "location")
                            DataRow(label: "Fotocamera", value: viewModel.cameraPermission ? "Consentita" : "Negata", icon: "camera")
                        }

                        // Info GDPR
                        GlassCard(height: .infinity, borderColor: Color(hex: "5CEBFF").opacity(0.6)) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(Color(hex: "5CEBFF"))
                                    Text("I Tuoi Diritti GDPR")
                                        .font(.custom("Sora-SemiBold", size: 16))
                                        .foregroundColor(.white)
                                }

                                Text("In conformità con il GDPR, hai il diritto di:")
                                    .font(.custom("Sora-Regular", size: 14))
                                    .foregroundColor(.white.opacity(0.8))

                                VStack(alignment: .leading, spacing: 8) {
                                    BulletPoint(text: "Esportare tutti i tuoi dati in formato JSON")
                                    BulletPoint(text: "Richiedere la cancellazione completa del tuo account")
                                    BulletPoint(text: "Accedere a tutti i dati che abbiamo raccolto su di te")
                                    BulletPoint(text: "Modificare le tue preferenze sulla privacy in qualsiasi momento")
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
                                        Text("Esporta i Miei Dati")
                                            .font(.custom("Sora-SemiBold", size: 16))
                                            .foregroundColor(.white)
                                    }
                                }
                            }

                            Button(action: {
                                viewModel.requestDataDeletion()
                                dismiss()
                            }) {
                                GlassCard(height: 56, borderColor: Color.red.opacity(0.4)) {
                                    HStack {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                        Text("Richiedi Cancellazione Dati")
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
            .navigationTitle("Protezione Dati")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "5CEBFF"))
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct DataSection<Content: View>: View {
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

            GlassCard(height: .infinity) {
                VStack(spacing: 12) {
                    content
                }
                .padding(16)
            }
        }
    }
}

struct DataRow: View {
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

struct BulletPoint: View {
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
