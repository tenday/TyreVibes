import SwiftUI
import UIKit

// MARK: - Vista Principale della Barra di Navigazione
struct BottomNavigationView: View {
    @State private var selectedIndex: Int = 0
    
    // Aggiunto un namespace per l'animazione
    @Namespace private var animationNamespace

    // Nomi delle icone come da screenshot (uso SF Symbols come placeholder)
    let iconNames = ["vehicleIcon", "reportIcon", "storeIcon", "settingIcon"]
    
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let safeBottom = proxy.safeAreaInsets.bottom
            let barH = bottomBarHeight(for: width)
            // Il contenuto rispetta già la safe area in basso; per evitare la sovrapposizione
            // aggiungiamo solo l'eccedenza della barra sopra la home indicator.

            ZStack {
                // AREA CONTENUTO
                Group {
                    switch selectedIndex {
                    case 0:
                        GarageScreen()
                    case 1:
                        ReportsDocumentationsView()
                    case 2:
                        MapView()
                    case 3:
                        SettingsView()
                    case 4:
                        TireAnalysisSelectionView()
                    default:
                        GarageScreen()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.customBackgroundColor.ignoresSafeArea())
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            // Barra ancorata in basso; l'altezza è calcolata dall'aspect ratio dell'asset
            .overlay(alignment: .bottom) {
                ZStack {
                  Image("BottomMenu")
                      .resizable()
                      .scaledToFit()
                      .frame(width: width, height: barH)
                      .clipped()
                      // Inner shadow che segue il contorno irregolare dell'immagine
                      .overlay(
                          Image("BottomMenu")
                              .resizable()
                              .scaledToFit()
                              .frame(width: width, height: barH)
                              //.compositingGroup()
                              // Ombra (esterna) che verrà poi "ritagliata" all'interno dalla maschera
                              .shadow(color: Color.white, radius: 50, x: 0, y: -10)
                              .shadow(color: Color.white, radius: 50, x: 0, y: -10)
                              .mask(
                                  Image("BottomMenu")
                                      .resizable()
                                      .scaledToFit()
                                      .frame(width: width, height: barH * 0.05)
                                      .luminanceToAlpha()
                              )
                              
                      )
                    
                    
                    HStack(spacing: 0) {
                        // Left side - Garage
                        Button(action: {
                            withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) { selectedIndex = 0 }
                        }) {
                            TabItem(iconName: iconNames[0], isSelected: selectedIndex == 0, namespace: animationNamespace)
                                .frame(width: width * 0.2, height: 60)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        // Reports
                        Button(action: {
                            withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) { selectedIndex = 1 }
                        }) {
                            TabItem(iconName: iconNames[1], isSelected: selectedIndex == 1, namespace: animationNamespace)
                                .frame(width: width * 0.2, height: 60)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        // Central spacer for floating button
                        Spacer()
                            .frame(width: width * 0.2)

                        // Right side - Store
                        Button(action: {
                            withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) { selectedIndex = 2 }
                        }) {
                            TabItem(iconName: iconNames[2], isSelected: selectedIndex == 2, namespace: animationNamespace)
                                .frame(width: width * 0.2, height: 60)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        // Settings
                        Button(action: {
                            withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) { selectedIndex = 3 }
                        }) {
                            TabItem(iconName: iconNames[3], isSelected: selectedIndex == 3, namespace: animationNamespace)
                                .frame(width: width * 0.2, height: 60)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, width * 0.05)

                    // Central floating button - positioned precisely
                    Button(action: {
                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) { selectedIndex = 4 }
                    }) {
                        TabItem(iconName: "Archi", isSelected: selectedIndex == 4, namespace: animationNamespace)
                            .frame(width: 80, height: 80)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .offset(y: -50)
                }
                .frame(width: width, height: barH)
                .padding(.bottom, -safeBottom)
            }
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

// MARK: - Elemento Singolo della Tab (Icona)
struct TabItem: View {
    let iconName: String
    let isSelected: Bool
    let namespace: Namespace.ID

    var body: some View {
        ZStack {
            if iconName == "Archi" {
                // Central floating button with liquid glass effect
                ZStack {
                    // Base glass circle
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: isSelected ?
                                            [.white.opacity(0.3), .white.opacity(0.1)] :
                                            [.white.opacity(0.3), .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )
                        .shadow(
                            color: isSelected ? .black.opacity(0.3) : .black.opacity(0.3),
                            radius: isSelected ? 15 : 10,
                            x: 0,
                            y: isSelected ? 8 : 5
                        )
                        .frame(width: isSelected ? 75 : 70, height: isSelected ? 75 : 70)

                    // Inner glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: isSelected ?
                                    [.white.opacity(0.1), .clear] :
                                    [.white.opacity(0.1), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: isSelected ? 40 : 35
                            )
                        )
                        .frame(width: isSelected ? 75 : 70, height: isSelected ? 75 : 70)
                        .opacity(0.8)

                    // Icon overlay
                    Image("Archi")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                }
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            } else {
                // Regular tab items with liquid glass effect
                ZStack {
                    if isSelected {
                        ZStack {
                            // Base glass circle
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2
                                        )
                                )
                                .shadow(
                                    color: .black.opacity(0.3),
                                    radius: 10,
                                    x: 0,
                                    y: 5
                                )
                                .frame(width: 44, height: 44)

                            // Inner glow
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [.white.opacity(0.1), .clear],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 25
                                    )
                                )
                                .frame(width: 44, height: 44)
                                .opacity(0.8)
                        }
                        .matchedGeometryEffect(id: "selected_tab", in: namespace)
                    }

                    Image(iconName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundColor(isSelected ? .white : .gray)
                }
            }
        }
        .background(InteractivePopGestureEnabler())
    }
}
// MARK: - Central Floating Button
struct CenterActionButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.init(hex: "1F1F1F"))
                    .frame(width: 70, height: 70)
                    .overlay(
                        Image("Archi")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Central action")
    }
}

// MARK: - Placeholder Screens
struct VehiclesView: View { var body: some View { Text("Vehicles").foregroundColor(.white) } }
struct ReportsView: View { var body: some View { Text("Reports").foregroundColor(.white) } }


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


// Calcola l'altezza della barra in base al rapporto dell'immagine di background
private func bottomBarHeight(for width: CGFloat) -> CGFloat {
    if let img = UIImage(named: "BottomMenu") {
        let ratio = img.size.height / img.size.width
        return width * ratio
    }
    return 110
}

// MARK: - Preview
struct BottomNavigationView_Previews: PreviewProvider {
    static var previews: some View {
        BottomNavigationView()
    }
}
