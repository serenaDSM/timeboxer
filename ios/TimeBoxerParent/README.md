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

The current service is a local preview implementation. It does not yet connect to
production Supabase or APNs.

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
