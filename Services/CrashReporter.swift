import Foundation
import FirebaseCore
import FirebaseCrashlytics

enum CrashReporter {
    private static let prefix = "[CrashReporter]"
    private static var hasInstalledExceptionHandler = false
    private static var previousExceptionHandler: (@convention(c) (NSException) -> Void)?

    static func start() {
        log("Crash reporter initialized")
        installUncaughtExceptionHandlerIfNeeded()

        guard TelemetryPreferences.isCrashReportingEnabled, FirebaseApp.app() != nil else {
            log("Crashlytics reporting is disabled.")
            return
        }

        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCustomValue(bundleShortVersion, forKey: "app_version")
        crashlytics.setCustomValue(bundleBuildVersion, forKey: "build_number")

        if crashlytics.didCrashDuringPreviousExecution() {
            let message = "Detected crash during previous execution. Check Firebase Console > Crashlytics."
            log(message)
            crashlytics.log(message)
        }
    }

    static func log(_ message: String, file: StaticString = #fileID, line: UInt = #line) {
        let formatted = "\(message) [\(file):\(line)]"
        print("\(prefix) \(formatted)")

        guard TelemetryPreferences.isCrashReportingEnabled, FirebaseApp.app() != nil else {
            return
        }

        Crashlytics.crashlytics().log(formatted)
    }

    static func record(
        error: Error,
        context: String,
        userInfo: [String: Any] = [:],
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        let summary = "Non-fatal issue in \(context): \(error.localizedDescription)"
        log(summary, file: file, line: line)

        guard TelemetryPreferences.isCrashReportingEnabled, FirebaseApp.app() != nil else {
            return
        }

        var enriched = userInfo
        enriched["context"] = context
        enriched["source_file"] = "\(file)"
        enriched["source_line"] = Int(line)

        Crashlytics.crashlytics().record(error: error, userInfo: enriched)
    }

    private static var bundleShortVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "unknown"
    }

    private static var bundleBuildVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "unknown"
    }

    private static func installUncaughtExceptionHandlerIfNeeded() {
        guard !hasInstalledExceptionHandler else {
            return
        }
        hasInstalledExceptionHandler = true
        previousExceptionHandler = NSGetUncaughtExceptionHandler()

        NSSetUncaughtExceptionHandler { exception in
            let reason = exception.reason ?? "Unknown reason"
            let callStack = exception.callStackSymbols.joined(separator: "\n")
            let message = "Uncaught NSException: \(exception.name.rawValue) - \(reason)"

            CrashReporter.log(message)
            CrashReporter.log("Call stack:\n\(callStack)")

            guard TelemetryPreferences.isCrashReportingEnabled, FirebaseApp.app() != nil else {
                CrashReporter.previousExceptionHandler?(exception)
                return
            }

            let userInfo: [String: Any] = [
                "exception_name": exception.name.rawValue,
                "exception_reason": reason,
                "call_stack": callStack
            ]
            let error = NSError(
                domain: "com.bbdyno.flashflow.uncaught-exception",
                code: 1,
                userInfo: userInfo
            )
            Crashlytics.crashlytics().record(error: error)
            CrashReporter.previousExceptionHandler?(exception)
        }
    }
}
