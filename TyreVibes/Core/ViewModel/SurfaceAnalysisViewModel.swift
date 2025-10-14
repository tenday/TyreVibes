//
//  SurfaceAnalysisViewModel.swift
//  TyreVibes
//
//  Created by Jules on 14/10/25.
//

import Foundation
import Combine

struct SurfaceAnalysisData {
    let vehicleName: String
    let tireSize: String
    let tireMake: String
    let manufactureDate: String
    let model: String
    let conditionDescription: String
    let conditionIconName: String
}

class SurfaceAnalysisViewModel: ObservableObject {
    @Published var analysisData: SurfaceAnalysisData

    init() {
        // Initialize with placeholder data
        self.analysisData = SurfaceAnalysisData(
            vehicleName: "Audi Q3",
            tireSize: "255/50 R19",
            tireMake: "Continental",
            manufactureDate: "2025/5",
            model: "Winter Contact TS870P",
            conditionDescription: "Slightly uneven wear detected on outer edge",
            conditionIconName: "exclamationmark.triangle.fill"
        )
    }

    func exportPDF() {
        // TODO: Implement PDF export logic
        print("Exporting PDF...")
    }

    func measureTread() {
        // TODO: Implement measure tread logic
        print("Measuring tread...")
    }
}