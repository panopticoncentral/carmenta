# Carmenta

A native Mac app for organizing a poet’s writing life. Built with SwiftUI, for macOS 14 and later.

## First version

- **Overview:** collection totals, pending submissions, upcoming deadlines, and recently updated poems.
- **Poems:** titles, draft/revising/ready/published stages, notes, and submission history.
- **Journals & contests:** a destination list with websites, optional deadlines, notes, and previous submissions.
- **Submissions:** connect one or more poems to a destination, record the sent date, and track pending, accepted, declined, or withdrawn outcomes for each poem. Partial responses keep a submission pending until all poems have an outcome. Simultaneous submissions are supported.
- Search, filters, editing, deletion confirmation, keyboard shortcuts, and JSON export.

Poem text and documents remain wherever the poet already keeps them. Acceptance does not automatically mark a poem as published; these are separate events.

## Run

Requires a Mac with Xcode 16 or later. No external dependencies. The build script uses `/Applications/Xcode.app` when available without changing the system’s selected developer directory.

```sh
./scripts/build-app.sh
open build/Carmenta.app
```

The build script creates a locally signed app bundle. You can copy it to Applications. Distribution to other users would require Developer ID signing and notarization.

For development and distribution, open `Carmenta.xcodeproj` in Xcode, choose the **Carmenta** scheme and **My Mac**, and select your Apple Developer team under the app target’s **Signing & Capabilities**. This project builds a sandboxed Mac app, has a shared scheme and test plan, and can create archives for TestFlight. See [Xcode Cloud and TestFlight setup](docs/XcodeCloud.md) for the walkthrough.

The Swift package and shell build remain available for quick local builds: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift run Carmenta`. These builds are not the distribution path.

To explore with fictional sample records without reading or writing your real library:

```sh
open -n build/Carmenta.app --args --demo
```

The regular app starts with an empty library. Demo mode is labeled in the sidebar, and changes to demo records disappear when it closes.

## App icon

The app uses `Resources/CarmentaIcon.png`, an ivory leaf/quill on a sage-green tile, generated with the built-in image tool. Its full prompt is saved in `Resources/CarmentaIcon.prompt.txt`. `scripts/package-icon.sh` produces the standard macOS icon sizes, the `.icns` file, and the Xcode asset catalog’s PNGs. Run it after changing the source icon, then commit the regenerated assets. The earlier SF Symbols icon and its drawing script are retained as an alternative.

## Data

Records save when you click Save. The original shell/Swift-package build uses:

```text
~/Library/Application Support/Carmenta/library.json
```

The sandboxed Xcode and TestFlight builds use:

```text
~/Library/Containers/com.panopticoncentral.carmenta/Data/Library/Application Support/Carmenta/library.json
```

The Xcode app includes a container migration manifest asking macOS to copy the original `Carmenta` application-support folder on the first sandboxed launch. Export a backup before switching builds. Once migrated, the two builds have separate libraries; use the sandboxed version consistently. Migration needs verification with a developer-signed build on your Mac.

Writes are atomic and coordinated with macOS. Before each edit is saved, Carmenta compares the file’s exact contents with the version it loaded. A changed, deleted, unavailable, or conflicted file blocks saving. Invalid relationships are rejected before saving, and load errors block editing to protect the existing file. Poems and destinations with submission history cannot be deleted until the linked records are removed. File → Export Library saves a portable JSON copy of the complete library, using a different filename from the open library.

### Sharing a library with iCloud Drive

Both people need the updated app. Start with the Mac containing the library you want to share:

1. Choose **File → Create Shared Library Folder…** and select a new folder in iCloud Drive. This copies your current library into `library.json` in that folder and switches Carmenta to the shared copy. An existing library is never overwritten by this command.
2. Share that folder in Finder with the other person, granting permission to make changes. Wait for the upload to finish.
3. On the other Mac, accept the folder invitation, wait for it to download, and choose **File → Open Shared Library Folder…**. Select the same shared folder. Opening a folder requires an existing, valid `library.json`; it never creates an empty replacement.

Carmenta remembers the selected folder across launches, including in the sandboxed Xcode/TestFlight app. The sidebar identifies the shared folder and offers **Show Library in Finder**. **File → Open Local Library** returns to that Mac’s separate local library; changes in the shared copy are not copied back automatically. The folder picker also works with ordinary local folders for testing.

**Take turns having the library open.** Finish saving, quit Carmenta, and wait for iCloud to finish uploading before handing over. The other person should wait for the updated file to download before opening Carmenta. Finder’s sync status is the place to check the handoff; Carmenta cannot confirm that another Mac has received an upload.

While active, Carmenta checks for external changes every three seconds and when returning to the app. Every save checks again under macOS file coordination. A detected change pauses editing and offers **Load Latest**. If an editor is open, its unsaved text remains visible: copy anything you want to keep, cancel the editor (including any nested editor), then load the latest library and reapply your changes. Reloading and switching libraries are disabled while an editor is open. Carmenta requests downloads for iCloud files that aren’t current and blocks editing when iCloud reports unresolved file versions.

This supports sequential editing, not simultaneous collaboration or automatic merging. File coordination protects cooperating processes on the same Mac; it is not a lock across two Macs. A remote edit that iCloud hasn’t delivered yet cannot be detected. Both people must still follow the handoff above and avoid editing offline during a handoff.

### Automatic backups and recovery

Carmenta keeps dated JSON backups **on each Mac**, outside the shared folder, under its application-support `Carmenta/Backups` directory. Each library location has its own subfolder. Before each save, backups preserve both the exact previous file and the new version, so even your last edit is recoverable if a later sync replaces it. Valid versions received when opening or reloading are also backed up. Identical contents are stored once. Backups are retained until you remove them; they are not automatically pruned. A backup failure prevents the associated save or load. If the library write fails after backups succeed, a recovery copy of that attempted save remains in the backup folder.

Choose **File → Show Library Backups** to find the copies for the current library. To restore one, finish editing and quit Carmenta on both Macs, keep a separate copy of the current `library.json`, then copy the chosen backup into the shared folder under the name `library.json`. Wait for iCloud to sync to both Macs before reopening. Exported libraries can be restored the same way. There is no in-app import or conflict-merging interface yet; do not discard an iCloud conflict version until you have preserved and compared both copies.

The independent `CarmentaCore` module contains the Codable models, validation, and persistence so a future iOS app can reuse them.

## Keyboard shortcuts

| Action | Shortcut |
| --- | --- |
| New poem | ⌘N |
| New journal or contest | ⇧⌘N |
| New submission | ⌥⌘N |
| Save an editor | Return |
| Cancel an editor | Escape |

## Verify

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test
```

Tests cover persistence round trips, partial responses, simultaneous submissions, relationship integrity, invalid dates, schema compatibility, stale and concurrent writers, deleted or corrupt libraries, safe shared-library creation, backup contents, and preservation of saved data after backup failures. File coordination tests need access to the macOS file-coordination service; a restricted command sandbox may block them.

Before distributing a signed build, verify the iCloud handoff on two Macs: create and share a library, open it on the second Mac, relaunch to check saved folder access, edit and hand over, then deliberately leave an editor open while a change arrives and confirm that Save is blocked. Also verify a cloud-only file downloads before opening. These checks require real iCloud accounts and are not simulated by the unit tests.

In Xcode, use **Product → Test** (⌘U) with the **Carmenta** scheme. The shared `Carmenta.xctestplan` runs the same tests against the native `CarmentaCore` target. No third-party packages or cloud setup scripts are needed.
