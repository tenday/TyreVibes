import SwiftUI

struct OTPVerificationView: View {
    @State private var otpCode: [String] = Array(repeating: "", count: 6)
    @State private var isKeyboardVisible = false
    @FocusState private var focusedField: Int?
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 10) {
                // Navigation bar
                HStack {
                    Button(action: {
                        //SignUpScreen()
                    }) {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.white)
                            .font(.system(size: 24))
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
                    
                    Text("The OTP code has sent to your number. Please enter the code.")
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
                        .textContentType(.oneTimeCode)
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
                
                Spacer()
                    .frame(height: 35)
                
                // Verify button
                Button(action: {
                    // Handle verification
                    let fullOTP = otpCode.joined()
                    print("OTP entered: \(fullOTP)")
                }) {
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
                .disabled(otpCode.contains { $0.isEmpty })
                
                // Resend code button - now with underline
                Button(action: {
                    // Handle resend code
                    // Reset OTP and focus sul primo campo
                    otpCode = Array(repeating: "", count: 6)
                    focusedField = 0
                }) {
                    Text("Resend Code")
                        .font(.customFont(size: 18, weight: .medium))
                        .foregroundColor(Color.customElectricBlueColor)
                        .underline()
                        .padding()
                }
                
                Spacer()
            }
        }
        .background(Color.customBackgroundColor)
        .onTapGesture {
            // Se l'utente tocca fuori dai campi, trova il primo campo vuoto
            if let firstEmptyIndex = otpCode.firstIndex(where: { $0.isEmpty }) {
                focusedField = firstEmptyIndex
            } else {
                focusedField = 5 // Se tutti i campi sono pieni, focus sull'ultimo
            }
        }
    }
    
    // Funzione separata per gestire l'input OTP
    private func handleOTPInput(newValue: String, at index: Int) {
        let oldValue = otpCode[index]
        
        // Se l'utente ha incollato tutto il codice
        if newValue.count > 1 {
            let numbers = newValue.filter { $0.isNumber }
            let startIndex = numbers.startIndex
            
            for i in 0..<min(6, numbers.count) {
                if index + i < 6 {
                    let charIndex = numbers.index(startIndex, offsetBy: i)
                    otpCode[index + i] = String(numbers[charIndex])
                }
            }
            
            // Focus sull'ultimo campo riempito o sul primo vuoto
            let nextFocusIndex = min(5, index + numbers.count)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = nextFocusIndex
            }
            return
        }
        
        // Input normale - un carattere alla volta
        let filtered = newValue.filter { $0.isNumber }
        
        if filtered.count <= 1 {
            otpCode[index] = filtered
            
            // Se è stato inserito un numero, vai al prossimo campo
            if !filtered.isEmpty && oldValue.isEmpty && index < 5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    focusedField = index + 1
                }
            }
            // Se il campo è stato svuotato (backspace), vai al precedente
            else if filtered.isEmpty && !oldValue.isEmpty && index > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    focusedField = index - 1
                }
            }
        }
    }
}

// Preview
struct OTPVerificationView_Previews: PreviewProvider {
    static var previews: some View {
        OTPVerificationView()
            .preferredColorScheme(.dark)
    }
}
