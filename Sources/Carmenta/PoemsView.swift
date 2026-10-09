import SwiftUI
import CarmentaCore

struct PoemsView: View {
    @Environment(LibraryStore.self) private var store
    @Binding var editor: Editor?
    @State private var search = ""
    @State private var stage: PoemStage?
    @State private var selected: UUID?
    @State private var deleting: Poem?
    @State private var sortByTitle = false
    private var poems: [Poem] {
        store.library.poems.filter { (stage == nil || $0.stage == stage) && (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.notes.localizedCaseInsensitiveContains(search)) }
            .sorted { sortByTitle ? $0.title.localizedStandardCompare($1.title) == .orderedAscending : $0.updatedAt > $1.updatedAt }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                PageHeading(eyebrow: "Your collection", title: "Poems", subtitle: "From a first thought to a finished piece.")
                Spacer()
                Button { editor = .poem(Poem()) } label: { Label("New poem", systemImage: "plus") }.buttonStyle(.borderedProminent)
            }.padding(.horizontal, 30).padding(.top, 30)
            if store.library.poems.isEmpty {
                EmptyState(icon: "doc.text", title: "Make room for your words", description: "Keep a record of each poem, where it stands, and what you want to remember.", actionTitle: "Add a poem") { editor = .poem(Poem()) }
            } else {
                HSplitView {
                    VStack(spacing: 14) {
                        SearchField(text: $search, prompt: "Find a poem…")
                        HStack {
                            Picker("Stage", selection: $stage) {
                                Text("All stages").tag(nil as PoemStage?)
                                ForEach(PoemStage.allCases) { Text($0.rawValue).tag(Optional($0)) }
                            }.labelsHidden().frame(maxWidth: .infinity)
                            Menu { Toggle("Sort alphabetically", isOn: $sortByTitle) } label: { Image(systemName: "arrow.up.arrow.down") }.menuStyle(.borderlessButton).fixedSize().help("Sort poems")
                        }
                        if poems.isEmpty { EmptyState(icon: "magnifyingglass", title: "No matching poems", description: "Try another search or stage.") }
                        else {
                            List(poems, selection: $selected) { poem in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(poem.title).font(.system(size: 18, design: .serif)).lineLimit(2)
                                    HStack { Badge(text: poem.stage.rawValue, color: poem.stage.color); Spacer(); Text(poem.updatedAt.formatted(.dateTime.month(.abbreviated).day())).font(.system(size: 10)).foregroundStyle(.secondary) }
                                }.padding(.vertical, 9).tag(poem.id)
                                    .contextMenu { Button("Edit…") { editor = .poem(poem) }; Button("Delete…", role: .destructive) { deleting = poem } }
                            }.listStyle(.inset).scrollContentBackground(.hidden)
                        }
                        Text("\(poems.count) \(poems.count == 1 ? "poem" : "poems")").font(.system(size: 11)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(.leading, 24).padding(.trailing, 16).padding(.bottom, 20).frame(minWidth: 280, idealWidth: 340, maxWidth: 420)
                    if let poem = poems.first(where: { $0.id == selected }) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 26) {
                                HStack { Badge(text: poem.stage.rawValue, color: poem.stage.color); Spacer(); Button("Edit") { editor = .poem(poem) } }
                                Text(poem.title).font(.system(size: 32, design: .serif)).textSelection(.enabled)
                                HStack(spacing: 20) {
                                    dateLabel("CREATED", date: poem.createdAt)
                                    dateLabel("UPDATED", date: poem.updatedAt)
                                }
                                Divider()
                                NotesView(notes: poem.notes)
                                Divider()
                                DetailSection(title: "Submission history") {
                                    let submissions = store.library.submissions(forPoem: poem.id).sorted { $0.sentAt > $1.sentAt }
                                    if submissions.isEmpty { Text("This poem hasn’t been sent out yet.").foregroundStyle(.secondary) }
                                    ForEach(submissions) { submission in
                                        Button { editor = .submission(submission) } label: {
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text(store.library.venue(submission.venueID)?.name ?? "Destination").fontWeight(.medium)
                                                HStack {
                                                    Text(submission.sentAt.formatted(date: .abbreviated, time: .omitted)).foregroundStyle(.secondary)
                                                    Spacer()
                                                    if let entry = submission.entries.first(where: { $0.poemID == poem.id }) { Badge(text: entry.outcome.rawValue, color: entry.outcome.color) }
                                                }
                                            }.padding(14).background(Palette.card, in: RoundedRectangle(cornerRadius: 10))
                                        }.buttonStyle(.plain)
                                    }
                                    Button { editor = .submission(Submission(venueID: store.library.venues.first?.id ?? UUID(), entries: [SubmissionEntry(poemID: poem.id)])) } label: { Label("Submit this poem", systemImage: "paperplane") }.disabled(store.library.venues.isEmpty)
                                    if store.library.venues.isEmpty { Text("Add a journal or contest to record a submission.").font(.caption).foregroundStyle(.secondary) }
                                }
                                Button("Delete poem…", role: .destructive) { deleting = poem }.buttonStyle(.borderless).font(.caption).padding(.top, 12)
                            }.padding(28)
                        }.frame(minWidth: 310, maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        EmptyState(icon: "doc.text", title: "A closer look", description: "Select a poem to see notes and its submission history.").frame(minWidth: 310)
                    }
                }
            }
        }
        .alert("Delete this poem?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Cancel", role: .cancel) { deleting = nil }
            Button("Delete", role: .destructive) { if let poem = deleting { store.deletePoem(poem.id) }; deleting = nil }
        } message: { Text("“\(deleting?.title ?? "")” will be removed. Poems with submission history must first be removed from those submissions.") }
    }
    private func dateLabel(_ title: String, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 9, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
            Text(date.formatted(date: .abbreviated, time: .omitted)).font(.system(size: 12))
        }
    }
}
