# TimeBoxer Parent for iPhone

This is the independent native parent client. It deliberately does not embed the
child web application or the macOS monitoring code.

## Current milestone

- SwiftUI mobile-first parent dashboard using the established TimeBoxer palette.
- Child Mac online/offline state, pending approval, blocked activity alert and
  daily allowance summary.
- One-time six-digit Mac pairing flow.
- `FamilyCloudService` boundary so preview data can be replaced by the authenticated
  cloud client without coupling UI code to a backend SDK.
- Real email/password registration, session restoration, sign-in and sign-out
  through the dedicated TimeBoxer Supabase project.
- Official `supabase-swift` dependency pinned exactly to `2.54.1`; only the
  publishable client key is embedded and all data access remains protected by RLS.

Authentication now connects to the hosted TimeBoxer project. Dashboard data and
pairing still use the preview service until the family onboarding and device Edge
Functions are connected. APNs is not connected yet.

The current development Mac has the iOS 18.5 SDK but no iOS Simulator runtime.
Install an iOS runtime from Xcode Settings > Components before running the scheme.

## Build locally

Open `TimeBoxerParent.xcodeproj` in Xcode, select an iPhone simulator and run the
`TimeBoxerParent` scheme, or run:

```bash
xcodebuild \
  -project ios/TimeBoxerParent/TimeBoxerParent.xcodeproj \
  -scheme TimeBoxerParent \
  -sdk iphonesimulator \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```
