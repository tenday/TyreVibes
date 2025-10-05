//
//  TireAnalysisView.swift
//  TyreVibes
//
//  Created by Matteo La Manna on 04/10/25.
//


import SwiftUI

// MARK: - Main Tire Analysis View
struct TireAnalysisView: View {
    @State private var selectedTire: TirePosition? = .frontLeft
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.customBackgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // Back Button
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                    }
                    .padding(.leading, 24)
                    
                    Spacer()
                }
                .padding(.top, 16)
                
                Spacer()
                
                // Car with Tire Indicators
                CarTireVisualization(selectedTire: $selectedTire)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Car Tire Visualization
struct CarTireVisualization: View {
    @Binding var selectedTire: TirePosition?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Car Image (rotated 90 degrees)
                Image("car_top_view")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 460, height: 216)
                    .rotationEffect(.degrees(90))
                    .position(
                        x: geometry.size.width / 2,
                        y: geometry.size.height / 2
                    )
                
                // Front Left Tire Indicator
                TireIndicators(
                    position: .frontLeft,
                    isSelected: selectedTire == .frontLeft
                )
                .position(x: 91, y: geometry.size.height / 2 - 153)
                .onTapGesture {
                    selectedTire = .frontLeft
                }
                
                // Front Right Tire Indicator
                TireIndicators(
                    position: .frontRight,
                    isSelected: selectedTire == .frontRight
                )
                .position(x: geometry.size.width - 61, y: geometry.size.height / 2 - 153)
                .onTapGesture {
                    selectedTire = .frontRight
                }
                
                // Rear Right Tire Indicator
                TireIndicators(
                    position: .rearRight,
                    isSelected: selectedTire == .rearRight
                )
                .position(x: geometry.size.width - 61, y: geometry.size.height / 2 + 117)
                .onTapGesture {
                    selectedTire = .rearRight
                }
                
                // Rear Left Tire Indicator
                TireIndicators(
                    position: .rearLeft,
                    isSelected: selectedTire == .rearLeft
                )
                .position(x: 91, y: geometry.size.height / 2 + 117)
                .onTapGesture {
                    selectedTire = .rearLeft
                }
            }
        }
    }
}

// MARK: - Tire Indicator Component
struct TireIndicators: View {
    let position: TirePosition
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            // Lines indicator (when not selected)
            if !isSelected {
                TireLines()
                    .frame(width: 42.83, height: 61)
                    .offset(x: 0, y: 4)
            }
            
            // Border box
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white, lineWidth: isSelected ? 2 : 1)
                .frame(width: 42, height: 72)
                .opacity(isSelected ? 1.0 : 0.6)
            
            // Selection indicator (optional glow effect)
            if isSelected {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "5CEBFF"), Color(hex: "2FB8FF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 44, height: 74)
                    .blur(radius: 2)
                    .opacity(0.6)
            }
        }
    }
}

// MARK: - Tire Lines (Indicator Pattern)
struct TireLines: View {
    var body: some View {
        // Questo componente rappresenta le linee di indicazione
        // che mostrano la posizione dello pneumatico
        VStack(spacing: 3) {
            ForEach(0..<5) { _ in
                Rectangle()
                    .fill(Color.white.opacity(0.4))
                    .frame(height: 2)
            }
        }
        .frame(width: 42)
    }
}

// MARK: - Tire Position Enum
enum TirePosition: String, CaseIterable {
    case frontLeft = "Front Left"
    case frontRight = "Front Right"
    case rearLeft = "Rear Left"
    case rearRight = "Rear Right"
    
    var icon: String {
        switch self {
        case .frontLeft: return "FL"
        case .frontRight: return "FR"
        case .rearLeft: return "RL"
        case .rearRight: return "RR"
        }
    }
    
    var detailTitle: String {
        return rawValue + " Tire"
    }
}

// MARK: - Preview
struct TireAnalysisView_Previews: PreviewProvider {
    static var previews: some View {
        TireAnalysisView()
    }
}

// MARK: - IMPORTANT NOTE
/*
 Per utilizzare questa view, dovrai:
 
 1. **Aggiungere l'immagine dell'auto**:
    - Scarica l'immagine dal link fornito da Figma
    - Aggiungi l'immagine agli Assets con nome "car_top_view"
    
 2. **Personalizzare le posizioni**:
    - Le coordinate dei TireIndicator potrebbero necessitare
      di aggiustamenti in base all'immagine reale dell'auto
    
 3. **Aggiungere interattività**:
    - Quando un pneumatico viene selezionato, puoi mostrare
      un pannello con i dettagli (pressione, temperatura, usura)
    
 4. **Animazioni**:
    - Aggiungi withAnimation{} nei tap gesture per transizioni fluide
    
 Esempio di utilizzo con dettagli pneumatico:
 
 @State private var showTireDetails = false
 
 .sheet(isPresented: $showTireDetails) {
     TireDetailView(tire: selectedTire)
 }
 
 E nel tap gesture:
 .onTapGesture {
     withAnimation {
         selectedTire = .frontLeft
         showTireDetails = true
     }
 }
*/
