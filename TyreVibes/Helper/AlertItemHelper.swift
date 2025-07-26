//
//  AlertItem.swift
//  TyreVibes
//
//  Created by Matteo La Manna on 26/07/25.
//

import Foundation

struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
