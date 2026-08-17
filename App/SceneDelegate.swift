//
//  SceneDelegate.swift
//  FlashForge
//
//  Created by bbdyno on 2/11/26.
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let repository = CardRepository()
    private lazy var cloudSyncService = ICloudSyncService(repository: repository)
    private var deckDataObserver: NSObjectProtocol?
    private var manualSyncObserver: NSObjectProtocol?
    private var syncStatusObserver: NSObjectProtocol?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = RootTabBarController(repository: repository)
        AppAppearanceService.shared.apply(to: window)
        window.makeKeyAndVisible()
        self.window = window

        if deckDataObserver == nil {
            deckDataObserver = NotificationCenter.default.addObserver(
                forName: .deckDataDidChange,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                guard let self else { return }
                Task {
                    await self.cloudSyncService.handleLocalDataDidChange()
                }
            }
        }

        if manualSyncObserver == nil {
            manualSyncObserver = NotificationCenter.default.addObserver(
                forName: .iCloudSyncManualRequested,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                guard let self else { return }
                Task {
                    await self.cloudSyncService.syncFromCloudNow()
                }
            }
        }

        if syncStatusObserver == nil {
            syncStatusObserver = NotificationCenter.default.addObserver(
                forName: .iCloudSyncStatusDidChange,
                object: nil,
                queue: nil
            ) { notification in
                let userInfo = notification.userInfo ?? [:]
                let isSyncing = (userInfo[ICloudSyncNotificationKey.isSyncing] as? Bool) ?? false
                let lastSyncedAt = userInfo[ICloudSyncNotificationKey.lastSyncedAt] as? Date
                let hasError = ((userInfo[ICloudSyncNotificationKey.errorMessage] as? String) ?? "").isEmpty == false
                Task { @MainActor in
                    StudyStatusService.shared.updateSyncStatus(
                        isSyncing: isSyncing,
                        lastSyncedAt: lastSyncedAt,
                        hasError: hasError
                    )
                }
            }
        }

        Task {
            await cloudSyncService.bootstrap()
        }
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        Task {
            await cloudSyncService.syncFromCloudNow()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        if let deckDataObserver {
            NotificationCenter.default.removeObserver(deckDataObserver)
            self.deckDataObserver = nil
        }
        if let manualSyncObserver {
            NotificationCenter.default.removeObserver(manualSyncObserver)
            self.manualSyncObserver = nil
        }
        if let syncStatusObserver {
            NotificationCenter.default.removeObserver(syncStatusObserver)
            self.syncStatusObserver = nil
        }
    }

}
