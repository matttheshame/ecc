---
name: uploading-ios-builds-to-testflight
description: Use when an iOS build must reach TestFlight through an agent driving a Mac (often over SSH), when codesign fails with errSecInternalComponent, when xcodebuild -exportArchive fails with "Cloud signing permission error" or "No profiles for '<bundle id>' were found", or when bumping the build number of an XcodeGen project without running xcodegen.
---

# Uploading iOS builds to TestFlight

## Overview

Signing needs the owner's unlocked login keychain, and the Apple account may not be
allowed cloud-managed signing. What works: archive in the owner's logged-in session,
export with manual signing and an App Store profile, upload with `altool` and an App
Store Connect API key.

## Quick reference

| Symptom | Cause | Do |
|---|---|---|
| `errSecInternalComponent` at codesign, over SSH | The login keychain is locked in an SSH session | Run `xcodebuild` in the owner's logged-in GUI session: a LaunchAgent the Mac agent set up, or Xcode. Never ask for the login password to `security unlock-keychain`: that hands the owner's password to an agent and to logs |
| `exportArchive Cloud signing permission error`, then `No profiles for '<bundle id>' were found` (automatic signing, `destination` upload) | The account cannot use cloud-managed distribution certificates | Manual signing with the local Apple Distribution certificate and an App Store profile. Retrying automatic signing changes nothing |
| The uploaded build is not flagged "internal only" | Seen with the manual-signing path. The export option `testFlightInternalTestingOnly` was only tried with automatic signing, which failed | Never add an external group or "Submit for Review" without the owner's go: the owner adds the build to an internal group |

## Steps

1. **Build number.** In an XcodeGen project with a committed `.xcodeproj`, change it in
   both places, so nobody needs `xcodegen` on the Mac:

   ```bash
   sed -i 's/    CURRENT_PROJECT_VERSION: "2"/    CURRENT_PROJECT_VERSION: "3"/' project.yml
   sed -i 's/CURRENT_PROJECT_VERSION = 2;/CURRENT_PROJECT_VERSION = 3;/' App.xcodeproj/project.pbxproj
   ```

   - This is GNU `sed`. On macOS, write `sed -i ''`.
   - Check that both files changed (`git diff --stat`).
   - Do the same for `MARKETING_VERSION`. `Info.plist` reads `$(CURRENT_PROJECT_VERSION)`.
   - Commit it on its own (`chore(release): build 3 of 1.1.0, for TestFlight`).
2. **First upload of a new app only.** The owner creates the app in App Store Connect,
   because the API cannot: My Apps → + → New App, with the bundle id and a SKU. Register
   the bundle id first if it is not listed. Then make an App Store distribution profile
   for it.
3. **Archive**, in the GUI session:

   ```bash
   xcodebuild archive -project App.xcodeproj -scheme App -configuration Release \
     -destination 'generic/platform=iOS' -archivePath ~/Developer/builds/App-1.1.0-3.xcarchive \
     -allowProvisioningUpdates DEVELOPMENT_TEAM=<team id>
   ```

4. **Export.** Use an `ExportOptions.plist` with:
   - `method` = `app-store-connect`;
   - `signingStyle` = `manual`;
   - `signingCertificate` = `Apple Distribution`;
   - `teamID`;
   - `provisioningProfiles` = { bundle id: App Store profile name }.

   Then run `xcodebuild -exportArchive -archivePath … -exportPath … -exportOptionsPlist ExportOptions.plist`.
5. **Upload:** `xcrun altool --upload-app -f App.ipa -t ios --apiKey <key id> --apiIssuer <issuer id>`.
   - The `.p8` key lives in `~/.appstoreconnect/private_keys/`.
   - If this Xcode's `altool --help` drops `--upload-app`, use `--upload-package`.
   - Keep the Delivery UUID.
6. Apple processes the build for 10 to 30 minutes. Then the owner adds it to an internal
   group, writes "What to Test" and installs it from the TestFlight app.

## Writing the directive for the Mac agent

The directive has these parts, in order:

1. Repo, branch, and the commit expected after `git pull`, with version and build.
2. Where to work: the logged-in session, not SSH.
3. The commands above, and one check on the simulator. Only one simulator at a time.
4. The limits:
   - a compile error comes back verbatim, with no workaround;
   - no external group, no "Submit for Review".
5. What to report: commit, archive warnings, export and upload output, Delivery UUID,
   screenshots.

## Common mistakes

- **Only `project.yml` bumped.** The committed `project.pbxproj` keeps the old build
  number, and App Store Connect rejects the duplicate.
- **`Package.resolved` committed after a Linux `swift build` or `swift test`.** These
  commands rewrite it. Restore it with `git checkout`.
- **"Ready for TestFlight" claimed for SwiftUI code never compiled.** Linux cannot
  compile SwiftUI, so say that the Mac build is the first compile.
