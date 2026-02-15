import SwiftUI

struct MaintenanceNotificationSettingsView: View {
    @AppStorage("maintenance_notifications_enabled") private var notificationsEnabled = true
    @AppStorage("maintenance_reminder_days") private var reminderDays = 7
    @State private var disabledTypes: Set<String> = []

    private let storageKey = "maintenance_disabled_notification_types"

    var body: some View {
        Form {
            Section {
                Toggle("Notifiche manutenzione", isOn: $notificationsEnabled)
            } footer: {
                Text("Abilita o disabilita tutte le notifiche relative alla manutenzione del veicolo.")
            }

            if notificationsEnabled {
                Section("Anticipo promemoria") {
                    Picker("Giorni prima della scadenza", selection: $reminderDays) {
                        Text("3 giorni").tag(3)
                        Text("7 giorni").tag(7)
                        Text("14 giorni").tag(14)
                        Text("30 giorni").tag(30)
                    }
                }

                ForEach(MaintenanceSchedule.MaintenanceType.groupedByCategory, id: \.category) { group in
                    Section(group.category.rawValue) {
                        ForEach(group.types, id: \.self) { type in
                            Toggle(isOn: binding(for: type)) {
                                Label(type.localizedName, systemImage: type.icon)
                            }
                            .tint(type.color)
                        }
                    }
                }
            }
        }
        .navigationTitle("Notifiche manutenzione")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadDisabledTypes()
        }
    }

    private func binding(for type: MaintenanceSchedule.MaintenanceType) -> Binding<Bool> {
        Binding(
            get: { !disabledTypes.contains(type.rawValue) },
            set: { enabled in
                if enabled {
                    disabledTypes.remove(type.rawValue)
                } else {
                    disabledTypes.insert(type.rawValue)
                }
                saveDisabledTypes()
            }
        )
    }

    private func loadDisabledTypes() {
        let saved = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        disabledTypes = Set(saved)
    }

    private func saveDisabledTypes() {
        UserDefaults.standard.set(Array(disabledTypes), forKey: storageKey)
    }

    // MARK: - Static helpers for other parts of the app

    static func isTypeEnabled(_ type: MaintenanceSchedule.MaintenanceType) -> Bool {
        let disabled = UserDefaults.standard.stringArray(forKey: "maintenance_disabled_notification_types") ?? []
        return !disabled.contains(type.rawValue)
    }

    static var reminderDaysAdvance: Int {
        UserDefaults.standard.integer(forKey: "maintenance_reminder_days").nonZero ?? 7
    }
}

private extension Int {
    var nonZero: Int? {
        self == 0 ? nil : self
    }
}
