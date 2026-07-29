# Ideal OverPar course data and creation experience

**Prepared:** 29 July 2026  
**Status:** Researched product specification  
**Related:** [`course-recording-workflows.md`](course-recording-workflows.md), [`community-course-discovery.md`](community-course-discovery.md), and [`overpar-app-build-blueprint.md`](overpar-app-build-blueprint.md)

## 1. Conclusion

Ideal course creation should use progressive enrichment:

### Required to publish a playable community course

- course/facility identity and location;
- layout name when a facility has multiple layouts;
- number of holes;
- par for every hole;
- one tee reference and one green reference for every hole;
- contributor confirmation and duplicate review.

### Strongly recommended scorecard data

- one or more named tee sets;
- tee colour or neutral display label;
- published yardage/metres for every hole and tee set;
- stroke index for every hole;
- official Course Rating and Slope Rating for each applicable tee/rating category;
- photo or source for the scorecard;
- course contact/website.

### Optional map enrichment

- green outline;
- multiple tee-box points;
- fairway centreline/outline;
- bunkers;
- water;
- out-of-bounds;
- dogleg/lay-up targets;
- penalty areas;
- paths and no-play areas;
- temporary/alternate greens and tees.

### Optional community profile data

- access type and booking details;
- facilities and amenities;
- course photos;
- accessibility information;
- operating/seasonal status;
- pace, condition and community reviews.

The interface should ask only for the minimum first, then offer scorecard import and map enrichment as clear follow-up steps. Completeness and verification are visible rather than pretending all community records are equivalent.

## 2. Facility, course and layout hierarchy

Do not model every named search result as one flat “course.”

```text
Facility/club
  -> layout/course
      -> layout revision
          -> holes
              -> tees, green and features
```

Examples:

- one club with a single 18-hole layout;
- one resort with North and South courses;
- a 27-hole facility with three nines combined into several named 18-hole routes;
- an 18-hole facility also offering Front 9 and Back 9 paths;
- a course with temporary winter greens.

Hole19 explicitly distinguishes the overall facility from specific 9/18-hole “paths” and notes that clubs may have multiple layouts and hole combinations. This hierarchy prevents duplicate search results and enables shared nines without copying geometry destructively.

### Ideal identity fields

#### Facility

- official/common name;
- aliases and former names;
- address;
- city/locality;
- region;
- postcode;
- country;
- timezone;
- representative location;
- phone;
- website;
- email optional;
- access type: public, private, resort, municipal, military/other;
- status: open, seasonal, temporarily closed, permanently closed;
- verified owner/manager account where available.

#### Layout

- layout name;
- hole count;
- constituent nines/loops when relevant;
- start hole options;
- routing order;
- active season/status;
- community/verified confidence;
- current revision.

Do not require contact/access information to create basic playable geometry.

## 3. Scorecard data

### Hole fields

- hole number within the selected route;
- stable underlying hole identity where routes share holes;
- par;
- published stroke index;
- optional alternate stroke index for a separately published 9-hole allocation;
- published yardage/metres for each tee set;
- optional hole name;
- notes about alternate green/tee.

Stroke index is not merely “difficulty rank.” USGA guidance defines it as the order in which handicap strokes are received/given, and the club's Handicap Committee determines the final allocation. It is used by Match Play, Stableford and net-double-bogey handling. OverPar should store the published value, not calculate and silently replace it.

### Tee sets

For every tee set:

- user-facing name, such as Black, Championship, Forward or Composite;
- colour as optional display metadata, not identity;
- unit;
- per-hole published length;
- total outward/inward/overall length;
- par where it legitimately differs for the rating/category;
- official Course Rating;
- official Slope Rating;
- rating category/jurisdiction metadata;
- official/unverified source state.

Do not assume tee colour has a universal meaning or that a tee is inherently “men’s” or “women’s.” Model tee geometry separately from one or more official rating records applicable to that tee. Official course/slope values can differ by rated category and must be attached to the correct tee/rating combination.

### Why Course Rating and Slope matter

The World Handicap System calculates Course Handicap using:

```text
Handicap Index × (Slope Rating / 113) + (Course Rating − par)
```

USGA materials state that Course Rating reflects difficulty for a scratch player and Slope Rating represents relative difficulty for non-scratch players. These values belong to a specific set of tees and should be obtained from an official scorecard, national association/federation or verified course source.

Community contributors must not invent a rating or use `113` as an unlabelled fallback. If no official rating exists:

- leave it null;
- mark handicap calculation unavailable/unofficial;
- retain normal gross scoring and GPS use;
- invite verified evidence later.

### Official source evidence

Allow:

- scorecard photo;
- course website URL;
- federation/association source reference;
- course representative verification;
- contributor notes.

18Birdies asks users reporting a course issue to include scorecards, maps, screenshots, tee set, course website and layout-change information. Hole19 notes that mapping depends on national federation information and aerial imagery. This supports an evidence-based submission workflow.

### Scorecard photo/OCR

Ideal flow:

1. contributor photographs or uploads an official scorecard;
2. OCR proposes course name, tee sets, hole pars, stroke indexes, lengths, ratings and slopes;
3. contributor reviews a grid highlighting low-confidence cells;
4. totals and uniqueness constraints are validated;
5. original evidence remains attached privately for moderation according to retention policy;
6. structured values, not the image, drive the app.

OCR is an assistant, never authority. Avoid publishing extracted values without human confirmation.

## 4. Ideal map geometry

### Green

Minimum:

- persistent green-reference point.

Ideal:

- green polygon;
- derived centroid;
- explicit/manual reference if centroid is unsuitable;
- alternate/winter green;
- optional green entrance/front orientation;
- source and confidence.

A polygon allows OverPar to calculate bearing-relative front/centre/back from the golfer's position. A permanent daily flag coordinate should not be assumed; future daily pin reports should expire.

### Tees

Minimum:

- one generic tee reference.

Ideal:

- separate point or small polygon for each physical teeing area;
- mapping from tee set to physical tee area per hole;
- temporary tee support;
- published scorecard length distinct from calculated straight-line GPS distance.

Store both:

- official published length;
- derived map distance.

Do not overwrite one with the other. Official yardage may follow measured playing lines/doglegs and differ from simple tee-to-green geodesic distance.

### Hazards and targets

Useful types:

- bunker;
- water body;
- penalty area;
- out-of-bounds;
- dogleg/turn;
- lay-up target;
- forced carry;
- fairway landing zone;
- trees/blocked line where responsibly mapped;
- no-play/ground-under-repair as temporary data.

Geometry:

- point for a simple target;
- line for boundaries/carries;
- polygon for water, bunker and larger areas.

18Birdies exposes tee boxes, fairways, greens, bunkers, hazards and draggable targets. Golf Pad allows users to submit hazards during a round; the change is immediately personal and becomes shared after review. OverPar should use a similar two-stage pattern for low-risk enrichment:

- contributor sees their draft addition immediately;
- community publication follows automated validation/moderation.

### Routing and shared geometry

Store:

- hole order for each layout;
- links from the end of one hole to the next tee;
- shared underlying hole IDs for combination courses;
- crossover/start options;
- alternate course routes.

Do not duplicate the same physical nine for every 18-hole combination without a shared model. Otherwise corrections diverge.

For the Release 1 repeated-layout case, a course may store nine physical holes once and declare a normal round of one, two or three ordered loops (9, 18 or 27 played holes). Round score/shot positions use the played-hole number while resolving map geometry with `(played_hole - 1) mod 9`. The loop count is route metadata and must not duplicate or renumber the underlying physical-hole geometry. More complex facilities with different constituent nines still require the full shared-route model above.

## 5. Course creation workflow additions

### Step 1 — Identity and location

Required:

- facility/course name;
- layout name if needed;
- hole count;
- country and approximate location.

Recommended:

- address/city/postcode;
- website/contact;
- access/status.

Run duplicate/facility/layout checks before progressing.

### Step 2 — Choose a data source

Offer:

- `Enter scorecard`;
- `Scan scorecard`;
- `Basic setup now`;
- `Copy an existing nine/layout` only through controlled facility composition;
- `Course representative import` later.

### Step 3 — Pars

Required for every hole, as already specified.

### Step 4 — Optional scorecard enrichment

- tee sets;
- per-hole lengths;
- stroke indexes;
- Course Rating/Slope;
- evidence/source.

Allow skip, but show what features remain unavailable:

- official net/handicap calculations;
- tee-specific scorecard;
- correct handicap strokes;
- official yardage comparison.

### Step 5 — Geometry

Satellite or walk mode captures minimum tee/green points.

### Step 6 — Optional map enrichment

After basic geometry:

- add another tee set;
- outline greens;
- add hazards/targets;
- define shared nines/routes;
- attach alternate greens/tees.

### Step 7 — Review and publish

Show:

- identity and possible duplicates;
- hole/par completeness;
- total par;
- tee-set scorecard completeness;
- rating/slope source status;
- map overview;
- geometry and GPS warnings;
- evidence;
- resulting feature availability;
- community versus verified badge.

## 6. Progressive completeness model

Give every course a transparent data-quality profile.

### Playable

- identity;
- holes and pars;
- tee/green references.

Enables:

- discovery;
- basic GPS centre distance;
- gross scoring;
- simple rounds.

### Scorecard complete

- stroke indexes;
- at least one tee set;
- per-hole lengths;
- source/evidence.

Enables:

- full digital scorecard;
- tee selection;
- handicap-stroke allocation where otherwise valid;
- published versus GPS length comparison.

### Handicap ready

- official Course Rating and Slope for relevant tee/rating records;
- verified par/length/rating source;
- jurisdiction/association compatibility.

Enables:

- Course Handicap calculations;
- suitable net formats;
- potential official-score integration only where licensed/authorised.

### Map enriched

- green shapes;
- multiple tee positions;
- key hazards/targets;
- reviewed geometry.

Enables:

- front/centre/back;
- hazard distances;
- auto lie classification;
- course preview and strategy.

### Verified

- course owner, trusted mapper or moderator confirmation;
- recent review date;
- no unresolved material disputes.

The badges are additive. A course can be map-enriched without being handicap-ready.

## 7. Data validation

### Hole and par

- exactly one required par per routed hole;
- configured legitimate range;
- no duplicate hole number in one route;
- total par derived;
- shared physical hole can have route-specific display number.

### Stroke index

- for 18-hole allocation, values normally form a unique set 1–18;
- for a separate 9-hole allocation, values normally form a unique set 1–9;
- flag duplicates/missing values;
- do not auto-generate an “official” allocation;
- preserve source/category where multiple allocations exist.

### Tee scorecard

- one length per routed hole for a complete tee set;
- total equals calculated sum or requires acknowledgement;
- length units stored explicitly and normalised internally;
- Course Rating/Slope attached to correct tee and rating record;
- slope plausibility validation based on official range, without claiming authenticity.

### Geometry

- all points valid WGS84;
- hole features spatially near their course;
- tee/green separation warnings;
- green polygon valid and non-self-intersecting;
- hazards not assigned to an unrelated hole accidentally;
- route ordering plausible but overridable;
- alternate/temporary geometry clearly labelled.

### Sources

- distinguish contributor assertion, scorecard image, course website, federation and verified owner;
- track evidence date;
- allow a source to expire/be superseded;
- do not display unverified values as “official.”

## 8. Maintenance and correction

Course data changes:

- renamed facilities/layouts;
- rerouted holes;
- rebuilt greens;
- new tee boxes;
- new scorecard lengths;
- changed pars/stroke indexes;
- re-rated tees;
- seasonal temporary greens;
- closures.

Ideal maintenance:

- `Suggest update` from course page and active round;
- choose category: identity, scorecard, tees, green, hazard, routing, status or imagery;
- attach screenshot/photo/source;
- hole- and tee-specific correction;
- compare new revision with current;
- review/merge/reject;
- notify contributor;
- retain historical revision.

18Birdies accepts reports from course profile and during a round and asks for hole/tee-specific evidence. Hole19 separates new mapping from updates and uses a mapping team. OverPar's community system should preserve that specificity while making revision status visible.

## 9. Course profile enrichment

Useful but not required for GPS:

- hero and community photos;
- course description;
- public/private/resort/municipal access;
- booking/website/phone;
- price band rather than fragile exact price;
- rental clubs/carts/trolleys;
- driving range;
- putting/chipping practice;
- clubhouse, restaurant, changing rooms;
- buggy/cart availability;
- walking restrictions;
- accessibility notes;
- pace/condition/difficulty reviews;
- community forum/events/leaderboards later;
- home-course membership/favourite.

Separate relatively stable facility facts from time-sensitive community reports.

Avoid allowing unverified users to publish sensitive operational claims immediately. Use moderation or expiry for:

- closures;
- unsafe conditions;
- temporary greens;
- pricing;
- opening times;
- course-condition alerts.

## 10. Daily and temporary course data

Permanent course revision:

- stable tees/greens;
- official scorecard;
- routing;
- long-lived hazards.

Time-bound overlay:

- today's pin;
- temporary tee;
- winter green;
- closed hole;
- ground under repair;
- cart restriction;
- temporary local note.

Each temporary item needs:

- start/end or expiry;
- submitter/source;
- confidence/moderation;
- automatic removal;
- no rewriting of the permanent revision.

This prevents a one-day flag position from polluting the permanent course database.

## 11. Recommended delivery priority

### Creation v1

- facility/layout name;
- location;
- hole count;
- hole pars;
- one tee and green reference per hole;
- search/duplicates;
- revision and moderation.

### Creation v1.5

- automatic sourced tee-to-green terrain sampling during publication;
- animated per-hole elevation-enrichment progress with retry/later fallback;
- scorecard photo;
- manual tee sets and per-hole lengths;
- stroke indexes;
- source/evidence;
- total validation.

### Creation v2

- OCR-assisted scorecard;
- official rating/slope records;
- multiple physical tee points;
- green polygons;
- hazards/targets;
- completeness badges.

### Creation v3

- shared nines/composite layouts;
- verified course-owner workflow;
- temporary overlays;
- federation/licensed imports;
- course profile facilities and community maintenance at scale.

## 12. Schema extensions

```text
facilities
  official_name, aliases
  address, city, region, postcode, country_code, timezone
  location geography(Point, 4326)
  access_type, operational_status
  phone, website, email
  verified_owner_id nullable

course_layouts
  facility_id
  name
  hole_count
  routing_definition/version
  status

physical_holes
  facility_id
  stable_identity

layout_holes
  revision_id
  physical_hole_id
  display_hole_number
  sequence
  par
  stroke_index_18 nullable
  stroke_index_9 nullable

tee_sets
  revision_id
  name
  colour nullable
  unit
  status

tee_set_holes
  tee_set_id
  layout_hole_id
  published_length_m
  physical_tee_geometry_id nullable

tee_ratings
  tee_set_id
  rating_category
  course_rating
  slope_rating
  rating_authority/source
  source_evidence_id
  verified_at nullable

course_evidence
  revision/draft id
  type enum(scorecard_photo, course_website, federation, course_owner, other)
  private_storage_path/url metadata
  submitted_by
  captured/published date
  review status

temporary_course_overlays
  course/layout/hole reference
  type
  geometry/details
  starts_at, expires_at
  source, moderation state
```

The exact schema should avoid duplicating existing blueprint tables, but preserve these relationships.

## 13. Research-backed product rules

- Treat facility and playable layout/path separately.
- Ask for scorecard and map evidence during creation/correction.
- Model tee-specific lengths and ratings.
- Store stroke index because scoring formats and handicap stroke allocation require it.
- Never invent or silently default official Course Rating/Slope.
- Allow hazards and map changes to be useful privately before community approval.
- Support course preview using the same mapped green/hazard data.
- Preserve corrections as revisions and attach them to a hole/tee/category.
- Make data completeness visible.
- Keep initial publishing achievable without every enrichment field.

## 14. Primary sources

- [USGA: Course Rating and Slope Rating](https://www.usga.org/content/usga/home-page/handicapping/world-handicap-system/topics/course-rating-and-slope-rating.html)
- [USGA: Course Handicap and Playing Handicap](https://www.usga.org/content/usga/home-page/handicapping/world-handicap-system/topics/course-handicap-and-playing-handicap.html)
- [USGA: Stroke Index Allocation](https://www.usga.org/content/usga/home-page/handicapping/world-handicap-system/topics/stroke-index-allocation.html)
- [USGA: Appendix E — Stroke Index Allocation](https://www.usga.org/content/usga/home-page/handicapping/roh/Content/rules/Appendix%20E%20Stroke%20Index%20Allocation.htm)
- [Hole19: Request a new course/path or update](https://help.hole19golf.com/hc/en-us/articles/16515391224348-Request-a-New-Course-or-a-Course-Update)
- [18Birdies: Missing or incorrect course evidence](https://help.18birdies.com/article/241-i-cant-find-my-course)
- [18Birdies: Course GPS data and corrections](https://help.18birdies.com/article/37-using-gps-on-the-golf-course)
- [18Birdies: Mapping tees and greens from satellite imagery](https://help.18birdies.com/article/678-how-can-i-show-18birdies-the-map-of-my-home-course)
- [18Birdies: Course profile scorecard, facilities and community data](https://help.18birdies.com/article/199-course-profile)
- [Golf Pad: Community hazard submission and review](https://support.golfpadgps.com/support/solutions/articles/6000262837-how-to-add-new-hazards-)
