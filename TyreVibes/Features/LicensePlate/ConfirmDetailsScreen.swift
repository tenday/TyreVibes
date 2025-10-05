import SwiftUI

struct ConfirmDetailsView: View {
    var onFullScreenDismiss: (() -> Void)? = nil
    let plateData: PlateData?
    let manualEntryEnabled : Bool
    let consultOnly: Bool
    @State private var isContinueEnabled: Bool = false
    @State private var selectedColor: Color = .black
    @ObservedObject var viewModel: ConfirmDetailsViewModel
    init(plateData: PlateData?, manualEntryEnabled: Bool, viewModel: ConfirmDetailsViewModel, consultOnly: Bool = false, onFullScreenDismiss: (() -> Void)? = nil) {
        self.plateData = plateData
        self.manualEntryEnabled = manualEntryEnabled
        self.consultOnly = consultOnly
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.onFullScreenDismiss = onFullScreenDismiss
    }
    @Environment(\.dismiss) private var dismiss
    
    @State private var navigateToCheckDetails: Bool = false
    @State private var makeText: String = ""
    @State private var modelText: String = ""
    @State private var yearText: String = ""
    @State private var engineText: String = ""
    @State private var licenseText: String = ""
    @State private var fuelText: String = ""
    @State private var powerText: String = ""

    // Form validation computed property
    private var isFormValid: Bool {
        !makeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !modelText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !licenseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Color.customBackgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom navigation bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .resizable()
                            .frame(width: 15, height: 24)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Text("Confirm Details")
                        .font(.customFont(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.top)
                .padding(.bottom, 20)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Detail items
                        VStack(alignment:.center, spacing: 14) {
                            if manualEntryEnabled {
                                VStack(spacing: 12) {
                                    TextField("Marchio (es. Fiat)", text: $makeText)
                                        .font(.customFont(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding()
                                        .frame(height: 56)
                                        .background(Color.customFieldColor)
                                        .cornerRadius(12)
                                        .autocapitalization(.words)

                                    TextField("Modello (es. 500)", text: $modelText)
                                        .font(.customFont(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding()
                                        .frame(height: 56)
                                        .background(Color.customFieldColor)
                                        .cornerRadius(12)
                                        .autocapitalization(.words)

                                    HStack(spacing: 12) {
                                        TextField("Anno", text: $yearText)
                                            .font(.customFont(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding()
                                            .frame(height: 56)
                                            .background(Color.customFieldColor)
                                            .cornerRadius(12)
                                            .keyboardType(.numberPad)

                                        TextField("Cilindrata (cc)", text: $engineText)
                                            .font(.customFont(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding()
                                            .frame(height: 56)
                                            .background(Color.customFieldColor)
                                            .cornerRadius(12)
                                            .keyboardType(.numberPad)
                                    }

                                    TextField("Targa (es. AB123CD)", text: $licenseText)
                                        .font(.customFont(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding()
                                        .frame(height: 56)
                                        .background(Color.customFieldColor)
                                        .cornerRadius(12)
                                        .autocapitalization(.allCharacters)
                                        .autocorrectionDisabled()

                                    HStack(spacing: 12) {
                                        TextField("Alimentazione", text: $fuelText)
                                            .font(.customFont(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding()
                                            .frame(height: 56)
                                            .background(Color.customFieldColor)
                                            .cornerRadius(12)

                                        TextField("CV", text: $powerText)
                                            .font(.customFont(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding()
                                            .frame(height: 56)
                                            .background(Color.customFieldColor)
                                            .cornerRadius(12)
                                            .keyboardType(.numberPad)
                                    }
                                }
                            } else {
                                DetailRow(label: "Marchio:", value: plateData?.make ?? "-")
                                DetailRow(label: "Modello:", value: plateData?.modelDetails ?? "-")
                                DetailRow(label: "Immatricolazione:", value: plateData?.registrationDate ?? "-")
                                if plateData?.displacementCC != "0" {
                                    DetailRow(label: "Cilindrata:", value: plateData?.displacementCC ?? "-")
                                }
                                DetailRow(label: "Targa:", value: plateData?.plate ?? "-")
                                DetailRow(label: "Alimentazione:", value: plateData?.fuelType ?? "-")
                                DetailRow(label: "Cavalli:", value: "\(plateData?.powerCV ?? "-") CV")
                            }
                        }
                        .padding(.horizontal, 24)

                        // Color picker
                        VStack(spacing: 10) {
                            ColorPickerView(selectedColor: $selectedColor)
                                .background(Color.customFieldColor)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 24)

                        if !consultOnly {
                            VStack {
                                Button(action: {
                                    performVehicleAction()
                                }) {
                                    if viewModel.isLoading {
                                        Text("")
                                            .foregroundColor(Color.white)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 62)
                                            .background(Color.customBitterSweet)
                                            .cornerRadius(28)
                                            .overlay(ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(1.2)
                                                .frame(height: 62)
                                                .frame(maxWidth: .infinity))
                                    } else {
                                        Text("Confirm")
                                            .font(.customFont(size: 18, weight: .semibold))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 62)
                                            .background(Color.customBitterSweet)
                                            .cornerRadius(28)
                                    }
                                }
                                .disabled(viewModel.isLoading || (manualEntryEnabled && !isFormValid))
                                .opacity((manualEntryEnabled && !isFormValid) ? 0.5 : 1.0)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 30)
                            }
                        }

                        Spacer(minLength: 20)
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToCheckDetails) {
                CheckDetailsView(
                    onFullScreenDismiss: onFullScreenDismiss,
                    vehicleImage: plateData?.vehicleImage ?? nil,
                    plateData: plateData,
                    consultOnly: consultOnly,
                    isContinueEnabled: $isContinueEnabled,
                    viewModel: viewModel
                )
            }
            .onReceive(viewModel.$didSavePlate) { newValue in
                if newValue {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        isContinueEnabled = true
                        navigateToCheckDetails = true
                    }
                }
            }
            .alert(item: $viewModel.alertItem) { alertItem in
                Alert(
                    title: Text(alertItem.title),
                    message: Text(alertItem.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .background(InteractivePopGestureEnabler())
        }
    }

    private func performVehicleAction() {
        guard !consultOnly else { return }

        // Se è in modalità inserimento manuale, crea un nuovo PlateData con i dati inseriti
        if manualEntryEnabled {
            // Validazione campi obbligatori
            guard !makeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !modelText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !licenseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                viewModel.alertItem = AlertItem(
                    title: "Dati mancanti",
                    message: "Compila almeno i campi: Marchio, Modello e Targa"
                )
                return
            }

            // Crea un PlateData con i dati inseriti manualmente
            let manualPlateData = PlateData(
                plate: licenseText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                make: makeText.trimmingCharacters(in: .whitespacesAndNewlines),
                model: modelText.trimmingCharacters(in: .whitespacesAndNewlines),
                version: "",
                year: yearText.trimmingCharacters(in: .whitespacesAndNewlines),
                month: "",
                color: ColorPickerView(selectedColor: .constant(selectedColor)).colorName(for: selectedColor),
                fuelType: fuelText.trimmingCharacters(in: .whitespacesAndNewlines),
                powerKW: "",
                powerCV: powerText.trimmingCharacters(in: .whitespacesAndNewlines),
                modelDetails: modelText.trimmingCharacters(in: .whitespacesAndNewlines),
                displacementCC: engineText.trimmingCharacters(in: .whitespacesAndNewlines),
                registrationDate: yearText.trimmingCharacters(in: .whitespacesAndNewlines),
                vin: "",
                insuranceCompany: nil,
                insuranceExpiry: nil,
                insurancePresent: false,
                insurancePolicyNumber: nil,
                emissionClass: nil,
                tyres: [],
                saleEnd: nil,
                gearbox: nil,
                maxSpeed: nil,
                bodyType: nil,
                doors: nil,
                seats: nil,
                consumption: nil,
                traction: nil,
                powerCVKW: powerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : "\(powerText) CV"
            )

            let colorName = ColorPickerView(selectedColor: .constant(selectedColor)).colorName(for: selectedColor)
            Task {
                await viewModel.savePlate(plateData: manualPlateData, color: colorName, angle: 23)
            }
            return
        }

        // Logica esistente per dati automatici
        guard let plate = plateData else { return }

        if LicensePlateReader.exists, !plate.plate.isEmpty {
            Task {
                await viewModel.associateVehicleWithUser(vehicleId: plate.vehicleId ?? 0)
            }
        } else {
            let colorName = ColorPickerView(selectedColor: .constant(selectedColor)).colorName(for: selectedColor)
            Task {
                await viewModel.savePlate(plateData: plate, color: colorName, angle: 23)
            }
        }
    }
}

// Reusable Detail Row
struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .center) {
            Spacer().frame(width: 10)
            Text(label)
                .font(.customFont(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.customFont(size: 18, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Spacer().frame(width: 20)

        }
        .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 1)
        .padding(.vertical, 8)
        .background(Color.customFieldColor)
        .cornerRadius(12)
    }
}

struct ColorPickerView: View {
    @Binding var selectedColor: Color
    @State private var displayAngle: Double = 0

    private let size: CGFloat = 140
    private let ringWidth: CGFloat = 23

    var body: some View {
        VStack(spacing: 10) {
            Text("Choose Color:")
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .font(.customFont(size: 18, weight: .semibold))
            
            HStack {
                ZStack {
                    // Base ring with discrete segments using AngularGradient with duplicated stops
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .black, location: 0.0),
                                    .init(color: .black, location: 0.125),

                                    .init(color: .white, location: 0.125),
                                    .init(color: .white, location: 0.25),

                                    .init(color: .red, location: 0.25),
                                    .init(color: .red, location: 0.375),

                                    .init(color: .orange, location: 0.375),
                                    .init(color: .orange, location: 0.5),

                                    .init(color: .yellow, location: 0.5),
                                    .init(color: .yellow, location: 0.625),

                                    .init(color: .green, location: 0.625),
                                    .init(color: .green, location: 0.75),

                                    .init(color: .blue, location: 0.75),
                                    .init(color: .blue, location: 0.875),

                                    .init(color: .gray, location: 0.875),
                                    .init(color: .gray, location: 1.0)
                                ]),
                                center: .center
                            ),
                            lineWidth: ringWidth
                        )
                        .frame(width: size, height: size)
                    
                    // Inner shadow ring for depth
                    Circle()
                        .stroke(Color.black.opacity(0.25), lineWidth: 4)
                        .blur(radius: 2)
                        .offset(x: 2, y: 2)
                        .mask(Circle().stroke(lineWidth: ringWidth))
                        .frame(width: size, height: size)
                    
                    ZStack {
                        Circle()
                            .fill(selectedColor)
                            .frame(width: 44, height: 44)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
                            .offset(x: (size/2 - ringWidth/2))
                    }
                    .frame(width: size, height: size)
                    .rotationEffect(.radians(displayAngle))
                }
                .contentShape(Circle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let center = CGPoint(x: size/2, y: size/2)
                            let dx = value.location.x - center.x
                            let dy = value.location.y - center.y
                            var ang = atan2(dy, dx)
                            if ang < 0 { ang += 2 * .pi }
                            // Choose the nearest equivalent angle (avoid crossing the center and cutting through the ring)
                            let current = displayAngle
                            let twoPi = 2 * Double.pi
                            var target = Double(ang)
                            while target - current > Double.pi { target -= twoPi }
                            while target - current < -Double.pi { target += twoPi }
                            withAnimation(.easeInOut) {
                                displayAngle = target
                            }
                            let normalized = ang / (2 * .pi)
                            switch normalized {
                            case 0..<0.125:   selectedColor = .black
                            case 0.125..<0.25: selectedColor = .white
                            case 0.25..<0.375: selectedColor = .red
                            case 0.375..<0.5:  selectedColor = .orange
                            case 0.5..<0.625:  selectedColor = .yellow
                            case 0.625..<0.75: selectedColor = .green
                            case 0.75..<0.875: selectedColor = .blue
                            case 0.875..<1.0:  selectedColor = .gray
                            default: selectedColor = .black
                            }
                        }
                )
                .frame(width: size, height: size)
                .padding(.horizontal, 17)
                .padding(.bottom, 16)
                
                Spacer()
                
                
                HStack {
                    Circle().fill(selectedColor).frame(width: 28, height: 28)
                    Text(colorName(for: selectedColor))
                        .font(.customFont(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)

    }

    // Helper to get a readable color name from a Color
    public func colorName(for color: Color) -> String {
        // Try to extract hue, saturation, brightness from the Color
        #if canImport(UIKit)
        // UIKit (iOS)
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        if uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return nameForHSV(hue: Double(hue), saturation: Double(saturation), brightness: Double(brightness))
        }
        #elseif canImport(AppKit)
        // macOS
        let nsColor = NSColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        if nsColor.usingColorSpace(.deviceRGB)?.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) ?? false {
            return nameForHSV(hue: Double(hue), saturation: Double(saturation), brightness: Double(brightness))
        }
        #endif
        return "Custom"
    }

    private func nameForHSV(hue: Double, saturation: Double, brightness: Double) -> String {
        guard saturation > 0.2, brightness > 0.2 else {
            if brightness < 0.3 { return "Black" }
            if brightness > 0.85 { return "White" }
            return "Gray"
        }
        let deg = hue * 360
        switch deg {
        case 0..<15, 345...360:
            return "Red"
        case 15..<45:
            return "Orange"
        case 45..<70:
            return "Yellow"
        case 70..<170:
            return "Green"
        case 170..<200:
            return "Cyan"
        case 200..<260:
            return "Blue"
        case 260..<290:
            return "Purple"
        case 290..<345:
            return "Magenta"
        default:
            return "Custom"
        }
        }
    }

#Preview {
    ConfirmDetailsView(
        plateData: PlateData(
            plate: "GB241PT",
            make: "SEAT",
            model: "Leon",
            version: "FR",
            year: "2020",
            month: "08",
            color: "Black",
            fuelType: "Hybrid",
            powerKW: "110",
            powerCV: "150",
            modelDetails: "Leon 1.5 eTSI 150 CV DSG FR",
            displacementCC: "1500",
            registrationDate: "08/2020",
            vin: "WVWZZZ1KZ6W000001",
            insuranceCompany: "Allianz",
            insuranceExpiry: Date(),
            insurancePresent: true,
            insurancePolicyNumber: "123456789",
            emissionClass: "EURO 6",
            tyres: [],
            saleEnd: "12/2020",
            gearbox: "Automatic",
            maxSpeed: "221 km/h",
            bodyType: "Hatchback",
            doors: "5",
            seats: "5",
            consumption: "Urban: 6.1 / Extra-urban: 4.2 / Combined: 5.6",
            traction: "Front",
            powerCVKW: "150 CV (110 kW)"
        ),
        manualEntryEnabled: false,
        viewModel: ConfirmDetailsViewModel()
    )
        .preferredColorScheme(.dark)
}
