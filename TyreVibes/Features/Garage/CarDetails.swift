import SwiftUI

extension String {
    func toUIImage() -> UIImage? {
        guard let data = Data(base64Encoded: self),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }
}

// MARK: - Advanced Animation Helpers
struct SpringAnimation {
    static let gentle = Animation.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.1)
    static let bouncy = Animation.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0.1)
    static let snappy = Animation.spring(response: 0.2, dampingFraction: 0.9, blendDuration: 0.1)
    static let fluid = Animation.interpolatingSpring(stiffness: 300, damping: 30)
}

fileprivate func formatVehicleInfoDate(_ dateString: String?) -> String {
    guard let rawDate = dateString?.trimmingCharacters(in: .whitespacesAndNewlines), !rawDate.isEmpty else {
        return "N/A"
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")

    let outputFormatter = DateFormatter()
    outputFormatter.dateFormat = "d MMMM yyyy"
    outputFormatter.locale = Locale(identifier: "it_IT")

    let inputFormats = [
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
        "yyyy-MM-dd"
    ]

    for format in inputFormats {
        formatter.dateFormat = format
        if let date = formatter.date(from: rawDate) {
            return outputFormatter.string(from: date)
        }
    }

    return rawDate
}

fileprivate func parseVehicleInfoDate(_ dateString: String?) -> Date? {
    guard let rawDate = dateString?.trimmingCharacters(in: .whitespacesAndNewlines), !rawDate.isEmpty else {
        return nil
    }

    let isoFormatter = DateFormatter()
    isoFormatter.locale = Locale(identifier: "en_US_POSIX")
    isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)

    let isoFormats = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd"
    ]

    for format in isoFormats {
        isoFormatter.dateFormat = format
        if let date = isoFormatter.date(from: rawDate) {
            return date
        }
    }

    let itFormatter = DateFormatter()
    itFormatter.locale = Locale(identifier: "it_IT_POSIX")
    itFormatter.timeZone = TimeZone(secondsFromGMT: 0)

    let localizedFormats = [
        "dd/MM/yyyy",
        "MM/yyyy"
    ]

    for format in localizedFormats {
        itFormatter.dateFormat = format
        if let date = itFormatter.date(from: rawDate) {
            return date
        }
    }

    if let year = Int(rawDate), year > 1900 {
        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = 1
        return Calendar(identifier: .gregorian).date(from: components)
    }

    return nil
}

struct RevisionForecastDisplay: Identifiable, Hashable {
    let id = UUID()
    let index: Int
    let isoDateString: String
    let context: String
    let detail: String?
    let relativeText: String?
}

fileprivate func makeRevisionForecasts(for vehicle: VehicleResponse, limit: Int = 2) -> [RevisionForecastDisplay] {
    guard limit > 0 else { return [] }
    let calendar = Calendar(identifier: .gregorian)
    let now = Date()

    let isoFormatter = DateFormatter()
    isoFormatter.dateFormat = "yyyy-MM-dd"
    isoFormatter.locale = Locale(identifier: "en_US_POSIX")
    isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)

    let relativeFormatter = RelativeDateTimeFormatter()
    relativeFormatter.locale = Locale(identifier: "it_IT")
    relativeFormatter.unitsStyle = .full

    let revisionDates = (vehicle.revisions ?? [])
        .compactMap { parseVehicleInfoDate($0.dataRevisione) }
        .sorted()

    var firstDueDate: Date?
    var firstContext = ""
    var firstDetail: String? = nil
    var baseDate: Date? = nil

    if let lastRevisionDate = revisionDates.last {
        firstDueDate = calendar.date(byAdding: DateComponents(year: 2), to: lastRevisionDate)
        baseDate = lastRevisionDate
        let formattedBase = formatVehicleInfoDate(isoFormatter.string(from: lastRevisionDate))
        firstContext = "Stima basata sull'ultima revisione registrata."
        firstDetail = "Ultima revisione: \(formattedBase)."
    } else if let registrationDate = parseVehicleInfoDate(vehicle.plate?.registrationDate) {
        firstDueDate = calendar.date(byAdding: DateComponents(year: 4), to: registrationDate)
        baseDate = registrationDate
        let formattedBase = formatVehicleInfoDate(isoFormatter.string(from: registrationDate))
        firstContext = "Prima revisione obbligatoria dopo 4 anni dall'immatricolazione."
        firstDetail = "Immatricolazione: \(formattedBase)."
    } else if let year = vehicle.plate?.year {
        var components = DateComponents()
        components.year = year
        components.month = vehicle.plate?.month ?? 1
        components.day = 1

        if let approxRegistration = calendar.date(from: components) {
            let offsetYears = revisionDates.isEmpty ? 4 : 2
            firstDueDate = calendar.date(byAdding: DateComponents(year: offsetYears), to: approxRegistration)
            baseDate = approxRegistration

            let monthFormatter = DateFormatter()
            monthFormatter.locale = Locale(identifier: "it_IT")
            monthFormatter.dateFormat = "MMMM yyyy"

            let approximateString = monthFormatter.string(from: approxRegistration).capitalized
            firstContext = offsetYears == 4
                ? "Prima revisione stimata dopo 4 anni dall'immatricolazione."
                : "Revisione stimata dopo 2 anni dalla data di riferimento."
            firstDetail = "Immatricolazione stimata: \(approximateString)."
        }
    }

    guard let initialDueDate = firstDueDate else {
        return []
    }

    var forecasts: [RevisionForecastDisplay] = []
    var currentDueDate: Date? = initialDueDate
    var previousDate: Date? = baseDate

    for index in 0..<limit {
        guard let dueDate = currentDueDate else { break }

        let isoDate = isoFormatter.string(from: dueDate)
        let relativeText: String?
        if dueDate > now {
            relativeText = relativeFormatter.localizedString(for: dueDate, relativeTo: now)
        } else {
            relativeText = nil
        }

        let context: String
        let detail: String?

        if index == 0 {
            context = firstContext.isEmpty ? "Revisione prevista calcolata automaticamente." : firstContext
            detail = firstDetail
        } else {
            let referenceDate = previousDate ?? dueDate
            let formattedReference = formatVehicleInfoDate(isoFormatter.string(from: referenceDate))
            context = "Revisione periodica programmata (intervallo biennale)."
            detail = "Successiva alla revisione prevista per \(formattedReference)."
        }

        forecasts.append(
            RevisionForecastDisplay(
                index: index,
                isoDateString: isoDate,
                context: context,
                detail: detail,
                relativeText: relativeText
            )
        )

        previousDate = dueDate
        currentDueDate = calendar.date(byAdding: DateComponents(year: 2), to: dueDate)
    }

    return forecasts
}

struct InsuranceForecastDisplay: Identifiable, Hashable {
    let id = UUID()
    let index: Int
    let isoDateString: String
    let context: String
    let detail: String?
    let relativeText: String?
}

fileprivate func makeInsuranceForecasts(for vehicle: VehicleResponse, limit: Int = 2) -> [InsuranceForecastDisplay] {
    guard limit > 0 else { return [] }

    let calendar = Calendar(identifier: .gregorian)
    let now = Date()

    let isoFormatter = DateFormatter()
    isoFormatter.dateFormat = "yyyy-MM-dd"
    isoFormatter.locale = Locale(identifier: "en_US_POSIX")
    isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)

    let relativeFormatter = RelativeDateTimeFormatter()
    relativeFormatter.locale = Locale(identifier: "it_IT")
    relativeFormatter.unitsStyle = .full

    let insuranceDates: [(VehicleInsurance, Date)] = (vehicle.insurances ?? [])
        .compactMap { insurance in
            guard let date = parseVehicleInfoDate(insurance.rcaExpiry) else { return nil }
            return (insurance, date)
        }

    var firstDueDate: Date?
    var firstInsurance: VehicleInsurance?
    var firstContext = ""
    var firstDetail: String? = nil
    var baseDate: Date?

    if let latest = insuranceDates.max(by: { $0.1 < $1.1 }) {
        firstInsurance = latest.0
        baseDate = latest.1

        var adjustedDue = latest.1
        var rolloverCount = 0
        while adjustedDue <= now {
            guard let bumped = calendar.date(byAdding: DateComponents(year: 1), to: adjustedDue) else { break }
            adjustedDue = bumped
            rolloverCount += 1
        }
        firstDueDate = adjustedDue

        let formattedBase = formatVehicleInfoDate(isoFormatter.string(from: latest.1))
        if rolloverCount == 0 {
            firstContext = "Scadenza della polizza registrata."
            firstDetail = "Compagnia: \(latest.0.rcaCompany ?? "Sconosciuta")."
        } else {
            firstContext = "Rinnovo stimato a un anno dall'ultima scadenza registrata."
            firstDetail = "Ultima scadenza: \(formattedBase)."
        }
    } else if let registrationDate = parseVehicleInfoDate(vehicle.plate?.registrationDate) {
        firstDueDate = calendar.date(byAdding: DateComponents(year: 1), to: registrationDate)
        baseDate = registrationDate
        let formattedBase = formatVehicleInfoDate(isoFormatter.string(from: registrationDate))
        firstContext = "Prima scadenza stimata a un anno dall'immatricolazione."
        firstDetail = "Immatricolazione: \(formattedBase)."
    } else if let year = vehicle.plate?.year {
        var components = DateComponents()
        components.year = year
        components.month = vehicle.plate?.month ?? 1
        components.day = 1

        if let approximate = calendar.date(from: components) {
            firstDueDate = calendar.date(byAdding: DateComponents(year: 1), to: approximate)
            baseDate = approximate

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "it_IT")
            formatter.dateFormat = "MMMM yyyy"
            let approxString = formatter.string(from: approximate).capitalized
            firstContext = "Scadenza assicurativa stimata dalla data di immatricolazione."
            firstDetail = "Immatricolazione stimata: \(approxString)."
        }
    }

    guard let initialDueDate = firstDueDate else {
        return []
    }

    var forecasts: [InsuranceForecastDisplay] = []
    var currentDueDate: Date? = initialDueDate
    var previousDate: Date? = baseDate
    var lastInsurance = firstInsurance

    for index in 0..<limit {
        guard let dueDate = currentDueDate else { break }

        let isoDate = isoFormatter.string(from: dueDate)
        let relativeText: String?
        if dueDate > now {
            relativeText = relativeFormatter.localizedString(for: dueDate, relativeTo: now)
        } else {
            relativeText = nil
        }

        let context: String
        let detail: String?

        if index == 0 {
            context = firstContext.isEmpty ? "Scadenza assicurativa stimata." : firstContext
            if let company = lastInsurance?.rcaCompany, !company.isEmpty {
                detail = firstDetail ?? "Compagnia: \(company)."
            } else {
                detail = firstDetail
            }
        } else {
            let referenceDate = previousDate ?? dueDate
            let formattedReference = formatVehicleInfoDate(isoFormatter.string(from: referenceDate))
            context = "Rinnovo annuale programmato."
            detail = "Successivo alla scadenza prevista per \(formattedReference)."
        }

        forecasts.append(
            InsuranceForecastDisplay(
                index: index,
                isoDateString: isoDate,
                context: context,
                detail: detail,
                relativeText: relativeText
            )
        )

        previousDate = dueDate
        lastInsurance = nil
        currentDueDate = calendar.date(byAdding: DateComponents(year: 1), to: dueDate)
    }

    return forecasts
}

fileprivate struct TyreInsightDisplay: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let detail: String?
    let isoDateString: String?
    let relativeText: String?
    let accentColor: Color
    let icon: String
}

fileprivate enum TyreSeasonType {
    case winter
    case summer
    case allSeason
    case unknown

    init(from raw: String?) {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !raw.isEmpty else {
            self = .unknown
            return
        }

        if raw.contains("winter") || raw.contains("invern") {
            self = .winter
        } else if raw.contains("summer") || raw.contains("estiv") {
            self = .summer
        } else if raw.contains("all") || raw.contains("4") || raw.contains("four") {
            self = .allSeason
        } else {
            self = .unknown
        }
    }
}

fileprivate func parseDOTDate(_ dotString: String?) -> Date? {
    guard let raw = dotString?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
        return nil
    }

    let digits = raw.filter { $0.isNumber }
    guard digits.count >= 4 else { return nil }

    let lastFour = String(digits.suffix(4))
    guard let week = Int(lastFour.prefix(2)), let yearSuffix = Int(lastFour.suffix(2)), (1...53).contains(week) else {
        return nil
    }

    let calendar = Calendar(identifier: .iso8601)
    let currentYear = calendar.component(.year, from: Date())
    var year = 2000 + yearSuffix
    if year > currentYear + 1 {
        year -= 100
    }

    var components = DateComponents()
    components.yearForWeekOfYear = year
    components.weekOfYear = week
    components.weekday = 4 // Thursday to stay within the ISO week

    return calendar.date(from: components)
}

fileprivate func makeTyreInsights(from tyres: [TyreRegistered]) -> [TyreInsightDisplay] {
    guard !tyres.isEmpty else { return [] }

    var insights: [TyreInsightDisplay] = []
    let now = Date()
    let calendar = Calendar(identifier: .gregorian)

    let isoFormatter = DateFormatter()
    isoFormatter.dateFormat = "yyyy-MM-dd"
    isoFormatter.locale = Locale(identifier: "en_US_POSIX")
    isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)

    let relativeFormatter = RelativeDateTimeFormatter()
    relativeFormatter.locale = Locale(identifier: "it_IT")
    relativeFormatter.unitsStyle = .full

    // 1. Highlight oldest DOT
    let tyresWithDOT = tyres.compactMap { tyre -> (TyreRegistered, Date)? in
        guard let dotDate = parseDOTDate(tyre.dot) else { return nil }
        return (tyre, dotDate)
    }

    if let oldest = tyresWithDOT.min(by: { $0.1 < $1.1 }) {
        let ageYears = max(calendar.dateComponents([.year], from: oldest.1, to: now).year ?? 0, 0)

        let (color, icon, message): (Color, String, String) = {
            if ageYears >= 6 {
                return (.red, "exclamationmark.triangle.fill", "Il DOT ha oltre \(ageYears) anni: pianifica la sostituzione quanto prima.")
            } else if ageYears >= 4 {
                return (.orange, "exclamationmark.circle.fill", "DOT di \(ageYears) anni: programma un controllo dello stato d'usura.")
            } else {
                return (.green, "checkmark.seal.fill", "DOT di \(ageYears) anni: gli pneumatici risultano ancora giovani.")
            }
        }()

        let manufactureISO = isoFormatter.string(from: oldest.1)
        let detail = "\(oldest.0.brand) \(oldest.0.model) • DOT \(oldest.0.dot)"

        insights.append(
            TyreInsightDisplay(
                title: "Età pneumatici",
                message: message,
                detail: detail,
                isoDateString: manufactureISO,
                relativeText: nil,
                accentColor: color,
                icon: icon
            )
        )
    }

    // 2. Seasonal reminders
    let seasonSet = Set(tyres.map { TyreSeasonType(from: $0.season) })

    func nextSeasonEvent(for season: TyreSeasonType) -> (Date, String, String, Color, String)? {
        let year = calendar.component(.year, from: now)
        guard let spring = calendar.date(from: DateComponents(year: year, month: 4, day: 15)),
              let autumn = calendar.date(from: DateComponents(year: year, month: 11, day: 15)) else {
            return nil
        }

        switch season {
        case .winter:
            if now < autumn {
                return (autumn, "Cambio gomme invernali", "Dal 15 novembre scatta l'obbligo: prepara il set invernale.", .blue, "snowflake")
            } else if let nextSpring = calendar.date(from: DateComponents(year: year + 1, month: 4, day: 15)) {
                return (nextSpring, "Ritorno alle estive", "Entro il 15 aprile puoi rimontare le gomme estive.", .mint, "sun.max.fill")
            }
        case .summer:
            if now < spring {
                return (spring, "Prepara le gomme estive", "Dal 15 aprile puoi tornare alle estive se le condizioni lo permettono.", .mint, "sun.max.fill")
            } else if now < autumn {
                return (autumn, "Prepara le gomme invernali", "Verso il 15 novembre monta il set invernale per rispettare l'obbligo.", .blue, "snowflake")
            } else if let nextSpring = calendar.date(from: DateComponents(year: year + 1, month: 4, day: 15)) {
                return (nextSpring, "Prepara le gomme estive", "Dal 15 aprile del prossimo anno torna alle estive.", .mint, "sun.max.fill")
            }
        case .allSeason, .unknown:
            return nil
        }

        return nil
    }

    var seasonalKeys: Set<String> = []
    for season in seasonSet {
        guard let event = nextSeasonEvent(for: season) else { continue }
        let isoDate = isoFormatter.string(from: event.0)
        let relative = event.0 > now ? relativeFormatter.localizedString(for: event.0, relativeTo: now) : nil
        let key = "\(event.1)-\(isoDate)"

        if !seasonalKeys.contains(key) {
            seasonalKeys.insert(key)
            insights.append(
                TyreInsightDisplay(
                    title: event.1,
                    message: event.2,
                    detail: nil,
                    isoDateString: isoDate,
                    relativeText: relative,
                    accentColor: event.3,
                    icon: event.4
                )
            )
        }
    }

    return insights
}

struct GlassCardStyle: ViewModifier {
    let isSelected: Bool
    let gradientColors: [Color]
    @State private var isHovered = false
    @State private var glowIntensity: Double = 0.0
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base glass background
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: gradientColors.map { $0.opacity(isSelected ? 0.8 : 0.3) },
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )
                        .shadow(
                            color: gradientColors.first?.opacity(isSelected ? 0.3 : 0.1) ?? .clear,
                            radius: isSelected ? 20 : 8,
                            x: 0,
                            y: isSelected ? 10 : 5
                        )
                    
                    // Animated glow effect
                    if isSelected {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        gradientColors.first?.opacity(0.2) ?? .clear,
                                        .clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 100
                                )
                            )
                            .scaleEffect(1.1 + glowIntensity * 0.2)
                            .opacity(0.8)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                                    glowIntensity = 1.0
                                }
                            }
                    }
                    
                    // Shimmer effect
                    if isSelected {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .clear,
                                        .white.opacity(0.1),
                                        .clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .rotationEffect(.degrees(45))
                            .offset(x: isSelected ? 200 : -200)
                            .animation(
                                .linear(duration: 1.5).repeatForever(autoreverses: false),
                                value: isSelected
                            )
                            .clipped()
                    }
                }
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(SpringAnimation.bouncy, value: isSelected)
    }
}

struct CarDetailsView: View {
    let vehicle: VehicleResponse
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tyreViewModel = TyreViewModel()
    @StateObject private var paywallManager = PaywallManager.shared
    @State private var showTyreRegistration: Bool = false
    @State private var showTyreDetails: Bool = false
    @State private var showInfoDialog: Bool = false
    @State private var infoDialogOffset: CGFloat = 0
    @State private var showPremiumScreen = false
    @State private var selectedRevisionIndex: Int? = nil
    @State private var selectedTyreIndex: Int? = nil
    @State private var selectedInsuranceIndex: Int? = nil
    @State private var selectedTyre: TyreRegistered? = nil
    @State private var show360View: Bool = false
    @State private var loadingProgress: Double = 0.0
    @State private var isLoading360: Bool = false
    @AppStorage("hasSeenDetailsHint") private var hasSeenDetailsHint: Bool = false
    @State private var showFirstTimeHint = false




    var body: some View {
        NavigationStack {
            ZStack {
                Color.customBackgroundColor.ignoresSafeArea()

                VStack {
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .resizable()
                                .frame(width: 15, height: 24)
                                .foregroundColor(.white)
                        }
                        Spacer()
                        
                        
                        VStack {
                            Text("\(vehicle.vehicle.make ?? "") \(vehicle.vehicle.model ?? "")")
                                .font(.customFont(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                    }


                    
                                
                    VStack(alignment: .leading, spacing: 20) {

                        // Car Image with 360 button
                        ZStack(alignment: .topTrailing) {
                            if let base64String = vehicle.image?.imageBase64,
                               let uiImage = base64String.toUIImage() {
                                let trimmed = uiImage.trimmedTransparentPixels(threshold: 5)

                                Image(uiImage: trimmed)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 50)
                                    .padding(.horizontal, 30)
                            } else {
                                Image("placeholder")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity)
                            }

                            
                        }
                            //.padding(.horizontal)

                        // Details Section
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(LocalizedStringKey("Technical Specs"))
                                    .font(.customFont(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                                
                                Button(action: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                        showInfoDialog = true
                                    }
                                }) {
                                    Button(action: {
                                        show360View = true
                                    }) {
                                        Image(systemName: "arkit")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                            .foregroundColor(.white)
                                            .padding(.leading, 4)
                                    }
                                    Image(systemName: "info.circle")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(.white)
                                        .padding(.leading, 4)
                                }
 
                            }
                            

                            // Details Grid
                            LazyVGrid(columns: [
                                GridItem(.flexible(), alignment: .leading),
                                GridItem(.flexible(), alignment: .leading),
                                GridItem(.flexible(), alignment: .leading)
                            ], spacing: 10) {
                                DetailItem(label: String(localized: "Make"), value: vehicle.vehicle.make?.uppercased() ?? "-")
                                DetailItem(label: String(localized: "Year"), value: vehicle.plate?.year.map { "\($0)" } ?? "-")
                                DetailItem(label: String(localized: "Color"), value: vehicle.vehicle.color?.uppercased() ?? "-")
                                DetailItem(label: String(localized: "Model"), value: vehicle.vehicle.model?.uppercased() ?? "-")
                                DetailItem(label: String(localized: "Engine"), value: vehicle.vehicle.engine?.uppercased() ?? "-")
                                DetailItem(label: String(localized: "License plate"), value: vehicle.plate?.plateNumber.uppercased() ?? "-")
                                DetailItem(label: String(localized: "Alimentazione"), value: vehicle.vehicle.fuelType?.uppercased() ?? "-")
                                DetailItem(label: String(localized: "Horsepower"), value: vehicle.vehicle.powerCV.map { "\($0) CV" } ?? "-")
                                DetailItem(label: String(localized: "Emission Class"), value: vehicle.vehicle.emissionClass?.uppercased() ?? "-")
                            }
                        }
                        .padding()
                        .background(Color.customFieldColor)
                        .cornerRadius(14)

                        Text(LocalizedStringKey("Add Your Tyres"))
                            .font(.customFont(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                // Add Button (sempre visibile)
                                Button(action: {
                                    // Verifica se l'utente può aggiungere altri pneumatici
                                    let tireCount = tyreViewModel.tyres.count
                                    if paywallManager.canAddTire(currentCount: tireCount) {
                                        showTyreRegistration = true
                                    } else {
                                        paywallManager.showPaywall(for: .unlimitedTires)
                                    }
                                }) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.customFieldColor)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Color.customGray, lineWidth: 1)
                                                    .frame(width: 188, height: 231)
                                            )
                                            .frame(width: 174, height: 215)

                                        Image("plusIcon")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 37, height: 37)
                                    }
                                }

                                // Shimmer durante il caricamento
                                if tyreViewModel.isLoading {
                                    ForEach(0..<2, id: \.self) { _ in
                                        TyreCardShimmer()
                                    }
                                }

                                // Registered Tyres
                                ForEach(tyreViewModel.registeredTyres) { tyre in
                                    Button(action: {
                                        selectedTyre = tyre
                                        showTyreDetails = true
                                    }) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color.customFieldColor)
                                                .frame(width: 188, height: 231)

                                            VStack {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.white.opacity(0.2))
                                                        .frame(width: 172, height: 122)
                                                        .cornerRadius(12)

                                                    Image("tyreSample")
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(width: 95, height: 100)
                                                        .clipped()
                                                }

                                                Text(tyre.brand)
                                                    .font(.customFont(size: 16, weight: .semibold))
                                                    .multilineTextAlignment(.center)
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                Spacer().frame(height: 6)
                                                Text(tyre.season)
                                                    .multilineTextAlignment(.center)
                                                    .font(.customFont(size: 16, weight: .semibold))
                                                    .foregroundColor(.white.opacity(0.6))
                                                Spacer().frame(height: 11)
                                                let radius: String = {
                                                    let parts = tyre.size.components(separatedBy: "R")
                                                    return parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : "-"
                                                }()
                                                Text("R\(radius)")
                                                    .font(.customFont(size: 16, weight: .semibold))
                                                    .multilineTextAlignment(.center)
                                                    .foregroundColor(.white)
                                                    .padding(.bottom, 10)

                                            }

                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 9)
                            .padding(.horizontal, 8)
                        }

                    }
                }
                .padding(.horizontal,24)

            }
            .navigationBarBackButtonHidden(true)
            .onAppear {
                tyreViewModel.fetchTyres(vehicleId: vehicle.vehicle.id)
                paywallManager.updatePremiumStatus()
                if hasSeenDetailsHint == false {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        showFirstTimeHint = true
                        hasSeenDetailsHint = true
                    }
                }
            }
            .sheet(isPresented: $showInfoDialog) {
                AdvancedInfoSheet(
                    vehicle: vehicle,
                    registeredTyres: tyreViewModel.tyres,
                    selectedRevisionIndex: $selectedRevisionIndex,
                    selectedTyreIndex: $selectedTyreIndex,
                    selectedInsuranceIndex: $selectedInsuranceIndex,
                    tyreViewModel: tyreViewModel
                )
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium, .large])
            }
            .fullScreenCover(isPresented: $showTyreRegistration) {
                TyreRegistrationView(
                    onConfirmCompletion: {
                        showTyreRegistration = false
                        tyreViewModel.fetchTyres(vehicleId: vehicle.vehicle.id)
                    },
                    vehicleid: vehicle.vehicle.id
                )
            }
            .fullScreenCover(isPresented: $showTyreDetails) {
                if let selectedTyre = selectedTyre {
                    TyreDetailView(tyre: selectedTyre) {
                        showTyreDetails = false
                    }
                }
            }
            .fullScreenCover(isPresented: $showPremiumScreen) {
                PremiumSubscriptionScreen()
            }
            .sheet(isPresented: $show360View) {
                if let make = vehicle.vehicle.make,
                   let model = vehicle.vehicle.model,
                   let year = vehicle.plate?.year {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                show360View = false
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding()
                        }

                        Vehicle360View(
                            make: make.lowercased(),
                            modelFamily: model.lowercased().components(separatedBy: " ").first ?? model.lowercased(),
                            year: "\(year)",
                            paintId: vehicle.vehicle.color?.uppercased() ?? "BLACK",
                            loadingProgress: $loadingProgress,
                            isLoading: $isLoading360
                        )

                        Text("Trascina per ruotare")
                            .font(.customFont(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.top, 20)

                        Spacer()
                    }
                    .background(Color.customBackgroundColor.ignoresSafeArea())
                }
            }
            .overlay(
                Group {
                    if paywallManager.showPaywall, let feature = paywallManager.paywallFeature {
                        PaywallView(
                            feature: feature,
                            onDismiss: {
                                withAnimation {
                                    paywallManager.showPaywall = false
                                }
                            },
                            onUpgrade: {
                                withAnimation {
                                    paywallManager.showPaywall = false
                                }
                                showPremiumScreen = true
                            }
                        )
                        .transition(.opacity)
                    }
                }
        )
        .alert("Benvenuto", isPresented: $showFirstTimeHint) {
            Button("Ho capito") { showFirstTimeHint = false }
        } message: {
            Text("Qui trovi due funzioni utili: il pulsante AR mostra la vista 360° della tua auto, mentre il pulsante info ti dà dettagli avanzati sul veicolo.")
        }
        }
    }
    
    
    
    
}

struct AdvancedInfoSheet: View {
    let vehicle: VehicleResponse
    let registeredTyres: [TyreRegistered]
    @Binding var selectedRevisionIndex: Int?
    @Binding var selectedTyreIndex: Int?
    @Binding var selectedInsuranceIndex: Int?
    @ObservedObject var tyreViewModel: TyreViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var currentTab = 0
    @State private var tabSelectorOffset: CGFloat = 0
    @State private var isTabTransitioning = false
    
    private var tabs: [String] {
        [
            String(localized: "Cronologia Revisioni"),
            String(localized: "Add Your Tyres"),
            String(localized: "Assicurazione")
        ]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and done button
            HStack {
                Text(LocalizedStringKey("Vehicle Info"))
                    .font(.customFont(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                if #available(iOS 26.0, *) {
                    Button(action: { dismiss() }) {
                        Text(LocalizedStringKey("Done"))
                            .font(.customFont(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.glass)
                } else {
                    // Fallback on earlier versions
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)
            
            // Enhanced Tab Picker with Liquid Glass Design
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                        let isSelected = currentTab == index
                        
                        Button(action: {
                            withAnimation(SpringAnimation.bouncy) {
                                currentTab = index
                                isTabTransitioning = true
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isTabTransitioning = false
                            }
                        }) {
                            VStack(spacing: 8) {
                                HStack(spacing: 6) {
                                    // Tab Icon
                                    Image(systemName: tabIcon(for: index))
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                                        .scaleEffect(isSelected ? 1.1 : 1.0)
                                        .animation(SpringAnimation.snappy, value: isSelected)
                                    
                                    Text(tab)
                                        .font(.customFont(size: 14, weight: .semibold))
                                        .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                                }
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.ultraThinMaterial)
                                        .opacity(isSelected ? 1.0 : 0.0)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    LinearGradient(
                                                        colors: tabGradientColors(for: index),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: isSelected ? 2 : 0
                                                )
                                                .opacity(isSelected ? 0.8 : 0.0)
                                        )
                                        .shadow(
                                            color: tabGradientColors(for: index).first?.opacity(0.3) ?? .clear,
                                            radius: isSelected ? 10 : 0,
                                            x: 0,
                                            y: isSelected ? 5 : 0
                                        )
                                )
                                .animation(SpringAnimation.fluid, value: isSelected)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 10)
            }
            .background(.thinMaterial)
            
            // Content with spectacular transition animations
            ZStack {
                if currentTab == 0 {
                    AdvancedRevisionsTable(
                        revisions: vehicle.revisions ?? [],
                        forecastRevisions: makeRevisionForecasts(for: vehicle),
                        selectedIndex: $selectedRevisionIndex
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                } else if currentTab == 1 {
                    AdvancedTyresTable(
                        tyres: vehicle.tyres ?? [],
                        registeredTyres: registeredTyres,
                        vehicleId: vehicle.vehicle.id,
                        selectedIndex: $selectedTyreIndex,
                        tyreViewModel: tyreViewModel
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
                } else {
                    AdvancedInsuranceTable(
                        insurances: vehicle.insurances ?? [],
                        forecastInsurances: makeInsuranceForecasts(for: vehicle),
                        selectedIndex: $selectedInsuranceIndex
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
            }
            .animation(SpringAnimation.fluid, value: currentTab)
            
            Spacer()
        }
        .background(
            LinearGradient(
                colors: [
                    Color.customBackgroundColor,
                    Color.customBackgroundColor.opacity(0.8),
                    Color.customFieldColor
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
    
    private func tabIcon(for index: Int) -> String {
        switch index {
        case 0: return "doc.text.magnifyingglass"
        case 1: return "car.circle"
        case 2: return "shield.checkered"
        default: return "questionmark"
        }
    }
    
    private func tabGradientColors(for index: Int) -> [Color] {
        switch index {
        case 0: return [.green, .mint] // Revisions
        case 1: return [.blue, .cyan] // Tyres
        case 2: return [.purple, .pink] // Insurance
        default: return [.gray, .gray]
        }
    }
}

struct AdvancedRevisionsTable: View {
    let revisions: [VehicleRevision]
    let forecastRevisions: [RevisionForecastDisplay]
    @Binding var selectedIndex: Int?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if revisions.isEmpty {
                    EmptyStateView(
                        icon: "doc.text.magnifyingglass",
                        title: String(localized: "Cronologia Revisioni"),
                        subtitle: forecastRevisions.isEmpty ? String(localized: "No data available") : String(localized: "No data available")
                    )
                } else {
                    ForEach(Array(revisions.enumerated()), id: \.offset) { index, revision in
                        RevisionRow(
                            revision: revision,
                            index: index,
                            isSelected: selectedIndex == index
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedIndex = selectedIndex == index ? nil : index
                            }
                        }
                        Divider().background(Color.customGray.opacity(0.5))
                    }
                }

                if !forecastRevisions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(LocalizedStringKey("Forecast Revisions"))
                            .font(.customFont(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 4)

                        ForEach(Array(forecastRevisions.enumerated()), id: \.element.id) { index, forecast in
                            ForecastRevisionRow(
                                forecast: forecast,
                                accentColor: accentColor(for: index)
                            )

                            if index < forecastRevisions.count - 1 {
                                Divider().background(Color.customGray.opacity(0.3))
                            }
                        }
                    }
                    .padding(.top, revisions.isEmpty ? 0 : 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
    }

    private func accentColor(for index: Int) -> Color {
        switch index {
        case 0: return .mint
        case 1: return .cyan
        default: return .blue
        }
    }
}

struct RevisionRow: View {
    let revision: VehicleRevision
    let index: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // Status Indicator
                    ZStack {
                        Circle()
                            .fill(statusColor.opacity(0.2))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: statusIcon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(statusColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(LocalizedStringKey("Revision #\(index + 1)"))
                                .font(.customFont(size: 16, weight: .semibold))
                                .foregroundColor(.white)

                            Spacer()

                            Text(formatVehicleInfoDate(revision.dataRevisione))
                                .font(.customFont(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }

                        HStack {
                            Text(revision.esitoRevisione ?? String(localized: "No data available"))
                                .font(.customFont(size: 14, weight: .medium))
                                .foregroundColor(statusColor)
                            
                            Spacer()
                            
                            if let km = revision.kmRevisione, !km.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "speedometer")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.6))
                                    
                                    Text("\(km) km")
                                        .font(.customFont(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .rotationEffect(.degrees(isSelected ? 90 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
                }
                .padding(16)
                
                if isSelected {
                    VStack(alignment: .leading, spacing: 12) {
                        Divider().background(Color.customGray)

                        DetailRowItem(icon: "calendar", label: String(localized: "Dettagli Revisione"), value: formatVehicleInfoDate(revision.dataRevisione))
                        DetailRowItem(icon: "checkmark.seal", label: String(localized: "Details"), value: revision.esitoRevisione ?? String(localized: "No data available"))
                        DetailRowItem(icon: "speedometer", label: String(localized: "Distance"), value: (revision.kmRevisione ?? "N/A") + " km")
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(isSelected ? 0.4 : 0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(statusColor.opacity(isSelected ? 0.5 : 0.2), lineWidth: 1)
                )
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
    
    private var statusColor: Color {
        guard let esito = revision.esitoRevisione?.lowercased() else { return .gray }
        
        if esito.contains("positive") || esito.contains("pass") || esito.contains("ok") {
            return .green
        } else if esito.contains("negative") || esito.contains("fail") || esito.contains("ko") {
            return .red
        } else {
            return .orange
        }
    }
    
    private var statusIcon: String {
        guard let esito = revision.esitoRevisione?.lowercased() else { return "questionmark.circle" }
        
        if esito.contains("positive") || esito.contains("pass") || esito.contains("ok") {
            return "checkmark.circle.fill"
        } else if esito.contains("negative") || esito.contains("fail") || esito.contains("ko") {
            return "xmark.circle.fill"
        } else {
            return "exclamationmark.circle.fill"
        }
    }
}

struct ForecastRevisionRow: View {
    let forecast: RevisionForecastDisplay
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.2))
                        .frame(width: 48, height: 48)

                    Circle()
                        .stroke(accentColor.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 48, height: 48)

                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(accentColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(LocalizedStringKey("Forecast #\(forecast.index + 1)"))
                            .font(.customFont(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        Spacer()

                        if let relative = forecast.relativeText {
                            Text(relative.capitalized)
                                .font(.customFont(size: 12, weight: .semibold))
                                .foregroundColor(accentColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(accentColor.opacity(0.15))
                                )
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))

                        Text(formatVehicleInfoDate(forecast.isoDateString))
                            .font(.customFont(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }

            Text(forecast.context)
                .font(.customFont(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.85))

            if let detail = forecast.detail {
                Text(detail)
                    .font(.customFont(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.25))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(accentColor.opacity(0.45), lineWidth: 1)
        )
    }
}

struct AdvancedTyresTable: View {
    let tyres: [VehicleTyre]
    let registeredTyres: [TyreRegistered]
    let vehicleId: Int
    @Binding var selectedIndex: Int?
    @ObservedObject var tyreViewModel: TyreViewModel

    // Enhanced filter states
    @State private var selectedRadius: Int? = nil
    @State private var selectedWidth: Int? = nil
    @State private var selectedRatio: Int? = nil
    @State private var selectedSpeedIndex: String? = nil
    @State private var selectedLoadIndex: String? = nil
    @State private var sortBy: TyreSortOption = .diameter
    @State private var sortAscending: Bool = true
    @State private var showFilters: Bool = false
    @State private var searchText: String = ""
    @State private var showSortDialog: Bool = false
    @State private var tyreToDelete: VehicleTyre? = nil
    @State private var showDeleteAlert: Bool = false

    private var tyreInsights: [TyreInsightDisplay] {
        makeTyreInsights(from: registeredTyres)
    }

    enum TyreSortOption: String, CaseIterable {
        case diameter = "Diametro"
        case width = "Larghezza"
        case ratio = "Rapporto"
        case speedIndex = "Indice Velocità"
        case loadIndex = "Indice Carico"
        
        var icon: String {
            switch self {
            case .diameter: return "circle"
            case .width: return "ruler"
            case .ratio: return "percent"
            case .speedIndex: return "speedometer"
            case .loadIndex: return "scalemass"
            }
        }
    }

    var body: some View {
        // Available options for filters
        let availableRadii = Array(Set(tyres.compactMap { $0.diameter })).sorted()
        let availableWidths = Array(Set(tyres.compactMap { $0.width })).sorted()
        let availableRatios = Array(Set(tyres.compactMap { $0.ratio })).sorted()
        let availableSpeedIndices = Array(Set(tyres.compactMap { $0.speedIndex }.filter { !$0.isEmpty })).sorted()
        let availableLoadIndices = Array(Set(tyres.compactMap { $0.loadIndex }.filter { !$0.isEmpty })).sorted()

        VStack(alignment: .leading, spacing: 0) {
            // Enhanced Filter Header
            VStack(spacing: 12) {
                // Search bar - full width
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))

                    TextField("Cerca pneumatici...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.customFont(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)

                // Filter and Sort controls
                HStack(spacing: 8) {
                    // Filter toggle
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showFilters.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: showFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .font(.system(size: 14, weight: .medium))
                            Text("Filtri")
                                .font(.customFont(size: 13, weight: .semibold))
                            if hasActiveFilters {
                                Text("(\(activeFilterTags.count))")
                                    .font(.customFont(size: 11, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(hasActiveFilters ? Color.orange.opacity(0.4) : Color.white.opacity(0.15))
                        .cornerRadius(8)
                    }

                    // Sort button - tap to change direction, long press for menu
                    Button(action: {
                        showSortDialog = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 12, weight: .medium))
                            Text(sortBy.rawValue)
                                .font(.customFont(size: 13, weight: .semibold))
                                .lineLimit(1)
                            Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.3))
                        .cornerRadius(8)
                    }
                    .confirmationDialog("Ordina per", isPresented: $showSortDialog, titleVisibility: .visible) {
                        // Sort by options
                        ForEach(TyreSortOption.allCases, id: \.self) { option in
                            Button(action: {
                                sortBy = option
                            }) {
                                HStack {
                                    Text(option.rawValue)
                                    if sortBy == option {
                                        Text("✓")
                                    }
                                }
                            }
                        }

                        Divider()

                        // Direction options
                        Button(action: {
                            sortAscending = true
                        }) {
                            HStack {
                                Text("Crescente")
                                if sortAscending {
                                    Text("✓")
                                }
                            }
                        }

                        Button(action: {
                            sortAscending = false
                        }) {
                            HStack {
                                Text("Decrescente")
                                if !sortAscending {
                                    Text("✓")
                                }
                            }
                        }

                        Button("Annulla", role: .cancel) {}
                    }

                    // Quick toggle direction button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            sortAscending.toggle()
                        }
                    }) {
                        Image(systemName: sortAscending ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.blue.opacity(0.3))
                            .cornerRadius(8)
                    }

                    Spacer()

                    // Reset button (visible only when filters active)
                    if hasActiveFilters {
                        Button(action: resetFilters) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Reset")
                                    .font(.customFont(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.4))
                            .cornerRadius(8)
                        }
                    }
                }

                // Expandable filters section - Grid Layout
                if showFilters {
                    VStack(spacing: 10) {
                        // First row - 3 filters
                        HStack(spacing: 8) {
                            FilterPicker(
                                title: "Raggio",
                                selection: $selectedRadius,
                                options: availableRadii,
                                formatOption: { "R\($0)" }
                            )

                            FilterPicker(
                                title: "Larghezza",
                                selection: $selectedWidth,
                                options: availableWidths,
                                formatOption: { "\($0)" }
                            )

                            FilterPicker(
                                title: "Rapporto",
                                selection: $selectedRatio,
                                options: availableRatios,
                                formatOption: { "\($0)%" }
                            )
                        }

                        // Second row - 2 filters
                        HStack(spacing: 8) {
                            FilterPicker(
                                title: "Velocità",
                                selection: $selectedSpeedIndex,
                                options: availableSpeedIndices,
                                formatOption: { $0 }
                            )

                            FilterPicker(
                                title: "Carico",
                                selection: $selectedLoadIndex,
                                options: availableLoadIndices,
                                formatOption: { $0 }
                            )

                            // Empty spacer to maintain layout
                            Spacer()
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Active filters chips
                if hasActiveFilters {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(activeFilterTags, id: \.self) { tag in
                                FilterTag(text: tag) {
                                    removeFilter(tag: tag)
                                }
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 16) {
                    let filteredAndSortedTyres: [(Int, VehicleTyre)] = {
                        // Apply all filters
                        let filtered = tyres.enumerated().filter { (_, tyre) in
                            // Search filter
                            if !searchText.isEmpty {
                                let searchLower = searchText.lowercased()
                                let tyreDescription = "\(tyre.width ?? 0)/\(tyre.ratio ?? 0) R\(tyre.diameter ?? 0) \(tyre.speedIndex ?? "") \(tyre.loadIndex ?? "")".lowercased()
                                if !tyreDescription.contains(searchLower) {
                                    return false
                                }
                            }
                            
                            // Diameter filter
                            if let selected = selectedRadius, tyre.diameter != selected {
                                return false
                            }
                            
                            // Width filter
                            if let selected = selectedWidth, tyre.width != selected {
                                return false
                            }
                            
                            // Ratio filter
                            if let selected = selectedRatio, tyre.ratio != selected {
                                return false
                            }
                            
                            // Speed index filter
                            if let selected = selectedSpeedIndex, tyre.speedIndex != selected {
                                return false
                            }
                            
                            // Load index filter
                            if let selected = selectedLoadIndex, tyre.loadIndex != selected {
                                return false
                            }
                            
                            return true
                        }
                        
                        // Sort by selected option
                        let sorted = filtered.sorted { lhs, rhs in
                            switch sortBy {
                            case .diameter:
                                let lhsValue = lhs.1.diameter ?? 0
                                let rhsValue = rhs.1.diameter ?? 0
                                return sortAscending ? (lhsValue < rhsValue) : (lhsValue > rhsValue)
                            case .width:
                                let lhsValue = lhs.1.width ?? 0
                                let rhsValue = rhs.1.width ?? 0
                                return sortAscending ? (lhsValue < rhsValue) : (lhsValue > rhsValue)
                            case .ratio:
                                let lhsValue = lhs.1.ratio ?? 0
                                let rhsValue = rhs.1.ratio ?? 0
                                return sortAscending ? (lhsValue < rhsValue) : (lhsValue > rhsValue)
                            case .speedIndex:
                                let lhsValue = lhs.1.speedIndex ?? ""
                                let rhsValue = rhs.1.speedIndex ?? ""
                                return sortAscending ? (lhsValue < rhsValue) : (lhsValue > rhsValue)
                            case .loadIndex:
                                let lhsValue = lhs.1.loadIndex ?? ""
                                let rhsValue = rhs.1.loadIndex ?? ""
                                return sortAscending ? (lhsValue < rhsValue) : (lhsValue > rhsValue)
                            }
                        }
                        return sorted
                    }()
                    
                    if tyres.isEmpty {
                        EmptyStateView(
                            icon: "car.circle",
                            title: "Nessun Pneumatico",
                            subtitle: "Non ci sono pneumatici disponibili"
                        )
                    } else if filteredAndSortedTyres.isEmpty {
                        EmptyStateView(
                            icon: "magnifyingglass",
                            title: "Nessun Risultato",
                            subtitle: "Nessun pneumatico corrisponde ai filtri selezionati"
                        )
                    } else {
                        ForEach(filteredAndSortedTyres, id: \.0) { index, tyre in
                            TyreRow(
                                tyre: tyre,
                                index: index,
                                isSelected: selectedIndex == index,
                                onTap: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedIndex = selectedIndex == index ? nil : index
                                    }
                                },
                                onLongPress: {
                                    tyreToDelete = tyre
                                    showDeleteAlert = true
                                }
                            )

                            if index < filteredAndSortedTyres.count - 1 {
                                Divider().background(Color.customGray.opacity(0.5))
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }

            if !tyreInsights.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tyre Smart Insights")
                        .font(.customFont(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        ForEach(tyreInsights) { insight in
                            TyreInsightRow(insight: insight)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 12)
            }
        }
        .alert(String(localized: "Delete"), isPresented: $showDeleteAlert) {
            Button(String(localized: "Cancel"), role: .cancel) {}
            Button(String(localized: "Delete"), role: .destructive) {
                if let tyreToDelete = tyreToDelete {
                    tyreViewModel.deleteTyre(tyreId: tyreToDelete.id, vehicleId: vehicleId) { success in
                        if success {
                            // Refresh list
                            tyreViewModel.fetchTyres(vehicleId: vehicleId, forceRefresh: true)
                        }
                    }
                }
            }
        } message: {
            Text(String(localized: "Are you sure you want to delete this tire?"))
        }
    }
    
    // MARK: - Helper Properties and Functions
    private var hasActiveFilters: Bool {
        selectedRadius != nil || selectedWidth != nil || selectedRatio != nil ||
        selectedSpeedIndex != nil || selectedLoadIndex != nil || !searchText.isEmpty
    }
    
    private var activeFilterTags: [String] {
        var tags: [String] = []
        
        if let radius = selectedRadius {
            tags.append("R\(radius)")
        }
        if let width = selectedWidth {
            tags.append("\(width)mm")
        }
        if let ratio = selectedRatio {
            tags.append("\(ratio)%")
        }
        if let speed = selectedSpeedIndex {
            tags.append("Vel: \(speed)")
        }
        if let load = selectedLoadIndex {
            tags.append("Carico: \(load)")
        }
        if !searchText.isEmpty {
            tags.append("'\(searchText)'")
        }
        
        return tags
    }
    
    private func resetFilters() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedRadius = nil
            selectedWidth = nil
            selectedRatio = nil
            selectedSpeedIndex = nil
            selectedLoadIndex = nil
            searchText = ""
        }
    }
    
    private func removeFilter(tag: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if tag.starts(with: "R") {
                selectedRadius = nil
            } else if tag.hasSuffix("mm") {
                selectedWidth = nil
            } else if tag.hasSuffix("%") {
                selectedRatio = nil
            } else if tag.starts(with: "Vel:") {
                selectedSpeedIndex = nil
            } else if tag.starts(with: "Carico:") {
                selectedLoadIndex = nil
            } else if tag.starts(with: "'") {
                searchText = ""
            }
        }
    }
}

// MARK: - Custom Filter Components
struct FilterPicker<T: Hashable>: View {
    let title: String
    @Binding var selection: T?
    let options: [T]
    let formatOption: (T) -> String

    @State private var showSheet = false

    var body: some View {
        Button(action: {
            showSheet = true
        }) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.customFont(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 4) {
                    if let selected = selection {
                        Text(formatOption(selected))
                            .font(.customFont(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    } else {
                        Text("Tutti")
                            .font(.customFont(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selection != nil ? Color.blue.opacity(0.25) : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(selection != nil ? Color.blue.opacity(0.4) : Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .confirmationDialog(title, isPresented: $showSheet, titleVisibility: .visible) {
            Button("Tutti") {
                selection = nil
            }

            ForEach(options, id: \.self) { option in
                Button(formatOption(option)) {
                    selection = option
                }
            }

            Button("Annulla", role: .cancel) {}
        }
    }
}

struct FilterTag: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.customFont(size: 12, weight: .medium))
                .foregroundColor(.white)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.3))
        .cornerRadius(12)
    }
}

struct TyreRow: View {
    let tyre: VehicleTyre
    let index: Int
    let isSelected: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // Tyre Icon
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "car.circle.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Tyre #\(index + 1)")
                                .font(.customFont(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            // Size badge
                            Text(tyreSize)
                                .font(.customFont(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.3))
                                .cornerRadius(8)
                        }
                        
                        HStack(spacing: 12) {
                            SpecBadge(label: "W", value: "\(tyre.width ?? 0)")
                            SpecBadge(label: "R", value: "\(tyre.ratio ?? 0)")
                            SpecBadge(label: "D", value: "R\(tyre.diameter ?? 0)")
                        }
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .rotationEffect(.degrees(isSelected ? 90 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
                }
                .padding(16)
                
                if isSelected {
                    VStack(alignment: .leading, spacing: 12) {
                        Divider().background(Color.customGray)
                        
                        HStack {
                            DetailRowItem(icon: "ruler", label: "Width", value: "\(tyre.width ?? 0) mm")
                            Spacer()
                            DetailRowItem(icon: "percent", label: "Ratio", value: "\(tyre.ratio ?? 0)%")
                        }
                        
                        HStack {
                            DetailRowItem(icon: "circle", label: "Diameter", value: "R\(tyre.diameter ?? 0)")
                            Spacer()
                            DetailRowItem(icon: "scalemass", label: "Load", value: tyre.loadIndex ?? "N/A")
                        }
                        
                        DetailRowItem(icon: "speedometer", label: "Speed Index", value: tyre.speedIndex ?? "N/A")
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(isSelected ? 0.4 : 0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(isSelected ? 0.5 : 0.2), lineWidth: 1)
                )
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        .onLongPressGesture(minimumDuration: 0.5) {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            onLongPress()
        }
    }
    
    private var tyreSize: String {
        let width = tyre.width ?? 0
        let ratio = tyre.ratio ?? 0
        let diameter = tyre.diameter ?? 0
        return "\(width)/\(ratio) R\(diameter)"
    }
}

struct TyreInsightRow: View {
    fileprivate let insight: TyreInsightDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(insight.accentColor.opacity(0.18))
                        .frame(width: 48, height: 48)

                    Circle()
                        .stroke(insight.accentColor.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 48, height: 48)

                    Image(systemName: insight.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(insight.accentColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(insight.title)
                            .font(.customFont(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        Spacer()

                        if let relative = insight.relativeText {
                            Text(relative.capitalized)
                                .font(.customFont(size: 12, weight: .semibold))
                                .foregroundColor(insight.accentColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(insight.accentColor.opacity(0.15))
                                )
                        }
                    }

                    if let isoDate = insight.isoDateString {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))

                            Text(formatVehicleInfoDate(isoDate))
                                .font(.customFont(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
            }

            Text(insight.message)
                .font(.customFont(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.85))

            if let detail = insight.detail {
                Text(detail)
                    .font(.customFont(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.25))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(insight.accentColor.opacity(0.4), lineWidth: 1)
        )
    }
}

struct SpecBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.customFont(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
            
            Text(value)
                .font(.customFont(size: 12, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(minWidth: 35)
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(Color.white.opacity(0.1))
        .cornerRadius(6)
    }
}

struct DetailRowItem: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.customFont(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                
                Text(value)
                    .font(.customFont(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 50, weight: .light))
                .foregroundColor(.white.opacity(0.3))
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.customFont(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(subtitle)
                    .font(.customFont(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}


struct DetailItem: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Rectangle()
                .inset(by: 0.5)
                .stroke(Color(red: 0.95, green: 0.4, blue: 0.34), lineWidth: 1)
                .frame(width: 1, height: 40)
                //.padding(.trailing, 4)
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.customFont(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                Text(value)
                    .font(.customFont(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

struct AdvancedInsuranceTable: View {
    let insurances: [VehicleInsurance]
    let forecastInsurances: [InsuranceForecastDisplay]
    @Binding var selectedIndex: Int?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if insurances.isEmpty {
                    EmptyStateView(
                        icon: "shield.checkered",
                        title: "Nessuna Assicurazione",
                        subtitle: forecastInsurances.isEmpty ? "Non ci sono assicurazioni registrate" : "Non ci sono assicurazioni registrate. Prossime scadenze stimate qui sotto."
                    )
                } else {
                    ForEach(Array(insurances.enumerated()), id: \.offset) { index, insurance in
                        InsuranceRow(
                            insurance: insurance,
                            index: index,
                            isSelected: selectedIndex == index
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedIndex = selectedIndex == index ? nil : index
                            }
                        }
                        Divider().background(Color.customGray.opacity(0.5))
                    }
                }

                if !forecastInsurances.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(LocalizedStringKey("Scadenze Stimate"))
                            .font(.customFont(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 4)

                        ForEach(Array(forecastInsurances.enumerated()), id: \.element.id) { index, forecast in
                            InsuranceForecastRow(
                                forecast: forecast,
                                accentColor: accentColor(for: index)
                            )

                            if index < forecastInsurances.count - 1 {
                                Divider().background(Color.customGray.opacity(0.3))
                            }
                        }
                    }
                    .padding(.top, insurances.isEmpty ? 0 : 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
    }

    private func accentColor(for index: Int) -> Color {
        switch index {
        case 0: return .orange
        case 1: return .yellow
        default: return .teal
        }
    }
}

enum InsuranceStatus {
    case inactive
    case expired
    case active

    var color: Color {
        switch self {
        case .inactive:
            return .gray
        case .expired:
            return .red
        case .active:
            return .green
        }
    }

    var icon: String {
        switch self {
        case .inactive:
            return "pause.circle.fill"
        case .expired:
            return "exclamationmark.triangle.fill"
        case .active:
            return "shield.checkered"
        }
    }

    var text: String {
        switch self {
        case .inactive:
            return "Inattiva"
        case .expired:
            return "Scaduta"
        case .active:
            return "Attiva"
        }
    }
}




struct InsuranceRow: View {
    let insurance: VehicleInsurance
    let index: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    private var isExpired: Bool {
        guard let expiryDateString = insurance.rcaExpiry else { return false }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let expiryDate = formatter.date(from: expiryDateString) else { return false }
        return expiryDate < Date()
    }

    private var insuranceStatus: InsuranceStatus {
        if insurance.rcaInsurancePresent == 0 {
            return .inactive
        } else if isExpired {
            return .expired
        } else {
            return .active
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // Status Indicator
                    ZStack {
                        Circle()
                            .fill(insuranceStatus.color.opacity(0.2))
                            .frame(width: 50, height: 50)

                        Image(systemName: insuranceStatus.icon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(insuranceStatus.color)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Polizza #\(index + 1)")
                                .font(.customFont(size: 16, weight: .semibold))
                                .foregroundColor(.white)

                            Spacer()

                            Text(insuranceStatus.text)
                                .font(.customFont(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(insuranceStatus.color.opacity(0.3))
                                .cornerRadius(8)
                        }

                        HStack {
                            Text(insurance.rcaCompany ?? "Compagnia sconosciuta")
                                .font(.customFont(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))

                            Spacer()

                            if let expiryDate = insurance.rcaExpiry {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.6))

                                    Text("Scade: \(formatVehicleInfoDate(expiryDate))")
                                        .font(.customFont(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .rotationEffect(.degrees(isSelected ? 90 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
                }
                .padding(16)

                if isSelected {
                    VStack(alignment: .leading, spacing: 12) {
                        Divider().background(Color.customGray)

                        HStack {
                            DetailRowItem(icon: "building.2", label: "Compagnia", value: insurance.rcaCompany ?? "N/A")
                            Spacer()
                            DetailRowItem(icon: "doc.text", label: "Numero Polizza", value: insurance.rcaPolicyNumber ?? "N/A")
                        }

                        HStack {
                            DetailRowItem(icon: "calendar.badge.exclamationmark", label: "Scadenza", value: formatVehicleInfoDate(insurance.rcaExpiry))
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(isSelected ? 0.4 : 0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(insuranceStatus.color.opacity(isSelected ? 0.5 : 0.2), lineWidth: 1)
                )
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
}

struct InsuranceForecastRow: View {
    let forecast: InsuranceForecastDisplay
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.2))
                        .frame(width: 48, height: 48)

                    Circle()
                        .stroke(accentColor.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 48, height: 48)

                    Image(systemName: "shield.checkered")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(accentColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(LocalizedStringKey("Forecast #\(forecast.index + 1)"))
                            .font(.customFont(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        Spacer()

                        if let relative = forecast.relativeText {
                            Text(relative.capitalized)
                                .font(.customFont(size: 12, weight: .semibold))
                                .foregroundColor(accentColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(accentColor.opacity(0.15))
                                )
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))

                        Text(formatVehicleInfoDate(forecast.isoDateString))
                            .font(.customFont(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }

            Text(forecast.context)
                .font(.customFont(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.85))

            if let detail = forecast.detail {
                Text(detail)
                    .font(.customFont(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.25))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(accentColor.opacity(0.45), lineWidth: 1)
        )
    }
}

