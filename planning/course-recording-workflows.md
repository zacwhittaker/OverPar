# OverPar course-recording workflows

**Prepared:** 29 July 2026  
**Status:** Implementation specification for community course creation  
**Related:** [`overpar-app-build-blueprint.md`](overpar-app-build-blueprint.md), [`community-course-discovery.md`](community-course-discovery.md), and [`ideal-course-data-and-creation.md`](ideal-course-data-and-creation.md)

## 1. Decision

OverPar supports two first-class ways to record a course:

1. **Satellite mode:** the contributor selects a tee-box location and flag/green reference on an interactive satellite map for each hole.
2. **Walk mode:** the contributor walks the course and captures a stable live-GPS location at the tee box and at the flag/green, then advances to the next hole.

Both modes write into the same versioned course draft. A contributor may switch modes or repair one captured point using the other mode before submission.

The minimum publishable geometry for each hole is:

- one tee-box point;
- one persistent flag/green reference point.

Additional tee sets, green outlines, hazards and scorecard information can be added later without blocking the requested simple workflow.

The full researched enrichment model—including facilities versus layouts, tee sets, lengths, stroke indexes, official rating/slope evidence, shared nines, hazards, temporary overlays and completeness badges—is specified in [`ideal-course-data-and-creation.md`](ideal-course-data-and-creation.md). Keep those additions progressive so the minimum tee/green/par workflow remains easy.

## 2. Terminology

The user-facing interface may say **Flag location** because golfers understand it immediately. The stored domain field should be `green_reference`, because a physical cup/flag is moved regularly and should not become a permanent course coordinate by accident.

Recommended UI copy:

> Flag location  
> Place this near the usual green centre. The physical flag may move day to day.

If a contributor captures the actual cup while walking, the point is still published initially as the green reference unless a future daily-pin system explicitly stores an expiring pin location.

## 3. Shared course-creation entry flow

### Screen 1 — Find or add a course

Fields/actions:

- search by course or club name;
- nearby existing courses;
- map result preview;
- `Use this course`;
- `Suggest a correction`;
- `Add missing course`.

Before a new draft is created, run duplicate checks using:

- normalised name;
- nearby club/course locations;
- overlap with existing hole geometry;
- same club with a different named layout.

### Screen 2 — Course basics

Required:

- course name;
- country/region;
- number of holes: 9, 18 or custom;
- par for every hole;
- optional club/facility name.

Helpful optional fields:

- layout name;
- address;
- additional scorecard fields such as stroke index and published yardages;
- contributor notes.

Course setup uses two screens: course details followed by a quick par grid with `3`, `4`, `5` and `Other` for each hole. Show derived front/back/total par. Every expected hole must have a par before publication, although an incomplete private draft can always be saved. The complete form and community search/discovery behaviour are specified in [`community-course-discovery.md`](community-course-discovery.md).

After saving the course name, hole count and pars, allocate a stable draft UUID immediately. Save locally and to the contributor's private Supabase draft as soon as connectivity permits.

### Screen 3 — Choose recording method

Two large choices:

- `Use satellite map`
  - “Place the tee and flag for every hole from above.”
- `Walk the course with GPS`
  - “Capture your position at each tee and flag while you play or walk.”

Also show:

- expected time;
- permission requirements;
- progress that can be resumed;
- warning not to obstruct play or enter restricted areas.

## 4. Satellite mode

### 4.1 Map presentation

Default to a top-down satellite or hybrid view at a useful golf-course zoom. Required controls:

- search/recentre;
- zoom and pan;
- switch satellite/hybrid labels;
- north reset;
- undo;
- delete/replace active point;
- previous/next hole;
- course progress such as `Hole 3 of 18`;
- current par such as `Par 4`;
- persistent bottom sheet with the current required action.

The selected provider must support satellite display and interactive annotations on all target clients. Current official documentation confirms that both Google Maps and Mapbox support satellite imagery and geographic point annotations; both also support interactive/draggable markers in their SDKs. Provider licensing remains a required decision before implementation.

### 4.2 Hole placement sequence

For each hole:

1. Show `Hole N — Place tee box`.
2. Contributor centres the map and either:
   - taps the visible tee box; or
   - keeps a crosshair fixed at screen centre and pans the map beneath it, then taps `Set tee`.
3. Show a tee marker and `Hole N — Place flag`.
4. Contributor moves to the green and sets the flag/green reference.
5. Draw a line from tee to flag with straight-line yardage/metres.
6. Show a confirmation card:
   - tee coordinate;
   - flag coordinate;
   - calculated length;
   - `Adjust tee`;
   - `Adjust flag`;
   - `Save & next hole`.
7. Advance the map toward the likely next tee while retaining manual control.

The centre-crosshair interaction is recommended as the primary precise placement mechanism on a phone. It avoids covering tiny tee/green details with a finger and marker during the final placement. Direct tap and draggable-marker adjustment remain useful secondary interactions.

### 4.3 Marker behaviour

- Tee marker and flag marker have distinct shapes/colours as well as labels; do not rely on colour alone.
- Selecting a marker opens `Move`, `Delete` and point details.
- During adjustment, use a magnified crosshair/coordinate preview if supported.
- Dragging updates the line/distance continuously.
- Do not save on every drag frame; persist on drag end and debounce background draft saves.
- Keep a local undo stack for the editing session.

### 4.4 Satellite placement validation

Before `Save & next hole`:

- both required points exist;
- coordinates are valid WGS84 longitude/latitude;
- tee-to-flag distance is plausible;
- points are not accidentally identical;
- hole number is unique in the draft;
- location does not appear implausibly far from the rest of the course.

Use warnings, not absolute rejection, for unusual legitimate holes. Suggested initial warning thresholds, configurable server-side:

- below 40 m;
- above 700 m;
- either point more than 2 km from the draft course envelope/other holes;
- new hole closely duplicates another hole's tee and flag.

The contributor may continue after acknowledging a warning, but the submission receives a lower automated trust score or moderation flag.

### 4.5 Satellite mode completion

After the last hole, show a course overview:

- every hole line and numbered markers;
- missing/invalid holes highlighted;
- list of required pars and calculated lengths;
- jump-to-hole editing;
- total course par and optional tee labels;
- `Save draft`;
- `Submit course`.

Do not publish directly from the map without this full review.

## 5. Walk mode

### 5.1 Permission and readiness

Before entering capture:

- explain why precise location is required;
- request while-in-use precise location;
- detect reduced/approximate permission;
- offer settings guidance if precise location is unavailable;
- show current GPS accuracy and whether it is improving;
- explain that live capture works best under open sky;
- tell the contributor to stand at the intended point and remain still briefly.

Do not require continuous background tracking for the basic workflow. High-accuracy updates are needed only while the capture screen is active and briefly warming up around a point capture.

### 5.2 Walk-mode hole screen

Persistent information:

- course name;
- `Hole N of total`;
- `Par X`;
- current step: `Go to tee` or `Go to flag`;
- live accuracy, such as `±4.2 m`;
- satellite mini-map with current location and captured points;
- capture status;
- `Pause & save`;
- emergency `Exit recording`.

Primary button states:

- `Waiting for GPS…`;
- `Capture tee location`;
- `Capturing… Keep still`;
- `Tee saved`;
- `Capture flag location`;
- `Flag saved`;
- `Next hole`.

### 5.3 Tee capture

When the user reaches the tee:

1. They tap `Capture tee location`.
2. Start or intensify high-accuracy location updates.
3. Ignore stale fixes.
4. Collect a short sample window rather than accepting the first location.
5. Show accuracy progress and a cancel action.
6. Reject invalid readings and statistical outliers.
7. Calculate the representative coordinate.
8. Save the representative point plus capture-quality metadata.
9. Show it on the mini-map.
10. Offer `Recapture` or `Continue to flag`.

### 5.4 Flag/green capture

At the green:

1. Show safety copy: do not delay play; capture a safe green-centre reference if the cup cannot be approached.
2. User taps `Capture flag location`.
3. Run the same multi-sample capture process.
4. Save point and quality metadata.
5. Calculate tee-to-flag straight-line distance.
6. Show `Hole N complete`, map and length.
7. Offer `Recapture tee`, `Recapture flag`, or `Next hole`.

### 5.5 GPS sampling algorithm

Initial algorithm to validate in field testing:

```text
start capture
discard locations older than capture start minus a small tolerance
collect up to 8–15 seconds
accept fixes only when:
  horizontalAccuracy > 0
  horizontalAccuracy <= configurable hard ceiling
  timestamp is fresh
prefer at least 5 accepted samples
remove spatial outliers
compute accuracy-weighted centre or robust median
calculate sample spread and aggregate quality
finish early when accuracy and stability criteria are met
otherwise show continue-waiting / save-with-warning / cancel
```

Do not use the numerical horizontal-accuracy value as a guarantee. It is the operating system's estimated uncertainty radius. Store:

- every accepted sample for the draft/audit window, or a privacy-conscious compressed summary;
- final representative WGS84 point;
- best and median horizontal accuracy;
- sample count;
- sample spread;
- capture duration;
- device/platform;
- timestamp;
- whether the user overrode a warning;
- capture method.

Suggested configurable quality bands:

- **Strong:** aggregate estimated accuracy ≤5 m and low sample spread;
- **Usable:** >5 m to ≤10 m;
- **Review:** >10 m to ≤20 m;
- **Poor:** >20 m, recapture strongly recommended.

These thresholds are starting hypotheses, not promises. Field data must determine final values.

### 5.6 Handling poor GPS

If quality does not improve:

- keep the user informed rather than showing an endless spinner;
- offer `Keep trying`;
- offer `Place on satellite map instead`;
- allow `Save with accuracy warning` only under a server-configured ceiling;
- do not permit an invalid/unknown fix;
- keep previously captured holes safe.

On iOS, request best appropriate accuracy but expect lower-accuracy fixes while the system converges. On Android, prefer a fresh current location or controlled high-accuracy updates rather than relying on an old cached last location. Stop updates promptly after capture.

### 5.7 Next-hole behaviour

`Next hole` becomes active only when tee and flag are saved or the current hole is explicitly marked `Skip for later`.

On advance:

- persist the completed hole locally immediately;
- enqueue idempotent draft sync;
- increment hole number;
- reset the current capture state;
- retain the course-level recording session;
- reduce/stop high-power location updates until the next capture;
- show a short completion confirmation.

The contributor may move backward to review/recapture a prior hole. Recapture creates a new draft point version; it does not erase the audit history silently.

### 5.8 Pause, resume and recovery

The walk may take hours. The workflow must survive:

- app backgrounding;
- app termination;
- device restart;
- no mobile signal;
- expired authentication;
- switching to satellite mode.

Persist after every meaningful transition:

```text
draft_id
course basics
hole count
current hole
current required step
captured points and quality
skipped holes
local operation IDs and sync state
```

On reopen, show:

> Resume recording Royal Example — 7 of 18 holes complete

Never automatically resume continuous high-accuracy GPS in the background merely because a draft exists.

## 6. Mixed-mode editing

Mode is a property of each captured point, not the entire course:

```text
Hole 1 tee: satellite
Hole 1 green_reference: satellite
Hole 2 tee: live_gps
Hole 2 green_reference: live_gps
Hole 3 tee: live_gps
Hole 3 green_reference: satellite correction
```

Benefits:

- poor GPS can be repaired from imagery;
- obscured satellite imagery can be confirmed on site;
- a contributor can map most holes remotely and verify uncertain points while walking;
- moderators can understand provenance.

The course overview should show a small provenance/quality indicator without overwhelming ordinary golfers.

## 7. Draft state machine

### Course draft

```text
new
  -> basics_complete
  -> recording
  -> review_ready
  -> submitted
  -> published | changes_requested | rejected
```

### Hole recording

```text
empty
  -> tee_pending
  -> tee_captured
  -> flag_pending
  -> complete
```

Additional states:

- `skipped`;
- `needs_review`;
- `sync_pending`;
- `sync_conflict`.

State transitions should be explicit and validated on both client and server.

## 8. Data contract refinements

Recommended minimal tables/fields:

```text
course_drafts
  id uuid
  owner_id uuid
  name
  club_name nullable
  country_code
  expected_hole_count
  current_hole_number
  state
  local_created_at
  created_at, updated_at

course_draft_holes
  id uuid
  draft_id uuid
  hole_number
  state
  tee_capture_id uuid nullable
  green_reference_capture_id uuid nullable
  calculated_length_m numeric nullable
  warning_codes text[]
  updated_at

location_captures
  id uuid
  draft_id uuid
  hole_number
  role enum(tee, green_reference)
  method enum(satellite, live_gps, moderator_adjustment)
  location geography(Point, 4326)
  horizontal_accuracy_m numeric nullable
  median_accuracy_m numeric nullable
  sample_spread_m numeric nullable
  sample_count integer nullable
  capture_duration_ms integer nullable
  captured_at
  device_metadata jsonb nullable
  warning_override boolean
  supersedes_capture_id uuid nullable

course_draft_events
  id uuid
  draft_id uuid
  operation_id uuid unique
  event_type
  payload jsonb
  actor_id uuid
  created_at
```

When submitted, a privileged transactional function:

1. verifies ownership and state;
2. locks the draft against simultaneous publication;
3. validates hole completeness and coordinates;
4. runs duplicate/spatial checks;
5. creates a new immutable course revision;
6. copies the selected captures into published hole geometry;
7. records contributor provenance;
8. changes submission state;
9. returns stable course and revision IDs.

### Coordinate order warning

GeoJSON and PostGIS convention is longitude then latitude. Client location APIs often present latitude then longitude. Centralise conversion and test it; reversed coordinates can create valid-looking but catastrophically misplaced points.

## 9. Database spatial operations

Use PostGIS with WGS84 (`SRID 4326`) geography points and GiST indexes for:

- nearby existing-course search;
- draft/course duplicate checks;
- tee-to-green distance;
- course envelope/outlier warnings;
- map viewport queries.

Supabase's official PostGIS guidance confirms indexable point/polygon types and nearest/bounding-box queries. `ST_DWithin` on geography accepts metres and can use spatial indexes, making it suitable for duplicate/proximity checks.

Server-side distance is authoritative for stored validation. The client may calculate immediate preview distance but should not be the only validator.

## 10. Submission review

Before submission, show:

- course name and hole count;
- par for every hole and derived total par;
- full satellite overview;
- each hole's tee, flag and length;
- capture method and GPS quality warnings;
- skipped/missing holes;
- possible duplicates;
- contributor certification:
  - points were added in good faith;
  - contributor had permission to access recorded locations;
  - no restricted area was entered;
  - flag points represent stable green references rather than guaranteed daily cup positions.

Submission outcomes:

- publish automatically at community confidence;
- send for moderation;
- request missing information;
- propose an edit to an existing course;
- merge with another draft.

## 11. Moderator experience

Moderator diff view:

- existing published revision versus submission;
- satellite overlay;
- tee/flag displacement in metres;
- GPS accuracy/provenance;
- hole-length change;
- duplicate candidates;
- contributor history/reputation;
- accept, request change, reject, merge or adjust.

Moderator adjustments create attributed captures/revisions. Never rewrite the contributor's original capture record.

## 12. Accessibility and on-course usability

- large capture and next-hole buttons;
- high contrast in sunlight;
- haptic/audio confirmation after a point is saved;
- screen-reader labels for tee/flag markers;
- do not encode status by colour alone;
- prevent accidental double capture;
- keep the display awake only during an active capture with user awareness;
- provide yards/metres based on profile while storing metres internally;
- offer left/right one-handed placement of the primary capture button if needed.

## 13. Privacy and safety

- Draft course captures are private until submitted/published.
- Store only point locations required for course mapping, not the contributor's continuous walking trail.
- Do not expose device identifiers publicly.
- Exact tee/green points become public course data only after submission policy permits.
- Explain that submitting course geometry makes those coordinates shared.
- Avoid capturing background GPS continuously between tee and green in the basic mode.
- Warn users not to use the workflow where phones are prohibited or unsafe.
- Provide pause/exit without losing progress.

## 14. Testing plan

### Unit and integration

- latitude/longitude conversion;
- Haversine/PostGIS distance agreement;
- state-machine transitions;
- multi-sample robust centre/outlier rejection;
- quality-band calculation;
- duplicate/outlier warnings;
- local persistence and idempotent replay;
- immutable revision publication;
- RLS for private drafts and public revisions.

### Interaction

- precise placement under finger/crosshair;
- marker drag and undo;
- map recenter and hole navigation;
- address/postcode map search for initial positioning without storing that query as required course metadata;
- a blank next hole opens around the previous hole's green/tee before falling back to current device location;
- capture button state changes;
- interruption and resume;
- switching methods for one point;
- final overview and jump-to-hole.

### Field

- open-sky course;
- tree-covered tee/green;
- weak/no mobile connection;
- nine- and eighteen-hole courses;
- nine-hole layouts normally played for two or three loops;
- multi-layout club;
- alternate tees/shared greens;
- Android/iPhone generations;
- precise location denied/reduced;
- one hole skipped and repaired later;
- contributor stops after several holes and resumes next day.

### Acceptance criteria for first version

- A contributor can complete a 9- or 18-hole draft entirely in either mode.
- Every completed hole has one tee and one green-reference point.
- Every publishable hole has a required par.
- The app survives termination without losing confirmed points.
- GPS capture never silently uses a stale last-known location.
- Poor accuracy produces an actionable warning/fallback.
- Satellite markers can be adjusted precisely.
- Every point records its method and provenance.
- Submission creates an immutable course revision.
- A second user can retrieve the published course.
- Existing rounds remain tied to their original course revision.
- Publishing automatically samples 100 ordered, sourced tee-to-green elevation
  points for every complete hole while an animated per-hole progress screen is
  visible. Requests may be batched without changing point order.
- Every mapped course preview exposes **Update Terrain**. It rescans all complete
  holes and publishes a new immutable course revision, allowing older/coarser
  profiles to be upgraded without recreating the course.
- Contributors are never asked to draw contours or enter elevations manually.
- A terrain-service failure preserves the draft and offers retry or publication
  marked for later enrichment.

## 15. Build sequence

1. Implement the shared draft/state/data model.
2. Implement local persistence and draft sync.
3. Build satellite mode using a provider abstraction.
4. Build course overview and validation.
5. Build live-GPS capture as a reusable `StableLocationCapture` module.
6. Add mixed-mode replacement and resume.
7. Add transactional submission/revision creation.
8. Add automatic terrain-profile enrichment with cached source/fetch metadata,
   provider attribution and a retry-safe publishing state.
9. Add duplicate checks and moderation queue.
10. Field test and calibrate accuracy/distance warnings.
11. Only then add richer tee sets, green polygons, hazards and daily pin features.

## 16. Primary technical sources

- [Apple Core Location desired accuracy](https://developer.apple.com/documentation/corelocation/cllocationmanager/desiredaccuracy)
- [Apple location accuracy values](https://developer.apple.com/documentation/corelocation/cllocationaccuracy)
- [Apple guidance for efficient location access](https://developer.apple.com/documentation/xcode/accessing-the-device-s-location-efficiently)
- [Android fresh versus last-known location](https://developer.android.com/develop/sensors-and-location/location/retrieve-current)
- [Google Maps iOS satellite/hybrid map types](https://developers.google.com/maps/documentation/ios-sdk/configure-map)
- [Google Maps iOS draggable markers](https://developers.google.com/maps/documentation/ios-sdk/marker-gestures)
- [Mapbox iOS annotations](https://docs.mapbox.com/ios/maps/guides/add-your-data/annotations/)
- [Mapbox draggable-marker example catalogue](https://docs.mapbox.com/ios/maps/examples/)
- [Supabase PostGIS geo queries](https://supabase.com/docs/guides/database/extensions/postgis)
- [PostGIS `ST_DWithin`](https://www.postgis.net/docs/manual-3.5/ST_DWithin.html)
- [Open-Meteo Elevation API](https://open-meteo.com/en/docs/elevation-api)
