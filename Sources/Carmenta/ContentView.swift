import SwiftUI
import CarmentaCore

enum Section: String, CaseIterable, Identifiable {
    case overview = "Overview", poems = "Poems", venues = "Journals & Contests", submissions = "Submissions"
    var id: String { rawValue }
    var icon: String {
        switch self { case .overview: return "square.grid.2x2"; case .poems: return "doc.text"; case .venues: return "books.vertical"; case .submissions: return "paperplane" }
    }
}

enum Editor: Identifiable {
    case poem(Poem), venue(Venue), submission(Submission?)
    var id: String {
        switch self { case .poem(let p): return "poem-\(p.id)"; case .venue(let v): return "venue-\(v.id)"; case .submission(let s): return "submission-\(s?.id.uuidString ?? "new")" }
    }
}

struct ContentView: View {
    @Environment(LibraryStore.self) private var store
    @State private var section: Section? = .overview
    @State private var editor: Editor?
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "leaf").font(.system(size: 25, weight: .light)).foregroundStyle(Palette.accent)
                    Text("carmenta").font(.system(size: 26, design: .serif))
                }.padding(.horizontal, 22).padding(.top, 35).padding(.bottom, 6)
                Text("A place for your poetic life").font(.system(size: 11)).foregroundStyle(.secondary).padding(.leading, 22).padding(.bottom, 35)
                List(Section.allCases, selection: $section) { item in
                    Label(item.rawValue, systemImage: item.icon).font(.system(size: 13, weight: .medium)).padding(.vertical, 7).tag(item)
                }.listStyle(.sidebar)
                Spacer()
                VStack(alignment: .leading, spacing: 10) {
                    Rectangle().fill(.primary.opacity(0.08)).frame(height: 1)
                    Label(store.isDemo ? "Sample library" : "Saved on this Mac", systemImage: store.isDemo ? "sparkles" : "internaldrive")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    if store.isDemo { Text("Fictional records · changes aren’t saved").font(.system(size: 10)).foregroundStyle(.secondary) }
                }.padding(22)
            }.navigationSplitViewColumnWidth(min: 210, ideal: 225, max: 270)
        } detail: {
            if let error = store.loadError {
                VStack(spacing: 20) {
                    EmptyState(icon: "externaldrive.badge.exclamationmark", title: "Your library couldn’t be opened", description: error)
                    Text("Your existing file has been preserved.").foregroundStyle(.secondary)
                    HStack {
                        Button("Show Library File") { NSWorkspace.shared.activateFileViewerSelecting([store.file.url]) }
                        Button("Try Again") { store.reload() }.buttonStyle(.borderedProminent)
                    }.padding(.bottom, 50)
                }
            } else {
                Group {
                    switch section ?? .overview {
                    case .overview: OverviewView(section: $section, editor: $editor)
                    case .poems: PoemsView(editor: $editor)
                    case .venues: VenuesView(editor: $editor)
                    case .submissions: SubmissionsView(editor: $editor)
                    }
                }.background(Palette.canvas)
            }
        }
        .sheet(item: $editor) { item in
            switch item {
            case .poem(let poem): PoemEditor(poem: poem)
            case .venue(let venue): VenueEditor(venue: venue)
            case .submission(let submission): SubmissionEditor(submission: submission)
            }
        }
        .alert("Unable to update library", isPresented: Binding(get: { store.error != nil && editor == nil }, set: { if !$0 { store.error = nil } })) {
            Button("OK") { store.error = nil }
        } message: { Text(store.error ?? "") }
        .onReceive(NotificationCenter.default.publisher(for: .newPoem)) { _ in if store.loadError == nil { editor = .poem(Poem()) } }
        .onReceive(NotificationCenter.default.publisher(for: .newVenue)) { _ in if store.loadError == nil { editor = .venue(Venue()) } }
        .onReceive(NotificationCenter.default.publisher(for: .newSubmission)) { _ in if store.loadError == nil { editor = .submission(nil) } }
    }
}
