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
}
