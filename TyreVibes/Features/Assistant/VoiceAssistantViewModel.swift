import AVFoundation
import Foundation
import Speech
import SwiftUI

struct AssistantMessage: Identifiable, Equatable {
    enum Role {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    let text: String
    let timestamp: Date

    init(id: UUID = UUID(), role: Role, text: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }
}

struct AssistantUserStats: Equatable {
    let vehicleCount: Int?
    let maxVehicles: Int?
    let remainingVehicleSlots: Int?
    let isPremium: Bool
    let isPaywallEnabled: Bool
}

struct AssistantContext {
    let allNotifications: [AppNotification]
    let upcomingNotifications: [AppNotification]
    let unreadNotifications: [AppNotification]
    let userStats: AssistantUserStats?
    let highlightedVehicleSummary: String?
    let nextReminderSummary: String?

    static let empty = AssistantContext(
        allNotifications: [],
        upcomingNotifications: [],
        unreadNotifications: [],
        userStats: nil,
        highlightedVehicleSummary: nil,
        nextReminderSummary: nil
    )

    var criticalNotifications: [AppNotification] {
        allNotifications.filter { $0.priority == .critical }
    }

    var rotationReminders: [AppNotification] {
        allNotifications.filter { $0.type == .rotation || $0.type == .maintenanceReminder }
    }

    var seasonalReminders: [AppNotification] {
        allNotifications.filter { $0.type == .seasonalReminder }
    }

    var replacementReminders: [AppNotification] {
        allNotifications.filter { $0.type == .tyreReplacement }
    }
}

struct AssistantResponseGenerator {
    private enum FollowUpTopic {
        case maintenance
        case tread
        case rotation
        case seasonal
        case inspection
        case garage
        case general
    }

    private let maintenanceIntros = [
        "Ecco le priorita piu vicine.",
        "Questo e l'ordine delle scadenze in arrivo.",
        "Sto vedendo queste prossime occasioni per agire."
    ]

    private let treadTips = [
        "Per il battistrada, sotto i 3 mm conviene pianificare un cambio.",
        "Usura sotto i 3 mm: meglio prenotare la sostituzione piu avanti.",
        "Controlla il battistrada ogni 2-3 mesi per evitare sorprese."
    ]

    private let rotationTips = [
        "La rotazione aiuta a mantenere l'usura uniforme.",
        "Ogni 10.000 km e consigliabile ruotare le gomme.",
        "Guarda il manuale del costruttore per la sequenza giusta, ma la regola generale e 10.000 km."
    ]

    private let seasonalTips = [
        "Per il cambio stagionale valuta temperature e normative locali.",
        "Sotto i 7 gradi conviene passare alle gomme invernali.",
        "Le quattro stagioni vanno bene in climi miti, ma in inverno estremo preferisci dedicate."
    ]

    private let inspectionTips = [
        "Controlla battistrada, spalle, valvole e DOT durante l'ispezione.",
        "Se il volante vibra, valuta allineamento e bilanciamento.",
        "Un controllo completo include pressione, usura e possibile danno invisibile."
    ]

    private let generalIntros = [
        "Dimmi pure cosa ti serve.",
        "Sono qui per aiutarti con pneumatici e manutenzione.",
        "Indicami su quale punto vuoi concentrare l attenzione."
    ]

    private let followUpPrompts: [FollowUpTopic: [String]] = [
        .maintenance: [
            "Vuoi che ti ricordi la prossima scadenza con una notifica?",
            "Ti serve un promemoria sui dettagli della rotazione?",
            "Preferisci che ti invii un follow-up quando si avvicina la scadenza?"
        ],
        .tread: [
            "Vuoi che monitori l'usura e ti ricordi di controllare di nuovo entro due mesi?",
            "Ti interessa una guida su come misurare il battistrada correttamente?"
        ],
        .rotation: [
            "Desideri che ti solidarizzi un reminder per la prossima rotazione?",
            "Ti aiuto a pianificare il prossimo giro di rotazione?"
        ],
        .seasonal: [
            "Vuoi che ti ricordi il cambio stagionale in anticipo?",
            "Ti mando un promemoria sul passaggio alle gomme invernali quando serve?"
        ],
        .inspection: [
            "Ti serve che ti segnali un'officina consigliata per il controllo?",
            "Vuoi che ti guidi passo passo durante l'ispezione?"
        ],
        .garage: [
            "Hai bisogno di assistenza per aggiungere o rimuovere un veicolo?",
            "Ti serve un promemoria quando sei vicino al limite del piano?"
        ],
        .general: [
            "Vuoi che ti suggerisca qualche azione rapida?",
            "Ti interessa che ti proponga uno dei nostri suggerimenti?"
        ]
    ]

    func response(for input: String, context: AssistantContext) -> AssistantReply {
        let normalized = normalize(input)
        guard !normalized.isEmpty else {
            return AssistantReply(
                text: "Non ho sentito bene. Puoi ripetere?",
                followUp: randomFollowUp(for: .general)
            )
        }

        let mentionsVehicles = containsAny(normalized, keywords: ["veicol", "auto", "garage"])
        let asksVehicleCount = containsAny(normalized, keywords: ["quanti", "numero", "veicoli ho", "ho nel garage"])
        let asksVehicleLimit = containsAny(normalized, keywords: ["posso aggiungere", "quanti ne posso aggiungere", "limite", "massimo", "quota"])
        if (mentionsVehicles && (asksVehicleCount || asksVehicleLimit)) || asksVehicleLimit {
            return garageStatusResponse(context: context)
        }

        if containsAny(normalized, keywords: ["prossim", "manutenzione", "promemoria", "cosa devo fare", "scadenza", "consigli"]) {
            return upcomingMaintenanceResponse(context: context)
        }

        if containsAny(normalized, keywords: ["battistrada", "usura", "tread", "profondita", "consumo"]) {
            return treadResponse(context: context)
        }

        if containsAny(normalized, keywords: ["rotazione", "invert", "anteriore", "posteriore"]) {
            return rotationResponse(context: context)
        }

        if containsAny(normalized, keywords: ["stagion", "invern", "estiv", "quattro stagioni"]) {
            return seasonalResponse(context: context)
        }

        if containsAny(normalized, keywords: ["controllo", "ispezione", "check", "allineamento", "bilanciamento"]) {
            return inspectionResponse(context: context)
        }

        return generalResponse(context: context)
    }

    func welcomeResponse(context: AssistantContext) -> AssistantReply {
        generalResponse(context: context)
    }

    private func upcomingMaintenanceResponse(context: AssistantContext) -> AssistantReply {
        let upcoming = context.upcomingNotifications.sorted { $0.priority.sortOrder < $1.priority.sortOrder }
        if upcoming.isEmpty {
            return AssistantReply(
                text: "Non vedo scadenze imminenti. Ti consiglio un controllo battistrada ogni 2 o 3 mesi.",
                followUp: randomFollowUp(for: .maintenance)
            )
        }

        let summary = summarizeNotifications(upcoming, limit: 2)
        let opener = maintenanceIntros.randomElement() ?? "Ecco le priorità più vicine."
        var text = "\(opener) \(summary) Vuoi che entriamo nei dettagli su rotazione, battistrada o cambio stagionale?"
        if let vehicleHint = contextVehicleHint(context) {
            text += " \(vehicleHint)"
        }
        return AssistantReply(text: text, followUp: randomFollowUp(for: .maintenance))
    }

    private func treadResponse(context: AssistantContext) -> AssistantReply {
        if let alert = context.replacementReminders.first {
            return AssistantReply(
                text: "Ho trovato un promemoria sostituzione. \(alert.message)",
                followUp: randomFollowUp(for: .tread)
            )
        }

        let tip = treadTips.randomElement() ?? "Per il battistrada, sotto i 3 mm conviene pianificare la sostituzione."
        return AssistantReply(text: tip, followUp: randomFollowUp(for: .tread))
    }

    private func rotationResponse(context: AssistantContext) -> AssistantReply {
        if let reminder = context.rotationReminders.first {
            return AssistantReply(
                text: "Hai un promemoria rotazione. \(reminder.message)",
                followUp: randomFollowUp(for: .rotation)
            )
        }

        let tip = rotationTips.randomElement() ?? "La rotazione aiuta a mantenere l usura uniforme."
        return AssistantReply(text: tip, followUp: randomFollowUp(for: .rotation))
    }

    private func seasonalResponse(context: AssistantContext) -> AssistantReply {
        if let reminder = context.seasonalReminders.first {
            return AssistantReply(
                text: "C'e un promemoria stagionale. \(reminder.message)",
                followUp: randomFollowUp(for: .seasonal)
            )
        }

        let tip = seasonalTips.randomElement() ?? "Per il cambio stagionale, considera le temperature medie."
        return AssistantReply(text: tip, followUp: randomFollowUp(for: .seasonal))
    }

    private func inspectionResponse(context: AssistantContext) -> AssistantReply {
        if let critical = context.criticalNotifications.first {
            return AssistantReply(
                text: "Attenzione, ho un avviso critico. \(critical.message) Ti consiglio un controllo in officina appena possibile.",
                followUp: randomFollowUp(for: .inspection)
            )
        }

        let tip = inspectionTips.randomElement() ?? "Per un check completo: battistrada, spalle del pneumatico, valvole e data DOT."
        return AssistantReply(text: tip, followUp: randomFollowUp(for: .inspection))
    }

    private func generalResponse(context: AssistantContext) -> AssistantReply {
        if let critical = context.criticalNotifications.first {
            let text = "C'e una segnalazione critica. \(critical.message) Vuoi che ti guidi passo passo?"
            return AssistantReply(text: text, followUp: randomFollowUp(for: .inspection))
        }

        if !context.upcomingNotifications.isEmpty {
            let summary = summarizeNotifications(context.upcomingNotifications, limit: 1)
            let intro = generalIntros.randomElement() ?? "Posso aiutarti con la manutenzione."
            let baseText = "\(intro) Prima cosa: \(summary) Dimmi se vuoi battistrada, rotazione o cambio stagionale."
            var textParts = [baseText]
            if let vehicleHint = contextVehicleHint(context) {
                textParts.append(vehicleHint)
            }
            return AssistantReply(text: textParts.joined(separator: " "), followUp: randomFollowUp(for: .maintenance))
        }

        let intro = generalIntros.randomElement() ?? "Dimmi pure cosa ti serve."
        let baseText = "\(intro) Posso guidarti su battistrada, rotazione, cambio stagionale e controlli di sicurezza."
        var textParts = [baseText]
        if let vehicleHint = contextVehicleHint(context) {
            textParts.append(vehicleHint)
        }
        if let reminderHint = contextReminderHint(context) {
            textParts.append(reminderHint)
        }
        return AssistantReply(text: textParts.joined(separator: " "), followUp: randomFollowUp(for: .general))
    }

    private func garageStatusResponse(context: AssistantContext) -> AssistantReply {
        guard let stats = context.userStats else {
            return AssistantReply(
                text: "Non riesco a recuperare i dati del garage in questo momento. Riprova tra poco.",
                followUp: randomFollowUp(for: .garage)
            )
        }

        var parts: [String] = []
        if let count = stats.vehicleCount {
            parts.append("Hai \(count) veicoli nel garage.")
        } else {
            parts.append("Non riesco a vedere quanti veicoli hai nel garage.")
        }

        if stats.isPremium {
            parts.append("Con il piano Premium puoi aggiungerne quanti vuoi.")
            let extra = "Fammi sapere se vuoi aggiornare qualcosa."
            return AssistantReply(text: "\(parts.joined(separator: " ")) \(extra)", followUp: randomFollowUp(for: .garage))
        }

        if stats.isPaywallEnabled, let maxVehicles = stats.maxVehicles {
            if let remaining = stats.remainingVehicleSlots {
                if remaining > 0 {
                    parts.append("Puoi aggiungerne ancora \(remaining) (limite massimo \(maxVehicles)).")
                } else {
                    parts.append("Hai raggiunto il limite free di \(maxVehicles) veicoli. Per aggiungerne altri serve Premium.")
                }
            } else {
                parts.append("Il limite free e \(maxVehicles) veicoli.")
            }
        } else {
            parts.append("Al momento non ci sono limiti attivi sul numero di veicoli.")
        }

        let closing = "Fammi sapere se ti serve aiuto sul garage."
        var text = "\(parts.joined(separator: " ")) \(closing)"
        if let vehicleHint = contextVehicleHint(context) {
            text += " \(vehicleHint)"
        }
        return AssistantReply(text: text, followUp: randomFollowUp(for: .garage))
    }

    private func summarizeNotifications(_ notifications: [AppNotification], limit: Int) -> String {
        let selected = Array(notifications.prefix(limit))
        let parts = selected.enumerated().map { index, item in
            let prefix = index == 0 ? "Prima" : "Poi"
            return "\(prefix): \(item.message)"
        }
        return parts.joined(separator: " ")
    }

    private func containsAny(_ text: String, keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }

    private func randomFollowUp(for topic: FollowUpTopic) -> String? {
        followUpPrompts[topic]?.randomElement()
    }

    private func contextVehicleHint(_ context: AssistantContext) -> String? {
        guard let summary = context.highlightedVehicleSummary else { return nil }
        return "Sto tenendo d'occhio il tuo \(summary)."
    }

    private func contextReminderHint(_ context: AssistantContext) -> String? {
        guard let reminder = context.nextReminderSummary else { return nil }
        return "Il prossimo promemoria e: \(reminder)"
    }

    private func normalize(_ text: String) -> String {
        let lowered = text.lowercased()
        return lowered.replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct AssistantReply {
    let text: String
    let followUp: String?
}

final class SpeechSession {
    private let audioEngine = AVAudioEngine()
    private let recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    var onPartialResult: ((String) -> Void)?
    var onFinalResult: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    init(locale: Locale) {
        recognizer = SFSpeechRecognizer(locale: locale)
    }

    func start() throws {
        guard let recognizer else {
            throw SpeechSessionError.unavailableRecognizer
        }
        guard recognizer.isAvailable else {
            throw SpeechSessionError.unavailableRecognizer
        }

        if audioEngine.isRunning {
            stop()
        }

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else {
            throw SpeechSessionError.invalidRequest
        }
        request.shouldReportPartialResults = true

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        guard audioSession.isInputAvailable else {
            throw SpeechSessionError.inputUnavailable
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            throw SpeechSessionError.invalidAudioFormat
        }
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let error = error {
                self?.onError?(error)
                self?.stop()
                return
            }

            guard let result = result else { return }
            let text = result.bestTranscription.formattedString
            if result.isFinal {
                self?.onFinalResult?(text)
                self?.stop()
            } else {
                self?.onPartialResult?(text)
            }
        }
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

enum SpeechSessionError: Error {
    case unavailableRecognizer
    case invalidRequest
    case inputUnavailable
    case invalidAudioFormat
}

@MainActor
final class VoiceAssistantViewModel: NSObject, ObservableObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    private enum ListeningMode {
        case wakeWord
        case command
    }

    @Published var messages: [AssistantMessage] = []
    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var isGenerating = false
    @Published var liveTranscript = ""
    @Published var statusMessage = "Di 'Ehi TyreVibes' per iniziare."
    @Published var errorMessage: String?
    @Published private(set) var userStats: AssistantUserStats?
    @Published var followUpPrompt: String?

    var contextProvider: (() -> AssistantContext)?

    private let responseGenerator = AssistantResponseGenerator()
    private let speechSynthesizer = AVSpeechSynthesizer()
    private let deepSeekService: DeepSeekServiceProtocol
    private let localRAG = LocalRAGService.shared
    private let vehicleService = VehicleService.shared
    private let paywallManager = PaywallManager.shared
    private let featureFlags = FeatureFlags.shared
    private let shouldSpeakResponses: Bool
    private let refreshUserStatsHandler: (() async -> Void)?
    private var speechSession: SpeechSession?
    private var remoteAudioPlayer: AVAudioPlayer?
    var highlightedVehicleSummary: String? {
        guard let cachedVehicles = vehicleService.getCachedVehicles(),
              let primary = cachedVehicles.first else {
            return nil
        }
        return primary.vehicle.summaryName
    }
    private var currentLocale: Locale = .current
    private var hasSpeechPermission = false
    private var hasMicPermission = false
    private var isActive = false
    private var listeningMode: ListeningMode = .wakeWord
    private var wasActiveBeforeTyping = false
    private let wakeWordPhrases = [
        "ehi tyrevibes",
        "hey tyrevibes",
        "ehi tyre vibes",
        "hey tyre vibes"
    ]
    private let llmBannedPhrases = [
        "sito web",
        "google",
        "www.",
        "http",
        "browser",
        "navigando",
        "trovarlo su"
    ]

    override convenience init() {
        self.init(
            deepSeekService: DeepSeekService.shared,
            shouldSpeakResponses: true,
            refreshUserStatsHandler: nil
        )
    }

    init(
        deepSeekService: DeepSeekServiceProtocol,
        shouldSpeakResponses: Bool,
        refreshUserStatsHandler: (() async -> Void)?
    ) {
        self.deepSeekService = deepSeekService
        self.shouldSpeakResponses = shouldSpeakResponses
        self.refreshUserStatsHandler = refreshUserStatsHandler
        super.init()
        speechSynthesizer.delegate = self
    }

    func prepare() {
        requestPermissionsIfNeeded()
    }

    func activate() {
        isActive = true
        listeningMode = .wakeWord
        startListening(mode: .wakeWord)
    }

    func deactivate() {
        isActive = false
        stopListening()
        stopAllSpeech()
    }

    func setChatFocus(_ focused: Bool) {
        if focused {
            wasActiveBeforeTyping = isActive
            if isActive {
                isActive = false
                stopListening()
                statusMessage = "Scrivi il messaggio..."
            }
        } else if wasActiveBeforeTyping {
            wasActiveBeforeTyping = false
            activate()
        }
    }

    func updateLocale(_ locale: Locale) {
        currentLocale = locale
    }

    func sendWelcomeIfNeeded(context: AssistantContext) {
        guard messages.isEmpty else { return }
        let welcome = responseGenerator.welcomeResponse(context: context)
        messages.append(AssistantMessage(role: .assistant, text: welcome.text))
        followUpPrompt = welcome.followUp
    }

    func toggleListening() {
        if isListening {
            isActive = false
            stopListening()
            stopAllSpeech()
            statusMessage = "Microfono disattivato."
        } else {
            isActive = true
            startListening(mode: .wakeWord)
        }
    }

    func handleManualInput(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        handleUserInput(trimmed)
    }

    func refreshUserStats() async {
        guard let userId = await AuthService.currentUserId, !userId.isEmpty else {
            userStats = nil
            return
        }

        let vehicles = try? await vehicleService.fetchVehicles(for: userId)
        if let vehicles {
            vehicleService.cacheVehicles(vehicles)
        }
        let cachedVehicles = vehicles ?? vehicleService.getCachedVehicles()
        let vehicleCount = cachedVehicles?.count

        let isPremium = paywallManager.isPremium
        let isPaywallEnabled = featureFlags.isPaywallEnabled
        let maxVehicles = (isPaywallEnabled && !isPremium) ? PaywallManager.FreeLimits.maxVehicles : nil
        let remaining: Int?
        if let maxVehicles, let vehicleCount {
            remaining = maxVehicles - vehicleCount
        } else {
            remaining = nil
        }

        userStats = AssistantUserStats(
            vehicleCount: vehicleCount,
            maxVehicles: maxVehicles,
            remainingVehicleSlots: remaining,
            isPremium: isPremium,
            isPaywallEnabled: isPaywallEnabled
        )
    }

    private func startListening(mode: ListeningMode) {
        errorMessage = nil
        guard hasSpeechPermission && hasMicPermission else {
            statusMessage = "Serve il permesso microfono e riconoscimento vocale."
            requestPermissionsIfNeeded()
            return
        }

        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        if isListening {
            stopListening()
        }

        listeningMode = mode
        liveTranscript = ""
        statusMessage = mode == .wakeWord ? "Di 'Ehi TyreVibes' per iniziare." : "Sto ascoltando..."
        isListening = true

        let session = SpeechSession(locale: currentLocale)
        session.onPartialResult = { [weak self] text in
            Task { @MainActor in
                self?.handlePartialTranscript(text)
            }
        }
        session.onFinalResult = { [weak self] text in
            Task { @MainActor in
                self?.handleFinalTranscript(text)
            }
        }
        session.onError = { [weak self] error in
            Task { @MainActor in
                self?.handleSpeechError(error)
            }
        }

        speechSession = session

        do {
            try session.start()
        } catch {
            handleSpeechError(error)
        }
    }

    private func stopListening() {
        speechSession?.stop()
        speechSession = nil
        isListening = false
        if liveTranscript.isEmpty {
            statusMessage = "Di 'Ehi TyreVibes' per iniziare."
        }
    }

    private func handlePartialTranscript(_ text: String) {
        switch listeningMode {
        case .wakeWord:
            if let command = extractCommand(from: text) {
                listeningMode = .command
                statusMessage = "Ti ascolto..."
                liveTranscript = command
            } else {
                liveTranscript = ""
            }
        case .command:
            liveTranscript = extractCommand(from: text) ?? text
        }
    }

    private func handleFinalTranscript(_ text: String) {
        switch listeningMode {
        case .wakeWord:
            if let command = extractCommand(from: text) {
                let cleaned = command.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.isEmpty {
                    statusMessage = "Dimmi pure."
                    liveTranscript = ""
                    restartListening(mode: .command)
                } else {
                    handleUserInput(cleaned)
                }
            } else {
                liveTranscript = ""
                statusMessage = "Di 'Ehi TyreVibes' per iniziare."
                restartListening(mode: .wakeWord)
            }
        case .command:
            let command = extractCommand(from: text) ?? text
            let cleaned = command.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.isEmpty {
                statusMessage = "Di 'Ehi TyreVibes' per iniziare."
                restartListening(mode: .wakeWord)
            } else {
                handleUserInput(cleaned)
            }
        }
    }

    private func handleUserInput(_ text: String) {
        stopListening()
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            statusMessage = "Non ho sentito bene."
            return
        }

        messages.append(AssistantMessage(role: .user, text: cleaned))
        statusMessage = "Sto preparando la risposta..."
        followUpPrompt = nil
        isGenerating = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            if let refreshUserStatsHandler {
                await refreshUserStatsHandler()
            } else {
                await self.refreshUserStats()
            }

            let context = self.contextProvider?() ?? .empty
            let fallbackReply = self.responseGenerator.response(for: cleaned, context: context)

            if self.deepSeekService.isConfigured {
                let prompt = self.buildPrompt(userInput: cleaned, context: context)
                #if DEBUG
                print("ℹ️ [VoiceAssistant][DeepSeek] request started")
                #endif
                do {
                    let llmResponse = try await self.deepSeekService.generateResponse(prompt: prompt)
                    if !llmResponse.isEmpty, self.isLLMResponseAcceptable(llmResponse) {
                        await self.deliverAssistantMessage(llmResponse, followUp: nil)
                    } else {
                        #if DEBUG
                        print("⚠️ [VoiceAssistant][DeepSeek] response filtered/empty, using fallback")
                        #endif
                        await self.deliverAssistantMessage(fallbackReply.text, followUp: fallbackReply.followUp)
                    }
                } catch {
                    #if DEBUG
                    if let deepSeekError = error as? DeepSeekServiceError {
                        print("⚠️ [VoiceAssistant][DeepSeek] service error: \(deepSeekError.localizedDescription)")
                    } else {
                        print("⚠️ [VoiceAssistant][DeepSeek] unexpected error: \(error.localizedDescription)")
                    }
                    #endif
                    await self.deliverAssistantMessage(fallbackReply.text, followUp: fallbackReply.followUp)
                }
            } else {
                #if DEBUG
                print("ℹ️ [VoiceAssistant][DeepSeek] not configured, using fallback")
                #endif
                await self.deliverAssistantMessage(fallbackReply.text, followUp: fallbackReply.followUp)
            }

            self.isGenerating = false
        }
    }

    private func deliverAssistantMessage(_ text: String, followUp: String?) async {
        messages.append(AssistantMessage(role: .assistant, text: text))
        followUpPrompt = followUp
        if shouldSpeakResponses {
            await speak(text)
        }
    }

    private func restartListening(mode: ListeningMode) {
        guard isActive else { return }
        stopListening()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.startListening(mode: mode)
        }
    }

    private func extractCommand(from text: String) -> String? {
        let lowered = text.lowercased()
        for phrase in wakeWordPhrases {
            if let range = lowered.range(of: phrase) {
                let remainder = text[range.upperBound...]
                return remainder.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        let normalizedText = normalizeForWakeWord(text)
        for phrase in wakeWordPhrases {
            let normalizedPhrase = normalizeForWakeWord(phrase)
            if let range = normalizedText.range(of: normalizedPhrase) {
                let remainder = normalizedText[range.upperBound...]
                return remainder.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }

    private func buildPrompt(userInput: String, context: AssistantContext) -> String {
        let header = """
        Sei l assistente virtuale di TyreVibes, una app mobile per manutenzione pneumatici e veicoli.
        Non sei un sito web e non puoi navigare su internet. Non suggerire Google o link.
        Rispondi solo con informazioni utili per l app o manutenzione veicolo.
        Se non hai dati specifici, fornisci una guida generale e chiedi una domanda di chiarimento.
        Risposta breve, chiara, in italiano.
        """

        let summary = buildContextSummary(context)
        let rag = buildRagContext(userInput: userInput)
        return """
        \(header)

        Contesto utente:
        \(summary)

        Conoscenza TyreVibes:
        \(rag)

        Domanda: \(userInput)
        Risposta:
        """
    }

    private func buildContextSummary(_ context: AssistantContext) -> String {
        var lines: [String] = []

        if let stats = context.userStats {
            if let count = stats.vehicleCount {
                lines.append("Veicoli nel garage: \(count).")
            } else {
                lines.append("Veicoli nel garage: non disponibile.")
            }

            if stats.isPremium {
                lines.append("Piano Premium attivo, limiti veicoli: nessuno.")
            } else if stats.isPaywallEnabled, let maxVehicles = stats.maxVehicles {
                lines.append("Limite veicoli free: \(maxVehicles).")
            } else {
                lines.append("Limiti veicoli: non attivi.")
            }
        }

        let upcoming = context.upcomingNotifications.prefix(3).map { "- \($0.message)" }
        if upcoming.isEmpty {
            lines.append("Nessun promemoria imminente.")
        } else {
            lines.append(contentsOf: upcoming)
        }

        return lines.joined(separator: "\n")
    }

    private func buildRagContext(userInput: String) -> String {
        let snippets = localRAG.retrieve(query: userInput, maxResults: 3)
        guard !snippets.isEmpty else { return "Nessuna conoscenza locale rilevante." }
        return snippets.map { "- \($0.title): \($0.content)" }.joined(separator: "\n")
    }

    private func isLLMResponseAcceptable(_ response: String) -> Bool {
        let normalized = response.lowercased()
        return !llmBannedPhrases.contains { normalized.contains($0) }
    }

    private func normalizeForWakeWord(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func speak(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSpeaking = true
        statusMessage = "Sto parlando..."
        stopRemoteAudio()

        speakWithLocalSynthesizer(trimmed)
    }

    private func speakWithLocalSynthesizer(_ text: String) {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        if let voice = bestVoice(for: currentLocale) {
            utterance.voice = voice
        }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.05
        utterance.preUtteranceDelay = 0.05
        utterance.postUtteranceDelay = 0.08

        speechSynthesizer.speak(utterance)
    }

    private func playRemoteAudio(data: Data) throws {
        stopRemoteAudio()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .allowBluetooth, .defaultToSpeaker])
        try session.setActive(true)

        let player = try AVAudioPlayer(data: data)
        player.delegate = self
        player.prepareToPlay()
        guard player.play() else {
            throw NSError(domain: "VoiceAssistantAudio", code: -1)
        }

        remoteAudioPlayer = player
    }

    private func stopRemoteAudio() {
        remoteAudioPlayer?.stop()
        remoteAudioPlayer = nil
    }

    private func stopAllSpeech() {
        stopRemoteAudio()
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }

    private func bestVoice(for locale: Locale) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let preferredLanguages = preferredVoiceLanguages(for: locale)

        for language in preferredLanguages {
            let candidates = voices.filter { $0.language == language }
            if let enhanced = candidates.first(where: { $0.quality == .enhanced }) {
                return enhanced
            }
            if let any = candidates.first {
                return any
            }
        }

        let languageCode = locale.languageCode ?? "it"
        let fallback = voices.filter { $0.language.hasPrefix(languageCode) }
        if let enhanced = fallback.first(where: { $0.quality == .enhanced }) {
            return enhanced
        }
        return fallback.first
    }

    private func preferredVoiceLanguages(for locale: Locale) -> [String] {
        if let identifier = locale.identifier.split(separator: "_").first {
            let normalized = locale.identifier.replacingOccurrences(of: "_", with: "-")
            if normalized.count > 1 {
                return [normalized, "\(identifier)-IT", "\(identifier)-US"]
            }
        }

        if let languageCode = locale.languageCode {
            return ["\(languageCode)-IT", "\(languageCode)-US", languageCode]
        }

        return ["it-IT", "en-US"]
    }

    private func handleSpeechError(_ error: Error) {
        stopListening()
        isGenerating = false
        if let sessionError = error as? SpeechSessionError {
            switch sessionError {
            case .inputUnavailable:
                errorMessage = "Microfono non disponibile su questo dispositivo."
                statusMessage = "Collega un microfono o prova su dispositivo reale."
            case .invalidAudioFormat:
                errorMessage = "Formato audio non valido."
                statusMessage = "Riprova o riavvia l app."
            default:
                errorMessage = "Errore audio: \(error.localizedDescription)"
                statusMessage = "Qualcosa non ha funzionato. Riprova."
            }
            return
        }

        errorMessage = "Errore audio: \(error.localizedDescription)"
        statusMessage = "Qualcosa non ha funzionato. Riprova."
    }

    private func requestPermissionsIfNeeded() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                self?.hasSpeechPermission = (status == .authorized)
                if status == .denied || status == .restricted {
                    self?.errorMessage = "Riconoscimento vocale non autorizzato."
                } else if self?.hasSpeechPermission == true,
                          self?.hasMicPermission == true,
                          self?.isActive == true,
                          self?.isListening == false {
                    self?.startListening(mode: .wakeWord)
                }
            }
        }

        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                self?.hasMicPermission = granted
                if !granted {
                    self?.errorMessage = "Accesso al microfono negato."
                } else if AVAudioSession.sharedInstance().isInputAvailable == false {
                    self?.errorMessage = "Microfono non disponibile su questo dispositivo."
                } else if self?.hasSpeechPermission == true,
                          self?.hasMicPermission == true,
                          self?.isActive == true,
                          self?.isListening == false {
                    self?.startListening(mode: .wakeWord)
                }
            }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
            if isActive {
                restartListening(mode: .wakeWord)
            } else {
                statusMessage = "Di 'Ehi TyreVibes' per iniziare."
            }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.remoteAudioPlayer === player {
                self.remoteAudioPlayer = nil
            }
            self.isSpeaking = false
            if self.isActive {
                self.restartListening(mode: .wakeWord)
            } else {
                self.statusMessage = "Di 'Ehi TyreVibes' per iniziare."
            }
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.remoteAudioPlayer === player {
                self.remoteAudioPlayer = nil
            }
            self.isSpeaking = false
            self.statusMessage = "Errore audio. Provo a riavviare."
            if self.isActive {
                self.restartListening(mode: .wakeWord)
            }
        }
    }
}
