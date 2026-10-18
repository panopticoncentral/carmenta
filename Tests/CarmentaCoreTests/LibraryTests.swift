import XCTest
@testable import CarmentaCore

final class LibraryTests: XCTestCase {
    private func fixture() -> Library {
        var library = Library()
        library.poems = [Poem(title: "First poem"), Poem(title: "Second poem", stage: .ready)]
        library.venues = [Venue(name: "A journal"), Venue(name: "A prize", kind: .contest)]
        library.submissions = [Submission(venueID: library.venues[0].id, entries: library.poems.map { SubmissionEntry(poemID: $0.id) })]
        return library
    }

    private func temporaryFile() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("library.json")
    }

    func testLibraryRoundTripsWithRelationshipsAndResponses() throws {
        var library = fixture()
        library.submissions[0].entries[0].outcome = .accepted
        library.poems[0].notes = "Line one\nLine two — with punctuation."
        let file = LibraryFile(url: try temporaryFile())
        try file.save(library)
        let loaded = try file.load()
        XCTAssertEqual(loaded, library)
        XCTAssertEqual(loaded.submissions(forPoem: library.poems[0].id).count, 1)
        XCTAssertEqual(loaded.submissions(forVenue: library.venues[0].id).count, 1)
    }

    func testPartialAcceptanceStaysPendingUntilEveryPoemHasResponse() {
        var submission = fixture().submissions[0]
        submission.entries[0].outcome = .accepted
        XCTAssertTrue(submission.isPending)
        XCTAssertEqual(submission.outcome, .pending)
        submission.entries[1].outcome = .declined
        XCTAssertFalse(submission.isPending)
        XCTAssertEqual(submission.outcome, .accepted)
        submission.entries[0].outcome = .withdrawn
        XCTAssertEqual(submission.outcome, .declined)
        submission.entries[1].outcome = .withdrawn
        XCTAssertEqual(submission.outcome, .withdrawn)
    }

    func testSimultaneousSubmissionsAreAllowed() throws {
        var library = fixture()
        library.submissions.append(Submission(venueID: library.venues[1].id, entries: [SubmissionEntry(poemID: library.poems[0].id)]))
        XCTAssertNoThrow(try library.validate())
        XCTAssertEqual(library.submissions(forPoem: library.poems[0].id).count, 2)
    }

    func testDanglingRelationshipsAndDuplicateEntriesAreRejected() {
        var library = fixture()
        library.poems.removeFirst()
        XCTAssertThrowsError(try library.validate())
        library = fixture()
        library.venues.removeFirst()
        XCTAssertThrowsError(try library.validate())
        library = fixture()
        library.submissions[0].entries.append(library.submissions[0].entries[0])
        XCTAssertThrowsError(try library.validate())
        library = fixture()
        library.submissions[0].entries = []
        XCTAssertThrowsError(try library.validate())
    }

    func testCompletionDatesFollowSubmissionState() {
        var library = fixture()
        library.submissions[0].completedAt = .now
        XCTAssertThrowsError(try library.validate())
        library.submissions[0].entries = library.submissions[0].entries.map { SubmissionEntry(poemID: $0.poemID, outcome: .declined) }
        XCTAssertNoThrow(try library.validate())
        library.submissions[0].completedAt = .now.addingTimeInterval(-86_400)
        XCTAssertThrowsError(try library.validate())
    }

    func testEmptyNamesAndDuplicateRecordIDsAreRejected() {
        var library = fixture()
        library.poems[0].title = " \n "
        XCTAssertThrowsError(try library.validate())
        library = fixture()
        library.venues[0].name = " "
        XCTAssertThrowsError(try library.validate())
        library = fixture()
        library.poems.append(library.poems[0])
        XCTAssertThrowsError(try library.validate())
    }

    func testFailedValidationDoesNotOverwriteSavedLibrary() throws {
        let file = LibraryFile(url: try temporaryFile())
        let library = fixture()
        try file.save(library)
        let originalBytes = try Data(contentsOf: file.url)
        var invalid = library
        invalid.poems.removeAll()
        XCTAssertThrowsError(try file.save(invalid))
        XCTAssertEqual(try Data(contentsOf: file.url), originalBytes)
        XCTAssertEqual(try file.load(), library)
    }

    func testMissingFileStartsEmptyAndCorruptFileFailsWithoutModification() throws {
        let file = LibraryFile(url: try temporaryFile())
        XCTAssertEqual(try file.load(), Library())
        let invalidBytes = Data("this is not a library".utf8)
        try invalidBytes.write(to: file.url)
        XCTAssertThrowsError(try file.load())
        XCTAssertEqual(try Data(contentsOf: file.url), invalidBytes)
    }

    func testFutureSchemaIsRejected() throws {
        var library = fixture()
        library.version = 2
        let file = LibraryFile(url: try temporaryFile())
        try JSONEncoder().encode(library).write(to: file.url)
        XCTAssertThrowsError(try file.load())
    }

    func testWebsiteNormalizationAndUnsafeSchemes() {
        XCTAssertEqual(Venue(website: " example.org/poetry ").websiteURL?.absoluteString, "https://example.org/poetry")
        XCTAssertEqual(Venue(website: "https://example.org").websiteURL?.scheme, "https")
        XCTAssertNil(Venue(website: "").websiteURL)
        XCTAssertNil(Venue(website: "file:///tmp/example").websiteURL)
        XCTAssertNil(Venue(website: "javascript://example.org").websiteURL)
    }

    private func backups(for file: LibraryFile) -> LibraryBackups {
        LibraryBackups(directory: file.url.deletingLastPathComponent().appendingPathComponent("Backups"))
    }

    func testStaleWriterCannotOverwriteAnotherPersonsChanges() throws {
        let file = LibraryFile(url: try temporaryFile())
        try file.save(fixture())
        let paul = try file.snapshot(), anya = try file.snapshot()
        var anyasEdit = anya.library
        anyasEdit.poems[0].title = "Anya’s revision"
        let saved = try file.save(anyasEdit, replacing: anya, backups: backups(for: file))
        XCTAssertFalse(try file.hasChanged(since: saved))
        XCTAssertTrue(try file.hasChanged(since: paul))
        var paulsEdit = paul.library
        paulsEdit.poems[1].notes = "A later edit from an old copy"
        XCTAssertThrowsError(try file.save(paulsEdit, replacing: paul, backups: backups(for: file))) {
            guard case LibraryAccessError.changed = $0 else { return XCTFail("Expected a conflict, got \($0)") }
        }
        XCTAssertEqual(try file.load(), anyasEdit)
        // Explicit reload gives the second person a new, safe starting point.
        let reloaded = try file.snapshot()
        paulsEdit = reloaded.library
        paulsEdit.poems[1].notes = "Now applied to the latest library"
        _ = try file.save(paulsEdit, replacing: reloaded, backups: backups(for: file))
        XCTAssertEqual(try file.load().poems[0].title, "Anya’s revision")
    }

    func testDetectsChangedBytesEvenWhenModificationDateIsUnchanged() throws {
        let file = LibraryFile(url: try temporaryFile())
        try file.save(fixture())
        let snapshot = try file.snapshot()
        let date = try XCTUnwrap(FileManager.default.attributesOfItem(atPath: file.url.path)[.modificationDate])
        var modified = snapshot.library
        modified.poems[0].notes = "Changed by sync"
        try file.save(modified)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: file.url.path)
        XCTAssertTrue(try file.hasChanged(since: snapshot))
    }

    func testDeletionAndCorruptionCannotBeOverwrittenByAnOpenLibrary() throws {
        let file = LibraryFile(url: try temporaryFile())
        try file.save(fixture())
        let snapshot = try file.snapshot()
        try FileManager.default.removeItem(at: file.url)
        XCTAssertTrue(try file.hasChanged(since: snapshot))
        XCTAssertThrowsError(try file.save(snapshot.library, replacing: snapshot, backups: backups(for: file)))
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.url.path))
        let corrupt = Data("incomplete sync".utf8)
        try corrupt.write(to: file.url)
        XCTAssertThrowsError(try file.snapshot(allowMissing: false))
        XCTAssertThrowsError(try file.save(snapshot.library, replacing: snapshot, backups: backups(for: file)))
        XCTAssertEqual(try Data(contentsOf: file.url), corrupt)
    }

    func testSharedOpenRequiresExistingLibraryAndCreateNeverReplacesOne() throws {
        let file = LibraryFile(url: try temporaryFile())
        XCTAssertThrowsError(try file.snapshot(allowMissing: false))
        let emptySnapshot = try file.snapshot()
        let existing = fixture()
        _ = try file.create(existing, backups: backups(for: file))
        XCTAssertThrowsError(try file.create(Library(), backups: backups(for: file)))
        XCTAssertThrowsError(try file.save(Library(), replacing: emptySnapshot, backups: backups(for: file)))
        XCTAssertEqual(try file.load(), existing)
    }

    func testBackupsPreservePreviousAndNewVersionsWithoutDuplicateCopies() throws {
        let file = LibraryFile(url: try temporaryFile())
        let original = fixture()
        // Keep a compactly encoded source to check that backups preserve exact bytes.
        let bytes = try JSONEncoder().encode(original)
        try bytes.write(to: file.url)
        let backups = backups(for: file)
        let snapshot = try file.snapshot(backups: backups)
        _ = try file.snapshot(backups: backups)
        let originals = try FileManager.default.contentsOfDirectory(at: backups.directory, includingPropertiesForKeys: nil)
        XCTAssertEqual(originals.count, 1)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(originals.first)), bytes)
        var edited = original
        edited.poems[0].notes = "Updated"
        _ = try file.save(edited, replacing: snapshot, backups: backups)
        var files = try FileManager.default.contentsOfDirectory(at: backups.directory, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 2)
        let versions = try files.map { try LibraryFile(url: $0).load() }
        XCTAssertTrue(versions.contains(original))
        XCTAssertTrue(versions.contains(edited), "The most recent edit must be recoverable even before the next launch.")
        _ = try file.snapshot(backups: backups)
        files = try FileManager.default.contentsOfDirectory(at: backups.directory, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 2)
        XCTAssertTrue(try files.map { try LibraryFile(url: $0).load() }.contains(edited))
    }

    func testBackupFailureAbortsSaveWithoutChangingLibrary() throws {
        let file = LibraryFile(url: try temporaryFile())
        try file.save(fixture())
        let snapshot = try file.snapshot()
        let original = try Data(contentsOf: file.url)
        let blockedDirectory = file.url.deletingLastPathComponent().appendingPathComponent("not-a-directory")
        try Data("occupied".utf8).write(to: blockedDirectory)
        var edited = snapshot.library
        edited.poems[0].title = "Must not be written"
        XCTAssertThrowsError(try file.save(edited, replacing: snapshot, backups: LibraryBackups(directory: blockedDirectory)))
        XCTAssertEqual(try Data(contentsOf: file.url), original)
    }

    func testSnapshotFromAnotherLibraryCannotAuthorizeSave() throws {
        let first = LibraryFile(url: try temporaryFile()), second = LibraryFile(url: try temporaryFile())
        let library = fixture()
        try first.save(library)
        try second.save(library)
        XCTAssertThrowsError(try second.save(Library(), replacing: first.snapshot(), backups: backups(for: second)))
        XCTAssertEqual(try second.load(), library)
    }

    func testConcurrentCoordinatedWritersAllowOnlyOneSaveFromSameSnapshot() throws {
        let file = LibraryFile(url: try temporaryFile())
        try file.save(fixture())
        let snapshot = try file.snapshot(), backups = backups(for: file)
        let saved = expectation(description: "One writer saves")
        let rejected = expectation(description: "The other writer sees a conflict")
        for title in ["First writer", "Second writer"] {
            DispatchQueue.global().async {
                var edited = snapshot.library
                edited.poems[0].title = title
                do {
                    _ = try file.save(edited, replacing: snapshot, backups: backups)
                    saved.fulfill()
                } catch LibraryAccessError.changed { rejected.fulfill() }
                catch { XCTFail("Unexpected save failure: \(error)") }
            }
        }
        wait(for: [saved, rejected], timeout: 10)
        XCTAssertTrue(["First writer", "Second writer"].contains(try file.load().poems[0].title))
    }
}
