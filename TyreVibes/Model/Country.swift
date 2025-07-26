//
//  Country.swift
//  TyreVibes
//
//  Created by Matteo La Manna on 26/07/25.
//

import Foundation

struct Country: Codable, Identifiable, Hashable {
    var id: Int?
    var name: String
    var iso2Code: String
    var dialCode: String
    var flagEmoji: String?
    
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case iso2Code = "iso2_code"
        case dialCode = "dial_code"
        case flagEmoji = "flag_emoji"
    }
}
