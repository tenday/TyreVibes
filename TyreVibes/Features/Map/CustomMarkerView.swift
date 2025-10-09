import SwiftUI

struct CustomMarkerView: View {
    @State private var isAnimating = false

    var body: some View {
        Image("garageMenu")
            .resizable()
            .scaledToFit()
            .frame(width: 40, height: 40)
            .scaleEffect(isAnimating ? 1.2 : 1.0)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}

struct CustomMarkerView_Previews: PreviewProvider {
    static var previews: some View {
        CustomMarkerView()
            .previewLayout(.sizeThatFits)
            .padding()
    }
}