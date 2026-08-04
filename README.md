# OverPar for iOS

OverPar is a community-powered golf GPS and scoring app. Release 1.0 is a native SwiftUI iPhone application. Open [`OverPar.xcodeproj`](OverPar.xcodeproj) in Xcode.

## Requirements

- macOS with the full current Xcode application installed
- iOS 17 or newer deployment target
- An Apple Account for free local-device development
- Apple Developer Program membership for TestFlight/App Store distribution

## Run

1. Open `OverPar.xcodeproj`.
2. Select the `OverPar` scheme.
3. In Signing & Capabilities, choose your development team.
4. Select an iPhone simulator or connected iPhone.
5. Press Run.

The current bundle identifier is `com.zacwhittaker.overpar`. Change it before signing if that identifier is not registered to your Apple developer account.

## Native implementation

- SwiftUI application lifecycle and four-tab navigation
- Google satellite hole logging with a keyless Apple fallback and interactive tee/green-reference placement
- Core Location foreground permission, nearest-course seam and stable multi-sample GPS capture
- Offline-first atomic JSON persistence for courses, active rounds, GPS shots and range hits
- Course revisions pinned into rounds
- Separated shot direction, ball flight, strike quality and finishing lie
- Rules-aware out-of-bounds/lost-ball relief
- Driving Range club averages and recommendation inputs
- Profile, Settings, privacy declarations and Release 1.0 credits
- Supabase/PostGIS migration with Row Level Security

## Backend setup

See [`planning/release-1-shipping-checklist.md`](planning/release-1-shipping-checklist.md). It lists every account, identifier, key, document and App Store item still required, including which items are free and the unavoidable Apple membership cost.
