import SwiftUI

struct DataProtectionSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Personal Data") {
                    dataRow(title: "Biometrics", value: viewModel.biometricAuth ? "Enabled" : "Disabled")
                    dataRow(title: "Language", value: viewModel.selectedLanguage.name)
                    dataRow(title: "Privacy Level", value: viewModel.privacyLevel.rawValue)
                }

                Section("Activity & Diagnostics") {
                    dataRow(title: "Background Sync", value: viewModel.backgroundSync ? "Active" : "Inactive")
                    dataRow(title: "Analytics", value: viewModel.privacyLevel == .strict ? "Disabled" : "Enabled")
                }

                Section("Storage") {
                    dataRow(title: "App Size", value: viewModel.stats.appSize)
                    dataRow(title: "Cache Size", value: viewModel.stats.cacheSize)
                }

                Section("Actions") {
                    Button("Export my data") {
                        viewModel.exportMyData()
                        dismiss()
                    }
                    Button("Request data deletion", role: .destructive) {
                        viewModel.requestDataDeletion()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Data Protection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func dataRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}
