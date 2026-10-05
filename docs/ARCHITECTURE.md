# Architecture

Reference notes for My Gig Calendar's services, data model, and public CloudKit schema. For setup steps see [`CLOUDKIT_SETUP.md`](../CLOUDKIT_SETUP.md) and [`CALENDAR_FEED_SETUP.md`](../CALENDAR_FEED_SETUP.md).

## Services

### PersistenceController (`Persistence.swift`)
Owns the Core Data stack, built on `NSPersistentCloudKitContainer`. All show data lives here and syncs to the performer's private iCloud database. Uses `NSMergeByPropertyObjectTrumpMergePolicy` so local edits are not overwritten during sync.

### PublicCloudSyncService (`PublicCloudSyncService.swift`)
Writes shows to the CloudKit **public** database — the records behind the web calendar and the `.ics` feed. Shows that fail to sync are flagged with `needsPublicSync` (or `pendingPublicDelete` for deletions) and retried on the next launch or foreground transition.

### CalendarService (`CalendarService.swift`)
EventKit wrapper. Maintains a dedicated "My Gig Calendar" calendar, adds an optional one-hour reminder, and stores the `EKEvent` identifier on each show so later edits update the same event instead of creating duplicates.

### UserIdentityService (`UserIdentityService.swift`)
Generates a stable UUID on first launch and attaches it to every public record. It becomes the `?user=` parameter of the performer's public calendar URL.

### PurchaseManager (`PurchaseManager.swift`)
StoreKit 2 in-app purchase for watermark removal (`comedy.SEEMELIVE.remove_watermark`). Listens for transaction updates and caches the entitlement so it holds across launches without a network call.

### ShareImageGenerator (`ShareImageGenerator.swift`)
Renders flyers with `UIGraphicsImageRenderer` from a show, a size preset, a background style, and a list of text-overlay descriptors. Video backgrounds are composited in `ShareImageEditorView.swift` with `AVMutableVideoComposition`.

### FlyerTextExtractionService (`FlyerTextExtractionService.swift`)
On-device OCR for flyer import: Vision's `VNRecognizeTextRequest` reads the text, then `NSDataDetector` and heuristics pull out a title, venue, and date to prefill the show editor.

### Siri & Shortcuts (`SiriIntents.swift`)
App Intents for adding a gig, opening the add-gig screen, and listing upcoming gigs, exposed through an `AppShortcutsProvider`.

## Data model

The Core Data `Show` entity has 18 attributes:

| Attribute | Type | Notes |
|-----------|------|-------|
| `title` | String | Required |
| `venue` | String | Required |
| `date` | Date | Required |
| `role` | String? | Headliner, Feature, etc. |
| `price` | Double? | Ticket price |
| `ticketLink` | String? | URL |
| `notes` | String? | Free-form notes |
| `flyerImageData` | Binary? | JPEG, external storage |
| `calendarEventID` | String? | EKEvent identifier |
| `publicRecordID` | String? | CloudKit record name |
| `userID` | String | Stable UUID from UserIdentityService |
| `addToCalendar` | Boolean | Default: YES |
| `setReminder` | Boolean | Default: NO |
| `needsPublicSync` | Boolean | Offline retry flag |
| `pendingPublicDelete` | Boolean | Offline delete queue |
| `lastPublicSyncError` | String? | Last sync error |
| `createdAt` | Date | Required |
| `updatedAt` | Date | Required |

## Public CloudKit schema

The public database mirrors a subset of `Show` in a `PublicShow` record type, leaving out local-only fields such as `calendarEventID` and `needsPublicSync`.

| Field | Type |
|-------|------|
| `title` | String |
| `role` | String |
| `venue` | String |
| `date` | Date/Time |
| `price` | Double |
| `ticketLink` | String |
| `notes` | String |
| `userID` | String |
| `flyer` | Asset |

Indexes: `userID` (Queryable), `date` (Queryable, Sortable), `recordName` (Queryable).

## iCalendar feed

`docs/calendar.ics.js` is a Vercel serverless function (routed from `/calendar.ics` in `vercel.json`). It queries the public database for a `?user=` ID using `CLOUDKIT_API_TOKEN` and returns an RFC 5545 calendar. Each event carries the show title and role, date, venue as location, ticket link, notes, and a stable `UID` derived from the CloudKit record name so updates don't create duplicates.
