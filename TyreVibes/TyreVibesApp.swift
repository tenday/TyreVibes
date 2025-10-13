//
//  TyreVibesApp.swift
//  TyreVibes
//
//  Created by Matteo La Manna on 11/05/25.
//

import SwiftUI
import GoogleSignIn
import Supabase

@main
struct TyreVibesApp: App {
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @StateObject private var languageManager = LanguageManager.shared
    @State private var showResetPasswordScreen = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isLoggedIn {
                    BottomNavigationView()
                } else {
                    LoginScreen()
                }
                SplashScreen()
            }

            .sheet(isPresented: $showResetPasswordScreen) {
                ResetPasswordScreen()
            }
            .onOpenURL { url in
                if GIDSignIn.sharedInstance.handle(url) {
                    return
                }

                if url.scheme == "it.tyrevibes.app" && url.host == "reset-password" {
                    showResetPasswordScreen = true
                }
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
            .onReceive(NotificationCenter.default.publisher(for: .didRequestLogout)) { _ in
                isLoggedIn = false
            }
            .environment(\.locale, languageManager.locale)
            .environmentObject(languageManager)
            .onReceive(NotificationCenter.default.publisher(for: .didRequestLogout)) { _ in
                isLoggedIn = false
            }
            .onAppear {
                SupabaseManager.client.auth.onAuthStateChange { event, session in
                    if case .passwordRecovery = event {
                        showResetPasswordScreen = true
                    }
                }
            }
        }
    }
}
