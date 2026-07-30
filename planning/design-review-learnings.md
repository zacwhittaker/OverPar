# OverPar design review learnings

**Status:** Mandatory design-task preflight
**Purpose:** Preserve concrete visual-quality lessons from implementation reviews so future agents do not repeat them.

Read this document completely before planning or implementing any OverPar interface, motion, layout, branding, onboarding, screenshot or visual-polish task.

## 1. A redesign must change composition, not merely tokens

Changing colours, corner radii, shadows and typography does not constitute a complete redesign when screen structure remains unchanged.

Before editing:

- identify the screen's focal point;
- decide the intended reading order;
- decide which content creates emotion;
- remove generic repeated card stacks;
- determine where information density is useful;
- distinguish primary, secondary and supporting regions;
- compare the new composition—not only its styling—with the old screen.

If a screenshot still has the same large blocks in the same order, the redesign is incomplete.

## 2. Judge screenshots, not implementation intent

A compiling token system can still produce a weak interface. Review the rendered simulator result at actual device scale.

For every materially redesigned screen:

1. Build the real application.
2. Populate only honest representative states.
3. Capture the target device.
4. Inspect hierarchy, spacing, cropping and control geometry visually.
5. Compare it directly with the approved reference.
6. Iterate before describing the work as complete.

Do not infer that padding or alignment is correct merely because the SwiftUI modifiers appear reasonable.

## 3. Inspect both outer and inner spacing

Container margins and content padding are different.

A control may be correctly inset from its parent while its label and icon remain uncomfortably close to the control's own edges. Review:

- distance from screen edge to container;
- distance from container edge to control;
- distance from control edge to label and icons;
- spacing between label, spacer and trailing icon;
- optical rather than merely mathematical centring.

Primary buttons with full-width `HStack` labels require explicit horizontal content padding. OverPar's shared primary button uses a minimum 20-point internal horizontal inset.

## 4. Diagnose the exact visual problem

When reviewing feedback, describe the visible defect precisely before changing code.

Do not substitute a nearby critique such as “the button is too large” when the actual issue is “the content is too close to the button edge.” Check:

- size;
- position;
- internal padding;
- external margin;
- contrast;
- hierarchy;
- alignment;
- clipping;
- text wrapping;
- hit area.

These are separate failure modes and require different fixes.

## 5. Photography should lead rather than decorate

The approved direction uses golf photography to establish place, emotion and product specificity.

- Use strong course imagery as a focal layer.
- Crop deliberately for each surface.
- Add overlays only as needed for legibility.
- Keep text away from visually busy areas.
- Do not replace photography with generic vector blobs when the experience calls for golf atmosphere.
- Do not let imagery become a template-style hero with unrelated marketing copy.

Project imagery must be original or appropriately licensed and stored in the asset catalogue.

## 6. Premium means controlled density

Premium is not equivalent to large text and empty space.

The approved reference feels premium because it combines:

- compact headers;
- strong photography;
- clear sections;
- restrained card sizes;
- useful information density;
- consistent alignment;
- quiet secondary text;
- one obvious action per region.

Avoid oversized greetings, giant headings that consume the first viewport, and sparse screens whose content ends far above the tab bar.

## 7. Preserve product truth

Visual references may contain data that OverPar does not yet own. Never invent handicap, weather, achievements, ratings, scores or activity merely to make a screenshot look complete.

Use:

- real stored data;
- clearly identified previews or fixtures used only for development;
- honest empty states;
- photography and composition to retain visual quality when data is absent.

Measured, modelled and visualised values remain distinct.

## 8. Reference fidelity checklist

Before presenting screenshots, ask:

- Is the visual hierarchy recognisably closer to the approved reference?
- Is the first viewport useful and emotionally engaging?
- Are controls comfortably padded internally and externally?
- Does every icon have consistent optical size?
- Do photographs crop cleanly?
- Are headings compact enough to leave room for content?
- Are cards varied by purpose rather than generic containers?
- Is there unexplained empty space?
- Is every displayed value real or clearly labelled?
- Does the screen work in light, dark and large text?
- Would the screenshot—not the implementation description—support the claim that this is a funded-startup-quality product?

If any answer is no, continue iterating.

## 9. Review communication

- Lead with what is visible in the screenshot.
- Admit when a redesign is only a reskin.
- Do not claim comprehensive completion from a partial pass.
- When the user identifies a defect, confirm the exact issue and show a fresh rendered screenshot after fixing it.
- Proof is the running app, not a description of changed modifiers.

## 10. Avoid the AI panel-layout signature

Repeated equal rounded rectangles are a common generative-UI shortcut. They make unrelated content look interchangeable and flatten the product's hierarchy.

Do not default to:

- four identical statistic tiles;
- a two-column grid for every collection;
- a rounded container around every list row;
- nested cards;
- equal-radius panels regardless of purpose;
- decorative charts boxed inside generic surfaces;
- a `VStack` of independent widgets with no continuous reading flow.

Instead choose a composition native to the content:

- photography can become the canvas;
- maps and video can run edge to edge;
- course collections can use editorial thumbnail rows and hairline separators;
- club selection can use a horizontal rail;
- metrics can share a baseline without individual boxes;
- a chart can live directly in the page with its legend and current value;
- a scorecard can look like a scorecard;
- settings can remain a native grouped list;
- one feature surface may anchor a screen while supporting content recedes.

The ten-reference review completed on 30 July 2026 reinforced:

- Flighty: mirror a trusted real-world information convention and change emphasis with context.
- Apple Weather: make the environmental canvas primary and reveal detail progressively.
- Apple Fitness: give one recognizable visual model priority, then support it with direct-on-page trends.
- Gentler Streak: use tone, illustration and humane guidance as identity rather than ornamental cards.
- CARROT Weather: show only contextually useful modules and let detail live one tap deeper.
- Arc Search: minimise chrome and defer to the user's content and immediate task.
- Linear: not every element earns equal weight; structure should be felt rather than seen.
- Arccos: let golf-specific dispersion and distance visualisations drive club analytics.
- Golfshot: use the course map as the on-course workspace instead of surrounding it with dashboard chrome.
- Hole19/TheGrint: optimise on-course information for fast scanning, but avoid importing their feature density wholesale.

For OverPar, this means each top-level destination needs a distinct spatial grammar. A shared token system creates family resemblance; repeated card templates do not.
