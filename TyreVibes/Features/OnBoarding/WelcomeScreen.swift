//
//  WelcomeScreenAdaptive.swift
//  TyreVibes
//
//  Created by Matteo La Manna on 11/05/25.
//

import SwiftUI

struct WelcomeScreen: View {

    @StateObject private var viewModel = LoginViewModel()
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @State private var goToLogin = false
    @State private var goToSignUp = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoggedIn || viewModel.showHomeScreen {
                    BottomNavigationView()
                } else {
                    GeometryReader { geometry in
                        let metrics = WelcomeLayoutMetrics(geometry: geometry)

                        ZStack {
                            // Background
                            Color.customBackgroundColor.edgesIgnoringSafeArea(.all)

                            VStack(spacing: 0) {
                                HeaderView(metrics: metrics)
                                    .padding(.horizontal, geometry.size.width * 0.05)

                                HeroImageView(metrics: metrics)
                                    .padding(.top, geometry.size.height * 0.02)
                                    .padding(.bottom, geometry.size.height * -0.02)

                                TitleView(metrics: metrics)
                                    .padding(.horizontal, metrics.horizontalPadding)
                                    .padding(.bottom, geometry.size.height * 0.05)

                                Spacer()

                                VStack(spacing: geometry.size.height * 0.015) {
                                    ActionButtonsView(
                                        metrics: metrics,
                                        goToLogin: $goToLogin,
                                        goToSignUp: $goToSignUp
                                    )

                                    SocialLoginView(
                                        metrics: metrics,
                                        onGoogleTap: {
                                            // Handle Google log in
                                        },
                                        onAppleTap: {
                                            handleAppleLogin()
                                        }
                                    )
                                }
                                .padding(.horizontal, metrics.horizontalPadding)
                                .padding(.bottom, geometry.safeAreaInsets.bottom + geometry.size.height * 0.04)
                            }
                        }
                        .preferredColorScheme(.dark)
                        .navigationBarHidden(true)
                        .navigationBarBackButtonHidden(true)

                    }
                }
            }
            .onAppear {
                viewModel.attemptAutoLogin()
            }
            .onChange(of: viewModel.showHomeScreen) { _, newValue in
                if newValue {
                    isLoggedIn = true
                }
            }
            .onChange(of: isLoggedIn) { _, newValue in
                if newValue {
                    goToLogin = false
                } else {
                    viewModel.showHomeScreen = false
                    goToLogin = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .didRequestLogout)) { _ in
                viewModel.showHomeScreen = false
                viewModel.email = ""
                viewModel.password = ""
                goToLogin = true
            }
            .navigationDestination(isPresented: $goToLogin) {
                LoginScreen()
                    .navigationBarBackButtonHidden(true)
            }
            .navigationDestination(isPresented: $goToSignUp) {
                SignUpScreen()
                    .navigationBarBackButtonHidden(true)
            }
        }
    }

    private func handleAppleLogin() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            print(window)
            viewModel.signInWithApple(presentationAnchor: window)
        }
    }
}

// MARK: - Subviews

private struct HeaderView: View {
    let metrics: WelcomeLayoutMetrics

    var body: some View {
        HStack {
            Text("TyreVibes")
                .font(.customFont(size: metrics.titleFontSize, weight: .bold))
                .foregroundColor(.white)

            Circle()
                .fill(Color.customSandyBrown)
                .frame(width: metrics.headerCircleSize, height: metrics.headerCircleSize)
                .offset(x: 0, y: metrics.screenHeight * 0.007)

            Spacer()
        }
    }
}

private struct HeroImageView: View {
    let metrics: WelcomeLayoutMetrics

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.customSandyBrown)
                .frame(width: min(metrics.circleBackgroundSize, 320), height: min(metrics.circleBackgroundSize, 320))
                .offset(x: metrics.screenWidth * 0.22, y: -metrics.screenHeight * 0.01)

            Image("carSample")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: min(metrics.carImageWidth, 700))
                .offset(x: metrics.screenWidth * 0.12, y: metrics.screenHeight * 0.02)
        }
    }
}

private struct TitleView: View {
    let metrics: WelcomeLayoutMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.screenHeight * 0.01) {
            Text("Let's")
                .font(.customFont(size: metrics.mainTitleFontSize, weight: .bold))
                .foregroundColor(.white)

            Text("Get Started")
                .font(.customFont(size: metrics.mainTitleFontSize, weight: .bold))
                .foregroundColor(.white)

            Text("Everything start from here")
                .font(.customFont(size: metrics.subtitleFontSize, weight: .regular))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ActionButtonsView: View {
    let metrics: WelcomeLayoutMetrics
    @Binding var goToLogin: Bool
    @Binding var goToSignUp: Bool

    var body: some View {
        Group {
            Button(action: {
                goToLogin = true
            }) {
                Text("Log in")
                    .font(.customFont(size: metrics.buttonFontSize, weight: .semibold))
                    .foregroundColor(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: metrics.buttonHeight)
                    .background(Color.customBitterSweet)
                    .cornerRadius(metrics.screenWidth * 0.133)
            }

            Button(action: {
                goToSignUp = true
            }) {
                Text("Sign Up")
                    .font(.customFont(size: metrics.buttonFontSize, weight: .semibold))
                    .foregroundColor(Color.customBitterSweet)
                    .frame(maxWidth: .infinity)
                    .frame(height: metrics.buttonHeight)
                    .cornerRadius(metrics.screenWidth * 0.133)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: metrics.screenWidth * 0.133)
                            .stroke(Color.customBitterSweet.opacity(1), lineWidth: 1)
                    )
            }
        }
    }
}

private struct SocialLoginView: View {
    let metrics: WelcomeLayoutMetrics
    let onGoogleTap: () -> Void
    let onAppleTap: () -> Void

    var body: some View {
        VStack(spacing: metrics.screenHeight * 0.015) {
            // Or Continue With
            HStack {
                Rectangle()
                    .fill(Color(hex: "FFFFFF"))
                    .frame(width: metrics.screenWidth * 0.25, height: 0.5)

                Text("Or Continue With")
                    .font(.customFont(size: metrics.screenWidth * 0.031, weight: .regular))
                    .foregroundColor(Color(hex: "FFFFFF"))
                    .padding(.horizontal, metrics.screenWidth * 0.025)

                Rectangle()
                    .fill(Color(hex: "FFFFFF"))
                    .frame(width: metrics.screenWidth * 0.25, height: 0.5)
            }
            .padding(.vertical, metrics.screenHeight * 0.02)

            // Social Login Buttons
            HStack(spacing: metrics.screenWidth * 0.04) {
                SocialButton(
                    metrics: metrics,
                    iconName: "GoogleIcon",
                    title: "Google",
                    action: onGoogleTap
                )

                SocialButton(
                    metrics: metrics,
                    iconName: "AppleIcon",
                    title: "Apple",
                    action: onAppleTap
                )
            }
        }
    }
}

private struct SocialButton: View {
    let metrics: WelcomeLayoutMetrics
    let iconName: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: metrics.iconSize, height: metrics.iconSize)
                    .foregroundColor(.white)

                Text(title)
                    .font(.customFont(size: metrics.socialButtonFontSize, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: metrics.socialButtonHeight)
            .background(Color(hex: "3A3A3A").opacity(0.3))
            .cornerRadius(metrics.screenWidth * 0.075)
        }
    }
}

// MARK: - Layout Metrics

struct WelcomeLayoutMetrics {
    let screenWidth: CGFloat
    let screenHeight: CGFloat

    init(geometry: GeometryProxy) {
        self.screenWidth = geometry.size.width
        self.screenHeight = geometry.size.height
    }

    var titleFontSize: CGFloat { screenWidth * 0.065 }
    var headerCircleSize: CGFloat { screenWidth * 0.025 }
    var carImageWidth: CGFloat { screenWidth * 0.8 }
    var circleBackgroundSize: CGFloat { screenWidth * 0.74 }
    var mainTitleFontSize: CGFloat { screenWidth * 0.12 }
    var subtitleFontSize: CGFloat { screenWidth * 0.04 }
    var buttonHeight: CGFloat { screenHeight * 0.075 }
    var buttonFontSize: CGFloat { screenWidth * 0.045 }
    var socialButtonHeight: CGFloat { screenHeight * 0.067 }
    var socialButtonFontSize: CGFloat { screenWidth * 0.04 }
    var iconSize: CGFloat { screenWidth * 0.06 }
    var horizontalPadding: CGFloat { screenWidth * 0.06 }
}

#Preview {
    WelcomeScreen()
}
