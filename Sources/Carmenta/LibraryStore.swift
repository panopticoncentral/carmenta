import AppKit
import Observation
import CarmentaCore
import CryptoKit

@MainActor @Observable
final class LibraryStore {
    private(set) var library = Library()
    private(set) var loadError: String?
    private(set) var syncIssue: String?
    private(set) var isBusy = false
    private(set) var isShared = false
    var error: String?
    var editorCount = 0
    let isDemo: Bool
    private(set) var file: LibraryFile
    private var snapshot: LibrarySnapshot?
    private var accessError: String?
    @ObservationIgnored private var scopedFolder: URL?
    @ObservationIgnored private var isChecking = false
    @ObservationIgnored private var generation = UUID()
    private let localURL: URL
    private let backupsRoot: URL
    private static let bookmarkKey = "sharedLibraryFolderBookmark"

    var canEdit: Bool { !isBusy && loadError == nil && syncIssue == nil && (isDemo || snapshot != nil) }
    var canSwitchLibrary: Bool { !isBusy && editorCount == 0 && !isDemo }
    var locationLabel: String { isDemo ? "Sample library" : (isShared ? "Shared folder library" : "Saved on this Mac") }
    var backupDirectory: URL { backups(for: file).directory }

    init(demo: Bool = CommandLine.arguments.contains("--demo")) {
        isDemo = demo
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        localURL = directory.appendingPathComponent("Carmenta/library.json")
        backupsRoot = directory.appendingPathComponent("Carmenta/Backups", isDirectory: true)
        file = LibraryFile(url: localURL)
        if demo { library = .sample; return }
        if let bookmark = UserDefaults.standard.data(forKey: Self.bookmarkKey) {
            isShared = true
            do {
                var stale = false
                let folder = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI], bookmarkDataIsStale: &stale)
                if folder.startAccessingSecurityScopedResource() { scopedFolder = folder }
                file = LibraryFile(url: folder.appendingPathComponent("library.json"))
                if stale {
                    let refreshed = try folder.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                    UserDefaults.standard.set(refreshed, forKey: Self.bookmarkKey)
                }
            } catch {
                accessError = "Access to your shared folder couldn’t be restored. Choose Open Shared Library Folder again. \(error.localizedDescription)"
                loadError = accessError
            }
        }
    }

    deinit { scopedFolder?.stopAccessingSecurityScopedResource() }

    private func backups(for file: LibraryFile) -> LibraryBackups {
        let identifier = SHA256.hash(data: Data(file.url.standardizedFileURL.path.utf8)).map { String(format: "%02x", $0) }.joined()
        return LibraryBackups(directory: backupsRoot.appendingPathComponent(identifier, isDirectory: true))
    }

    func reload() async {
        guard !isDemo, !isBusy, editorCount == 0, accessError == nil else { return }
        isBusy = true
        defer { isBusy = false }
        let file = file, backups = backups(for: file)
        let allowMissing = !isShared && (snapshot == nil || snapshot?.isNew == true)
        let isLocal = !isShared
        do {
            let loaded = try await Task.detached {
                if isLocal { try FileManager.default.createDirectory(at: file.url.deletingLastPathComponent(), withIntermediateDirectories: true) }
                return try file.snapshot(allowMissing: allowMissing, backups: backups)
            }.value
            accept(loaded)
        }
        catch { loadError = error.localizedDescription }
    }

    private func accept(_ loaded: LibrarySnapshot) {
        generation = UUID()
        snapshot = loaded
        library = loaded.library
        loadError = nil
        syncIssue = nil
        error = nil
    }

    func checkForExternalChanges() async {
        guard !isDemo, !isBusy, !isChecking, loadError == nil, syncIssue == nil, let snapshot else { return }
        isChecking = true
        defer { isChecking = false }
        let file = file, generation = generation
        do {
            let changed = try await Task.detached(operation: { try file.hasChanged(since: snapshot) }).value
            // A save or folder switch may have completed while the check ran.
            guard generation == self.generation, !isBusy else { return }
            if changed {
                syncIssue = LibraryAccessError.changed.localizedDescription
            }
        } catch {
            guard generation == self.generation, !isBusy else { return }
            syncIssue = error.localizedDescription
        }
    }

    func chooseSharedFolder(create: Bool) async {
        guard canSwitchLibrary, !create || canEdit else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = create
        panel.prompt = create ? "Create Library Here" : "Open Library"
        panel.message = create
            ? "Choose an empty folder in iCloud Drive. Carmenta will copy your current library there. Share the folder with editing permission in Finder, then have the other person open it in Carmenta."
            : "Choose the shared iCloud Drive folder containing library.json. Wait for syncing to finish before opening it."
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        isBusy = true
        defer { isBusy = false }
        let didAccess = folder.startAccessingSecurityScopedResource()
        var adopted = false
        defer { if didAccess && !adopted { folder.stopAccessingSecurityScopedResource() } }
        do {
            let bookmark = try folder.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            let candidate = LibraryFile(url: folder.appendingPathComponent("library.json"))
            let backups = backups(for: candidate)
            let current = library, source = file, sourceSnapshot = snapshot
            let loaded = try await Task.detached {
                if create {
                    guard let sourceSnapshot, try !source.hasChanged(since: sourceSnapshot) else { throw LibraryAccessError.changed }
                    return try candidate.create(current, backups: backups)
                }
                return try candidate.snapshot(allowMissing: false, backups: backups)
            }.value
            scopedFolder?.stopAccessingSecurityScopedResource()
            scopedFolder = didAccess ? folder : nil
            adopted = true
            file = candidate
            isShared = true
            accessError = nil
            UserDefaults.standard.set(bookmark, forKey: Self.bookmarkKey)
            accept(loaded)
        } catch { self.error = error.localizedDescription }
    }

    func useLocalLibrary() async {
        guard canSwitchLibrary else { return }
        isBusy = true
        defer { isBusy = false }
        let candidate = LibraryFile(url: localURL), backups = backups(for: LibraryFile(url: localURL))
        do {
            let loaded = try await Task.detached {
                try FileManager.default.createDirectory(at: candidate.url.deletingLastPathComponent(), withIntermediateDirectories: true)
                return try candidate.snapshot(backups: backups)
            }.value
            scopedFolder?.stopAccessingSecurityScopedResource()
            scopedFolder = nil
            file = candidate
            isShared = false
            accessError = nil
            UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
            accept(loaded)
        } catch { self.error = error.localizedDescription }
    }

    func showBackups() {
        do {
            try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
            NSWorkspace.shared.open(backupDirectory)
        } catch { self.error = error.localizedDescription }
    }

    @discardableResult
    func change(_ edit: (inout Library) -> Void) async -> Bool {
        guard canEdit else { return false }
        isBusy = true
        defer { isBusy = false }
        var next = library
        edit(&next)
        do {
            try next.validate()
            if !isDemo {
                guard let snapshot else { return false }
                let file = file, backups = backups(for: file), updated = next
                self.snapshot = try await Task.detached { try file.save(updated, replacing: snapshot, backups: backups) }.value
                generation = UUID()
            }
            library = next
            error = nil
            return true
        } catch {
            if error is LibraryAccessError { syncIssue = error.localizedDescription }
            self.error = error.localizedDescription
            return false
        }
    }

    func save(_ poem: Poem) async -> Bool {
        var poem = poem
        poem.title = poem.title.trimmingCharacters(in: .whitespacesAndNewlines)
        poem.updatedAt = .now
        return await change { library in
            if let index = library.poems.firstIndex(where: { $0.id == poem.id }) { library.poems[index] = poem }
            else { library.poems.append(poem) }
        }
    }

    func save(_ venue: Venue) async -> Bool {
        var venue = venue
        venue.name = venue.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return await change { library in
            if let index = library.venues.firstIndex(where: { $0.id == venue.id }) { library.venues[index] = venue }
            else { library.venues.append(venue) }
        }
    }

    func save(_ submission: Submission) async -> Bool {
        await change { library in
            if let index = library.submissions.firstIndex(where: { $0.id == submission.id }) { library.submissions[index] = submission }
            else { library.submissions.append(submission) }
        }
    }

    func deletePoem(_ id: UUID) {
        guard library.submissions(forPoem: id).isEmpty else {
            error = "This poem belongs to a submission. Remove it from its submissions before deleting it."
            return
        }
        Task { await change { $0.poems.removeAll { $0.id == id } } }
    }

    func deleteVenue(_ id: UUID) {
        guard library.submissions(forVenue: id).isEmpty else {
            error = "This destination has submission history. Delete those submissions before deleting the destination."
            return
        }
        Task { await change { $0.venues.removeAll { $0.id == id } } }
    }

    func deleteSubmission(_ id: UUID) { Task { await change { $0.submissions.removeAll { $0.id == id } } } }

    func exportLibrary() async {
        guard !isBusy else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Carmenta Library.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard url.resolvingSymlinksInPath().standardizedFileURL != file.url.resolvingSymlinksInPath().standardizedFileURL else {
            error = "Choose a different filename for the export so your open library stays protected."
            return
        }
        isBusy = true
        defer { isBusy = false }
        let current = library
        do { try await Task.detached { try LibraryFile(url: url).save(current) }.value }
        catch { self.error = error.localizedDescription }
    }
}

extension Library {
    static var sample: Library {
        var library = Library()
        let titles = ["The shape of returning", "Small hours", "What the garden keeps", "Instructions for rain", "A room facing west", "After the last ferry"]
        let stages: [PoemStage] = [.ready, .revising, .ready, .draft, .published, .ready]
        library.poems = zip(titles, stages).enumerated().map { index, pair in
            Poem(title: pair.0, stage: pair.1, notes: index == 0 ? "A poem about the places we carry with us. Revisit the final image before the next round of submissions." : "", createdAt: Date.now.addingTimeInterval(Double(-index - 10) * 86_400))
        }
        library.venues = [
            Venue(name: "Fieldnotes Review", website: "", deadline: .now.addingTimeInterval(12 * 86_400), notes: "Fictional sample journal. Intimate poems, close observation, and a strong sense of place."),
            Venue(name: "The Stillwater Poetry Prize", kind: .contest, deadline: .now.addingTimeInterval(28 * 86_400), notes: "Fictional sample contest. Up to three poems per entry."),
            Venue(name: "Lantern Quarterly", notes: "Fictional sample journal. Read the latest issue before sending."),
            Venue(name: "Orchard & Sky", notes: "Fictional sample journal.")
        ]
        library.submissions = [
            Submission(venueID: library.venues[0].id, entries: [SubmissionEntry(poemID: library.poems[0].id), SubmissionEntry(poemID: library.poems[2].id)], sentAt: .now.addingTimeInterval(-18 * 86_400)),
            Submission(venueID: library.venues[2].id, entries: [SubmissionEntry(poemID: library.poems[5].id)], sentAt: .now.addingTimeInterval(-32 * 86_400)),
            Submission(venueID: library.venues[3].id, entries: [SubmissionEntry(poemID: library.poems[4].id, outcome: .accepted)], sentAt: .now.addingTimeInterval(-60 * 86_400), completedAt: .now.addingTimeInterval(-9 * 86_400))
        ]
        return library
    }
}
