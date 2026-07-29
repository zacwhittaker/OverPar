# OverPar app build blueprint

**Prepared:** 29 July 2026  
**Status:** Pre-development product and technical plan  
**Companion research:** [`research/golf-gps-and-shot-tracking-apps.md`](../research/golf-gps-and-shot-tracking-apps.md)

## 1. Product vision

OverPar will be a community-powered golf companion combining:

- golf-course discovery and permanent community course registration;
- live GPS rangefinding and course mapping;
- digital scoring and social rounds;
- manual, watch-assisted and eventually automatic shot logging;
- plays-like distances and personalised club assistance;
- real-time and post-processed visual shot tracing;
- statistics, strokes gained and shareable round/video content.

The product should feel simple during play even though the underlying system is complex. A golfer should be able to open a course, start a round and see a useful distance within seconds. Advanced functions should appear only when needed.

## 2. Non-negotiable product principles

1. **Community-created courses are permanent, but versioned.** A course should not disappear when its creator leaves. Incorrect edits must remain reversible.
2. **Measured, inferred and visualised data stay distinct.**
   - Measured: device position and raw mapped distance.
   - Inferred: current hole, club, lie, swing event and plays-like distance.
   - Visualised: shot-tracer path and extrapolated flight.
3. **Uncertainty is visible.** GPS accuracy and low-confidence visual traces must not be presented as exact.
4. **Automation is correctable.** Fixing a wrong hole, pin, shot or trace must be faster than entering it from scratch.
5. **The active round works with poor connectivity.** Course data, scoring and essential GPS functions need an offline path.
6. **Original user data is preserved.** Do not destroy source videos, raw shot positions or course revision history.
7. **Privacy and safety are default behaviours.** Precise location, private rounds and videos are not public unless the user deliberately shares them.
8. **Tournament mode removes disallowed assistance.** Slope/weather adjustment and club recommendations can be disabled while retaining permitted distance information.

## 3. Primary users and jobs

### Casual golfer

- find a course;
- get front/centre/back and hazard distances;
- keep score with friends;
- film a satisfying tracer;
- review and share the round.

### Improving golfer

- record clubs, lies and outcomes;
- learn actual club-distance distributions;
- see shot dispersion and strokes gained;
- compare performance over time;
- receive plays-like and club suggestions in casual rounds.

### Course contributor

- add a missing course using satellite imagery;
- map tees, greens and hazards;
- walk the course and capture accurate live GPS points;
- submit corrections when a course changes.

### Group organiser

- invite players;
- choose Stroke Play, Match Play or Stableford;
- view live scoring;
- preserve a group round and media recap.

### Moderator/administrator

- review duplicate or suspicious courses;
- merge contributions;
- approve/reject disputed revisions;
- restore an earlier version;
- handle privacy, abuse and deletion requests.

## 4. Product surfaces

The cross-product visual language, navigation, Profile/Settings menus and animation behaviour are defined in [`interface-design-system.md`](interface-design-system.md).

### Public landing website

- clear product proposition;
- screenshots/demos;
- course-coverage search;
- feature and pricing overview;
- account creation and sign-in;
- privacy, terms and support;
- app-store links;
- web-based course registration/editor where practical.

### Mobile app

- authentication and onboarding;
- automatic nearest-course home section and nearby/course search;
- course and hole maps;
- round/scoring experience;
- GPS and shot tracking;
- camera/tracer capture and editing;
- bag, statistics and profile;
- course creation using live GPS;
- offline cache and sync.

The main mobile destinations are `Home`, `Play`, `Gallery`, `Range` and `Profile`. `Range` opens the page titled **Driving Range**. Settings are entered from Profile rather than occupying a sixth tab.

### Administrative console

- course moderation;
- duplicate detection;
- geometry revision comparison;
- user/report management;
- feature flags;
- tracer-processing diagnostics;
- data-quality and system-health dashboards.

## 5. Recommended technical direction

This is a provisional recommendation to validate before implementation.

### Client architecture

- **Mobile shell:** React Native with TypeScript for shared product UI, data, auth and mapping flows.
- **Native modules:** Swift/AVFoundation/Vision/Core ML on iOS and Kotlin/CameraX/ML Kit or TensorFlow Lite on Android for camera capture, device sensors and low-latency tracer processing.
- **Web:** Next.js with TypeScript for the landing page, account surfaces and desktop course editor.
- **Shared contracts:** generated TypeScript types from the database/API schema.

Why not make visual tracing entirely cross-platform? Camera formats, frame timing, exposure, thermal state, GPU/ML acceleration and video export need platform-specific control. The product shell can be shared, but the tracer engine should have a native boundary.

### Delivery order

Start with an iPhone tracer implementation because SmoothSwing demonstrates demand there and Apple provides a relatively consistent AVFoundation/Vision/Core ML stack. Do not block the GPS/course/scoring app on completion of the tracer. Android should be designed into the data contracts and added through its own validated camera pipeline.

### Backend

- **Supabase Auth:** Apple, Google, email/password and optional username login.
- **PostgreSQL:** primary relational database.
- **PostGIS:** course coordinates, polygons, proximity searches and geometry validation.
- **Supabase Storage:** avatars, course assets, exported tracer videos and permitted source uploads.
- **Row Level Security:** mandatory ownership, visibility and moderation rules.
- **Edge Functions/server API:** privileged mutations, course publishing, duplicate detection, media processing requests and provider secrets.
- **Realtime:** group scoring and selected round events.
- **Background workers:** media transcoding/refinement, statistics aggregation, notifications and data-quality jobs.

The mobile app must never contain database service-role credentials, satellite-provider secrets or unrestricted storage credentials.

### Maps and imagery

**Release 1 iOS course-recording decision (29 July 2026):** use the official Google Maps SDK for iOS for in-app tee/green placement, with native Apple satellite mapping as a functional fallback before the key is configured. Keep stored community geometry provider-neutral. The Google project must enable only Maps SDK for iOS, use no map ID or Street View, and restrict its key to OverPar's iOS bundle identifier and that SDK. Google tiles must never be scraped or displayed through an unofficial workaround.

Before expanding or replacing the provider elsewhere, continue to evaluate:

- iOS, Android and web SDK coverage;
- satellite/aerial resolution in target markets;
- per-user and tile pricing;
- offline caching restrictions;
- whether users may derive and permanently store course coordinates from imagery;
- attribution requirements;
- static-image/video export permissions;
- rate limits.

Provider terms are a product constraint, not a late implementation detail. OverPar should store user-created coordinates and geometry, not copy or redistribute satellite tiles beyond the provider licence.

## 6. Authentication and account design

The researched profile identity, privacy, home/favourite course, contribution-attribution, avatar and trust-role behaviour is specified in [`profile-system.md`](profile-system.md). The first authorised performance surface—personal club distances—is specified in [`driving-range-and-club-recommendations.md`](driving-range-and-club-recommendations.md). Other performance statistics remain excluded until separately specified.

### Supported methods

- Sign in with Apple;
- Sign in with Google;
- email/username and password;
- password reset;
- verified email changes;
- account linking so the same person does not receive duplicate accounts.

Apple sign-in should be offered wherever other third-party social sign-in is presented on iOS, subject to current App Store rules.

### Username behaviour

- case-insensitive uniqueness;
- separate immutable user UUID;
- profanity/reserved-name filtering;
- username history or cooldown to prevent impersonation;
- display name may be non-unique;
- never use username as a database foreign key.

Profiles use a non-unique editable display name plus a unique `@username`, both separate from the immutable Supabase user UUID. OAuth-provided names and avatars are suggestions that the user confirms; later sign-ins must not silently overwrite the OverPar profile. This is especially important because Sign in with Apple may provide the person's name only during the first authorization.

### Onboarding

1. accept terms/privacy;
2. confirm a required display name and choose a unique username;
3. select yard/metre units;
4. optionally add an avatar, short biography and broad city/region;
5. request location only when explaining its on-course value;
6. request camera/microphone/photo permissions when tracer capture is first used;
7. optionally choose up to five home courses and pin one;
8. offer course discovery or “add a missing course.”

During setup, present a `Find your nearest course` explanation and offer foreground/When-in-Use location permission. Trigger the operating-system prompt only after the user chooses `Enable nearby courses`. Denial must not block onboarding; fall back to course-name, city and postcode search. Approximate location is sufficient for broad nearby discovery, while walk-mode course capture can later explain why precise location is required.

### Account deletion

Deleting an account should:

- remove/anonymise personal profile and private data according to policy;
- preserve community course geometry under an anonymous contributor record where legally permitted;
- remove public attribution if requested;
- queue user media for deletion;
- retain necessary audit/security records for a documented period.

### Profile scope before statistics

Profile v1 includes:

- display name and `@username`;
- avatar and short biography;
- optional broad city/region, never precise/current location;
- up to five home courses, one pinned, with explicit membership visibility;
- private favourite courses;
- published community course contributions;
- trusted mapper, verified course representative and moderator/team badges;
- community/private visibility;
- block/report foundations;
- separate public-profile, application-preference and security settings.

It does not yet display handicap, scores, rounds, leaderboards or general performance summaries. It may display the private-by-default club-distance card specified for Driving Range.

## 7. Community course registration

The screen-level course-recording specification, GPS sampling design, draft state machine and publication contract are defined in [`course-recording-workflows.md`](course-recording-workflows.md). That specification is authoritative for implementation details.

Community home discovery, foreground location onboarding, name/city/postcode/GPS search and required per-hole par entry are defined in [`community-course-discovery.md`](community-course-discovery.md).

The progressive ideal data model—facility/layout hierarchy, tee sets, scorecard lengths, stroke indexes, Course Rating/Slope evidence, green/hazard geometry, shared nines, temporary overlays and completeness badges—is defined in [`ideal-course-data-and-creation.md`](ideal-course-data-and-creation.md). It enriches rather than replaces the minimum creation flow.

### Creation routes

#### A. Satellite-map editor

The contributor:

1. searches by course/club name or map location;
2. confirms no matching course already exists;
3. enters course identity and address;
4. creates/selects an 18-hole, 9-hole or custom layout;
5. enters the par for every hole;
6. selects a tee-box point for hole 1 on a satellite map;
7. selects a flag/green-reference point for hole 1;
8. reviews the line and calculated distance;
9. taps `Save & next hole` and repeats;
10. reviews the complete course, pars and geometry before submission.

The first version requires one tee, one flag/green reference and par for every hole. Richer tee sets, green polygons, bunkers, water, lay-up targets, fairways, out-of-bounds and stroke index are additive enhancements. A green polygon is eventually preferable because bearing-relative front/centre/back can be derived from it, but it must not make the simple first course-recording flow cumbersome.

Par is not optional: the contributor selects `3`, `4`, `5` or an allowed `Other` value for every hole before publication. Total course par is derived from hole pars. Course name, hole count and pars are part of the immutable revision so later edits do not change historical rounds.

On a phone, use a centre crosshair as the primary precise placement interaction: the contributor pans the imagery under the fixed crosshair and confirms the point. Direct tapping and draggable markers provide quick placement and correction. This avoids hiding a small tee or green under the contributor's finger.

#### B. Live-GPS walking mode

The contributor physically visits the course:

1. starts a course-capture session;
2. sees `Hole 1 — Go to tee`;
3. taps `Capture tee location`;
4. waits briefly while multiple fresh GPS fixes are collected and stabilised;
5. walks to the flag/green;
6. taps `Capture flag location`;
7. reviews the two points, accuracy and calculated length;
8. taps `Next hole`;
9. repeats for each hole;
10. reviews and submits the captured course.

The interface may use the familiar label **Flag location**, with helper text explaining that the point becomes a persistent green reference because the physical cup moves. In schemas and APIs, call it `green_reference`; reserve daily pin/hole locations for a future expiring daily-pin feature.

Mode belongs to each captured point, not to the entire draft. A contributor may map most holes from satellite imagery, capture others with live GPS, or replace a poor GPS point with satellite placement.

### GPS capture quality

Each captured point should store:

- latitude/longitude;
- horizontal accuracy radius;
- altitude and vertical accuracy if available;
- timestamp and fix age;
- source device/platform;
- capture method;
- sample count;
- sample spread and capture duration;
- derived median/filtered coordinate;
- whether a quality warning was overridden;
- whether this capture supersedes another draft capture;
- contributor and course revision.

Do not accept a single arbitrary location silently. Recommended capture:

1. require an accuracy threshold or warn the user;
2. start a bounded 8–15 second sampling window;
3. collect several fresh fixes and finish early when accuracy and stability are strong;
4. reject stale and spatially inconsistent readings;
5. calculate a robust median or accuracy-weighted representative point;
6. display accuracy, sample stability and the point on a mini-map;
7. store the final point and quality metadata;
8. offer recapture or satellite placement when quality is poor.

Live GPS is well suited to tee and green-centre points but poor for tracing precise green boundaries unless the contributor walks them with stable fixes. Satellite editing and GPS capture should be composable in the same revision.

The basic walk workflow stores point captures only, not the user's continuous route around the course. High-accuracy updates should stop/reduce between captures to protect privacy and battery.

### Draft durability

Course recording may take several hours and must survive backgrounding, termination, weak connectivity and authentication refresh. Persist locally and enqueue idempotent draft sync after:

- course basics;
- every confirmed tee or flag capture;
- every satellite point adjustment;
- next/previous-hole movement;
- skips;
- pause/exit.

On relaunch, offer `Resume recording — N of M holes complete`. Never silently restart continuous high-accuracy GPS merely because a draft exists.

### Course identity and duplicate prevention

Before creating a course, search by:

- normalised name and aliases;
- address/postcode;
- distance from proposed clubhouse/first tee;
- overlapping hole geometry;
- external course identifiers, when legitimately licensed.

Possible outcomes:

- use existing course;
- propose an edit;
- add another course at the same club;
- continue creating a genuinely new course;
- submit a merge request.

Never deduplicate only by name. Different clubs share names, and one club can have several layouts.

### Community discovery and search

With foreground location permission, the home screen automatically requests one fresh-enough position and queries the nearest published course using its indexed PostGIS discovery point. It shows course name, distance, hole count, total par when verified, and `View course`/`Start round`. It then stops active location work rather than continuously tracking the home screen.

Without permission, show `Enable location` alongside manual search. Search supports:

- course or club name;
- city/locality;
- postcode;
- current GPS position.

Name/address fields use indexed PostgreSQL text search plus typo-tolerant matching where appropriate. City/postcode queries that do not directly match stored course fields are geocoded server-side through the selected map provider, then converted into a PostGIS nearby-course query. Provider secrets remain server-side and caching follows provider terms.

Published courses require a representative `discovery_location`, derived from a verified clubhouse point, course geometry centre or first tee fallback. Search and nearest-course APIs return only published/searchable courses and accept bounded radii/result limits.

### Publishing model

Recommended trust states:

- `draft`: visible only to creator/collaborators;
- `submitted`: awaiting automated checks or moderation;
- `community`: published but community-sourced;
- `verified`: confirmed by trusted contributors/course owner;
- `disputed`: visible with warning while a material issue is reviewed;
- `archived`: no longer active but retained historically.

A new course may publish quickly after automated validation, but sensitive or suspicious edits should require moderation. Publication policy can tighten as usage grows.

### Editing and permanence

Courses are never edited destructively:

- a course has a stable ID;
- every change creates a revision;
- the published course points at one current revision;
- revisions record contributor, source, reason and timestamp;
- geometry diffs can be reviewed;
- moderators can revert or merge;
- archived layouts remain attached to historical rounds.

Past rounds should reference the exact course revision used at play time. Otherwise later green/tee edits would rewrite historical distances.

### Course ownership

Community contribution is not legal ownership. Provide a course-owner verification process that can:

- mark the official account;
- propose authoritative scorecard/map updates;
- publish temporary closures or alternate greens;
- manage attribution;
- coexist with a transparent community correction process.

## 8. Proposed Supabase/Postgres data model

This is a logical starting schema, not final migration SQL.

### Identity

```text
profiles
  id uuid PK -> auth.users.id
  username citext UNIQUE
  display_name text
  avatar_path text
  bio text nullable
  location_label text nullable
  show_location boolean
  visibility enum(community, connections, private)
  discoverable boolean
  unit_system enum(yards, metres)
  locale, timezone nullable
  created_at, updated_at

username_history
  user_id uuid FK
  previous username and redirect/cooldown metadata

profile_home_courses
  user_id uuid FK
  course_id uuid FK
  sort_order integer
  is_pinned, is_visible boolean

favorite_courses
  user_id uuid FK
  course_id uuid FK

profile_roles
  user_id uuid FK
  trusted role and optional scope
  granted_by, granted_at, revoked_at

profile_blocks
profile_reports

user_devices
  id uuid PK
  user_id uuid FK
  platform, model, os_version, app_version
  push_token encrypted/secured
  last_seen_at
```

### Courses and versioned mapping

```text
clubs
  id uuid PK
  name, address fields, country_code, timezone
  location geography(Point, 4326)
  status

courses
  id uuid PK
  club_id uuid nullable FK
  name, slug
  hole_count
  discovery_location geography(Point, 4326)
  total_par integer derived/cached
  status, verification_level
  current_revision_id uuid nullable
  created_by uuid nullable
  created_at, updated_at

course_revisions
  id uuid PK
  course_id uuid FK
  revision_number integer
  state
  change_summary
  capture_method enum(map, live_gps, import, merged)
  created_by uuid nullable
  reviewed_by uuid nullable
  created_at, published_at

holes
  id uuid PK
  course_revision_id uuid FK
  hole_number integer
  par integer NOT NULL for a publishable revision
  stroke_index integer nullable
  green_polygon geography(Polygon, 4326) nullable
  green_centre geography(Point, 4326)
  explicit_front/back geography(Point, 4326) nullable

tee_sets
  id uuid PK
  course_revision_id uuid FK
  name, colour, gender/category
  course_rating, slope_rating

tee_positions
  id uuid PK
  hole_id uuid FK
  tee_set_id uuid FK
  location geography(Point, 4326)
  published_yardage integer nullable

course_features
  id uuid PK
  hole_id uuid FK
  type enum(bunker, water, layup, dogleg, fairway, out_of_bounds, other)
  geometry geography(Geometry, 4326)
  label text nullable

geometry_captures
  id uuid PK
  revision_id uuid FK
  entity_type, entity_id
  raw_location geography(Point, 4326)
  horizontal_accuracy_m numeric
  altitude_m, vertical_accuracy_m nullable
  captured_at, capture_method, sample_count
```

Add constraints such as unique `(course_revision_id, hole_number)`, valid hole ranges, valid latitude/longitude, green geometry sanity, and no published revision with missing required tee/green data.

### Rounds, players and shots

```text
rounds
  id uuid PK
  course_id uuid FK
  course_revision_id uuid FK
  owner_id uuid FK
  tee_set_id uuid nullable
  format enum(stroke, stableford, match, gps_only)
  visibility enum(private, friends, public)
  tournament_mode boolean
  status enum(planned, active, completed, abandoned)
  started_at, completed_at

round_players
  id uuid PK
  round_id uuid FK
  user_id uuid nullable
  guest_name text nullable
  playing_handicap numeric nullable
  team integer nullable

hole_scores
  id uuid PK
  round_player_id uuid FK
  hole_number integer
  strokes, putts, penalties
  fairway_result, gir

shots
  id uuid PK
  round_player_id uuid FK
  hole_number, shot_number
  club_id uuid nullable
  start_location, end_location geography(Point, 4326) nullable
  start_accuracy_m, end_accuracy_m nullable
  lie_before, result
  capture_method enum(manual, phone_inferred, watch, tag, corrected)
  raw_distance_m, adjusted_distance_m nullable
  confidence numeric nullable
  occurred_at
```

### Bag, statistics and recommendations

Detailed behaviour and data contracts are defined in [`driving-range-and-club-recommendations.md`](driving-range-and-club-recommendations.md).

```text
clubs
  id uuid PK
  user_id uuid FK
  category, number_or_role, display_name
  brand, model, loft_degrees nullable
  status enum(active, inventory, retired)

range_sessions
  id uuid PK
  user_id uuid FK
  distance_kind enum(carry, total)
  source, started_at, ended_at

club_distance_observations
  id uuid PK
  user_id, club_id, session_id nullable
  context, distance_kind, distance_m, source
  shot_intent, quality_label, included_by_user
  occurred_at

club_distance_aggregates
  club_id uuid FK
  distance_kind, period_filter, algorithm_version
  raw_sample_count, eligible_sample_count
  arithmetic_mean_m, median_m, trimmed_mean_m
  playing_distance_m, p20_m, p80_m, confidence
  dispersion geometry nullable
  updated_at

player_statistics
  user_id, period/course filters
  rounds, scoring, fairway, gir, putting
  strokes_gained categories
  generated_at
```

Recommendations use active-bag distributions and confidence/sample size, not only a single club average. Carry and total remain separate.

### Visual tracing

```text
tracer_projects
  id uuid PK
  user_id uuid FK
  round_id, shot_id nullable
  source_video_path
  source_metadata jsonb
  impact_frame/time nullable
  status
  processing_mode enum(on_device, cloud, hybrid, manual)
  visibility
  created_at, updated_at

tracer_versions
  id uuid PK
  project_id uuid FK
  version_number
  camera_transforms jsonb/storage reference
  observations jsonb/storage reference
  curve_control_points jsonb
  observed_fraction numeric
  confidence_components jsonb
  overall_confidence numeric
  style jsonb
  created_by enum(auto_live, auto_refined, user, moderator)

tracer_exports
  id uuid PK
  tracer_version_id uuid FK
  output_path
  format, resolution, duration
  watermark_state
  created_at, expires_at nullable
```

Large frame-by-frame arrays may belong in compressed object storage rather than a giant database row. Database records should retain queryable summaries and durable references.

### Social, reports and moderation

```text
friendships/follows
round_invites
course_reports
revision_reviews
moderation_actions
notifications
audit_events
```

Audit logs must avoid storing unnecessary raw location or tokens.

## 9. Row Level Security outline

- Public users may read only published public course revisions and explicitly public profiles/rounds.
- Authenticated users may update only their own profile, bag, private rounds and tracer projects.
- Round participants may read/write their permitted active-round scoring rows.
- Contributors may edit their course drafts, never published revisions in place.
- Publishing runs through a server function that validates and creates the immutable revision.
- Moderators receive scoped access through claims/roles and audited server operations.
- Storage paths are private by default; signed URLs control temporary access.
- Source tracer videos are accessible only to their owner and explicitly authorised processing workers.
- Service-role operations never execute directly from an untrusted client.

RLS policies require automated tests. “The UI hides the button” is not security.

## 10. GPS and on-course system

The detailed preview-to-play journey, active-hole controls, shot actions and Gallery lifecycle are defined in [`round-companion-and-gallery.md`](round-companion-and-gallery.md).

### Round start

1. optionally preview the saved course and individual holes over licensed satellite imagery;
2. fetch/download the selected published course revision;
3. select tee set, format, players, starting hole and assistance mode;
4. establish current location and accuracy;
5. cache round/course state locally;
6. start controlled high-accuracy updates.

Saved and nearest-course cards expose `Preview` and `Play`. Starting a round pins the exact immutable course revision.

### Distance engine

- raw geodesic distances to green and features;
- bearing-aware front/back derived from green polygon where available;
- draggable map target;
- accuracy radius and stale-fix handling;
- tournament-compliant raw mode;
- optional adjusted distance from elevation/weather;
- personal club-reach arcs and recommendations.

### Offline-first round storage

Use a local transactional database:

- all score/shot changes write locally first;
- each mutation receives a client-generated UUID and timestamp;
- a sync queue retries safely;
- server calls are idempotent;
- conflicts are resolved per entity, with explicit review for competing score edits;
- group realtime is opportunistic, not required to preserve the local score.

The active-hole screen exposes separate actions:

- **Log Shot** for correctable GPS endpoints, club and lie/outcome data;
- **Record Shot** for camera video and visual tracing.

They may reference the same shot but remain separate records and may be used independently.

Finishing `Log Shot` captures:

- target-relative `on target`, `left` or `right`;
- optional flight shape (`straight`, `draw`, `fade`, `hook`, `slice`, `pull`, `push`);
- optional strike quality (`solid`, `fat/heavy`, `thin`, `topped`, `shank`, `sky`, `toe`, `heel`);
- finishing outcome/lie (`fairway`, `rough`, `bunker`, `fringe`, `green`, `general area`, `penalty area`, `out of bounds/lost`, `holed`).

These are separate fields. Out of bounds/lost invokes official stroke-and-distance (+1 from the prior location), applicable Model Local Rule E-5 (+2), or provisional-ball handling. A nearby +1 drop is available only as a labelled non-conforming casual rule.

### Battery behaviour

- high accuracy only during active play;
- pause/reduce updates when the round is backgrounded according to platform rules;
- use watch position deliberately, not accidentally;
- offer low-battery mode;
- stop all round tracking visibly at completion;
- record diagnostic energy/thermal metrics with consent.

## 11. Visual shot-tracer system

The detailed vision pipeline is in the companion research. The implementation target is:

```text
camera capability/scene check
  -> rolling capture buffer
  -> impact event
  -> camera-motion solution
  -> stationary ball origin
  -> temporal ball observations
  -> sequence tracking/filtering
  -> observed/interpolated/extrapolated segmentation
  -> confidence-aware curve
  -> manual repair if needed
  -> non-destructive render/export
```

### First tracer MVP

- iOS;
- rear camera;
- daylight;
- fixed phone/tripod behind golfer;
- white ball;
- manual source-video preservation;
- automatic impact and early-flight detection;
- plausible 2D continuation clearly treated as visual;
- immediate provisional result;
- simple launch/apex/curve/landing controls;
- tracer colour, width, glow and timing;
- local export/share.

### Later tracer capabilities

- full-clip refinement;
- imported clips;
- handheld shake and deliberate panning;
- additional ball colours;
- Android native engine;
- rolling automatic shot capture;
- live broadcast-style overlays;
- GPS distance/map replay;
- optional launch-monitor inputs;
- transparent observed-versus-estimated confidence.

### Media handling

- process on device by default;
- cloud refinement is opt-in;
- upload with resumable signed requests;
- define source-video retention;
- strip unnecessary EXIF/location from public exports;
- use background jobs for transcoding;
- never train on user footage without separate explicit consent;
- provide deletion controls.

## 12. Scoring, stats and social features

### Round formats

- Stroke Play;
- Stableford;
- Match Play;
- GPS-only practice;
- solo and group rounds;
- guest players without forced registration.

### Basic statistics

- score relative to par;
- fairways and miss direction;
- greens in regulation;
- putts;
- penalties;
- scrambling/sand saves where captured;
- club distances;
- course and hole history.

The first statistics surface is named **Driving Range**. It records repeated club distances, shows an arithmetic average plus a robust playing distance/range, and provides a private-by-default profile summary. This does not authorise the other statistics above.

### Advanced statistics

- strokes gained off tee, approach, around green and putting;
- shot dispersion and percentile club distances;
- scoring by par/course/conditions;
- trends with sample-size warnings;
- raw versus adjusted distance outcomes.

### Social

- invite link/code;
- live group leaderboard;
- friend/follow model selected intentionally;
- shareable round recap;
- tracer clips attached to shots;
- privacy per round and media item;
- block/report controls.

### Gallery

Recorded shot videos and visual tracer projects appear in a private-by-default page named **Gallery**, filterable by round, course, hole, club and processing status. Source video, tracer versions, rendered exports and linked GPS shots remain separate durable objects. Round completion never waits for Gallery upload or processing.

## 13. Plays-like and club-assistance engine

The attack-first and last-resort lay-up behaviour is defined in [`driving-range-and-club-recommendations.md`](driving-range-and-club-recommendations.md). GPS distance alone is not enough to infer that a lay-up is smart.

Inputs may include:

- raw target distance;
- elevation change;
- wind speed and direction;
- temperature, humidity and altitude;
- lie and shot type;
- player's club-distance distribution;
- uncertainty and sample size.

Outputs:

- raw distance remains prominent;
- adjusted plays-like distance;
- recommended club or small set of options;
- expected landing/dispersion region;
- explanation such as “+8 yd: uphill and into wind”;
- confidence level.

Do not claim that weather-derived recommendations are exact. Store provider timestamps and refuse to use stale weather silently.

Attack towards a safe green target is the default. Lay-up advice requires trustworthy mapped risk and personal distance/dispersion evidence, and must beat attack by a meaningful expected-cost margin. Without those inputs, provide a distance-based club option without inventing a lay-up verdict.

## 14. Course and user safety

- Warn contributors not to obstruct play or enter restricted/private areas.
- Live course mapping should be completed only where the user has permission to be.
- Do not encourage walking green boundaries during active play.
- Prevent precise live user locations from appearing publicly.
- Delay/aggregate public round location if live sharing is ever added.
- Provide content reporting and moderation.
- Protect minors through appropriate account/privacy design.
- Display an on-course camera warning so users do not place phones where balls or clubs could hit them.

## 15. Observability and analytics

Track privacy-conscious product events:

- sign-up completion by method;
- course search success/failure;
- missing-course creation funnel;
- course submission/approval/rejection;
- GPS time-to-first-stable-fix and accuracy distribution;
- round start/completion and offline-sync failure;
- shot capture/edit rate;
- tracer impact detection, shareable-without-edit rate and correction time;
- processing latency, temperature and export failure;
- subscription conversion when monetisation begins.

Operational monitoring:

- API/database latency and error rates;
- RLS/authorisation failures;
- realtime connection health;
- storage/worker backlog;
- duplicate course rate;
- course report resolution time;
- crash-free sessions by device;
- tracer quality by device/capture conditions.

Never put access tokens, exact private coordinates or private video URLs in logs.

## 16. Quality strategy

### Automated testing

- unit tests for distance/bearing and score calculations;
- property tests for coordinate and unit conversion;
- database constraints and migration tests;
- RLS tests for every role/visibility combination;
- API idempotency and offline replay tests;
- map-editor geometry validation;
- tracer renderer golden-image/video tests;
- ML regression set split by device/session/course;
- authentication linking and deletion tests.

### Field testing

Test:

- open links, wooded parkland and urban-adjacent courses;
- poor/no mobile signal;
- nine, eighteen and multi-layout clubs;
- alternate greens/tees;
- walking, trolley and cart play;
- phone in pocket versus cart;
- Apple Watch/Android watch when supported;
- hot/cold weather and low battery;
- crowded driving ranges;
- white, yellow and patterned balls;
- fixed and panning video;
- multiple phone generations.

### Release gates

- no high-severity auth/RLS failures;
- active round recoverable after app termination;
- course drafts and revisions cannot be lost silently;
- GPS uncertainty displayed correctly;
- source tracer video preserved on processing failure;
- manual tracer always completes successfully;
- published course changes reversible;
- account export/deletion works.

## 17. Delivery phases

### Phase 0 — foundations

- settle platform and map provider;
- set up Supabase environments and migrations;
- authentication;
- design system and landing page;
- profiles and basic course search;
- CI, telemetry, crash reporting and feature flags.

### Phase 1 — community course database

- PostGIS schema;
- satellite course editor;
- drafts/revisions/publication;
- duplicate detection;
- course search and detail;
- moderation console;
- live-GPS capture for tees and green centres.

### Phase 2 — GPS rounds

- map/download course;
- raw distances and accuracy;
- scoring formats;
- offline local round;
- history and basic stats;
- group invitation and live scoring.

### Phase 3 — manual shots and club intelligence

- bag;
- manual shot endpoints;
- club/lie capture;
- shot repair;
- distance distributions;
- advanced stats/strokes gained.

### Phase 4 — visual tracer MVP

- manual editor first;
- iOS fixed-camera automatic capture;
- white-ball temporal tracking;
- immediate plus refined trace;
- confidence and correction;
- export/share and attach to a shot.

### Phase 5 — caddie and watch

- watch distances/scoring;
- swing-event suggestions;
- plays-like distances;
- weather/elevation;
- club recommendations and dispersion.

### Phase 6 — advanced tracing and scale

- panning-camera transforms;
- Android tracer;
- more ball types;
- optional cloud refinement;
- richer overlays/map replay;
- course-owner verification and contributor reputation;
- performance/cost optimisation.

“All features” remains the destination, but these phases prevent the riskiest computer-vision work from blocking a useful course/GPS product.

## 18. Monetisation candidates

Keep the initial value proposition generous:

### Free

- account and course discovery;
- community course contribution;
- raw GPS front/centre/back;
- scorecard and basic stats;
- limited/manual tracer with watermark or fair export limits;
- public course corrections.

### Premium

- plays-like/weather/elevation;
- club recommendations and dispersion;
- strokes gained/advanced history;
- watch automation;
- unlimited/refined tracer exports;
- premium tracer styles and broadcast overlays;
- cloud backup/refinement where costly.

Avoid putting community course creation behind a paywall; it improves the shared network. Do not degrade automatic tracking quality after purchase—the paid benefit can be volume, refinement, export and advanced presentation.

## 19. Major risks and mitigations

| Risk | Consequence | Mitigation |
|---|---|---|
| bad community mapping | unsafe/untrusted distances | accuracy metadata, validation, revisions, reports and moderation |
| duplicate courses/layouts | fragmented history | proximity/name/geometry detection and merge tools |
| satellite licence mismatch | forced redesign/legal exposure | select provider and review terms before editor build |
| weak phone GPS | false precision | accuracy radius, stable sampling and correction |
| visual tracer failure | user distrust | constrained MVP, confidence and excellent manual fallback |
| camera heat/battery | unusable sessions | capability checks, adaptive modes and two-pass processing |
| private location leakage | safety/privacy harm | private defaults, RLS, stripping metadata and audited sharing |
| offline conflict/data loss | lost rounds | local-first writes, UUIDs, idempotent sync and recovery |
| scope explosion | no shippable product | vertical phases with explicit release gates |
| unaffordable imagery/video costs | poor unit economics | cost modelling, caching within terms and on-device processing |
| patent/trademark conflict | commercial risk | professional search before tracer commercialisation |

## 20. Decisions required before coding

1. iOS-first or simultaneous iOS/Android launch?
2. React Native/native-module approach, or fully native clients?
3. Satellite/map provider and permitted offline/derived-data use?
4. Initial target geography?
5. Immediate community publishing or moderator approval?
6. Minimum course definition: tee + green centre, or complete tees/green geometry/scorecard?
7. Public social model: friends, followers or round invite only?
8. Tracer pricing: one-time purchase, subscription or premium bundle?
9. Is cloud video refinement acceptable, optional or excluded?
10. Which features must work in the first public beta?

## 21. Definition of the first compelling beta

A user can:

- create an account using Apple, Google or email/password;
- find an existing course or register a missing one;
- map tees and greens using satellite imagery or live GPS;
- submit the course and retrieve it permanently on another device/account;
- start a round with an offline-capable course;
- see raw GPS distances with an accuracy indicator;
- keep a score and finish/recover the round;
- record a golf video;
- produce a reliable manual tracer and an automatic fixed-camera trace on supported iPhones;
- correct, save and share the trace;
- report an incorrect course;
- control the visibility and deletion of personal data.

This beta demonstrates the complete OverPar promise—community courses, GPS, scoring and visual tracing—without pretending every advanced automation is already solved.

## 22. First actions when development is authorised

1. Confirm the decisions in section 20.
2. Inspect current repository state and choose the app/web workspace structure.
3. Create development, staging and production Supabase projects.
4. Select/review the map provider contract.
5. Convert the logical schema into versioned migrations with RLS tests.
6. Build an interactive product skeleton covering auth, course search, empty states and navigation.
7. Prototype satellite course mapping and live GPS capture separately.
8. Build the non-destructive manual tracer editor before training an automatic model.
9. Establish field-test footage and course-mapping datasets.
10. Ship narrow internal vertical slices and measure them on real courses.
