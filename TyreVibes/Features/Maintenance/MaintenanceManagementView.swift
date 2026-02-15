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
    @State private var showVINPrompt = false
    @State private var vinInput: String = ""
    @State private var selectedEntry: CompletedMaintenanceEntry?

    enum Section: String, CaseIterable {
        case planned = "Da fare"
        case completed = "Fatte"
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

    private var thisMonthCompleted: Int {
        let calendar = Calendar.current
        let now = Date()
        return completedItems.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }.count
    }

    private var totalCostThisMonth: Double {
        let calendar = Calendar.current
        let now = Date()
        return completedItems
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
            .compactMap(\.cost)
            .reduce(0, +)
    }

    var body: some View {
        VStack(spacing: 14) {
            header
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
            sectionSelector
            content
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .onAppear {
            scheduleStore.seedDefaultsIfNeeded(for: vehicleId)
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

    // MARK: - Mileage Update Banner

    private var mileageUpdateBanner: some View {
        Button {
            showMileagePrompt = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "speedometer")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.cyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Aggiorna chilometraggio")
                        .font(.customFont(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Per calcolare le scadenze in base ai km")
                        .font(.customFont(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.cyan.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.cyan.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Gestione manutenzione")
                    .font(.customFont(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text("Piano, storico e registrazioni manuali")
                    .font(.customFont(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.65))
            }

            Spacer()

            Button {
                showCostDashboard = true
            } label: {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.trailing, 8)

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
                } label: {
                    Label("Ricalcola scadenze", systemImage: "arrow.clockwise")
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
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
                title: "Scadute",
                value: "\(overdueCount)",
                color: .orange,
                icon: "exclamationmark.triangle.fill"
            )
            MaintenanceStatCard(
                title: "Questo mese",
                value: "\(thisMonthCompleted)",
                color: .green,
                icon: "checkmark.seal.fill"
            )
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
                    Text(section.rawValue)
                        .font(.customFont(size: 13, weight: .semibold))
                        .foregroundColor(selected ? .black : .white.opacity(0.8))
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule(style: .continuous)
                                .fill(selected ? Color.white : Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }
        }
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
        Group {
            if plannedItems.isEmpty {
                EmptyStateView(
                    icon: "calendar.badge.exclamationmark",
                    title: "Nessuna manutenzione pianificata",
                    subtitle: "Aggiungi il prossimo intervento dal pulsante in alto."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(plannedItems) { item in
                            MaintenancePlannedCard(
                                item: item,
                                onComplete: {
                                    scheduleStore.markCompleted(scheduleId: item.id, vehicleId: vehicleId)
                                },
                                onDelete: {
                                    scheduleStore.deleteSchedule(item.id)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var completedContent: some View {
        Group {
            if completedItems.isEmpty {
                EmptyStateView(
                    icon: "checkmark.circle",
                    title: "Nessuna manutenzione registrata",
                    subtitle: "Registra i lavori effettuati per avere storico e tracciamento."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(completedItems) { entry in
                            MaintenanceCompletedCard(entry: entry)
                                .onTapGesture {
                                    selectedEntry = entry
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
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
            RoundedRectangle(cornerRadius: 12)
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
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.25), lineWidth: 1)
        )
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
