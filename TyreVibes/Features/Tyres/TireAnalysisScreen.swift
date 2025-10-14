import SwiftUI

struct TireAnalysisScreen: View {
    @StateObject private var viewModel: TireAnalysisScreenViewModel

    // The vehicle object will be passed in when this view is integrated.
    init(vehicle: Vehicle) {
        _viewModel = StateObject(wrappedValue: TireAnalysisScreenViewModel(vehicle: vehicle))
    }

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            VStack {
                if viewModel.isLoading {
                    ProgressView()
                } else if let image = viewModel.carImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(32)
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.white)
                }
            }
            .onAppear {
                viewModel.fetchImage()
            }

            // Tire placeholders
            TirePlaceholdersOverlay()
        }
        .navigationBarTitle("Tire Analysis", displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                // The presentationMode environment variable would be used here
                // to dismiss the view, but that will be handled during integration.
                Button(action: {
                    // presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .foregroundColor(.white)
                }
            }
        }
    }
}

struct TirePlaceholdersOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            let carWidth = geometry.size.width * 0.6
            let carHeight = carWidth * 1.8
            let tireWidth = carWidth * 0.15
            let tireHeight = tireWidth * 2.5

            let topOffset = (geometry.size.height - carHeight) / 2
            let sideOffset = (geometry.size.width - carWidth) / 2

            // Front-left tire
            TirePlaceholderView()
                .frame(width: tireWidth, height: tireHeight)
                .position(x: sideOffset, y: topOffset + tireHeight * 0.7)

            // Front-right tire
            TirePlaceholderView()
                .frame(width: tireWidth, height: tireHeight)
                .position(x: geometry.size.width - sideOffset, y: topOffset + tireHeight * 0.7)

            // Rear-left tire
            TirePlaceholderView()
                .frame(width: tireWidth, height: tireHeight)
                .position(x: sideOffset, y: topOffset + carHeight - tireHeight * 0.7)

            // Rear-right tire
            TirePlaceholderView()
                .frame(width: tireWidth, height: tireHeight)
                .position(x: geometry.size.width - sideOffset, y: topOffset + carHeight - tireHeight * 0.7)
        }
    }
}

struct TirePlaceholderView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(Color.white, lineWidth: 2)
    }
}

struct TireAnalysisScreen_Previews: PreviewProvider {
    static var previews: some View {
        // A mock vehicle is used for the preview.
        let mockVehicle = Vehicle(id: 1, modelDetail: "Test", engine: "Test", make: "Test", model: "Test", version: "Test", fuelType: "Test", displacementCC: 1, powerCV: 1, powerKW: "1", emissionClass: "1", gearbox: "1", maxSpeed: "1", bodyType: "1", doors: "1", seats: "1", consumption: "1", traction: "1", saleStart: "1", saleEnd: "1", color: "1", vin: "1", createdAt: "1")

        NavigationView {
            TireAnalysisScreen(vehicle: mockVehicle)
        }
        .preferredColorScheme(.dark)
    }
}