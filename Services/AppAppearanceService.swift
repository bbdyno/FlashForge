//
//  AppAppearanceService.swift
//  FlashForge
//

import UIKit

enum AppAppearance: String, CaseIterable, Sendable {
    case system
    case light
    case dark

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system:
            return .unspecified
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

extension Notification.Name {
    static let appAppearanceDidChange = Notification.Name("appAppearanceDidChange")
}

@MainActor
final class AppAppearanceService {
    static let shared = AppAppearanceService()

    private enum Key {
        static let appearance = "appAppearance"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var current: AppAppearance {
        guard let rawValue = defaults.string(forKey: Key.appearance),
              let appearance = AppAppearance(rawValue: rawValue) else {
            return .dark
        }
        return appearance
    }

    func apply(to window: UIWindow) {
        window.overrideUserInterfaceStyle = current.interfaceStyle
    }

    func set(_ appearance: AppAppearance, on window: UIWindow?) {
        defaults.set(appearance.rawValue, forKey: Key.appearance)
        window?.overrideUserInterfaceStyle = appearance.interfaceStyle
        NotificationCenter.default.post(
            name: .appAppearanceDidChange,
            object: self,
            userInfo: ["appearance": appearance.rawValue]
        )
    }
}
