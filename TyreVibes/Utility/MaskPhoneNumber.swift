//
//  MaskPhoneNumber.swift
//  TyreVibes
//
//  Created by Matteo La Manna on 31/07/25.
//

import Foundation
class Utilities {
    public static func maskPhoneNumber(_ number: String) -> String {
        // Mostra i primi 3 e ultimi 3 caratteri, maschera il resto con •
        let visiblePrefix = number.prefix(3)
        let visibleSuffix = number.suffix(3)
        let maskedCount = max(0, number.count - 6)
        let maskedPart = String(repeating: "•", count: maskedCount)
        return "\(visiblePrefix)\(maskedPart)\(visibleSuffix)"
    }
}

