import SwiftUI

struct VoiceAssistantScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var notificationStore: NotificationStore
    @EnvironmentObject private var languageManager: LanguageManager
    @StateObject private var viewModel = VoiceAssistantViewModel()
    @State private var chatInput = ""
    @FocusState private var isChatFocused: Bool

    private let suggestions = [
        "Prossima manutenzione",
        "Rotazione gomme",
        "Battistrada",
        "Cambio stagionale"
    ]

    var body: some View {
        ZStack {
            Color.customBackgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerView

                messagesView

                if viewModel.isGenerating {
                    typingIndicatorView
                }

                if viewModel.isListening && !viewModel.liveTranscript.isEmpty {
                    liveTranscriptView
                }

                suggestionChips

                chatInputView

                statusView

                micButton
            }
        }
        .onAppear {
            viewModel.updateLocale(languageManager.locale)
            viewModel.contextProvider = { buildContext() }
            viewModel.prepare()
            viewModel.activate()
            viewModel.sendWelcomeIfNeeded(context: buildContext())
            Task {
                await viewModel.refreshUserStats()
            }
        }
        .onChange(of: languageManager.locale) { newLocale in
            viewModel.updateLocale(newLocale)
        }
        .onChange(of: isChatFocused) { focused in
            viewModel.setChatFocus(focused)
        }
        .onDisappear {
            viewModel.deactivate()
        }
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Assistente vocale")
                    .font(.customFont(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Text("Manutenzione pneumatici e veicolo")
                    .font(.customFont(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Circle().fill(Color.customFieldColor))
            }
            .accessibilityLabel("Chiudi assistente")
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var typingIndicatorView: some View {
        HStack {
            TypingDotsView()
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.customFieldColor)
                )
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 6)
    }

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        AssistantMessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .onChange(of: viewModel.messages.count) { _ in
                if let last = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var liveTranscriptView: some View {
        HStack {
            Image(systemName: "waveform")
                .foregroundColor(.white)
            Text(viewModel.liveTranscript)
                .font(.customFont(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.customFieldColor))
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(action: {
                        viewModel.handleManualInput(suggestion)
                    }) {
                        Text(suggestion)
                            .font(.customFont(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(
                                Capsule()
                                    .fill(Color.customFieldColor)
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                    )
                            )
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 10)
    }

    private var chatInputView: some View {
        HStack(spacing: 12) {
            TextField("Scrivi un messaggio...", text: $chatInput, axis: .vertical)
                .font(.customFont(size: 14, weight: .medium))
                .foregroundColor(.white)
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(true)
                .lineLimit(1...4)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.customFieldColor)
                )
                .focused($isChatFocused)
                .submitLabel(.send)
                .onSubmit {
                    sendChatMessage()
                }

            Button(action: {
                sendChatMessage()
            }) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.white)
                    .padding(12)
                    .background(
                        Circle()
                            .fill(chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.4) : Color.customBitterSweet)
                    )
            }
            .disabled(chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Invia messaggio")
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    private var statusView: some View {
        VStack(spacing: 4) {
            Text(viewModel.statusMessage)
                .font(.customFont(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.customFont(size: 12, weight: .medium))
                    .foregroundColor(.red.opacity(0.8))
            }
        }
        .padding(.bottom, 12)
    }

    private var micButton: some View {
        Button(action: {
            viewModel.toggleListening()
        }) {
            ZStack {
                Circle()
                    .fill(Color.customBitterSweet)
                    .frame(width: 72, height: 72)
                    .shadow(color: Color.customBitterSweet.opacity(0.4), radius: 12, x: 0, y: 6)

                Image(systemName: viewModel.isListening ? "stop.fill" : "mic.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .accessibilityLabel(viewModel.isListening ? "Ferma ascolto" : "Avvia ascolto")
        .padding(.bottom, 24)
    }

    private func buildContext() -> AssistantContext {
        let all = notificationStore.getAllNotifications()
        let upcoming = notificationStore.getUpcomingNotifications(withinDays: 30)
        let unread = notificationStore.getUnreadNotifications()
        return AssistantContext(
            allNotifications: all,
            upcomingNotifications: upcoming,
            unreadNotifications: unread,
            userStats: viewModel.userStats
        )
    }

    private func sendChatMessage() {
        let trimmed = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        chatInput = ""
        viewModel.handleManualInput(trimmed)
    }
}

private struct AssistantMessageBubble: View {
    let message: AssistantMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 50)
            }

            Text(message.text)
                .font(.customFont(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(12)
                .background(bubbleBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(message.role == .assistant ? 0.12 : 0.0), lineWidth: 1)
                )

            if message.role == .assistant {
                Spacer(minLength: 50)
            }
        }
        .padding(.horizontal, 24)
    }

    private var bubbleBackground: Color {
        message.role == .user ? Color.customBitterSweet : Color.customFieldColor
    }
}

struct VoiceAssistantScreen_Previews: PreviewProvider {
    static var previews: some View {
        VoiceAssistantScreen()
            .environmentObject(NotificationStore())
            .environmentObject(LanguageManager.shared)
            .preferredColorScheme(.dark)
    }
}

private struct TypingDotsView: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 6, height: 6)
                    .scaleEffect(animate ? 1.0 : 0.4)
                    .opacity(animate ? 1.0 : 0.35)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
        }
    }
}
