import Foundation

actor ICloudSyncService {
    private struct CloudSnapshotEnvelope: Codable, Sendable {
        let version: Int
        let updatedAt: Date
        let backupData: Data

        init(updatedAt: Date, backupData: Data) {
            self.version = Constants.currentSnapshotVersion
            self.updatedAt = updatedAt
            self.backupData = backupData
        }
    }

    private enum SyncError: LocalizedError {
        case iCloudUnavailable
        case unsupportedSnapshotVersion(Int)
        case coordinatedReadFailed
        case coordinatedWriteFailed

        var errorDescription: String? {
            switch self {
            case .iCloudUnavailable:
                return "iCloud Drive is unavailable. Check your Apple ID and iCloud Drive settings."
            case let .unsupportedSnapshotVersion(version):
                return "This iCloud data uses a newer sync format (version \(version)). Update FlashForge before syncing."
            case .coordinatedReadFailed:
                return "FlashForge could not safely read the iCloud snapshot."
            case .coordinatedWriteFailed:
                return "FlashForge could not safely write the iCloud snapshot."
            }
        }
    }

    private enum Constants {
        static let currentSnapshotVersion = 1
        static let defaultContainerIdentifier = "iCloud.com.bbdyno.app.flashFlow"
        static let snapshotFileName = "flashforge-sync-v1.json"
        static let localRevisionKey = "FlashForge.iCloud.localRevision"
    }

    private enum DateCoding {
        static let fractionalFormatter: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter
        }()

        static let legacyFormatter: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            return formatter
        }()

        static func decode(_ value: String) -> Date? {
            fractionalFormatter.date(from: value) ?? legacyFormatter.date(from: value)
        }
    }

    private let repository: CardRepository
    private let fileManager: FileManager
    private let notificationCenter: NotificationCenter
    private let userDefaults: UserDefaults
    private let ubiquityContainerIdentifier: String
    private let containerURLOverride: URL?

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private var hasBootstrapped = false
    private var suppressNextLocalPush = false

    init(
        repository: CardRepository,
        fileManager: FileManager = .default,
        notificationCenter: NotificationCenter = .default,
        userDefaults: UserDefaults = .standard,
        ubiquityContainerIdentifier: String = Constants.defaultContainerIdentifier,
        containerURLOverride: URL? = nil
    ) {
        self.repository = repository
        self.fileManager = fileManager
        self.notificationCenter = notificationCenter
        self.userDefaults = userDefaults
        self.ubiquityContainerIdentifier = ubiquityContainerIdentifier
        self.containerURLOverride = containerURLOverride

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(DateCoding.fractionalFormatter.string(from: date))
        }
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = DateCoding.decode(value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported date format: \(value)"
            )
        }
    }

    func bootstrap() async {
        guard !hasBootstrapped else {
            return
        }
        hasBootstrapped = true

        do {
            try await repository.prepare()
            try await syncBidirectionally()
            await publishStatus(isSyncing: false, errorMessage: nil)
        } catch {
            CrashReporter.record(error: error, context: "ICloudSyncService.bootstrap")
            await publishStatus(isSyncing: false, errorMessage: error.localizedDescription)
            return
        }
    }

    func handleLocalDataDidChange() async {
        if suppressNextLocalPush {
            suppressNextLocalPush = false
            return
        }

        do {
            try await repository.prepare()
            try await pushLocalSnapshot()
            await publishStatus(isSyncing: false, errorMessage: nil)
        } catch {
            CrashReporter.record(error: error, context: "ICloudSyncService.handleLocalDataDidChange")
            await publishStatus(isSyncing: false, errorMessage: error.localizedDescription)
            return
        }
    }

    func syncFromCloudNow() async {
        await publishStatus(isSyncing: true, errorMessage: nil)
        do {
            try await repository.prepare()
            try await syncBidirectionally()
            await publishStatus(isSyncing: false, errorMessage: nil)
        } catch {
            CrashReporter.record(error: error, context: "ICloudSyncService.syncFromCloudNow")
            await publishStatus(isSyncing: false, errorMessage: error.localizedDescription)
            return
        }
    }

    private func syncBidirectionally() async throws {
        let localHasDecks = try await repository.hasAnyDecks()
        let remoteEnvelope = try loadRemoteEnvelope()
        let localRevisionDate = localRevisionDate

        guard let remoteEnvelope else {
            if localHasDecks {
                try await pushLocalSnapshot()
            }
            return
        }

        guard let localRevisionDate else {
            if localHasDecks {
                try await pushLocalSnapshot()
            } else {
                try await importRemoteEnvelope(remoteEnvelope)
            }
            return
        }

        if remoteEnvelope.updatedAt > localRevisionDate {
            try await importRemoteEnvelope(remoteEnvelope)
        } else if remoteEnvelope.updatedAt < localRevisionDate {
            try await pushLocalSnapshot()
        }
    }

    private func importRemoteEnvelope(_ envelope: CloudSnapshotEnvelope) async throws {
        try await repository.importBackupData(envelope.backupData)
        localRevisionDate = envelope.updatedAt
        suppressNextLocalPush = true

        await MainActor.run {
            notificationCenter.post(name: .deckDataDidChange, object: nil)
        }
    }

    private func pushLocalSnapshot() async throws {
        let backupData = try await repository.exportBackupData()
        let updatedAt = Date()
        let envelope = CloudSnapshotEnvelope(updatedAt: updatedAt, backupData: backupData)
        try writeRemoteEnvelope(envelope)
        localRevisionDate = updatedAt
    }

    private func loadRemoteEnvelope() throws -> CloudSnapshotEnvelope? {
        let fileURL = try cloudSnapshotFileURL()

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let currentEnvelope = try decodeAndValidateEnvelope(
            from: try coordinatedRead(from: fileURL)
        )
        let conflictVersions = NSFileVersion.unresolvedConflictVersionsOfItem(at: fileURL) ?? []
        guard !conflictVersions.isEmpty else {
            return currentEnvelope
        }

        var candidates: [(envelope: CloudSnapshotEnvelope, isCurrent: Bool)] = [
            (currentEnvelope, true)
        ]
        for conflictVersion in conflictVersions {
            let envelope = try decodeAndValidateEnvelope(
                from: try coordinatedRead(from: conflictVersion.url)
            )
            candidates.append((envelope, false))
        }

        guard let winner = candidates.max(by: {
            $0.envelope.updatedAt < $1.envelope.updatedAt
        }) else {
            return currentEnvelope
        }

        if !winner.isCurrent {
            try writeRemoteEnvelope(winner.envelope)
        }

        for conflictVersion in conflictVersions {
            conflictVersion.isResolved = true
            do {
                try conflictVersion.remove()
            } catch {
                CrashReporter.record(error: error, context: "ICloudSyncService.resolveConflictVersion")
            }
        }

        return winner.envelope
    }

    private func writeRemoteEnvelope(_ envelope: CloudSnapshotEnvelope) throws {
        let fileURL = try cloudSnapshotFileURL()
        let data = try encoder.encode(envelope)
        try coordinatedWrite(data, to: fileURL)
    }

    private func cloudSnapshotFileURL() throws -> URL {
        if let containerURLOverride {
            try fileManager.createDirectory(at: containerURLOverride, withIntermediateDirectories: true)
            return containerURLOverride.appendingPathComponent(Constants.snapshotFileName)
        }

        guard let containerRoot = fileManager.url(forUbiquityContainerIdentifier: ubiquityContainerIdentifier) else {
            throw SyncError.iCloudUnavailable
        }

        let documentsURL = containerRoot.appendingPathComponent("Documents", isDirectory: true)
        try fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        return documentsURL.appendingPathComponent(Constants.snapshotFileName)
    }

    private func decodeAndValidateEnvelope(from data: Data) throws -> CloudSnapshotEnvelope {
        let envelope = try decoder.decode(CloudSnapshotEnvelope.self, from: data)
        guard envelope.version <= Constants.currentSnapshotVersion else {
            throw SyncError.unsupportedSnapshotVersion(envelope.version)
        }
        _ = try compatibleBackupPreview(envelope.backupData)
        return envelope
    }

    private func compatibleBackupPreview(_ backupData: Data) throws -> BackupPreview {
        // Envelope validation happens on the actor, before any destructive repository import.
        // The payload itself is decoded again by CardRepository during import.
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        struct BackupShape: Decodable {
            let decks: [Deck]
        }
        let shape = try decoder.decode(BackupShape.self, from: backupData)
        return BackupPreview(
            deckCount: shape.decks.count,
            cardCount: shape.decks.reduce(0) { $0 + $1.cards.count },
            reviewCount: shape.decks.reduce(0) { total, deck in
                total + deck.cards.reduce(0) { $0 + $1.schedule.reviewHistory.count }
            }
        )
    }

    private func coordinatedRead(from fileURL: URL) throws -> Data {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var operationResult: Result<Data, Error>?

        coordinator.coordinate(
            readingItemAt: fileURL,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            operationResult = Result {
                try Data(contentsOf: coordinatedURL)
            }
        }

        if let coordinationError {
            throw coordinationError
        }
        guard let operationResult else {
            throw SyncError.coordinatedReadFailed
        }
        return try operationResult.get()
    }

    private func coordinatedWrite(_ data: Data, to fileURL: URL) throws {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var operationError: Error?
        var didCoordinate = false

        coordinator.coordinate(
            writingItemAt: fileURL,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            didCoordinate = true
            do {
                try data.write(to: coordinatedURL, options: .atomic)
            } catch {
                operationError = error
            }
        }

        if let coordinationError {
            throw coordinationError
        }
        if let operationError {
            throw operationError
        }
        guard didCoordinate else {
            throw SyncError.coordinatedWriteFailed
        }
    }

    private var localRevisionDate: Date? {
        get {
            userDefaults.object(forKey: Constants.localRevisionKey) as? Date
        }
        set {
            userDefaults.set(newValue, forKey: Constants.localRevisionKey)
        }
    }

    private func publishStatus(isSyncing: Bool, errorMessage: String?) async {
        var userInfo: [String: Any] = [
            ICloudSyncNotificationKey.isSyncing: isSyncing
        ]
        if let localRevisionDate {
            userInfo[ICloudSyncNotificationKey.lastSyncedAt] = localRevisionDate
        }
        if let errorMessage, !errorMessage.isEmpty {
            userInfo[ICloudSyncNotificationKey.errorMessage] = errorMessage
        }
        await MainActor.run {
            notificationCenter.post(name: .iCloudSyncStatusDidChange, object: nil, userInfo: userInfo)
        }
    }
}
