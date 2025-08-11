//
//  Vehicle.swift
//  TyreVibes
//
//  Created by Matteo La Manna on 20/07/25.
//

import Foundation
import SwiftUI


struct Car : Decodable{
    let id = UUID()
    let name: String
    let plateCode: String
    let make: String
    let model: String
    let year: String
    let engine: String
    let imageName: String
    
}
