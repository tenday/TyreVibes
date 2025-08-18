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
    var body: some Scene {
        WindowGroup {
            SplashScreen()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
