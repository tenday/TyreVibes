import SwiftUI

// MARK: - Vista Principale della Barra di Navigazione
struct BottomNavigationView: View {
    @State private var selectedIndex: Int = 0
    // Aggiunto un namespace per l'animazione
    @Namespace private var animationNamespace

    // Nomi delle icone come da screenshot (uso SF Symbols come placeholder)
    let iconNames = ["car.fill", "doc.text.fill", "calendar", "gearshape.fill"]
    
    var body: some View {
        VStack {
            Spacer() // Spinge la barra in basso
            
            ZStack {
                // 1. Usiamo la nostra nuova forma personalizzata come sfondo
                //CustomTabBarShape()
                Image("BottomMenu")
                    //.fill(Color(white: 0.15)) // Colore grigio scuro come da screenshot
                    //.frame(height: 80)
                    //.shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: -5)

                // 2. HStack per contenere le icone
                HStack(spacing: 0) {
                    ForEach(0..<iconNames.count, id: \.self) { index in
                        TabItem(
                            iconName: iconNames[index],
                            isSelected: selectedIndex == index,
                            namespace: animationNamespace
                        )
                        .frame(maxWidth: .infinity)
                        .onTapGesture {
                            withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) {
                                selectedIndex = index
                            }
                        }
                    }
                }
                //.frame(height: 80)
                //.padding(.horizontal)
            }
            .edgesIgnoringSafeArea(.bottom)
        }
        .background(Color.black.opacity(0.2).edgesIgnoringSafeArea(.all)) // Sfondo per la preview
    }
}

// MARK: - Elemento Singolo della Tab (Icona)
struct TabItem: View {
    let iconName: String
    let isSelected: Bool
    let namespace: Namespace.ID

    var body: some View {
        ZStack {
            if isSelected {
                // Cerchio con gradiente che appare dietro l'icona selezionata
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.orange, Color.pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 50, height: 50)
                    // Questa è la magia: permette al cerchio di "spostarsi" fluidamente
                    .matchedGeometryEffect(id: "selected_tab", in: namespace)
            }
            
            Image(systemName: iconName)
                .font(.system(size: 22))
                .foregroundColor(isSelected ? .white : .gray)
        }
    }
}


// MARK: - Forma Personalizzata della Barra
struct CustomTabBarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        // Inizia dall'angolo in alto a sinistra
        path.move(to: CGPoint(x: 0, y: 0))
        
        // Curva per la prima icona
        path.addQuadCurve(to: CGPoint(x: width * 0.20, y: 0), control: CGPoint(x: width * 0.10, y: -10))
        
        // Curva per la seconda icona
        path.addQuadCurve(to: CGPoint(x: width * 0.40, y: 0), control: CGPoint(x: width * 0.30, y: 10))

        // Incavo centrale (più profondo)
        path.addQuadCurve(to: CGPoint(x: width * 0.60, y: 0), control: CGPoint(x: width * 0.50, y: 35))
        
        // Curva per la terza icona
        path.addQuadCurve(to: CGPoint(x: width * 0.80, y: 0), control: CGPoint(x: width * 0.70, y: 10))
        
        // Curva per la quarta icona
        path.addQuadCurve(to: CGPoint(x: width, y: 0), control: CGPoint(x: width * 0.90, y: -10))
        
        // Linee per chiudere la forma in basso
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        
        return path
    }
}


// MARK: - Preview
struct BottomNavigationView_Previews: PreviewProvider {
    static var previews: some View {
        BottomNavigationView()
    }
}
