import SwiftUI

struct TreadAnalysisResultView: View {

    let vehicle: VehicleResponse
    let measurements: [Double] = [7.2, 4.8, 4.5, 3.2] // Placeholder
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            VStack {

                // Header
                Text("\(vehicle.vehicle.make ?? "") \(vehicle.vehicle.model ?? "")")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top)

                // Tyre Image
                Image("tyreSample")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 250)
                    .padding(.vertical)

                // Measurements
                HStack(spacing: 20) {
                    ForEach(measurements, id: \.self) { measurement in
                        VStack {
                            Text(String(format: "%.1f", measurement))
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(measurement > 5.0 ? .green : .white)
                            Text("mm")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()

                Spacer()

                // Continue Button
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Continue")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#FF6B6B"))
                        .cornerRadius(25)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            Image(systemName: "chevron.left")
                .foregroundColor(.white)
        })
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Tread Analysis")
                    .foregroundColor(.white)
            }
        }
        .preferredColorScheme(.dark)
    }
}

//#Preview {
//    TreadAnalysisResultView(vehicle: .previewSample)
//}
