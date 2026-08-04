# OverPar interface and motion design system

**Prepared:** 29 July 2026  
**Status:** Approved pre-development design plan  
**Design direction:** Friendly clubhouse

> **Scope update — 12 August 2026:** The shipping navigation is **Home, Play, Range and Profile**. Gallery, Record Shot, tracer editing and camera/video settings are removed. Later references to those surfaces are superseded design history.

## 1. Product feeling

OverPar should feel welcoming rather than elite, clean rather than clinical, playful rather than childish, and calm during a round. The visual idea is **friendly clubhouse**: generous white space, warm rounded cards, deep golf green, soft mint feedback, friendly typography and restrained physical motion.

## 2. Principles

1. White is the canvas.
2. Deep green anchors identity and primary actions.
3. Liquid Glass is a functional navigation/control layer, not a card texture.
4. Each screen has one obvious primary action.
5. Round screens prioritise outdoor readability and speed.
6. Animation explains navigation, saving and progress.
7. GPS uncertainty, penalties, privacy and processing remain explicit.
8. Dynamic Type, contrast, reduced motion/transparency and screen readers are designed from the start.

## 3. Colour system

Initial tokens require contrast testing in real components.

| Token | Value | Use |
|---|---:|---|
| `canvas` | `#FFFFFF` | Main background |
| `canvas-soft` | `#F5F8F6` | Grouped pages |
| `surface` | `#FFFFFF` | Cards, sheets, fields |
| `surface-raised` | `#FBFDFC` | Raised content |
| `forest-900` | `#083D2E` | Strong brand/header |
| `forest-800` | `#0B4D3B` | Main accent/buttons |
| `forest-700` | `#126148` | Pressed green |
| `forest-100` | `#DDF2E8` | Selected chips |
| `mint-100` | `#EAF8F1` | Quiet success/info |
| `ink-900` | `#13231D` | Primary text |
| `ink-600` | `#53665E` | Secondary text |
| `ink-400` | `#82938C` | Metadata |
| `line` | `#DFE7E2` | Borders |
| `success` | `#178457` | Saved/on target |
| `warning` | `#B77912` | GPS/confidence caution |
| `danger` | `#B43A3A` | Destructive/penalty |
| `info` | `#286EA8` | Neutral information |
| `sand` | `#C99A43` | Bunker map accent |
| `water` | `#3C85B7` | Water map accent |

Meaning never relies on colour alone.

Dark mode uses a near-black green canvas, raised dark-green surfaces, warm-white text and brighter accents. It remains recognisably OverPar rather than merely inverting colours.

## 4. Typography

Use **Nunito Sans**. Its rounded terminals provide the requested bubbly friendliness while remaining readable for scorecards, settings and distance data.

| Role | Weight | Typical size |
|---|---|---:|
| Hero/display | ExtraBold | 34–42 |
| Screen title | ExtraBold | 28–32 |
| Section title | Bold | 20–24 |
| Card title | Bold | 17–20 |
| Body | Regular/SemiBold | 16–17 |
| Supporting | Regular | 14–15 |
| Caption | SemiBold | 12–13 |
| Distance hero | ExtraBold/tabular | 44–64 |
| Button | Bold | 16–18 |
| Tab label | Bold | 11–12 |

Requirements:

- verify and retain the font licence before bundling;
- support Dynamic Type;
- use tabular figures for distance, score, timer and shot count;
- fall back to `ui-rounded`, SF Rounded/system rounded on iOS and a rounded system sans elsewhere;
- do not use decorative bubble lettering for body copy;
- avoid forced all-caps except short status labels.

The future wordmark may have custom lettering but never replaces accessible UI text.

## 5. Shape, spacing and depth

- cards: 20-point logical radius;
- feature cards/sheets: 24–28;
- buttons: capsule or 16–20 radius;
- chips: capsule;
- thumbnails: 16–20;
- map containers: 22;
- avatar: circle;
- 4-point spacing scale: `4, 8, 12, 16, 20, 24, 32, 40, 48, 64`;
- standard screen gutter: 20, minimum 16;
- minimum iOS touch target: 44 × 44;
- on-course primary controls: at least 56 high.

Prefer subtle borders to heavy shadows. Liquid Glass supplies its own depth. Do not turn every card into a pill.

## 6. Liquid Glass

Apple defines Liquid Glass as a distinct functional layer above content. OverPar uses it for:

- the iOS tab bar;
- navigation and compact toolbars;
- active-round accessory/control strip;
- transient map controls;
- camera/video controls where contrast is proven;
- system menus and connected control transitions.

Do not use it for:

- ordinary cards/list rows;
- scorecards and form bodies;
- large reading surfaces;
- warnings;
- thumbnails;
- satellite imagery.

### iOS direction

- Prefer native `TabView`, navigation and toolbar components.
- Use `glassEffect(_:in:)` only for custom controls.
- Group related effects in `GlassEffectContainer`.
- Tint one prominent action/selection selectively with forest green.
- Use clear glass only over suitable bold media with tested contrast.
- Respect Increased Contrast, Reduce Transparency and Reduce Motion.
- Limit simultaneous custom effects for performance.

Compatibility:

- current iOS: native Liquid Glass;
- earlier iOS: native material/blur fallback with identical hierarchy;
- Android: platform-appropriate translucent navigation, not a fake Apple promise;
- web: restrained backdrop material with solid fallback.

Expose a semantic `navigation_material` token whose platform adapter selects the implementation.

## 7. Top-level navigation

Use five stable destinations:

1. **Home**
2. **Play**
3. **Gallery**
4. **Range**
5. **Profile**

`Range` opens a page titled **Driving Range**.

The tab bar navigates only. Recording remains an action within a round and never becomes a central fake tab.

- labels remain visible;
- selected item uses forest tint and filled platform symbol;
- each tab preserves its navigation stack;
- positions never change;
- an active round appears in a compact accessory above the bar where supported:

```text
Hole 7 · 151 yd                         [Resume]
```

Suggested concepts are Home/clubhouse, flag/map, media stack, target and person. Use native licensed symbols through native APIs.

## 8. Screen patterns

### Home

- friendly greeting/avatar;
- nearest-course hero with `Preview` and primary `Play`;
- resume-round card;
- saved/recent courses;
- compact Gallery and Range progress;
- no unauthorised vanity metrics.

### Course preview

- satellite map is the hero;
- floating glass hole selector/map controls;
- show a live yards scale in the upper-left that recomputes from the Google map projection whenever zoom changes;
- show measured saved tee-to-green-reference yardage as a prominent map badge and repeat it beside par;
- use friendly custom tee/green pins and labelled Previous/Next controls instead of default map markers and isolated chevrons;
- solid white bottom sheet for par, tee and distances;
- forest `Play this course`;
- interruptible fly-to-hole transition.

### Active round

- the licensed satellite map fills the central screen; do not replace it with a
  decorative fairway capsule or mock hole;
- hide the persistent navigation and tab bars during play; replace them with
  compact floating glass close/menu controls over a genuinely edge-to-edge map;
- use compact floating glass/material surfaces for the hole header, map modes
  and bottom companion controls so the map remains visible;
- translucent round controls retain enough material tint and a light outline to
  remain legible over both dark trees and bright fairways; forest actions always
  use explicit white foreground content;
- opening the hole frames its saved tee and green reference with roughly ten
  percent visual breathing room; a remote live/test position must not force the
  initial camera out to regional or world scale;
- camera framing reserves the actual companion-panel footprint plus marker and
  label clearance, so neither hole endpoint sits behind the bottom controls;
- expand the geographic tee/green bounds proportionally on every side so
  horizontal, vertical, short and long holes receive consistent framing;
- raw distances dominate;
- GPS accuracy stays high contrast;
- a manual-position marker is orange, labelled `Manual position` and paired
  with an obvious `Use GPS` action;
- manual position and manual shot-pin modes require an explicit button before
  map taps mutate round data;
- recommendation never covers raw distance;
- tapping the recommended club opens a polished active-bag sheet showing every
  club's measured carry, on-course GPS playing distance or modelled estimate
  with distinct labels;
- large separate `Log Shot` and `Record Shot`;
- completing a hole uses a compact checkered-flag control with a full
  accessibility label instead of a wide text button;
- a compact red close control sits beside the hole-complete flag and opens
  explicit save, discard and keep-playing choices;
- floating action strip may use glass;
- red reserved for penalties/destructive actions;
- animations quieter than Home/Gallery.

### Gallery

- white/mist background;
- rounded two-column video grid where width permits;
- filter chips and tracer-state badges;
- glass controls only over full-screen video;
- empty state: `Record your first shot`.

### Driving Range

- a two-column **club locker** is the primary club selector, with each compartment showing the club and its real carry state;
- optional club nicknames are primary in the locker, with the actual club name retained directly underneath;
- original vector club silhouettes and exact club-designation badges replace generic person/flag/angle symbols;
- selected locker compartments use forest green; uncalibrated clubs say `No carries recorded` until a personal estimate is possible, then show an explicit `Est.` carry;
- measured averages, low-confidence estimates and possible gapping anomalies must be visually and verbally distinct;
- bag management supports drag reordering, temporary active/inactive status and deliberate permanent deletion;
- large one-handed distance input;
- readable animated average;
- green gapping bars on white;
- typical range uses tint plus outline;
- confidence always has text;
- celebrate meaningful calibration milestones, not every hit.

### Profile

- white page with avatar, name and username;
- optional light forest wash rather than a dense dark block;
- home course, contributions and authorised Club distances;
- clear `Edit profile`;
- settings button at top right;
- no fictional metrics.

### Settings

- grouped white lists on `canvas-soft`;
- plain-language labels and visible current values;
- account/destructive actions separated;
- glass navigation bar, not glass list rows.

## 9. Profile menu

Owner Profile contains avatar, name/username, bio, broad location, home courses, contributions, Club distances, `Edit profile`, Settings and privacy preview.

Owner overflow:

- Share profile;
- Preview as community;
- Copy profile link;
- Report a problem.

Other-user overflow:

- Share profile;
- Block/unblock;
- Report.

Do not put sign-out, password or location permission inside the public-facing profile menu.

## 10. Settings structure

```text
Settings
├── Account
│   ├── Name, username and avatar
│   ├── Sign-in methods, email and password
│   └── Export or delete account
├── Golf preferences
│   ├── Units and handedness
│   ├── Active bag and default tee
│   ├── Default round format
│   └── Assistant/rules-compliant default
├── Location and maps
│   ├── Permission status and precise-location explanation
│   ├── Offline courses
│   ├── Map/satellite preference
│   └── Low-battery GPS mode
├── Camera and Gallery
│   ├── Permission status and framing
│   ├── Video quality and tracer defaults
│   ├── On-device/cloud refinement and retention
│   └── Storage management
├── Privacy and community
│   ├── Profile/discoverability
│   ├── Club-distance/home-course visibility
│   ├── Blocked accounts
│   └── Reports
├── Appearance and accessibility
│   ├── System/light/dark
│   ├── Text-size shortcut
│   ├── Haptics and animation
│   └── High-contrast map
├── Notifications
├── Help and legal
│   ├── GPS/recommendation limitations
│   ├── Rules, privacy, terms and map attribution
│   └── Open-source licences
└── About
    ├── Version/build and What's new
    └── Send feedback
```

OS permission rows explain why, then deep-link to system settings. Never show a toggle the app cannot control.

## 11. Component library

Build documented primitives before screens:

- screen/navigation/tab shell;
- active-round accessory;
- primary, secondary, destructive and icon buttons;
- cards, course cards and metric cards;
- chips and status badges;
- settings row and profile header;
- permission primer and inline notice;
- bottom sheet and dialogs;
- map controls and distance readout;
- shot action bar;
- Gallery tile/video controls;
- club-distance row;
- skeleton, empty state and toast.

Every component defines pressed, focused, disabled, loading and error states; light/dark/high-contrast behaviour; Dynamic Type; VoiceOver/TalkBack; reduced-motion/transparency; and haptic policy.

## 12. Motion

Motion is soft, buoyant and responsive, without delaying play.

| Motion | Duration |
|---|---:|
| Press response | 80–140 ms |
| Selection | 160–220 ms |
| Card/sheet | 220–320 ms |
| Navigation | Platform native |
| Map fly-to-hole | 450–750 ms, interruptible |
| Success acknowledgement | 500–900 ms total |

Signature interactions:

- primary button compresses slightly;
- selected tab uses a restrained native symbol effect;
- native glass selection flows between tabs;
- course card expands toward preview map where practical;
- `Log Shot` morphs into `Finish Shot`;
- saved map point pulses once;
- changed average digits roll/crossfade;
- gapping bars animate from prior value;
- Gallery placeholder resolves into video;
- tracer-ready state draws one final short segment;
- sync uses a small check, not confetti.
- app launch hands off from the matching mist system launch screen to a short logo/wordmark reveal and compact indeterminate ring; it must not hold the usable app for a long or network-dependent delay.

Haptics:

- light for tabs/chips;
- medium for GPS shot start/finish;
- stronger notification for camera start/stop and penalty confirmation;
- success for round completion;
- optional and system-respecting.

Reduced Motion replaces morphs/zooms with fades, removes parallax/overshoot and avoids animated blur. No animation is required to understand state.

## 13. Performance

- Prefer transform/opacity animation.
- Keep interactive map camera state inside the map component so pinch/pan updates do not invalidate the complete course-creation wizard.
- Prefer stable 2D satellite point placement unless profiled elevation/3D presentation adds a clear user benefit.
- Avoid animating large satellite layers unnecessarily.
- Pause decoration during background/camera use.
- Limit custom glass containers.
- Profile on lower supported devices.
- Never let a dropped frame obscure shot confirmation.
- Avoid looping animation during an active round.

## 14. Voice

Friendly and direct:

- `Ready for the first?`
- `Your round is safe on this phone.`
- `GPS is still settling — accuracy is about ±12 m.`
- `Original video saved. The trace needs a quick adjustment.`
- `That nearby +1 drop is for casual rounds only.`

Avoid fake certainty, scolding, unexplained acronyms, class-coded jargon and celebration after a penalty.

## 15. Accessibility/outdoor validation

- Validate contrast on every glass background.
- Support accessibility Dynamic Type sizes.
- Minimum 44-point targets and larger round controls.
- Screen-reader order follows visual order.
- Reduced Transparency provides solid high-contrast navigation.
- Increased Contrast strengthens text/separators.
- Maps use outlines/patterns/symbols, not colour alone.
- Test in sunlight, with sunglasses, one-handed and on wet screens.
- Avoid rapid flashing tracer effects.

## 16. Architecture

Use semantic typed tokens:

```text
color.canvas
color.surface
color.brand.primary
color.text.primary
color.semantic.warning
radius.card
space.screen
type.title
type.distance
motion.fast
material.navigation
```

- shared token source;
- SwiftUI/Android/web material adapters;
- component preview/Storybook equivalent;
- screenshot/golden tests;
- fixtures for light, dark, high contrast and large type;
- no glass image assets;
- no unnecessary platform fork when an adapter works.

## 17. Delivery

1. Tokens, font licence, theme modes, components and native/fallback navigation.
2. Five-tab shell, Home, Profile, Settings, onboarding and permission primers.
3. Course preview, active round, shot controls, Driving Range and Gallery.
4. Connected transitions, haptics, offline/error states, accessibility, sunlight tests and performance profiling.

## 18. Acceptance criteria

- White/soft white dominates content.
- Deep friendly green is the primary accent.
- Nunito Sans or safe rounded fallback is used.
- Main navigation is Home, Play, Gallery, Range and Profile.
- Settings opens from Profile.
- Profile and Settings have distinct purposes.
- iOS uses native Liquid Glass where supported.
- Glass remains in navigation/control layers.
- Other platforms and older iOS have coherent fallbacks.
- Components support dark, high-contrast and large-text modes.
- Motion communicates state and respects Reduce Motion.
- Active-round screens have no decorative loops.
- Outdoor distance/action readability is validated.

## 19. Primary sources

- [Apple HIG: Materials and Liquid Glass](https://developer.apple.com/design/human-interface-guidelines/materials)
- [Apple: Applying Liquid Glass to custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
- [Apple HIG: Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)
- [Apple HIG: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Apple WWDC: Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/)
