import SwiftUI
import CarmentaCore

struct OverviewView: View {
    @Environment(LibraryStore.self) private var store
    @Binding var section: Section?
    @Binding var editor: Editor?
    private var pending: [Submission] { store.library.submissions.filter(\.isPending).sorted { $0.sentAt < $1.sentAt } }
    private var deadlines: [Venue] {
        store.library.venues.filter { ($0.deadline ?? .distantPast) >= Calendar.current.startOfDay(for: .now) }
            .sorted { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .top) {
                    PageHeading(eyebrow: Date.now.formatted(.dateTime.month(.wide).day().year()), title: "Your writing life, gathered.", subtitle: "A little space to see where you are, and what comes next.")
                    Spacer()
                    Menu {
                        Button("Poem", systemImage: "doc.text") { editor = .poem(Poem()) }
                        Button("Journal or contest", systemImage: "books.vertical") { editor = .venue(Venue()) }
                        Button("Submission", systemImage: "paperplane") { editor = .submission(nil) }
                    } label: { Label("Add new", systemImage: "plus") }.menuStyle(.borderlessButton).fixedSize().padding(10)
                        .background(Palette.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                }
                HStack(spacing: 16) {
                    stat("Poems in your collection", count: store.library.poems.count, icon: "doc.text", destination: .poems)
                    stat("Awaiting a response", count: pending.count, icon: "paperplane", destination: .submissions)
                    stat("Poems accepted", count: Set(store.library.submissions.flatMap(\.entries).filter { $0.outcome == .accepted }.map(\.poemID)).count, icon: "sparkles", destination: .submissions)
                }
                if store.library.poems.isEmpty && store.library.venues.isEmpty {
                    HStack(spacing: 30) {
                        Image(systemName: "pencil.and.outline").font(.system(size: 58, weight: .ultraLight)).foregroundStyle(Palette.accent)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Every collection begins with a poem.").font(.system(size: 25, design: .serif))
                            Text("Add a title and a few notes. As your work grows, keep track of the places you’d like to send it and the journeys it takes.").foregroundStyle(.secondary).lineSpacing(4)
                            Button("Add your first poem") { editor = .poem(Poem()) }.buttonStyle(.borderedProminent).padding(.top, 4)
                        }
                    }.padding(30).frame(maxWidth: .infinity, alignment: .leading).background(Palette.accent.opacity(0.065), in: RoundedRectangle(cornerRadius: 16))
                }
                HStack(alignment: .top, spacing: 22) {
                    VStack(alignment: .leading, spacing: 18) {
                        blockHeading("Out in the world", subtitle: "Submissions awaiting a response", action: "View all") { section = .submissions }
                        if pending.isEmpty {
                            quietCard("No submissions waiting", description: "When you send your work, its progress will appear here.", icon: "paperplane")
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(pending.prefix(5).enumerated()), id: \.element.id) { index, submission in
                                    Button { editor = .submission(submission) } label: {
                                        HStack(alignment: .top, spacing: 12) {
                                            Image(systemName: "envelope").foregroundStyle(Palette.gold).frame(width: 32, height: 32).background(Palette.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(store.library.venue(submission.venueID)?.name ?? "Destination").font(.system(size: 14, weight: .medium))
                                                Text(submission.entries.compactMap { store.library.poem($0.poemID)?.title }.joined(separator: " · ")).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2)
                                                Text("Sent \(submission.sentAt.formatted(date: .abbreviated, time: .omitted))").font(.system(size: 11)).foregroundStyle(.tertiary)
                                            }
                                            Spacer(minLength: 0)
                                            Text("\(max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: submission.sentAt), to: Calendar.current.startOfDay(for: .now)).day ?? 0))d").font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                                        }.padding(18).contentShape(Rectangle())
                                    }.buttonStyle(.plain)
                                    if index < min(pending.count, 5) - 1 { Divider().padding(.horizontal, 18) }
                                }
                            }.background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 18) {
                        blockHeading("On the horizon", subtitle: "Upcoming journal and contest deadlines", action: nil) {}
                        if deadlines.isEmpty {
                            quietCard("Room for possibilities", description: "Save journals and contests, then add deadlines to see them here.", icon: "calendar")
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(deadlines.prefix(4).enumerated()), id: \.element.id) { index, venue in
                                    Button { editor = .venue(venue) } label: {
                                        HStack(spacing: 14) {
                                            VStack(spacing: 2) {
                                                Text((venue.deadline ?? .now).formatted(.dateTime.month(.abbreviated)).uppercased()).font(.system(size: 9, weight: .semibold)).tracking(1)
                                                Text((venue.deadline ?? .now).formatted(.dateTime.day())).font(.system(size: 25, design: .serif))
                                            }.foregroundStyle(Palette.accent).frame(width: 48, height: 55).background(Palette.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(venue.name).font(.system(size: 13, weight: .medium))
                                                Text(venue.kind.rawValue).font(.system(size: 11)).foregroundStyle(.secondary)
                                            }
                                            Spacer(minLength: 0)
                                        }.padding(16).contentShape(Rectangle())
                                    }.buttonStyle(.plain)
                                    if index < min(deadlines.count, 4) - 1 { Divider().padding(.horizontal, 16) }
                                }
                            }.background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
                        }
                        Button { editor = .venue(Venue()) } label: { Label("Add a journal or contest", systemImage: "plus") }.buttonStyle(.plain).foregroundStyle(Palette.accent).font(.system(size: 12))
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: 16) {
                    blockHeading("At your desk", subtitle: "Recently updated poems", action: "All poems") { section = .poems }
                    if store.library.poems.isEmpty {
                        Text("Drafts, revisions, and finished work—all welcome here.").foregroundStyle(.secondary).padding(.vertical, 10)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(store.library.poems.sorted { $0.updatedAt > $1.updatedAt }.prefix(4))) { poem in
                                Button { editor = .poem(poem) } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: "doc.text").foregroundStyle(.tertiary)
                                        Text(poem.title).font(.system(size: 16, design: .serif))
                                        Spacer()
                                        Badge(text: poem.stage.rawValue, color: poem.stage.color)
                                    }.padding(15).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                            }
                        }.background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }.padding(36).frame(maxWidth: 1250, alignment: .leading).frame(maxWidth: .infinity)
        }
    }

    private func stat(_ title: String, count: Int, icon: String, destination: Section) -> some View {
        Button { section = destination } label: {
            VStack(alignment: .leading, spacing: 13) {
                HStack { Image(systemName: icon).foregroundStyle(Palette.accent); Spacer(); Text(String(format: "%02d", count)).font(.system(size: 38, weight: .regular, design: .serif)) }
                Text(title).font(.system(size: 12)).foregroundStyle(.secondary)
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
    }

    private func blockHeading(_ title: String, subtitle: String, action: String?, perform: @escaping () -> Void) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 22, design: .serif))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 5)
            if let action { Button(action, action: perform).buttonStyle(.plain).foregroundStyle(Palette.accent).font(.system(size: 11)) }
        }
    }

    private func quietCard(_ title: String, description: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Image(systemName: icon).font(.system(size: 23, weight: .light)).foregroundStyle(Palette.accent)
            Text(title).font(.system(size: 15, weight: .medium))
            Text(description).font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(3)
        }.padding(23).frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading).background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
    }
}
