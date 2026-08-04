# Golf GPS and shot-tracking app research

**Research date:** 29 July 2026  
**Purpose:** Product and technical research for later use in OverPar  
**Scope:** Smartphone golf GPS/rangefinder apps and golf shot-tracer apps, with particular attention to Big Wedge's **Wedge** app and **SmoothSwing**

> **Product decision — 12 August 2026:** OverPar no longer includes visual shot tracing, camera shot recording or Gallery. Tracer material below is retained only as historical research and must not be treated as implementation scope. GPS shot logging remains in scope.

> Pricing and feature gates change frequently and vary by country/app store. Prices below are the public prices found on the research date, normally in USD unless stated otherwise. “Free” means that a useful free tier exists, not necessarily that every feature is free.

## Executive summary

A golf GPS app does not normally track the golf ball. It obtains the phone/watch position from the operating system, looks up stored coordinates or polygons for the chosen course, and calculates straight-line ground distances from the player to mapped targets such as the front, centre and back of the green. The product's quality therefore depends on two different accuracy layers: the current device location and the accuracy/freshness of its course mapping.

Most phones do not expose “raw GPS only” to an ordinary app. iOS Core Location and Android's location services fuse GNSS/GPS with Wi-Fi, mobile networks, Bluetooth and motion sensors. Under open sky, GPS.gov says a typical smartphone is accurate to about a **4.9 m / 16 ft radius**, but trees, buildings, reflected signals, phone placement and poor satellite geometry can make it worse. A good golf app shows or internally uses the reported accuracy radius, rejects stale/noisy fixes, smooths positions, and avoids displaying false precision.

The mainstream GPS products have converged on the same core loop:

1. Find/select a course and tee.
2. Download a course record and map imagery.
3. Request a high-accuracy live location.
4. match the player to a hole.
5. calculate distances to stored course points.
6. optionally adjust a distance for elevation, weather and the golfer's club history.
7. collect score, lie, club and shot positions for post-round statistics.

Big Wedge's Wedge publicly advertises this familiar model: GPS scoring, live distances, smart course mapping, club selection, stats and more than 40,000 courses. Its public material does **not** disclose its mapping supplier, GPS sampling/filtering, distance formula, offline architecture or shot-detection method. Claims about those implementation details would therefore be speculation.

SmoothSwing is a different and unusually attractive proposition. It uses the phone camera to generate a broadcast-style trace over golf video in real time and also bundles a “360 Golf GPS,” plays-like distances and club assistance. The App Store says it needs a **white golf ball**, does not support iPhone 8/8 Plus/X, can stop recording when the device is hot, is free with in-app purchases, and sells SmoothSwing Pro for **$9.99** in the US. Its public listing does not reveal the model or source code, so the exact computer-vision implementation is not verifiable. The most plausible architecture is impact/launch detection followed by tiny bright-object tracking across consecutive frames, temporal/path filtering, trajectory fitting and rendering. That is an informed inference, not a developer-confirmed fact.

The opportunity for OverPar is not merely “another GPS screen.” A strong product would combine Wedge-like fast scoring and social play with SmoothSwing-like instant visual delight, while being explicit about confidence, allowing effortless corrections, and keeping measured GPS shot logs separate from a video tracer that is a visualisation rather than launch-monitor telemetry.

---

## 1. How smartphone golf GPS works

### 1.1 Position acquisition

The phone receives timestamped latitude/longitude estimates through its operating-system location framework:

- [Apple Core Location](https://developer.apple.com/documentation/corelocation) combines available GPS, Wi-Fi, Bluetooth, cellular, magnetometer and barometer information. Apps configure the desired accuracy and update behaviour rather than directly operating the GPS radio.
- [Android location updates](https://developer.android.com/develop/sensors-and-location/location/request-updates) similarly provide the best available location from providers such as Wi-Fi and GPS, subject to permissions and the app's request settings.
- Each fix should carry an uncertainty estimate. Apple defines `horizontalAccuracy` as the radius of uncertainty in metres around the returned coordinate.

“GPS” in an app's marketing is consequently shorthand for a fused location result that will usually be GNSS-led outdoors. Modern devices may hear multiple satellite constellations and frequencies; app behaviour and hardware vary.

### 1.2 Course data

The app needs a course database containing, at minimum:

- course and hole identifiers;
- tee positions and pars;
- front, centre and back green reference points, or ideally a green polygon;
- optional hazard, bunker, water, dogleg and lay-up points/polygons;
- satellite/aerial imagery tiles or a vector course rendering;
- scorecard metadata, ratings, slopes and stroke indexes.

The database may be licensed, created in-house, derived from mapping data, submitted by courses/users, or use a mixture. Mapping quality can cause a consistent error even when the player's phone location is perfect. Green renovations, alternate greens, moved tee boxes and incorrect hole assignments all require correction workflows.

### 1.3 Distance calculation

For ordinary golf distances, the app calculates the geodesic distance between the player's coordinate and one or more stored target coordinates. A Haversine or another Earth-distance calculation is more than adequate at golf-course scale. A simplified form is:

```text
a = sin²(Δφ/2) + cos φ1 × cos φ2 × sin²(Δλ/2)
c = 2 × atan2(√a, √(1−a))
distance = EarthRadius × c
```

The result is the straight horizontal distance, not the route walked and not necessarily the distance to the day's physical flag. Front/middle/back are mapped reference locations. If the user drags a target on the map, the app converts that screen point to a map coordinate and performs the same calculation, often also showing target-to-green distance.

### 1.4 “Plays like” distance

Premium caddie features adjust the geometric number:

- elevation difference between ball and target;
- wind speed/direction;
- temperature, humidity and altitude/air density;
- rain or other conditions;
- the golfer's observed club-distance distribution.

[18Birdies](https://help.18birdies.com/article/645-plays-like-distances), for example, publicly says its adjusted distance uses temperature, elevation change, wind, altitude and other conditions. The exact proprietary weighting is generally undisclosed. A plays-like figure is a recommendation/model output, not a more accurate measurement of the target.

Tournament legality matters. Under the Rules of Golf, competition committees and local rules can restrict distance-measuring or advice-like functionality; an app should offer a tournament-compliant mode that disables slope, weather-based adjustment and club recommendation while retaining permitted distance information.

### 1.5 GPS shot logging

A conventional shot tracker saves a start coordinate, waits for the player to reach the ball, and saves the next coordinate. The separation estimates total shot distance. It normally **cannot know the actual airborne path, carry distance, landing point, spin or curvature**. It measures start-to-next-ball-position, which includes roll and can be wrong if the player carries the phone elsewhere.

Detection modes include:

- **Manual:** tap “track/start shot,” then confirm at the ball.
- **Watch-assisted:** detect a swing from accelerometer/gyroscope patterns and pair it with GPS movement.
- **Club tag/sensor:** identify the selected club through NFC/Bluetooth/acoustic or grip-mounted hardware.
- **Inference:** use movement, hole context, scoring and stops to propose shot positions, then ask for review.

[18Birdies Smart Tracking](https://help.18birdies.com/article/734-smart-tracking-automatic-shot-tracking-with-18birdies) explicitly says it uses GPS movement and, when available, Apple Watch swing detection. [Hole19's current watch flow](https://help.hole19golf.com/hc/en-us/articles/25036534122012-How-to-use-the-Shot-Tracker-Premium) starts counting from the previous position, then records the shot when the golfer reaches the ball and taps, with suggested club and lie.

### 1.6 Accuracy and failure modes

[GPS.gov](https://www.gps.gov/index.php/gps-accuracy-0) states that GPS-enabled smartphones are typically accurate to a 4.9 m radius under open sky and identifies blockage, atmospheric conditions, receiver quality, geometry and multipath reflections as important factors. For golf, that implies:

- a few metres of error can visibly alter a short-game or green-edge distance;
- two uncertain endpoints compound error in a tracked-shot length;
- a phone in a cart reports the cart's location, not the ball's;
- a watch and phone can disagree because their antenna, filtering and current fixes differ;
- “153 yards” on screen should not be interpreted as guaranteed one-yard accuracy.

Good implementation practices include:

- request high accuracy only during a round to manage battery;
- ignore stale fixes and locations whose accuracy radius is too large;
- wait for several stable readings before committing a shot point;
- use median/Kalman-style filtering cautiously, without causing lag;
- show the accuracy circle or a “GPS settling” state;
- allow manual correction and course-map issue reporting;
- cache course geometry for weak-data areas;
- separate map download/network failure from GPS failure;
- use geofencing/map matching only as a hint, never to force the golfer onto a fairway when they are in trees.

---

## 2. GPS app examples: free and paid mix

### 2.1 Wedge by Big Wedge — free/freemium, closest named reference

**Public proposition.** [Wedge's site](https://app.bigwedgegolf.com/) promises GPS-powered scoring, accurate shot selection, worldwide insights, 40,000+ courses and smart stat tracking. Its [UK App Store listing](https://apps.apple.com/gb/app/wedge/id6748689243) describes Stroke Play, Match Play, Stableford and GPS modes, live distances, smart mapping, automatic round saving, performance review and real-time social play. It is free with in-app purchases and iPhone-only in that listing.

**Likely operating model.** Its feature set necessarily requires device location plus mapped course target coordinates, followed by live distance calculation. That is an architectural inference from the functions, not a disclosed Big Wedge specification.

**What is compelling.**

- modern, social framing rather than a pure rangefinder;
- multiple scoring formats;
- GPS and score entry in the same round flow;
- a large course catalogue;
- club-confidence/shot-selection messaging that is easy for recreational golfers to understand.

**Unknowns that public research could not verify.**

- course-map source and map correction process;
- exact free-versus-paid gates and in-app purchase prices;
- whether shots are logged individually or “smart tracking” refers to aggregate score stats;
- source device for position when a watch is present;
- update frequency, filtering, offline maps and battery strategy;
- whether “accurate shot selection” includes slope/weather/personal dispersion.

### 2.2 18Birdies — strong free GPS, expensive premium intelligence

**Free tier.** 18Birdies says its free version includes GPS on 40,000+ courses, shot tracking, scoring, target distances, stats, multiplayer scoring, notes, low-battery mode and a watch app. Its [GPS guide](https://help.18birdies.com/article/37-using-gps-on-the-golf-course) says maps are powered by Google Maps and that it verifies tee markers, landing zones and hole locations; it shows front/centre/back, hazards and movable targets.

**Paid tier.** The [official premium page](https://18birdies.com/premium/) listed $7.99/week, $19.99/month or $99.99/year, with trials on monthly/yearly plans. Premium adds plays-like distance, weather/slope, club recommendations, advanced stats, strokes gained, 3D green maps and strategy tools.

**Tracking model.** Manual shot tracking is free. Its newer automatic system uses GPS movement and Apple Watch swing detection when available, then proposes shot markers after the hole.

**Product lesson.** This is an effective freemium ladder: core on-course utility is genuinely useful for free; higher-value decision support and analysis are monetised.

### 2.3 Hole19 — free GPS, paid watch/shot/caddie depth

**Core.** Hole19 advertises GPS yardages over 42,000+ courses, maps, scoring and cross-device use. Its [GPS page](https://www.hole19golf.com/hole19/features/gps-yardages) notably says the user's accuracy radius is displayed on the map—excellent honesty in a category that often shows unjustified single-yard precision.

**Paid tier.** The [official premium page](https://www.hole19golf.com/premium) showed €14.99/month or €69.99/year. Premium includes plays-like distances, club recommendation, iOS AR, auto-hole change, shot tracker, watch scoring/maps, distance arcs and no ads.

**Tracking model.** Current watch shot tracking measures live distance as the golfer walks, records at the ball, then suggests club and lie for confirmation. This is GPS endpoint logging, not ball-flight measurement.

**Product lesson.** Accuracy transparency and a phone-in-pocket watch workflow are meaningful differentiators. The manual confirmation step trades perfect automation for more trustworthy data.

### 2.4 Golfshot — freemium GPS with Apple Watch auto shot tracking and AR

**Core.** [Golfshot](https://golfshot.com/) advertises real-time green/hazard/target distances on 45,000+ courses, digital scoring/statistics, Golfscape augmented reality, handicap connections and automatic shot tracking through Apple Watch.

**Commercial model.** Free download with Pro subscription and other product levels. The official support page tells users to check their local in-app subscription price, so a durable single global price could not be verified. This itself is a useful pricing lesson: store/region/product complexity makes comparison harder.

**Tracking model.** Watch motion sensing can identify a golf swing and associate it with a location; GPS movement provides subsequent positions. Like other GPS trackers, resulting distance is between inferred/confirmed points, not a measured 3D flight.

**Product lesson.** AR makes the same stored target data feel novel, especially for blind shots, while automatic watch detection reduces taps. The risks are false/missed swing events and platform dependence.

### 2.5 SwingU — useful permanent free tier, mid-priced premium

**Free tier and price.** SwingU's [official pricing help](https://help.swingu.com/article/24-how-much-does-swingu-cost) says the non-expiring free app includes a GPS rangefinder, basic digital scorecard and basic stats; Plus was $59.99/year.

**Premium direction.** Premium/Plus layers historically centre on enhanced caddie features, adjusted yardages, club recommendations, more detailed statistics and instruction.

**Product lesson.** “Free forever” is an easy acquisition promise. $59.99/year occupies a middle position between Golf Pad and 18Birdies, but the value must remain obvious every round rather than after-the-round only.

### 2.6 Golf Pad — most generous low-cost value benchmark

**Free tier.** [Golf Pad's official support](https://support.golfpadgps.com/support/solutions/articles/98-golf-pad-gps-is-free-is-it-a-trial-or-a-limited-functionality-lite-version-) says free-for-life includes front/middle/back GPS, scorecard, aerial view, shot tracking and unlimited course access. It can work without separate tags.

**Paid tier.** [Golf Pad Premium](https://golfpadgps.com/) was $29.99/year, adding deeper statistics/strokes gained, club recommendations, plays-like values, more capable watch use and other advanced tools.

**Tracking model.** Tap-to-track is available; optional club tags and related hardware can make club/shot capture more automatic. GPS still supplies positions and distances.

**Product lesson.** This is the price/value threat: a full free rangefinder plus shot logging, followed by a relatively inexpensive annual upgrade. Optional hardware provides an automation path without making the base app useless.

### GPS comparison snapshot

| App | Useful free access | Public paid price found | Courses claimed | Position/shot pattern | Standout |
|---|---:|---:|---:|---|---|
| Wedge | Yes | IAP price not publicly verified | 40,000+ | Phone GPS + mapped course; shot detail undisclosed | modern scoring/social experience |
| 18Birdies | Yes | $99.99/year; $19.99/month; $7.99/week | 40,000+ | phone GPS; optional watch swing detection | deep premium caddie/stats |
| Hole19 | Yes | €69.99/year; €14.99/month | 42,000+ | phone/watch GPS with shot confirmation | visible GPS accuracy radius |
| Golfshot | Yes | local in-app price | 45,000+ | Apple Watch auto swing + GPS | AR and hands-free tracking |
| SwingU | Yes, non-expiring | $59.99/year Plus | large global database | phone GPS; manual/stat workflows | simple free-to-paid ladder |
| Golf Pad | Yes, free for life | $29.99/year | global/unlimited access claim | tap GPS tracking; optional tags | strongest low-cost bundle |

---

## 3. Shot tracking versus shot tracing

The label needs to be disambiguated in product requirements:

| Category | What it observes | What it can reliably output | What it cannot inherently output |
|---|---|---|---|
| GPS stroke logger | phone/watch locations and perhaps swing motion | start/end position, approximate total distance, club/lie history, strokes gained | true carry, apex, spin, exact curve or landing point |
| Video shot tracer | pixels over time from a camera | an overlaid visual path and shareable video | calibrated 3D ball telemetry unless supplemented |
| Launch monitor | radar or high-speed photometric sensor data | launch/ball/club metrics and modelled/measured trajectory | course-wide GPS/scoring unless integrated |

SmoothSwing belongs primarily to the video shot-tracer category. A beautiful tracer line should not be labelled as scientifically measured trajectory or distance unless there is independent calibrated data.

---

## 4. SmoothSwing deep dive

### 4.1 Verified public facts

The [US App Store listing](https://apps.apple.com/us/app/smoothswing/id1514586439) calls SmoothSwing “Shot Tracer & Golf GPS” and claims:

- real-time shot tracing;
- a “360 Golf GPS”;
- white golf balls are required;
- Club Assistant shows expected landing areas based on the player's entered club distances and plays-like distance;
- iPhone 8, iPhone 8 Plus and iPhone X are unsupported;
- prolonged direct sun/heat can warm the device;
- location may be used while the app is not open, affecting battery;
- free download with a **$9.99 SmoothSwing Pro** in-app purchase in the US;
- iPhone/iPad support, with a 111.6 MB listed download;
- 4.8/5 from roughly 10,000 ratings at the research date.

Reviews and community reports consistently praise its unusually easy, immediate trace when conditions are right. Repeated reported limitations include heat shutdown, white-ball dependence, occasional incorrect object tracking (for example grass/debris), imperfect high-speed tracking and a watermark/free-use limitation. Reviews are anecdotal rather than controlled tests, but repeated patterns are useful product evidence.

### 4.1.1 Capture-interface verification — 30 July 2026

Direct comparison against the supplied current SmoothSwing capture screen adds useful observable behaviour:

- the camera feed is the screen, rather than being hidden behind a separate explanatory page;
- a large golfer/ball-position template remains over the live preview before capture;
- both left- and right-handed visual positions are represented without requiring a settings detour;
- a central arrow/ball-origin cue establishes the launch region;
- the record control is a conventional large camera shutter;
- elapsed recording time remains visible;
- tracer colour is accessible beside the shutter;
- the user is not asked to mark impact, apex or landing before the automatic result;
- the product constrains the scene before capture instead of asking users to repair it afterwards.

The App Store still explicitly claims “World's First Real-Time Shot Tracer” and requires white balls. It also continues to exclude iPhone 8, 8 Plus and X. This supports a constrained real-time design, but does not reveal SmoothSwing's proprietary detector, temporal model, thresholds or fitting logic.

The critical UX lesson is that the template is part of the vision system, not decoration. It narrows:

- expected golfer/body region;
- stationary ball origin;
- launch direction;
- first candidate search window;
- regions dominated by club/body motion;
- the coordinate frame in which a trace can remain stable.

OverPar should therefore validate alignment on the live feed, keep the camera visible, start automatic temporal tracking at impact and draw accepted observations immediately. A canned curve before recording is actively misleading and provides none of SmoothSwing's actual value.

### 4.2 How it most likely works — explicitly an inference

SmoothSwing does not publicly document its vision stack. Based on its real-time claim, white-ball constraint, hardware exclusions and observed failure modes, a plausible on-device pipeline is:

1. **Stable capture and scene setup.** The camera is placed behind/near the golfer. A stable field of view gives the algorithm a mostly static background.
2. **Shot/impact trigger.** Motion around the club/ball, audio impact, or a combination determines when to search intensively.
3. **Candidate extraction.** Frames are searched near the launch area for a small bright, fast-moving object. White-ball dependence suggests brightness/colour contrast is important.
4. **Temporal association.** Candidate positions across successive frames are linked using expected speed, direction and continuity. Consecutive-frame information is critical because a distant ball may be only a few pixels.
5. **Background/camera compensation.** Static-scene subtraction can remove grass/sky detail. If the camera moves, feature matching or device motion sensors would be needed to stabilise the world coordinate system.
6. **Path filtering and fitting.** Outliers are rejected and a smooth spline/curve is fit through observations. When the ball disappears, the displayed tail may be interpolated or extrapolated.
7. **Rendering.** A coloured line is composited over the live/recorded video and exported.

This general approach is consistent with sports-ball research such as [TrackNet](https://arxiv.org/abs/1907.03698), which uses consecutive frames and heatmaps to track small fast objects, but there is no evidence that SmoothSwing uses TrackNet specifically.

### 4.3 Why it feels “almost perfect”

- **Instant payoff:** the user sees a TV-style result immediately, not a spreadsheet after 18 holes.
- **No external hardware:** the camera and processing device are already in the user's pocket.
- **Minimal editing:** automation removes the tedious frame-by-frame work common in manual tracer tools.
- **Shareability:** the output is inherently social content.
- **One-time low price:** $9.99 is psychologically simpler than another golf subscription.
- **Bundled utility:** GPS and club assistance give the app an on-course reason to stay installed beyond content creation.
- **Constraint-led performance:** requiring a white ball and capable hardware narrows the vision problem instead of pretending every scene will work.

### 4.4 Technical limitations

- A golf ball can travel more than 150 mph and rapidly shrink below a few pixels; blur, compression and skipped observations are inevitable.
- White clouds, bright sky, range balls, birds, insects, club reflections and flying turf can become false candidates.
- A low-contrast white ball against an overexposed sky can disappear despite satisfying the colour requirement.
- Handheld panning invalidates simple background subtraction and requires robust camera-motion compensation.
- One monocular, uncalibrated view cannot uniquely recover full 3D trajectory and true scale.
- Extended camera + high-frame-rate inference + display + GPS is computationally and thermally expensive. Direct sunlight compounds heat.
- A line can look plausible after curve smoothing even when much of the true ball flight was not observed. Confidence should therefore be communicated.
- Setting a phone up behind every shot slows play and creates a risk of damage or abandonment.

### 4.5 UX limitations and improvements

The ideal successor should preserve “point, swing, receive tracer” while adding:

- a two-second setup guide showing camera angle, launch zone, horizon and whether contrast is sufficient;
- a prominent device temperature/battery indicator before the user starts;
- auto-capture from a rolling buffer so the user need not time record;
- explicit **high/medium/low trace confidence**;
- one-tap corrections: choose launch point, drag apex/control point, choose last observed point, undo a turf false-positive;
- both live mode and higher-quality post-process mode;
- import from camera roll;
- robust handheld/panning stabilisation;
- configurable ball colour or ball auto-calibration, where hardware permits;
- watermark-free export as the paid value, without degrading the tracking algorithm;
- original video preservation so a failed trace never costs the shot;
- privacy-first on-device processing where possible, and a clear disclosure if cloud upload is used;
- thermal adaptation: lower preview resolution/frame rate or defer refinement rather than a surprise hard stop;
- accessible trace colours, thickness and glow;
- separate “visual trace” and “measured shot data” labels.

For Release 1, manual correction is a recovery path, not a required step in the happy path. The successful flow is:

```text
align golfer/ball template
  -> press record
  -> detect swing/impact
  -> associate white-ball observations across frames
  -> draw the trace during capture
  -> save original + trace metadata automatically
  -> open/replay/remove from Gallery
```

### 4.6 GPS portion of SmoothSwing

The public description says its Club Assistant combines the user's stored club distances with a plays-like distance and visual expected landing locations when zooming. That implies:

- current device position;
- stored course targets/maps;
- straight-line distance computation;
- some combination of elevation/weather adjustment;
- a personal club-distance table;
- rendering club-reach zones/arcs around the player or target.

The precise data providers and adjustment formula are not public. A future implementation should show the raw GPS distance alongside the adjusted plays-like number so users understand what was measured and what was modelled.

---

## 5. Other visual shot-tracer examples

### 5.1 Shot Tracer — paid/freemium automatic feature leader

[Shot Tracer's iOS material](https://www.shottracerapp.com/ios) advertises automatic ball-flight, swing, putt and pitch tracing. Its [App Store listing](https://apps.apple.com/us/app/shot-tracer/id1140451547) adds real-time generation, custom tracer styles, 3D map tracer, GPS/distance tools, scorecards and a 44,000+ course database. It is a broad creator toolkit rather than only a red line.

**Strength:** depth—multiple trace types, styles, games/targets and course context.  
**Risk:** a much larger feature surface can make the core one-shot workflow feel less direct, and automatic tracking still depends heavily on footage.

### 5.2 The Golf Tracer — manual, controllable alternative

The [App Store listing](https://apps.apple.com/us/app/the-golf-tracer/id1330717186) describes a manual tracer with style/colour controls, yardage overlays, swing sequence, loop, scoreboard/crowd overlays and export.

**Strength:** manual control can produce a believable result even when automatic vision fails.  
**Trade-off:** editing takes longer and the line represents the user's reconstruction.

### 5.3 Golf Ball Tracer — free, panning-aware competitor

[Golf Ball Tracer](https://golfballtracer.com/) says every feature is free and claims iOS can detect a panning camera and pin the trace to the world while the camera follows the ball.

**Strength:** explicitly tackles camera motion, one of the hardest practical cases, with an aggressive free proposition.  
**Trade-off:** free economics require scrutiny (ads, growth strategy, data policy or future monetisation), and claims should be tested across devices/scenes.

### 5.4 Shashot — manual-assisted/free entry

[Shashot](https://www.underparlab.com/) says it films the shot and allows the user to draw a matching trajectory, while acknowledging it is not fully automatic.

**Strength:** honest expectation-setting and recoverable manual workflow.  
**Trade-off:** less magical than SmoothSwing and more effort per clip.

### Tracer comparison

| Product | Automation | Capture/edit model | Pricing signal found | Key lesson |
|---|---|---|---|---|
| SmoothSwing | real-time automatic claim | live camera, white ball | free + $9.99 Pro IAP | fastest delight; narrow constraints |
| Shot Tracer | automatic + rich tools | live/post-production feature suite | paid/freemium; store price varies | creator breadth and customisation |
| The Golf Tracer | manual | user-shaped trace and overlays | free/IAP store model | correction/control beats failed AI |
| Golf Ball Tracer | automatic/manual-oriented, panning-aware claim | mobile capture/edit | advertised completely free | camera compensation is a differentiator |
| Shashot | not fully automatic | assisted manual drawing | free-access proposition | transparent expectations |

---

## 6. Visual shot tracing: detailed technical research

### 6.1 The actual problem being solved

A visual shot tracer has two separate jobs:

1. **Estimate a plausible two-dimensional screen path for the ball.**
2. **Composite a stable, attractive graphic over the video.**

It does not need to recover the complete physical flight to make a convincing social video. Conversely, a smooth and believable line is not proof that the ball was measured throughout its flight.

For a fixed camera, the core output can be represented as:

```text
observation = (frame time, screen x, screen y, confidence)
trace = smooth path through accepted observations
```

For a moving camera, the app additionally needs a mapping from each frame into a stable reference frame:

```text
world-like trace point = inverseCameraTransform(frame) × observedScreenPoint
rendered point(frame) = cameraTransform(frame) × storedWorldLikePoint
```

This is why a tracer that works with a tripod can fail badly when the filmer pans: without camera-motion compensation, it cannot distinguish ball movement from movement of the entire image.

### 6.2 End-to-end pipeline recommended for a phone

#### Stage A — capability and scene check

Before recording:

- choose a supported rear-camera format and lens;
- inspect supported frame rates;
- estimate available light and whether exposure can remain short enough;
- check device temperature, storage and battery;
- identify portrait/landscape orientation;
- guide the golfer into a launch region;
- determine whether the sky/ground contrast is suitable;
- establish whether the phone is stable or handheld.

[Apple AVFoundation](https://developer.apple.com/documentation/avfoundation/avcapturedevice/activevideominframeduration) exposes supported frame-rate ranges through the active camera format. The maximum frame rate is the reciprocal of minimum frame duration. Device-specific capability detection is therefore preferable to a hard-coded “60 fps” assumption.

The product should offer:

- **Live mode:** lower latency/resolution, immediate tracer.
- **Quality mode:** record high-quality source and analyse after the swing.
- **Manual mode:** always available, including on unsupported hardware.

#### Stage B — rolling capture and shot event detection

Keep a short circular video buffer in memory. Detect a likely strike and retain, for example, two seconds before and several seconds after it.

Possible impact signals:

- a sharp audio transient;
- sudden club/golfer motion around the ball;
- optical movement leaving the known launch region;
- pose/swing phase;
- smartwatch accelerometer event;
- combinations of the above.

Audio alone is unsafe on a busy range because nearby strikes will trigger it. Vision alone can confuse a practice swing, turf or a person crossing the scene. Sensor fusion should produce an event confidence rather than a binary truth.

This architecture lets the golfer press “arm,” take a normal swing, and receive a clip without asking a friend to time the record button.

#### Stage C — camera-motion estimation

Estimate background motion independently of the golfer, club and ball:

- detect stable background features;
- match features between frames;
- reject dynamic foreground matches;
- estimate an affine transform or homography with robust outlier rejection;
- combine visual motion with phone gyroscope/orientation data when available;
- accumulate transforms into a reference coordinate system.

A homography is appropriate for rotation and approximately planar/distant scenery, but a golf scene contains near grass, golfer, trees and distant sky at different depths. Parallax means one homography cannot perfectly align everything. A practical hierarchy is:

1. assume locked camera when residual background motion is tiny;
2. use rotation/affine stabilisation for small shake;
3. use robust homography for deliberate pans;
4. reduce confidence or request manual anchoring when parallax/zoom is too severe.

Shot Tracer's current App Store description now advertises **3D camera tracking**, moving-camera shots and improved stabilisation. [Golf Ball Tracer](https://golfballtracer.com/) similarly claims it detects a panning camera and pins the trace to the world. Public descriptions confirm that this capability is commercially important, although neither company discloses its exact algorithm.

#### Stage D — locate the ball before launch

Ball localisation is much easier while the ball is stationary and close to the camera. The app can:

- ask the user to place the ball inside a marked launch zone;
- use a small-object detector in that region;
- exploit circularity, size and brightness;
- let the user tap the ball once if automatic localisation is uncertain.

This tap is low-cost and eliminates a large search space. An excellent product should prefer one purposeful setup tap over a confident trace attached to flying turf.

#### Stage E — detect launch and early-flight observations

The first frames after impact contain the most useful evidence:

- the launch origin is known;
- expected direction is constrained;
- the ball is largest in the image;
- apparent speed is high and unlike ordinary background motion.

Candidate generation can combine:

- frame differencing/background subtraction after stabilisation;
- brightness and colour likelihood;
- a lightweight neural detector/heatmap model;
- optical flow magnitude/direction;
- shape/blur analysis;
- proximity to the predicted position.

A conventional single-frame object detector is not sufficient by itself. The ball quickly becomes tiny, blurred and sometimes invisible. [TrackNet](https://arxiv.org/abs/1907.03698) was designed for high-speed, tiny sports objects and uses consecutive images to predict a heatmap, explicitly addressing blur, afterimages and invisibility. [Golf-specific research](https://arxiv.org/abs/2012.09393) has combined CNN detectors with a Kalman filter for golf-ball detection and tracking.

The recommended design is therefore hybrid:

- a neural heatmap/detector proposes observations;
- motion/colour methods add cheap candidates;
- a temporal tracker chooses the sequence that is most consistent with a golf launch;
- physics/path priors penalise impossible jumps without forcing every shot into the same shape.

#### Stage F — temporal tracking and candidate association

Maintain a track state:

```text
state = position, velocity, acceleration/curvature,
        uncertainty, last-observed-frame, appearance
```

For each frame:

1. predict the next position and uncertainty region;
2. score all candidates using detection confidence, distance from prediction, direction continuity, brightness/appearance and curve plausibility;
3. accept the best candidate only above a threshold;
4. update the filter;
5. otherwise record a missing observation and widen uncertainty gradually.

Useful techniques:

- Kalman filtering for a lightweight motion estimate;
- particle filtering where multiple hypotheses must survive;
- Viterbi/dynamic programming across a completed clip to choose the best global path;
- spline or robust polynomial fitting after outlier rejection;
- bidirectional tracking in post-processing;
- limited optical flow for short gaps, not indefinite propagation.

Post-processing has a material advantage: it can evaluate future frames and optimise the whole path. A real-time tracker can only use current/past evidence and must commit sooner. This supports a two-pass SmoothSwing-like experience:

- show an immediate provisional trace;
- silently refine it from the saved clip;
- let the user compare or accept the refined result.

#### Stage G — deal with disappearance

The ball will often disappear long before landing. The system should store which segments are:

- **observed:** supported by accepted detections;
- **interpolated:** between reliable observations;
- **extrapolated:** beyond the last reliable observation;
- **manually supplied:** user-adjusted.

Do not visually expose four distracting colours by default, but use the distinction internally for confidence and editing.

Completion options, in order of honesty:

1. end/fade the trace at the last reliable observation;
2. ask the user to mark landing/direction;
3. fit a smooth 2D continuation labelled as estimated;
4. combine GPS-measured start/end positions or launch-monitor data when available;
5. use a physics model only after camera calibration and with clear uncertainty.

The most common consumer treatment is likely a visually plausible curve, not a recovered 3D trajectory. Recent [monocular 3D trajectory research](https://openaccess.thecvf.com/content/CVPR2026W/CVsports/html/Grad_Physics-Based_3D_Ball_Trajectory_Reconstruction_from_Monocular_Soccer_Video_A_CVPRW_2026_paper.html) found that observation noise and single-view geometric ambiguity can dominate the choice of sophisticated physics model. That finding transfers conceptually to golf: more elaborate aerodynamics cannot recover information that one uncalibrated view never captured.

#### Stage H — curve construction

For a social tracer, fit in a stabilised 2D reference frame:

- preserve the actual observed launch direction;
- apply robust fitting that ignores debris/false detections;
- use a cubic Bézier, B-spline or piecewise smooth curve;
- constrain the curve to pass through high-confidence anchors;
- avoid oscillation from frame-level noise;
- taper/fade the far end;
- transform the path back into each original video frame.

A simple parabola is not universally correct in image space. Perspective projection, camera tilt, draw/fade and camera motion alter the apparent curve. A spline with sensible regularisation is better for visual output, while physics should be a prior rather than a rigid template.

#### Stage I — rendering

The tracer is a graphics product as much as a vision product. Render:

- a consistent world-anchored path;
- anti-aliased line and optional glow;
- width that accounts for perspective or remains deliberately graphic;
- progressive reveal following the ball;
- configurable colour, opacity and persistence;
- a short fade rather than a sudden endpoint;
- optional launch flash, landing marker, distance or club overlay;
- colour-blind-safe presets;
- export at the original aspect ratio and frame rate when possible.

Keep the original video immutable. Save the trace as editable metadata—control points, transforms, styles and timing—so the user can change it without rerunning detection or degrading the video through repeated encoding.

### 6.3 Capture engineering: resolution, frame rate and exposure

The intuitive answer “always use the highest resolution and frame rate” is wrong for a phone:

- more resolution makes a distant ball occupy more pixels;
- more frames reduce the distance travelled between observations;
- but both increase processing, heat, memory bandwidth and storage;
- high frame rates may force lower resolution or poorer low-light exposure;
- shorter exposure reduces blur but admits less light and increases noise;
- digital stabilisation/cropping can remove edge pixels needed for the flight.

Recommended adaptive approach:

| Conditions | Capture bias | Reason |
|---|---|---|
| Bright daylight, modern phone | 60 fps or supported higher-rate mode; short exposure | more early-flight samples with manageable noise |
| Cloud/low light | 30–60 fps with quality post-process | excessive high-rate capture may become noisy/dark |
| Locked tripod | prioritise resolution and stable lens | background subtraction becomes powerful |
| Handheld pan | prioritise stabilisation, IMU and wider framing | prevents losing the ball and supports camera transforms |
| Heat/battery pressure | lower analysis resolution; retain source if possible | graceful degradation instead of failure |

Use a lower-resolution analysis stream/crop and retain a higher-resolution recording stream where the device supports it. Search initially inside a launch-oriented region of interest, then expand along the predicted path. This saves computation without throwing away export quality.

Phone CMOS sensors normally use rolling shutter: image rows are captured at slightly different times. Rapid ball/club movement and panning can cause skew in addition to ordinary motion blur. A short exposure reduces blur but does not eliminate row-timing distortion. The tracer should learn from blurred/streak-like ball appearances rather than assume a clean circle.

### 6.4 Why white-ball dependence helps SmoothSwing

Requiring a white ball reduces model entropy:

- the launch object has predictable brightness/chroma;
- contrast is strong against grass and blue/dark sky;
- non-white candidates can be rejected cheaply;
- synthetic training augmentation is easier;
- a smaller mobile model can perform acceptably.

But “white” is not always discriminative:

- clouds and overexposed sky are white;
- range markers and distant balls may be white;
- a white ball can clip to the same brightness as the background;
- dirt, shadow and compression change its colour;
- turf, insects and club glare create transient bright objects.

A better calibration flow would let the user frame the stationary ball and derive an appearance embedding/colour distribution for that particular ball and lighting. Supporting yellow or patterned balls could then be rolled out as explicitly tested profiles instead of a generic colour picker.

### 6.5 Fixed camera versus panning camera

| Property | Fixed/tripod | Handheld/panning |
|---|---|---|
| Background subtraction | highly effective | unreliable before stabilisation |
| World-anchored line | straightforward | requires camera transforms |
| Ball kept in frame | difficult after launch | filmer can follow it |
| Setup effort | requires stand/positioning | natural for a second person |
| Parallax | limited | can be material |
| Best product mode | automatic real-time MVP | advanced/post-process mode |

The recommended MVP is a fixed, rear-camera view from behind the golfer. It is the best chance of producing SmoothSwing-like magic reliably. Panning support should be a separately tested capability, not silently treated as equivalent.

### 6.6 2D visual trace versus real 3D flight

One uncalibrated phone view loses depth. Many 3D paths can project to a similar 2D image path. Scale also changes as the ball travels away, while its few-pixel image size becomes too noisy to use as a precise depth cue.

Potential constraints that improve reconstruction include:

- known golf-ball diameter;
- calibrated camera intrinsics/lens;
- known camera height and orientation;
- detected ground plane/horizon;
- known launch coordinate and target direction;
- GPS start/end location;
- measured initial ball speed/launch angle;
- a second synchronised camera;
- radar/launch-monitor input.

Research has shown that known ball diameter can assist [3D localisation from a calibrated monocular image](https://arxiv.org/abs/2204.00003), but this becomes unstable once the ball is only a handful of pixels. OverPar should not claim measured apex, carry or spin from an ordinary single-phone tracer unless validated against suitable ground truth.

### 6.7 A confidence model users can trust

Calculate confidence per stage:

```text
capture confidence
  × impact confidence
  × ball-origin confidence
  × tracking confidence
  × camera-transform confidence
  × completion confidence
  = overall trace confidence
```

A multiplicative concept is useful because one catastrophic stage should reduce the total even when other stages are strong. The production formula can be calibrated empirically.

User-facing states:

- **Strong trace:** sufficient observations and stable camera solution.
- **Review suggested:** path is plausible but contains a long estimated segment.
- **Needs one adjustment:** ask for apex/landing/direction.
- **Manual trace:** automatic result is not reliable enough.

Never hide a low-confidence automatic curve behind polished graphics. The fastest correction workflow is more valuable than generating a plausible-looking wrong trace.

### 6.8 Manual correction as a core feature, not failure

The ideal correction UI asks for the smallest missing piece:

- wrong launch: tap the ball/impact point;
- tracked turf: choose the correct early candidate;
- curve wrong: drag one control point left/right;
- height wrong: drag apex;
- disappeared early: tap last seen or landing direction;
- panning slipped: pin a background feature in two frames;
- timing wrong: adjust impact frame.

Changes should propagate through the fitted curve while preserving high-confidence observations. Provide undo and an instant before/after preview.

Manual-only tracers remain competitive because they guarantee completion. Automation wins only if:

```text
automatic processing + average correction time
<
time to draw a clean manual trace
```

This should be a primary product metric.

### 6.9 Model and deployment strategy

#### Recommended hybrid model

- **Scene/impact model:** small temporal classifier over cropped frames plus audio features.
- **Ball heatmap model:** temporal encoder-decoder inspired by TrackNet-style consecutive-frame input.
- **Motion candidates:** stabilised frame differences and optical flow.
- **Sequence solver:** Kalman/particle hypotheses during live capture; global path optimisation after capture.
- **Camera motion:** feature/flow-based robust transforms assisted by gyroscope.
- **Curve/refinement:** deterministic robust spline fitting with confidence-aware anchors.

#### On-device advantages

- immediate response;
- works with weak course connectivity;
- better privacy;
- no video upload cost;
- live preview is possible.

#### Cloud advantages

- larger models;
- multi-pass/bidirectional analysis;
- easier rapid model updates;
- less sustained device heat during inference, although recording/upload still costs energy;
- aggregation of opted-in difficult examples for retraining.

#### Best product architecture

Use on-device capture, impact detection and provisional tracing. Offer an optional cloud/high-quality refinement only with explicit video-upload consent. Preserve a fully functional on-device/manual path.

### 6.10 Data and training programme

There is no substitute for golf-specific footage. A useful dataset should label:

- impact frame;
- stationary ball centre;
- ball centre or blur endpoints per visible frame;
- visibility state: clear, blurred, occluded, out of frame or indeterminate;
- camera motion type;
- approximate flight shape;
- last trustworthy observation;
- false moving objects such as turf, birds and other balls;
- device, lens, resolution, fps, exposure/lighting and stabilisation;
- ball colour/design;
- whether the point was human-observed or interpolated.

Collect hard negatives aggressively:

- practice swings;
- divots without visible balls;
- adjacent-bay strikes;
- birds/insects;
- white clouds;
- range pickers and markers;
- raindrops/lens flare;
- a golfer walking across the launch zone.

Use staged data:

1. synthetic small bright objects and blurred streaks over real golf backgrounds;
2. manually labelled real fixed-camera shots;
3. active-learning review of production failures with opt-in consent;
4. panning-camera sequences;
5. broader ball colours, weather and devices.

Split evaluation by golfer, course/session and device—not random frames—so nearly identical frames cannot leak between training and test.

### 6.11 Evaluation metrics

Computer-vision metrics:

- impact-event precision/recall and timing error;
- ball detection precision/recall at pixel-size bands;
- centre error in pixels for visible frames;
- track continuity and longest correct segment;
- false-track rate;
- last-correct-observation time;
- camera-transform residual;
- percentage of curve supported by observations.

Product metrics:

- percentage of swings yielding a shareable trace without editing;
- median time from impact to preview;
- median correction time;
- percentage abandoned;
- export time/failure rate;
- temperature rise and battery consumed per ten shots;
- user rating of trace faithfulness;
- comparison against human-authored trace;
- retention/share rate after successful versus failed traces.

Do not use only average pixel error. A tracker attached to a divot may be smooth with a deceptively low error for a few frames but is a total product failure.

### 6.12 Recommended prototype milestones

**Prototype 0 — manual editor**

- video import/record;
- impact frame and launch-point selection;
- three control points and animated reveal;
- styles/export;
- editable non-destructive metadata.

This validates the renderer and sharing value before ML risk.

**Prototype 1 — automatic fixed-camera launch**

- white ball;
- daylight;
- rear wide/standard lens;
- fixed phone behind golfer;
- automatic impact and first 0.25–0.75 seconds;
- estimated continuation;
- one-control-point repair.

**Prototype 2 — two-pass trace**

- immediate provisional output;
- post-shot temporal heatmap processing;
- confidence segmentation;
- automatic selection between result versions;
- device/thermal adaptation.

**Prototype 3 — camera motion**

- shake stabilisation;
- deliberate pan;
- world-anchored trace;
- manual background pin fallback.

**Prototype 4 — richer inputs**

- yellow/patterned balls;
- imported clips;
- GPS shot start/end integration;
- optional launch-monitor metadata;
- map replay and verified-versus-estimated labels.

### 6.13 Competitive and intellectual-property caution

Shot Tracer describes itself as the first smartphone ball-flight tracking app and currently markets live tracing, 3D camera tracking and automatic distance. There are also patents covering golf tracking and automated “TV style” visual enhancement systems, including multi-camera/AI course installations. This report does not provide a freedom-to-operate opinion.

Before commercial implementation:

- commission a proper patent and trademark search in target markets;
- avoid copying competitor terminology, screens or distinctive tracer treatments;
- document independently developed algorithms and design decisions;
- review licences for datasets, models, map imagery and video codecs;
- obtain explicit rights for any user footage used in training.

---

## 7. Implications and recommendations for OverPar

### Product principles

1. **Build one excellent round loop.** Course → hole → distance → shot/score → next hole should require very few touches.
2. **Show uncertainty.** Display GPS accuracy and a settling state; never imply laser-like one-yard certainty.
3. **Use progressive automation.** Propose the hole, shot and club, but make correction faster than accepting a bad automatic result.
4. **Keep three truths separate.**
   - measured: device coordinate and raw target distance;
   - inferred: hole, swing event, club, lie and plays-like distance;
   - visualised: video trace and any extrapolated portion.
5. **Provide offline resilience.** Cache course vectors/targets and the active round; synchronise later.
6. **Optimise for battery and heat.** GPS and camera/vision need distinct lifecycle controls.
7. **Design phone and watch as a system.** The watch is ideal for glanceable distance, swing events and confirmation; the phone is ideal for maps, editing and video.
8. **Make data portable and editable.** Users will tolerate imperfect auto-detection if they can repair a round quickly and export their history.

### Suggested staged roadmap

**Stage 1 — credible free GPS core**

- course selection/nearby courses;
- front/centre/back and target distances;
- accuracy radius/GPS state;
- map target dragging;
- scorecard and round history;
- downloaded course/round offline behaviour;
- course correction reporting.

**Stage 2 — Wedge-like engagement**

- live group scoring and several formats;
- social round recap;
- bag/club distances;
- lightweight stats and personal bests;
- fast watch companion.

**Stage 3 — trusted shot logging**

- manual tap-to-track;
- watch swing suggestion;
- club/lie confirmation;
- post-hole timeline repair;
- robust outlier detection and strokes-gained analysis.

**Stage 4 — SmoothSwing-like delight**

- tripod/stable-camera automatic tracer MVP;
- white-ball/high-contrast supported mode first;
- confidence and one-tap correction;
- on-device real-time preview plus optional refinement;
- share card combining video, hole, club and verified GPS start/end distance.

**Stage 5 — differentiation**

- panning-camera stabilisation;
- selectable ball colours;
- automatic rolling capture;
- trace plus course-map replay;
- opt-in personal shot-dispersion caddie that shows ranges rather than a falsely exact recommendation.

### What to test before committing to a tracer build

Create a labelled footage set spanning:

- driver, irons, wedges and pitches;
- white/yellow balls;
- blue, grey, clouded and sunset sky;
- grass-only backgrounds and ball crossing the horizon;
- tripod versus handheld pan;
- older and current phones;
- 30/60/120 fps, multiple resolutions and stabilisation modes;
- turf/debris, practice swings and multiple balls;
- hot devices and long sessions.

Measure launch detection rate, path-point precision, usable-trace rate, false-positive rate, correction time, processing latency, energy/temperature and export success. “Looks good in selected demo clips” is not a sufficient acceptance test.

---

## 8. Bottom line

The GPS category is mature: obtaining a position and computing distance is straightforward; maintaining excellent course geometry, handling uncertainty, saving battery, making watches effortless and converting raw locations into trustworthy golf insight are the difficult parts. Wedge's attraction is its modern, integrated scoring/social presentation, not a publicly disclosed breakthrough in GPS.

SmoothSwing's attraction is more fundamental: it turns a golf shot into gratifying content immediately and asks for little expertise or hardware. Its constraints reveal how it likely achieves that speed—controlled ball colour, supported devices, a relatively stable scene and heavy on-device camera processing. The right product response is to preserve this immediacy while making confidence, failure recovery, heat handling and the boundary between visual inference and actual measurement substantially better.

## Sources

### Terrain, weather and rollout addendum — 30 July 2026

Rollout cannot be derived from carry with one universal multiplier. Published
ball/turf work identifies landing speed, landing angle, backspin and surface
firmness as key inputs. USGA turf guidance adds that soil moisture and
maintenance cause substantial between-course, day-to-day and even green-to-green
variation. Titleist describes sub-45-degree descent as more prone to skipping
and rolling rather than holding.

For OverPar's no-cost private release, Open-Meteo weather history can supply
precipitation, temperature and FAO reference evapotranspiration without another
client secret. These variables support a probabilistic firmness class, not a
measured turf condition. Recent UK golfer reports corroborate the product need:
dry summer fairways can add tens of yards, while wet courses can make carry and
total nearly equal, but these experiences are contextual rather than calibration
truth.

Product consequence: preserve and display raw carry, elevation-adjusted target,
estimated rollout and estimated total independently. Select green approaches by
carry and loft/landing suitability; use rollout primarily as risk/context.

- [Roh and Lee, Golf ball landing, bounce and roll on turf](https://doi.org/10.1016/j.proeng.2010.04.138)
- [USGA, Factors Affecting Firmness](https://www.usga.org/content/usga/home-page/course-care/green-section-record/61/issue-01/factors-affecting-firmness0.html)
- [USGA, Understanding and Appreciating Firmness](https://www.usga.org/content/usga/home-page/articles/2010/11/understanding-and-appreciating-firmness-2147491053.html)
- [Titleist, Angle of Descent](https://www.titleist.com/learning-lab/performance/golf-ball-angle-of-descent)
- [Open-Meteo API documentation](https://open-meteo.com/en/docs)
- [UK golfers discussing dry-summer rollout](https://www.reddit.com/r/golf/comments/1koxdmq)
- [Golfers discussing wet carry versus total](https://www.reddit.com/r/golf/comments/171h8la)

Primary/product sources are preferred for features and current price; government/platform documentation supports the technical GPS explanation. Community reviews were used only to identify recurring experience patterns, not as proof of implementation.

- Big Wedge, [Wedge product site](https://app.bigwedgegolf.com/)
- Apple App Store, [Wedge](https://apps.apple.com/gb/app/wedge/id6748689243)
- Apple App Store, [SmoothSwing](https://apps.apple.com/us/app/smoothswing/id1514586439)
- SmoothSwing, [privacy policy](https://www.smoothswingapp.com/privacy-policy)
- 18Birdies, [using GPS](https://help.18birdies.com/article/37-using-gps-on-the-golf-course)
- 18Birdies, [premium plans](https://18birdies.com/premium/)
- 18Birdies, [Smart Tracking](https://help.18birdies.com/article/734-smart-tracking-automatic-shot-tracking-with-18birdies)
- Hole19, [GPS yardages](https://www.hole19golf.com/hole19/features/gps-yardages)
- Hole19, [premium](https://www.hole19golf.com/premium)
- Hole19, [Shot Tracker workflow](https://help.hole19golf.com/hc/en-us/articles/25036534122012-How-to-use-the-Shot-Tracker-Premium)
- Golfshot, [product site](https://golfshot.com/)
- SwingU, [pricing](https://help.swingu.com/article/24-how-much-does-swingu-cost)
- Golf Pad, [product and premium](https://golfpadgps.com/)
- Golf Pad, [free-tier explanation](https://support.golfpadgps.com/support/solutions/articles/98-golf-pad-gps-is-free-is-it-a-trial-or-a-limited-functionality-lite-version-)
- Apple Developer, [Core Location](https://developer.apple.com/documentation/corelocation)
- Apple Developer, [`horizontalAccuracy`](https://developer.apple.com/documentation/corelocation/cllocation/horizontalaccuracy)
- Android Developers, [request location updates](https://developer.android.com/develop/sensors-and-location/location/request-updates)
- GPS.gov, [GPS accuracy](https://www.gps.gov/index.php/gps-accuracy-0)
- Shot Tracer, [iOS product page](https://www.shottracerapp.com/ios)
- Apple App Store, [Shot Tracer](https://apps.apple.com/us/app/shot-tracer/id1140451547)
- Apple App Store, [The Golf Tracer](https://apps.apple.com/us/app/the-golf-tracer/id1330717186)
- Golf Ball Tracer, [product site](https://golfballtracer.com/)
- UnderparLab, [Shashot](https://www.underparlab.com/)
- TrackNet research paper, [high-speed tiny-object tracking](https://arxiv.org/abs/1907.03698)
- Efficient Golf Ball Detection and Tracking, [CNN detectors with Kalman filtering](https://arxiv.org/abs/2012.09393)
- Apple Developer, [object tracking with Vision](https://developer.apple.com/documentation/vision/vntrackobjectrequest)
- Apple Developer, [optical-flow request](https://developer.apple.com/documentation/vision/vntrackopticalflowrequest)
- Apple Developer, [capture frame-duration controls](https://developer.apple.com/documentation/avfoundation/avcapturedevice/activevideominframeduration)
- CVPR Workshops 2026, [physics-based 3D ball trajectory reconstruction from monocular video](https://openaccess.thecvf.com/content/CVPR2026W/CVsports/html/Grad_Physics-Based_3D_Ball_Trajectory_Reconstruction_from_Monocular_Soccer_Video_A_CVPRW_2026_paper.html)
- Ball 3D Localization, [known ball size with a calibrated monocular camera](https://arxiv.org/abs/2204.00003)
- ACCV 2022, [Tracking Small and Fast Moving Objects benchmark](https://openaccess.thecvf.com/content/ACCV2022/papers/Zhang_Tracking_Small_and_Fast_Moving_Objects_A_Benchmark_ACCV_2022_paper.pdf)
- Google Patents, [AI-enabled golf course and shot tracing system](https://patents.google.com/patent/US12014543B2/en)
- Justia Patents, [automated visual enhancement camera system](https://patents.justia.com/patent/20190299056)
