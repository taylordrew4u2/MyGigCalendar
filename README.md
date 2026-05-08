# SEE ME LIVE

An iOS app for performers to log upcoming shows, automatically sync them to the iPhone calendar, and share a public link that displays all upcoming gigs in a clean calendar view.

---

## Features

- **Add / Edit / Delete shows** with title, venue, date/time, price, ticket link, flyer image, and notes.
- **Automatic iPhone calendar sync** via EventKit – creates calendar events with reminders.
- **Private iCloud sync** across all your devices via Core Data + NSPersistentCloudKitContainer.
- **Public CloudKit database** – every show is also saved to the public database so a web page can display it.
- **Shareable public link** – share a URL with fans/bookers that shows all your upcoming gigs.
- **Offline support** – failed public database operations are queued and retried automatically.

---

## Project Settings

| Setting                  | Value                   |
|--------------------------|-------------------------|
| Product Name             | SEE ME LIVE             |
| Team                     | Taylor Drew             |
| Organization Identifier  | comedy                  |
| Bundle Identifier        | comedy.SEE-ME-LIVE      |
| Interface                | SwiftUI                 |
| Language                 | Swift                   |
| Storage                  | Core Data               |
| Host in CloudKit         | ✅ Yes                  |

---

## Setup Instructions

### 1. Apple Developer Portal – CloudKit Container

1. Sign in to [Apple Developer](https://developer.apple.com/account/).
2. Go to **Certificates, Identifiers & Profiles** → **Identifiers**.
3. Select your App ID (`comedy.SEE-ME-LIVE`).
4. Under **Capabilities**, enable **iCloud** and check **CloudKit**.
5. Under **iCloud Containers**, create a new container: `iCloud.comedy.SEE-ME-LIVE`.
6. Assign this container to your App ID.

### 2. CloudKit Dashboard – Create PublicShow Record Type

1. Open the [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard/).
2. Select your container: `iCloud.comedy.SEE-ME-LIVE`.
3. Go to **Schema** → **Record Types** → **Create New Type**.
4. Name it: `PublicShow`.
5. Add the following fields:

| Field Name   | Type       | Notes               |
|--------------|------------|----------------------|
| `title`      | String     | Required             |
| `role`       | String     | Optional             |
| `venue`      | String     | Required             |
| `date`       | Date/Time  | Required             |
| `price`      | Double     | Optional             |
| `ticketLink` | String     | Optional             |
| `notes`      | String     | Optional             |
| `flyer`      | Asset      | Optional             |
| `userID`     | String     | Required (queryable) |

6. Under **Indexes**, add a **QUERYABLE** index on the `userID` field and a **SORTABLE** index on the `date` field.

### 3. CloudKit Dashboard – Set Permissions

1. In CloudKit Dashboard, go to **Schema** → **Security Roles**.
2. For the `PublicShow` record type:
   - **Authenticated** (iCloud users): **Create**, **Read**, **Write** (the app creates/updates/deletes its own records).
   - **World** (unauthenticated): **Read** (so the public web page can fetch shows without login).

### 4. CloudKit Dashboard – Create API Token

1. In CloudKit Dashboard, go to **API Access** → **API Tokens**.
2. Click **Create New Token**.
3. Name: `SEE ME LIVE Web` (or similar).
4. Sign In Type: **Web**.
5. Copy the generated API token.
6. Paste it into `docs/index.html` where it says `YOUR_CLOUDKIT_API_TOKEN`.
7. Also update the `CONTAINER_ID` constant if needed.

### 5. Deploy to CloudKit Production

1. In CloudKit Dashboard, go to **Deploy Schema Changes**.
2. Deploy the `PublicShow` record type and its indexes to the **Production** environment.
3. In `docs/index.html`, change `ENVIRONMENT` from `'development'` to `'production'`.

### 6. Host the Public Calendar on GitHub Pages

1. Create a new GitHub repository (e.g., `seemelive`).
2. Copy the `docs/` folder into the repository root.
3. Push to GitHub:
   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   git remote add origin https://github.com/YOURUSERNAME/seemelive.git
   git branch -M main
   git push -u origin main
   ```
4. Go to **Settings** → **Pages** in your GitHub repo.
5. Under **Source**, select **Deploy from a branch** → `main` → `/docs`.
6. Click **Save**. Your page will be live at:
   ```
   https://YOURUSERNAME.github.io/seemelive?user=YOUR_USER_ID
   ```
7. Update the calendar feed host in `docs/index.html` to match your GitHub Pages URL.

### 7. Update the Share Link in the App

The public profile URL is built directly from the user ID in `docs/index.html`. Change the `seemelive.vercel.app` host in that file if you are deploying to a different domain.

---

## Architecture Overview

```
┌─────────────────────────────────────────────┐
│              SEE ME LIVE App                │
│                                             │
│  ┌──────────┐  ┌────────────────────┐       │
│  │ SwiftUI  │  │  Core Data         │       │
│  │ Views    │──│  (Show entity)     │       │
│  └──────────┘  │  + CloudKit Sync   │       │
│                │  (private DB auto) │       │
│                └────────────────────┘       │
│                         │                   │
│         ┌───────────────┴──────────────┐    │
│         ▼                              ▼    │
│  ┌──────────────┐            ┌──────────┐   │
│  │ CalendarSvc  │            │ PublicCK  │   │
│  │ (EventKit)   │            │ SyncSvc   │   │
│  └──────────────┘            └──────────┘   │
│                                     │       │
└─────────────────────────────────────│───────┘
                                      ▼
                          ┌─────────────────────┐
                          │  CloudKit Public DB  │
                          │  (PublicShow records)│
                          └─────────┬───────────┘
                                    │
                                    ▼
                          ┌─────────────────────┐
                          │  GitHub Pages        │
                          │  (CloudKit JS)       │
                          │  Public calendar     │
                          └─────────────────────┘
```

---

## File Structure

```
SEE ME LIVE/
├── SEE ME LIVE/                    # App source
│   ├── SEE_ME_LIVEApp.swift        # App entry point
│   ├── ContentView.swift           # Main show list
│   ├── ShowEditorView.swift        # Add/Edit form
│   ├── ShowDetailView.swift        # Detail screen
│   ├── Show+Extensions.swift       # Convenience accessors
│   ├── Persistence.swift           # Core Data + CloudKit stack
│   ├── UserIdentityService.swift   # UUID generation
│   ├── CalendarService.swift       # EventKit integration
│   ├── PublicCloudSyncService.swift # Public CloudKit CRUD + queue
│   ├── Info.plist                  # Usage descriptions
│   ├── SEE_ME_LIVE.entitlements    # CloudKit entitlements
│   ├── SEE_ME_LIVE.xcdatamodeld/   # Core Data model (Show entity)
│   └── Assets.xcassets/            # App icon, accent color
├── docs/                           # Public web page
│   └── index.html                  # CloudKit JS calendar viewer
└── README.md                       # This file
```

---

## Key Implementation Notes

### Core Data Entity: `Show`
- Uses `NSPersistentCloudKitContainer` for automatic private iCloud sync.
- Attributes include `needsPublicSync` and `pendingPublicDelete` flags for the offline queue.
- `calendarEventID` stores the EKEvent identifier for updates/deletes.
- `publicRecordID` stores the CloudKit public record name for updates/deletes.
- `usedWithCloudKit="true"` is set in the model for CloudKit compatibility.

### Offline Queue
- When a public CloudKit operation fails (e.g., no network), the show is flagged with `needsPublicSync = true`.
- Pending deletes are stored in `UserDefaults` (since the Core Data object is deleted).
- The queue is flushed on app launch and when returning to the foreground.

### Calendar Integration
- Uses `EKEventStore.requestFullAccessToEvents()` (iOS 17+).
- Only requests permission when the user first saves a show with "Add to Calendar" ON.
- Gracefully handles denial with a Settings redirect.

### Image Handling
- Flyer images are stored as compressed JPEG binary data in Core Data.
- For the public database, images are converted to `CKAsset` via temporary files.
- The `allowsExternalBinaryDataStorage` flag is set for efficient large binary storage.

---

## Requirements

- **iOS 17.0+** (uses `requestFullAccessToEvents`, `ContentUnavailableView`)
- **Xcode 15+**
- **iCloud account** (required for CloudKit sync; app works locally without it)
- **Apple Developer account** (required for CloudKit container setup)

---

## License

This project is provided as-is for personal use by Taylor Drew.
