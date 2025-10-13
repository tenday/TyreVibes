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
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @StateObject private var languageManager = LanguageManager.shared

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
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
            .onReceive(NotificationCenter.default.publisher(for: .didRequestLogout)) { _ in
                isLoggedIn = false
            }
            .environment(\.locale, languageManager.locale)
            .environmentObject(languageManager)
        }
    }
}
