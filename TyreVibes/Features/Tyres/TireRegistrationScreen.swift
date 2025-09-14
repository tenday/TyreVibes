//
//  TireRegistrationView.swift
//  TyreVibes
//
//  Created by Matteo La Manna on 14/09/25.
//


import SwiftUI

struct TyreRegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            // Background
            Color.customBackgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Status bar area
                Spacer()
                    .frame(height: 29)
                
                // Title
                HStack {
                    Text("Tire Registration")
                        .font(.customFont(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 10, height: 10)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(
                                ZStack {
                                    Circle()
                                        .fill(Color.customBackgroundColor)
                                    Circle()
                                        .stroke(Color.white.opacity(0.22), lineWidth: 1.5)
                                        .blur(radius: 1)
                                        .offset(x: 0.3, y: 1)
                                        .mask(
                                            Circle().fill(LinearGradient(
                                                gradient: Gradient(colors: [.black, .black]),
                                                startPoint: .top,
                                                endPoint: .bottom)
                                            )
                                        )
                                    VisualEffectBlur(blurStyle:.systemUltraThinMaterial)
                                        .clipShape(Circle())
                                        .padding(12)
                                        .blur(radius: 40)
                                        .opacity(0.8)
                                }
                            )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 80)
                
                // Tire circle with dashed border
                ZStack {
                    // Dashed circle border
                    Circle()
                        .stroke(
                            style: StrokeStyle(
                                lineWidth: 2,
                                dash: [10, 8]
                            )
                        )
                        .foregroundColor(.white)
                        .frame(width: 360, height: 360)
                    
                    CameraPreview(
                        roiSize: CGSize(width: 350, height: 350),
                        onPlateDetected: { _ in }
                    )
                        .frame(width: 350, height: 350)
                        .clipShape(Circle())
                }
                .padding(.bottom, 100)
                
                // Bottom text
                VStack(spacing: 8) {
                    Text("Position Tire within Frame")
                        .font(.customFont(size: 26, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Ensure text is visible")
                        .font(.customFont(size: 18, weight: .regular))
                        .foregroundColor(.white)
                }
                
                Spacer()
            }
        }
    }
}

struct TireTreadView: View {
    var body: some View {
        ZStack {
            // Outer tire
            Circle()
                .fill(Color.gray.opacity(0.8))
            
            // Inner rim
            Circle()
                .fill(Color.gray.opacity(0.6))
                .frame(width: 120, height: 120)
            
            // Tread pattern - vertical lines around the tire
            ForEach(0..<24) { index in
                Rectangle()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 3, height: 25)
                    .offset(y: -105)
                    .rotationEffect(.degrees(Double(index) * 15))
            }
            
            // Radial spokes
            ForEach(0..<8) { index in
                Rectangle()
                    .fill(Color.black.opacity(0.2))
                    .frame(width: 2, height: 60)
                    .rotationEffect(.degrees(Double(index) * 45))
            }
            
            // Center hub
            Circle()
                .fill(Color.gray.opacity(0.9))
                .frame(width: 40, height: 40)
        }
    }
}

#Preview {
    TyreRegistrationView()
}
