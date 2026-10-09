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

Writes are atomic. Invalid relationships are rejected before saving, and load errors block editing to protect the existing file. Poems and destinations with submission history cannot be deleted until the linked records are removed. File → Export Library saves a portable JSON copy of the complete library. There is no in-app import yet; to restore an export, quit Carmenta, back up the current library, and replace `library.json` with the export.

This version is local to one Mac, with no account or sync. Use one running app instance for your real library; cross-process editing is not supported yet. The independent `CarmentaCore` module contains the Codable models, validation, and persistence so a future iOS app can reuse them.

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

Tests cover persistence round trips, partial responses, simultaneous submissions, relationship integrity, invalid dates, schema compatibility, and preservation of saved data after failures.

In Xcode, use **Product → Test** (⌘U) with the **Carmenta** scheme. The shared `Carmenta.xctestplan` runs the same tests against the native `CarmentaCore` target. No third-party packages or cloud setup scripts are needed.
