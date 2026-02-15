import SwiftUI

struct CustomNotificationsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SettingsViewModel
    @State private var editorNotification: CustomNotificationSetting?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.customBackgroundColor.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Crea promemoria personalizzati")
                            .font(.custom("Sora-Regular", size: 14))
                            .foregroundColor(.white.opacity(0.7))

                        if viewModel.customNotifications.isEmpty {
                            emptyState
                        } else {
                            VStack(spacing: 12) {
                                ForEach(viewModel.customNotifications) { notification in
                                    CustomNotificationRow(
                                        notification: notification,
                                        onToggle: { isEnabled in
                                            viewModel.setCustomNotificationEnabled(notification.id, isEnabled: isEnabled)
                                        },
                                        onEdit: { editorNotification = notification },
                                        onDelete: { viewModel.deleteCustomNotification(notification) }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Notifiche personalizzate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Chiudi") {
                        dismiss()
                    }
                    .foregroundColor(.customAzure)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { editorNotification = .makeDraft() }) {
                        Image(systemName: "plus")
                            .foregroundColor(.customAzure)
                    }
                }
            }
            .sheet(item: $editorNotification) { notification in
                CustomNotificationEditor(notification: notification) { updated in
                    viewModel.upsertCustomNotification(updated)
                }
            }
        }
    }

    private var emptyState: some View {
        GlassCard(height: nil, borderColor: Color(hex: "5CEBFF").opacity(0.6)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "bell.badge")
                        .foregroundColor(Color(hex: "5CEBFF"))
                    Text("Nessuna notifica personalizzata")
                        .font(.custom("Sora-SemiBold", size: 16))
                        .foregroundColor(.white)
                }

                Text("Aggiungi promemoria con titolo, messaggio e orario.")
                    .font(.custom("Sora-Regular", size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(18)
        }
    }
}

private struct CustomNotificationRow: View {
    let notification: CustomNotificationSetting
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        GlassCard(height: 96) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(notification.title.isEmpty ? "Promemoria" : notification.title)
                        .font(.custom("Sora-SemiBold", size: 15))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if !notification.body.isEmpty {
                        Text(notification.body)
                            .font(.custom("Sora-Regular", size: 13))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(2)
                    }

                    Text(scheduleLabel)
                        .font(.custom("Sora-Regular", size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                VStack(spacing: 10) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Toggle("", isOn: Binding(
                        get: { notification.isEnabled },
                        set: { onToggle($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Color(hex: "2FB8FF")))

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red)
                            .frame(width: 28, height: 28)
                            .background(Color.red.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var scheduleLabel: String {
        if notification.repeatsDaily {
            return "Ogni giorno alle \(notification.timeString)"
        }
        return "Una volta alle \(notification.timeString)"
    }
}

private struct CustomNotificationEditor: View {
    @Environment(\.dismiss) private var dismiss
    let notification: CustomNotificationSetting
    let onSave: (CustomNotificationSetting) -> Void

    @State private var title: String
    @State private var bodyText: String
    @State private var time: Date
    @State private var repeatsDaily: Bool
    @State private var isEnabled: Bool

    init(notification: CustomNotificationSetting, onSave: @escaping (CustomNotificationSetting) -> Void) {
        self.notification = notification
        self.onSave = onSave
        _title = State(initialValue: notification.title)
        _bodyText = State(initialValue: notification.body)
        _time = State(initialValue: notification.timeDate)
        _repeatsDaily = State(initialValue: notification.repeatsDaily)
        _isEnabled = State(initialValue: notification.isEnabled)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.customBackgroundColor.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        fieldHeader("Titolo")
                        TextField("Promemoria", text: $title)
                            .padding(12)
                            .background(Color.customFieldColor)
                            .cornerRadius(12)
                            .foregroundColor(.white)

                        fieldHeader("Messaggio")
                        TextField("Scrivi il messaggio", text: $bodyText, axis: .vertical)
                            .padding(12)
                            .background(Color.customFieldColor)
                            .cornerRadius(12)
                            .foregroundColor(.white)

                        fieldHeader("Orario")
                        DatePicker("Orario", selection: $time, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Toggle("Ripeti ogni giorno", isOn: $repeatsDaily)
                            .tint(Color(hex: "2FB8FF"))
                            .font(.custom("Sora-Regular", size: 14))
                            .foregroundColor(.white)

                        Toggle("Abilitata", isOn: $isEnabled)
                            .tint(Color(hex: "2FB8FF"))
                            .font(.custom("Sora-Regular", size: 14))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Dettagli promemoria")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") {
                        dismiss()
                    }
                    .foregroundColor(.customAzure)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salva") {
                        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
                        let updated = CustomNotificationSetting(
                            id: notification.id,
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            body: bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
                            hour: components.hour ?? notification.hour,
                            minute: components.minute ?? notification.minute,
                            repeatsDaily: repeatsDaily,
                            isEnabled: isEnabled,
                            createdAt: notification.createdAt
                        )
                        onSave(updated)
                        dismiss()
                    }
                    .foregroundColor(.customAzure)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func fieldHeader(_ text: String) -> some View {
        Text(text)
            .font(.custom("Sora-SemiBold", size: 14))
            .foregroundColor(.white.opacity(0.8))
    }
}
