import SwiftUI

struct CompletedMaintenanceTable: View {
    let entries: [CompletedMaintenanceEntry]
    let onAddManual: () -> Void

    private var formatter: DateFormatter {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                HStack {
                    Text("Storico manutenzioni")
                        .font(.customFont(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: onAddManual) {
                        Label("Registra", systemImage: "plus.circle.fill")
                            .font(.customFont(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 2)

                if entries.isEmpty {
                    EmptyStateView(
                        icon: "checkmark.circle",
                        title: "Nessuna manutenzione registrata",
                        subtitle: "Aggiungile manualmente o attendi conferma automatica da prenotazione partner."
                    )
                } else {
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Image(systemName: icon(for: entry.source))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(color(for: entry.source))
                                    .frame(width: 30, height: 30)
                                    .background(color(for: entry.source).opacity(0.15), in: Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title)
                                        .font(.customFont(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text("\(entry.source.label) • \(formatter.string(from: entry.date))")
                                        .font(.customFont(size: 12, weight: .regular))
                                        .foregroundColor(.white.opacity(0.65))
                                }

                                Spacer()
                            }

                            if let note = entry.note, !note.isEmpty {
                                Text(note)
                                    .font(.customFont(size: 12, weight: .regular))
                                    .foregroundColor(.white.opacity(0.8))
                            }

                            if let mileage = entry.mileage {
                                Text("Km: \(mileage)")
                                    .font(.customFont(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.65))
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }

    private func icon(for source: CompletedMaintenanceSource) -> String {
        switch source {
        case .manual: return "square.and.pencil"
        case .partner: return "building.2.fill"
        case .automatic: return "gearshape.2.fill"
        }
    }

    private func color(for source: CompletedMaintenanceSource) -> Color {
        switch source {
        case .manual: return .orange
        case .partner: return .green
        case .automatic: return .blue
        }
    }
}
