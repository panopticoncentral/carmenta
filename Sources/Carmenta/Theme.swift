import SwiftUI
import CarmentaCore

enum Palette {
    static let accent = adaptive(light: (0.24, 0.39, 0.33), dark: (0.60, 0.77, 0.66))
    static let canvas = adaptive(light: (0.97, 0.965, 0.95), dark: (0.105, 0.117, 0.11))
    static let card = adaptive(light: (0.997, 0.994, 0.986), dark: (0.15, 0.17, 0.157))
    static let muted = Color.secondary
    static let gold = adaptive(light: (0.65, 0.44, 0.20), dark: (0.82, 0.66, 0.40))
    private static func adaptive(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: value.0, green: value.1, blue: value.2, alpha: 1)
        })
    }
}

extension PoemStage {
    var color: Color {
        switch self { case .draft: return .secondary; case .revising: return Palette.gold; case .ready: return Palette.accent; case .published: return .purple }
    }
}

extension Outcome {
    var color: Color {
        switch self { case .pending: return Palette.gold; case .accepted: return Palette.accent; case .declined: return .secondary; case .withdrawn: return .secondary }
    }
}

struct Badge: View {
    var text: String
    var color: Color = Palette.accent
    var body: some View {
        Text(text).font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 9).padding(.vertical, 5)
            .foregroundStyle(color).background(color.opacity(0.10), in: Capsule())
            .fixedSize()
    }
}

struct PageHeading: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(eyebrow.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(2).foregroundStyle(Palette.accent)
            Text(title).font(.system(size: 34, weight: .regular, design: .serif))
            Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
        }
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let description: String
    var actionTitle: String? = nil
    var action: () -> Void = {}
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: icon).font(.system(size: 32, weight: .light)).foregroundStyle(Palette.accent)
                .frame(width: 72, height: 72).background(Palette.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
            Text(title).font(.system(size: 24, design: .serif))
            Text(description).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 330)
            if let actionTitle { Button(actionTitle, action: action).buttonStyle(.borderedProminent).padding(.top, 4) }
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(30)
    }
}

struct DetailSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(1.5).foregroundStyle(.secondary)
            content()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NotesView: View {
    let notes: String
    var body: some View {
        DetailSection(title: "Notes") {
            Text(notes.isEmpty ? "No notes yet." : notes).font(.system(size: 13)).foregroundStyle(notes.isEmpty ? .secondary : .primary)
                .lineSpacing(5).textSelection(.enabled)
        }
    }
}

struct SearchField: View {
    @Binding var text: String
    var prompt: String
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.tertiary)
            TextField(prompt, text: $text).textFieldStyle(.plain)
            if !text.isEmpty { Button { text = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(.secondary).help("Clear search") }
        }.padding(10).background(Palette.card, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.primary.opacity(0.07)))
    }
}
