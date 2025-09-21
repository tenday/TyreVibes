import SwiftUI

struct ConfirmDetailsTyreView: View {
    let tireData: TireData

    @Environment(\.dismiss) var dismiss
    @State private var selectedSeason: String

    init(tireData: TireData) {
        self.tireData = tireData
        // Usa la stagionalità rilevata automaticamente, altrimenti default "Winter"
        self._selectedSeason = State(initialValue: tireData.season.isEmpty ? "Winter" : tireData.season)
    }

    private func displayValue(_ value: String) -> String {
        value.isEmpty ? "-" : value
    }
    
    private func productionDate(from dot: String) -> String {
        guard dot.count == 4,
              let week = Int(dot.prefix(2)),
              let year = Int(dot.suffix(2)) else { return "-" }
        
        let calendar = Calendar.current
        let yearFull = 2000 + year
        if let date = calendar.date(from: DateComponents(calendar: calendar, year: yearFull, weekday: 1, weekOfYear: week)) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/yyyy"
            return formatter.string(from: date)
        }
        return "-"
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.customBackgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Navigation Bar
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.customFont(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text("Confirm Details")
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
                    DetailRow(label: "Size Label:", value: displayValue(tireData.size))
                    DetailRow(label: "DOT:", value: displayValue("\(tireData.dot) (\(productionDate(from: tireData.dot)))"))
                    DetailRow(label: "Make:", value: displayValue(tireData.brand))
                    DetailRow(label: "Model:", value: displayValue(tireData.model))
                    DetailRow(label: "Load Index:", value: displayValue(tireData.loadIndex))
                    DetailRow(label: "Speed Rating:", value: displayValue(tireData.speedRating))
                    DetailRowMenu(label: "Season:", value: $selectedSeason)
                }
                .padding(.top, 56)
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Confirm Button
                Button(action: {
                    // Handle confirmation
                    print("Confirmed")
                }) {
                    Text("Confirm")
                        .font(.customFont(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.customBitterSweet)
                        .cornerRadius(28)
                }
                .padding(.horizontal, 24)
            }
        }
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
    }
}


struct DetailRowMenu: View {
    var label: String
    @Binding var value: String
    
    var body: some View {
        HStack {
            Spacer().frame(width: 10)
            Text(label)
                .font(.customFont(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
            
            Spacer()
            
            Menu {
                Button(action: { value = "Winter" }) {
                    Text("Winter")
                        .font(.customFont(size: 15, weight: .bold))
                }
                Button(action: { value = "Summer" }) {
                    Text("Summer")
                        .font(.customFont(size: 15, weight: .bold))
                }
                Button(action: { value = "All Season" }) {
                    Text("All Season")
                        .font(.customFont(size: 15, weight: .bold))
                }
            } label: {
                HStack(spacing: 8) {
                    Text(value)
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
                return data
            }()
        )
    }
}
