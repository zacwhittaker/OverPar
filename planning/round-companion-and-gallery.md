# OverPar round companion, course preview and Gallery

**Prepared:** 29 July 2026  
**Status:** Approved product-flow specification  
**Related:** [`overpar-app-build-blueprint.md`](overpar-app-build-blueprint.md), [`driving-range-and-club-recommendations.md`](driving-range-and-club-recommendations.md), and [`../research/golf-gps-and-shot-tracking-apps.md`](../research/golf-gps-and-shot-tracking-apps.md)

## 1. Product decision

A golfer should be able to find a saved course and press **Play** with very little setup. They may optionally preview the entire course over satellite imagery first.

During the round, one companion screen combines:

- live GPS distance;
- satellite hole map;
- personal club recommendation;
- score and hole progress;
- manual GPS shot logging;
- a prominent **Record Shot** camera/tracer action.

Recorded shot videos and tracer results are saved into a first-class page named **Gallery**. A Gallery item can remain linked to the originating round, hole and shot without making the source video public.

The app must distinguish:

- **Log Shot** — records golf data and GPS endpoints;
- **Record Shot** — records camera video for a visual tracer and can also attach it to a logged shot.

This avoids claiming that a camera recording measured GPS distance or that two GPS points measured the airborne flight.

## 2. Reference-screen conclusions

The supplied Wedge references demonstrate useful ideas:

- nearest/saved course cards should expose `Preview` and `Play Golf` directly;
- course identity, hole count, par and distance from user belong above the actions;
- the detail view should retain a large primary `Play Golf` action;
- contact/address information can exist without obstructing play.

The supplied SmoothSwing reference demonstrates:

- camera capture needs one obvious record control;
- a setup guide should show where golfer and ball belong in frame;
- handedness/framing guidance can be presented visually;
- timer, flash and tracer styling must not compete with the shutter;
- the capture interface should feel like a camera, not a scorecard.

OverPar should adopt the useful interaction principles, not visually copy either product.

## 3. End-to-end golfer journey

### A. Before leaving home

The golfer opens a saved course from:

- `Saved courses`;
- nearest course on Home;
- search results;
- recent course;
- a shared course link.

The course card has:

```text
Royal Example Golf Club
18 holes · Par 72 · 4.2 mi away

[Preview] [Play]
```

Pressing **Preview** does not request continuous GPS or create a round. Pressing **Play** opens a short round setup.

### B. Course preview

Preview opens with a full-course satellite overview fitted to the saved geometry:

- all holes drawn and numbered;
- tee and persistent green reference for each hole;
- tee-to-green line or fairway centreline where available;
- green polygons, bunkers, water, OB and lay-up areas where mapped;
- selected tee-set lengths and par;
- course completeness/verification indicator;
- current revision/update date;
- list or strip for holes 1–9/18.

Selecting a hole flies the satellite camera to that hole and shows:

```text
Hole 7 · Par 4 · 386 yd
[Tee selector]

Front 371 · Centre 386 · Back 401
[Previous hole] [Next hole]
```

The golfer can tap anywhere on the map to inspect distance from the tee or planned landing point. Before a live round this is planning, not live device-to-target ranging.

Primary actions remain:

- `Play this course`;
- `Save offline`;
- `Directions`;
- `Course details`;
- `Suggest correction`.

Satellite tiles are displayed under the selected provider's licence. OverPar stores its own course geometry, not copied satellite imagery.

### C. Press Play

The setup sheet asks only what is necessary:

1. tee set;
2. round type:
   - GPS companion only;
   - Stroke Play;
   - Stableford;
   - Match Play;
3. players/guests if scoring;
4. starting hole, defaulting from current proximity when reliable;
5. active bag confirmation;
6. assistance mode:
   - `Golf assistant` — club and strategy advice;
   - `Rules-compliant` — permitted raw distances only.

Defaults come from the golfer's last round. A returning solo user should usually confirm and begin with one tap.

`Start round`:

- pins the exact published course revision to the round;
- downloads/caches essential course geometry;
- creates a local round immediately;
- requests fresh foreground location;
- starts controlled high-accuracy GPS;
- opens the starting hole.

If offline, play may begin from already cached course data. Sync waits safely.

## 4. Active-hole companion

The main screen is one continuous satellite workspace rather than a separate
diagram, distance card and map. The licensed satellite map fills the screen;
the hole header, compact map tools and companion controls float above it:

```text
Hole 7                   Par 4                   2 over

┌──────────── full-screen satellite map ────────┐
│ Hole 7 · Par 4                         GPS ±4m │
│                                               │
│ tee •──────── user ● ─────────────── green ◎  │
│                            [Set position]      │
│                            [Pin shot]          │
│                                               │
│ ┌──────── floating companion panel ─────────┐ │
│ │ TO GREEN 151 yd             PLAY 7 Iron   │ │
│ │ [Log Shot] [Record]  Score 4 [Complete]   │ │
│ └───────────────────────────────────────────┘ │
└───────────────────────────────────────────────┘
```

Requirements:

- real satellite imagery, saved geometry and friendly labelled markers replace
  decorative or inferred fairway artwork;
- front/centre/back raw distances remain readable;
- current GPS accuracy/staleness is visible;
- the satellite map is the central full-screen surface;
- the initial camera frames the saved tee-to-green extent with approximately
  ten percent context around the hole and does not include an off-course live
  location in those opening bounds;
- drag/tap a target to recalculate raw distance and club option;
- an explicit `Set position` mode lets a tester or golfer tap the map to
  override the device location for the current hole/round;
- manual position mode is always labelled and uses a visually distinct marker;
  it never masquerades as measured GPS;
- `Use GPS` immediately clears the override and returns distance calculations
  to a fresh device location;
- an explicit `Pin shot` mode lets the golfer tap manual shot-start and
  shot-finish endpoints when GPS is unavailable or wrong;
- manual endpoints are stored as manually supplied coordinates and remain
  correctable; they are not assigned fake horizontal-accuracy values;
- club advice is explainable and attack-first;
- lay-up appears only under the Driving Range strategy rules;
- recommendation never covers the raw distance;
- left/right swipe or buttons move holes, with accidental-change protection during an active shot;
- screen stays useful in bright light and poor connectivity;
- low-battery mode reduces map/GPS refresh deliberately.

The app may suggest the current hole from location, but the golfer can correct it instantly.

## 5. Log Shot: GPS/statistical record

### Starting a shot

The golfer stands safely near the ball and presses **Log Shot**:

1. capture a fresh stable GPS point and its accuracy;
2. open a fast active-bag picker and require the golfer to choose the actual
   club; the recommendation is highlighted context, never silently assumed;
3. optionally select lie and shot intent;
4. save the shot start locally;
5. change the button to `Finish Shot`.

Quick mode can accept the recommended/last-used club with a single tap, followed by an unobtrusive correction window.

### Finishing a shot

At the next ball position, press **Finish Shot**:

1. capture another fresh stable GPS point;
2. show endpoint distance and uncertainty;
3. collect the quick shot result described below;
4. open the appropriate relief workflow for a penalty area, lost ball or out of bounds;
5. close the prior shot;
6. offer `Start next shot`.

The endpoint distance is ground distance between device positions. It is not
labelled carry. The user can move/correct either endpoint on the satellite map.
If GPS is unavailable or clearly wrong, `Pin shot` accepts a deliberate map tap
for the start and finish. These endpoints remain classified as manually
supplied rather than measured GPS.

When a club is attached, saving the shot also stores this endpoint distance as
an **on-course GPS playing-distance observation**. It remains separate from
driving-range carry, retains its source, and is excluded when marked as a
mishit. Recommendations prefer robust measured range carry; when that is absent,
robust on-course GPS distance may be used as a visibly lower-confidence
fallback before a purely modelled estimate.

### Shot result prompt

Direction, curvature, strike quality and finishing lie are different facts. Do not present `shank`, `hook`, `topped` and `left` as mutually exclusive answers.

The fast required prompt is:

```text
Where did the shot finish relative to your target?

[On target] [Left] [Right]

Where did it finish?

[Fairway] [Rough] [Bunker] [Fringe]
[Green] [Penalty area] [Out of bounds / lost] [Holed]

[Add shot detail — optional]
```

`On target`, `Left` and `Right` are deliberately relative to the player's intended target, so they work for both left- and right-handed golfers. For tee-shot fairway statistics these map to `fairway`, `miss_left` and `miss_right`.

Optional professional ball-flight detail:

- `Straight` — little meaningful sideways curve;
- `Draw` — controlled curve towards the player's lead side;
- `Fade` — controlled curve towards the player's trail side;
- `Hook` — excessive curve towards the lead side;
- `Slice` — excessive curve towards the trail side;
- `Pull` — starts left of the intended line and stays predominantly left;
- `Push` — starts right of the intended line and stays predominantly right;
- `Other/unsure`.

For a left-handed golfer, the screen may add plain-language direction beneath draw/fade/hook/slice. The stored concept remains relative to handedness and intended target.

Optional strike-quality detail:

- `Solid`;
- `Fat / heavy` — turf struck before ball;
- `Thin` — contact low on the clubface/ball;
- `Topped` — contact on the upper part of the ball, normally very low/short;
- `Shank` — hosel/heel-side strike sending the ball sharply offline;
- `Sky / pop-up` — very high, short strike, normally high on a driver face;
- `Toe` or `Heel`;
- `Other/unsure`.

The app must not diagnose these automatically from endpoint direction. A ball may be pulled and fat, or pushed and sliced, so the optional fields allow combinations.

### Finishing lie

Use golf-course outcome terms:

- `Fairway`;
- `Rough` (with optional first cut/deep rough later);
- `Bunker`;
- `Fringe`;
- `Green`;
- `General area / other` for trees, paths and unmapped areas;
- `Penalty area` for red/yellow penalty areas, including mapped water;
- `Out of bounds / lost`;
- `Holed`.

Out of bounds is not technically a lie because that ball is no longer in play. It is offered in the same outcome control for speed, then opens a rules-aware relief sheet.

### Out of bounds, lost ball and replacement-ball flow

Do not implement a generic “drop near where it went out for +1” as the normal Rules option.

When `Out of bounds / lost` is selected:

```text
Ball out of bounds or lost

[Stroke and distance · +1]
Play again from where the previous stroke was made

[Local Rule E-5 · +2]
Drop in the permitted relief area near the boundary/fairway

[Provisional ball]
Use a provisional already played from the previous position

[Casual drop · +1]
Non-conforming social-round option
```

#### Stroke and distance

- Add one penalty stroke.
- Return the ball/start point to where the previous stroke was made.
- From the teeing area, the replacement ball may be re-teed.
- From the general area, the app records a drop in the permitted previous-spot relief area.
- The next shot number updates automatically. After a tee shot goes OB, the replayed stroke is the player's third stroke.
- The original ball is no longer in play after the replacement is put into play.

The map action is labelled `Place replacement ball at previous position`, not `Drop where it went out`.

#### Model Local Rule E-5

Offer only when the course/round indicates the Local Rule is in effect or the golfer explicitly confirms it:

- add two penalty strokes;
- let the player indicate the estimated ball/boundary reference point;
- help indicate the nearest permitted fairway reference and relief area, no nearer the hole;
- do not offer if a provisional has already become the ball in play;
- label that the option is generally not intended for elite competition.

After a tee shot, the next stroke under E-5 is normally the fourth.

#### Provisional ball

The golfer should ideally press `Provisional` before leaving the previous position:

1. link it to the possibly lost/OB shot;
2. record its start from the previous position;
3. if the original is found in bounds, mark the provisional abandoned without adding it to the score;
4. if the original is lost/OB, promote the provisional and apply the one-stroke penalty.

#### Casual +1 drop

Because the user explicitly wants a quick nearby `Drop ball +1` option, support it only in a casual/non-conforming round:

- warn once that it is not the standard Rules procedure for lost/OB;
- label the round/result as using a custom casual rule;
- add one penalty;
- let the user place the replacement-ball point on the map or capture fresh GPS;
- never allow this option in rules-compliant mode or present the resulting score as eligible for official handicap submission.

### Penalty-area flow

`Penalty area` is separate from out of bounds. It opens the applicable red/yellow relief options with a one-stroke penalty, using the estimated crossing/reference point and mapped boundary when trustworthy. Stroke-and-distance remains available. The app must not assume every water feature is a penalty area unless the course data or user confirms it.

### Friction controls

- Undo last action is always available.
- An unfinished shot survives app termination.
- Auto-suggesting an endpoint is allowed later, but inferred endpoints require confirmation.
- A missed shot can be added from the map.
- GPS logging is optional; scoring still works without it.
- Putting can use simplified count entry rather than forcing noisy GPS points a few metres apart.

## 6. Record Shot: camera and visual tracer

**Record Shot** opens an in-round camera rather than abandoning the round.

### Pre-capture setup

First use requests camera/microphone permission in context. A short overlay guides:

- landscape orientation preferred for reusable video;
- phone fixed safely behind or beside the golfer;
- golfer and ball placement;
- left/right-handed framing;
- enough sky/landing direction in frame;
- daylight/contrast warning;
- tripod or stable support;
- never place the phone where a club or ball can hit it.

Controls:

- large record button;
- front/rear-camera selection where supported, with rear recommended;
- timer/delayed start;
- exposure/focus lock;
- zoom only where validated;
- framing grid;
- storage/battery warning;
- exit back to the live hole.

### Capture

1. Choose or confirm the club.
2. Press the record button or use a short countdown.
3. Record the swing and early ball flight.
4. Stop manually; later a validated impact/post-roll timer may stop automatically.
5. Immediately save the original video locally.
6. Return a provisional trace when available.

Recording can create/attach a shot start at the device position only with explicit user confirmation. It must not silently pretend the phone is exactly at the ball.

### Review

After capture:

```text
Hole 7 · Shot 2 · 7 Iron

[video with provisional trace]

[Looks good] [Adjust trace] [Keep original only] [Retake]
```

Adjustment can correct:

- impact frame;
- ball origin;
- observed path;
- curve/apex/landing visual;
- colour, width and glow;
- crop and trim.

Observed, interpolated, extrapolated and manual segments remain distinct internally. A visually smooth trace is not marketed as measured carry, apex or spin.

The user can:

- save and return to the hole;
- export/share a rendered copy;
- attach/detach from the current GPS shot;
- delete only the export, trace version or source video deliberately;
- finish the tracer later from Gallery.

Automatic failure never blocks saving the original or completing a manual trace.

## 7. Relationship between Log Shot and Record Shot

These actions may be used independently or together:

| Golfer action | GPS shot | Gallery media |
|---|---:|---:|
| Log Shot only | Yes | No |
| Record Shot only | Optional link | Yes |
| Log then Record | Same active shot | Yes, attached |
| Record then confirm Log | Creates/attaches with confirmation | Yes |
| Import video later | Optional later attachment | Yes |

The active round keeps a single `current_shot_id`. A tracer project references it when attached. The video and GPS record remain separate durable objects so correcting or deleting one does not silently corrupt the other.

## 8. Completing a hole

When the golfer reaches the green:

- switch to green detail if mapped;
- show raw front/centre/back until close enough that GPS uncertainty dominates;
- simplify putting entry;
- confirm strokes, putts and penalties if scoring;
- show recorded shots as editable numbered points;
- show video badge on shots with Gallery media;
- `Complete hole` moves to the next hole.

Auto-advance may be suggested from location but never lock the golfer into a wrong hole.

Between holes, show a small recap rather than a blocking results screen:

```text
Hole 7 complete · 5 (+1)
3 logged shots · 1 video
[Review]                         [Go to Hole 8]
```

## 9. Pausing, resuming and finishing

The round can be:

- backgrounded;
- paused;
- resumed after app termination;
- continued offline;
- abandoned with confirmation;
- finished early as 9/partial round.

On relaunch:

```text
Resume Royal Example
Hole 12 · 2 hr 14 min · all changes saved locally
[Resume round]
```

Finishing:

1. stop high-accuracy round GPS visibly;
2. review incomplete holes/shots;
3. confirm final score if scoring;
4. save round history;
5. queue sync and media processing;
6. show recap with `View Gallery`.

Never hold round completion hostage to video upload or tracer processing.

## 10. Gallery

### Navigation

**Gallery** is a first-class app tab/page. It contains visual recordings, not every non-video GPS shot.

Default sections:

- `All`;
- `Rounds`;
- `Driving Range`;
- `Draft traces`;
- `Exports`;
- optionally `Favourites`.

### Gallery card

```text
[video thumbnail + tracer preview]
Royal Example · Hole 7 · Shot 2
7 Iron · 29 Jul 2026
Trace ready                         Private
```

Filters:

- course;
- round/date;
- hole;
- club;
- tracer status;
- original versus exported;
- favourite.

Sort newest first by default.

### Gallery item detail

- original video;
- current tracer preview;
- versions/edits;
- linked course, round, hole and shot;
- club selected by user;
- GPS endpoint distance only if a linked GPS shot exists;
- processing/confidence state;
- edit trace;
- export/share;
- visibility;
- download;
- detach from shot;
- delete controls.

Never label visual trace length as real shot distance. A linked GPS distance is identified as endpoint distance, with accuracy where available.

### Processing states

- `Original saved`;
- `Processing`;
- `Trace ready`;
- `Needs adjustment`;
- `Manual trace`;
- `Exporting`;
- `Failed — original safe`.

The Gallery opens immediately even while background processing or upload continues.

### Privacy and deletion

- Everything is private by default.
- Sharing creates an explicit rendered export; it does not expose the private source.
- Cloud refinement is opt-in with retention disclosure.
- Exact private locations and unnecessary metadata are stripped from public exports.
- Deleting an export does not delete source video.
- Deleting a tracer does not delete its linked GPS shot.
- Deleting source media requires confirmation and documented recovery/retention behaviour.
- Account export/deletion includes Gallery media workflows.

## 11. Proposed data additions

The existing `rounds`, `round_players`, `hole_scores`, `shots`, `tracer_projects`, `tracer_versions` and `tracer_exports` remain authoritative. Add/clarify:

```text
rounds
  course_revision_id uuid NOT NULL
  tee_set_id uuid nullable
  start_hole
  assistance_mode enum(assistant, rules_compliant)
  local_state_version
  paused_at nullable

shots
  start/end GPS and accuracy
  actual_club_id nullable
  recommendation_event_id nullable
  target_location geography(Point, 4326) nullable
  result_direction enum(on_target, left, right, unknown)
  ball_flight enum(straight, draw, fade, hook, slice, pull, push, other, unknown)
  strike_quality enum(solid, fat, thin, topped, shank, sky, toe, heel, other, unknown)
  finishing_lie enum(fairway, rough, bunker, fringe, green, general_area,
                     penalty_area, out_of_bounds_or_lost, holed, unknown)
  media_count derived/queryable

penalty_events
  id uuid PK
  round_player_id, hole_number, related_shot_id
  reason enum(penalty_area, out_of_bounds, lost_ball, unplayable, other)
  relief_procedure enum(stroke_and_distance, local_rule_e5,
                        provisional_promoted, casual_drop, other)
  penalty_strokes smallint
  reference_location, replacement_location nullable
  local_rule_confirmed boolean
  rules_compliance enum(conforming, non_conforming, uncertain)
  created_at

media_assets
  id uuid PK
  user_id uuid FK
  source_kind enum(camera, import)
  media_type enum(video, image)
  private_storage_path
  thumbnail_path nullable
  captured_at
  duration, dimensions, orientation
  local_sync_state, remote_processing_state
  deletion_state

gallery_items
  id uuid PK
  user_id uuid FK
  media_asset_id uuid FK
  tracer_project_id uuid nullable FK
  round_id uuid nullable FK
  shot_id uuid nullable FK
  range_session_id uuid nullable FK
  club_id uuid nullable FK
  title nullable
  favourite boolean
  visibility enum(private, connections, community, unlisted)
  created_at, updated_at
```

`gallery_items` is presentation/linkage, not a duplicate media file. Re-linking a Gallery item does not rewrite the source asset or historical shot.

## 12. Offline and failure behaviour

- Starting/finishing shots writes locally first.
- Recording video never depends on network.
- Original video is durable before processing starts.
- Thumbnail/tracer jobs retry idempotently.
- Failed uploads remain visible as local-only.
- Low storage is checked before recording and explained.
- If GPS permission is denied, satellite preview, scoring and camera still
  work; `Set position` and `Pin shot` permit clearly labelled manual operation,
  while live GPS features explain what is unavailable.
- If camera permission is denied, round GPS and manual shot logging continue.
- If the course map is incomplete, show known geometry and label missing features.
- If satellite imagery cannot load, cached vector geometry/list view still permits the round.

## 13. Accessibility and outdoor usability

- Large targets, high contrast and dynamic type.
- No meaning by colour alone.
- Screen-reader labels include hole, distance type, GPS accuracy and recommendation confidence.
- Camera setup guidance has text and diagrams.
- Haptics can confirm shot start/finish and recording start/stop.
- Avoid long modal flows during play.
- Critical actions have undo rather than repeated confirmation.
- Keep active-hole controls reachable one-handed.

## 14. Acceptance criteria

- Saved/nearest course cards expose **Preview** and **Play**.
- Preview shows saved course geometry over licensed satellite imagery.
- A golfer can inspect every hole without creating a round.
- Play setup is short and remembers safe defaults.
- Starting pins an immutable course revision and creates a recoverable local round.
- Saving an ended round creates a durable completed-round snapshot and presents
  its overview before leaving play.
- Ending without saving clears the active round without creating round history,
  and is presented as a destructive choice distinct from saving.
- The active hole shows raw GPS distance, accuracy, map, score context and explainable recommendation.
- The active hole uses a central satellite map rather than decorative mock
  course artwork.
- A golfer can deliberately set a temporary map position, see that it is
  manual, use it for distance/recommendation testing and return to live GPS.
- A golfer can drop correctable manual start/finish pins when a GPS shot fix
  fails, without those coordinates being represented as measured GPS.
- **Log Shot** records correctable GPS endpoints and club data.
- Finishing a logged shot captures target-relative direction and finishing lie.
- Hook/slice/push/pull remain separate from fat/thin/topped/shank strike quality.
- Out-of-bounds relief defaults to correct stroke-and-distance (+1), not a nearby +1 drop.
- Model Local Rule E-5 uses +2 and is offered only when applicable.
- A requested nearby +1 casual drop exists only as a clearly non-conforming casual-round option.
- Provisional balls can be abandoned or promoted without corrupting stroke counts.
- **Record Shot** opens a purpose-built camera/tracer capture.
- The two concepts remain technically and linguistically separate.
- Original recordings survive tracer failure.
- Recorded videos automatically appear in **Gallery**.
- Gallery media can link to round, hole, shot and club.
- The round can continue while processing/upload occurs.
- Completing the round stops high-accuracy GPS.
- All active-round changes survive network loss and app termination.
- Gallery items are private by default and deletions do not cascade unexpectedly.
- A rules-compliant round removes disallowed assistance.

## 15. Rules and terminology sources

- [R&A Rule 18: lost ball, out of bounds, stroke and distance, and provisional ball](https://www.randa.org/rog/the-rules-of-golf/rule-18)
- [USGA: Stroke-and-distance relief](https://rules.usga.org/courses/rules-for-teams/lessons/penalty-relief/topic/stroke-and-distance-relief/)
- [USGA: Model Local Rule E-5 alternative for lost/OB](https://www.usga.org/content/usga/home-page/rules-hub/rules-modernization-copy/major-changes/golfs-new-rules-stroke-and-distance.html)
- [PGA of America: golf terminology glossary](https://www.pga.com/story/golf-dictionary-glossary-and-golf-terms%3Fsrsltid%3DAfmBOoqYlZ5oGg5EKJ-gFVpU8UOumCwsq0vxyQcPo90M7NEX0RS5OwYA)
