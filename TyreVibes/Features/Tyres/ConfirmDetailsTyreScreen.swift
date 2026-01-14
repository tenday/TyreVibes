import Foundation
import SwiftUI

struct ConfirmDetailsTyreView: View {
    let tireData: TireData
    var onConfirm: ((String, String) -> Void)? = nil
    var onCancel: (() -> Void)? = nil
    var onConfirmCompletion: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var selectedSeason: String
    @State private var modelText: String
    @FocusState private var modelFieldFocused: Bool
    @State private var showModelAlert = false
    @StateObject private var viewModel = TyreViewModel()

    
    

    init(tireData: TireData, onConfirm: ((String, String) -> Void)? = nil, onCancel: (() -> Void)? = nil, onConfirmCompletion: (() -> Void)? = nil) {
        self.tireData = tireData
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        self.onConfirmCompletion = onConfirmCompletion
        // Usa la stagionalità rilevata automaticamente, altrimenti default "Winter"
        self._selectedSeason = State(initialValue: tireData.season.isEmpty ? "Winter" : tireData.season)
        self._modelText = State(initialValue: tireData.model)
    }

    private func displayValue(_ value: String) -> String {
        value.isEmpty ? "-" : value
    }

    private var isModelValid: Bool {
        !modelText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func productionDate(from dot: String) -> String {
        let trimmedDOT = dot.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedDOT.count == 4,
              let week = Int(trimmedDOT.prefix(2)),
              let year = Int(trimmedDOT.suffix(2)) else { return "-" }

        let calendar = Calendar.current
        let yearFull = 2000 + year
        if let date = calendar.date(from: DateComponents(calendar: calendar, year: yearFull, weekday: 1, weekOfYear: week)) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/yyyy"
            return formatter.string(from: date)
        }
        return "-"
    }

    private func dotDisplayValue() -> String {
        let trimmedDOT = tireData.dot.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDOT.isEmpty else { return "" }
        let dateString = productionDate(from: trimmedDOT)
        return dateString == "-" ? trimmedDOT : "\(trimmedDOT) (\(dateString))"
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.customBackgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Navigation Bar
                HStack {
                    Button(action: handleCancel) {
                        Image(systemName: "chevron.left")
                            .font(.customFont(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text(L10n.confirmDetails.localized)
                        .font(.customFont(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Invisible spacer for centering
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24))
                        .foregroundColor(.clear)
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                
                // Details List
                VStack(spacing: 14) {
                    DetailRow(label: "\(String(localized: "Size")):", value: displayValue(tireData.size))
                    DetailRow(label: "\(String(localized: "DOT")):", value: displayValue(dotDisplayValue()))
                    DetailRow(label: "\(String(localized: "Make")):", value: displayValue(tireData.brand))
                    DetailRowTextField(
                        label: "\(String(localized: "Model")):",
                        placeholder: String(localized: "Enter model"),
                        text: $modelText
                    )
                    .focused($modelFieldFocused)
                    DetailRow(label: "\(String(localized: "Load Index")):", value: displayValue(tireData.loadIndex))
                    DetailRow(label: "\(String(localized: "Speed Rating")):", value: displayValue(tireData.speedRating))
                    DetailRowMenu(label: "\(String(localized: "Season")):", value: $selectedSeason)
                }
                .padding(.top, 56)
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Confirm Button
                Button(action: confirmAction) {
                    if viewModel.isLoading {
                        Text("")
                            .foregroundColor(Color.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.customBitterSweet)
                            .cornerRadius(28)
                            .overlay(ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                                .frame(maxWidth: .infinity))
                            .disabled(true)
                    }
                    else {
                    Text(L10n.confirm.localized)
                        .font(.customFont(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(isModelValid ? Color.customBitterSweet : Color.customBitterSweet.opacity(0.6))
                        .cornerRadius(28)
                    }
                    
                }
                .disabled(!isModelValid)
                .padding(.horizontal, 24)
            }
        }
        .navigationBarHidden(true)
        .overlay(
            Group {
                if showModelAlert {
                    CustomAlertView(
                        title: String(localized: "Enter the tire model to continue."),
                        showProgress: false
                    )
                }
            }
        )
        .preferredColorScheme(.dark)
        .onAppear {
            if !isModelValid {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    modelFieldFocused = true
                }
            }
        }
        .onChange(of: viewModel.success) { oldValue, newValue in
            print("✅ Success changed: \(oldValue) -> \(newValue)")
            if newValue {
                print("✅ Chiamando onConfirmCompletion")
                onConfirmCompletion?()
            }
        }
        .onChange(of: viewModel.errorMessage) { oldValue, newValue in
            if let error = newValue {
                print("Errore inserimento pneumatico: \(error)")
            }
        }
    }

    private func confirmAction() {
        let trimmedModel = modelText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedModel.isEmpty else {
            modelFieldFocused = true
            showModelAlert = false
            DispatchQueue.main.async {
                showModelAlert = true
            }
            return
        }
        modelText = trimmedModel


        viewModel.brand       = tireData.brand
        viewModel.model       = trimmedModel
        viewModel.size        = tireData.size
        viewModel.dot         = tireData.dot
        viewModel.loadIndex   = tireData.loadIndex
        viewModel.speedRating = tireData.speedRating
        viewModel.season      = selectedSeason
        viewModel.setName     = tireData.setName
        viewModel.setPosition = tireData.setPosition

        viewModel.insertTyre(vehicleId: Int(tireData.vehicleId))
    }

    private func handleCancel() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            onCancel?()
        }
    }
}


struct DetailRowMenu: View {
    var label: String
    @Binding var value: String

    private func localizedSeason(_ season: String) -> String {
        switch season {
        case "Winter":
            return L10n.winter.localized
        case "Summer":
            return L10n.summer.localized
        case "All Season":
            return L10n.allSeason.localized
        default:
            return season
        }
    }
    
    var body: some View {
        HStack {
            Spacer().frame(width: 10)
            Text(label)
                .font(.customFont(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
            
            Spacer()
            
            Menu {
                Button(action: { value = "Winter" }) {
                    Text(L10n.winter.localized)
                        .font(.customFont(size: 15, weight: .bold))
                }
                Button(action: { value = "Summer" }) {
                    Text(L10n.summer.localized)
                        .font(.customFont(size: 15, weight: .bold))
                }
                Button(action: { value = "All Season" }) {
                    Text(L10n.allSeason.localized)
                        .font(.customFont(size: 15, weight: .bold))
                }
            } label: {
                HStack(spacing: 8) {
                    Text(localizedSeason(value))
                        .font(.customFont(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(minWidth: 100, alignment: .leading)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14))
                }
                .foregroundColor(.white)
            }
            Spacer().frame(width: 20)
        }
        .frame(maxWidth: .infinity, minHeight: 20, maxHeight: 50)
        .background(Color.customFieldColor)
        .cornerRadius(12)
    }
}

struct DetailRowTextField: View {
    var label: String
    var placeholder: String
    @Binding var text: String

    var body: some View {
        HStack {
            Spacer().frame(width: 10)
            Text(label)
                .font(.customFont(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))

            Spacer()

            TextField(placeholder, text: $text)
                .font(.customFont(size: 18, weight: .bold))
                .foregroundColor(.white)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.words)
                .multilineTextAlignment(.trailing)

            Spacer().frame(width: 20)
        }
        .frame(maxWidth: .infinity, minHeight: 20, maxHeight: 50)
        .background(Color.customFieldColor)
        .cornerRadius(12)
    }
}

// Preview
struct ConfirmDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        ConfirmDetailsTyreView(
            tireData: {
                var data = TireData()
                data.brand = "Pirelli"
                data.model = "Cinturato"
                data.size = "205/55R18"
                data.dot = "0323"
                data.loadIndex = "91"
                data.speedRating = "V"
                data.season = "Winter"
                data.vehicleId = 1
                return data
            }()
        )
    }
}
