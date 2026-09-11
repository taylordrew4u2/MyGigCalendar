# App Store asset pack

Prepared for My Gig Calendar's iPhone/iPad target, checked against Apple documentation on 2026-09-11.

## Icons

The catalog uses universal 1024 × 1024 images. Xcode generates smaller iPhone/iPad Home Screen, Spotlight, Settings, and notification renditions. The App Store reads the icon from the uploaded build.

- `icons/AppIcon_New.png`: approved red and pure white default.
- `icons/AppIcon_Dark.png`: dark appearance.
- `icons/AppIcon_Tinted.png`: monochrome system-tinted appearance.
- Editable SVG masters accompany all three.

Each PNG is an opaque RGB square without baked-in corner masking. The images are also installed in the app's AppIcon catalog.

## Screenshots

Upload `screenshots/en-US/iphone-6.9/` to the 6.9-inch iPhone slot and `screenshots/en-US/ipad-13/` to the 13-inch iPad slot. These show real app views with fictional example gigs, using a temporary in-memory capture harness excluded from the shipping app.

- iPhone: 1320 × 2868, portrait.
- iPad: 2064 × 2752, portrait.
- Opaque RGB PNG, no alpha channel.

Smaller screen classes can use App Store Connect scaling. iPad requires its own set. The in-app animated splash is not an App Store preview video; those videos are optional and are not included.

## Validate

Run `python3 AppStore/validate_assets.py` from the repository root.

## Submission scope

These are the standard icon and English screenshot assets for this iPhone/iPad app. No App Store Connect upload or release is performed. The release build, listing text, privacy/support URLs, age-rating/privacy answers, and review information remain separate submission requirements. Other localizations, custom product pages, featuring, and promoted in-app purchase artwork are conditional. A new in-app purchase submission also needs a review screenshot of its purchase flow.

## Apple references

- [Icon asset catalogs](https://developer.apple.com/documentation/xcode/configuring-your-app-icon/)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
- [Screenshots and optional previews](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots)
