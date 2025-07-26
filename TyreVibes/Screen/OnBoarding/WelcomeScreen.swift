//
//  WelcomeScreenAdaptive.swift
//  TyreVibes
//
//  Created by Matteo La Manna on 11/05/25.
//

import SwiftUI

struct WelcomeScreen: View {
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let screenWidth = geometry.size.width
                let screenHeight = geometry.size.height
                
                // Calcola le dimensioni dinamiche basate sullo schermo
                let titleFontSize = screenWidth * 0.065 // ~25pt per iPhone 16 Pro
                let headerCircleSize = screenWidth * 0.025
                let carImageWidth = screenWidth * 0.8
                let circleBackgroundSize = screenWidth * 0.74
                let mainTitleFontSize = screenWidth * 0.12 // ~48pt
                let subtitleFontSize = screenWidth * 0.04 // ~16pt
                let buttonHeight = screenHeight * 0.075 // ~60pt
                let buttonFontSize = screenWidth * 0.045 // ~18pt
                let socialButtonHeight = screenHeight * 0.067 // ~56pt
                let socialButtonFontSize = screenWidth * 0.04 // ~16pt
                let iconSize = screenWidth * 0.06 // ~20pt
                let horizontalPadding = screenWidth * 0.06
                
                ZStack {
                    // Background
                    Color.customBackgroundColor.edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            Text("TyreVibes")
                                .font(.customFont(size: titleFontSize, weight: .bold))
                                .foregroundColor(.white)
                            
                            Circle()
                                .fill(Color.customSandyBrown)
                                .frame(width: headerCircleSize, height: headerCircleSize)
                                .offset(x: 0, y: screenHeight * 0.007) // ~6pt
                            
                            Spacer()
                        }
                        //.padding(.top, geometry.safeAreaInsets.top + screenHeight * 0.00)
                        .padding(.horizontal, screenWidth * 0.05)
                        
                        // Car Image with Orange Circle Background
                        ZStack {
                            Circle()
                                .fill(Color.customSandyBrown)
                                .frame(width: min(circleBackgroundSize, 320), height: min(circleBackgroundSize, 320))
                                .offset(x: screenWidth * 0.22, y: -screenHeight * 0.01)
                            
                            // Replace this with your actual car image
                            Image("carSample")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: min(carImageWidth, 700))
                                .offset(x: screenWidth * 0.12, y: screenHeight * 0.02) // Adjust as needed to match the design
                        }
                        .padding(.top, screenHeight * 0.02)
                        .padding(.bottom, screenHeight * -0.02)
                        
                        // Let's Get Started Text
                        VStack(alignment: .leading, spacing: screenHeight * 0.01) {
                            Text("Let's")
                                .font(.customFont(size: mainTitleFontSize, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Get Started")
                                .font(.customFont(size: mainTitleFontSize, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Everything start from here")
                                .font(.customFont(size: subtitleFontSize, weight: .regular))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, screenHeight * 0.05)
                        
                        Spacer()
                        
                        // Login Buttons
                        VStack(spacing: screenHeight * 0.015) {
                            
                            NavigationLink(destination: LoginScreen()
                                .navigationBarBackButtonHidden(true)){
                                    Text("Log in")
                                        .font(.customFont(size: buttonFontSize, weight: .semibold))
                                        .foregroundColor(Color.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: buttonHeight)
                                        .background(Color.customBitterSweet)
                                        .cornerRadius(screenWidth * 0.133) // ~50pt radius
                            }
                        
                            
                            
                            NavigationLink(destination: SignUpScreen()
                                .navigationBarBackButtonHidden(true)){
                                Text("Sign Up")
                                    .font(.customFont(size: buttonFontSize, weight: .semibold))
                                    .foregroundColor(Color.customBitterSweet)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: buttonHeight)
                                    .cornerRadius(screenWidth * 0.133)
                                    .background(Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: screenWidth * 0.133)
                                            .stroke(Color.customBitterSweet.opacity(1), lineWidth: 1)
                                    )
                            }
                            
                            // Or Continue With
                            HStack {
                                Rectangle()
                                    .fill(Color(hex: "FFFFFF"))
                                    .frame(width: screenWidth * 0.25, height: 0.5)
                                
                                Text("Or Continue With")
                                    .font(.customFont(size: screenWidth * 0.031, weight: .regular)) // ~12pt
                                    .foregroundColor(Color(hex: "FFFFFF"))
                                    .padding(.horizontal, screenWidth * 0.025)
                                
                                Rectangle()
                                    .fill(Color(hex: "FFFFFF"))
                                    .frame(width: screenWidth * 0.25, height: 0.5)
                            }
                            .padding(.vertical, screenHeight * 0.02)
                            
                            // Social Login Buttons
                            HStack(spacing: screenWidth * 0.04) {
                                Button(action: {
                                    // Handle Google log in
                                }) {
                                    HStack {
                                        Image("GoogleIcon") // Replace with Google logo
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: iconSize, height: iconSize)
                                            .foregroundColor(.white)
                                        
                                        Text("Google")
                                            .font(.customFont(size: socialButtonFontSize, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: socialButtonHeight)
                                    .background(Color(hex: "3A3A3A").opacity(0.3))
                                    .cornerRadius(screenWidth * 0.075) // ~28pt radius
                                    
                                }
                                
                                Button(action: {
                                    // Handle Apple login
                                }) {
                                    HStack {
                                        Image("AppleIcon") // Apple logo
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: iconSize, height: iconSize)
                                            .foregroundColor(.white)
                                        
                                        Text("Apple")
                                            .font(.customFont(size: socialButtonFontSize, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: socialButtonHeight)
                                    .background(Color(hex: "3A3A3A").opacity(0.3))
                                    .cornerRadius(screenWidth * 0.075)
                                }
                            }
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, geometry.safeAreaInsets.bottom + screenHeight * 0.04)
                    }
                }
                .preferredColorScheme(.dark)
                .navigationBarBackButtonHidden(true)
            }
        }
    }
}

#Preview {
    WelcomeScreen()
}
