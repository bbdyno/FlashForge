//
//  AppDelegate.swift
//  FlashForge
//
//  Created by bbdyno on 2/11/26.
//

import UIKit
import FirebaseCore

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        configureFirebaseIfAvailable()
        AppTelemetry.configure()
        CrashReporter.start()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    private func configureFirebaseIfAvailable() {
        guard FirebaseApp.app() == nil else {
            return
        }

        guard let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: plistPath) else {
            CrashReporter.log("GoogleService-Info.plist not found. Firebase is not configured.")
            return
        }

        FirebaseApp.configure(options: options)
        CrashReporter.log("Firebase configured successfully.")
    }
}
