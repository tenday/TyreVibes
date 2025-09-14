import SwiftUI


struct CarCardShimmer: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            Image("CardModel")
                .resizable()
                .scaledToFill()
                .frame( height: h)
                .clipped()
                .shimmer()
            
            ZStack {
             
                    
                
                VStack(alignment: .leading, spacing: h * 0.05) {
                    // Titolo + Targa
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: w * 0.3, height: 16)
                            .shimmer()
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: w * 0.2, height: 14)
                            .shimmer()
                        
                        Spacer()
                    }
                    .padding(.horizontal, w * 0.04)
                    .padding(.top, w * 0.02)
                    
                    HStack(alignment: .center, spacing: w * 0.04) {
                        // Placeholder immagine
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: w * 0.5, height: h * 0.7)
                            .shimmer()
                        
                        // Placeholder specs
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(0..<4) { _ in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.4))
                                    .frame(height: 12)
                                    .shimmer()
                            }
                        }
                        .padding(.trailing, w * 0.04)
                    }
                }
            }
            .padding(.horizontal, 24)

        }
        .aspectRatio(2.05, contentMode: .fit)
    }
    
}


import SwiftUI

struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -0.5

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.3),
                        Color.white.opacity(0.9),
                        Color.white.opacity(0.3)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: phase * 300) // lunghezza animazione
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 0.5
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        self.modifier(Shimmer())
    }
}
