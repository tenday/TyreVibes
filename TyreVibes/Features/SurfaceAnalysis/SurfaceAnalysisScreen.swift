//
//  SurfaceAnalysisScreen.swift
//  TyreVibes
//
//  Created by Jules on 14/10/25.
//

import SwiftUI

struct SurfaceAnalysisScreen: View {
    @ObservedObject var viewModel: SurfaceAnalysisViewModel

    var body: some View {
        ZStack {
            Color(hex: "1E1E1E").ignoresSafeArea()

            VStack {
                // Header
                HStack {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                    Text("Surface Analysis")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding()

                // Vehicle Info
                Text(viewModel.analysisData.vehicleName)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "F26440"))
                    .padding(.bottom, 20)

                // Tire Image and Details
                ZStack(alignment: .bottomLeading) {
                    Image("tyre_image_placeholder") // Placeholder image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 250)
                        .clipped()
                        .cornerRadius(10)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tire Size:").foregroundColor(.gray)
                        Text(viewModel.analysisData.tireSize).foregroundColor(.white)
                        Text("Tire Make:").foregroundColor(.gray)
                        Text(viewModel.analysisData.tireMake).foregroundColor(.white)
                        Text("Manufacture Date:").foregroundColor(.gray)
                        Text(viewModel.analysisData.manufactureDate).foregroundColor(.white)
                        Text("Model:").foregroundColor(.gray)
                        Text(viewModel.analysisData.model).foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(10)
                    .padding()
                }

                // Tire Condition
                VStack {
                    Text("Tire Condition")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.top)

                    HStack {
                        Image(systemName: viewModel.analysisData.conditionIconName)
                            .foregroundColor(.yellow)
                        Text(viewModel.analysisData.conditionDescription)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(10)
                }
                .padding()

                // Export PDF
                Button(action: {
                    viewModel.exportPDF()
                }) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.red)
                        Text("Export PDF Data")
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "square.and.arrow.down")
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(10)
                }
                .padding(.horizontal)

                Spacer()

                // Measure Tread Button
                Button(action: {
                    viewModel.measureTread()
                }) {
                    Text("Measure Tread")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "2FB8FF"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
            }
        }
    }
}

struct SurfaceAnalysisScreen_Previews: PreviewProvider {
    static var previews: some View {
        SurfaceAnalysisScreen(viewModel: SurfaceAnalysisViewModel())
    }
}