import SwiftUI

extension String {
    func toUIImage() -> UIImage? {
        guard let data = Data(base64Encoded: self),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }
}

struct CarDetailsView: View {
    let vehicle: VehicleResponse
    @Environment(\.dismiss) private var dismiss
    
    
    
    var body: some View {
        
            ZStack {
                Color.customBackgroundColor.ignoresSafeArea()

                VStack {
                    HStack {
                        Button(action: {
                           dismiss()
                        }) {
                            Image("ArrowIcon")
                        }
                        Spacer()
                        
                        
                        VStack {
                            Text("\(vehicle.vehicle.make ?? "") \(vehicle.vehicle.model ?? "")")
                                .font(.customFont(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                    }


                    
                                
                    VStack(alignment: .leading, spacing: 20) {
                            
                        // Car Image
                        if let base64String = vehicle.image?.imageBase64,
                           let uiImage = base64String.toUIImage() {
                            let trimmed = uiImage.trimmedTransparentPixels(threshold: 5)

                            Image(uiImage: trimmed)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .padding(.top, 50)
                                .padding(.horizontal, 30)
                        } else {
                            Image("placeholder") // fallback se Base64 non valida
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                        }
                            //.padding(.horizontal)

                        // Details Section
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Details")
                                    .font(.customFont(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                                
                                Button(action: {
                                    // Azione da eseguire
                                }) {
                                    Image(systemName: "info.circle")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(.white)
                                        .padding(.leading, 4)
                                }
 
                            }
                            

                            // Details Grid
                            LazyVGrid(columns: [
                                GridItem(.flexible(), alignment: .leading),
                                GridItem(.flexible(), alignment: .leading),
                                GridItem(.flexible(), alignment: .leading)
                            ], spacing: 10) {
                                DetailItem(label: "Make", value: vehicle.vehicle.make?.uppercased() ?? "-")
                                DetailItem(label: "Year", value: vehicle.plate?.year.map { "\($0)" } ?? "-")
                                DetailItem(label: "Color", value: vehicle.vehicle.color?.uppercased() ?? "-")
                                DetailItem(label: "Model", value: vehicle.vehicle.model?.uppercased() ?? "-")
                                DetailItem(label: "Engine", value: vehicle.vehicle.engine?.uppercased() ?? "-")
                                DetailItem(label: "License No", value: vehicle.plate?.plateNumber.uppercased() ?? "-")
                                DetailItem(label: "Fuel Type", value: vehicle.vehicle.fuelType?.uppercased() ?? "-")
                                DetailItem(label: "Horsepower", value: vehicle.vehicle.powerCV.map { "\($0) CV" } ?? "-")
                            }
                        }
                        .padding()
                        .background(Color.customFieldColor)
                        .cornerRadius(14)

                        Text("Add Your Tyres")
                            .font(.customFont(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                ForEach(0..<5, id: \.self) { _ in
                                    Button(action: {}) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.customFieldColor)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color.customGray, lineWidth: 1)
                                                        .frame(width: 188, height: 231)
                                                )
                                                .frame(width: 174, height: 215)
                                            
                                            Image("plusIcon")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 37, height: 37)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 9)
                            .padding(.horizontal, 8)
                        }
                    }
                }
                .padding(.horizontal,24)
                
            }
        
        
        
    }
    
    
    
    
}

struct DetailItem: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Rectangle()
                .inset(by: 0.5)
                .stroke(Color(red: 0.95, green: 0.4, blue: 0.34), lineWidth: 1)
                .frame(width: 1, height: 40)
                //.padding(.trailing, 4)
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.customFont(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                Text(value)
                    .font(.customFont(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}
