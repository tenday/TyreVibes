import SwiftUI
import UIKit

// Hidden UITextField to capture iOS OTP AutoFill (SMS one-time code)
struct OneTimeCodeTextField: UIViewRepresentable {
    @Binding var code: String
    @Binding var isFirstResponder: Bool

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: OneTimeCodeTextField
        init(parent: OneTimeCodeTextField) { self.parent = parent }
        @objc func editingChanged(_ textField: UITextField) {
            parent.code = textField.text ?? ""
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField(frame: .zero)
        tf.keyboardType = .numberPad
        tf.textContentType = .oneTimeCode
        tf.delegate = context.coordinator
        tf.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        tf.setContentHuggingPriority(.required, for: .horizontal)
        tf.setContentCompressionResistancePriority(.required, for: .horizontal)
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != code { uiView.text = code }
        if isFirstResponder && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isFirstResponder && uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }
}

struct OTPVerificationView: View {
    @ObservedObject var viewModel: SignUpViewModel
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var otpCode: [String] = Array(repeating: "", count: 6)
    @State private var isKeyboardVisible = false
    @FocusState private var focusedField: Int?
    @State private var countdown = 60
    @State private var timer: Timer? = nil
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    @State private var hiddenCode: String = ""
    @State private var captureAutoFill: Bool = false

    
var body: some View {
    NavigationStack {
        GeometryReader { geometry in
            OneTimeCodeTextField(code: $hiddenCode, isFirstResponder: $captureAutoFill)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .allowsHitTesting(false)
            
            VStack(spacing: 10) {
                // Navigation bar
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
                .padding(.horizontal)
                .padding(.bottom, 20)
                
                
                // Title and description
                VStack(alignment: .leading, spacing: 12) {
                    Text("Enter 6-Digit")
                        .font(.customFont(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Authentication \nCode")
                        .font(.customFont(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("The OTP code has been sent to \(Utilities.maskPhoneNumber(viewModel.phoneNumber)). Please enter the code.")
                        .font(.customFont(size: 18, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.top, 5)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                Spacer()
                    .frame(height: 32)
                
                HStack(spacing: 6) {
                    ForEach(0..<6, id: \.self) { index in
                        TextField("", text: Binding(
                            get: { otpCode[index] },
                            set: { newValue in
                                handleOTPInput(newValue: newValue, at: index)
                            })
                        )
                        .keyboardType(.numberPad)
                        // oneTimeCode handled by hidden field
                        .multilineTextAlignment(.center)
                        .font(.system(size: 24, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 68)
                        .background(Color.customFieldColor)
                        .cornerRadius(18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(
                                    focusedField == index ? Color.customElectricBlueColor :
                                        (otpCode[index].isEmpty ? Color.clear : Color.cyan.opacity(0.7)),
                                    lineWidth: 2
                                )
                        )
                        .focused($focusedField, equals: index)
                        .onTapGesture {
                            focusedField = index
                            captureAutoFill = true
                        }
                        
                    }
                }
                .padding(.horizontal)
                .onAppear {
                    // Focus automatico sul primo campo quando appare la view
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        focusedField = 0
                    }
                }
                .onChange(of: hiddenCode) { _, newValue in
                    let digits = newValue.filter { $0.isNumber }
                    guard !digits.isEmpty else { return }
                    // If iOS pasted the full 6-digit code, distribute it
                    if digits.count >= 6 {
                        for i in 0..<6 { otpCode[i] = String(digits[digits.index(digits.startIndex, offsetBy: i)]) }
                        focusedField = 5
                        viewModel.fullOtp = otpCode.joined()
                        viewModel.verifyOtp()
                        captureAutoFill = false
                    }
                }
                
                Spacer()
                    .frame(height: 35)
                
                // Verify button
                Button(action: {
                    // Handle verification
                    viewModel.fullOtp = otpCode.joined()
                    viewModel.verifyOtp()
                }) {
                    if viewModel.isLoadingCheckingOtp {
                        ZStack {
                            RoundedRectangle(cornerRadius: 100)
                                .fill(Color.customBitterSweet)
                                .frame(height: 62)
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                    }
                    else {
                        Text("Verify Now")
                            .font(.customFont(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .opacity(otpCode.contains { $0.isEmpty } ? 0.6 : 1.0)
                            .frame(maxWidth: .infinity)
                            .frame(height: 62)
                            .background(
                                RoundedRectangle(cornerRadius: 100)
                                    .fill(Color.customBitterSweet)
                            )
                            .opacity(otpCode.contains { $0.isEmpty } ? 0.6 : 1.0)
                            .padding(.horizontal)
                    }
                    
                }
                .disabled(otpCode.contains { $0.isEmpty })
                .background(Color.customBackgroundColor)
                
                // Resend code button with countdown
                if countdown > 0 {
                    Text("Resend available in \(countdown)s")
                        .font(.customFont(size: 18, weight: .medium))
                        .foregroundColor(Color.gray)
                        .underline()
                        .padding()
                        .disabled(true)
                } else {
                    Button(action: {
                        viewModel.sendCode(completion: { result in
                            switch result {
                            case .success(_):
                                break;
                            case .failure(_):
                                errorMessage = "\(viewModel.alertTitle): \(viewModel.alertMessage)"
                                viewModel.showAlert = true
                            }
                        })
                        otpCode = Array(repeating: "", count: 6)
                        focusedField = 0
                        countdown = 60
                        startCountdown()
                    }) {
                        Text("Resend Code")
                            .font(.customFont(size: 18, weight: .medium))
                            .foregroundColor(Color.customElectricBlueColor)
                            .underline()
                            .padding()
                    }
                }
                
                Spacer()
            }
        }
        .background(Color.customBackgroundColor)
        .onAppear {
            startCountdown()
            captureAutoFill = true
        }
        .alert(viewModel.alertTitle, isPresented: $viewModel.showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
        .navigationDestination(isPresented: $viewModel.showCreationSuccessScreen) {
            CreationSuccessScreen()
        }
        .navigationBarBackButtonHidden(true)
        .background(InteractivePopGestureEnabler())
    }
}
    
    
    private func handleOTPInput(newValue: String, at index: Int) {
        // Consente solo numeri e rende le transizioni di focus idempotenti
        let filtered = newValue.filter { $0.isNumber }

        // Evita riassegnazioni inutili che possono causare "lampeggio" del focus
        if filtered == otpCode[index] {
            return
        }

        // Gestione incolla multipla (es. "123456"): riempi i campi da `index` in avanti
        if filtered.count > 1 {
            var cursor = index
            for ch in filtered.prefix(6 - index) {
                otpCode[cursor] = String(ch)
                cursor += 1
            }
            let target = min(5, cursor)
            if focusedField != target {
                focusedField = target
            }
            if !otpCode.contains(where: { $0.isEmpty }) {
                viewModel.fullOtp = otpCode.joined()
                viewModel.verifyOtp()
            }
            return
        }

        // Inserimento singolo carattere
        if let ch = filtered.first {
            otpCode[index] = String(ch)
            let target = min(5, index + 1)
            if focusedField != target {
                focusedField = target
            }
            if !otpCode.contains(where: { $0.isEmpty }) {
                viewModel.fullOtp = otpCode.joined()
                viewModel.verifyOtp()
            }
            return
        }

        // Cancellazione: svuota il campo corrente e torna indietro di uno (se possibile)
        otpCode[index] = ""
        if index > 0 {
            let target = index - 1
            if focusedField != target {
                focusedField = target
            }
        }
    }
    
    // Timer logic for countdown
    private func startCountdown() {
        timer?.invalidate()
        if countdown > 0 {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
                if countdown > 0 {
                    countdown -= 1
                }
                if countdown == 0 {
                    timer?.invalidate()
                }
            }
        }
    }

    
}

// Preview
struct OTPVerificationView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = SignUpViewModel()
        viewModel.phoneNumber = "3519770640"
        return OTPVerificationView(viewModel: viewModel)
        .preferredColorScheme(.dark)
    }
}
    
