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

For development, open `Package.swift` in Xcode, select the Carmenta executable scheme, and run. Or use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift run Carmenta`.

To explore with fictional sample records without reading or writing your real library:

```sh
open -n build/Carmenta.app --args --demo
```

The regular app starts with an empty library. Demo mode is labeled in the sidebar, and changes to demo records disappear when it closes.

## App icon

The app uses `Resources/CarmentaIcon.png`, an ivory leaf/quill on a sage-green tile, generated with the built-in image tool. Its full prompt is saved in `Resources/CarmentaIcon.prompt.txt`. `scripts/package-icon.sh` produces the standard macOS icon sizes and the `.icns` file; the app build refreshes this automatically when the source image changes. The earlier SF Symbols icon and its drawing script are retained as an alternative.

## Data

Records save automatically when you click Save, to:

```text
~/Library/Application Support/Carmenta/library.json
```

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
