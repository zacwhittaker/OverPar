# UI Craft Standard

Use this document as a mandatory preflight before planning, implementing, reviewing, or approving interface work.

The objective is not to make an interface look “designed.” The objective is to make it feel intentional, specific to its product, trustworthy, and polished at real device scale.

## 1. Redesign composition, not decoration

Changing colours, fonts, radii, shadows, and gradients is a reskin when the original layout remains intact.

Before changing code, define:

- the screen’s focal point;
- the intended reading order;
- the primary action;
- which content creates emotion or product identity;
- where high information density is useful;
- which information should recede;
- what can be removed rather than restyled.

If the same large blocks remain in the same order, the redesign is unfinished.

## 2. Give each screen a spatial grammar

Do not build every destination from the same stack of cards. Choose a composition that belongs to its content:

- photography can become the canvas;
- maps and video can run edge to edge;
- analytics can centre on a plot or trend;
- collections can use editorial rows and separators;
- metrics can share a baseline without separate boxes;
- selectors can become rails, lockers, timelines, or native lists;
- scorecards should resemble scorecards;
- settings should use familiar platform conventions.

A design system creates family resemblance through colour, typography, spacing, motion, and interaction. It should not make every screen structurally identical.

## 3. Avoid the AI panel-layout signature

Common generative-interface shortcuts include:

- repeated equal rounded rectangles;
- four identical statistic tiles;
- two-column grids for unrelated content;
- rounded containers around every row;
- nested cards;
- decorative charts boxed inside generic surfaces;
- equal visual weight for everything;
- random gradients and excessive glow;
- giant headings followed by empty space;
- template hero sections with generic copy.

Structure should be felt before it is seen. Not every element has earned equal attention.

## 4. Premium means controlled density

Premium does not mean making everything large, sparse, translucent, or rounded.

Premium interfaces usually combine:

- one confident focal element;
- compact headers;
- useful first-viewport content;
- deliberate imagery;
- strong alignment;
- restrained surfaces;
- quiet secondary information;
- purposeful density;
- one obvious action per region;
- generous but not wasteful spacing.

Empty space is valuable only when it improves focus, rhythm, or comprehension.

## 5. Diagnose the exact defect

Describe the visible problem precisely before changing code.

These are different failure modes:

- incorrect size;
- incorrect position;
- insufficient internal padding;
- insufficient external margin;
- weak contrast;
- poor hierarchy;
- bad alignment;
- clipping;
- text wrapping;
- inadequate hit area;
- incorrect optical balance.

For example, “the button is too large” is not an acceptable diagnosis when the real problem is “the label and trailing icon sit too close to the button’s edges.”

Fix the defect that exists, not a nearby one.

## 6. Review outer and inner spacing separately

Always inspect:

- screen edge to container;
- container edge to control;
- control edge to label and icon;
- label-to-icon spacing;
- vertical rhythm between regions;
- optical centring;
- minimum touch-target size.

A control can have correct external margins and still feel cramped internally. Full-width labels with spacers and trailing icons require explicit content insets.

Use a consistent spacing grid, but allow optical corrections where mathematical spacing looks wrong.

## 7. Let product-specific content lead

The interface should be recognisable even with the logo removed.

Use domain-specific materials as primary structure:

- real photography;
- maps;
- timelines;
- charts;
- diagrams;
- media;
- activity;
- native content models.

Do not use generic illustrations, abstract blobs, decorative dashboards, or stock gradients when real product content can establish identity.

Crop imagery deliberately. Protect text from busy regions and use overlays only where needed for legibility.

## 8. Preserve truth

Never invent data merely to make a screen look complete.

Use:

- real stored values;
- clearly identified development fixtures;
- honest empty states;
- loading and unavailable states;
- composition and imagery to maintain quality when data is sparse.

Keep measured, inferred, estimated, and visualised information distinct. Polish must never disguise uncertainty.

## 9. Use familiar domain notation

Do not transform established labels or symbols merely for decoration.

Users should not have to relearn familiar notation because a lowercase letter, unusual abbreviation, or novel icon looks more stylish. Domain conventions are part of the product’s usability and credibility.

Consistency applies across:

- capitalization;
- units;
- abbreviations;
- icon metaphors;
- number formatting;
- status language;
- control placement.

## 10. Use glass and effects with restraint

Translucency works best for functional layers above content:

- navigation;
- floating controls;
- media controls;
- compact toolbars;
- transient overlays.

Avoid glass on ordinary reading surfaces, forms, warnings, and every content card. Effects should clarify layering, not become the visual identity.

Use subtle shadows, borders, and gradients only when they communicate elevation, selection, or atmosphere.

## 11. Motion explains change

Motion should communicate:

- navigation;
- selection;
- saving;
- progress;
- state transitions;
- spatial relationships.

Good motion is responsive, interruptible, and quiet. Avoid decorative looping animation, excessive spring, or transitions that delay the user.

Respect reduced-motion and reduced-transparency settings. No information should depend on animation.

## 12. Design for real conditions

Validate:

- light and dark appearance;
- high contrast;
- large text;
- screen readers;
- reduced motion;
- reduced transparency;
- one-handed reach;
- outdoor visibility where relevant;
- long names and localisation;
- empty, loading, error, and populated states;
- small and large supported devices.

Minimum touch targets and readable contrast are design requirements, not post-build accessibility fixes.

## 13. Judge screenshots, not intentions

A clean component library and successful build can still produce a weak interface.

For every materially changed screen:

1. Build the real application.
2. Render it on a target device.
3. Use honest representative data.
4. Capture a screenshot.
5. Inspect hierarchy, spacing, cropping, wrapping, and control geometry.
6. Compare it directly with the approved reference or design goal.
7. Fix visible defects.
8. Capture fresh proof.

Do not approve a design by reading modifiers or inspecting a design-system file.

## 14. Reference review

When studying another product, do not copy its cards. Identify its underlying decision:

- Flighty mirrors trusted real-world travel conventions.
- Apple Weather makes the environment the canvas.
- Apple Fitness gives one recognisable visual model priority.
- Gentler Streak builds identity through humane tone and guidance.
- CARROT reveals only contextually useful modules.
- Arc Search minimises chrome and defers to the task.
- Linear allows structure to recede and attention to remain earned.

Transfer the principle, not the screenshot.

## 15. Approval checklist

Before presenting work, ask:

- Is the focal point obvious?
- Is the reading order intentional?
- Is the first viewport useful?
- Does the composition belong to this product?
- Are controls comfortable internally and externally?
- Are icons optically consistent?
- Is any region unnecessarily boxed?
- Is there unexplained empty space?
- Is every displayed value honest?
- Does typography preserve established notation?
- Are loading, empty, and error states deliberate?
- Does the interface survive dark mode and large text?
- Would the screenshot itself support the claim that this is a professionally funded product?

If any answer is no, continue iterating.

## 16. Review communication

- Lead with what is visible.
- Distinguish a redesign from a reskin.
- Name the exact defect.
- Do not claim comprehensive completion from a partial pass.
- When feedback identifies a problem, fix it and show a fresh rendered result.
- Treat the running product—not the implementation description—as proof.
