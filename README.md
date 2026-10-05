<div align="center">
  <img src="screenshots/app-icon-appstore.jpg" alt="My Gig Calendar app icon" width="120" />
  <h1>My Gig Calendar</h1>
  <p><strong>A native iOS calendar for live performers: add a show once and it reaches your devices, your fans, and your socials.</strong></p>

  [![App Store](https://img.shields.io/badge/App%20Store-Download-0D96F6?logo=app-store&logoColor=white)](https://apps.apple.com/us/app/my-gig-calendar/id6760590068)
  ![iOS 17+](https://img.shields.io/badge/iOS-17%2B-black?logo=apple)
  ![Swift](https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white)
  ![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-0066CC)
  ![CloudKit](https://img.shields.io/badge/sync-CloudKit-007AFF)
  [![iOS Build & Test](https://github.com/taylordrew4u2/MyGigCalendar/actions/workflows/ios.yml/badge.svg)](https://github.com/taylordrew4u2/MyGigCalendar/actions/workflows/ios.yml)
</div>

---

My Gig Calendar is a shipping iOS app for comedians, musicians, speakers, and anyone with a live show schedule. A performer enters a gig once; it syncs privately across their Apple devices, is published to a public fan-facing web calendar and subscribable `.ics` feed, and can be turned into a ready-to-post promotional flyer — all from one SwiftUI app built entirely on Apple frameworks.

**[Download on the App Store](https://apps.apple.com/us/app/my-gig-calendar/id6760590068)**

<div align="center">
  <img src="AppStore/screenshots/en-US/iphone-6.9/01-calendar.png" alt="Calendar home screen" width="260" />
  &nbsp;&nbsp;
  <img src="AppStore/screenshots/en-US/iphone-6.9/02-gig-details.png" alt="Gig details screen" width="260" />
</div>

## Features

**Show management**
- Calendar-first home screen with a month view, upcoming and past lists, and search across title, venue, role, and notes
- Shows carry venue, date, time, price, ticket link, performer role, notes, and a flyer photo
- **Flyer import:** photograph a show poster and the app reads the title, venue, and date to prefill the form (on-device OCR)
- **Siri & Shortcuts:** "Add a gig", "Open add gig", and "Show my gigs" via App Intents

**Sync and calendars**
- Private iCloud sync across devices with `NSPersistentCloudKitContainer`
- Public CloudKit mirror that powers a fan-facing web calendar
- Optional iPhone Calendar event per show, with an optional one-hour reminder
- Offline-resilient: failed public syncs and deletes are queued and retried

**Flyer studio**
- Six social size presets: IG Story and TikTok (9:16), IG Post (1:1), X/Twitter (16:9), Facebook and Link Preview (1.91:1)
- Gradient, dark, light, or custom backgrounds (solid color, gradient, photo, or video)
- Draggable text overlays with rotation, font, weight, size, color, shadow, and outline
- Export to the photo library; watermark removal is an in-app purchase

**Public calendar and feed**
- Every performer gets a shareable link: `https://seemelive.vercel.app/?user=<ID>`
- Shows grouped by month with role, price, and "Get tickets" links — no account needed to view
- One-tap subscribe for Apple Calendar (`webcal://`) and Google Calendar via an RFC 5545 `.ics` feed

<div align="center">
  <img src="screenshots/web-calendar-demo.png" alt="Public web calendar on mobile" width="240" />
  &nbsp;&nbsp;
  <img src="screenshots/web-calendar-desktop.png" alt="Public web calendar on desktop" width="520" />
</div>

## Tech Stack

| Layer | Technology |
|-------|-----------|
| App | Swift 5, SwiftUI, iOS 17+ |
| Persistence & private sync | Core Data + `NSPersistentCloudKitContainer` |
| Public data | CloudKit public database |
| System integration | EventKit, App Intents (Siri), PhotosUI, AVFoundation |
| Text recognition | Vision (`VNRecognizeTextRequest`) + `NSDataDetector` |
| Rendering | UIKit `UIGraphicsImageRenderer`, `AVMutableVideoComposition` |
| Purchases | StoreKit 2 |
| Web calendar | Static HTML/CSS/JS + CloudKit JS |
| Calendar feed | Node.js serverless function on Vercel |
| CI | GitHub Actions (`xcodebuild test` on macOS) |

No third-party Swift dependencies.

## Engineering Highlights

- **Two-database CloudKit design.** Private data syncs automatically through `NSPersistentCloudKitContainer`, while a separate service mirrors a deliberately reduced `PublicShow` record to the public database, so fans see only what's meant to be public.
- **Offline-first public sync.** Each show tracks `needsPublicSync` / `pendingPublicDelete` flags in Core Data; anything that fails to publish is retried on the next launch or foreground, so a performer can add gigs with no signal backstage.
- **Idempotent calendar integration.** The EventKit event ID is stored on each show, so edits update the same iPhone Calendar event; the `.ics` feed uses CloudKit record names as stable `UID`s for the same reason.
- **Stable public identity without accounts.** A UUID generated on first launch becomes the performer's public URL key — no sign-up flow.
- **Native media pipeline.** Flyers are rendered with Core Graphics at exact platform dimensions (e.g. 1080×1920, 1200×628); video backgrounds are composited with AVFoundation.
- **On-device flyer OCR.** Vision text recognition plus date detection and venue heuristics turn a poster photo into a prefilled show.
- **Zero-backend web layer.** The public calendar is a static page reading CloudKit directly; the only server code is a single serverless function for the `.ics` feed.

Deeper notes on each service, the Core Data model, and the CloudKit schema are in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Getting Started

**Prerequisites**
- macOS with Xcode 16 or later (the project uses the Xcode 16 project format)
- An Apple Developer account for the iCloud/CloudKit capabilities
- Node.js and the Vercel CLI, only if you want to run the web calendar and feed locally

```bash
git clone https://github.com/taylordrew4u2/MyGigCalendar.git
cd MyGigCalendar
open "SEE ME LIVE.xcodeproj"
```

Select the **SEE ME LIVE** scheme, choose a simulator or device, and press **Cmd+R**. CloudKit features need a signed-in iCloud account; the app checks availability at launch and disables sync when it's missing.

**CloudKit:** create the `iCloud.comedy.SEE-ME-LIVE` container and the `PublicShow` record type — full walkthrough in [`CLOUDKIT_SETUP.md`](CLOUDKIT_SETUP.md).

**Web calendar and feed:** set `CLOUDKIT_API_TOKEN`, then run locally with:

```bash
npx vercel dev
# Web calendar: http://localhost:3000/?user=<USER_ID>
# iCal feed:    http://localhost:3000/calendar.ics?user=<USER_ID>
```

Deployment details are in [`CALENDAR_FEED_SETUP.md`](CALENDAR_FEED_SETUP.md).

## Testing

100 XCTest cases across 9 test files cover persistence, the show editor's save logic, flyer rendering, HTML export, OCR parsing, user identity, and StoreKit purchases (using a local `.storekit` configuration).

```bash
xcodebuild test \
  -project "SEE ME LIVE.xcodeproj" \
  -scheme "SEE ME LIVE" \
  -destination "platform=iOS Simulator,name=iPhone 16,OS=latest"
```

Or press **Cmd+U** in Xcode. CI runs the same command on every push and pull request to `main`, skipping the one purchase test that needs a UI window scene to present the StoreKit sheet.

## Project Structure

```
MyGigCalendar/
├── SEE ME LIVE/             # iOS app: SwiftUI views, services, Core Data model, Siri intents
├── SEE ME LIVETests/        # XCTest suite and StoreKit test configuration
├── docs/                    # Public web calendar (index.html) and .ics serverless function
├── AppStore/                # App Store icon and screenshot assets
├── Tools/simulator-run/     # Script that drives the app in the Simulator for screenshots
├── .github/workflows/       # CI build/test and on-demand Simulator run
├── screenshots/             # README images
└── vercel.json              # Routes /calendar.ics to the serverless function
```

## Author

Built by **Taylor Drew** — [App Store](https://apps.apple.com/us/app/my-gig-calendar/id6760590068) · [GitHub](https://github.com/taylordrew4u2)
