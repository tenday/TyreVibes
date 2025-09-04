import SwiftUI
import UIKit



struct PlateTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = "AA123AA"
    var maxLen: Int = 8

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.textAlignment = .center
        tf.borderStyle = .none
        tf.backgroundColor = .clear
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .allCharacters
        tf.keyboardType = .asciiCapable
        tf.textColor = .clear
        // Font similar to plate font (fallback to monospaced bold)
        let font = UIFont(name: "FE-Font", size: 32) ?? UIFont.monospacedSystemFont(ofSize: 32, weight: .bold)
        tf.font = font
        // Kerning/tracking to match previous plate spacing
        tf.defaultTextAttributes[.kern] = 6
        tf.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        tf.delegate = context.coordinator
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.placeholder = placeholder
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, maxLen: maxLen)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        let maxLen: Int
        private let allowed: CharacterSet = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

        init(text: Binding<String>, maxLen: Int) {
            self._text = text
            self.maxLen = maxLen
        }

        @objc func textChanged(_ sender: UITextField) {
            var value = sender.text ?? ""
            value = value.uppercased()
            value = String(value.unicodeScalars.filter { allowed.contains($0) })
            if value.count > maxLen {
                value = String(value.prefix(maxLen))
            }
            if text != value {
                text = value
                sender.text = value
            }
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            // Allow only allowed characters and enforce length as user types
            let upper = string.uppercased()
            if upper.unicodeScalars.contains(where: { !allowed.contains($0) }) {
                return false
            }
            let current = textField.text ?? ""
            guard let swiftRange = Range(range, in: current) else { return true }
            let prospective = current.replacingCharacters(in: swiftRange, with: upper)
            return prospective.count <= maxLen
        }
    }
}

struct EnterLicensePlateView: View {
    @State private var licensePlate: String = ""
    @Environment(\.dismiss) private var dismiss

    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var vehicleImage: UIImage?
    @State private var navigateToCheckDetails = false
    @State private var data : PlateData?
    @State private var isLoadingDetails: Bool = false
    @State private var showConfirmDetailsScreen : Bool = false
    
    private let maxPlateLength: Int = 8 // es. formato IT: AA123AA (7) o formati estesi
    private var isContinueEnabled: Bool {
        !licensePlate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && licensePlate.count >= 5
    }

    private func sanitizePlate(_ input: String) -> String {
        let allowed = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let upper = input.uppercased()
        let filtered = upper.filter { allowed.contains($0) }
        return String(filtered.prefix(maxPlateLength))
    }
    
    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            NavigationStack {
                HStack {
                    Spacer()
                    Text("Enter License Plate")
                        .font(.customFont(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 10, height: 10)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(
                                ZStack {
                                    Circle()
                                        .fill(Color.customBackgroundColor)
                                    Circle()
                                        .stroke(Color.white.opacity(0.22), lineWidth: 1.5)
                                        .blur(radius: 1)
                                        .offset(x: 0.3, y: 1)
                                        .mask(
                                            Circle().fill(LinearGradient(
                                                gradient: Gradient(colors: [.black, .black]),
                                                startPoint: .top,
                                                endPoint: .bottom)
                                            )
                                        )
                                    VisualEffectBlur(blurStyle:.systemUltraThinMaterial)
                                        .clipShape(Circle())
                                        .padding(12)
                                        .blur(radius: 40)
                                        .opacity(0.8)
                                }
                            )
                    }
                }
                .padding(.top)
                .padding(.horizontal)
                .background(Color.customBackgroundColor)
                
                
                VStack(spacing: 2) {
                    Spacer()
                    
                    // Title
                    
                    
                    // Manual plate entry styled as a license plate (EU style)
                    LicensePlateComponent(
                        text: licensePlate.isEmpty ? "AA123AA" : licensePlate,
                        width: 280,
                        height: 80,
                        countryCode: "I"
                    )
                    .overlay(
                        PlateTextField(text: $licensePlate, placeholder: "", maxLen: maxPlateLength)
                            .frame(width: 280, height: 80)
                            .background(Color.clear)
                            .contentShape(Rectangle())
                    )
                    
                    Spacer()
                    
                    // Continue Button
                    Button(action: {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        isLoadingDetails = true
                        let trimmed = licensePlate.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        
                        Task {
                            do {
                                let data = try await LicensePlateReader.fetchPlateSummary(plate: trimmed)
                                if data.make == ""  {
                                    licensePlate = ""
                                    self.errorMessage = "Targa errata!"
                                    self.showErrorAlert = true
                                    self.isLoadingDetails = false
                                    return
                                }
                                
                                self.data = data
                                self.vehicleImage = data.vehicleImage
                                licensePlate = ""
                                self.navigateToCheckDetails = true
                            } catch {
                                self.errorMessage = error.localizedDescription
                                self.showErrorAlert = true
                            }
                            self.isLoadingDetails = false
                        }
                        
                    }) {
                        if  isLoadingDetails {
                            Text("")
                                .foregroundColor(Color.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 62)
                                .background(Color.customBitterSweet)
                                .overlay(ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.2)
                                    .frame(height: 62)
                                    .frame(maxWidth: .infinity))
                                .disabled(true)
                        } else {
                            Text("Continue")
                                .font(.customFont(size: 18, weight: .bold))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 62)
                        }
                    }
                    .background(Color.customBitterSweet)
                    .cornerRadius(100)
                    .opacity(isContinueEnabled ? 1.0 : 0.6)
                    .disabled(!isContinueEnabled)
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                    
                    Button(action: {
                        showConfirmDetailsScreen = true
                    }) {
                        Text("Non trovi la tua auto?")
                            .font(.customFont(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .underline()
                    }
                    .padding(.bottom, 20)
                }
                .background(Color.customBackgroundColor.edgesIgnoringSafeArea(.all))
                .preferredColorScheme(.dark)
                .overlay(
                    Group {
                        if showErrorAlert {
                            CustomAlertView(
                                title: errorMessage, showProgress: false
                            )
                        }
                    }
                )
                .navigationDestination(isPresented: $navigateToCheckDetails) {
                    CheckDetailsView(vehicleImage: vehicleImage, plateData: data ?? nil, isContinueEnabled: .constant(false), viewModel: ConfirmDetailsViewModel())
                }
                .navigationDestination(isPresented: $showConfirmDetailsScreen) {
                    ConfirmDetailsView(plateData: data ?? nil, manualEntryEnabled: true, viewModel: ConfirmDetailsViewModel() )
                        .preferredColorScheme(.dark)
                        .navigationBarBackButtonHidden(true)
                }
                .navigationBarBackButtonHidden(true)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}


#Preview {
    EnterLicensePlateView()
}
