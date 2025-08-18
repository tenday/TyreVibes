import SwiftUI

struct CarDetailsView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    
    var body: some View {
        NavigationStack {
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
                    }


                    VStack {
                        Text("Audi Q3")
                            .font(.customFont(size: 24, weight: .semibold))
                    }
                    
                    VStack(alignment: .leading, spacing: 20) {
                        // Car Image
                        Image("audiQ3")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            //.padding(.horizontal)

                        // Details Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Audi Q3 Details")
                                .font(.customFont(size: 16, weight: .semibold))
                                .foregroundColor(.white)

                            // Details Grid
                            LazyVGrid(columns: [
                                GridItem(.flexible(), alignment: .leading),
                                GridItem(.flexible(), alignment: .leading),
                                GridItem(.flexible(), alignment: .leading)
                            ], spacing: 10) {
                                DetailItem(label: "Make", value: "Audi")
                                DetailItem(label: "Year", value: "2024")
                                DetailItem(label: "Color", value: "Orange")
                                DetailItem(label: "Model", value: "Q3")
                                DetailItem(label: "Engine", value: "40 TFSI")
                                DetailItem(label: "License No", value: "FNB41WA")
                                DetailItem(label: "Fuel Type", value: "Gasoline")
                                DetailItem(label: "Horsepower", value: "154 CV")
                            }
                        }
                        .padding()
                        .background(Color.customFieldColor)
                        .cornerRadius(14)

                        Text("Add Your Tyres")
                            .font(.customFont(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            //.padding(.horizontal)

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
                .preferredColorScheme(.dark)
                .padding(.horizontal,24)
                
            }
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

#Preview {
    CarDetailsView()
}
