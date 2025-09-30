//
//  TyreVibesApp.swift
//  TyreVibes
//
//  Created by Matteo La Manna on 11/05/25.
//

import SwiftUI
import GoogleSignIn
import GoogleMobileAds

@main
struct TyreVibesApp: App {
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false

    init() {
        GADMobileAds.sharedInstance().start(completionHandler: nil)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isLoggedIn {
                    BottomNavigationView()
                } else {
                    LoginScreen()
                }
                SplashScreen()
                    .onOpenURL { url in
                        GIDSignIn.sharedInstance.handle(url)
                    }
            }
        }
    }
}
