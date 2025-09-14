import SwiftUI

// MARK: - Data Models
struct TireReport {
    let id = UUID()
    let title: String
    let vehicleName: String?
    let serviceName: String?
    let description: String
    let frontLeft: Int
    let frontRight: Int
    let rearLeft: Int
    let rearRight: Int
    let date: Date
    let icon: String
    let reportType: ReportType
}

enum ReportType {
    case tireHealth
    case quickScan
    case wheelAlignment
}

// MARK: - Main Content View
struct Report: View {
    @State private var searchText = ""
    
    let reports: [TireReport] = [
        TireReport(
            title: "Complete Tire Health",
            vehicleName: "Vehicle Name",
            serviceName: nil,
            description: "All tires in fair condition. Rear right tire shows signs of uneven wear.",
            frontLeft: 82,
            frontRight: 78,
            rearLeft: 85,
            rearRight: 64,
            date: Calendar.current.date(from: DateComponents(year: 2025, month: 5, day: 9))!,
            icon: "car",
            reportType: .tireHealth
        ),
        TireReport(
            title: "Quick Scan",
            vehicleName: "Toyota Camry",
            serviceName: "TireCity Auto Service",
            description: "All tires in good condition. Recommend rotations in the next 1,000 miles.",
            frontLeft: 88,
            frontRight: 85,
            rearLeft: 90,
            rearRight: 72,
            date: Calendar.current.date(from: DateComponents(year: 2025, month: 5, day: 5))!,
            icon: "speedometer",
            reportType: .quickScan
        ),
        TireReport(
            title: "Wheel Alignment Report",
            vehicleName: "Toyota Camry",
            serviceName: "TireCity Auto Service",
            description: "",
            frontLeft: 0,
            frontRight: 0,
            rearLeft: 0,
            rearRight: 0,
            date: Calendar.current.date(from: DateComponents(year: 2025, month: 5, day: 2))!,
            icon: "wrench.and.screwdriver",
            reportType: .wheelAlignment
        )
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.customBackgroundColor.ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(reports, id: \.id) { report in
                            ReportCardView(report: report)
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Reports & Docs")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Report Card View
struct ReportCardView: View {
    let report: TireReport
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let vehicleName = report.vehicleName {
                        Text(vehicleName)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    Text(report.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    if let serviceName = report.serviceName {
                        Text(serviceName)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {}) {
                        Image(systemName: "paperplane")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "arrow.down")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Description
            if !report.description.isEmpty {
                HStack {
                    Text(report.description)
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            
            // Tire Percentages (only for tire reports)
            if report.reportType != .wheelAlignment {
                TirePercentageGrid(report: report)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
            }
            
            // Date
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.gray)
                    .font(.caption)
                
                Text(formatDate(report.date))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
            
            // Service Info Card (for Toyota Camry reports)
            if report.vehicleName == "Toyota Camry" && report.serviceName != nil {
                ServiceInfoCard(
                    vehicleName: report.vehicleName!,
                    serviceName: report.serviceName!,
                    date: report.date,
                    icon: report.icon
                )
            }
        }
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Tire Percentage Grid
struct TirePercentageGrid: View {
    let report: TireReport
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                TirePercentageItem(label: "Front Left:", percentage: report.frontLeft)
                Spacer()
                TirePercentageItem(label: "Front Right:", percentage: report.frontRight)
            }
            
            HStack {
                TirePercentageItem(label: "Rear Left:", percentage: report.rearLeft)
                Spacer()
                TirePercentageItem(label: "Rear Right:", percentage: report.rearRight)
            }
        }
    }
}

// MARK: - Tire Percentage Item
struct TirePercentageItem: View {
    let label: String
    let percentage: Int
    
    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.body)
                .foregroundColor(.gray)
            
            Text("\(percentage)%")
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Service Info Card
struct ServiceInfoCard: View {
    let vehicleName: String
    let serviceName: String
    let date: Date
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: getSystemIcon())
                    .foregroundColor(.red)
                    .font(.title3)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(vehicleName)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(serviceName)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 12) {
                Button(action: {}) {
                    Image(systemName: "paperplane")
                        .foregroundColor(.white)
                        .font(.title2)
                }
                
                Button(action: {}) {
                    Image(systemName: "arrow.down")
                        .foregroundColor(.white)
                        .font(.title2)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6).opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    private func getSystemIcon() -> String {
        switch icon {
        case "wrench.and.screwdriver":
            return "wrench.and.screwdriver"
        case "speedometer":
            return "speedometer"
        default:
            return "doc.text"
        }
    }
}

// MARK: - Tab Bar Item
private struct TabBarItem_1: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isSelected ? .red : .gray)
        }
    }
}

// MARK: - Root App View
struct TireMonitoringApp: View {
    var body: some View {
        VStack(spacing: 0) {
            Report()
        }
        .background(Color.customBackgroundColor.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        TireMonitoringApp()
            .preferredColorScheme(.dark)
    }
}
