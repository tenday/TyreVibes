import SwiftUI

/// Badge che indica lo stato Premium dell'utente
struct PremiumBadge: View {
    let size: BadgeSize
    let showLabel: Bool

    init(size: BadgeSize = .medium, showLabel: Bool = true) {
        self.size = size
        self.showLabel = showLabel
    }

    var body: some View {
        HStack(spacing: size.spacing) {
            Image(systemName: "crown.fill")
                .font(.system(size: size.iconSize))
                .foregroundColor(.yellow)

            if showLabel {
                Text("Premium")
                    .font(.customFont(size: size.fontSize, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.3)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(size.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: size.cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [Color.yellow, Color.orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        )
    }

    enum BadgeSize {
        case small
        case medium
        case large

        var iconSize: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 16
            case .large: return 20
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 14
            case .large: return 16
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 8
            case .medium: return 12
            case .large: return 16
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small: return 4
            case .medium: return 6
            case .large: return 8
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .small: return 8
            case .medium: return 10
            case .large: return 12
            }
        }

        var spacing: CGFloat {
            switch self {
            case .small: return 4
            case .medium: return 6
            case .large: return 8
            }
        }
    }
}

/// Badge per indicare funzionalità bloccate per utenti free
struct LockedFeatureBadge: View {
    let size: PremiumBadge.BadgeSize
    let showLabel: Bool

    init(size: PremiumBadge.BadgeSize = .medium, showLabel: Bool = true) {
        self.size = size
        self.showLabel = showLabel
    }

    var body: some View {
        HStack(spacing: size.spacing) {
            Image(systemName: "lock.fill")
                .font(.system(size: size.iconSize))
                .foregroundColor(.yellow)

            if showLabel {
                Text("Premium")
                    .font(.customFont(size: size.fontSize, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(Color.white.opacity(0.1))
        .cornerRadius(size.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: size.cornerRadius)
                .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
        )
    }
}

/// Badge per mostrare il limite raggiunto
struct LimitReachedBadge: View {
    let current: Int
    let max: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(.orange)

            Text("\(current)/\(max)")
                .font(.customFont(size: 12, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.orange.opacity(0.2))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.5), lineWidth: 1)
        )
    }
}

#Preview("Premium Badge") {
    ZStack {
        Color.customBackgroundColor
            .ignoresSafeArea()

        VStack(spacing: 20) {
            PremiumBadge(size: .small)
            PremiumBadge(size: .medium)
            PremiumBadge(size: .large)

            PremiumBadge(size: .small, showLabel: false)
            PremiumBadge(size: .medium, showLabel: false)

            LockedFeatureBadge(size: .medium)
            LockedFeatureBadge(size: .small, showLabel: false)

            LimitReachedBadge(current: 2, max: 2)
        }
    }
}
