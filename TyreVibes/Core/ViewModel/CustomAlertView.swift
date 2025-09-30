import SwiftUI

public struct CustomAlertButton {
    public let title: String
    public let role: ButtonRole?
    public let action: () -> Void

    public init(_ title: String, role: ButtonRole? = nil, action: @escaping () -> Void = {}) {
        self.title = title
        self.role = role
        self.action = action
    }
}

public struct CustomAlertConfig: Identifiable {
    public let id = UUID()
    public let title: String
    public let message: String
    public let buttons: [CustomAlertButton]

    public init(title: String, message: String, buttons: [CustomAlertButton] = [CustomAlertButton("OK")]) {
        self.title = title
        self.message = message
        self.buttons = buttons
    }
}

public struct CustomAlertView: View {
    @Binding public var isPresented: Bool
    public let config: CustomAlertConfig

    public init(isPresented: Binding<Bool>, config: CustomAlertConfig) {
        self._isPresented = isPresented
        self.config = config
    }

    public var body: some View {
        if isPresented {
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            isPresented = false
                        }
                    }

                VStack(spacing: 12) {
                    Text(config.title)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Text(config.message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        ForEach(Array(config.buttons.enumerated()), id: \.offset) { _, button in
                            Button(role: button.role) {
                                button.action()
                                withAnimation {
                                    isPresented = false
                                }
                            } label: {
                                Text(button.title)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding(20)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 24)
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(), value: isPresented)
            }
        }
    }
}

public extension View {
    func customAlert(isPresented: Binding<Bool>, config: CustomAlertConfig) -> some View {
        ZStack {
            self
            CustomAlertView(isPresented: isPresented, config: config)
        }
    }
}

#if DEBUG
struct CustomAlertView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var showAlert = false

        var body: some View {
            VStack {
                Button("Show Alert") {
                    showAlert = true
                }
            }
            .customAlert(isPresented: $showAlert, config: CustomAlertConfig(
                title: "Hello",
                message: "This is a custom alert.",
                buttons: [
                    CustomAlertButton("Cancel", role: .cancel) { print("Cancel tapped") },
                    CustomAlertButton("OK") { print("OK tapped") }
                ]
            ))
        }
    }

    static var previews: some View {
        PreviewWrapper()
    }
}
#endif
