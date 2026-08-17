import Foundation

/// The whole persisted state of the app in one codable envelope.
///
/// Versioned from the start: `schemaVersion` gives a migration hook before
/// there is any user data to lose, which is the only time adding one is free.
struct AppSnapshot: Codable, Hashable {
    var schemaVersion: Int = 1
    var pets: [Pet] = []
    var logs: [BehaviorLog] = []
    var tasks: [CareTask] = []
    var healthRecords: [HealthRecord] = []
    var flags: [BehaviorFlag] = []
    var config: DetectionConfig = .default

    /// This device's stable identity in the sync mesh.
    var nodeID: String = UUID().uuidString

    /// Lamport clock — see `SyncService` for why a wall clock alone is not
    /// enough to order edits from two devices.
    var lamport: Int = 0

    static let empty = AppSnapshot()
}

/// Reads and writes `AppSnapshot` to disk.
///
/// An `actor`, so the main actor never blocks on file I/O, and two concurrent
/// saves can never interleave into a half-written file. Writes go to a
/// temporary file and are then moved into place, so a crash mid-save leaves the
/// previous good snapshot intact rather than a truncated one.
actor PersistenceService {

    enum StorageLocation {
        /// The real app-support file used when the app runs.
        case applicationSupport
        /// A throwaway directory, used by tests so they never touch real data.
        case temporary(String)
        /// Nothing is written at all — used by SwiftUI previews.
        case inMemory
    }

    private let location: StorageLocation
    private var inMemorySnapshot: AppSnapshot?

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init(location: StorageLocation = .applicationSupport) {
        self.location = location
    }

    // MARK: File location

    private var fileURL: URL? {
        switch location {
        case .inMemory:
            return nil

        case .temporary(let name):
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("MyPetTests", isDirectory: true)
                .appendingPathComponent(name, isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory.appendingPathComponent("snapshot.json")

        case .applicationSupport:
            guard let base = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first else { return nil }

            let directory = base.appendingPathComponent("MyPet", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory.appendingPathComponent("snapshot.json")
        }
    }

    /// Where the data actually lives, surfaced in Settings so the file is easy
    /// to find when debugging on a simulator.
    var storageDescription: String {
        fileURL?.path(percentEncoded: false) ?? "In memory only"
    }

    // MARK: Load / save

    /// Loads the snapshot, or `nil` on a first run or an unreadable file.
    ///
    /// A corrupt file is moved aside rather than deleted — losing a household's
    /// pet history to a decode bug would be unforgivable, and a `.corrupt` file
    /// can be recovered by hand.
    func load() -> AppSnapshot? {
        switch location {
        case .inMemory:
            return inMemorySnapshot

        case .temporary, .applicationSupport:
            guard let url = fileURL,
                  FileManager.default.fileExists(atPath: url.path(percentEncoded: false)),
                  let data = try? Data(contentsOf: url)
            else { return nil }

            do {
                return try decoder.decode(AppSnapshot.self, from: data)
            } catch {
                let quarantine = url.appendingPathExtension("corrupt-\(Int(Date.now.timeIntervalSince1970))")
                try? FileManager.default.moveItem(at: url, to: quarantine)
                return nil
            }
        }
    }

    @discardableResult
    func save(_ snapshot: AppSnapshot) -> Bool {
        switch location {
        case .inMemory:
            inMemorySnapshot = snapshot
            return true

        case .temporary, .applicationSupport:
            guard let url = fileURL, let data = try? encoder.encode(snapshot) else { return false }

            // Write-then-move: a crash between the two leaves the old file whole.
            let scratch = url.appendingPathExtension("writing")
            do {
                try data.write(to: scratch, options: .atomic)
                if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                    _ = try FileManager.default.replaceItemAt(url, withItemAt: scratch)
                } else {
                    try FileManager.default.moveItem(at: scratch, to: url)
                }
                return true
            } catch {
                try? FileManager.default.removeItem(at: scratch)
                return false
            }
        }
    }

    /// Wipes stored data. Only reachable from the Settings reset button, which
    /// asks for confirmation first.
    func reset() {
        switch location {
        case .inMemory:
            inMemorySnapshot = nil
        case .temporary, .applicationSupport:
            if let url = fileURL { try? FileManager.default.removeItem(at: url) }
        }
    }
}
