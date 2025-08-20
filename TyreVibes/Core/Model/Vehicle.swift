//
//  Vehicle.swift
//  TyreVibes
//
//  Created by Matteo La Manna on 20/07/25.
//

import Foundation
import SwiftUI


struct Car: Identifiable, Codable {
    let id: UUID
    let name: String
    let plateCode: String
    let make: String
    let model: String
    let year: String
    let engine: String
    let imageName: String
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case plateCode = "plate_code"
        case make
        case model
        case year
        case engine
        case imageName = "image_name"
        case userId = "user_id"
    }
}
