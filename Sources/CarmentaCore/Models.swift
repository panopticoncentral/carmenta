import Foundation
import CryptoKit

public enum PoemStage: String, Codable, CaseIterable, Identifiable, Sendable {
    case draft = "Draft", revising = "Revising", ready = "Ready to submit", published = "Published"
    public var id: String { rawValue }
}

public enum VenueKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case journal = "Journal", contest = "Contest"
    public var id: String { rawValue }
}

public enum Outcome: String, Codable, CaseIterable, Identifiable, Sendable {
    case pending = "Pending", accepted = "Accepted", declined = "Declined", withdrawn = "Withdrawn"
    public var id: String { rawValue }
}

public struct Poem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var stage: PoemStage
    public var notes: String
    public var createdAt: Date
    public var updatedAt: Date
    public init(id: UUID = UUID(), title: String = "", stage: PoemStage = .draft, notes: String = "", createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id; self.title = title; self.stage = stage; self.notes = notes
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

public struct Venue: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var kind: VenueKind
    public var website: String
    public var deadline: Date?
    public var notes: String
    public init(id: UUID = UUID(), name: String = "", kind: VenueKind = .journal, website: String = "", deadline: Date? = nil, notes: String = "") {
        self.id = id; self.name = name; self.kind = kind; self.website = website
        self.deadline = deadline; self.notes = notes
    }
    public var websiteURL: URL? {
        let value = website.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, let url = URL(string: value.contains("://") ? value : "https://" + value),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }
}

public struct SubmissionEntry: Identifiable, Codable, Equatable, Sendable {
    public var poemID: UUID
    public var outcome: Outcome
    public var id: UUID { poemID }
    public init(poemID: UUID, outcome: Outcome = .pending) {
        self.poemID = poemID; self.outcome = outcome
    }
}

public struct Submission: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var venueID: UUID
    public var entries: [SubmissionEntry]
    public var sentAt: Date
    public var completedAt: Date?
    public var notes: String
    public init(id: UUID = UUID(), venueID: UUID, entries: [SubmissionEntry] = [], sentAt: Date = .now, completedAt: Date? = nil, notes: String = "") {
        self.id = id; self.venueID = venueID; self.entries = entries
        self.sentAt = sentAt; self.completedAt = completedAt; self.notes = notes
    }
    public var isPending: Bool { entries.contains { $0.outcome == .pending } }
    public var outcome: Outcome {
        if isPending { return .pending }
        if entries.contains(where: { $0.outcome == .accepted }) { return .accepted }
        if entries.contains(where: { $0.outcome == .declined }) { return .declined }
        return .withdrawn
    }
}

public struct Library: Codable, Equatable, Sendable {
    public var version: Int = 1
    public var poems: [Poem] = []
    public var venues: [Venue] = []
    public var submissions: [Submission] = []
    public init() {}
    public func poem(_ id: UUID) -> Poem? { poems.first { $0.id == id } }
    public func venue(_ id: UUID) -> Venue? { venues.first { $0.id == id } }
    public func submissions(forPoem id: UUID) -> [Submission] { submissions.filter { $0.entries.contains { $0.poemID == id } } }
    public func submissions(forVenue id: UUID) -> [Submission] { submissions.filter { $0.venueID == id } }
    public func validate() throws {
        guard version == 1 else { throw LibraryError.invalid("This library was created by a newer version of Carmenta.") }
        guard Set(poems.map(\.id)).count == poems.count,
              Set(venues.map(\.id)).count == venues.count,
              Set(submissions.map(\.id)).count == submissions.count else {
            throw LibraryError.invalid("The library contains duplicate records.")
        }
        guard poems.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              venues.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw LibraryError.invalid("Poems and destinations need a name.")
        }
        for submission in submissions {
            guard venue(submission.venueID) != nil, !submission.entries.isEmpty,
                  Set(submission.entries.map(\.poemID)).count == submission.entries.count,
                  submission.entries.allSatisfy({ poem($0.poemID) != nil }) else {
                throw LibraryError.invalid("A submission must link an existing destination and at least one distinct poem.")
            }
            if let completed = submission.completedAt {
                guard !submission.isPending, Calendar.current.startOfDay(for: completed) >= Calendar.current.startOfDay(for: submission.sentAt) else {
                    throw LibraryError.invalid("The completion date must be on or after the sent date, with no poems pending.")
                }
            }
        }
    }
}

public enum LibraryError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}

public enum LibraryAccessError: LocalizedError {
    case changed, missing, downloading, cloudConflict

    public var errorDescription: String? {
        switch self {
        case .changed: return "The library changed outside Carmenta. Close any editor, then load the latest library before making changes."
        case .missing: return "The library file is missing. Wait for iCloud to sync, or choose its folder again. Carmenta won’t replace it with an empty library."
        case .downloading: return "iCloud hasn’t downloaded the latest library yet. Wait for it to finish, then try again."
        case .cloudConflict: return "iCloud reports conflicting versions of this library. Editing is paused. Preserve both versions and resolve the conflict before reopening the library."
        }
    }
}

/// Keeps the decoded records and the exact bytes they came from together.
public struct LibrarySnapshot: Sendable {
    public let library: Library
    public var isNew: Bool { data == nil }
    fileprivate let url: URL
    fileprivate let data: Data?
}

/// Backups live outside the shared folder and are never automatically removed.
public struct LibraryBackups: Sendable {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }

    public func preserve(_ data: Data) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let suffix = "-\(digest).json"
        // Opening an unchanged library doesn't need another identical backup.
        if try manager.contentsOfDirectory(atPath: directory.path).contains(where: { $0.hasSuffix(suffix) }) { return }
        let stamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")
        let name = "library-\(stamp)-\(UUID().uuidString)\(suffix)"
        try data.write(to: directory.appendingPathComponent(name), options: .atomic)
    }
}

public struct LibraryFile: Sendable {
    public let url: URL
    public init(url: URL) { self.url = url }

    public func load() throws -> Library {
        try snapshot().library
    }

    public func snapshot(allowMissing: Bool = true, backups: LibraryBackups? = nil) throws -> LibrarySnapshot {
        try coordinated(writing: false) { coordinatedURL in
            let data = try Self.readBytes(at: coordinatedURL)
            guard let data else {
                guard allowMissing else { throw LibraryAccessError.missing }
                return LibrarySnapshot(library: Library(), url: url, data: nil)
            }
            let library = try JSONDecoder().decode(Library.self, from: data)
            try library.validate()
            try backups?.preserve(data)
            return LibrarySnapshot(library: library, url: url, data: data)
        }
    }

    public func hasChanged(since snapshot: LibrarySnapshot) throws -> Bool {
        try coordinated(writing: false) { coordinatedURL in
            if snapshot.url != url { return true }
            return try Self.readBytes(at: coordinatedURL) != snapshot.data
        }
    }

    /// Export only. Editing an open library must use the checked save below.
    public func save(_ library: Library) throws {
        let data = try Self.encode(library)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try coordinated(writing: true) { try data.write(to: $0, options: .atomic) }
    }

    public func save(_ library: Library, replacing snapshot: LibrarySnapshot, backups: LibraryBackups) throws -> LibrarySnapshot {
        guard snapshot.url == url else { throw LibraryAccessError.changed }
        return try checkedSave(library, expected: snapshot.data, backups: backups)
    }

    /// Creates a library only if the destination still doesn't exist at write time.
    public func create(_ library: Library, backups: LibraryBackups) throws -> LibrarySnapshot {
        do { return try checkedSave(library, expected: nil, backups: backups) }
        catch LibraryAccessError.changed {
            throw LibraryError.invalid("That folder already contains a library. Use Open Shared Library Folder to open it, or choose a different folder for the copy.")
        }
    }

    private func checkedSave(_ library: Library, expected: Data?, backups: LibraryBackups) throws -> LibrarySnapshot {
        let data = try Self.encode(library)
        // The caller creates the local application-support directory. Never recreate
        // a missing shared folder here: it may have been moved or unshared.
        return try coordinated(writing: true) { coordinatedURL in
            let current = try Self.readBytes(at: coordinatedURL)
            guard current == expected else { throw LibraryAccessError.changed }
            if let current { try backups.preserve(current) }
            // Preserve the new version too, so a later iCloud overwrite cannot
            // erase this Mac's last edit. If writing fails, this remains a useful
            // recovery copy of the attempted save.
            try backups.preserve(data)
            try data.write(to: coordinatedURL, options: .atomic)
            return LibrarySnapshot(library: library, url: url, data: data)
        }
    }

    private static func encode(_ library: Library) throws -> Data {
        try library.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(library)
    }

    private static func isMissing(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == NSCocoaErrorDomain &&
            [NSFileReadNoSuchFileError, NSFileNoSuchFileError].contains(error.code)
    }

    private static func checkAvailability(at url: URL) throws {
        var url = url
        url.removeAllCachedResourceValues()
        let values: URLResourceValues
        do { values = try url.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]) }
        catch { if isMissing(error) { return }; throw error }
        if values.isUbiquitousItem == true {
            if let status = values.ubiquitousItemDownloadingStatus, status != .current {
                try FileManager.default.startDownloadingUbiquitousItem(at: url)
                throw LibraryAccessError.downloading
            }
            if !(NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? []).isEmpty {
                throw LibraryAccessError.cloudConflict
            }
        }
    }

    private static func readBytes(at url: URL) throws -> Data? {
        try checkAvailability(at: url)
        do { return try Data(contentsOf: url) }
        catch { if isMissing(error) { return nil }; throw error }
    }

    private func coordinated<T>(writing: Bool, _ body: (URL) throws -> T) throws -> T {
        // Check first so an evicted iCloud item requests a download without
        // blocking inside coordination. The accessor checks again before use.
        try Self.checkAvailability(at: url)
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var result: Result<T, Error>?
        let accessor: (URL) -> Void = { coordinatedURL in result = Result { try body(coordinatedURL) } }
        if writing {
            coordinator.coordinate(writingItemAt: url, options: [], error: &coordinationError, byAccessor: accessor)
        } else {
            coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError, byAccessor: accessor)
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw LibraryError.invalid("Carmenta couldn’t access the library. Please try again.") }
        return try result.get()
    }
}
