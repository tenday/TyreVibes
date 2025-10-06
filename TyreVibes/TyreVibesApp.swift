//
//  TyreVibesApp.swift
//  TyreVibes
//
//  Created by Matteo La Manna on 11/05/25.
//

import SwiftUI
import GoogleSignIn

@main
struct TyreVibesApp: App {
    @StateObject private var sessionManager = SessionManager()

    var body: some Scene {
        WindowGroup {
            ZStack {
                if sessionManager.isLoggedIn {
                    // Assuming BottomNavigationView will have access to services
                    // through the environment or other means.
                    BottomNavigationView()
                } else {
                    // Injecting the SessionManager into the LoginViewModel,
                    // which is then passed to the LoginScreen.
                    LoginScreen(
                        viewModel: LoginViewModel(sessionManager: sessionManager)
                    )
                }
                SplashScreen()
                    .onOpenURL { url in
                        GIDSignIn.sharedInstance.handle(url)
                    }
            }
            .environmentObject(sessionManager)
        }
    }
}

// Dummy views for compilation, assuming they are defined elsewhere.
struct BottomNavigationView: View {
    var body: some View { Text("Home Screen") }
}

struct LoginScreen: View {
    // This is an assumption based on common MVVM patterns.
    // The actual implementation might differ.
    @ObservedObject var viewModel: LoginViewModel

    var body: some View {
        Text("Login Screen")
    }
}

struct SplashScreen: View {
    var body: some View {
        Color.clear // Dummy view
    }
}