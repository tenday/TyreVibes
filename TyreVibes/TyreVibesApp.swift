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
    @State private var authStateChangeTask: Any? = nil
    
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
            }
            .onReceive(NotificationCenter.default.publisher(for: .didRequestLogout)) { _ in
                isLoggedIn = false
            }
            .environment(\.locale, languageManager.locale)
            .environmentObject(languageManager)
            .onAppear {
                Task { @MainActor in
                    let token = await SupabaseManager.client.auth.onAuthStateChange { event, session in
                        if case .passwordRecovery = event {
                            showResetPasswordScreen = true
                        }
                    }
                    authStateChangeTask = token as Any
                }
            }
            .onDisappear {
                if let cancellable = authStateChangeTask as? AnyObject, cancellable.responds(to: Selector(("cancel"))) {
                    _ = cancellable.perform(Selector(("cancel")))
                }
                authStateChangeTask = nil
            }
        }
    }
}
