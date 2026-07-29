# OverPar community course discovery and creation

**Prepared:** 29 July 2026  
**Status:** Implementation specification  
**Related:** [`course-recording-workflows.md`](course-recording-workflows.md), [`ideal-course-data-and-creation.md`](ideal-course-data-and-creation.md), and [`overpar-app-build-blueprint.md`](overpar-app-build-blueprint.md)

## 1. Community objective

The OverPar home screen should make the shared course database immediately useful:

- with foreground location permission, automatically show the nearest published course;
- allow the user to start a round or open that course quickly;
- let anyone search published courses by course name, club name, city, postcode or current GPS position;
- make it obvious when a course is missing and start the community creation flow;
- require a course name, hole count and par for every hole before submission.

Course discovery and course creation use the same permanent, versioned community database.

The ideal optional enrichment fields and completeness levels are defined in [`ideal-course-data-and-creation.md`](ideal-course-data-and-creation.md). Search cards must omit unavailable fields rather than fabricate them, and may display transparent `Playable`, `Scorecard complete`, `Handicap ready`, `Map enriched` and `Verified` states as those levels are implemented.

## 2. Location permission during setup

### Permission level

Request **When in Use / foreground location**, not background/always access.

- Approximate/coarse location is adequate for recommending nearby courses and city-level search.
- Precise location is preferred for accurate nearest-course ordering.
- Precise location is required later for walk-mode tee/flag recording, with a separate in-context explanation if the user originally granted approximate access.
- The rest of the app must remain usable after denial.

### Setup sequence

During onboarding, show a dedicated explanation screen:

> Find your nearest course  
> Allow location while using OverPar to see nearby courses, measure on-course distances and record course points. We do not publish your live location.

Actions:

- `Enable nearby courses`;
- `Not now`.

`Enable nearby courses` triggers the operating-system foreground location prompt. This satisfies setup-time prompting while keeping the permission request tied to a visible feature. Apple and Android both recommend requesting sensitive permissions in context rather than showing an unexplained system prompt at application launch.

Do not use manipulative copy or disable account completion after denial.

### Permission outcomes

| Outcome | Home behaviour |
|---|---|
| Precise foreground granted | fetch fresh location and show nearest course with distance |
| Approximate foreground granted | show nearby result labelled approximately; request precise only when a precision-dependent feature begins |
| Denied/not now | show location/postcode search and `Enable location` call to action |
| Restricted/unavailable | explain limitation and retain manual search |
| Location service off | show settings guidance and manual search |

If the user later taps `Use my location`, request permission if the status is undetermined or show concise settings guidance if the OS will not prompt again.

### Privacy

- Do not publish or expose the user's live location.
- Do not store a continuous home-location history.
- Prefer sending a transient coordinate to a nearby-course RPC and returning course results.
- If analytics records the feature, log permission/result categories, not exact coordinates.
- Cache the selected course/result locally but not an unnecessary raw coordinate.

## 3. Home-page nearest course section

### Placement

The signed-in home screen contains a prominent section:

```text
Nearest course

[course image/map thumbnail]
Royal Example Golf Club
0.8 mi away · 18 holes · Par 72
[View course] [Start round]

Other nearby courses >
```

If course par is incomplete/unverified, omit total par rather than displaying a fabricated value.

### Loading behaviour

1. Render the rest of the home screen immediately.
2. Inspect foreground location permission.
3. If allowed, request one fresh-enough location.
4. Query the nearest published, playable course revision.
5. Render the result and distance.
6. Cache the result for a short period for fast subsequent home loads.
7. Refresh when:
   - the cache expires;
   - the user pulls to refresh;
   - the user has moved materially;
   - a course is newly created/published;
   - location permission changes.

Do not leave high-accuracy GPS running while the user remains on the home screen.

### Search radius and empty results

Use expanding server-side radii rather than loading all courses:

1. nearest within 25 km;
2. if none, nearest within 100 km;
3. if none, return no nearby result.

Exact radii should be remotely configurable based on market density.

Empty state:

> No community course found nearby  
> Search another location or add the course for everyone.

Actions:

- `Search courses`;
- `Add a course`.

### Nearest does not always mean best match

The default card is geographic nearest. The `Other nearby courses` list can rank using:

- distance;
- published/verified status;
- course completeness;
- community reports;
- whether it is currently playable;
- recent user selection.

Never silently substitute a farther sponsored result as “nearest.”

## 4. Course search

### User interface

One search field:

> Search course, city or postcode

Supporting controls:

- `Use my location`;
- recent searches;
- nearby suggestions;
- filters such as 9/18 holes and verified/community;
- map/list toggle later.

Examples:

- `St Andrews Links`;
- `Manchester`;
- `SW19 5AE`;
- `90210`;
- `Use my location`.

### Search types

#### Course/name search

Search:

- course name;
- club/facility name;
- known aliases;
- city/locality;
- region;
- postcode;
- country.

Use normalised and accent-insensitive text. Rank:

1. exact course-name match;
2. prefix course-name match;
3. club/alias match;
4. fuzzy name match;
5. address/locality match;
6. distance from optional user/search location;
7. verification/completeness quality.

PostgreSQL full-text search supports indexed token search and ranking. `pg_trgm` can add typo-tolerant similarity for short names/postcodes. Do not expose unrestricted database queries directly; use a stable search RPC/API.

#### City/postcode search

Search local structured course address fields first. If no adequate direct match—or the query is clearly a place/postcode—resolve it through the chosen map provider's geocoding service:

1. send the query to a server/Edge Function;
2. apply country/market bias where appropriate;
3. receive candidate place coordinates and formatted labels;
4. let the user choose if ambiguous;
5. run a PostGIS nearby-course query around the chosen location;
6. return courses ordered by distance/quality.

Google's current Geocoding API, for example, supports unstructured addresses and structured postal-code/locality components and returns latitude/longitude. Final implementation must use the geocoding product compatible with the selected map provider and its storage/licensing rules.

Do not treat arbitrary course-name text as an address without trying the internal course search first.

#### GPS search

`Use my location`:

1. checks/requests foreground permission;
2. requests a fresh current location;
3. calls the nearby-course RPC;
4. shows results ordered by distance;
5. stops active location work.

### Search request behaviour

- debounce typed queries;
- cancel stale in-flight requests;
- require a small minimum length except for structured postcodes;
- paginate;
- show why each result matched, such as `Course name` or `Near Manchester`;
- show distance only when a reference coordinate exists;
- keep name results useful without location permission;
- rate-limit server geocoding and cache allowed place resolutions under provider terms;
- never expose provider API secrets in the client.

### No-result path

When there is no matching course:

> Can't find it?

- `Search another location`;
- `Add a new community course`.

Pass the current query/place into course creation to prefill the course name or location, but require confirmation.

## 5. Course creation form

Course creation begins before satellite/walk recording and must include the requested structured fields.

### Required course fields

- **Course name**
  - user-editable;
  - trimmed;
  - sensible length limit;
  - case-insensitive duplicate checks;
  - not globally unique by itself.
- **Number of holes**
  - presets: 9 and 18;
  - `Custom` for legitimate alternatives;
  - initial configurable range, for example 1–36;
  - changing the count updates the par-entry list safely.
- **Par for every hole**
  - required before course submission;
  - stored as an integer for each hole;
  - quick options `3`, `4`, `5`;
  - `Other` permits legitimate unusual values under a configured range;
  - warn rather than automatically reject plausible unusual pars.

Recommended optional fields:

- club/facility name;
- layout name;
- city;
- postcode;
- country;
- course description;
- default tee name.

### Screen structure

#### Step 1 — Course details

```text
Create a course

Course name            [________________]
Club/facility          [________________] optional
Holes                   [9] [18] [Custom]
City                    [________________] optional
Postcode                [________________] optional

[Continue to pars]
```

Run a duplicate search after course name and approximate location are known. If likely matches exist, show `Use existing` or `Suggest correction` before continuing.

#### Step 2 — Hole pars

Efficient grid/list:

```text
Set par for each hole

Hole 1       [3] [4] [5] [Other]
Hole 2       [3] [4] [5] [Other]
...

Front 9 par: 36
Back 9 par: 36
Total par: 72

[Save & choose recording method]
```

Usability:

- allow `Set all to 4`, followed by individual changes;
- preserve entered pars when switching 18 to 9 by keeping removed values in local undo state;
- when increasing hole count, create blank pars that must be completed;
- show missing pars clearly;
- calculate total par live;
- support yards/metres independently—par is unitless;
- large controls for mobile use.

### Validation

Before choosing satellite/walk mode:

- name is present;
- hole count is supported;
- exactly one par exists for every expected hole;
- par values are within configured constraints;
- total par is derived, never manually entered as authority;
- possible duplicates have been acknowledged.

The contributor may save a private incomplete draft at any time. Publication requires all mandatory fields and geometry.

### Recording integration

Once details and pars are complete, show:

- `Use satellite map`;
- `Walk the course with GPS`.

Every recording screen displays:

- course name;
- `Hole N of M`;
- `Par X`;
- current tee/flag step.

The final overview lists:

- hole number;
- par;
- tee-to-green reference distance;
- capture method/quality;
- missing or warned information;
- total course par.

## 6. Data-model additions

```text
clubs
  city text nullable
  postcode text nullable
  country_code text
  search_document tsvector/generated

courses
  name text
  normalized_name text
  hole_count integer
  total_par integer derived/cached
  discovery_location geography(Point, 4326)
  current_revision_id uuid
  status

course_aliases
  id uuid
  course_id uuid
  alias text
  normalized_alias text

course_revisions
  expected_hole_count integer

holes
  hole_number integer
  par integer not null for publishable revision

course_search_places (optional provider-compliant cache)
  normalized_query
  provider
  provider_place_id
  label
  location geography(Point, 4326)
  expires_at/provider metadata
```

### Discovery location

Each published course needs one representative `discovery_location` for nearby queries. Derive it from:

1. verified clubhouse/course coordinate when available;
2. centroid/medoid of published tee and green points;
3. first tee as an early fallback.

Store how it was derived. Recalculate when a new course revision materially changes geometry.

### Search indexes

- GiST index on `courses.discovery_location`;
- GIN index on weighted text search document;
- trigram indexes on normalised course/club names where beneficial;
- normal B-tree index on normalised postcode/country;
- partial indexes limited to published/searchable courses.

### Nearby RPC shape

```text
nearby_courses(
  latitude,
  longitude,
  radius_m,
  limit,
  cursor?
) -> course summary + distance_m
```

Server requirements:

- validate coordinate ranges;
- query only published/searchable course revisions;
- use PostGIS indexed `ST_DWithin`;
- order by geographic distance, then stable tie-breaker;
- cap radius and result count;
- avoid retaining the query coordinate unnecessarily.

### Unified search API

```text
search_courses(
  query text nullable,
  latitude numeric nullable,
  longitude numeric nullable,
  hole_count integer nullable,
  cursor text nullable
) -> ranked course summaries
```

Geocoding should sit behind a separate server orchestration layer because it invokes an external provider and may have different caching/licensing rules.

## 7. Community trust and updates

- Newly submitted courses enter the existing draft/review/revision system.
- Course name, hole count and hole pars are versioned along with geometry.
- Changing hole count on a published course is a major revision and may represent a different layout; require deliberate review.
- Changing par creates a new revision and does not rewrite historic round calculations.
- Search should show current published data.
- Old rounds retain the course revision and pars used at play time.
- Contributors can suggest name/address/par corrections.
- Verified course representatives can propose authoritative updates, still through revision history.

## 8. Home and search states to design

- permission not determined;
- permission explanation;
- precise granted;
- approximate granted;
- denied;
- restricted/services disabled;
- acquiring location;
- nearby result;
- multiple nearby results;
- no nearby course;
- offline with cached nearest course;
- internal name search results;
- ambiguous city/postcode;
- geocoding error/rate limit;
- no search results;
- newly created course pending publication.

## 9. Offline behaviour

- Display the last cached nearest/recent course with `Last updated` while offline.
- Name search may use a small local recent/downloaded-course index.
- City/postcode geocoding requires connectivity unless a local provider feature exists.
- Course creation details and pars save locally.
- A contributor can begin/continue a draft offline if the required satellite tiles are already legally cached; otherwise walk mode remains available.
- Submission waits in the sync queue.

## 10. Acceptance criteria

### Location and home

- Setup clearly offers foreground location access.
- Denial does not block signup or manual search.
- Granted users see a nearest-course card without manually searching.
- Home does not leave continuous GPS running.
- Nearest distance comes from an indexed geospatial query.
- Approximate permission is handled honestly.

### Search

- Users can find courses by exact and partial course name.
- Users can search by city.
- Users can search by postcode.
- Users can request results around current GPS position.
- Results are ranked predictably and show distance when available.
- No-result state leads directly to community course creation.

### Course creation

- Contributor names the course.
- Contributor selects 9, 18 or a supported custom hole count.
- Contributor enters par for every hole.
- Total par is derived and shown.
- Every recording step shows current hole and par.
- Submission cannot publish with missing pars or missing required tee/flag geometry.
- Published course becomes searchable and eligible for nearest-course results.
- Subsequent changes create new revisions without changing historical rounds.

## 11. Primary sources

- [Apple: requesting location authorisation](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services)
- [Android: foreground, precise and approximate location permissions](https://developer.android.com/develop/sensors-and-location/location/permissions)
- [Android: runtime location permission guidance](https://developer.android.com/develop/sensors-and-location/location/permissions/runtime)
- [Supabase/Postgres full-text search](https://supabase.com/docs/guides/database/full-text-search)
- [Supabase PostGIS geo queries](https://supabase.com/docs/guides/database/extensions/postgis)
- [PostGIS `ST_DWithin`](https://www.postgis.net/docs/manual-3.5/ST_DWithin.html)
- [Google Geocoding API address and postcode inputs](https://developers.google.com/maps/documentation/geocoding/geocoding)
