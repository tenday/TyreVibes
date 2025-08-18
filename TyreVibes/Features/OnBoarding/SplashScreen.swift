import SwiftUI

struct SplashScreen: View {
    @State private var isActive = false
    @State private var size = 0.8
    @State private var opacity = 0.5
    @State private var rotation = 0.0
    @State private var offsetY: CGFloat = 200
    
    var body: some View {
        if isActive {
            OnboardingView()
        } else {
            VStack {
                ZStack(alignment: .center) {
                   
                    Image("Archi")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300, height: 300)
                        .rotationEffect(.degrees(rotation))
                        .onAppear() {
                            withAnimation(.linear(duration: 1.5)) {
                                self.rotation = 360
                                self.opacity = 1.0
                                self.size = 0.8
                                self.offsetY = 0.0
                            }
                        }
                    
                    Image("T")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                        .padding()
                        .offset(x: 2, y : 23)
                }
                .scaleEffect(size)
                .opacity(opacity)
                .offset(y: offsetY)
            
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                Color.customBackgroundColor
            )
            .onAppear {
               
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        self.isActive = true
                    }
                }
            }
        }
    }
}

// Anteprima per SwiftUI
struct SplashScreen_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreen()
    }
}
