import SwiftUI

struct MaintenanceManagementView: View {
    let vehicleId: Int
    var vin: String?

    @StateObject private var historyStore = MaintenanceHistoryStore.shared
    @StateObject private var scheduleStore = MaintenanceScheduleStore.shared
    @StateObject private var notificationStore = NotificationStore.shared
    @StateObject private var mileageStore = VehicleMileageStore.shared
    @StateObject private var oemService = ManufacturerMaintenanceService.shared

    @State private var selectedSection: Section = .planned
    @State private var showPlanSheet = false
    @State private var showCompletedSheet = false
    @State private var showMileagePrompt = false
    @State private var mileageInput: String = ""
    @State private var showCostDashboard = false
    @State private var showScanReceiptSheet = false
    @State private var oemBannerMessage: String?
    @State private var selectedEntry: CompletedMaintenanceEntry?

    enum Section: String, CaseIterable {
        case planned = "Prossimi"
        case completed = "Storico"

        var icon: String {
            switch self {
            case .planned: return "calendar.badge.clock"
            case .completed: return "clock.arrow.circlepath"
            }
        }
    }

    private let automaticTypes: Set<AppNotification.NotificationType> = [
        .maintenanceReminder,
        .rotation,
        .alignment,
        .inspection,
        .tyreReplacement,
        .pressureAlert,
        .oilChangeReminder,
        .filterReminder,
        .brakeReminder,
        .batteryReminder,
        .generalMaintenanceReminder
    ]

    private var plannedItems: [MaintenanceSchedule] {
        scheduleStore.schedules(for: vehicleId)
    }

    private var currentMileage: Int? {
        mileageStore.mileage(for: vehicleId)
    }

    private var automaticEntries: [CompletedMaintenanceEntry] {
        let resolvedVehicleId = String(vehicleId)
        return notificationStore.notifications
            .filter { notification in
                automaticTypes.contains(notification.type) &&
                notification.isRead &&
                (notification.vehicleId == nil || notification.vehicleId == resolvedVehicleId)
            }
            .sorted { $0.timestamp > $1.timestamp }
            .map { notification in
                CompletedMaintenanceEntry(
                    id: "notification-\(notification.id)",
                    vehicleId: vehicleId,
                    title: notification.title,
                    note: notification.message,
                    date: notification.timestamp,
                    mileage: notification.metadata?.mileage,
                    source: .automatic
                )
            }
    }

    private var completedItems: [CompletedMaintenanceEntry] {
        (historyStore.entries(for: vehicleId) + automaticEntries)
            .sorted { $0.date > $1.date }
    }

    private var overdueCount: Int {
        plannedItems.filter(\.isOverdue).count
    }

    private var nextItem: MaintenanceSchedule? {
        plannedItems.first
    }

    private var upcomingSoonCount: Int {
        plannedItems.filter { !$0.isOverdue && $0.daysUntil <= 14 }.count
    }

    private var totalCostThisMonth: Double {
        let calendar = Calendar.current
        let now = Date()
        return completedItems
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
            .compactMap(\.cost)
            .reduce(0, +)
    }

    private var readinessScore: Double {
        var score = 1.0

        if plannedItems.isEmpty {
            score -= 0.28
        }

        score -= min(Double(overdueCount) * 0.22, 0.56)
        score -= min(Double(upcomingSoonCount) * 0.05, 0.15)

        if mileageStore.needsUpdate(for: vehicleId) {
            score -= 0.14
        }

        return max(0.10, min(score, 1.0))
    }

    private var statusColor: Color {
        if overdueCount > 0 { return .orange }
        if mileageStore.needsUpdate(for: vehicleId) || upcomingSoonCount > 0 { return .cyan }
        return .green
    }

    private var statusIcon: String {
        if overdueCount > 0 { return "exclamationmark.triangle.fill" }
        if mileageStore.needsUpdate(for: vehicleId) { return "speedometer" }
        if upcomingSoonCount > 0 { return "sparkles" }
        return "checkmark.seal.fill"
    }

    private var statusTitle: String {
        if overdueCount > 0 { return "Intervento scaduto" }
        if currentMileage == nil { return "Km necessari" }
        if plannedItems.isEmpty { return "Piano da creare" }
        if mileageStore.needsUpdate(for: vehicleId) { return "Km da aggiornare" }
        if upcomingSoonCount > 0 { return "Prossima manutenzione vicina" }
        return "Manutenzione in ordine"
    }

    private var statusSubtitle: String {
        if overdueCount > 0 {
            return "\(overdueCount) attività richiedono attenzione."
        }

        if currentMileage == nil {
            return "Inserisci i km attuali per stimare interventi reali."
        }

        if plannedItems.isEmpty {
            return "Nessun intervento necessario con i dati attuali."
        }

        if mileageStore.needsUpdate(for: vehicleId) {
            return "I km attuali rendono più precise le scadenze."
        }

        if let nextItem {
            return "Prossimo step: \(nextItem.title)."
        }

        return "Nessuna urgenza rilevata."
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                header
                commandCenter
                quickActions

                if mileageStore.needsUpdate(for: vehicleId) {
                    mileageUpdateBanner
                }

                if let oemMessage = oemBannerMessage {
                    oemBanner(message: oemMessage)
                }

                if oemService.isLoading {
                    oemLoadingBanner
                }

                stats
                nextStepPanel
                sectionSelector
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .onAppear {
            scheduleStore.removeLegacySeededSchedules(for: vehicleId)
            SmartMaintenanceScheduler.shared.evaluateAndSchedule(vehicleId: vehicleId)
            NotificationScheduler.shared.scheduleMaintenanceReminders(vehicleId: vehicleId, vehicleName: "Veicolo")
            fetchOEMIntervalsIfNeeded()
        }
        .sheet(isPresented: $showPlanSheet) {
            MaintenancePlanCreateSheet(vehicleId: vehicleId)
        }
        .sheet(isPresented: $showCompletedSheet) {
            MaintenanceCompletionSheet(vehicleId: vehicleId)
        }
        .sheet(isPresented: $showCostDashboard) {
            MaintenanceCostDashboardView(vehicleId: vehicleId)
        }
        .sheet(isPresented: $showScanReceiptSheet) {
            ScanReceiptSheet(vehicleId: vehicleId)
        }
        .sheet(item: $selectedEntry) { entry in
            MaintenanceDetailSheet(entry: entry, vehicleId: vehicleId)
        }
        .alert("Aggiorna chilometraggio", isPresented: $showMileagePrompt) {
            TextField("Km attuali", text: $mileageInput)
                .keyboardType(.numberPad)
            Button("Salva") {
                if let km = Int(mileageInput) {
                    mileageStore.setMileage(km, for: vehicleId)
                    SmartMaintenanceScheduler.shared.evaluateAndSchedule(vehicleId: vehicleId)
                    NotificationScheduler.shared.scheduleMaintenanceReminders(vehicleId: vehicleId, vehicleName: "Veicolo")
                }
                mileageInput = ""
            }
            Button("Annulla", role: .cancel) {
                mileageInput = ""
            }
        } message: {
            Text("Inserisci i km attuali del veicolo per calcolare le scadenze manutenzione.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Manutenzione smart")
                    .font(.customFont(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Text("Piano, storico e costi in un solo cockpit")
                    .font(.customFont(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.62))
            }

            Spacer()

            Button {
                showCostDashboard = true
            } label: {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.10), in: Circle())
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    showPlanSheet = true
                } label: {
                    Label("Pianifica intervento", systemImage: "calendar.badge.plus")
                }

                Button {
                    showCompletedSheet = true
                } label: {
                    Label("Registra intervento fatto", systemImage: "checkmark.circle")
                }

                Button {
                    showScanReceiptSheet = true
                } label: {
                    Label("Scansiona ricevuta", systemImage: "doc.text.viewfinder")
                }

                Divider()

                Button {
                    SmartMaintenanceScheduler.shared.evaluateAndSchedule(vehicleId: vehicleId)
                    NotificationScheduler.shared.scheduleMaintenanceReminders(vehicleId: vehicleId, vehicleName: "Veicolo")
                } label: {
                    Label("Ricalcola scadenze", systemImage: "arrow.clockwise")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 38, height: 38)
                    .background(Color.white, in: Circle())
            }
        }
    }

    // MARK: - Command Center

    private var commandCenter: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(statusColor)
                    Text(statusTitle)
                        .font(.customFont(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                Text(statusSubtitle)
                    .font(.customFont(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.70))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    metricPill(icon: "calendar", value: "\(plannedItems.count)", label: "aperte", color: .cyan)
                    metricPill(icon: "checkmark.seal", value: "\(completedItems.count)", label: "fatte", color: .green)
                }
            }

            Spacer(minLength: 8)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 9)
                    .frame(width: 84, height: 84)
                Circle()
                    .trim(from: 0, to: readinessScore)
                    .stroke(
                        AngularGradient(
                            colors: [statusColor.opacity(0.45), statusColor, .white.opacity(0.9)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 84, height: 84)

                VStack(spacing: 0) {
                    Text("\(Int(readinessScore * 100))")
                        .font(.customFont(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Text("score")
                        .font(.customFont(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.13),
                            statusColor.opacity(0.10),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(statusColor.opacity(0.28), lineWidth: 1)
        )
    }

    private func metricPill(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(value)
                .font(.customFont(size: 12, weight: .bold))
            Text(label)
                .font(.customFont(size: 10, weight: .medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(color.opacity(0.13), in: Capsule())
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        HStack(spacing: 10) {
            MaintenanceQuickActionButton(
                title: "Pianifica",
                icon: "calendar.badge.plus",
                tint: .cyan
            ) {
                showPlanSheet = true
            }

            MaintenanceQuickActionButton(
                title: "Registra",
                icon: "checkmark.circle.fill",
                tint: .green
            ) {
                showCompletedSheet = true
            }

            MaintenanceQuickActionButton(
                title: "Scansiona",
                icon: "doc.text.viewfinder",
                tint: .orange
            ) {
                showScanReceiptSheet = true
            }
        }
    }

    // MARK: - Mileage Update Banner

    private var mileageUpdateBanner: some View {
        Button {
            showMileagePrompt = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "speedometer")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.cyan)
                    .frame(width: 34, height: 34)
                    .background(Color.cyan.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Aggiorna chilometraggio")
                        .font(.customFont(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Scadenze più precise con i km reali")
                        .font(.customFont(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.62))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.cyan.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.cyan.opacity(0.24), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stats

    private var stats: some View {
        HStack(spacing: 10) {
            MaintenanceStatCard(
                title: "Da fare",
                value: "\(plannedItems.count)",
                color: .cyan,
                icon: "calendar.badge.clock"
            )
            MaintenanceStatCard(
                title: "Urgenti",
                value: "\(overdueCount)",
                color: .orange,
                icon: "exclamationmark.triangle.fill"
            )
            MaintenanceStatCard(
                title: "Spesa mese",
                value: currencyText(totalCostThisMonth, maxDigits: 0),
                color: .green,
                icon: "eurosign.circle.fill"
            )
        }
    }

    // MARK: - Next Step

    private var nextStepPanel: some View {
        Group {
            if let item = nextItem {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Prossimo intervento")
                            .font(.customFont(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.55))
                        Text(item.title)
                            .font(.customFont(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text("\(item.formattedDate) - \(item.relativeTimeString)")
                            .font(.customFont(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.68))
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        scheduleStore.markCompleted(scheduleId: item.id, vehicleId: vehicleId)
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 36, height: 36)
                            .background(Color.green, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(item.type.color.opacity(0.28), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Section Selector

    private var sectionSelector: some View {
        HStack(spacing: 8) {
            ForEach(Section.allCases, id: \.self) { section in
                let selected = selectedSection == section
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSection = section
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: section.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(section.rawValue)
                            .font(.customFont(size: 13, weight: .semibold))
                    }
                    .foregroundColor(selected ? .black : .white.opacity(0.78))
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity)
                    .background(
                        Capsule(style: .continuous)
                            .fill(selected ? Color.white : Color.white.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.05), in: Capsule(style: .continuous))
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if selectedSection == .planned {
            plannedContent
        } else {
            completedContent
        }
    }

    private var plannedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            contentHeader(
                title: "Timeline interventi",
                subtitle: "\(plannedItems.count) attività aperte",
                icon: "point.topleft.down.curvedto.point.bottomright.up"
            )

            if plannedItems.isEmpty {
                EmptyStateView(
                    icon: currentMileage == nil ? "speedometer" : "calendar.badge.exclamationmark",
                    title: currentMileage == nil ? "Inserisci il chilometraggio" : "Nessuna manutenzione necessaria",
                    subtitle: currentMileage == nil ? "TyreVibes userà i km attuali per stimare scadenze reali." : "La timeline si aggiornerà quando cambiano km, storico o intervalli."
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(Array(plannedItems.enumerated()), id: \.element.id) { index, item in
                        MaintenancePlannedCard(
                            item: item,
                            isNext: index == 0,
                            onComplete: {
                                scheduleStore.markCompleted(scheduleId: item.id, vehicleId: vehicleId)
                                NotificationScheduler.shared.scheduleMaintenanceReminders(vehicleId: vehicleId, vehicleName: "Veicolo")
                            },
                            onDelete: {
                                scheduleStore.deleteSchedule(item.id)
                                NotificationScheduler.shared.scheduleMaintenanceReminders(vehicleId: vehicleId, vehicleName: "Veicolo")
                            }
                        )
                    }
                }
            }
        }
    }

    private var completedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            contentHeader(
                title: "Registro lavori",
                subtitle: "\(completedItems.count) interventi salvati",
                icon: "list.bullet.clipboard"
            )

            if completedItems.isEmpty {
                EmptyStateView(
                    icon: "checkmark.circle",
                    title: "Nessuna manutenzione registrata",
                    subtitle: "Registra i lavori effettuati per avere storico e tracciamento."
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(completedItems) { entry in
                        MaintenanceCompletedCard(entry: entry)
                            .onTapGesture {
                                selectedEntry = entry
                            }
                    }
                }
            }
        }
    }

    private func contentHeader(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.cyan)
                .frame(width: 28, height: 28)
                .background(Color.cyan.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.customFont(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.customFont(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.55))
            }

            Spacer()
        }
        .padding(.top, 2)
    }

    // MARK: - OEM Loading Banner

    private var oemLoadingBanner: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(.cyan)
            Text("Caricamento intervalli produttore...")
                .font(.customFont(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cyan.opacity(0.08))
        )
    }

    // MARK: - OEM Banner

    private func oemBanner(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.green)
            Text(message)
                .font(.customFont(size: 13, weight: .medium))
                .foregroundColor(.white)
            Spacer()
            Button {
                withAnimation { oemBannerMessage = nil }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.green.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.green.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Formatting

    private func currencyText(_ value: Double, maxDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = maxDigits
        return formatter.string(from: NSNumber(value: value)) ?? "€0"
    }

    // MARK: - OEM Fetch

    private func fetchOEMIntervalsIfNeeded() {
        guard let vin = vin, !vin.isEmpty else { return }
        guard !oemService.hasOEMBeenFetched(for: vehicleId) else { return }

        Task {
            do {
                let count = try await oemService.fetchAndApplyOEMIntervals(vin: vin, vehicleId: vehicleId)
                if count > 0 {
                    SmartMaintenanceScheduler.shared.evaluateAndSchedule(vehicleId: vehicleId)
                    NotificationScheduler.shared.scheduleMaintenanceReminders(vehicleId: vehicleId, vehicleName: "Veicolo")
                    withAnimation {
                        oemBannerMessage = "Applicati \(count) intervalli del produttore"
                    }
                }
            } catch {
                print("⚠️ [OEM] Fetch failed: \(error.localizedDescription)")
            }
        }
    }
}

private struct MaintenanceQuickActionButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.13), in: Circle())
                Text(title)
                    .font(.customFont(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.86))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.065))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
