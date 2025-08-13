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
                        ReportsView()
                    case 2:
                        CalendarScreen()
                    default:
                        SettingsScreen()
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
                        // Left side
                        Button(action: {
                            withAnimation(.interpolatingSpring(stiffness: 300, damping: 1)) { selectedIndex = 0 }
                        }) {
                            TabItem(iconName: iconNames[0], isSelected: selectedIndex == 0, namespace: animationNamespace)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) { selectedIndex = 1 }
                        }) {
                            TabItem(iconName: iconNames[1], isSelected: selectedIndex == 1, namespace: animationNamespace)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        // Gap per il "bump" centrale
                        Spacer().frame(width: 84)

                        // Right side
                        Button(action: {
                            withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) { selectedIndex = 2 }
                        }) {
                            TabItem(iconName: iconNames[2], isSelected: selectedIndex == 2, namespace: animationNamespace)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) { selectedIndex = 3 }
                        }) {
                            TabItem(iconName: iconNames[3], isSelected: selectedIndex == 3, namespace: animationNamespace)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    // Pulsante centrale flottante (azione scan)
                    CenterActionButton(action: {
                        // TODO: collega all'azione di scan targa o alla view desiderata
                    })
                    .offset(y: -50)
                }
                .frame(width: width, height: barH)
                .padding(.bottom, -safeBottom)
            }
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
            if isSelected {
                // Cerchio con gradiente che appare dietro l'icona selezionata
                Circle()
                    .fill(LinearGradient(
                        stops: [
                        Gradient.Stop(color: Color(red: 0.97, green: 0.56, blue: 0.09), location: 0.00),
                        Gradient.Stop(color: Color(red: 1, green: 0.3, blue: 0.51), location: 1.00),
                        ],
                        startPoint: UnitPoint(x: 0.85, y: 0.22),
                        endPoint: UnitPoint(x: 0.09, y: 0.41)
                    ))
                    .frame(width: 48, height: 48)
                    .matchedGeometryEffect(id: "selected_tab", in: namespace)
            }

            Image(iconName)
                .font(.system(size: 22))
                .foregroundColor(isSelected ? .white : .gray)
                .frame(width: 24, height: 24, alignment: .center)
        }
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
struct CalendarScreen: View { var body: some View { Text("Calendar").foregroundColor(.white) } }
struct SettingsScreen: View { var body: some View { Text("Settings").foregroundColor(.white) } }


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
