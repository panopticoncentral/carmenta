import Foundation

public enum PoemStage: String, Codable, CaseIterable, Identifiable {
    case draft = "Draft", revising = "Revising", ready = "Ready to submit", published = "Published"
    public var id: String { rawValue }
}

public enum VenueKind: String, Codable, CaseIterable, Identifiable {
    case journal = "Journal", contest = "Contest"
    public var id: String { rawValue }
}

public enum Outcome: String, Codable, CaseIterable, Identifiable {
    case pending = "Pending", accepted = "Accepted", declined = "Declined", withdrawn = "Withdrawn"
    public var id: String { rawValue }
}

public struct Poem: Identifiable, Codable, Equatable {
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

public struct Venue: Identifiable, Codable, Equatable {
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

public struct SubmissionEntry: Identifiable, Codable, Equatable {
    public var poemID: UUID
    public var outcome: Outcome
    public var id: UUID { poemID }
    public init(poemID: UUID, outcome: Outcome = .pending) {
        self.poemID = poemID; self.outcome = outcome
    }
}

public struct Submission: Identifiable, Codable, Equatable {
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

public struct Library: Codable, Equatable {
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

public struct LibraryFile {
    public let url: URL
    public init(url: URL) { self.url = url }
    public func load() throws -> Library {
        guard FileManager.default.fileExists(atPath: url.path) else { return Library() }
        let library = try JSONDecoder().decode(Library.self, from: Data(contentsOf: url))
        try library.validate()
        return library
    }
    public func save(_ library: Library) throws {
        try library.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(library)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
