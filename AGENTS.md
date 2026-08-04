# AGENTS.md

## Purpose

This file is the durable instruction set for every coding agent working in the OverPar repository.

OverPar is a community-powered golf application combining permanent user-created golf courses, satellite/live-GPS course mapping, GPS rangefinding, scoring, social rounds, shot logging, personalised golf statistics, plays-like club assistance and visual golf-shot tracing.

Treat the repository documentation named below as the project's product and technical brain. Do not reduce OverPar to a generic scorecard, map demo or manually drawn video effect.

## Mandatory pre-code reading gate

Before planning an implementation, creating scaffolding, installing dependencies, writing a migration, or changing any source/configuration code, the agent must:

1. Read this `AGENTS.md` completely.
2. Read [`planning/overpar-app-build-blueprint.md`](planning/overpar-app-build-blueprint.md) completely.
3. Read [`research/golf-gps-and-shot-tracking-apps.md`](research/golf-gps-and-shot-tracking-apps.md) completely.
4. Read [`planning/course-recording-workflows.md`](planning/course-recording-workflows.md) completely.
5. Read [`planning/community-course-discovery.md`](planning/community-course-discovery.md) completely.
6. Read [`planning/ideal-course-data-and-creation.md`](planning/ideal-course-data-and-creation.md) completely.
7. Read [`planning/profile-system.md`](planning/profile-system.md) completely.
8. Read [`planning/driving-range-and-club-recommendations.md`](planning/driving-range-and-club-recommendations.md) completely.
9. Read [`planning/round-companion-and-gallery.md`](planning/round-companion-and-gallery.md) completely.
10. Read [`planning/interface-design-system.md`](planning/interface-design-system.md) completely.
11. For every interface, motion, branding, onboarding, screenshot or visual-polish task, read [`planning/design-review-learnings.md`](planning/design-review-learnings.md) completely.
12. Inspect the existing repository, current architecture, configuration and relevant tests.
13. State in its working update that the documents were read and identify which requirements affect the current task.

Do not begin code changes after reading only headings, summaries or excerpts. The complete reports contain important distinctions, safety requirements, phased architecture and implementation constraints.

This gate applies again in a new agent session or after context loss. If either report is missing or unreadable, stop before writing code and report the problem.

Explicit instructions from the user override this file. A more deeply nested `AGENTS.md` may add package-specific instructions, but it must not silently discard the product requirements here.

## Authoritative project documents

### Product and build authority

[`planning/overpar-app-build-blueprint.md`](planning/overpar-app-build-blueprint.md) defines:

- the complete OverPar product vision;
- proposed application and backend architecture;
- Supabase authentication and database approach;
- PostGIS course and geometry model;
- permanent, versioned community course registration;
- satellite-map and live-GPS capture workflows;
- rounds, scoring, shots, clubs, statistics and social functions;
- Row Level Security expectations;
- offline, privacy, moderation and testing requirements;
- visual-tracer integration;
- delivery phases, risks and pre-build decisions.

Use it as the primary source for what to build and how major product areas fit together.

### Research and behavioural authority

[`research/golf-gps-and-shot-tracking-apps.md`](research/golf-gps-and-shot-tracking-apps.md) defines:

- how golf GPS applications obtain and use positioning;
- GPS accuracy, uncertainty and course-mapping limitations;
- researched behaviour from Wedge, 18Birdies, Hole19, Golfshot, SwingU and Golf Pad;
- the distinction between GPS shot logging, visual shot tracing and launch-monitor measurement;
- the SmoothSwing-focused visual tracer research;
- the visual computer-vision pipeline, capture constraints and failure cases;
- confidence, manual correction, data, evaluation and deployment recommendations.

Use it to prevent misleading product claims and technically naive implementations.

### Course-recording authority

[`planning/course-recording-workflows.md`](planning/course-recording-workflows.md) defines:

- the exact satellite-map tee/flag placement flow;
- the exact walk-mode live-GPS tee/flag capture flow;
- the shared resumable course-draft state machine;
- stable multi-sample location capture and quality handling;
- mixed-mode correction, publication and moderation behaviour;
- course-recording data contracts and acceptance tests.

Use it as the implementation authority for creating or editing community courses.

### Community discovery authority

[`planning/community-course-discovery.md`](planning/community-course-discovery.md) defines:

- setup-time foreground location permission and denial fallbacks;
- automatic nearest-course content on the signed-in home screen;
- course search by name, club, city, postcode and current GPS position;
- PostGIS nearby ranking and server-side geocoding boundaries;
- mandatory course name, hole count and per-hole par entry;
- discovery/search data contracts and acceptance tests.

Use it as the implementation authority for community course discovery and the structured creation form.

### Ideal course-data authority

[`planning/ideal-course-data-and-creation.md`](planning/ideal-course-data-and-creation.md) defines:

- the required-versus-progressive course data model;
- facility, layout, route and shared-nine relationships;
- tee sets, published lengths, stroke indexes and official rating/slope evidence;
- green, tee, hazard and temporary map geometry;
- scorecard scan/OCR review and source evidence;
- course completeness/verification levels;
- course maintenance, correction and profile enrichment.

Use it as the authority for enriching course creation without bloating the minimum playable workflow.

### Profile-system authority

[`planning/profile-system.md`](planning/profile-system.md) defines:

- display name, unique username, avatar, biography and broad-location behaviour;
- own, public and limited/private profile surfaces;
- home courses, private favourites and course-contribution attribution;
- profile visibility, discoverability, blocking and reporting;
- trusted contributor/course representative roles and badge boundaries;
- Supabase profile tables, avatar storage and RLS/API requirements;
- the explicit exclusion of golfer performance statistics for now.

Use it as the implementation authority for identity and profiles. Do not add handicap, score, round, club or other performance-statistic UI until the user supplies that feature.

The user has now supplied the club-distance feature. [`planning/driving-range-and-club-recommendations.md`](planning/driving-range-and-club-recommendations.md) is the implementation authority for:

- the practical club catalogue, inventory and active bag;
- range-shot capture and carry-versus-total separation;
- arithmetic averages, robust playing distances and confidence;
- the private-by-default profile club-distance interface;
- attack-first club selection and last-resort lay-up logic;
- its data, privacy, offline, testing and rules-compliant requirements.

This authorisation does not extend to handicap, score, round or other performance-statistic UI.

### Round companion and Gallery authority

[`planning/round-companion-and-gallery.md`](planning/round-companion-and-gallery.md) defines:

- saved-course Preview and Play entry points;
- satellite course/hole preview behaviour;
- minimal round setup and resumable active-hole companion;
- the distinction between GPS **Log Shot** and camera **Record Shot**;
- in-round visual-tracer capture and review;
- hole/round completion, offline recovery and GPS shutdown;
- the private-by-default **Gallery** page, media linkage and deletion rules.

Use it as the screen-flow and data-lifecycle authority for playing a round and managing recorded shot videos. Recorded shot media must appear in Gallery without coupling round completion to tracer processing.

When logging shot results, keep target-relative direction, ball-flight shape, strike quality and finishing lie separate. Lost/out-of-bounds defaults to stroke-and-distance (+1 at the previous position); Model Local Rule E-5 is +2 when applicable. A nearby +1 drop is permitted only as an explicitly non-conforming casual-round rule and is disabled in rules-compliant mode.

### Interface and motion authority

[`planning/interface-design-system.md`](planning/interface-design-system.md) defines:

- the friendly-clubhouse visual direction;
- white/soft-white surfaces and deep forest-green tokens;
- Nunito Sans typography and rounded components;
- Home, Play, Gallery, Range and Profile navigation;
- native iOS Liquid Glass boundaries and platform fallbacks;
- Profile and Settings information architecture;
- component, motion, haptic, accessibility and outdoor-use requirements.

Use it before implementing UI. Liquid Glass belongs primarily to navigation and floating controls, not ordinary content cards. Settings remain distinct from the public-facing Profile surface.

[`planning/design-review-learnings.md`](planning/design-review-learnings.md) is the mandatory visual-quality preflight for all design tasks. It records screenshot-review failures and concrete spacing, composition, reference-fidelity and proof requirements learned during implementation. Read it before changing UI and use its checklist before presenting screenshots.

### Conflict handling

- The user's current explicit request has highest priority.
- For product scope and architecture, prefer the build blueprint.
- For GPS/tracer facts and behavioural constraints, prefer the research report.
- If the documents disagree or a decision has become outdated, identify the conflict before implementation and update the relevant document when the user authorises the decision.
- Never invent an undecided provider, platform, pricing model or policy merely to make scaffolding easier.

## Core product requirements

The intended complete product includes:

- Apple, Google and email/username/password authentication, with Supabase as the planned provider;
- a high-quality public landing and account experience;
- a persistent shared database of community-created golf courses;
- course registration by dropping/editing geometry over satellite imagery;
- course registration by capturing stable live-GPS positions at tees, greens and optional course features;
- automatic nearest-course discovery on the home screen with foreground location permission;
- search by course/club name, city, postcode and current GPS position;
- mandatory course name, hole count and par for every publishable hole;
- progressive tee sets, scorecard data, stroke indexes, verified Course Rating/Slope and map enrichment;
- display-name/username profiles with avatars, biographies, broad optional location, home courses and privacy;
- versioned course revisions, duplicate detection, reports, moderation and rollback;
- nearby course discovery and permanent retrieval across devices/accounts;
- front/centre/back green distances, targets, hazards and map-based distance selection;
- GPS uncertainty display, stale-fix handling and tournament-compliant raw-distance mode;
- offline-capable rounds and reliable synchronisation;
- Stroke Play, Stableford, Match Play and GPS-only play;
- solo, guest and group scoring;
- manual and later watch/inference-assisted shot logging;
- club bag, distance distributions, shot dispersion, strokes gained and performance history;
- plays-like distances using clearly separated measured and modelled values;
- club assistance with confidence and sample-size awareness;
- visual shot tracing with automatic and manual workflows;
- shareable, editable, non-destructive tracer projects and exports;
- privacy controls, account deletion, location safety and content moderation.

“All features” is the destination. Follow the blueprint's vertical delivery phases so risk-heavy camera/ML work does not prevent a useful GPS/course product from shipping.

## Invariants that code must preserve

### Measured, inferred and visualised data

Always keep these concepts separate in schemas, APIs and UI:

- **Measured:** device coordinates, reported accuracy and raw map distances.
- **Inferred/modelled:** current hole, swing event, lie, club, plays-like distance and recommendation.
- **Visualised:** tracer curve, interpolated segments and extrapolated flight.

Do not label a monocular phone-camera trace as measured carry, apex, spin or complete 3D ball flight without validated external measurement.

### Permanent but versioned courses

- A course receives a stable ID.
- Published course data is not edited destructively.
- Material geometry/scorecard changes create immutable revisions.
- The current published revision can move forward or be rolled back.
- Historical rounds retain the exact course revision used during play.
- Deleting a contributor account must not automatically delete useful shared course data.
- Community contribution does not imply legal ownership of the physical course.
- Facility/club and playable layout/path are separate domain concepts.
- Official rating/slope values require an attributable official/verified source; never invent defaults.

### Course terminology

The course recorder may use **Flag location** in user-facing copy because it is familiar, but it must explain that the saved point is a persistent green reference because the physical cup moves. Use `green_reference` in schemas/APIs. Reserve a daily **hole location** or **pin** for a future expiring daily-pin feature.

### GPS honesty

- Store location accuracy and capture metadata where relevant.
- Reject or flag stale and low-quality fixes.
- Prefer multi-sample stable capture to a single arbitrary GPS point.
- Do not use a cached last-known location as a silent tee/flag capture.
- Show uncertainty rather than false one-yard precision.
- A phone or watch location is the device location, not automatically the ball location.
- GPS endpoint distance is not airborne carry or the actual curved path.
- The basic course recorder stores tee/green point captures, not the contributor's continuous walking route.
- Home-page nearest-course discovery uses a bounded fresh foreground lookup and must not leave continuous GPS running.

### Tracer honesty and resilience

- Preserve the original video.
- Store tracing instructions/results as editable metadata.
- Track confidence through capture, impact, ball origin, temporal tracking, camera motion and path completion.
- Distinguish internally between observed, interpolated, extrapolated and manually supplied segments.
- Provide a fast manual correction/fallback.
- Automatic failure must not prevent the user from completing a tracer.
- Prefer a constrained, reliable fixed-camera MVP before claiming robust panning support.

### Offline and data integrity

- Active round changes write locally first where the client architecture supports it.
- Use stable client-generated IDs and idempotent sync.
- App termination or temporary connection loss must not silently lose a round.
- Resolve group scoring conflicts deliberately.
- Do not rewrite historical statistics when course geometry changes.

## Planned technical direction

Unless the user approves a different architecture, treat the blueprint recommendation as the working direction:

- React Native and TypeScript for the shared mobile product shell;
- platform-native camera, sensor, ML and video modules;
- iOS-first visual-tracer engine using Swift, AVFoundation, Vision and Core ML;
- Android native tracer integration later with an equivalent validated pipeline;
- Next.js and TypeScript for the landing page and desktop-friendly course editor;
- Supabase Auth, PostgreSQL, PostGIS, Storage, Realtime and server/Edge functions;
- local transactional storage and an offline sync queue for active rounds;
- private/on-device tracer processing by default, with optional consented cloud refinement.

This direction is not permission to create a new stack without checking the repository. Reuse and extend sound existing architecture where it exists.

## Supabase and database rules

- All schema changes must be versioned migrations.
- Enable and test Row Level Security for user-owned or visibility-controlled tables.
- Never ship a Supabase service-role key or provider secret to a client.
- Privileged publishing, moderation and media actions run server-side.
- Use immutable UUIDs as identities; usernames are mutable presentation identifiers.
- Use PostGIS geography/geometry types for course spatial data.
- Add constraints for hole numbers, required course geometry, revision uniqueness and valid states.
- Public access is limited to explicitly published/public data.
- User videos and precise private locations are private by default.
- Storage access uses policies and short-lived signed access where appropriate.
- Database types/contracts should be generated or kept synchronised with clients.
- RLS tests are required; hiding UI controls is not authorisation.

## Map and satellite rules

No imagery provider is selected merely by assumption.

Before implementing or locking in a map provider, verify:

- iOS, Android and web support;
- target-market satellite resolution;
- pricing and rate limits;
- offline caching terms;
- rights to derive and permanently store user-created course coordinates;
- attribution and export requirements.

Store user-created course geometry. Do not copy, cache or redistribute satellite imagery outside the selected provider's licence.

## Visual tracer implementation guidance

The intended pipeline is:

```text
capability and scene check
  -> rolling capture buffer
  -> impact detection
  -> camera-motion estimation
  -> stationary ball origin
  -> temporal ball observations
  -> candidate association/filtering
  -> confidence-aware path completion
  -> editable curve
  -> non-destructive rendering/export
```

Implementation priorities:

1. Make guided fixed-camera, daylight, white-ball automatic tracking the Release 1 happy path.
2. Show the real camera with a golfer/ball alignment template and draw accepted observations during capture.
3. Use temporal/consecutive-frame evidence rather than a canned curve or only a per-frame generic detector.
4. Preserve the original video and save it automatically to Gallery without requiring manual editing.
5. Provide an immediate live/provisional trace and a better post-process pass.
6. Retain a confidence-aware manual correction fallback for automatic failure.
7. Treat handheld panning and world-anchored transforms as a later, separately tested capability.
8. Expand device, lighting and ball support only after measured validation.

Do not represent a smooth fitted spline as proof that every part of the ball flight was observed.

## Security and privacy

- Request location, camera, microphone and photo permissions in context.
- Never log access tokens, passwords, private media URLs or unnecessary exact coordinates.
- Do not expose precise live user locations publicly.
- Strip unnecessary embedded location metadata from public media exports.
- Cloud video refinement must be explicit and disclose retention.
- Never train on user footage without separate, informed consent.
- Implement account deletion and media deletion as real backend workflows.
- Audit moderator and privileged actions.
- Include block/report tooling when public social features are introduced.
- Warn course mappers not to enter restricted areas or obstruct active play.

## Development workflow

### Before changing code

- Pass the mandatory reading gate.
- Inspect the worktree and preserve unrelated user changes.
- Find the nearest applicable `AGENTS.md`.
- Identify the smallest vertical slice that fulfils the request.
- Check whether a product decision in blueprint section 20 is still unresolved.
- Do not silently decide unresolved high-impact choices.

### While changing code

- Increment `CURRENT_PROJECT_VERSION` for every user-facing application update. The Settings About section must display the live `CFBundleShortVersionString` and `CFBundleVersion` values rather than hard-coded release copy.
- Keep source, migrations, policies and tests in the same task where practical.
- Use strict typing.
- Make state transitions explicit.
- Design mutations to be retry-safe when used by mobile/offline clients.
- Add comments only where they explain non-obvious domain or safety reasoning.
- Avoid premature abstractions, but do not encode course/tracer concepts as unstructured blobs when they need querying or integrity.
- Preserve backwards compatibility for stored course revisions and rounds.

### Verification

Run the relevant checks defined by the repository once tooling exists:

- formatting;
- linting;
- type checking;
- unit/integration tests;
- database migration checks;
- RLS policy tests;
- build checks for affected clients;
- tracer regression/golden tests for vision or renderer changes.

Add or update tests for changed behaviour. If a required check cannot run, report exactly why and what remains unverified.

### Documentation

Update the build blueprint when an architectural/product decision is approved and materially changes it. Update the research report only when new evidence or corrected research warrants it. Keep this file concise enough to remain operational, but revise it when repository commands, conventions or non-negotiable rules become known.

## Current repository state

Release 1.0 is a native SwiftUI iPhone application in `OverPar.xcodeproj`, targeting iOS 17 and newer. The earlier browser prototype was removed because Xcode/App Store distribution is the authorised product target.

Current boundaries:

- `OverPar/` contains SwiftUI screens, typed domain models, Core Location, MapKit, camera/video capture, offline-first local persistence, assets, entitlements and the privacy manifest.
- `OverPar.xcodeproj/` is the shared native Xcode project and scheme.
- `supabase/migrations/` contains the versioned PostgreSQL/PostGIS schema, functions, RLS and Storage policies for the production community backend.
- `planning/release-1-shipping-checklist.md` is the credential, account, free-tier and App Store handoff authority.
- `planning/` and `research/` remain the product and behavioural authority.

Real commands when the full Xcode application is installed and selected:

- `open OverPar.xcodeproj` — open the native project.
- `xcodebuild -project OverPar.xcodeproj -scheme OverPar -sdk iphonesimulator build` — compile for the simulator.
- `xcodebuild -project OverPar.xcodeproj -scheme OverPar -configuration Release archive` — create an unsigned/signed archive according to local signing configuration.
- `swiftc -parse OverPar/*.swift` — syntax-parse Swift sources when only Command Line Tools are available.
- `plutil -lint OverPar/Info.plist OverPar/OverPar.entitlements OverPar/PrivacyInfo.xcprivacy OverPar.xcodeproj/project.pbxproj` — validate native metadata.

This machine currently reports only `/Library/Developer/CommandLineTools` as its active developer directory, so simulator/device compilation cannot be claimed until full Xcode is installed or selected. Supabase credentials and Apple/Google identities are intentionally not committed.

## Definition of responsible progress

A change is not successful merely because it renders or compiles. It must preserve the core OverPar promises:

- contributed courses remain trustworthy, permanent and reversible;
- golfers understand what GPS and tracer outputs actually mean;
- active-round data survives normal mobile failures;
- private location and video stay private;
- automatic features remain correctable;
- the system can grow toward the complete researched feature set without corrupting historical data or requiring a rewrite of its core domain model.
