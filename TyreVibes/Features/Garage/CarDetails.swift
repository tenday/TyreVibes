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
    @State private var showTyreRegistration: Bool = false
    @State private var showInfoDialog: Bool = false
    @State private var infoDialogOffset: CGFloat = 0
    
    
    
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
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                        showInfoDialog = true
                                    }
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
                                ForEach(0..<1, id: \.self) { _ in
                                    Button(action: {
                                        showTyreRegistration = true
                                    }) {
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
                        .fullScreenCover(isPresented: $showTyreRegistration) {
                            TyreRegistrationView()
                        }

                    }
                }
                .padding(.horizontal,24)
                
            }
            .sheet(isPresented: $showInfoDialog) {
                VStack(spacing: 12) {
                    Capsule()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 40, height: 5)
                        .padding(.top, 8)

                    Text("Storico Revisioni")
                        .font(.customFont(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    VStack(spacing: 0) {
                        HStack {
                            Text("Data")
                                .font(.customFont(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("Esito")
                                .font(.customFont(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("Km")
                                .font(.customFont(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 6)

                        Divider().background(Color.customGray)

                        ScrollView {
                            VStack(spacing: 0) {
                                if let revisions = vehicle.revisions, !revisions.isEmpty {
                                    ForEach(revisions) { revisione in
                                        HStack {
                                            Text(revisione.dataRevisione ?? "" )
                                                .font(.customFont(size: 12, weight: .regular))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            Text(revisione.esitoRevisione ?? "")
                                                .font(.customFont(size: 12, weight: .regular))
                                                .foregroundColor(.green)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            Text(revisione.kmRevisione ?? "")
                                                .font(.customFont(size: 12, weight: .regular))
                                                .foregroundColor(.white.opacity(0.8))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .padding(.vertical, 6)
                                        Divider().background(Color.customGray)
                                    }
                                } else {
                                    Text("Nessuna revisione disponibile")
                                        .font(.customFont(size: 12, weight: .regular))
                                        .foregroundColor(.white.opacity(0.7))
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 12)
                                }
                                
                            }
                        }
                        .frame(maxHeight: 280)
                    }

                    Divider().background(Color.customGray)

                    Text("Pneumatici Supportati")
                        .font(.customFont(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.top, 8)

                    ScrollView {
                        VStack(spacing: 6) {
                            if let tyres = vehicle.tyres, !tyres.isEmpty {
                                ForEach(tyres) { tyre in
                                    HStack {
                                        Text("\(tyre.width ?? 0)")
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text("\(tyre.ratio ?? 0)")
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text("R\(tyre.diameter ?? 0)")
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text(tyre.loadIndex ?? "-")
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text(tyre.speedIndex ?? "-")
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .font(.customFont(size: 12, weight: .regular))
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Color.customGray.opacity(0.3))
                                    .cornerRadius(6)
                                }
                            } else {
                                Text("Nessun pneumatico disponibile")
                                    .font(.customFont(size: 12, weight: .regular))
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    .frame(maxHeight: 120)

                    Button(action: { showInfoDialog = false }) {
                        Text("Chiudi")
                            .font(.customFont(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.customGray)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .background(Color.customFieldColor.ignoresSafeArea())
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
