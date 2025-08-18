//
//  Users.swift
//  TyreVibes
//
//  Created by Matteo La Manna on 26/07/25.
//

import Foundation

// Modello per la tabella 'profiles'
struct Users: Codable {
    var id: UUID
    var fullName: String
    var username: String
    var phoneNumber: String?
    var countryDialCode: String?
    var agreedToTerms: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case username
        case phoneNumber = "phone_number"
        case countryDialCode = "country_dial_code"
        case agreedToTerms = "agreed_to_terms"
    }
}
