import SwiftUI

struct MaintenanceTypeIconView: View {
    let type: MaintenanceSchedule.MaintenanceType
    var color: Color
    var size: CGFloat

    init(
        type: MaintenanceSchedule.MaintenanceType,
        color: Color = .primary,
        size: CGFloat = 16
    ) {
        self.type = type
        self.color = color
        self.size = size
    }

    var body: some View {
        Group {
            if let assetName = type.assetIconName {
                Image(assetName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: type.icon)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: size, height: size)
        .foregroundStyle(color)
    }
}
