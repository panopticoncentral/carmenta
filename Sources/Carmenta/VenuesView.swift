import SwiftUI
import CarmentaCore

struct VenuesView: View {
    @Environment(LibraryStore.self) private var store
    @Binding var editor: Editor?
    @State private var search = ""
    @State private var kind: VenueKind?
    @State private var selected: UUID?
    @State private var deleting: Venue?
    private var venues: [Venue] {
        store.library.venues.filter { (kind == nil || $0.kind == kind) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.notes.localizedCaseInsensitiveContains(search)) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                PageHeading(eyebrow: "Places for your work", title: "Journals & Contests", subtitle: "Keep your possibilities close.")
                Spacer()
                Button { editor = .venue(Venue()) } label: { Label("Add destination", systemImage: "plus") }.buttonStyle(.borderedProminent)
            }.padding(.horizontal, 30).padding(.top, 30)
            if store.library.venues.isEmpty {
                EmptyState(icon: "books.vertical", title: "Where might your work belong?", description: "Collect journals and contests you’re interested in, along with deadlines and notes.", actionTitle: "Add a journal or contest") { editor = .venue(Venue()) }
            } else {
                HSplitView {
                    VStack(spacing: 14) {
                        SearchField(text: $search, prompt: "Find a destination…")
                        Picker("Kind", selection: $kind) {
                            Text("All").tag(nil as VenueKind?)
                            Text("Journals").tag(Optional(VenueKind.journal))
                            Text("Contests").tag(Optional(VenueKind.contest))
                        }.pickerStyle(.segmented).labelsHidden()
                        if venues.isEmpty { EmptyState(icon: "magnifyingglass", title: "No matches", description: "Try another name or filter.") }
                        else {
                            List(venues, selection: $selected) { venue in
                                VStack(alignment: .leading, spacing: 9) {
                                    Text(venue.name).font(.system(size: 17, design: .serif)).lineLimit(2)
                                    HStack {
                                        Badge(text: venue.kind.rawValue, color: venue.kind == .journal ? Palette.accent : Palette.gold)
                                        Spacer()
                                        if let deadline = venue.deadline { Text(deadline.formatted(.dateTime.month(.abbreviated).day())).font(.system(size: 11)).foregroundStyle(.secondary) }
                                    }
                                }.padding(.vertical, 9).tag(venue.id)
                                    .contextMenu { Button("Edit…") { editor = .venue(venue) }; Button("Delete…", role: .destructive) { deleting = venue } }
                            }.listStyle(.inset).scrollContentBackground(.hidden)
                        }
                        Text("\(venues.count) \(venues.count == 1 ? "destination" : "destinations")").font(.system(size: 11)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(.leading, 24).padding(.trailing, 16).padding(.bottom, 20).frame(minWidth: 280, idealWidth: 340, maxWidth: 420)
                    if let venue = venues.first(where: { $0.id == selected }) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 26) {
                                HStack { Badge(text: venue.kind.rawValue, color: venue.kind == .journal ? Palette.accent : Palette.gold); Spacer(); Button("Edit") { editor = .venue(venue) } }
                                Text(venue.name).font(.system(size: 32, design: .serif)).textSelection(.enabled)
                                if let url = venue.websiteURL { Link(destination: url) { Label(url.host ?? "Visit website", systemImage: "arrow.up.right.square") }.font(.system(size: 12)) }
                                if let deadline = venue.deadline {
                                    HStack(spacing: 12) {
                                        Image(systemName: "calendar").font(.title2).foregroundStyle(Palette.gold)
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(deadline < Calendar.current.startOfDay(for: .now) ? "Past deadline" : "Submission deadline").font(.caption).foregroundStyle(.secondary)
                                            Text(deadline.formatted(date: .long, time: .omitted)).font(.system(size: 14, weight: .medium))
                                        }
                                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Palette.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                                }
                                NotesView(notes: venue.notes)
                                Divider()
                                DetailSection(title: "Your submissions") {
                                    let submissions = store.library.submissions(forVenue: venue.id).sorted { $0.sentAt > $1.sentAt }
                                    if submissions.isEmpty { Text("No submissions here yet.").foregroundStyle(.secondary) }
                                    ForEach(submissions) { submission in
                                        Button { editor = .submission(submission) } label: {
                                            VStack(alignment: .leading, spacing: 10) {
                                                Text(submission.entries.compactMap { store.library.poem($0.poemID)?.title }.joined(separator: ", ")).fontWeight(.medium)
                                                HStack {
                                                    Text(submission.sentAt.formatted(date: .abbreviated, time: .omitted)).foregroundStyle(.secondary)
                                                    Spacer()
                                                    Badge(text: submission.outcome.rawValue, color: submission.outcome.color)
                                                }
                                            }.padding(14).background(Palette.card, in: RoundedRectangle(cornerRadius: 10))
                                        }.buttonStyle(.plain)
                                    }
                                    Button { editor = .submission(Submission(venueID: venue.id)) } label: { Label("Record a submission", systemImage: "paperplane") }.disabled(store.library.poems.isEmpty)
                                    if store.library.poems.isEmpty { Text("Add a poem to record a submission.").font(.caption).foregroundStyle(.secondary) }
                                }
                                Button("Delete destination…", role: .destructive) { deleting = venue }.buttonStyle(.borderless).font(.caption).padding(.top, 12)
                            }.padding(28)
                        }.frame(minWidth: 310, maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        EmptyState(icon: "books.vertical", title: "Find the right home", description: "Select a journal or contest for details and submission history.").frame(minWidth: 310)
                    }
                }
            }
        }
        .alert("Delete this destination?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Cancel", role: .cancel) { deleting = nil }
            Button("Delete", role: .destructive) { if let venue = deleting { store.deleteVenue(venue.id) }; deleting = nil }
        } message: { Text("“\(deleting?.name ?? "")” will be removed. Destinations with submission history cannot be deleted until those submissions are removed.") }
    }
}
