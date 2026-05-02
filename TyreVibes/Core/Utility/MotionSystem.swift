import SwiftUI
import UIKit

enum AppMotion {
    static let quick = Animation.easeOut(duration: 0.18)
    static let smooth = Animation.spring(response: 0.32, dampingFraction: 0.82)
    static let emphasized = Animation.spring(response: 0.48, dampingFraction: 0.72)
    static let subtlePulse = Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)

    static func staggered(_ index: Int, baseDelay: Double = 0.04) -> Animation {
        smooth.delay(Double(index) * baseDelay)
    }
}

enum AppHaptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        #if targetEnvironment(simulator)
        return
        #else
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        #endif
    }

    static func success() {
        #if targetEnvironment(simulator)
        return
        #else
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    static func warning() {
        #if targetEnvironment(simulator)
        return
        #else
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }
}

struct PressScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var scale: CGFloat = 0.96
    var opacity: Double = 0.92

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed ? opacity : 1)
            .animation(reduceMotion ? nil : AppMotion.quick, value: configuration.isPressed)
    }
}

struct ShakeEffect: GeometryEffect {
    var travelDistance: CGFloat = 8
    var shakesPerUnit = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: travelDistance * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
            y: 0
        ))
    }
}

extension View {
    func pressScaleButtonStyle(scale: CGFloat = 0.96, opacity: Double = 0.92) -> some View {
        buttonStyle(PressScaleButtonStyle(scale: scale, opacity: opacity))
    }

    func shake(trigger: Int, distance: CGFloat = 8) -> some View {
        modifier(ShakeEffect(travelDistance: distance, animatableData: CGFloat(trigger)))
    }
}
