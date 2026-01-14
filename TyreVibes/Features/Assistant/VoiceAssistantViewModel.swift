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

    static let empty = AssistantContext(
        allNotifications: [],
        upcomingNotifications: [],
        unreadNotifications: [],
        userStats: nil
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
    func response(for input: String, context: AssistantContext) -> String {
        let normalized = normalize(input)
        guard !normalized.isEmpty else {
            return "Non ho sentito bene. Puoi ripetere?"
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

    func welcomeResponse(context: AssistantContext) -> String {
        generalResponse(context: context)
    }

    private func upcomingMaintenanceResponse(context: AssistantContext) -> String {
        let upcoming = context.upcomingNotifications.sorted { $0.priority.sortOrder < $1.priority.sortOrder }
        if upcoming.isEmpty {
            return "Non vedo scadenze imminenti. Ti consiglio un controllo battistrada ogni 2 o 3 mesi."
        }

        let summary = summarizeNotifications(upcoming, limit: 2)
        return "Ecco le priorita piu vicine. \(summary) Vuoi che entriamo nei dettagli su rotazione, battistrada o cambio stagionale?"
    }

    private func treadResponse(context: AssistantContext) -> String {
        if let alert = context.replacementReminders.first {
            return "Ho trovato un promemoria sostituzione. \(alert.message)"
        }

        return "Per il battistrada, sotto i 3 mm conviene pianificare la sostituzione. Se noti usura irregolare, valuta allineamento e bilanciamento."
    }

    private func rotationResponse(context: AssistantContext) -> String {
        if let reminder = context.rotationReminders.first {
            return "Hai un promemoria rotazione. \(reminder.message)"
        }

        return "La rotazione aiuta a mantenere l usura uniforme. Di solito ogni 10.000 km e una buona pratica, salvo indicazioni del costruttore."
    }

    private func seasonalResponse(context: AssistantContext) -> String {
        if let reminder = context.seasonalReminders.first {
            return "C'e un promemoria stagionale. \(reminder.message)"
        }

        return "Per il cambio stagionale, considera le temperature medie e la normativa locale. Se scendi spesso sotto i 7 gradi, le invernali offrono piu sicurezza."
    }

    private func inspectionResponse(context: AssistantContext) -> String {
        if let critical = context.criticalNotifications.first {
            return "Attenzione, ho un avviso critico. \(critical.message) Ti consiglio un controllo in officina appena possibile."
        }

        return "Per un check completo: battistrada, spalle del pneumatico, valvole e data DOT. Se il volante vibra, valuta il bilanciamento."
    }

    private func generalResponse(context: AssistantContext) -> String {
        if let critical = context.criticalNotifications.first {
            return "C'e una segnalazione critica. \(critical.message) Vuoi che ti guidi passo passo?"
        }

        if !context.upcomingNotifications.isEmpty {
            let summary = summarizeNotifications(context.upcomingNotifications, limit: 1)
            return "Posso aiutarti con la manutenzione. Prima cosa: \(summary) Dimmi se vuoi battistrada, rotazione o cambio stagionale."
        }

        return "Dimmi pure cosa ti serve. Posso guidarti su battistrada, rotazione, cambio stagionale e controlli di sicurezza."
    }

    private func garageStatusResponse(context: AssistantContext) -> String {
        guard let stats = context.userStats else {
            return "Non riesco a recuperare i dati del garage in questo momento. Riprova tra poco."
        }

        var parts: [String] = []
        if let count = stats.vehicleCount {
            parts.append("Hai \(count) veicoli nel garage.")
        } else {
            parts.append("Non riesco a vedere quanti veicoli hai nel garage.")
        }

        if stats.isPremium {
            parts.append("Con il piano Premium puoi aggiungerne quanti vuoi.")
            return parts.joined(separator: " ")
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

        return parts.joined(separator: " ")
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

    private func normalize(_ text: String) -> String {
        let lowered = text.lowercased()
        return lowered.replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
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
final class VoiceAssistantViewModel: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
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

    var contextProvider: (() -> AssistantContext)?

    private let responseGenerator = AssistantResponseGenerator()
    private let speechSynthesizer = AVSpeechSynthesizer()
    private let localLLM = LocalLLMService.shared
    private let localRAG = LocalRAGService.shared
    private let vehicleService = VehicleService.shared
    private let paywallManager = PaywallManager.shared
    private let featureFlags = FeatureFlags.shared
    private var speechSession: SpeechSession?
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

    override init() {
        super.init()
        speechSynthesizer.delegate = self
    }

    func prepare() {
        requestPermissionsIfNeeded()
        localLLM.prepare()
    }

    func activate() {
        isActive = true
        listeningMode = .wakeWord
        startListening(mode: .wakeWord)
    }

    func deactivate() {
        isActive = false
        stopListening()
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
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
        messages.append(AssistantMessage(role: .assistant, text: welcome))
    }

    func toggleListening() {
        if isListening {
            isActive = false
            stopListening()
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
        isGenerating = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.refreshUserStats()

            let context = self.contextProvider?() ?? .empty
            let fallbackResponse = self.responseGenerator.response(for: cleaned, context: context)

            if self.shouldUseLocalLLM(for: cleaned, fallback: fallbackResponse), self.localLLM.isReady {
                let prompt = self.buildPrompt(userInput: cleaned, context: context)
                if let llmResponse = await self.localLLM.generateResponse(prompt: prompt), !llmResponse.isEmpty {
                    if self.isLLMResponseAcceptable(llmResponse) {
                        self.messages.append(AssistantMessage(role: .assistant, text: llmResponse))
                        self.speak(llmResponse)
                    } else {
                        self.messages.append(AssistantMessage(role: .assistant, text: fallbackResponse))
                        self.speak(fallbackResponse)
                    }
                } else {
                    self.messages.append(AssistantMessage(role: .assistant, text: fallbackResponse))
                    self.speak(fallbackResponse)
                }
            } else {
                self.messages.append(AssistantMessage(role: .assistant, text: fallbackResponse))
                self.speak(fallbackResponse)
            }

            self.isGenerating = false
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

    private func shouldUseLocalLLM(for input: String, fallback: String) -> Bool {
        let normalized = input.lowercased()
        let keywords = ["spiega", "approfond", "dettagli", "perche", "consigliami", "diagnosi"]
        if keywords.contains(where: { normalized.contains($0) }) {
            return true
        }

        if fallback.hasPrefix("Dimmi pure") || fallback.hasPrefix("Posso aiutarti") {
            return true
        }

        return input.count > 60
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

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        if let voice = bestVoice(for: currentLocale) {
            utterance.voice = voice
        }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.05
        utterance.preUtteranceDelay = 0.05
        utterance.postUtteranceDelay = 0.08

        isSpeaking = true
        speechSynthesizer.speak(utterance)
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
}
