import SwiftUI

struct TireData1 {
    let frontLeft: Int
    let frontRight: Int
    let rearLeft: Int
    let rearRight: Int
}
// MARK: - Reports & Documentations View
struct ReportsDocumentationsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""
    @State private var showFilterSheet = false
    
    
   
    
    var body: some View {
        ZStack {
            Color.customBackgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // App Bar
                HStack {
                    Text("Reports & Docs")
                        .font(.custom("Sora-SemiBold", size: 36))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .frame(height: 62)
                
                // Search + Filter
                HStack(spacing: 4) {
                    // Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                        
                        TextField("Search...", text: $searchText)
                            .font(.custom("Sora-Regular", size: 14))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .frame(width: 340)
                    .background(Color(hex: "212121"))
                    .cornerRadius(35)
                    
                    // Filter Button
                    Button(action: { showFilterSheet = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(Color(hex: "212121"))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                
                // Scrollable Content
                ScrollView {
                    VStack(spacing: 22) {
                        // Report Cards (with random values)
                        ReportCard(
                            vehicleName: ["Tesla Model 3", "BMW X5", "Audi A3", "Toyota Camry", "Hyundai Tucson"].randomElement()!,
                            description: [
                                "All tires in fair condition. Rear right tire shows signs of uneven wear.",
                                "Front tires show moderate wear. Rear tires in good condition.",
                                "All tires in excellent condition. No immediate action needed.",
                                "Rear left tire pressure slightly low. Monitor over next week.",
                                "Uneven wear detected on front right tire. Rotation recommended."
                            ].randomElement()!,
                            reportType: ["Quick Scan", "Complete Tire Health", "Rotation Check"].randomElement()!,
                            date: {
                                let formatter = DateFormatter()
                                formatter.dateFormat = "MMM d, yyyy"
                                let daysAgo = Int.random(in: 0...10)
                                let randomDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
                                return formatter.string(from: randomDate)
                            }(),
                            tireData: TireData1(
                                frontLeft: Int.random(in: 60...100),
                                frontRight: Int.random(in: 60...100),
                                rearLeft: Int.random(in: 60...100),
                                rearRight: Int.random(in: 60...100)
                            )
                        )
                        
                        // Document Card (with random values)
                        DocumentCard(
                            title: [
                                "Toyota Camry",
                                "Tire Replacement Invoice",
                                "Service History",
                                "Inspection Certificate",
                                "BMW X5"
                            ].randomElement()!,
                            subtitle: [
                                "TireCity Auto Service",
                                "AutoPro Garage",
                                "QuickFix Center",
                                "Speedy Wheels",
                                "Urban Motors"
                            ].randomElement()!,
                            date: {
                                let formatter = DateFormatter()
                                formatter.dateFormat = "MMM d, yyyy"
                                let daysAgo = Int.random(in: 0...15)
                                let randomDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
                                return formatter.string(from: randomDate)
                            }(),
                            iconColor: [
                                Color(hex: "F36656").opacity(0.1),
                                Color(hex: "FEB96A").opacity(0.1),
                                Color(hex: "5CEBFF").opacity(0.1),
                                Color(hex: "2FB8FF").opacity(0.1),
                                Color(hex: "A9FF8B").opacity(0.1)
                            ].randomElement()!,
                            icon: [
                                "doc.text",
                                "wrench.and.screwdriver",
                                "checkmark.seal",
                                "car.fill",
                                "doc.plaintext"
                            ].randomElement()!
                        )
                        
                        // Another Report Card (with random values)
                        ReportCard(
                            vehicleName: ["Tesla Model 3", "BMW X5", "Audi A3", "Toyota Camry", "Hyundai Tucson"].randomElement()!,
                            description: [
                                "All tires in good condition. Recommend rotations in the next 1,000 miles.",
                                "Front right tire needs replacement soon.",
                                "Tire pressure optimal for all tires.",
                                "Check rear left tire for slow leak.",
                                "Excellent tread depth on all tires."
                            ].randomElement()!,
                            reportType: ["Quick Scan", "Complete Tire Health", "Rotation Check"].randomElement()!,
                            date: {
                                let formatter = DateFormatter()
                                formatter.dateFormat = "MMM d, yyyy"
                                let daysAgo = Int.random(in: 0...20)
                                let randomDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
                                return formatter.string(from: randomDate)
                            }(),
                            tireData: TireData1(
                                frontLeft: Int.random(in: 60...100),
                                frontRight: Int.random(in: 60...100),
                                rearLeft: Int.random(in: 60...100),
                                rearRight: Int.random(in: 60...100)
                            )
                        )
                        
                        // Service Document Card (with random values)
                        DocumentCard(
                            title: [
                                "Wheel Alignment Report",
                                "Tire Rotation Receipt",
                                "Brake Inspection",
                                "Annual Service Document",
                                "Alignment Certificate"
                            ].randomElement()!,
                            subtitle: [
                                "TireCity Auto Service",
                                "AutoPro Garage",
                                "QuickFix Center",
                                "Speedy Wheels",
                                "Urban Motors"
                            ].randomElement()!,
                            date: {
                                let formatter = DateFormatter()
                                formatter.dateFormat = "MMM d, yyyy"
                                let daysAgo = Int.random(in: 0...30)
                                let randomDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
                                return formatter.string(from: randomDate)
                            }(),
                            iconColor: [
                                Color(hex: "FEB96A").opacity(0.1),
                                Color(hex: "F36656").opacity(0.1),
                                Color(hex: "5CEBFF").opacity(0.1),
                                Color(hex: "2FB8FF").opacity(0.1),
                                Color(hex: "A9FF8B").opacity(0.1)
                            ].randomElement()!,
                            icon: [
                                "wrench.and.screwdriver",
                                "doc.text",
                                "car.fill",
                                "doc.plaintext",
                                "checkmark.seal"
                            ].randomElement()!
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 22)
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Report Card Component
struct ReportCard: View {
    let vehicleName: String
    let description: String
    let reportType: String
    let date: String
    let tireData: TireData1
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "212121"))
                .frame(height: 214)
            
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 10) {
                    Text(vehicleName)
                        .font(.custom("Sora-SemiBold", size: 14))
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.custom("Sora-Regular", size: 12))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                        .frame(height: 35)
                }
                .padding(.top, 38)
                .padding(.horizontal, 14)
                
                Spacer()
                
                // Tire Data
                HStack(spacing: 36) {
                    VStack(spacing: 10) {
                        TireDataRow(label: "Front Left:", value: "\(tireData.frontLeft)%")
                        TireDataRow(label: "Rear Left:", value: "\(tireData.rearLeft)%")
                    }
                    .frame(width: 123)
                    
                    VStack(spacing: 10) {
                        TireDataRow(label: "Front Right:", value: "\(tireData.frontRight)%")
                        TireDataRow(label: "Rear Right:", value: "\(tireData.rearRight)%")
                    }
                    .frame(width: 133)
                }
                .padding(.leading, 50)
                .padding(.bottom, 18)
                
                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)
                    .padding(.horizontal, 26)
                
                // Footer
                HStack {
                    // Report Type Badge
                    Text(reportType)
                        .font(.custom("Sora-Regular", size: 10))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(hex: "191919"))
                        .cornerRadius(12)
                    
                    Spacer()
                    
                    // Action Buttons
                    HStack(spacing: 12) {
                        Button(action: {}) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "arrow.down.to.line")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 14)
                
                // Date
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                    
                    Text(date)
                        .font(.custom("Sora-Regular", size: 12))
                        .foregroundColor(.white)
                }
                .padding(.leading, 26)
                .padding(.bottom, 14)
            }
        }
        .frame(height: 214)
        .padding(.horizontal,24)
    }
}

// MARK: - Tire Data Row
struct TireDataRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.custom("Sora-Regular", size: 14))
                .foregroundColor(.white.opacity(0.6))
            
            Spacer()
            
            Text(value)
                .font(.custom("Sora-Regular", size: 14))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Document Card Component
struct DocumentCard: View {
    let title: String
    let subtitle: String
    let date: String
    let iconColor: Color
    let icon: String
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Background
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "212121"))
                .frame(height: 101)
            
            HStack(spacing: 0) {
                // Icon Container
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor)
                        .frame(width: 55, height: 85)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                .padding(.leading, 8)
                
                // Content
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.custom("Sora-SemiBold", size: 14))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(subtitle)
                            .font(.custom("Sora-Regular", size: 12))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                        
                        Text(date)
                            .font(.custom("Sora-Regular", size: 12))
                            .foregroundColor(.white)
                    }
                }
                .padding(.leading, 17)
                .padding(.vertical, 14)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {}) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "arrow.down.to.line")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                }
                .padding(.trailing, 12)
            }
        }
        .frame(height: 101)
    }
}

// MARK: - Depth Indicator Component
struct DepthIndicator: View {
    let measurement: TireDepthMeasurement
    let isSelected: Bool
    
    var depthColor: Color {
        if measurement.depth > 5.0 {
            return Color.green
        } else if measurement.depth > 3.0 {
            return Color.yellow
        } else {
            return Color.red
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Lines Pattern (when not selected)
            if !isSelected {
                VStack(spacing: 2) {
                    ForEach(0..<5) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(0.4))
                            .frame(height: 2)
                    }
                }
                .frame(width: 42, height: 61)
                .offset(y: -4)
            }
            
            // Measurement Box
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        isSelected ?
                        LinearGradient(
                            colors: [Color(hex: "5CEBFF"), Color(hex: "2FB8FF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color.white],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isSelected ? 2 : 1
                    )
                    .frame(width: 42, height: 72)
                    .opacity(isSelected ? 1.0 : 0.6)
                
                // Depth Value Display (when selected)
                if isSelected {
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f", measurement.depth))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(depthColor)
                        
                        Text("mm")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                // Glow Effect
                if isSelected {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(depthColor, lineWidth: 3)
                        .frame(width: 44, height: 74)
                        .blur(radius: 4)
                        .opacity(0.6)
                }
            }
        }
    }
}

// MARK: - Tire Depth Measurement Model
struct TireDepthMeasurement {
    let position: TirePosition
    let depth: Double // in millimeters
    
    var status: DepthStatus {
        if depth > 5.0 {
            return .good
        } else if depth > 3.0 {
            return .medium
        } else {
            return .critical
        }
    }
}

// MARK: - Depth Status Enum
enum DepthStatus {
    case good
    case medium
    case critical
    
    var color: Color {
        switch self {
        case .good: return .green
        case .medium: return .yellow
        case .critical: return .red
        }
    }
    
    var description: String {
        switch self {
        case .good: return "Good Condition"
        case .medium: return "Monitor Closely"
        case .critical: return "Replace Soon"
        }
    }
}

// MARK: - Preview
struct TireProfileDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ReportsDocumentationsView()
        
    }
}
