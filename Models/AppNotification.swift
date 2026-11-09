//
//  AppNotification.swift
//  FlashForge
//
//  Created by bbdyno on 2/11/26.
//

import Foundation

extension Notification.Name {
    static let deckDataDidChange = Notification.Name("FlashForge.deckDataDidChange")
    static let iCloudSyncManualRequested = Notification.Name("FlashForge.iCloudSyncManualRequested")
    static let iCloudSyncStatusDidChange = Notification.Name("FlashForge.iCloudSyncStatusDidChange")
}

enum ICloudSyncNotificationKey {
    static let isSyncing = "isSyncing"
    static let lastSyncedAt = "lastSyncedAt"
    static let errorMessage = "errorMessage"
}
