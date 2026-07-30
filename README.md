# OverPar for iOS

OverPar Release 1.0 is a native SwiftUI iPhone application. Open [`OverPar.xcodeproj`](OverPar.xcodeproj) in Xcode.

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

- SwiftUI application lifecycle and five-tab navigation
- Google satellite hole logging with a keyless Apple fallback and interactive tee/green-reference placement
- Core Location foreground permission, nearest-course seam and stable multi-sample GPS capture
- Offline-first atomic JSON persistence for courses, active rounds, shots, range hits and Gallery metadata
- Native fixed-camera shot capture with golfer alignment, live white-ball tracing and private source-video preservation
- Course revisions pinned into rounds
- Separated shot direction, ball flight, strike quality and finishing lie
- Rules-aware out-of-bounds/lost-ball relief
- Driving Range club averages and recommendation inputs
- Profile, Settings, privacy declarations and Release 1.0 credits
- Supabase/PostGIS migration with Row Level Security and private Storage policies

The live tracer analyses consecutive camera frames, renders accepted white-ball observations during capture, stores observed versus extrapolated trace metadata and preserves the source video. It does not claim measured carry, apex, spin or full 3D flight. Gallery clips can be played and permanently removed with confirmation.

## Backend setup

See [`planning/release-1-shipping-checklist.md`](planning/release-1-shipping-checklist.md). It lists every account, identifier, key, document and App Store item still required, including which items are free and the unavoidable Apple membership cost.
