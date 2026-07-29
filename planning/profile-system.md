# OverPar profile system

**Prepared:** 29 July 2026  
**Status:** Researched pre-development specification  
**Scope:** Identity, personal presentation, course-community identity and account controls. Personal club-distance summaries are now authorised by the separate Driving Range specification; other performance statistics remain excluded.

## 1. Product objective

An OverPar profile should answer:

- who is this golfer/contributor?
- how should the app address them?
- which course communities do they identify with?
- which course records have they created or helped improve?
- is this account a trusted contributor, moderator or verified course representative?
- what has the user chosen to make visible?

It should not yet display:

- scoring averages;
- handicap or handicap trends;
- round counts;
- fairways, greens, putts or strokes gained;
- leaderboards or performance comparisons;
- activity feeds built from rounds.

It may display the private-by-default **Club distances** card defined in [`driving-range-and-club-recommendations.md`](driving-range-and-club-recommendations.md). The profile owns presentation/privacy; Driving Range owns observations, calculations and recommendation semantics.

## 2. Research conclusions

Current golf and activity communities tend to combine:

- display name and avatar;
- username/search identity;
- short biography;
- broad location;
- home course or club memberships;
- friends/following;
- activity and statistics;
- privacy controls.

For OverPar now, identity, home courses, contribution trust and the specified club-distance summary are useful; all other activity statistics are out of scope.

18Birdies allows up to five home courses, pins one on the profile, and adds home-course users to the course's public member list. This is useful for a course-centred community, but membership visibility must be explicit. Strava demonstrates that profile visibility and activity visibility should be separate controls and that non-approved viewers can receive a limited profile. OverPar should adopt that separation before round/activity sharing exists.

Supabase recommends a public-schema profile table linked to `auth.users`, protected by Row Level Security. User-editable authentication metadata must not be used for authorization decisions. Avatars belong in Storage with explicit access policies. Supabase can link OAuth and email identities, while the stable user UUID remains the profile identity.

## 3. Profile types

### Own profile

Shows:

- profile header;
- edit profile;
- private account/settings entry;
- home and favourite courses;
- created/suggested course records;
- draft course work;
- trust/verification status;
- privacy preview;
- club-distance summary when the owner has Driving Range data;

### Another user's profile

Shows only fields permitted by profile visibility and blocks:

- display name;
- username;
- avatar;
- biography;
- broad location if shared;
- pinned home course if shared;
- visible home courses;
- contribution role/badges;
- published community course contributions;
- report/block actions.

Never show:

- email;
- authentication providers;
- precise/current location;
- private favourite courses;
- course drafts;
- account/security settings;
- moderation notes;
- device or sign-in information.

### Limited/private profile

For viewers without access:

- avatar or initials;
- display name;
- username;
- privacy indication;
- block state;
- no home course, bio, location or contributions unless explicitly public.

## 4. Profile fields

### Required

#### Display name

- the name shown prominently;
- may contain spaces;
- not unique;
- user confirms it during onboarding;
- sensible length and character controls;
- can initially be proposed from Apple/Google identity data;
- editable.

Sign in with Apple may provide the person's name only on the first authorization. Persist a confirmed profile name in OverPar rather than expecting the provider to return it later.

#### Username

- unique, case-insensitive handle;
- shown as `@username`;
- used for search, mentions and stable human recognition;
- separate from immutable UUID;
- normalized for uniqueness;
- restricted/reserved words and profanity checks;
- change cooldown;
- history/redirect record to reduce impersonation and broken links;
- not used as a foreign key.

Suggested rules:

- 3–24 characters;
- letters, digits, underscore and full stop;
- starts/ends with a letter or digit;
- no consecutive separators;
- case stored for display but compared case-insensitively.

Final internationalisation policy should be decided deliberately. If usernames begin ASCII-only, display names still support normal Unicode names.

### Optional personal presentation

#### Avatar

- upload/take photo;
- crop to square;
- generate multiple sizes;
- default initials/brand placeholder;
- replace/remove;
- file type/size validation;
- image re-encoding to remove hidden metadata;
- moderation/reporting;
- owner-scoped upload path.

#### Biography

- short plain text, approximately 160 characters initially;
- line breaks limited;
- links either disallowed initially or safely linkified;
- abuse/profanity reporting;
- no rich HTML.

Prompt:

> Tell the golf community a little about yourself.

#### Broad location

- optional city/region/country label;
- never exact GPS coordinates on the public profile;
- manually chosen or suggested via geocoding;
- independently hideable;
- not automatically populated from live location without confirmation.

Example: `Leeds, United Kingdom`, not a postcode, street, home course proximity or current position.

#### Preferred units

- yards or metres;
- useful account preference;
- visible only to the owner;
- affects maps, course creation and round UI;
- stored internally separately from course source units.

#### Timezone and locale

- system-derived defaults;
- private;
- used for dates/notifications;
- editable if needed.

### Golf-community identity

#### Home courses

- up to five initially;
- one can be pinned;
- each references a published course/layout;
- user explicitly chooses whether each membership is visible;
- visible membership may add the person to a course-member list later;
- removing a home course removes that public membership;
- home course is not inferred from live location or play history.

#### Favourite/saved courses

- private by default;
- unlimited or a reasonable product limit;
- used for quick course access;
- distinct from public home-course identity;
- no automatic public membership.

This distinction is important: a user may save a holiday course without claiming it as home.

#### Contributor identity

Profile may display non-performance roles:

- `Course contributor`;
- `Trusted mapper`;
- `Verified course representative`;
- `Moderator`;
- `OverPar team`.

Authorization roles must come from trusted server-managed data/app metadata, never user-editable profile fields.

#### Course contributions

Own profile:

- private drafts;
- submissions needing changes;
- published courses/layouts;
- accepted corrections;
- moderation status.

Public profile, if enabled:

- published courses created;
- published revisions/corrections with attribution;
- no rejected submissions, internal trust score or moderation details.

Contribution history is useful community provenance, not player-performance statistics.

## 5. Profile screen design

### Header

```text
[avatar]
Display Name
@username
[Trusted mapper badge]

Leeds, United Kingdom
Short biography text…

Home course: Royal Example Golf Club

[Edit profile] [Settings]
```

Another user's actions may later include connect/follow/message, but do not add non-functional controls before the social relationship model is specified.

### Sections for v1

1. **Home courses**
   - pinned course first;
   - visible course cards;
   - add/manage on own profile.
2. **Community contributions**
   - published course/layout cards;
   - accepted public corrections;
   - draft/manage entry only for owner.
3. **About**
   - bio and broad location;
   - joined month/year optional;
   - verification explanation.
4. **Club distances**
   - private by default and independently shareable;
   - longest-to-shortest list/gapping chart;
   - clearly labelled carry or total values;
   - playing distance, typical range, sample count and confidence;
   - owner entry point to **Driving Range**;
   - no raw hits, session times or precise range locations publicly.

Omit Club distances for viewers when empty. The owner may see `Record club distances`. Do not render a generic “Stats coming soon” panel.

### Empty states

No avatar:

- initials fallback.

No bio:

- owner: `Add a short bio`;
- viewer: omit the row.

No home course:

- owner: `Choose a home course`;
- viewer: omit the section.

No contributions:

- owner: `Add a missing course`;
- viewer: omit the section.

Private profile:

- concise privacy message without revealing hidden field existence.

## 6. Edit-profile experience

### Editable profile form

- avatar;
- display name;
- username;
- bio;
- broad location;
- pinned home course;
- home-course visibility;
- profile visibility.

Save behaviour:

- local validation;
- server uniqueness/normalisation check for username;
- optimistic UI only for safe fields;
- transactional username change/history update;
- clear field errors;
- no silent overwriting from OAuth on later sign-ins.

### Separate settings

Do not mix public profile with account/security settings.

Account settings:

- email;
- linked Apple/Google/password identities;
- password change/reset;
- session/device management later;
- data export;
- account deletion.

App preferences:

- yards/metres;
- locale/timezone;
- notifications;
- location permissions guidance;
- camera/media preferences later.

Privacy and safety:

- profile visibility;
- location visibility;
- home-course visibility;
- contribution attribution visibility where legally/product-wise permitted;
- blocked users;
- future round/activity visibility separately.

## 7. Privacy model

### Recommended v1 visibility

Profile visibility:

- `OverPar community` — signed-in users can see allowed public-profile fields;
- `Private` — other users see only limited identity.

Future-compatible enum:

```text
community
connections
private
```

Do not expose full user profiles to logged-out web visitors by default.

### Independent field controls

At minimum:

- broad location visible/hidden;
- home-course membership visible/hidden;
- published contribution attribution visible/anonymous where policy permits.

Future round/activity privacy must be independent of profile privacy. A community-visible identity must not automatically make rounds, GPS locations or tracer media public.

### Searchability

- community profiles searchable by display name/username;
- private profiles may remain searchable by limited identity to support invites, unless the user disables discoverability;
- blocked users cannot search/view/interact;
- email/phone never searchable;
- rate-limit enumeration.

### Blocking and reporting

Block:

- hides profiles/content in both directions where practical;
- prevents future direct interaction;
- does not erase necessary course revision attribution from audit/moderation records;
- may show public course edits as an anonymized contribution to the blocked viewer.

Report:

- impersonation;
- abusive name/bio/avatar;
- spam;
- inappropriate image;
- privacy issue;
- other.

Moderation actions are audited and never stored in user-editable profile metadata.

## 8. Username and identity lifecycle

### Creation

1. Supabase creates/authenticates the stable user UUID.
2. OverPar creates a profile row.
3. Provider display name/avatar may be proposed.
4. User confirms display name.
5. User selects an available username.
6. Profile privacy defaults are explained.
7. User may skip optional avatar, bio, location and home course.

### Username changes

- server-side RPC/transaction;
- normalize and reserve atomically;
- enforce cooldown;
- store previous username and release/redirect policy;
- update search index;
- audit change;
- never change user UUID or contribution ownership.

### Linked identities

Apple, Google and email/password identities may belong to one Supabase user. The profile is keyed to that user, not an individual login provider. Linking/unlinking must preserve at least one viable sign-in method and use reauthentication for sensitive changes.

### Account deletion

- remove/anonymize personal profile according to policy;
- delete avatars;
- remove home/favourite memberships;
- preserve shared course revisions under anonymous attribution where permitted;
- preserve internal audit/security data only for the documented retention period;
- queue all deletion work and expose status/retry;
- prevent a half-deleted publicly searchable profile.

## 9. Proposed data model

```text
profiles
  id uuid PK -> auth.users.id
  username citext UNIQUE NOT NULL
  username_normalized text UNIQUE NOT NULL
  display_name text NOT NULL
  bio text nullable
  avatar_object_path text nullable
  location_label text nullable
  location_city text nullable
  location_region text nullable
  location_country_code text nullable
  show_location boolean default false
  visibility enum(community, connections, private)
  discoverable boolean default true
  preferred_unit enum(yards, metres)
  locale text nullable
  timezone text nullable
  created_at, updated_at

username_history
  id uuid PK
  user_id uuid FK
  normalized_username text
  display_username text
  started_at, ended_at
  redirect_until nullable

profile_home_courses
  user_id uuid FK
  course_id uuid FK
  sort_order integer
  is_pinned boolean
  is_visible boolean
  created_at
  UNIQUE(user_id, course_id)

favorite_courses
  user_id uuid FK
  course_id uuid FK
  created_at
  UNIQUE(user_id, course_id)

profile_roles
  user_id uuid FK
  role enum(course_contributor, trusted_mapper, verified_course_rep, moderator, team)
  scope_type/scope_id nullable
  granted_by uuid
  granted_at, revoked_at nullable

profile_blocks
  blocker_id uuid FK
  blocked_id uuid FK
  created_at
  UNIQUE(blocker_id, blocked_id)

profile_reports
  id uuid PK
  reporter_id uuid FK
  reported_user_id uuid FK
  category, details
  status
  created_at

profile_visibility_overrides (only if field controls outgrow profile columns)
  user_id, field, audience
```

Course contribution ownership already belongs in course draft/revision tables. Query it for profile displays instead of duplicating authority in a profile counter.

## 10. Storage design for avatars

Recommended private or controlled bucket:

```text
avatars/{user_uuid}/{version_uuid}.jpg
```

Rules:

- authenticated user uploads only under their UUID;
- validated image MIME and size;
- server/native image pipeline re-encodes;
- current object path stored in profile;
- old versions deleted asynchronously after safe replacement;
- read access follows profile visibility, either through controlled object policy or transformed/signed delivery;
- bucket listing is not public;
- service credentials never shipped.

If avatars are made publicly cacheable, accept that object URLs may remain accessible outside profile RLS. Use non-guessable versioned paths and moderation/removal tooling.

## 11. RLS and API boundaries

### Profiles

- owner can read/update their full profile;
- other authenticated users receive a safe public projection filtered by visibility/blocking;
- no client can edit roles or trust fields;
- username change goes through an RPC, not arbitrary profile update;
- email never copied into public profile.

Prefer a security-invoker view or server RPC that returns explicit public columns rather than granting broad access to a row containing private settings.

### Home/favourite courses

- owner manages both;
- visible home-course memberships readable subject to profile/course visibility;
- favourites owner-only;
- pinned constraint: at most one per user;
- maximum home-course count enforced server-side.

### Roles

- normal users may read safe display badges;
- only privileged audited server actions grant/revoke;
- authorization checks use trusted role tables/app metadata;
- do not use `raw_user_meta_data` or display badges for authorization.

### Reports/blocks

- reporter/blocker inserts their own rows;
- reports never public;
- users cannot read reports made about them;
- moderation access server-scoped and audited.

## 12. Profile search

Search:

- exact username;
- username prefix;
- display-name token/prefix;
- optional home-course filter later.

Ranking:

1. exact username;
2. username prefix;
3. exact display name;
4. display-name text match;
5. trusted/verified account only as a tie-breaker, not paid priority.

Return:

- safe limited profile summary;
- avatar;
- display name;
- username;
- one contextual badge/pinned home course if visible.

Protect against:

- email enumeration;
- unbounded pagination;
- scraping;
- blocked-user leakage;
- private-location exposure.

## 13. Validation and moderation

### Display name/username

- trim and Unicode-normalize;
- length limits;
- reserved names;
- impersonation/brand review;
- profanity/abuse filtering with appeal;
- reject invisible/control characters;
- handle confusable names carefully.

### Bio

- plain text;
- length limit;
- strip unsafe markup;
- safe link policy;
- report flow.

### Avatar

- image signature validation;
- dimension and decompression limits;
- re-encoding;
- metadata removal;
- moderation;
- default fallback after removal.

### Badges

- explanatory tap target;
- distinguish identity verification from course-data quality;
- never sell a badge that looks like moderator/course-owner verification.

## 14. Accessibility

- profile works without avatar;
- avatar has meaningful or decorative accessibility treatment;
- badge meaning not colour-only;
- large edit/menu targets;
- screen-reader order follows display name, username, badges, bio, courses;
- respect dynamic text;
- location/home course rows have clear visibility labels;
- username availability errors announced;
- cropper supports keyboard/assistive controls on web.

## 15. Analytics without profile statistics

Permitted product events:

- profile onboarding completed/skipped;
- avatar/bio/home-course added;
- visibility changed;
- username change success/failure category;
- profile search result opened;
- block/report submitted.

Do not build or display golfer-performance aggregates. Avoid logging profile text, exact location or private course selections.

## 16. Testing

### Identity

- Apple first sign-in versus repeat sign-in with missing name;
- Google and email creation;
- provider identity linking;
- duplicate username race;
- case-insensitive username;
- username change redirect/cooldown;
- account deletion.

### Privacy/RLS

- owner/community/private viewer matrices;
- hidden location and home course;
- block in both directions;
- private drafts never exposed;
- roles cannot be self-assigned;
- reports inaccessible to reported user;
- public projection contains no email/auth metadata.

### Media

- supported/unsupported file;
- oversized/decompression-bomb protection;
- interrupted upload;
- replace/remove;
- metadata stripped;
- blocked/private avatar access policy.

### UX

- all optional fields empty;
- long display names;
- no home course;
- five home courses and pinned switching;
- deleted/archived home course;
- contribution with anonymized attribution;
- offline own-profile cache.

## 17. Delivery plan

### Profile v1

- Supabase-linked profile row;
- confirmed display name;
- unique username;
- avatar;
- bio;
- broad optional location;
- yards/metres preference;
- community/private visibility;
- own versus public profile;
- up to five home courses with one pinned;
- private favourites;
- published course contributions;
- edit/settings separation;
- block/report foundations;
- RLS tests.

### Later social extension

- connections/follows;
- invites;
- course member directory;
- messaging only after safety design;
- round/activity privacy;
- notifications.

### Authorised club-distance extension

- club inventory and Driving Range input;
- average and robust distance summaries;
- profile gapping chart;
- independent statistics visibility.

These behaviours are authoritative in [`driving-range-and-club-recommendations.md`](driving-range-and-club-recommendations.md).

### Later statistics extension

Still reserved for a separate user specification:

- performance summary;
- rounds and score history;
- handicap;
- trends;
- achievements.

Do not implement this extension from the current document.

## 18. Acceptance criteria

- Every account has a stable UUID-backed profile.
- User confirms a display name and unique username.
- Repeat Apple sign-in does not erase the saved name.
- User can add, replace and remove an avatar.
- User can add a short bio and optional broad location.
- Exact/current location is never displayed.
- User can choose up to five home courses and pin one.
- Home-course public membership is explicit.
- Favourite courses remain private.
- Public contribution attribution links to a safe profile.
- Private drafts never appear to other users.
- Profile visibility and future activity visibility are separate concepts.
- Email and auth provider details never appear publicly.
- Trust roles cannot be self-assigned.
- Block/report and account deletion have real backend behaviour.
- No golfer performance statistics other than the separately specified club-distance summary are displayed in this version.

## 19. Primary sources

- [18Birdies: Home Courses and profile pinning](https://help.18birdies.com/article/779-home-courses)
- [18Birdies: profile activity privacy](https://help.18birdies.com/article/620-activity-sharing)
- [Strava: profile-page privacy controls](https://support.strava.com/en-us/articles/15401967-profile-page-privacy-controls)
- [Strava: privacy controls overview](https://support.strava.com/en-us/articles/15401951-privacy-controls)
- [Supabase: user/profile data management](https://supabase.com/docs/guides/auth/managing-user-data)
- [Supabase: identity linking](https://supabase.com/docs/guides/auth/auth-identity-linking)
- [Supabase: Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Supabase: Storage access control](https://supabase.com/docs/guides/storage/security/access-control)
- [Apple: Sign in with Apple authentication behaviour](https://developer.apple.com/documentation/signinwithapple/authenticating-users-with-sign-in-with-apple)
