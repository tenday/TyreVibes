import SwiftUI
import MapKit

struct WorkshopBookingSheet: View {
    let shopName: String
    let shopAddress: String?
    let shopPhone: String?
    let vehicleId: Int?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date = Date()
    @State private var selectedService: MaintenanceSchedule.MaintenanceType = .generalService
    @State private var notes: String = ""
    @State private var showConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Officina") {
                    HStack {
                        Image(systemName: "building.2.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading) {
                            Text(shopName)
                                .font(.customFont(size: 15, weight: .semibold))
                            if let address = shopAddress {
                                Text(address)
                                    .font(.customFont(size: 12, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section("Servizio richiesto") {
                    Picker("Tipo intervento", selection: $selectedService) {
                        ForEach(MaintenanceSchedule.MaintenanceType.groupedByCategory, id: \.category) { group in
                            Section(group.category.rawValue) {
                                ForEach(group.types, id: \.self) { type in
                                    HStack(spacing: 8) {
                                        MaintenanceTypeIconView(type: type, size: 16)
                                        Text(type.localizedName)
                                    }
                                        .tag(type)
                                }
                            }
                        }
                    }

                    DatePicker("Data preferita", selection: $selectedDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                }

                Section("Note aggiuntive") {
                    TextField("Descrivi il problema o la richiesta...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    if let phone = shopPhone, !phone.isEmpty {
                        Button {
                            callWorkshop(phone)
                        } label: {
                            Label("Chiama officina", systemImage: "phone.fill")
                                .foregroundColor(.green)
                        }

                        Button {
                            sendWhatsApp(phone)
                        } label: {
                            Label("Invia su WhatsApp", systemImage: "message.fill")
                                .foregroundColor(.green)
                        }
                    }

                    Button {
                        showConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Prenota appuntamento", systemImage: "calendar.badge.plus")
                                .font(.customFont(size: 15, weight: .semibold))
                            Spacer()
                        }
                    }
                    .tint(.blue)
                }
            }
            .navigationTitle("Prenota appuntamento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
            .alert("Appuntamento prenotato", isPresented: $showConfirmation) {
                Button("OK") { dismiss() }
            } message: {
                Text("La richiesta di appuntamento per \(selectedService.localizedName) è stata inviata a \(shopName).")
            }
        }
    }

    private func callWorkshop(_ phone: String) {
        let cleaned = phone.replacingOccurrences(of: " ", with: "")
        if let url = URL(string: "tel://\(cleaned)") {
            UIApplication.shared.open(url)
        }
    }

    private func sendWhatsApp(_ phone: String) {
        let cleaned = phone.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "+", with: "")
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "it_IT")
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short

        var message = "Buongiorno, vorrei prenotare un appuntamento per: \(selectedService.localizedName)"
        message += "\nData preferita: \(dateFormatter.string(from: selectedDate))"
        if !notes.isEmpty {
            message += "\nNote: \(notes)"
        }
        message += "\n\nInviato tramite TyreVibes"

        let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://wa.me/\(cleaned)?text=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }
}
