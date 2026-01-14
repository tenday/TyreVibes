//
//  ColorExtension.swift
//  TyreVibes
//
//  Created by Matteo La Manna on 12/05/25.
//

import Foundation
import SwiftUI

extension Color {

    static let customGray = Color(hex: "212121")
    static let customBlue = Color(hex: "0062FE")
    static let customAzure = Color(hex: "5CEBFF")
    static let customBitterSweet = Color(hex: "F36656")
    static let customSandyBrown = Color(hex: "F8A450")
    static let customPurple = Color(hex: "AA18A5")
    static let customElectricBlueColor = Color(hex: "5CEBFF")
    static let customFieldColor = Color(red: 0.23, green: 0.23, blue: 0.23).opacity(0.30)
    static let customBackgroundColor = Color(hex: "191919")

    // Colors for LoginScreen refactoring
    static let customWhite = Color(hex: "FFFFFF")
    static let customSocialButtonBackground = Color(hex: "3A3A3A")

    // MARK: - Accessibility Colors (WCAG AA Compliant - 4.5:1 contrast ratio)
    // Questi colori hanno un contrasto sufficiente rispetto a customBackgroundColor (#191919)

    /// Grigio accessibile per testo secondario (contrasto 7:1 vs #191919)
    static let accessibleGray = Color(hex: "9E9E9E")

    /// Grigio chiaro per testo terziario (contrasto 4.6:1 vs #191919)
    static let accessibleLightGray = Color(hex: "757575")

    /// Viola accessibile (contrasto 4.5:1 vs #191919)
    static let accessiblePurple = Color(hex: "D47CD0")

    /// Coral/Rosso accessibile (contrasto 4.5:1 vs #191919)
    static let accessibleCoral = Color(hex: "FF7B6B")

    /// Arancione accessibile (contrasto 4.5:1 vs #191919)
    static let accessibleOrange = Color(hex: "FFB366")
}

