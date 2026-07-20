//
//  AppTelemetry.swift
//  FlashForge
//

import Foundation
import FirebaseAnalytics
import FirebaseCore
import FirebaseCrashlytics

enum TelemetryPreferences {
    private enum Key {
        static let analyticsEnabled = "FlashForge.telemetry.analyticsEnabled"
        static let crashReportingEnabled = "FlashForge.telemetry.crashReportingEnabled"
        static let firstStudyCompleted = "FlashForge.telemetry.firstStudyCompleted"
    }

    static var isAnalyticsEnabled: Bool {
        UserDefaults.standard.bool(forKey: Key.analyticsEnabled)
    }

    static var isCrashReportingEnabled: Bool {
        UserDefaults.standard.bool(forKey: Key.crashReportingEnabled)
    }

    static var hasCompletedFirstStudy: Bool {
        get { UserDefaults.standard.bool(forKey: Key.firstStudyCompleted) }
        set { UserDefaults.standard.set(newValue, forKey: Key.firstStudyCompleted) }
    }

    static func setAnalyticsEnabled(_ isEnabled: Bool) {
        UserDefaults.standard.set(isEnabled, forKey: Key.analyticsEnabled)
    }

    static func setCrashReportingEnabled(_ isEnabled: Bool) {
        UserDefaults.standard.set(isEnabled, forKey: Key.crashReportingEnabled)
    }
}

enum AppTelemetry {
    enum Event: String {
        case onboardingCompleted = "onboarding_completed"
        case deckCreated = "deck_created"
        case studySessionStarted = "study_session_started"
        case studySessionCompleted = "study_session_completed"
        case firstStudyCompleted = "first_study_completed"
        case insightsViewed = "insights_viewed"
        case iCloudSyncCompleted = "icloud_sync_completed"
        case backupExported = "backup_exported"
        case backupImported = "backup_imported"
    }

    static func configure() {
        guard FirebaseApp.app() != nil else {
            return
        }
        Analytics.setAnalyticsCollectionEnabled(TelemetryPreferences.isAnalyticsEnabled)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(
            TelemetryPreferences.isCrashReportingEnabled
        )
    }

    static func setAnalyticsEnabled(_ isEnabled: Bool) {
        TelemetryPreferences.setAnalyticsEnabled(isEnabled)
        guard FirebaseApp.app() != nil else {
            return
        }
        Analytics.setAnalyticsCollectionEnabled(isEnabled)
    }

    static func setCrashReportingEnabled(_ isEnabled: Bool) {
        TelemetryPreferences.setCrashReportingEnabled(isEnabled)
        guard FirebaseApp.app() != nil else {
            return
        }

        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCrashlyticsCollectionEnabled(isEnabled)
        if isEnabled {
            crashlytics.sendUnsentReports()
        } else {
            crashlytics.deleteUnsentReports()
        }
    }

    static func log(_ event: Event, parameters: [String: String] = [:]) {
        guard TelemetryPreferences.isAnalyticsEnabled, FirebaseApp.app() != nil else {
            return
        }
        let firebaseParameters = parameters.reduce(into: [String: Any]()) { result, item in
            result[item.key] = item.value
        }
        Analytics.logEvent(event.rawValue, parameters: firebaseParameters)
    }

    static func logFirstStudyCompletedIfNeeded() {
        guard !TelemetryPreferences.hasCompletedFirstStudy else {
            return
        }
        TelemetryPreferences.hasCompletedFirstStudy = true
        log(.firstStudyCompleted)
    }
}
