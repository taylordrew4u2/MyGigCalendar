# SEE ME LIVE

**SEE ME LIVE is a published iOS App Store app for live performers who need one place to manage upcoming shows, keep their personal calendar current, and share professional public gig links with fans, bookers, and venues.**

This repository contains the native SwiftUI iOS app, CloudKit-backed persistence and sync layer, public calendar experience, iCalendar feed support, flyer/share-image studio, and automated tests.

## App Store Status

**Published on the iOS App Store.**

SEE ME LIVE is not a prototype or tutorial project. It is a real shipped iOS product with production concerns including persistence, iCloud sync, public data publishing, calendar integration, image generation, purchase-gated behavior, onboarding, privacy metadata, entitlements, and test coverage.

## Live Surfaces

- iOS app: distributed through Apple's App Store.
- Public performer calendar: `https://seemelive.vercel.app/?user=<USER_ID>`
- Subscribable iCalendar feed: `https://seemelive.vercel.app/calendar.ics?user=<USER_ID>`

The public web surfaces require a valid user ID from an installed app instance.

## Product Overview

SEE ME LIVE is the working calendar a touring performer keeps in their pocket. The app stores each gig with title, role, venue, date and time, price, ticket link, notes, and optional flyer artwork. It keeps the performer's private data synced across Apple devices, optionally writes matching events into iPhone Calendar, mirrors future-dated shows to a public CloudKit database, and powers a public web calendar that fans and bookers can open or subscribe to.

Primary user: a solo performer managing their own schedule.

Secondary users: fans, bookers, venues, and collaborators who receive the performer's public link.

## Problem

Performers often juggle dates across DMs, screenshots, group chats, email threads, ticketing pages, and venue calendars. Fans and bookers either cannot find the next show or land on out-of-date flyers. Keeping a personal calendar and a publishable show list in sync is repetitive enough that most performers stop doing it.

## Solution

The performer enters a show once. The app then:

1. Persists the private copy locally with Core Data.
2. Syncs private user data across the performer's Apple devices through CloudKit.
3. Optionally creates, updates, or deletes a matching iPhone Calendar event through EventKit.
4. Mirrors a sanitized public copy to CloudKit's public database.
5. Generates a public performer URL and subscribable calendar feed.
6. Provides a flyer studio for creating social-media-ready promotional images from the same show data.

## Core Features

- Add, edit, and delete shows with title, role, venue, date, time, price, ticket link, notes, and optional flyer image.
- Calendar-first home screen with month navigation, selected-date details, upcoming list, and past-show handling.
- Local search across title, venue, role, and notes.
- Private iCloud sync with `NSPersistentCloudKitContainer`.
- Public CloudKit mirror for shareable web calendars.
- EventKit integration for iPhone Calendar events and reminders.
- Offline-tolerant public sync with retry behavior.
- Photo library and camera flyer capture.
- JPEG downscaling for efficient CloudKit asset uploads.
- Flyer studio with social formats, templates, layout controls, overlays, colors, and export styles.
- Public web calendar powered by CloudKit JS.
- Subscribable iCalendar feed for Apple Calendar, Google Calendar, and other calendar clients.
- StoreKit-facing purchase state for watermark removal.
- Onboarding, splash, home, editor, detail, sharing, and export flows.
- Privacy manifest and entitlements configured for real App Store distribution.
- Unit tests for persistence, export, image generation, model helpers, and identity behavior.

## Technical Highlights

| Area | Implementation |
| --- | --- |
| Platform | Native iOS |
| Language | Swift |
| UI | SwiftUI |
| Minimum OS | iOS 17+ |
| Persistence | Core Data |
| Private Sync | `NSPersistentCloudKitContainer` |
| Public Data | CloudKit public database |
| Calendar Integration | EventKit |
| Photo Input | PhotosUI and camera capture |
| Purchases | StoreKit-facing purchase manager |
| Image Export | UIKit/Core Graphics rendering |
| Web Calendar | Static HTML/CSS/JavaScript with CloudKit JS |
| Calendar Feed | Vercel serverless `calendar.ics` endpoint |
| Tests | XCTest target |

## Architecture

```text
SEE ME LIVE iOS App
|
|-- SwiftUI screens
|   |-- SplashScreenView
|   |-- HomeScreenView
|   |-- ShowEditorView
|   |-- ShowDetailView
|   |-- ShareImageEditorView
|   |-- OnboardingWalkthroughView
|
|-- Local app data
|   |-- Core Data Show entity
|   |-- Persistence controller
|   |-- CloudKit private database sync
|
|-- External integrations
|   |-- CalendarService for EventKit
|   |-- PublicCloudSyncService for public CloudKit records
|   |-- PurchaseManager for paid feature state
|   |-- UserIdentityService for stable public identity
|
|-- Sharing
|   |-- ShareImageGenerator
|   |-- HTMLExportService
|   |-- docs/index.html public calendar
|   |-- docs/calendar.ics.js calendar feed endpoint
|
|-- Tests
    |-- PersistenceTests
    |-- HTMLExportServiceTests
    |-- ShareImageGeneratorTests
    |-- ShowExtensionsTests
    |-- UserIdentityServiceTests
```

## End-to-End Flow

1. The performer opens the app. `SEE_ME_LIVEApp` shows the splash flow, then `HomeScreenView`.
2. They add or edit a show in `ShowEditorView`, including optional flyer artwork.
3. The show is saved to Core Data. `NSPersistentCloudKitContainer` syncs the private copy to the performer's iCloud.
4. If calendar sync is enabled, `CalendarService` creates or updates an `EKEvent` and stores its identifier.
5. `PublicCloudSyncService` writes a public `PublicShow` record, plus a `CKAsset` for flyer artwork when present.
6. Failed public sync work is queued and retried on app launch and foreground.
7. A visitor opens the performer's public URL. `docs/index.html` queries public CloudKit records and renders upcoming shows grouped by month.
8. A visitor can subscribe to the schedule through `calendar.ics`, which returns a generated iCalendar feed.

## What This Project Demonstrates

- Shipping a native iOS app to the App Store.
- Designing a complete SwiftUI app with production screens and user flows.
- Modeling durable local data with Core Data.
- Syncing private app data across devices with CloudKit.
- Separating private user data from public shareable records.
- Integrating Apple system services such as iCloud, Calendar, Photos, and StoreKit-facing purchase state.
- Building a custom social image generation workflow.
- Handling async work, offline-friendly retries, and public data publishing.
- Building a companion public web surface and calendar feed.
- Writing tests around persistence, formatting, identity, and export logic.
- Maintaining privacy metadata, entitlements, and project structure required for App Store distribution.

## Repository Structure

```text
SEE ME LIVE/
├── SEE ME LIVE/                       # Main iOS app source
│   ├── SEE_ME_LIVEApp.swift           # App entry point
│   ├── SplashScreenView.swift         # Launch/splash flow
│   ├── HomeScreenView.swift           # Calendar-first dashboard
│   ├── ShowEditorView.swift           # Add/edit show workflow
│   ├── ShowDetailView.swift           # Show detail screen
│   ├── ShareImageEditorView.swift     # Flyer studio and export UI
│   ├── ShareImageGenerator.swift      # Promotional image rendering
│   ├── CalendarService.swift          # EventKit integration
│   ├── PublicCloudSyncService.swift   # Public CloudKit sync and retry logic
│   ├── Persistence.swift              # Core Data and CloudKit stack
│   ├── PurchaseManager.swift          # Paid feature state
│   ├── UserIdentityService.swift      # Stable public identity handling
│   ├── HTMLExportService.swift        # Public calendar/export helpers
│   ├── DateTextSizeSheet.swift        # Date text size settings UI
│   ├── BrandLogoView.swift            # SwiftUI brand mark
│   ├── Show+Extensions.swift          # Show model convenience behavior
│   ├── PrivacyInfo.xcprivacy          # App privacy manifest
│   ├── SEE_ME_LIVE.entitlements       # iCloud/CloudKit entitlements
│   ├── Info.plist                     # Usage descriptions and app metadata
│   ├── Assets.xcassets/               # App icons, colors, and image assets
│   └── SEE_ME_LIVE.xcdatamodeld/      # Core Data model
├── SEE ME LIVETests/                  # Unit tests
│   ├── HTMLExportServiceTests.swift
│   ├── PersistenceTests.swift
│   ├── ShareImageGeneratorTests.swift
│   ├── ShowExtensionsTests.swift
│   └── UserIdentityServiceTests.swift
├── docs/                              # Public web calendar and feed endpoint
│   ├── index.html
│   └── calendar.ics.js
├── SEE ME LIVE.xcodeproj/
├── CALENDAR_FEED_SETUP.md
├── CLOUDKIT_SETUP.md
├── vercel.json
└── README.md
```

## How to Run Locally

Prerequisites:

- macOS with Xcode 15 or later
- iOS 17+ simulator or device
- Apple Developer account for CloudKit/App Store capabilities
- Node.js 18+ to run the `calendar.ics` function locally

iOS app:

```bash
git clone https://github.com/taylordrew4u2/seemelive.git
cd seemelive
open "SEE ME LIVE.xcodeproj"
```

Public web calendar:

```bash
npx vercel dev
```

CloudKit and calendar feed setup details are documented in:

- `CLOUDKIT_SETUP.md`
- `CALENDAR_FEED_SETUP.md`

## Testing

Run the `SEE ME LIVETests` target from Xcode.

The test suite covers:

- Core Data persistence behavior
- HTML export behavior
- Share image generation behavior
- Show model convenience extensions
- User identity generation and stability

## Notes for Employers

This codebase shows end-to-end product execution: native app development, Apple framework integration, cloud sync, public data publishing, production distribution, and testable app architecture. The project also reflects real-world tradeoffs around offline behavior, privacy boundaries, App Store requirements, and user-facing polish.

## About

Built and shipped by Taylor Drew as a production iOS app for performers.
