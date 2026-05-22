# SEE ME LIVE

A SwiftUI iPhone app that lets live performers track their upcoming shows, sync them to their personal iPhone calendar, and publish a public, bookable calendar that fans and bookers can subscribe to from any calendar app.

## Live Demo

- iOS app: distributed via the App Store / TestFlight (not open to the public from this repo).
- Public web calendar (one performer at a time, keyed by user ID): `https://seemelive.vercel.app/?user=<USER_ID>`
- iCalendar feed (subscribable): `https://seemelive.vercel.app/calendar.ics?user=<USER_ID>` (served via `docs/calendar.ics.js` as a Vercel serverless function).

The web surfaces require a valid user ID from an installed app instance.

## Screenshots

TODO: Add screenshots of the calendar home, show editor, show detail, flyer studio, and the public performer profile.

## Overview

SEE ME LIVE is the working calendar a touring performer keeps in their pocket. The app stores each gig (title, role, venue, date and time, price, ticket link, notes, and optional flyer image), keeps the data in sync across the performer's own devices, optionally writes a corresponding event into the iPhone Calendar, and mirrors the future-dated shows to a public CloudKit database. A static web page then queries that database with CloudKit JS so fans, bookers, and venues can see upcoming dates, click through to ticket links, or subscribe to the schedule from Apple Calendar, Google Calendar, or any iCalendar-compatible app.

Primary user: solo performer (the app is built around a single performer's schedule). Secondary users: anyone the performer shares their public link with.

## Problem

Performers juggle dates across DMs, screenshots, group chats, and venue calendars. Bookers and fans either don't know where to find the next show or land on out-of-date flyers. Keeping a personal calendar and a publishable list of shows in sync, with assets and ticket links attached, is fiddly enough that most performers stop doing it.

## Solution

The performer enters a show once. The app then:

1. Persists it locally with Core Data and syncs the private copy across the performer's devices via CloudKit.
2. Optionally writes a calendar event into iOS Calendar via EventKit, with an optional one-hour reminder.
3. Mirrors a sanitized copy to the CloudKit public database so a static web page can read it without authentication.
4. Generates a shareable performer URL and an iCalendar feed URL that any calendar app can subscribe to.
5. Provides a flyer studio that turns the same data into social-media-sized share images.

## Features

- Add, edit, and delete shows with title, role, venue, date and time, price, ticket link, notes, and an optional flyer image.
- Calendar-first home screen with a month view, selectable date, upcoming list, and collapsible past shows.
- Local search across title, venue, role, and notes.
- Private CloudKit sync of personal show data across the performer's own devices via `NSPersistentCloudKitContainer`.
- Public CloudKit mirror of upcoming shows so the web page can render them without an Apple ID.
- EventKit integration that creates, updates, and deletes matching iPhone Calendar events, with optional one-hour reminders.
- Offline-tolerant public sync: failed CloudKit operations are queued and retried on launch and on foreground.
- Photo library and camera flyer capture, with JPEG downscaling to keep CloudKit asset uploads cheap.
- Flyer studio (`ShareImageEditorView`) that composites shows onto social-sized backgrounds (IG Story, IG Post, TikTok, X, Facebook, link preview cards) with template, layout, text, color, and image controls.
- Public web calendar (`docs/index.html`) that loads shows from CloudKit via CloudKit JS, groups them by month, and surfaces a subscribe row (Apple Calendar via `webcal://`, Google Calendar URL, copy-feed-link).
- Serverless `calendar.ics` endpoint (`docs/calendar.ics.js`) that re-issues the public CloudKit data as a valid iCalendar feed.
- Privacy manifest (`PrivacyInfo.xcprivacy`) declared for App Store submission.

## Tech Stack

- Language: Swift 5
- UI: SwiftUI (iOS 17+)
- Persistence: Core Data with `NSPersistentCloudKitContainer` (private iCloud sync)
- Public sync: CloudKit (public database) via `CKContainer` / `CKRecord` / `CKAsset`
- Calendar: EventKit (`EKEventStore.requestFullAccessToEvents`)
- Photos: PhotosUI (`PhotosPicker`) plus a `UIImagePickerController` camera wrapper
- Image rendering: UIKit (`UIGraphicsImageRenderer`) for downscale and flyer composition
- Web page: vanilla HTML, CSS, JavaScript, CloudKit JS CDN
- iCalendar feed: Node.js serverless function (`cloudkit` Node SDK) deployed to Vercel
- Hosting: Vercel (`vercel.json` routes `/calendar.ics` to the function and serves `docs/` as static)
- Build system: Xcode 15+ project with `PBXFileSystemSynchronizedRootGroup` (files added by virtue of being in the folder)

No package manager file (SPM/CocoaPods/Carthage) is checked in; the app uses only Apple frameworks.

## Architecture

```
SEE ME LIVE/
├── SEE ME LIVE/                       # iOS app source
│   ├── SEE_ME_LIVEApp.swift           # @main App entry, splash → home
│   ├── SplashScreenView.swift         # Quiet launch view
│   ├── HomeScreenView.swift           # Calendar-first dashboard
│   ├── ShowEditorView.swift           # Add / edit form, photo picker
│   ├── ShowDetailView.swift           # Show detail, ticket CTA, share
│   ├── ShareImageEditorView.swift     # Flyer studio (templates + canvas)
│   ├── ShareImageGenerator.swift      # Social-size flyer rendering
│   ├── HTMLExportService.swift        # HTML export + CalendarDisplayOptions
│   ├── DateTextSizeSheet.swift        # Date text size setting
│   ├── BrandLogoView.swift            # Brand mark drawn in SwiftUI
│   ├── Show+Extensions.swift          # Safe accessors / derived display
│   ├── Persistence.swift              # NSPersistentCloudKitContainer
│   ├── PublicCloudSyncService.swift   # Public CK CRUD + offline queue
│   ├── CalendarService.swift          # EventKit wrapper
│   ├── UserIdentityService.swift      # Per-install UUID
│   ├── ContentView.swift              # Vestigial stub (no longer referenced)
│   ├── Assets.xcassets/               # Icon, accent, AppBackground, CardBackground
│   ├── SEE_ME_LIVE.xcdatamodeld/      # Show entity, CloudKit-compatible
│   ├── SEE_ME_LIVE.entitlements      # CloudKit entitlement
│   ├── PrivacyInfo.xcprivacy          # Privacy manifest
│   └── Info.plist                     # Usage descriptions + background modes
├── SEE ME LIVETests/                  # XCTest target
│   ├── HTMLExportServiceTests.swift
│   ├── PersistenceTests.swift
│   ├── ShareImageGeneratorTests.swift
│   ├── ShowExtensionsTests.swift
│   └── UserIdentityServiceTests.swift
├── docs/                              # Public site (served by Vercel + GitHub Pages compatible)
│   ├── index.html                     # CloudKit JS performer profile
│   └── calendar.ics.js                # Vercel serverless ICS endpoint
├── SEE ME LIVE.xcodeproj/
├── vercel.json                        # Routes /calendar.ics + static docs/
├── CALENDAR_FEED_SETUP.md             # Setup notes for the ICS endpoint
├── CLOUDKIT_SETUP.md                  # CloudKit container / schema notes
└── README.md
```

End-to-end flow in plain English:

1. The performer opens the app. `SEE_ME_LIVEApp` shows the splash, then `HomeScreenView`.
2. They tap **Add show**. `ShowEditorView` opens, the form is filled in, an optional flyer is picked.
3. On save, the `Show` is written to Core Data. `NSPersistentCloudKitContainer` syncs the private copy to the performer's own iCloud.
4. If the user kept **Add to Calendar** on, `CalendarService` creates an `EKEvent` and stores its identifier on the Show.
5. The Show is flagged `needsPublicSync = true`. `PublicCloudSyncService` writes a `PublicShow` record (and a `CKAsset` for the flyer if present) to the CloudKit public database. Failures stay in the queue and are retried on launch / foreground.
6. The performer shares their public URL. A visitor opens `https://seemelive.vercel.app/?user=<id>`. `docs/index.html` configures CloudKit JS and queries `PublicShow` records for that user ID, sorted by date, and renders them grouped by month.
7. The visitor can also subscribe via Apple Calendar or Google Calendar. Their calendar app then hits `https://seemelive.vercel.app/calendar.ics?user=<id>`, which `docs/calendar.ics.js` answers with a generated iCalendar feed.

## How to Run Locally

Prerequisites:

- macOS with Xcode 15 or later
- An iPhone simulator or device running iOS 17+
- An Apple Developer account if you want to test CloudKit sync against your own container
- Node.js 18+ if you want to test the `calendar.ics` function locally with Vercel

iOS app:

```bash
git clone https://github.com/taylordrew4u2/seemelive.git
cd seemelive
open "SEE ME LIVE.xcodeproj"
```

Then in Xcode, select the **SEE ME LIVE** scheme, pick a simulator or device, and **Run**. Tests run with **Product → Test** (`⌘U`).

The app will launch and function without CloudKit, but no public sharing or iCloud sync will succeed until the CloudKit container is configured. See `CLOUDKIT_SETUP.md` for the container, schema, and API token setup, and `CALENDAR_FEED_SETUP.md` for the public feed.

Public web page (static):

```bash
cd docs
python3 -m http.server 8000
# Open http://localhost:8000/?user=<your user id>
```

Public web page + ICS feed via Vercel (recommended for the feed):

```bash
npm install -g vercel
vercel dev
# Visit http://localhost:3000/?user=<your user id>
# Feed:  http://localhost:3000/calendar.ics?user=<your user id>
```

## Environment Variables

The iOS app does not require any environment variables. The web side reads one:

```bash
CLOUDKIT_API_TOKEN=        # CloudKit Web Services API token for the public DB
```

If unset, `docs/calendar.ics.js` falls back to a baked-in token. See **Security** below.

## Usage

After installing the app on a device or simulator:

1. The first launch generates a stable per-install user ID (stored via `UserIdentityService`).
2. Tap **Add show** on the home calendar.
3. Fill in title (required), role, venue, date and time, optional price, ticket link, and notes. Optionally attach a flyer.
4. Leave **Add to Calendar** on if you want an iPhone Calendar event created. Toggle **Reminder** to add a one-hour heads-up.
5. Save. The show appears under the selected date and in **Upcoming**.
6. From the toolbar overflow menu, pick **Create flyer** to open the flyer studio and export a social-sized image.
7. Share your public URL (`https://seemelive.vercel.app/?user=<your id>`) or the iCalendar feed URL with fans and bookers.

## What I Built

- Designed and implemented the SwiftUI calendar-first home screen, including the month view, weekday-aware day grid, search, selected-day section, upcoming list, and collapsible past section.
- Wrote `PublicCloudSyncService`: an offline-tolerant queue that handles `CKRecord` create / update / delete against the public database, marshals optional flyer images into `CKAsset` via temporary files, and persists pending-delete IDs in `UserDefaults` so deletes survive Core Data deletion.
- Wrote `CalendarService`: a wrapper around `EKEventStore.requestFullAccessToEvents` with create/update/delete keyed by a `calendarEventID` stored on each Show.
- Built `ShowEditorView` with form-style sections, keyboard focus traversal, photo library + camera picker, off-main JPEG downscaling, and a calendar-access denial path that deep-links to Settings.
- Built `ShareImageEditorView` and `ShareImageGenerator`: a multi-tab flyer studio that composites a performer's shows onto social-sized canvases (IG, TikTok, X, Facebook, link preview) with template, layout, text, color, and background controls.
- Built the public web page (`docs/index.html`): CloudKit JS query, month grouping, hairline-bordered date rows, a subscribe row that wires Apple Calendar (`webcal://`), Google Calendar add-by-URL, and a clipboard copy-feed button.
- Wrote `docs/calendar.ics.js`: a Vercel serverless function that reissues the public CloudKit data as a conformant iCalendar feed.
- Set up the Core Data model for CloudKit compatibility (`usedWithCloudKit="true"`, external binary storage on the flyer attribute) and the entitlements / Info.plist permissions.
- Wrote unit tests covering Show extensions, identity generation, persistence, HTML export, and share image generation.
- Did a design pass that unified the product visually around hairline borders, one accent, and system typography across the iOS app and the public web page.

## Technical Decisions

- **SwiftUI + Core Data + `NSPersistentCloudKitContainer`** for the private layer. Free per-user iCloud sync, no server to operate, and the entity / fetch request model maps cleanly onto SwiftUI's `@FetchRequest`.
- **A separate public CloudKit database** (rather than reusing the private one) so the web page can read with a public API token instead of OAuth. Each `Show` carries a `needsPublicSync` flag plus a `publicRecordID` so the mirror can be updated or deleted later.
- **Queue + UserDefaults for pending deletes.** Deletes of the local `Show` would otherwise remove the `publicRecordID` along with the row, so the public delete is recorded in `UserDefaults` before the Core Data object goes away. The queue flushes on launch and on `willEnterForegroundNotification`.
- **CloudKit JS on a static page** for the public surface. No backend; the page configures CloudKit JS against the public container, filters by `userID`, sorts by date, and renders. Adding bookers / fans does not require an Apple ID.
- **Separate `calendar.ics` Node function** so subscribers can use Apple Calendar / Google Calendar / Outlook without visiting the page. Vercel routes `/calendar.ics` to the function and serves `docs/` otherwise.
- **JPEG downscale before persistence.** Flyers are downscaled to a max dimension of 1600px and re-encoded at 0.75 quality on a background queue, then assigned on the main thread. This keeps Core Data row size and CloudKit asset uploads small.
- **Xcode synchronized file groups (`PBXFileSystemSynchronizedRootGroup`)** so adding or deleting a `.swift` file does not require editing `project.pbxproj`. This made the redesign and the dead-code cleanup low-friction.
- **Modern minimal visual system** (hairline borders, single accent, system typography) applied across the app and the public page so the same data feels like one product whether the viewer is the performer, a fan, or a booker.

## Challenges Solved

- **Bridging Core Data deletes to CloudKit deletes.** Once the local `Show` is deleted, its `publicRecordID` is gone, so the public delete cannot read it back. Solved by recording pending deletes in `UserDefaults` before tearing down the Core Data object, and reconciling them through the same retry queue that handles failed creates and updates. This keeps the public web page in sync even when the user deletes a show offline.
- **Calendar permission UX on iOS 17.** `EKEventStore` permission semantics changed with `requestFullAccessToEvents`. The editor delays the permission prompt until the user actually saves a show with the calendar toggle on, and degrades to a settings-redirect alert if the user denies. This avoids burning the prompt at launch.
- **Photo capture pipeline.** Decoding, downscaling, and re-encoding flyer images on the main thread would jank the editor. The pipeline hops to a global QoS queue for decode + downscale, then jumps back to the main actor to assign to the binding, keeping the form responsive.
- **One-screen flyer authoring.** The flyer studio needs a live preview, draggable text overlays, and template / layout / text / color / image controls without overwhelming the canvas. Solved with a pinned preview, a debounced regeneration task, a quick action bar, and a five-tab control surface that defaults to **Templates** so a one-tap export is reachable.

## Testing

The repo contains an XCTest target (`SEE ME LIVETests`) with the following:

- `ShowExtensionsTests.swift` — derived display fields (`titleOrEmpty`, `dateFormatted`, `relativeDateLabel`, `normalizedTicketURL`, etc.).
- `UserIdentityServiceTests.swift` — UUID generation and persistence.
- `PersistenceTests.swift` — Core Data stack and `Show` create / fetch / delete.
- `HTMLExportServiceTests.swift` — `CalendarDisplayOptions` codable defaults plus rendered HTML output.
- `ShareImageGeneratorTests.swift` — social size presets and flyer rendering output.

Run tests:

```bash
# In Xcode
Product → Test  (⌘U)

# From the command line
xcodebuild test \
  -project "SEE ME LIVE.xcodeproj" \
  -scheme "SEE ME LIVE" \
  -destination "platform=iOS Simulator,name=iPhone 15"
```

Coverage is not currently measured automatically. Manual testing should additionally cover:

- The first-launch path with no shows.
- The CloudKit-offline path: add a show with the network off, then go online and confirm the public mirror catches up.
- The Calendar-permission-denied path.
- Editing and deleting a show that was previously synced to the public DB.
- The public web page against a populated user ID, in both light and dark mode.
- Subscribing to the `calendar.ics` feed from Apple Calendar and Google Calendar.

## Security

- The CloudKit private database is protected by the user's own Apple ID; the app does not store private credentials.
- The CloudKit public database is intentionally world-readable; only future-dated shows that the user explicitly saves are mirrored there.
- Calendar, camera, and photo library access are gated by iOS permission prompts with usage strings declared in `Info.plist`.
- A privacy manifest (`PrivacyInfo.xcprivacy`) is included for App Store submission.
- Build artifacts and user-specific Xcode state are ignored via `.gitignore`.
- The repository currently contains a hard-coded CloudKit Web Services API token in `docs/index.html` and as a fallback in `docs/calendar.ics.js`. CloudKit web tokens are designed to be publicly distributable and are rate-limited, but rotating that token and supplying it only via the `CLOUDKIT_API_TOKEN` environment variable (for the serverless function) and via a build-time injection (for the static page) would be a stronger posture.
- There is no end-user authentication on the public web page. Anyone with a user ID URL can read that performer's future shows by design.

Further security hardening (token rotation, build-time injection of CloudKit identifiers, CSP headers on the static page) is a future improvement.

## Accessibility

- All primary actions use standard SwiftUI controls, which inherit Dynamic Type and VoiceOver behavior.
- The splash screen exposes a combined accessibility label.
- The redesign uses hairline borders and system colors that respect light and dark mode and high-contrast settings.
- The public web page uses semantic HTML (`header`, `section`, `article`, `h1`–`h3`), labeled buttons and links, and a responsive layout for narrow viewports.

A full accessibility audit (VoiceOver flow, Dynamic Type at XXXL, color contrast measurements across the flyer studio dark canvas, keyboard navigation on the web page) has not been completed and is a future improvement.

## Known Limitations

- The app is built around a single performer per install; there is no multi-account or team mode.
- The public web page hard-codes the CloudKit container ID and API token; a self-hosted deploy requires editing `docs/index.html` and `docs/calendar.ics.js`.
- The flyer studio is iPhone-shaped — it works on iPad but is not tuned for the larger canvas.
- Automated test coverage is meaningful for service-layer code but does not include UI tests.
- There is no CI workflow in this repo; tests must be run locally.
- The `graphite-demo/` folder and `.github/agents/hu.agent.md` are unrelated to the product and should be cleaned up (see **Repo presentation** below).
- No license file is included.

## Roadmap

- Add a GitHub Actions workflow that runs `xcodebuild test` on push.
- Rotate the CloudKit web token and inject it at build time instead of committing it.
- Add UI tests for the editor and flyer studio.
- Add screenshots and a short demo video to the README.
- Add a `LICENSE` file (likely MIT or proprietary, owner's choice).
- Add a `SECURITY.md` describing how to report vulnerabilities.
- Promote a clearer empty state on the public web page for performers with no upcoming shows.
- Expand accessibility coverage and run a Dynamic Type / VoiceOver audit.
- Remove the `graphite-demo/` directory and the `.github/agents/hu.agent.md` placeholder, or move them out of this repo.

## Status

**Active.** The iOS app, the public web page, and the iCalendar feed are working end-to-end. The product is in iteration, with a recent redesign pass landed on `main` (see commit history) and follow-up cleanup removing dead code.

## License

No license has been added yet. Until a `LICENSE` file is committed, the default is "all rights reserved" by the author.

---

## Repo presentation suggestions

These are not part of the README itself, but should accompany this PR.

**Suggested short repository description** (for the GitHub sidebar):

> SwiftUI iPhone app for live performers to track shows, sync them to iPhone Calendar, and publish a public, subscribable calendar via CloudKit.

**Suggested repository topics:**

`ios`, `swiftui`, `swift`, `core-data`, `cloudkit`, `eventkit`, `icalendar`, `vercel`, `cloudkit-js`, `performers`, `calendar`, `comedy`

**Files worth removing or relocating:**

- `graphite-demo/server.js` — unrelated Express demo with hard-coded fake task data. Either delete or move to a separate sandbox repo.
- `.github/agents/hu.agent.md` — appears to be a Copilot/agent placeholder with a long design brief baked in. Either flesh it out into a real agent definition or remove.
- `SEE ME LIVE/ContentView.swift` — currently a comment-only stub left from earlier cleanup. Safe to delete since `SEE_ME_LIVEApp` no longer references it.

**Additions worth making:**

- `LICENSE` file (MIT is a common employer-friendly default; pick the one that matches the owner's intent).
- `SECURITY.md` describing how to report issues.
- `.github/workflows/ci.yml` running `xcodebuild test` on macOS runners; add a status badge to the top of this README once it exists.
- A `screenshots/` folder with at least: calendar home, show editor, show detail, flyer studio, public web page. Reference them in the **Screenshots** section above.
- A short demo GIF for the flyer studio if possible — it is the most visually compelling surface in the app.
