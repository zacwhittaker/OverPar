# OverPar Driving Range and club recommendations

**Prepared:** 29 July 2026  
**Status:** Researched pre-development specification  
**Scope:** Personal clubs, range-shot capture, profile club-distance summaries and attack-first on-course recommendations.

## 1. Product decision

The statistics area for this feature is named **Driving Range**. It lets a golfer build a club inventory, record repeated range shots, see an updating average and turn those observations into on-course advice.

The clean profile presentation is a summary; Driving Range is where data is entered and managed. Score, handicap, strokes-gained and other round-performance statistics remain outside this feature.

## 2. Research conclusions

- Equipment rules broadly describe woods, irons and putters. Practical product categories are driver, fairway wood, hybrid/rescue, utility/driving iron, iron, wedge, putter and specialty clubs.
- A player may carry at most 14 conforming clubs in a round, with no required mixture. Duplicate types are allowed. OverPar must model individual physical clubs.
- An inventory may exceed 14; only the active on-course bag is capped.
- Golf Pad accepts entered typical distances immediately, then learns from tracked shots and weights recent data. It also supports duplicate club types.
- Shot Scope's Performance Average and Arccos's Smart Distance filter abnormal results. Arccos additionally exposes a typical range and data confidence.
- OverPar should display the requested arithmetic average, but recommendations should use a robust playing distance, distance range, sample count and confidence.
- Carry and total distance answer different questions and must never be mixed.
- GPS distance alone cannot determine that a lay-up is smart. That requires mapped hazards/landing zones, a reliable target and personal distance/dispersion evidence.
- Strategy can be framed as a stochastic shortest-path problem: compare expected next states and penalty risk. The first version can use an explainable approximation and later graduate to a validated model.
- More distance is normally useful. A lay-up is not automatically safer and should not blindly target a fashionable “favourite wedge yardage.”
- Club recommendations and plays-like adjustments may be restricted in competition. A rules-compliant mode must hide them while retaining permitted raw distances.

## 3. Complete practical club catalogue

No permanently closed list can literally contain every club: manufacturers invent labels, lofts overlap and specialty/historical clubs exist. Use this comprehensive modern catalogue plus `Custom`.

| Category | Options |
|---|---|
| Driver | Driver / 1 Wood |
| Mini driver | Mini Driver / 2 Wood |
| Fairway wood | 3W, 4W, 5W, 7W, 9W, 11W, 13W, custom number/loft |
| Hybrid/rescue | 1H–9H, custom number/loft |
| Utility/driving iron | 1U–6U, custom number/loft |
| Iron | 1I–9I |
| Pitching wedge | PW |
| Approach/gap wedge | AW, GW, UW |
| Sand wedge | SW |
| Lob wedge | LW |
| Loft-labelled wedge | Any explicit loft, commonly 46°–72° |
| Chipper | Chipper |
| Putter | Blade, mid-mallet, mallet, arm-lock, long/broomstick, custom |
| Custom/specialty | Free label and optional legacy alias, such as mashie/niblick |

Wedge role and loft are separate. “Rescue” is an alias for hybrid, not a separate statistical category. Putter styles, handedness, brand, model, shaft and nickname are attributes. Putters and chippers can be in the bag but are excluded from full-shot recommendations by default.

## 4. Personal club and bag behaviour

1. In **Driving Range**, choose `Add club`.
2. Select category and number/role, or `Custom`.
3. Confirm the label and optionally add nickname, brand, model, loft, handedness, shaft and notes.
4. Choose whether it is in the active bag.

Rules:

- `Inventory` contains current, experimental and retired clubs.
- `Active bag` contains at most 14 and is the only set eligible for advice.
- Duplicate categories are allowed; the UI requires a visible differentiator.
- Retiring preserves historical shots.
- Replacing a club creates a new record rather than contaminating its predecessor's history.
- Starter suggestions never include invented distances.
- The active bag can be reordered. Permanent deletion is distinct from retirement/temporary deactivation, warns that linked range history is also removed, and uses a normal recoverable confirmation flow where available.
- Every club may have an optional nickname. When present, the locker and Profile show the nickname as the primary label and the actual club name immediately beneath it.
- The locker uses an original, licence-safe vector club system covering driver, mini driver, every numbered wood/hybrid/utility/iron, each wedge role, chipper, putter and custom clubs. Family silhouette communicates head type while a compact designation such as `5W`, `7I` or `SW` distinguishes the exact club.

## 5. Driving Range recording

### Session start

Choose:

- club;
- yards or metres;
- **carry** (recommended) or **total**;
- manual estimate/range marker, launch monitor or other measured source.

Explain that carry is first landing point, total is final resting distance, and range balls, slope, wind and poor markers affect results. Do not label manual entry as GPS or launch-monitor measurement.

### Fast entry

```text
Driving Range                         7 Iron

Average carry                         146 yd
Playing distance                      148 yd
Typical range                       139–155 yd
12 included shots                 Confidence: Building

[ 147 ] yd                            [Add hit]
[Mishit] [Partial swing] [Undo last]

Recent: 147, 151, 143, 149, 146
```

Requirements:

- large one-handed numeric entry;
- retain selected club after entry;
- update immediately;
- undo, edit or delete;
- label mishit, partial, punch/positional or invalid;
- switch clubs without ending the session;
- survive app suspension/network loss with idempotent local-first sync.

A mishit is retained privately but excluded from the robust playing-distance calculation. The label is reversible.

Later integrations may import launch-monitor data or capture lateral dispersion. Phone GPS endpoints are not airborne carry.

### Release 1 decision

Release 1's manual fast-entry surface records **carry only**. It starts with zero observations and never seeds example hits into a real profile. The summary may show maximum carry, but it must be explicitly labelled **Max carry** and must never substitute total distance or a single maximum for the robust playing-carry value used by recommendations. Total-distance capture remains a separately labelled later expansion.

On-course shot logging may add a separate GPS endpoint/ground-distance
observation when the golfer explicitly selects a club. This is not relabelled as
carry. The algorithm prefers robust range carry, may use robust non-mishit
on-course GPS playing distance as a lower-confidence fallback, and only then
uses a family-model estimate.

### Terrain- and weather-aware rollout

Carry and rollout remain separate outputs. During an active round, OverPar may
retrieve recent Open-Meteo weather history for the course and combine:

- seven-day precipitation;
- FAO reference evapotranspiration;
- recent hot-day count;
- current temperature/wind context;
- club category/expected landing behaviour;
- the saved terrain around the selected club's predicted landing position.

This produces a conservative `soft`, `normal`, `firm` or `very firm` ground
classification and an estimated rollout. The interface shows raw GPS distance,
elevation-adjusted `plays like` distance and estimated roll separately.
Measured range carry is never rewritten into total distance.

Rollout combines the grade around the selected club's **predicted landing
position** (75 percent weight) with the whole remaining-shot grade (25
percent). It must not use the slope beside the green when a lay-up club is
expected to land well short of it. Uphill grade sharply reduces estimated
roll. Downhill rollout grows nonlinearly because gravity can keep the ball
moving once it overcomes turf resistance, particularly on very firm ground.
Club-specific baseline ratios also give lower-lofted irons progressively more
roll than higher-lofted irons. This changes estimated total only—never the
golfer's measured carry.

On very firm ground, a materially downhill whole-shot grade also supplies a
downhill floor to the rollout calculation. This prevents one locally flat or
quantised DEM window from erasing a sustained descent across the shot. Soft and
normal ground deliberately receive no such floor.

Weather cannot observe irrigation, mowing, turf species, compaction or the
ball's actual landing angle/spin. Therefore rollout remains explicitly
estimated, includes a weather-based confidence note, and must never be used as
false precision for clearing a hazard or holding a green. Green approaches
continue to select primarily by required carry and favour suitable loft.
Very firm, materially downhill shots may legitimately model rollout comparable
to or greater than carry, but the approximation marker must remain visible and
the result must not be presented as a guaranteed stopping position.

Supporting evidence:

- [USGA: Factors Affecting Firmness](https://www.usga.org/content/usga/home-page/course-care/green-section-record/61/issue-01/factors-affecting-firmness0.html)
- [Golf ball landing, bounce and roll on turf](https://doi.org/10.1016/j.proeng.2010.04.138)
- [Titleist: Angle of Descent](https://www.titleist.com/learning-lab/performance/golf-ball-angle-of-descent)
- [Open-Meteo weather API documentation](https://open-meteo.com/en/docs)

### Slope-aware club strategy

Elevation does not make an iron universally superior to a driver. Lower-lofted
clubs normally maximise distance, while higher-lofted irons produce steeper
landing angles and greater stopping control. Uphill and downhill terrain can
also change launch, spin, balance and rollout.

OverPar therefore distinguishes a reachable target from an unreachable sloped
target. If a club can carry the adjusted target, choose the shortest suitable
club that reaches it. A controlled iron lay-up is allowed only when all three
conditions hold: the target is more than eight percent beyond every credible
club distance, terrain is significant, and the shot is inside a personalised
lay-up window. Start that window at the golfer's longest credible iron carry
plus 100 yards. Expand it by 15 yards per absolute percentage point of average
grade, capped at 60 additional yards. Targets beyond that slope-adjusted window
remain distance-maximising driver shots. Treat terrain
as significant when the remaining shot climbs/drops at least four metres, has
at least a 1.5-percent average grade, or has a consistently directional profile
with at least two metres of net change. Gentle slopes retain the
distance-maximising driver recommendation. Show the measured climb/drop and
average grade in the interface rather than only a categorical terrain label.

For a qualifying lay-up, prefer the lowest-numbered active standard iron (for
example, 5 iron before 6 iron) because normal club order is stronger evidence
than a sparse observation set whose gapping is inverted. Use the
corrected/modelled carry when that club's samples are anomalous. Fall back to
the iron or utility iron with the greatest credible playing carry when numbered
irons are unavailable. Label the result as a lay-up rather than implying it
reaches the green.

Supporting evidence:

- [Titleist: Angle of Descent](https://www.titleist.com/learning-lab/performance/golf-ball-angle-of-descent)
- [TrackMan comparison on uphill and downhill fairways](https://www.sciencedirect.com/org/science/article/pii/S1875399X21000177)
- [The Effect of Uphill and Downhill Slopes on Weight Transfer, Alignment, and Shot Outcome](https://cir.nii.ac.jp/crid/1360013173029000960)

## 6. Calculations

Store canonical values in metres and convert for display. Never combine different physical clubs, carry with total, or full shots with partial/punch shots. Preserve source and context (`driving_range`, `course`, `fitting`, `other`).

### Requested average

```text
arithmetic_mean = sum(distance_m) / included_sample_count
new_mean = old_mean + (new_distance - old_mean) / new_sample_count
```

Shot-level data remains authoritative. Edits, deletions and exclusions trigger deterministic recomputation.

### Playing distance

Initial transparent method:

1. select valid full-swing observations of one club and distance kind;
2. exclude user-labelled mishits/partial/positional shots;
3. at 8+ eligible shots, calculate median and median absolute deviation (MAD);
4. flag extremes outside `median ± 3 × 1.4826 × MAD`;
5. calculate a 10% trimmed mean of the remaining set;
6. keep the raw arithmetic average visible separately.

If MAD is zero or the sample is small, use the median and do not auto-exclude. Show excluded count and permit review. This is OverPar's initial rule, not a reproduction of proprietary competitors.

Calculate `p20`, median and `p80`; show p20–p80 as the typical range. Retain standard deviation/interquartile range internally. Use a documented percentile interpolation method everywhere.

### Recency and confidence

Keep all-time and recent filters. Recent observations may receive more weight after validation, while underlying shots never age out. Allow recalibration after injury, swing or equipment change.

Initial confidence:

| State | Eligible observations |
|---|---:|
| No data | 0 |
| Very low | 1–2 |
| Low | 3–7 |
| Building | 8–19 |
| Good | 20+ recent observations with usable spread |

Source quality, recency and consistency can reduce confidence. Twenty shots do not guarantee accuracy.

### Personal gapping estimates and anomaly checks

The locker may help a partially calibrated golfer, but modelled values must remain separate from measured range shots:

1. assign each recognisable club/loft a documented neutral reference carry used only for relative gapping;
2. for every calibrated club, divide the golfer's robust playing carry by that club's reference carry;
3. use the median ratio as the golfer's current personal power factor so one unusual club does not control the bag;
4. multiply an uncalibrated club's reference carry by that factor;
5. label the result `Estimated carry`, show low confidence and replace it automatically once real observations exist.

To check a calibrated club, calculate its model estimate from the **other** calibrated clubs. Flag a `Possible gapping anomaly` when the recorded playing carry differs by more than the larger of roughly 9 yards or 18 percent. This catches reversed gaps such as a 7 Iron materially shorter than a 9 Iron without deleting, rewriting or automatically excluding the golfer's observations. Ask for more full swings and allow equipment, loft, strike and labelling differences.

Putter, chipper and unrecognisable custom clubs receive no automatic full-swing estimate. Explicit loft takes priority over a generic category. Recommendations may use estimates only as a visibly low-confidence fallback; measured robust carry always wins.

### 29 July 2026 evidence refresh: family curves, anchors and contradictions

Research does not support one universal whole-bag multiplier. Carry depends on ball speed, launch and spin; loft, shaft length and head design differ by family. TrackMan calls carry consistency important for equipment gapping, while Titleist fitting explicitly evaluates each category and seeks even useful spacing. Callaway notes that a fairway wood normally travels farther than an equal-loft hybrid because of its longer shaft and head design.

Release 1's replacement estimator should therefore:

1. group clubs into `tee_wood`, `fairway_wood`, `hybrid`, `utility_iron`, `iron` and `wedge`;
2. use actual loft when known, then club number, and decline to estimate ambiguous custom clubs;
3. derive each family's scale from the highest **credible robust carry**, never the longest individual shot;
4. weight anchors by eligible-shot count, recency and spread;
5. enforce monotonic order within a comparable family using weighted isotonic regression;
6. treat a backwards observation as a possible anomaly without deleting it;
7. estimate an anomalous club from the other credible family anchors;
8. show a range and confidence, not false one-yard precision;
9. keep estimates out of measured averages, maximum carry and shot counts;
10. allow estimates in recommendations only as an explicit low-confidence fallback.

For the concrete `9 Iron = 100 yd`, `7 Iron = 60 yd` case, published TrackMan-based curves place the 7I/9I carry ratio around `1.17–1.21`, depending on cohort. The initial neutral prior can be `1.19`, producing an estimated 7 Iron near `119 yd`. The 60-yard observation remains visible but cannot become the iron-family anchor unless repeated evidence establishes that the clubs, labels, lofts or swing intent differ.

Suggested neutral within-family indices (ratios are applied as `anchor carry × target index ÷ anchor index`) remain priors:

| Family | Neutral index |
|---|---|
| Tee woods | Driver `1.00`, Mini Driver `0.95` |
| Fairway woods | 3W `0.90`, 4W `0.87`, 5W `0.84`, 7W `0.78`, 9W `0.72`, 11W `0.66`, 13W `0.60` |
| Hybrids | 1H `0.94`, 2H `0.89`, 3H `0.84`, 4H `0.79`, 5H `0.74`, 6H `0.69`, 7H `0.64`, 8H `0.59`, 9H `0.54` |
| Utility irons | 1U `0.94`, 2U `0.89`, 3U `0.84`, 4U `0.79`, 5U `0.74`, 6U `0.69` |
| Irons | 1I `0.94`, 2I `0.89`, 3I `0.84`, 4I `0.79`, 5I `0.74`, 6I `0.69`, 7I `0.64`, 8I `0.59`, 9I `0.54` |
| Wedges | PW `0.50`, GW/AW `0.46`, SW `0.42`, LW `0.39` |

These indices are starting constraints, not claims about a particular golfer. Modern iron lofts vary materially by model, woods/hybrids can overlap, slower golfers may see long-club distance compression, and wedge partial swings require separate modelling.

Evidence reviewed:

- [TrackMan: PGA and LPGA tour averages](https://support.trackmangolf.com/hc/en-us/articles/5089752464667-Shot-Analysis-Tour-Averages-On-PGA-LPGA-Tour)
- [TrackMan: definition and use of carry](https://support.trackmangolf.com/hc/en-us/articles/39726543090971-Parameters-Carry-Tee-to-Green)
- [TrackMan: Map My Bag uses 6–30 shots, carry, total, dispersion and gaps](https://www.trackman.com/de/blog/golf/know-your-numbers-introducing-map-my-bag-in-tps-10-1)
- [Arccos: Smart Distance, Smart Range and Longest](https://support.arccosgolf.com/hc/en-us/articles/360036475132-What-is-Smart-Distance-Smart-Range-and-Longest)
- [Arccos: Club Overview filters mishits/outliers and varies percentile by club type](https://support.arccosgolf.com/hc/en-us/articles/50225781366164-Understanding-Your-Club-Overview-Stats)
- [Shot Scope: Performance Average removes extreme outliers](https://shotscope.com/au/wp-content/uploads/2024/11/Ebook-8-Data-with-Danny-Maude_digital.pdf)
- [Titleist: median carry rather than the best-ever shot](https://www.titleist.com/learning-lab/performance/golf-carry-and-total-distance)
- [Titleist: category-aware fitting and distance gapping](https://www.titleist.com/fitting/golf-club-fitting)
- [Titleist Vokey: 4–6° and approximately 10–15-yard wedge gaps](https://www.titleist.com/teamtitleist/team-titleist/f/golf-clubs/65080/maximize-your-performance-with-the-right-wedges-for-you)
- [Callaway: fairway wood lofts, equal-loft hybrid differences and 4–5° wood spacing](https://www.callawaygolf.com/golf-guides/fairway-wood-buying-guide.html)
- [Callaway: current iron and wedge loft specifications](https://callawaymedia.com/wp-content/uploads/2026/02/2026_Club-Spec-Charts_final.pdf)
- [PING: power/retro loft specifications change distance and trajectory](https://ping.com/en-us/golf-clubs/irons/g730-iron)
- [TaylorMade: top-of-bag loft gaps do not translate to one fixed distance gap](https://www.taylormadegolf.com/gapr-recommender.html)
- [ASGCA Longleaf: reference carries as percentages of driver carry](https://assets-us-01.kc-usercontent.com/c42c7bf4-dca7-00ea-4f2e-373223f80f76/091273c3-425d-4c7e-91e0-6f76742c263e/Longleaf-Tee-Syst-Brochure2016.pdf)
- [Reddit: eight rounds can still be too little for sparsely used clubs](https://www.reddit.com/r/golf/comments/18p7wcc)
- [Reddit: users observe Arccos estimating unused clubs from other club data](https://www.reddit.com/r/golf/comments/1k4qdif)
- [Reddit: poor range balls make gapping unreliable](https://www.reddit.com/r/golf/comments/mw0b7g)
- [Reddit: real ranges may use deliberately reduced-flight balls](https://www.reddit.com/r/golf/comments/1svbnan/how_much_distance_do_range_balls_actually_lose/)
- [Reddit: practical iron gaps vary with speed, loft and design](https://www.reddit.com/r/golf/comments/1r8pvvx/what_are_typical_iron_distance_gaps_between_clubs/)

## 7. Profile presentation and privacy

```text
Club distances                         [Driving Range]

Driver       231 yd     214–244       24 shots
5 Wood       194 yd     185–202       18 shots
7 Iron       146 yd     139–155       20 shots
PW           108 yd     102–113       21 shots

[View all clubs and gapping]
```

The expanded view has a longest-to-shortest gapping chart, explicitly labelled carry/total, playing distance, typical range, sample count, confidence, last update and gap/overlap indicators.

- Private by default.
- Independently selectable visibility: `Only me`, later `Connections`, or `OverPar community`.
- Public viewers never see raw observations, session times or precise practice locations.
- Profile visibility never automatically publishes club statistics.
- Omit the card for viewers when empty; the owner may see `Record club distances`.

## 8. On-course recommendation engine

### Inputs

Minimum club choice:

- fresh device position and GPS accuracy;
- selected target, normally green centre or user-selected map point;
- raw geodesic distance;
- active-bag clubs with compatible data.

High-quality strategy also needs:

- green and hazard/OB/bunker/landing geometry;
- personal longitudinal and ideally lateral dispersion;
- carry observations for forced carries;
- current lie/shot intent;
- optional fresh enabled elevation/weather.

Measured raw distance, modelled plays-like distance and recommendation stay separate.

### Attack-first selection

“Attack” means play towards the safest useful part of the green, not always the flag.

For each eligible club:

1. project its personal distance distribution;
2. evaluate overlap with the safe green/approach target;
3. estimate short, long and hazard outcomes;
4. rank club and aim point;
5. prefer a safe green-centre target unless pin geometry is trustworthy.

With only one-dimensional data, prefer the shortest robust playing carry that reaches the selected target; if none reaches it, show the longest calibrated option and make the limitation clear. Do not select an under-club merely because its numeric distance is closest, use total rollout as carry, or use a one-off maximum as the normal recommendation distance. Say hazard strategy is unavailable and do not invent lateral accuracy.

```text
Recommended: 7 Iron
151 yd to green centre
Your playing carry: 148 yd (typical 139–155)
Good confidence · aim centre of green
```

If two are close, show the primary and alternative with the reason.

### Expected-cost model

```text
expected_cost(action) =
  1
  + Σ probability(outcome | club, aim, lie, conditions)
      × [expected_strokes_remaining(outcome) + penalty_strokes(outcome)]
```

Choose the lowest expected cost subject to confidence and safety. The first release may use a deterministic risk grid but should preserve these semantics.

### Lay-up is a last resort

A lay-up may win only when:

1. no credible active-club range reaches a useful green/approach landing area;
2. conservative carry cannot clear a severe hazard plus GPS/dispersion margin;
3. water, OB, unplayable recovery or another severe mapped risk makes attack materially worse;
4. attack dispersion has no viable landing region while a nearer zone is demonstrably safer;
5. a user-declared recovery lie, injury or shot restriction invalidates the attacking club.

A bunker alone or low confidence does not automatically force a lay-up. With insufficient evidence, show options and uncertainty.

Attack remains selected unless:

```text
expected_cost(lay_up) + decision_margin < expected_cost(attack)
```

Start with a conservative remotely configurable hypothesis such as `0.20 expected strokes`, then validate it. Obvious unreachable/forced-carry failures may bypass the comparison but still need an explanation.

### Lay-up target

Do not default to 100 yards or a favourite wedge distance. Choose the longest reliably safe advance that:

- clears the player's typical dispersion from severe hazard and map uncertainty;
- does not run through the safe area into new trouble;
- leaves a viable next shot;
- uses a sufficiently calibrated active club;
- respects the lie.

Use a preferred next-club distance only as a tie-breaker between similarly safe outcomes.

```text
Lay-up suggested: 6 Iron to the left fairway
Attack is 224 yd. Your 3 Wood's lower carry range does not clear the
water with the current GPS margin. This leaves about 82 yd.

[Use lay-up] [Show attack option]
```

The user always decides. Store recommendation version, reason and selected option for validation.

### GPS honesty and compliant mode

- Use a fresh foreground fix and display accuracy.
- Expand buffers with GPS/map uncertainty.
- If uncertainty could reverse the decision, do not issue confident advice.
- Remind the golfer the device should be near the ball when safe.
- Never call a recommendation exact.
- Rules-compliant mode retains permitted raw distances but hides plays-like, club and attack/lay-up advice for the whole round.
- Tell users to check competition/local rules rather than promise universal legality.

## 9. Proposed data model

```text
user_clubs
  id uuid PK
  user_id uuid FK
  category, number_or_role, display_name, nickname
  loft_degrees, handedness, brand, model, shaft
  status enum(active, inventory, retired)
  created_at, updated_at, retired_at

range_sessions
  id uuid PK
  user_id uuid FK
  started_at, ended_at
  default_distance_kind enum(carry, total)
  source enum(manual, launch_monitor, gps, imported, other)
  conditions_note

club_distance_observations
  id uuid PK
  user_id, club_id, session_id
  context enum(driving_range, course, fitting, other)
  distance_kind enum(carry, total)
  distance_m
  source enum(manual, launch_monitor, gps_endpoints, imported, corrected)
  shot_intent enum(full, partial, punch, positional, unknown)
  quality_label enum(normal, mishit, invalid, unknown)
  included_by_user
  source_accuracy_m nullable
  occurred_at, client_created_at, updated_at

club_distance_aggregates
  user_id, club_id, context_filter, distance_kind, period_filter
  raw_sample_count, eligible_sample_count, excluded_sample_count
  arithmetic_mean_m, median_m, trimmed_mean_m
  p20_m, p80_m, standard_deviation_m
  playing_distance_m, confidence, algorithm_version, generated_at

club_stats_visibility
  user_id
  visibility enum(private, connections, community)

recommendation_events
  id, user_id, round_id, hole_number
  raw_distance_m, adjusted_distance_m, gps_accuracy_m
  recommended_club_id, alternative_club_ids
  strategy enum(attack, lay_up, options_only, unavailable)
  explanation_codes, confidence, model_version, selected_option, created_at
```

Constraints:

- positive, plausibly bounded distances;
- no more than 14 active clubs;
- observation owner owns club/session;
- aggregate uniqueness includes filter and algorithm version;
- recommendation events are private round data;
- aggregate removal never cascades into raw-shot loss.

## 10. Security, offline and jobs

- Users manage only their own clubs, sessions and observations.
- Public profile queries see only deliberately published aggregate projections.
- Raw observations/session metadata never enter the public view.
- Client UUIDs make offline capture retry-safe.
- Aggregate jobs are versioned and idempotent.
- Observation changes mark affected aggregates dirty.
- Client optimistic values reconcile with server values.
- Algorithm updates create a versioned recomputation; historical advice remains attributable.

## 11. Failure states

- No shots: request calibration; never recommend that club.
- 1–7 shots: show low confidence.
- Only total exists for forced carry: do not claim clearance.
- Implausible input: confirm likely unit mistake.
- Poor GPS: pause strategic advice if uncertainty matters.
- Missing hazards: give distance-based club choice, no lay-up verdict.
- Offline: record normally; label cached recommendation timestamp.
- Retired club: preserve history but do not recommend.

## 12. Delivery order

1. **Driving Range foundation:** catalogue, inventory, 14-club active bag, local-first sessions, carry/total, averages, robust range/confidence, edit/undo/exclude/retire.
2. **Profile card:** private summary, list/gapping chart and privacy selector.
3. **Basic advice:** fresh GPS, active bag, attack-first distribution match, explanation, no unsupported lay-up, rules-compliant mode.
4. **Course-aware strategy:** hazard geometry, carry clearance, uncertainty and expected-cost comparison.
5. **Advanced modelling:** lateral dispersion, lie/conditions, two-dimensional landing distributions and validated expected-strokes model.

## 13. Acceptance criteria

- The page is labelled **Driving Range**.
- Every common modern club and unrestricted custom clubs can be represented.
- Duplicate types remain distinct.
- Inventory may exceed 14; active bag may not.
- Repeated carry/total entries immediately update an arithmetic average.
- Hits can be corrected, removed or labelled without corrupting history.
- Carry and total never mix.
- Playing distance, range, sample count and confidence accompany the average.
- A clean private-by-default aggregate appears on the profile.
- New hits update that aggregate.
- Only active calibrated clubs are recommended.
- Advice explains target distance, personal evidence and confidence.
- A safe green target is preferred.
- Missing hazard/dispersion data never produces a fictional lay-up verdict.
- Lay-up appears only for unreachable/forced-carry cases or material expected-risk advantage.
- Lay-up advances as far as reliably safe rather than seeking an arbitrary yardage.
- The user can inspect/choose attack.
- Raw GPS remains separate from advice.
- Rules-compliant mode removes assistance.

## 14. Primary sources

- [USGA: Clubs and the 14-club limit](https://www.usga.org/content/usga/home-page/rules-hub/topics/clubs.html/1000)
- [USGA: Equipment Rules](https://www.usga.org/content/dam/usga/pdf/Equipment/Equipment%20Rules%20Final.pdf)
- [USGA: Informational Club Database](https://www.usga.org/rules-hub/grooves/informational-club-database.html)
- [PING: club categories](https://ping.com/en-us/golf-clubs)
- [TaylorMade: club categories](https://www.taylormadegolf.com/taylormade-clubs/?lang=en_US)
- [Golf Pad: recommendations and typical-distance learning](https://support.golfpadgps.com/support/solutions/articles/6000193136-how-do-club-recommendations-work-does-golf-pad-use-plays-like-data-)
- [Golf Pad: duplicate and individual clubs](https://support.golfpadgps.com/support/solutions/articles/6000143649-how-to-configure-your-clubs)
- [Golf Pad: rules-compliant mode](https://support.golfpadgps.com/support/solutions/articles/6000244430-rules-compliant-mode)
- [Shot Scope: Performance Average](https://v5support.shotscope.com/hc/en-us/articles/23425490591889-What-Is-P-AVG-Performance-Average-Distance)
- [Shot Scope: P-AVG on the hole map](https://x5support.shotscope.com/hc/en-us/articles/22979636108817-How-to-View-Your-Performance-Average-P-Avg-Distances-on-the-Hole-Map-View)
- [Arccos: Smart Distance, range, dispersion and confidence](https://support.arccosgolf.com/hc/en-us/articles/50225781366164-Understanding-Your-Club-Overview-Stats)
- [Baugher et al.: Golf Strategy Optimization and the Value of Golf Skills](https://arxiv.org/abs/2309.00485)
