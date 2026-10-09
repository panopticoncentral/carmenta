import SwiftUI

@main
struct CarmentaApp: App {
    @State private var store = LibraryStore()
    var body: some Scene {
        Window("Carmenta", id: "main") {
            ContentView().environment(store).tint(Palette.accent)
                .frame(minWidth: 980, minHeight: 680)
        }
        .defaultSize(width: 1240, height: 820)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Poem…") { NotificationCenter.default.post(name: .newPoem, object: nil) }.keyboardShortcut("n")
                Button("New Journal or Contest…") { NotificationCenter.default.post(name: .newVenue, object: nil) }.keyboardShortcut("n", modifiers: [.command, .shift])
                Button("New Submission…") { NotificationCenter.default.post(name: .newSubmission, object: nil) }.keyboardShortcut("n", modifiers: [.command, .option])
                Divider()
                Button("Export Library…") { store.exportLibrary() }.disabled(store.loadError != nil)
            }
        }
    }
}

extension Notification.Name {
    static let newPoem = Notification.Name("carmenta.newPoem")
    static let newVenue = Notification.Name("carmenta.newVenue")
    static let newSubmission = Notification.Name("carmenta.newSubmission")
}
