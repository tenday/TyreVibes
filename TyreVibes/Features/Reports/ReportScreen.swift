import SwiftUI

// MARK: - Data Models
struct TireReport: Identifiable {
    let id = UUID()
    let vehicleName: String
    let serviceName: String
    let date: Date
    let frontLeftTire: Int
    let frontRightTire: Int
    let rearLeftTire: Int
    let rearRightTire: Int
    let description: String
    let reportType: ReportType
    
    enum ReportType {
        case complete
        case quick
        case wheelAlignment
        
        var icon: String {
            switch self {
            case .complete: return "doc.text.fill"
            case .quick: return "gauge"
            case .wheelAlignment: return "wrench.and.screwdriver"
            }
        }
        
        var iconColor: Color {
            switch self {
            case .complete: return .gray
            case .quick: return .gray
            case .wheelAlignment: return .orange
            }
        }
    }
}

// MARK: - Main View
struct ReportsDocsView: View {
    @State private var searchText = ""
    @State private var reports: [TireReport] = [
        TireReport(
            vehicleName: "Vehicle Name",
            serviceName: "Complete Tire Health",
            date: Date(timeIntervalSince1970: 1741132800), // May 9, 2025
            frontLeftTire: 82,
            frontRightTire: 78,
            rearLeftTire: 85,
            rearRightTire: 64,
            description: "All tires in fair condition. Rear right tire shows signs of uneven wear.",
            reportType: .complete
        ),
        TireReport(
            vehicleName: "Toyota Camry",
            serviceName: "TireCity Auto Service",
            date: Date(timeIntervalSince1970: 1740873600), // May 7, 2025
            frontLeftTire: 0,
            frontRightTire: 0,
            rearLeftTire: 0,
            rearRightTire: 0,
            description: "",
            reportType: .complete
        ),
        TireReport(
            vehicleName: "Toyota Camry",
            serviceName: "Quick Scan",
            date: Date(timeIntervalSince1970: 1740700800), // May 5, 2025
            frontLeftTire: 88,
            frontRightTire: 85,
            rearLeftTire: 90,
            rearRightTire: 72,
            description: "All tires in good condition. Recommend rotations in the next 1,000 miles.",
            reportType: .quick
        ),
        TireReport(
            vehicleName: "Wheel Alignment Report",
            serviceName: "TireCity Auto Service",
            date: Date(timeIntervalSince1970: 1738454400), // May 2, 2025
            frontLeftTire: 0,
            frontRightTire: 0,
            rearLeftTire: 0,
            rearRightTire: 0,
            description: "",
            reportType: .wheelAlignment
        )
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HeaderView(searchText: $searchText)
                
                // Reports List
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(filteredReports) { report in
                            ReportCardView(report: report)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }
            
            // Bottom Tab Bar
            VStack {
                Spacer()
                TabBarView()
            }
        }
    }
    
    var filteredReports: [TireReport] {
        if searchText.isEmpty {
            return reports
        } else {
            return reports.filter { report in
                report.vehicleName.localizedCaseInsensitiveContains(searchText) ||
                report.serviceName.localizedCaseInsensitiveContains(searchText) ||
                report.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

// MARK: - Header View
struct HeaderView: View {
    @Binding var searchText: String
    
    var body: some View {
        VStack(spacing: 16) {
            // Status Bar
            HStack {
                Text("10:45")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 2) {
                    Image(systemName: "cellularbars")
                    Image(systemName: "wifi")
                    Image(systemName: "battery.100")
                }
                .font(.system(size: 14))
                .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // Title
            Text("Reports & Docs")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))
                
                TextField("Search...", text: $searchText)
                    .foregroundColor(.white)
                    .font(.system(size: 16))
                
                Image(systemName: "line.3.horizontal.decrease")
                    .foregroundColor(.gray)
                    .font(.system(size: 18))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Report Card View
struct ReportCardView: View {
    let report: TireReport
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                // Icon
                Image(systemName: report.reportType.icon)
                    .font(.system(size: 24))
                    .foregroundColor(report.reportType.iconColor)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(report.vehicleName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(report.serviceName)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                    
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                }
            }
            .padding(16)
            
            // Expandable Content
            if isExpanded && !report.description.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(report.description)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 16)
                    
                    if report.frontLeftTire > 0 {
                        TireStatusView(report: report)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 16)
            }
            
            // Date
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                Text(formatDate(report.date))
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Tire Status View
struct TireStatusView: View {
    let report: TireReport
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 40) {
                TireIndicator(label: "Front Left:", percentage: report.frontLeftTire)
                TireIndicator(label: "Front Right:", percentage: report.frontRightTire)
            }
            
            HStack(spacing: 40) {
                TireIndicator(label: "Rear Left:", percentage: report.rearLeftTire)
                TireIndicator(label: "Rear Right:", percentage: report.rearRightTire)
            }
        }
    }
}

// MARK: - Tire Indicator
struct TireIndicator: View {
    let label: String
    let percentage: Int
    
    var textColor: Color {
        if percentage >= 80 {
            return .green
        } else if percentage >= 60 {
            return .yellow
        } else {
            return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .frame(width: 80, alignment: .leading)
            
            Text("\(percentage)%")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(textColor)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - Tab Bar View
struct TabBarView: View {
    @State private var selectedTab = 1
    
    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(
                icon: "car.fill",
                isSelected: selectedTab == 0,
                action: { selectedTab = 0 }
            )
            
            Spacer()
            
            // Center Scan Button
            Button(action: {
                selectedTab = 1
            }) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.red, Color.orange]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .offset(y: -10)
            
            Spacer()
            
            TabBarButton(
                icon: "folder.fill",
                isSelected: selectedTab == 2,
                action: { selectedTab = 2 }
            )
            
            Spacer()
            
            TabBarButton(
                icon: "gearshape.fill",
                isSelected: selectedTab == 3,
                action: { selectedTab = 3 }
            )
        }
        .padding(.horizontal, 30)
        .padding(.top, 10)
        .padding(.bottom, 20)
        .background(
            Color.black.opacity(0.95)
                .background(.ultraThinMaterial)
        )
    }
}

// MARK: - Tab Bar Button
struct TabBarButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(isSelected ? .white : .gray)
                .frame(width: 44, height: 44)
        }
    }
}

// MARK: - Preview
#Preview {
    ReportsDocsView()
        .preferredColorScheme(.dark)
}

