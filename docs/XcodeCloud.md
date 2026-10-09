# Xcode Cloud and TestFlight

Carmenta has two build paths. Use **Carmenta.xcodeproj** for Xcode Cloud and TestFlight; the original Swift package and ad-hoc shell build are for local development.

## 1. Connect your Apple Developer team

1. Open `Carmenta.xcodeproj` in Xcode.
2. Open **Xcode → Settings → Accounts** and sign in with the Apple Account enrolled in the Apple Developer Program, if it is not already listed.
3. Select the blue **Carmenta** project in the navigator, then the **Carmenta** app target.
4. Under **Signing & Capabilities**, leave **Automatically manage signing** enabled and choose your paid developer **Team**. Do not choose Personal Team.
5. Keep the bundle identifier `com.panopticoncentral.carmenta`, provided it belongs to your account. If Apple reports that it is unavailable, select a unique identifier before creating the App Store Connect app record. The identifier must match across Xcode and App Store Connect.
6. Apply the team selection to both Debug and Release configurations (the All view in Signing & Capabilities).

The project already includes App Sandbox, user-selected file read/write access for JSON export, hardened runtime, the app icon, version `0.1.0`, and a shared **Carmenta** scheme. `CarmentaCore` is a static library linked into the app, so there is no additional framework to distribute or register.

## 2. Verify the project locally

Choose the **Carmenta** scheme and **My Mac** in the toolbar. Run **Product → Test** (⌘U), then **Product → Archive**. The archive should appear in **Window → Organizer → Archives** as a Mac app.

An unsigned archive check confirms that the project builds and packages correctly, but Apple account signing and App Store Connect validation still need to succeed before distribution.

For the first sandboxed run, export a backup of any records from the original local app first. The migration manifest asks macOS to copy `~/Library/Application Support/Carmenta` into the sandbox container. Check that your records appear in the signed Xcode build before moving to TestFlight. A developer-signed run is needed to validate migration; unsigned build checks do not exercise it.

## 3. Commit and push the setup

Xcode Cloud reads GitHub, not uncommitted local files. Commit the project, shared scheme, test plan, resources, and the team setting Xcode writes, then push to `main`. Team IDs can be committed; certificates, private keys, and account credentials must not be.

The source repository is `panopticoncentral/carmenta`. Build output and personal Xcode state are ignored.

## 4. Create the first Xcode Cloud workflow

1. In Xcode’s **Report navigator** (⌘9), open **Cloud** and choose **Get Started**. Choose the **Carmenta** app product, not the CarmentaCore library.
2. Select your developer team and review the suggested workflow.
3. Start with the **Carmenta** scheme, a current stable Xcode release, macOS, and changes to branch `main` as the start condition. Use a released Xcode version offered by Xcode Cloud that supports Swift 6 (Xcode 16 or later).
4. Include a **Test** action using the **Carmenta** scheme and test plan, and an **Archive** action for macOS.
5. Follow the GitHub authorization flow to grant Xcode Cloud access to `panopticoncentral/carmenta`. If offered repository selection, granting just this repository is sufficient.
6. Start the first build and inspect its logs in the Cloud report. No custom `ci_scripts` or manual certificate uploads are needed for this project.

Apple’s [first-workflow guide](https://developer.apple.com/documentation/xcode/configuring-your-first-xcode-cloud-workflow) describes the product selection, repository connection, and initial build.

## 5. Enable TestFlight distribution

After the first development build succeeds, control-click the **Carmenta** product in Xcode’s Cloud report and choose **Set Up Distribution**. Xcode can create the App Store Connect app record or connect to an existing one with the matching bundle ID. If the name Carmenta is already taken, choose an available App Store name; this is separate from the bundle identifier.

Alternatively, create the record in [App Store Connect](https://appstoreconnect.apple.com/): **Apps → + → New App**, platform **macOS**, name **Carmenta**, primary language **English (U.S.)**, bundle ID **com.panopticoncentral.carmenta**, and an internal SKU such as **carmenta-macos**. The SKU is an internal identifier you choose.

For a distribution workflow, use:

| Setting | Value |
| --- | --- |
| Name | Carmenta TestFlight |
| Branch condition | Changes to `main` |
| Scheme | Carmenta |
| Test action | macOS, Carmenta test plan |
| Archive action | macOS, Release |
| Deployment preparation | **TestFlight and App Store** |
| Environment | Clean build, stable supported Xcode/macOS |
| General | Restrict editing as required for distribution |
| Post-action | TestFlight, initially your internal tester group |

**TestFlight and App Store** allows later distribution to external testers. **TestFlight (Internal Testing Only)** restricts that particular build to internal testers. Choosing the broader option does not publish the app on the App Store; publication requires a separate submission and review.

Create an internal tester group in App Store Connect before selecting it in the post-action. Xcode Cloud handles distribution signing, upload, and increasing build numbers. Since this is a new app, numbering can start at 1. If you manually upload a Mac build first, set Cloud’s next build number above the highest number already uploaded: **App Store Connect → Carmenta → Xcode Cloud → Settings → Build Number**.

References: [distribution setup](https://developer.apple.com/documentation/xcode/distributing-your-xcode-cloud-builds-through-testflight), [distribution workflow settings](https://developer.apple.com/documentation/xcode/creating-a-workflow-that-builds-your-app-for-distribution), [build numbering](https://developer.apple.com/documentation/xcode/setting-the-next-build-number-for-xcode-cloud-builds).

## 6. Install through TestFlight

For your own first install, open **App Store Connect → Carmenta → TestFlight**, create an internal group, add yourself as an eligible App Store Connect user, and add the processed build. Install Apple’s **TestFlight** app from the Mac App Store and accept the invitation with the corresponding Apple Account.

For a poet who is not on your App Store Connect team, use **External Testing**. Create an external group after the internal group exists, supply the beta description, feedback email, contact details, and what to test, then add the build and submit it for TestFlight App Review. Apple reviews the first external build; later builds may also need review. After approval, invite testers by email or a TestFlight link. They do not need a developer membership. Follow Apple’s [external testing guide](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/).

## Data and release checks

The sandboxed app stores its library at `~/Library/Containers/com.panopticoncentral.carmenta/Data/Library/Application Support/Carmenta/library.json`. The entitlement permits only user-selected file access in addition to the app’s container; it does not enable arbitrary disk access or networking. Export uses a native save panel.

Before inviting external testers, verify in the signed app that creating records, quitting/reopening, exporting JSON to a chosen folder, and any first-run migration all work. These exercise the sandbox and signing environment that unit tests and unsigned archives cannot fully validate. If you change the bundle ID, the container location changes too.

When you push later changes to `main`, the configured workflow builds, tests, archives, and distributes them according to its TestFlight post-action. Change `MARKETING_VERSION` in Xcode for a new app version; let Cloud keep build numbers increasing.
