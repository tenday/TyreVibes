import Foundation

struct CustomNotificationSetting: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var body: String
    var hour: Int
    var minute: Int
    var repeatsDaily: Bool
    var isEnabled: Bool
    var createdAt: Date

    var timeComponents: DateComponents {
        DateComponents(hour: hour, minute: minute)
    }

    var timeDate: Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    var timeString: String {
        Self.timeFormatter.string(from: timeDate)
    }

    func nextTriggerDate(from referenceDate: Date = Date()) -> Date {
        let calendar = Calendar.current
        var nextDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: referenceDate) ?? referenceDate
        if nextDate <= referenceDate {
            nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
        }
        return nextDate
    }

    static func makeDraft() -> CustomNotificationSetting {
        let components = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return CustomNotificationSetting(
            id: UUID().uuidString,
            title: "",
            body: "",
            hour: components.hour ?? 9,
            minute: components.minute ?? 0,
            repeatsDaily: true,
            isEnabled: true,
            createdAt: Date()
        )
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}
