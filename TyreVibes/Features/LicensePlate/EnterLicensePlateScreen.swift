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

        // Font originale
        let font = UIFont(name: "FE-Font", size: 32) ?? UIFont.monospacedSystemFont(ofSize: 32, weight: .bold)
        tf.font = font

        // Kerning originale
        tf.defaultTextAttributes[.kern] = 6

        // Cursore originale
        // tf.tintColor = .white

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
    var onDismiss: (() -> Void)? = nil
    var onFullScreenDismiss: (() -> Void)? = nil

    @State private var licensePlate: String = ""
    @Environment(\.dismiss) private var dismiss
    

    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var vehicleImage: UIImage?
    @State private var navigateToCheckDetails = false
    @State private var data : PlateData?
    @State private var isLoadingDetails: Bool = false
    @State private var showConfirmDetailsScreen : Bool = false

    // Vehicle action selection
    @State private var selectedAction: VehicleAction = .addToGarage

    enum VehicleAction: String, CaseIterable, Identifiable {
        case addToGarage
        case justConsult

        var id: String { rawValue }

        var title: String {
            switch self {
            case .addToGarage:
                return "Aggiungi al Garage"
            case .justConsult:
                return "Consulta dati"
            }
        }
    }

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
            Color.customBackgroundColor.ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            NavigationStack {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Text(L10n.enterLicensePlate.localized)
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

                    Picker("", selection: $selectedAction) {
                        ForEach(VehicleAction.allCases) { action in
                            Text(action.title).tag(action)
                        }
                    }
                    .pickerStyle(.segmented)
                    .background(Color.customBackgroundColor)
                    .padding(.horizontal)
                    .padding(.top, 30)
                    .padding(.bottom, 20)

                    Spacer().frame(maxWidth: .infinity).background(Color.customBackgroundColor)

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
                    
                    Spacer().frame(maxWidth: .infinity).background(Color.customBackgroundColor)
                    
                    // Continue Button
                    Button(action: {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        self.showErrorAlert = false
                        isLoadingDetails = true
                        let plate = LicensePlateReader.normalizePlate(licensePlate)
                        logInfo("[PlateUI:manual] continue tapped raw='\(licensePlate)' normalized='\(plate)'")
                        guard !plate.isEmpty else {
                            logWarning("[PlateUI:manual] empty normalized plate")
                            isLoadingDetails = false
                            return
                        }
                        
                        Task {
                            let startedAt = Date()
                            logInfo("[PlateUI:manual] task started plate=\(plate)")
                            let watchdog = Task {
                                try? await Task.sleep(nanoseconds: 5_000_000_000)
                                guard !Task.isCancelled else { return }
                                let loadingAfter5s = await MainActor.run { self.isLoadingDetails }
                                logWarning("[PlateUI:manual] still waiting after 5s plate=\(plate) loading=\(loadingAfter5s)")
                                try? await Task.sleep(nanoseconds: 10_000_000_000)
                                guard !Task.isCancelled else { return }
                                let loadingAfter15s = await MainActor.run { self.isLoadingDetails }
                                logWarning("[PlateUI:manual] still waiting after 15s plate=\(plate) loading=\(loadingAfter15s)")
                            }
                            defer {
                                watchdog.cancel()
                                logInfo("[PlateUI:manual] task finished plate=\(plate) elapsedMs=\(Int(Date().timeIntervalSince(startedAt) * 1000))")
                            }

                            do {
                                logInfo("[PlateUI:manual] fetchPlateSummary.start plate=\(plate)")
                                let data = try await LicensePlateReader.fetchPlateSummary(plate: plate)
                                let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
                                logInfo("[PlateUI:manual] fetchPlateSummary.done plate=\(plate) identity=\(data.hasVehicleIdentityData) image=\(data.vehicleImage != nil) elapsedMs=\(elapsedMs)")
                                if !data.hasVehicleIdentityData {
                                    licensePlate = ""
                                    self.data = data.plate.isEmpty ? PlateData(plate: plate) : data
                                    self.vehicleImage = nil
                                    self.showConfirmDetailsScreen = true
                                    self.isLoadingDetails = false
                                    logWarning("[PlateUI:manual] navigating manual fallback plate=\(plate)")
                                    logInfo("[PlateUI:manual] ui.state loading=\(self.isLoadingDetails) showConfirm=\(self.showConfirmDetailsScreen) navigateCheck=\(self.navigateToCheckDetails) showError=\(self.showErrorAlert)")
                                    return
                                }
                                
                                self.data = data
                                self.vehicleImage = data.vehicleImage
                                licensePlate = ""
                                self.navigateToCheckDetails = true
                                logInfo("[PlateUI:manual] navigating check details plate=\(plate)")
                                logInfo("[PlateUI:manual] ui.state loading=\(self.isLoadingDetails) showConfirm=\(self.showConfirmDetailsScreen) navigateCheck=\(self.navigateToCheckDetails) showError=\(self.showErrorAlert)")
                            }
                            catch let apiError as PlateAPIError {
                                logError("[PlateUI:manual] PlateAPIError plate=\(plate) error=\(apiError.localizedDescription)")
                                switch apiError {
                                case .alreadyInGarage:
                                    self.errorMessage = "Questa targa è già presente nel tuo garage."
                                default:
                                    self.errorMessage = apiError.localizedDescription
                            }
                                self.showErrorAlert = true
                                licensePlate = ""
                                logInfo("[PlateUI:manual] ui.errorState loading=\(self.isLoadingDetails) showError=\(self.showErrorAlert) message='\(self.errorMessage)'")
                                
                            } catch {
                                logError("[PlateUI:manual] generic error plate=\(plate) error=\(error.localizedDescription)")
                                self.errorMessage = error.localizedDescription
                                self.showErrorAlert = true
                                logInfo("[PlateUI:manual] ui.errorState loading=\(self.isLoadingDetails) showError=\(self.showErrorAlert) message='\(self.errorMessage)'")
                            }
                        self.isLoadingDetails = false
                        logInfo("[PlateUI:manual] loading reset plate=\(plate)")
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
                            Text(L10n.continue_.localized)
                                .font(.customFont(size: 18, weight: .bold))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 62)
                        }
                    }
                    .background(Color.customBitterSweet)
                    .cornerRadius(100)
                    .opacity(isContinueEnabled && !isLoadingDetails ? 1.0 : 0.6)
                    .disabled(!isContinueEnabled || isLoadingDetails)
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                    
                    Button(action: {
                        let plate = LicensePlateReader.normalizePlate(licensePlate)
                        logInfo("[PlateUI:manual] manual entry tapped raw='\(licensePlate)' normalized='\(plate)'")
                        if !plate.isEmpty {
                            data = PlateData(plate: plate)
                        }
                        showConfirmDetailsScreen = true
                    }) {
                        Text("Non trovi la tua auto?")
                            .font(.customFont(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .underline()
                    }
                    .padding(.bottom, 20)
                }
                // Background removed here; handled by ZStack above
                .preferredColorScheme(.dark)
                .background(Color.customBackgroundColor)
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
                    CheckDetailsView(
                        onFullScreenDismiss: onFullScreenDismiss, // 👈 propaghi qui!
                        vehicleImage: vehicleImage,
                        plateData: data,
                        consultOnly: selectedAction == .justConsult,
                        isContinueEnabled: .constant(false),
                        viewModel: ConfirmDetailsViewModel()
                    )
                }
                .navigationDestination(isPresented: $showConfirmDetailsScreen) {
                    ConfirmDetailsView(
                        plateData: data ?? nil,
                        manualEntryEnabled: true,
                        viewModel: ConfirmDetailsViewModel(),
                        consultOnly: selectedAction == .justConsult
                    )
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
