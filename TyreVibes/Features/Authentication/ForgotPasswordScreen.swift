import SwiftUI

struct ForgotPasswordScreen: View {
    @StateObject private var viewModel = ForgotPasswordViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let screenWidth = geometry.size.width
                let screenHeight = geometry.size.height

                let buttonHeight = screenHeight * 0.075
                let buttonFontSize = screenWidth * 0.045

                ZStack {
                    Color.customBackgroundColor
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        header

                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 28) {
                                titleSection
                                emailSection(buttonHeight: buttonHeight, buttonFontSize: buttonFontSize)

                                Spacer(minLength: 20)
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
        .alert(item: $viewModel.alertItem) { alertItem in
            Alert(
                title: Text(alertItem.title),
                message: Text(alertItem.message),
                dismissButton: .default(Text("OK"), action: {
                    if viewModel.didSendLink {
                        dismiss()
                    }
                })
            )
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    private var header: some View {
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
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Forgot Password")
                .font(.customFont(size: 32, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 20)

            Text("Inserisci l'email utilizzata per registrarti. Ti invieremo un link per creare una nuova password.")
                .font(.customFont(size: 16, weight: .regular))
                .foregroundColor(.gray)
                .lineSpacing(4)
        }
    }

    private func emailSection(buttonHeight: CGFloat, buttonFontSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Email")
                .font(.customFont(size: 18, weight: .semibold))
                .foregroundColor(.white)

            EmailField(email: $viewModel.email, isValid: viewModel.isEmailValid)

            Text("Riceverai una mail da TyreVibes con il link per resettare la password. Se non la trovi, controlla anche la cartella spam.")
                .font(.customFont(size: 14, weight: .regular))
                .foregroundColor(.gray)
                .lineSpacing(4)

            Button(action: {
                viewModel.sendResetLink()
            }) {
                if viewModel.isSendingLink {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Invia link")
                        .font(.customFont(size: buttonFontSize, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: buttonHeight)
            .background(viewModel.isSendButtonEnabled ? Color.customBitterSweet : Color.customBitterSweet.opacity(0.6))
            .cornerRadius(30)
            .disabled(!viewModel.isSendButtonEnabled)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isSendButtonEnabled)
        }
    }
}

struct ForgotPasswordScreen_Previews: PreviewProvider {
    static var previews: some View {
        ForgotPasswordScreen()
    }
}
