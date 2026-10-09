import SwiftUI
import CarmentaCore

struct EditorFrame<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LibraryStore.self) private var store
    let title: String
    let subtitle: String
    var canSave = true
    let save: () -> Void
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.system(size: 27, design: .serif))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(26)
            Divider()
            content()
            if let error = store.error { Text(error).font(.caption).foregroundStyle(.red).padding(.horizontal, 24).padding(.bottom, 12) }
            Divider()
            HStack {
                Text(store.isDemo ? "Sample library · not saved" : "Saved privately on this Mac").font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save", action: save).buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(!canSave)
            }.padding(20)
        }.frame(width: 590).onAppear { store.error = nil }
    }
}

struct PoemEditor: View {
    @Environment(LibraryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var poem: Poem
    @FocusState private var titleFocused: Bool
    var body: some View {
        EditorFrame(title: store.library.poem(poem.id) == nil ? "A new poem" : "Your poem", subtitle: "A title, a stage, and anything you want to remember.", canSave: !poem.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
            if store.save(poem) { dismiss() }
        } content: {
            Form {
                SwiftUI.Section {
                    TextField("Title", text: $poem.title, prompt: Text("Untitled poem")).focused($titleFocused)
                    Picker("Stage", selection: $poem.stage) { ForEach(PoemStage.allCases) { Text($0.rawValue).tag($0) } }
                }
                SwiftUI.Section {
                    TextEditor(text: $poem.notes).font(.body).frame(minHeight: 150).accessibilityLabel("Poem notes")
                } header: { Text("Notes") } footer: { Text("Use this space for revision ideas or context. Your poem can live wherever you write.") }
            }.formStyle(.grouped).frame(height: 360)
        }.onAppear { titleFocused = true }
    }
}

struct VenueEditor: View {
    @Environment(LibraryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var venue: Venue
    @FocusState private var nameFocused: Bool
    private var valid: Bool {
        !venue.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (venue.website.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || venue.websiteURL != nil)
    }
    var body: some View {
        EditorFrame(title: store.library.venue(venue.id) == nil ? "A place for your work" : "Destination details", subtitle: "Keep the details that will help you choose where to send.", canSave: valid) {
            if store.save(venue) { dismiss() }
        } content: {
            Form {
                SwiftUI.Section {
                    TextField("Name", text: $venue.name).focused($nameFocused)
                    Picker("Type", selection: $venue.kind) { ForEach(VenueKind.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                    TextField("Website", text: $venue.website, prompt: Text("example.org"))
                    if !venue.website.isEmpty && venue.websiteURL == nil { Text("Enter a valid http or https website address.").font(.caption).foregroundStyle(.red) }
                }
                SwiftUI.Section {
                    Toggle("Track a deadline", isOn: Binding(get: { venue.deadline != nil }, set: { venue.deadline = $0 ? .now : nil }))
                    if venue.deadline != nil {
                        DatePicker("Deadline", selection: Binding(get: { venue.deadline ?? .now }, set: { venue.deadline = $0 }), displayedComponents: .date)
                    }
                }
                SwiftUI.Section {
                    TextEditor(text: $venue.notes).font(.body).frame(minHeight: 105).accessibilityLabel("Destination notes and guidelines")
                } header: { Text("Notes & guidelines") } footer: { Text("Reading periods, entry fees, poem limits, preferences—anything useful for later.") }
            }.formStyle(.grouped).frame(height: 425)
        }.onAppear { nameFocused = true }
    }
}

struct SubmissionEditor: View {
    @Environment(LibraryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var submission: Submission
    @State private var quickEditor: Editor?
    @State private var poemSearch = ""
    init(submission: Submission?) {
        _submission = State(initialValue: submission ?? Submission(venueID: UUID()))
    }
    private var valid: Bool {
        store.library.venue(submission.venueID) != nil && !submission.entries.isEmpty &&
        (submission.completedAt == nil || Calendar.current.startOfDay(for: submission.completedAt!) >= Calendar.current.startOfDay(for: submission.sentAt))
    }
    private var poems: [Poem] {
        store.library.poems.filter { poemSearch.isEmpty || $0.title.localizedCaseInsensitiveContains(poemSearch) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }
    var body: some View {
        EditorFrame(title: store.library.submissions.contains(where: { $0.id == submission.id }) ? "Submission details" : "Send your work into the world", subtitle: "Link a destination and poems, then record each response.", canSave: valid) {
            if submission.isPending { submission.completedAt = nil }
            if store.save(submission) { dismiss() }
        } content: {
            Form {
                SwiftUI.Section {
                    if store.library.venues.isEmpty {
                        Text("First, add a journal or contest to send your poems to.").foregroundStyle(.secondary)
                    } else {
                        Picker("Destination", selection: $submission.venueID) {
                            ForEach(store.library.venues.sorted { $0.name < $1.name }) { Text($0.name).tag($0.id) }
                        }
                    }
                    Button("Add a journal or contest…") { quickEditor = .venue(Venue()) }.font(.caption)
                    DatePicker("Sent", selection: $submission.sentAt, in: ...Date.now, displayedComponents: .date)
                }
                SwiftUI.Section {
                    if store.library.poems.isEmpty {
                        Text("Add your first poem to include it in this submission.").foregroundStyle(.secondary)
                    } else {
                        if store.library.poems.count > 6 { TextField("Find a poem", text: $poemSearch) }
                        ForEach(poems) { poem in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Toggle(isOn: Binding(get: { submission.entries.contains { $0.poemID == poem.id } }, set: { included in
                                        if included { submission.entries.append(SubmissionEntry(poemID: poem.id)); submission.completedAt = nil }
                                        else { submission.entries.removeAll { $0.poemID == poem.id } }
                                    })) { Text(poem.title).lineLimit(2) }.toggleStyle(.checkbox)
                                    Spacer()
                                    if submission.entries.contains(where: { $0.poemID == poem.id }) {
                                        Picker("Outcome for \(poem.title)", selection: Binding(get: { submission.entries.first { $0.poemID == poem.id }?.outcome ?? .pending }, set: { outcome in
                                            if let index = submission.entries.firstIndex(where: { $0.poemID == poem.id }) { submission.entries[index].outcome = outcome }
                                            if submission.isPending { submission.completedAt = nil }
                                        })) { ForEach(Outcome.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(width: 120)
                                    }
                                }
                                if submission.entries.contains(where: { $0.poemID == poem.id }), hasOtherPendingSubmission(poem.id) {
                                    Label("Also pending at another destination", systemImage: "info.circle").font(.system(size: 10)).foregroundStyle(.secondary).padding(.leading, 20)
                                }
                            }.padding(.vertical, 3)
                        }
                    }
                    Button("Add a new poem…") { quickEditor = .poem(Poem()) }.font(.caption)
                } header: { Text("Poems · \(submission.entries.count) selected") }
                  footer: { Text("A submission remains pending while any of its poems are awaiting a response.") }
                if !submission.entries.isEmpty && !submission.isPending {
                    SwiftUI.Section {
                        Toggle("Record a completion date", isOn: Binding(get: { submission.completedAt != nil }, set: { submission.completedAt = $0 ? max(.now, submission.sentAt) : nil }))
                        if submission.completedAt != nil {
                            DatePicker("Completed", selection: Binding(get: { submission.completedAt ?? .now }, set: { submission.completedAt = $0 }), in: Calendar.current.startOfDay(for: submission.sentAt)...Date.now, displayedComponents: .date)
                            if !valid { Text("Completion cannot be before the sent date.").font(.caption).foregroundStyle(.red) }
                        }
                    }
                }
                SwiftUI.Section("Notes") {
                    TextEditor(text: $submission.notes).font(.body).frame(minHeight: 75).accessibilityLabel("Submission notes")
                }
            }.formStyle(.grouped).frame(height: 450)
        }
        .onAppear { selectDestinationIfNeeded() }
        .onChange(of: store.library.venues) { _, _ in selectDestinationIfNeeded() }
        .sheet(item: $quickEditor) { editor in
            switch editor {
            case .poem(let poem): PoemEditor(poem: poem)
            case .venue(let venue): VenueEditor(venue: venue)
            case .submission: EmptyView()
            }
        }
    }
    private func selectDestinationIfNeeded() {
        if store.library.venue(submission.venueID) == nil, let first = store.library.venues.first { submission.venueID = first.id }
    }
    private func hasOtherPendingSubmission(_ id: UUID) -> Bool {
        store.library.submissions.contains { $0.id != submission.id && $0.entries.contains { $0.poemID == id && $0.outcome == .pending } }
    }
}
