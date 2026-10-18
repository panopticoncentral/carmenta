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
                Button("New Poem…") { NotificationCenter.default.post(name: .newPoem, object: nil) }.keyboardShortcut("n").disabled(!store.canEdit || store.editorCount > 0)
                Button("New Journal or Contest…") { NotificationCenter.default.post(name: .newVenue, object: nil) }.keyboardShortcut("n", modifiers: [.command, .shift]).disabled(!store.canEdit || store.editorCount > 0)
                Button("New Submission…") { NotificationCenter.default.post(name: .newSubmission, object: nil) }.keyboardShortcut("n", modifiers: [.command, .option]).disabled(!store.canEdit || store.editorCount > 0)
                Divider()
                Button("Create Shared Library Folder…") { Task { await store.chooseSharedFolder(create: true) } }
                    .disabled(!store.canSwitchLibrary || !store.canEdit)
                Button("Open Shared Library Folder…") { Task { await store.chooseSharedFolder(create: false) } }
                    .disabled(!store.canSwitchLibrary)
                Button("Open Local Library") { Task { await store.useLocalLibrary() } }
                    .disabled(!store.canSwitchLibrary || !store.isShared)
                Divider()
                Button("Load Latest Library") { Task { await store.reload() } }
                    .disabled(!store.canSwitchLibrary)
                Button("Show Library Backups") { store.showBackups() }.disabled(store.isDemo)
                Button("Export Library…") { Task { await store.exportLibrary() } }.disabled(store.loadError != nil || store.isBusy)
            }
        }
    }
}

extension Notification.Name {
    static let newPoem = Notification.Name("carmenta.newPoem")
    static let newVenue = Notification.Name("carmenta.newVenue")
    static let newSubmission = Notification.Name("carmenta.newSubmission")
}
