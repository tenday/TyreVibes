//
//  FontExtension.swift
//  TyreVibes
//
//  Created by Matteo La Manna on 13/05/25.
//

import Foundation
import SwiftUI

extension Font {
    static func customFont(size: CGFloat, weight: Font.Weight) -> Font {
        switch weight {
        case .bold:
            return Font.custom("Sora-Bold", size: size)
        case .light:
            return Font.custom("Sora-Light", size: size)
        case .medium:
            return Font.custom("Sora-Medium", size: size)
        case.regular:
            return Font.custom("Sora-Regular", size: size)
        case .semibold:
            return Font.custom("Sora-SemiBold", size: size)
        case .thin:
            return Font.custom("Sora-Thin", size: size)
        default:
            return Font.custom("Sora-Regular", size: size).weight(weight)
        }
    }

    static func soraExtraBold(size: CGFloat) -> Font {
        return Font.custom("Sora-ExtraBold", size: size)
    }
    
    static func soraExtraLight(size: CGFloat) -> Font {
        return Font.custom("Sora-ExtraLight", size: size)
    }
}
