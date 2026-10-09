import SwiftUI
import CarmentaCore

private enum SubmissionFilter: String, CaseIterable, Identifiable {
    case all = "All", pending = "Pending", completed = "Completed"
    var id: Self { self }
}

struct SubmissionsView: View {
    @Environment(LibraryStore.self) private var store
    @Binding var editor: Editor?
    @State private var search = ""
    @State private var filter: SubmissionFilter = .all
    @State private var selected: UUID?
    @State private var deleting: Submission?
    private var submissions: [Submission] {
        store.library.submissions.filter { submission in
            (filter == .all || (filter == .pending ? submission.isPending : !submission.isPending)) &&
            (search.isEmpty || (store.library.venue(submission.venueID)?.name.localizedCaseInsensitiveContains(search) ?? false) || submission.entries.contains { store.library.poem($0.poemID)?.title.localizedCaseInsensitiveContains(search) ?? false })
        }.sorted { $0.sentAt > $1.sentAt }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                PageHeading(eyebrow: "The journey of your work", title: "Submissions", subtitle: "Every send, every wait, every answer.")
                Spacer()
                Button { editor = .submission(nil) } label: { Label("New submission", systemImage: "plus") }.buttonStyle(.borderedProminent)
            }.padding(.horizontal, 30).padding(.top, 30)
            if store.library.submissions.isEmpty {
                EmptyState(icon: "paperplane", title: "Let your work go places", description: "Connect poems to a journal or contest, then keep track of responses as they arrive.", actionTitle: "Record a submission") { editor = .submission(nil) }
            } else {
                HSplitView {
                    VStack(spacing: 14) {
                        SearchField(text: $search, prompt: "Find a poem or destination…")
                        Picker("Status", selection: $filter) { ForEach(SubmissionFilter.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).labelsHidden()
                        if submissions.isEmpty { EmptyState(icon: "tray", title: "Nothing here yet", description: "Try a different search or status.") }
                        else {
                            List(submissions, selection: $selected) { submission in
                                VStack(alignment: .leading, spacing: 9) {
                                    Text(store.library.venue(submission.venueID)?.name ?? "Destination").font(.system(size: 17, design: .serif)).lineLimit(2)
                                    Text(submission.entries.compactMap { store.library.poem($0.poemID)?.title }.joined(separator: " · ")).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                                    HStack {
                                        Badge(text: submission.outcome.rawValue, color: submission.outcome.color)
                                        Spacer()
                                        Text(submission.sentAt.formatted(.dateTime.month(.abbreviated).day().year())).font(.system(size: 10)).foregroundStyle(.secondary)
                                    }
                                }.padding(.vertical, 9).tag(submission.id)
                                    .contextMenu { Button("Edit…") { editor = .submission(submission) }; Button("Delete…", role: .destructive) { deleting = submission } }
                            }.listStyle(.inset).scrollContentBackground(.hidden)
                        }
                        Text("\(submissions.count) \(submissions.count == 1 ? "submission" : "submissions")").font(.system(size: 11)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(.leading, 24).padding(.trailing, 16).padding(.bottom, 20).frame(minWidth: 280, idealWidth: 340, maxWidth: 420)
                    if let submission = submissions.first(where: { $0.id == selected }) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 26) {
                                HStack { Badge(text: submission.outcome.rawValue, color: submission.outcome.color); Spacer(); Button("Edit / record response") { editor = .submission(submission) } }
                                Text(store.library.venue(submission.venueID)?.name ?? "Destination").font(.system(size: 32, design: .serif))
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Sent \(submission.sentAt.formatted(date: .long, time: .omitted))", systemImage: "paperplane")
                                    if let completed = submission.completedAt { Label("Completed \(completed.formatted(date: .long, time: .omitted))", systemImage: "checkmark.circle") }
                                }.font(.system(size: 12)).foregroundStyle(.secondary)
                                Divider()
                                DetailSection(title: "Included poems") {
                                    ForEach(submission.entries) { entry in
                                        HStack {
                                            Button { if let poem = store.library.poem(entry.poemID) { editor = .poem(poem) } } label: {
                                                Text(store.library.poem(entry.poemID)?.title ?? "Poem").font(.system(size: 17, design: .serif)).multilineTextAlignment(.leading)
                                            }.buttonStyle(.plain)
                                            Spacer()
                                            Badge(text: entry.outcome.rawValue, color: entry.outcome.color)
                                        }.padding(14).background(Palette.card, in: RoundedRectangle(cornerRadius: 10))
                                    }
                                    if submission.isPending && submission.entries.contains(where: { $0.outcome != .pending }) {
                                        Text("Some poems have a response. This submission stays pending until every poem has an outcome.").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                NotesView(notes: submission.notes)
                                if let venue = store.library.venue(submission.venueID) {
                                    Button { editor = .venue(venue) } label: { Label("Destination details", systemImage: "books.vertical") }
                                }
                                Button("Delete submission…", role: .destructive) { deleting = submission }.buttonStyle(.borderless).font(.caption).padding(.top, 12)
                            }.padding(28)
                        }.frame(minWidth: 310, maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        EmptyState(icon: "envelope.open", title: "Follow your work", description: "Select a submission to see its poems or record a response.").frame(minWidth: 310)
                    }
                }
            }
        }
        .alert("Delete this submission?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Cancel", role: .cancel) { deleting = nil }
            Button("Delete", role: .destructive) { if let submission = deleting { store.deleteSubmission(submission.id) }; deleting = nil }
        } message: { Text("This submission record will be permanently removed. Its poems and destination will remain in your library.") }
    }
}
