import AppKit
import Observation
import CarmentaCore

@MainActor @Observable
final class LibraryStore {
    private(set) var library = Library()
    private(set) var loadError: String?
    var error: String?
    let isDemo: Bool
    let file: LibraryFile

    init(demo: Bool = CommandLine.arguments.contains("--demo")) {
        isDemo = demo
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        file = LibraryFile(url: directory.appendingPathComponent("Carmenta/library.json"))
        if demo { library = .sample } else { reload() }
    }

    func reload() {
        do { library = try file.load(); loadError = nil }
        catch { loadError = error.localizedDescription }
    }

    @discardableResult
    func change(_ edit: (inout Library) -> Void) -> Bool {
        guard loadError == nil else { return false }
        var next = library
        edit(&next)
        do {
            try next.validate()
            if !isDemo { try file.save(next) }
            library = next
            error = nil
            return true
        } catch { self.error = error.localizedDescription; return false }
    }

    func save(_ poem: Poem) -> Bool {
        var poem = poem
        poem.title = poem.title.trimmingCharacters(in: .whitespacesAndNewlines)
        poem.updatedAt = .now
        return change { library in
            if let index = library.poems.firstIndex(where: { $0.id == poem.id }) { library.poems[index] = poem }
            else { library.poems.append(poem) }
        }
    }

    func save(_ venue: Venue) -> Bool {
        var venue = venue
        venue.name = venue.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return change { library in
            if let index = library.venues.firstIndex(where: { $0.id == venue.id }) { library.venues[index] = venue }
            else { library.venues.append(venue) }
        }
    }

    func save(_ submission: Submission) -> Bool {
        change { library in
            if let index = library.submissions.firstIndex(where: { $0.id == submission.id }) { library.submissions[index] = submission }
            else { library.submissions.append(submission) }
        }
    }

    func deletePoem(_ id: UUID) {
        guard library.submissions(forPoem: id).isEmpty else {
            error = "This poem belongs to a submission. Remove it from its submissions before deleting it."
            return
        }
        change { $0.poems.removeAll { $0.id == id } }
    }

    func deleteVenue(_ id: UUID) {
        guard library.submissions(forVenue: id).isEmpty else {
            error = "This destination has submission history. Delete those submissions before deleting the destination."
            return
        }
        change { $0.venues.removeAll { $0.id == id } }
    }

    func deleteSubmission(_ id: UUID) { change { $0.submissions.removeAll { $0.id == id } } }

    func exportLibrary() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Carmenta Library.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try LibraryFile(url: url).save(library) }
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
