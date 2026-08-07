# Direct-Start LPC Creator and Animator
## Research-Hardened Production Implementation Plan

**Document status:** Authoritative LPC-specific implementation plan  
**Repository:** `DocDamage/2d-character-creator-and-animator`  
**Target engine:** Godot 4.7.1 desktop application  
**Primary platform:** Windows desktop; architecture must remain portable  
**Research baseline date:** 2026-08-07  
**Supersedes:** the repository copy of `DIRECT_START_LPC_CREATOR_PLAN.md` and the earlier phased-risk revision  
**Relationship to master plan:** This is the LPC product profile and production acceptance plan for `MODULAR_2D_CHARACTER_ANIMATION_STUDIO_MASTER_PLAN.md`. It does not replace the general studio architecture.

---

# 1. Executive Decision

Animating and deforming LPC artwork is a committed product capability. It is no longer treated as a single high-risk feature that may be abandoned after a feasibility spike.

The earlier plan bundled three materially different problems under the word **deformation**:

1. Playing and editing the existing frame animations already present in LPC sheets.
2. Warping one existing raster frame or layer without introducing filtered colors.
3. Creating genuinely new poses and motion from artwork that was originally painted as flattened animation frames.

Those problems require different representations and tools. The product will therefore use three interoperable authoring modes:

| Mode | Authoritative source | Best use | Guaranteed fallback |
| --- | --- | --- | --- |
| **Native Frame** | Original LPC sheet frames and project-owned cel overrides | Existing LPC animation cycles, image swaps, timing edits, pixel edits | Always available for every valid imported frame |
| **Frame Warp** | A mesh bound to one source frame or a validated topology group | Squash/stretch, hit reactions, local corrections, controlled per-frame deformation | Return to the untouched source frame or bake a project-owned cel |
| **Rigged Cutout** | Project-owned semantic pieces, pivots, bones, slots, optional meshes and weights | New poses, new directional animation, weapon posing, reusable skeletal motion | Keep unsupported layers on Native Frame tracks or replace them with custom cels |

A character, clip, and even a single composite frame may combine all three modes. No selected LPC asset reaches a dead end:

- Existing animation can play as native frames.
- Small changes can use frame-local warp.
- Large pose changes can use **Prepare for Rig**.
- Assets that are unsuitable for rigging remain frame-driven and can be edited as custom cels.

The product will not claim that a flattened pixel-art frame can be bent into arbitrary new poses without tradeoffs. Instead, it will provide the correct conversion path whenever deformation exceeds what a frame warp can preserve.

---

# 2. Research Findings That Change the Plan

## 2.1 Findings in the current repository

The current repository contains useful foundations, but its generic mesh/deformation milestone is not production evidence for LPC deformation.

### Existing code that can be reused

- `export/review/character_raster_renderer.gd` is a real deterministic CPU image compositor for transformed raster layers.
- Image-sequence and sprite-sheet exporters already accept real `Image` frames and write actual artifacts.
- The project has versioned persistence, command history, autosave/recovery, animation schemas, rigging schemas, constraints, and export infrastructure.
- The compatibility renderer and nearest texture defaults are appropriate for LPC authoring.

### Existing code that must be corrected or extended

- `deformation/solvers/deformation_baker.gd` copies deformed vertex coordinates into another mesh. It does not rasterize a deformed image and therefore is not an LPC Bake implementation.
- `deformation/meshes/auto_mesh_generator.gd` creates a rectangular grid over the full frame and contains a custom unconstrained Delaunay helper. It does not follow alpha contours, preserve holes, split disconnected islands, or prove coverage of visible pixels.
- `deformation/handles/grid_cage_deformation.gd` is a radial pin falloff solver, not a true grid cage implementation.
- `deformation/weights/bone_binder.gd` is distance-based initialization, not heat-diffusion binding.
- `deformation/weights/weight_painter.gd` does not perform topology-neighbor smoothing in its Smooth mode.
- `deformation/solvers/deformation_validator.gd` checks basic indices, weights, UV bounds, and zero-area triangles, but not flipped triangles, self-intersection, shared-edge cracks, alpha coverage, stretch, palette preservation, or deterministic raster output.
- `tests/unit/test_mesh_deformation.gd` proves helper calculations and coordinate changes. It does not render LPC-shaped fixtures, save PNGs, compare visual goldens, reopen projects, or prove preview/export parity.
- The generic rig template is not tied to LPC body families, directions, source frames, masks, overlap zones, or layer-order rules.
- Global project settings do not enable 2D transform or vertex snapping. Strict LPC behavior must be enforced by the LPC workspace and baker rather than assumed from global settings.

Historical generic `MSH-*` and `DEF-*` tasks may remain recorded as prototype work, but they cannot satisfy any new `REQ-LPC-*` requirement without fresh LPC-specific implementation and verification.

## 2.2 Findings from the upstream Universal LPC generator

The upstream project is not one uniform sheet format.

- Standard LPC frames are normally 64×64 pixels and the standard sheet uses 13 frame columns.
- Standard direction order is up, left, down, right.
- Animation row locations and playback cycles differ by animation.
- ULPC, LPCR, LPCE, oversize weapons, and custom animations can use additional rows, different cycles, different source mappings, and different frame sizes.
- An asset may declare only a subset of animations. If the declaration is absent, upstream applies a defined default subset; it does not mean every expanded animation exists.
- One logical selection may contain multiple visual layers with separate `zPos` values, such as foreground and background portions of a tail.
- Upstream JSON export includes selected body type, per-layer item IDs, variants, recolors, layer numbers, z positions, source paths, supported animations, and credits.
- Assets may be multi-licensed. License choices and obligations must be handled per credited source, not reduced to a misleading single commercial/noncommercial boolean.
- LPC Expanded includes more body types and animations, but coverage is incomplete. Compatibility must be calculated, not assumed.

Therefore, Paper Quest must import a pinned, versioned LPC data model rather than infer layout from PNG dimensions or hard-code one sheet arrangement.

## 2.3 Findings from Godot’s 2D deformation model

Godot has the engine capabilities required for this product:

- `Polygon2D` supports explicit vertices, UVs, polygon topology, internal vertices, skeleton binding, bones, and weights.
- `Skeleton2D` and `Bone2D` support 2D skeletal deformation.
- `CanvasItem` supports per-item texture filtering and custom mesh drawing.
- `Geometry2D` provides polygon operations, Delaunay triangulation, polygon triangulation, intersection checks, and pixel-grid line helpers.
- `Image` provides CPU pixel access for deterministic reference rendering and PNG output.

Godot’s own 2D skeleton guidance warns that automatically generated internal triangles can bend unexpectedly. Explicit topology and internal control vertices are required around regions that bend. This confirms that a generic full-frame rectangle mesh is not an acceptable production rigging strategy.

## 2.4 Reference rasterization result

A small reference implementation was exercised against a synthetic indexed-color sprite and a two-triangle warped quad. The implementation:

- evaluated destination pixel centers;
- used deterministic triangle ownership on shared edges;
- inverse-mapped each covered destination pixel through barycentric coordinates;
- nearest-sampled the source texel;
- produced no uncovered pixels inside the destination polygon; and
- produced an output RGBA set that was a subset of the source RGBA set.

This establishes the technical basis for a deterministic palette-preserving frame baker. Production implementation still requires Godot fixtures, performance evidence, malformed-input handling, and cross-platform repeatability tests.

---

# 3. Product Outcome

Opening Paper Quest must immediately do one of the following:

1. Resume the most recent editable LPC character at the last workspace and playhead.
2. Present a focused pack and base-family chooser when no resumable LPC project exists.
3. Open a non-LPC project through the existing Advanced Studio path without requiring the LPC library.

The complete LPC workflow must support:

```text
Choose a validated LPC source pack
→ choose a compatible body family
→ assemble body/features/clothing/equipment
→ preview every supported native animation and direction
→ inspect missing-animation conflicts before authoring
→ edit pixels or create replacement cels
→ retime, reorder, and combine frame and transform tracks
→ apply strict frame-local deformation where appropriate
→ prepare selected artwork as a rigged cutout for new poses
→ author rigid or weighted skeletal animation
→ add or author missing directions, including diagonal directions when required
→ save, close, reopen, and continue without data loss
→ export baked frames, sprite sheets, review packages, or editable Godot runtime data
→ receive exact credits, license choices, derivative ancestry, and validation results
```

The upstream LPC source remains outside Git. Tracked repository fixtures must be synthetic or separately verified as redistributable.

---

# 4. Non-Negotiable Product Truths

## 4.1 No universal-deformation fiction

- A full LPC sheet is a collection of independently painted frames, not one continuous deformable model.
- A mesh is never silently reused across frames with different geometry, masks, dimensions, or topology signatures.
- Large pose changes require rig-ready cutout pieces or new cels because hidden pixels do not exist in a flattened source frame.
- Unsupported layers remain valid frame tracks instead of blocking the entire character.

## 4.2 No false pixel-safety claim

The phrase **pixel-safe deformation** is too vague. The UI and documentation must use explicit modes:

1. **Strict LPC Raster** — nearest source sampling, deterministic coverage, no antialiasing, exact palette lookup, and authoritative CPU verification.
2. **Stepped Pixel Motion** — strict raster plus integer-quantized evaluated transforms or vertices at each exported frame.
3. **Smooth Art** — subpixel motion and optional linear sampling; clearly labeled as capable of introducing intermediate colors.

Strict rasterization preserves source RGBA choices per sampled texel. It does not promise that the spatial arrangement of pixels remains unchanged; warping necessarily duplicates, omits, or relocates texels. The editor must show stretch and sampling diagnostics rather than hide that fact.

## 4.3 No coordinate-only Bake

**Bake** means producing and validating a real raster derivative or a complete editable runtime artifact. Copying vertex positions into another mesh is a pose snapshot, not a bake.

## 4.4 No inferred compatibility from filenames or dimensions

Compatibility must come from versioned catalog records and explicit layout adapters. PNG dimensions alone are insufficient.

## 4.5 No source mutation

Bundled or local-source LPC art is immutable. Every edit, cutout, patch, cel, mesh, rig adapter override, or bake is project-owned and retains provenance.

## 4.6 No historical status substitution

A generic task previously marked completed does not satisfy an LPC requirement unless the new requirement’s actual artifacts, persistence, rendering, and clean-consumer behavior are independently verified.

---

# 5. LPC Source Lock and Catalog Architecture

## 5.1 Reproducible source lock

Create `lpc_source.lock.json` with:

- upstream repository URL;
- exact upstream commit SHA;
- catalog-adapter version;
- accepted source tree paths;
- expected root hashes;
- palette/layout policy versions;
- license-policy version;
- build timestamp and tool version; and
- a deterministic catalog signature.

Updating upstream LPC data is an explicit operation. It produces a report of:

- added, removed, renamed, aliased, or changed assets;
- source hash changes;
- dimension or layout changes;
- animation-support changes;
- palette changes;
- credit or license changes; and
- projects that would require migration or source rebinding.

No library silently updates when the application launches.

## 5.2 Canonical source inputs

The catalog builder reads pinned upstream source data:

- `sheet_definitions/**/*.json`;
- `palette_definitions/**/*.json`;
- required animation/layout adapter data;
- `CREDITS.csv` and per-definition credit records;
- sprite PNGs;
- aliases; and
- any approved oversize/custom animation definitions.

Generated upstream JavaScript modules are not the sole canonical dependency because they are build outputs and may be absent. Paper Quest produces its own versioned Godot-friendly catalog from upstream source records.

## 5.3 `LpcAssetRecord`

Every asset or credited source component records at least:

- stable Paper Quest asset ID;
- upstream item ID and type name;
- upstream aliases;
- source-relative path;
- source SHA-256;
- image width, height, format, and alpha statistics;
- body-family support;
- layer group and layer number;
- default and override z-order data;
- supported animation IDs;
- direction support;
- frame/layout adapter ID;
- palette/recolor material and allowed palettes;
- compatibility tags;
- credited source records;
- available license options;
- selected license option when used by a project;
- distribution-policy eligibility with a reason, not only a boolean;
- deformation capability declarations;
- rig-adapter availability;
- source-lock commit and adapter version; and
- validation status and diagnostics.

## 5.4 Staged catalog loading

Separate catalog data into independently loadable shards:

- index and aliases;
- lightweight item rows;
- layer/layout data;
- palettes;
- credits/licenses; and
- thumbnails.

The creator can show categories and cached thumbnails before full credit data is loaded, but selection, save, and export remain blocked until all records required by the active character are validated.

## 5.5 Catalog validation

Library intake fails with precise diagnostics for:

- missing files;
- unexpected hashes;
- invalid dimensions;
- unsupported image formats;
- path traversal or paths outside the source root;
- unknown body families;
- unresolved aliases;
- invalid frame rectangles;
- overlapping or out-of-bounds frame definitions;
- unknown palettes;
- missing credit records;
- no selectable license option under the active policy;
- declared animations without valid frame mappings; and
- invalid multi-layer group definitions.

A valid root manifest does not excuse an invalid individual asset.

---

# 6. License and Attribution Architecture

## 6.1 Replace “Commercial-safe” terminology

Commercial use and permissive distribution are not the same thing. The product must not label GPL or CC-BY-SA art as noncommercial. Replace the earlier pack name with explicit policy profiles:

| Policy profile | Intended use | Default rule |
| --- | --- | --- |
| **Full Source** | Users prepared to follow each selected license | Any supported and reviewed option |
| **DRM-Friendly** | Distribution where anti-DRM clauses are unacceptable | Prefer CC0 and OGA-BY according to the pinned policy review |
| **Attribution-Oriented** | Projects that permit attribution but avoid share-alike/copyleft art obligations | CC0, OGA-BY, and reviewed CC-BY options |
| **Share-Alike Allowed** | Projects that accept CC-BY-SA obligations | Adds reviewed CC-BY-SA options |
| **Custom** | Organization-specific policy | Versioned allow/deny/require rules |

These are product policies, not legal opinions. Each public release still requires human review.

## 6.2 License-choice model

An asset may provide alternative licenses. The project records the license option actually selected for each credited source. It must not incorrectly combine all alternative licenses as simultaneous obligations.

A derivative records:

- every ancestor source record;
- selected license option per ancestor;
- required authors and source URLs;
- derivative notices;
- share-alike/copyleft flags when applicable;
- platform/distribution warnings; and
- the policy version used to approve it.

Combining multiple assets creates the union of obligations from the selected options for those ancestors.

## 6.3 Policy viability tests

A release pack cannot advertise a body family or workflow unless the active policy contains a complete usable path for it. Tests must prove at least:

- one valid base body;
- required head/body components;
- a declared minimum native animation set;
- exact credits;
- exportable license choices; and
- no hidden disallowed ancestor in derived art.

---

# 7. Sheet Layout and Native Animation Model

## 7.1 `LpcSheetLayout`

Do not scatter row constants through UI or rendering code. Define versioned layout adapters containing:

- layout ID and version;
- source frame size or per-animation frame size;
- frame columns;
- animation row ranges;
- direction order;
- source frame cycles;
- repeated-frame timing;
- animation aliases;
- oversize source rectangles and offsets;
- custom animation source mappings;
- default animation-support semantics; and
- validation rules.

The initial standard adapter must faithfully encode the pinned upstream standard layout, including its 64×64 frames, 13 columns, four cardinal directions, exact rows, and exact playback cycles. Custom and oversize adapters must remain data-driven.

## 7.2 `LpcFrameRef`

Every source frame reference contains:

- source asset ID and hash;
- animation ID;
- direction ID;
- logical frame index;
- source cycle index;
- source rectangle;
- logical origin and oversize offset;
- frame duration;
- topology group ID when explicitly validated; and
- active layer-order context.

## 7.3 Native compatibility resolver

For each selected layer and requested clip, calculate:

- body-family compatibility;
- animation support;
- direction support;
- layout compatibility;
- palette compatibility;
- multi-layer group completeness;
- active policy eligibility; and
- source availability.

The character-level native-animation set is the intersection of required visible layers, not merely the body’s animation list.

When a selected layer lacks a requested animation, the editor offers explicit actions:

1. hide the layer for that clip;
2. substitute a compatible variant;
3. keep a user-authored cel override;
4. convert the layer to a rigged or custom-cel representation; or
5. cancel the clip requirement.

Nothing disappears silently.

## 7.4 Direction model

The data model supports arbitrary named direction sets. Initial native LPC support is cardinal four-direction playback.

Eight-direction output is supported through authored data:

- existing diagonal source frames when available;
- project-owned custom diagonal cels; or
- direction-specific rig conversion and animation.

The product must not present automatically rotated cardinal pixel art as authored diagonal LPC art. Mirroring is allowed only when an adapter or user explicitly approves it, and the mirrored result remains editable for asymmetric corrections.

---

# 8. Unified Render and Evaluation Pipeline

Every preview, bake, export, and runtime evaluation uses the same ordered model:

1. Resolve project, source-lock, policy, and migration state.
2. Resolve clip, playhead, direction, and source-frame selection.
3. Load the immutable source image or project-owned cel.
4. Apply exact palette lookup or project-owned pixel override.
5. Evaluate frame-local mesh offsets or rig/skinning state.
6. Evaluate layer transform, pivot, opacity, visibility, and image swap.
7. Resolve deterministic layer ordering.
8. Composite into the declared logical frame canvas.
9. Run mode-specific validation.
10. Cache or export the resulting image and its render manifest.

No exporter reimplements clip evaluation independently.

## 8.1 Two previews with clear semantics

### Interactive Preview

- Uses Canvas2D/Polygon2D or an equivalent GPU path.
- Optimized for responsive dragging and playback.
- Uses nearest filtering in Strict and Stepped modes.
- May be marked **Unverified Preview** while a deformation gesture is active.

### Verified Preview

- Displays the authoritative CPU-baked frame or an exact cached result.
- Must match exported PNG bytes for the same render snapshot.
- Refreshes on pointer release, command commit, playhead settle, explicit Verify, and export.
- Shows validation failures instead of silently falling back to the GPU image.

This removes cross-GPU edge-rasterization differences from the definition of export correctness.

## 8.2 `LpcRenderSnapshot`

A render snapshot is immutable and includes:

- project/profile/schema versions;
- source-lock signature;
- clip and playhead state;
- direction;
- selected layers and exact source hashes;
- palette maps;
- cel/mesh/rig versions;
- evaluated geometry;
- layer order;
- strictness mode;
- baker version;
- output canvas and origin; and
- expected credit/license manifest hash.

Preview and export parity is proven by rendering the same snapshot, not by reconstructing state in separate code paths.

---

# 9. Authoring Capability Model

Each layer instance has an explicit capability record. Capabilities are never inferred only from the presence of a PNG.

```text
FRAME_NATIVE
FRAME_EDITABLE
FRAME_WARPABLE
RIG_TEMPLATE_AVAILABLE
RIG_PREPARED
WEIGHTED_MESH_READY
SMOOTH_ART_ALLOWED
```

The UI displays one of these practical statuses:

- **Native**
- **Editable Cel**
- **Warpable**
- **Rig Template Available**
- **Rig Ready**
- **Needs Setup**
- **Frame Only**
- **Source Missing**
- **Blocked by Policy**

A diagnostic panel explains why a capability is unavailable and the exact action that enables it.

---

# 10. Pixel and Cel Editing

## 10.1 Project-owned derivatives

Use copy-on-first-edit with content-addressed storage. A derivative stores:

- derivative ID and current content hash;
- original source asset ID and source hash;
- source frame reference when applicable;
- all ancestor credits and selected license options;
- operation type: pixel edit, cutout, gap patch, warp bake, composite bake, palette bake, or imported replacement;
- parent derivative when chained;
- dimensions, alpha statistics, and palette audit; and
- creation tool and version.

## 10.2 Pixel editor milestones

### Pixel-canvas core

- pencil;
- eraser;
- transparent pixels;
- exact palette selection;
- native-grid zoom;
- project-owned layers and cels;
- PNG import/export;
- one command per stroke; and
- lossless save/reload.

### Production cel authoring

- fill;
- contiguous/non-contiguous selection;
- move/copy/paste;
- onion skin;
- frame timeline;
- reference layers;
- whole-character and per-layer cels;
- rig cut-mask and gap-patch editing; and
- palette/alpha audit.

Autosave records document revisions and blob references. It does not create a new PNG for every autosave.

---

# 11. Frame Warp Architecture

## 11.1 Correct scope

Frame Warp deforms one source frame/layer or an explicitly validated topology group. It is intended for controlled changes to existing art, not arbitrary pose generation.

A clip-wide warp modifier may project normalized controls onto each frame’s own mesh, but every frame retains its own source binding, UVs, topology validation, and bake result.

## 11.2 `LpcFrameMesh` schema

Replace or migrate the generic mesh schema with fields for:

- schema version;
- mesh ID and topology version;
- source asset ID and SHA-256;
- source frame reference and source rectangle;
- source image dimensions;
- alpha-mask hash and alpha threshold policy;
- rest vertices;
- UVs using one documented texel convention;
- explicit triangle indices;
- boundary edges;
- disconnected island IDs;
- hole records when supported;
- control vertices and locked vertices;
- topology group ID;
- deformation mode;
- output origin/bounds policy;
- rig binding when applicable;
- quality thresholds;
- provenance; and
- solver/baker versions.

Rest geometry is immutable. Animated offsets, cage controls, and evaluated positions are stored separately.

## 11.3 Mesh creation strategies

### Strategy A — Rectangular control grid

Use as the reliable initial implementation and fallback:

- tightly crop the frame’s nontransparent bounds;
- add configurable transparent padding;
- create a regular grid;
- preserve transparent sampling outside the visible sprite; and
- keep the alpha mask authoritative during diagnostics.

It is predictable but may contain unnecessary transparent triangles.

### Strategy B — Alpha-aware production mesh

Add after the reference baker is verified:

- detect disconnected opaque islands;
- trace alpha contours on the pixel grid;
- simplify contours within an explicit pixel tolerance;
- preserve holes;
- add internal bend/control points;
- triangulate with deterministic Godot `Geometry2D` operations or another reviewed constrained implementation;
- map all original opaque pixels to covered source regions; and
- validate every island independently.

### Strategy C — Manual topology

Users can add, move, lock, split, and remove vertices and triangles. Manual topology is required for art whose silhouette or bend regions cannot be inferred reliably.

The existing custom Delaunay helper must not remain the unverified production topology path.

## 11.4 Deformation tools

Committed tools:

- direct vertex move;
- multi-select and transform;
- normalized lattice/grid controls;
- radial pin/attractor controls;
- soft drag with a visible radius and falloff;
- locked boundary or anchor vertices;
- keyframed control/vertex offsets;
- copy deformation between compatible topology groups; and
- reset selected/all deformation.

Names must reflect implementations. A radial pin solver must not be labeled as a grid cage.

## 11.5 Geometry diagnostics

Before verified preview or export, detect:

- invalid or duplicate indices;
- degenerate triangles;
- flipped winding relative to rest geometry;
- triangle self-overlap;
- boundary self-intersection;
- UVs outside the declared source rectangle;
- uncovered required source regions;
- shared-edge cracks in raster coverage;
- excessive area ratio;
- excessive edge stretch or compression;
- destination bounds overflow;
- transparent intrusion into required opaque regions; and
- topology/source-mask mismatch.

Warnings may allow user-approved export only where policy permits. Foldovers, invalid source references, and nondeterministic strict output are hard failures.

---

# 12. Deterministic Strict Raster Baker

## 12.1 Required implementation

Add a real `PixelRasterBaker` or equivalently named service. Extend the existing CPU compositor rather than replacing it with another disconnected export path.

For each destination triangle:

1. Compute deterministic integer destination bounds.
2. Evaluate destination pixel centers.
3. Apply one documented shared-edge ownership rule, such as the top-left rule.
4. Calculate barycentric coordinates in destination space.
5. Map to source texel-space UV coordinates.
6. Nearest-sample the source image using one documented clamp/floor convention.
7. Write the exact sampled RGBA value.
8. Composite layers using the selected strictness rules.

The reference implementation is the correctness oracle. A later GDExtension/C++ optimization must produce the same verified hashes on the fixture suite.

## 12.2 Strict LPC Raster invariants

Per deformed layer:

- no linear filtering;
- no antialiasing;
- no mipmapping;
- no implicit palette re-quantization;
- sampled RGBA values must come from the post-palette source image;
- no partial alpha values may be introduced; and
- output must be deterministic for the same render snapshot.

For an entire composite to claim **exact palette preservation**:

- source layers must satisfy the declared alpha policy;
- opacity must be 1.0;
- tint/modulate must be neutral;
- blend mode must be an approved exact mode; and
- palette replacement must be a direct lookup.

If partial alpha, tint, opacity, or a non-exact blend is active, the UI labels the result **Strict Geometry / Expanded Composite Colors** instead of making a false palette claim.

## 12.3 Stepped Pixel Motion

For rig or mesh animation intended to look like authored pixel motion:

- sample the clip at export frame times;
- quantize configured transforms, pivots, and/or vertex positions to integer units;
- use stepped or explicitly selected interpolation;
- run the strict baker; and
- allow per-key exceptions where the artist approves subpixel geometry before rasterization.

## 12.4 Smooth Art mode

Smooth mode is separate and explicit:

- permits subpixel interpolation;
- may use linear filtering;
- may introduce intermediate colors and partial alpha;
- carries its own visual goldens; and
- is never substituted for Strict or Stepped export.

## 12.5 Bake artifact

Every bake produces:

- actual output image(s);
- output SHA-256;
- render-snapshot hash;
- source and derivative ancestry;
- geometry diagnostics;
- color/alpha audit;
- baker version;
- timing and performance metrics;
- credits/license manifest hash; and
- any approved warnings.

---

# 13. Rigged Cutout Conversion

## 13.1 Why conversion is required

A flattened LPC frame usually lacks hidden pixels behind overlapping limbs, clothing, hair, and equipment. New skeletal poses expose those missing regions. Therefore, new-pose animation uses project-owned semantic cutout pieces with overlap repairs rather than pretending a full flattened frame is already a reusable rig.

## 13.2 `LpcRigAdapter`

A versioned adapter contains:

- adapter ID/version;
- body family and age/body tags;
- direction ID;
- reference animation and frame;
- expected source layout and frame rectangle;
- bone hierarchy and rest pose;
- semantic piece definitions;
- source masks/cut lines;
- pivots and attachment slots;
- front/middle/back z groups;
- permitted layer-order overrides;
- overlap padding and gap-patch regions;
- clothing/armor transfer mapping;
- hand, weapon, and tool anchors;
- tail/wing/hair chain definitions when applicable;
- mirror policy;
- compatible source hashes or mask signatures; and
- validation fixtures.

Cardinal directions use separate adapters because the visible anatomy and occlusion differ. A single generic front-facing humanoid rig is not silently rotated to represent all directions.

## 13.3 Prepare for Rig wizard

The wizard must:

1. Choose the target body family, direction, and reference frame.
2. Find compatible adapters using explicit catalog metadata and source signatures.
3. Preview cut masks, pivots, bones, z groups, and expected hidden regions.
4. Create project-owned pieces without changing source assets.
5. Detect missing coverage and open gap-patch regions in the pixel editor.
6. Let the user adjust masks, pieces, pivots, and anchors.
7. Validate every piece and attachment.
8. Save the adapter instance, derivative ancestry, and exact source hashes.
9. Produce a reversible command macro.
10. Keep original native frames as fallback/reference.

When no adapter exists, the same wizard enters guided manual setup rather than ending the workflow.

## 13.4 Layer strategies after rig preparation

Each selected visual layer chooses one strategy per direction/clip:

- **Rigid attachment** — hats, held items, simple accessories.
- **Shared topology/weight transfer** — compatible shirts, pants, armor, or body-following layers.
- **Dedicated mesh and weights** — hair, capes, tails, wings, or unusual silhouettes.
- **Frame swap** — complex layer remains on native or custom cels.
- **Hidden for clip** — explicit user choice.

Weight transfer uses shared adapter topology or barycentric mapping from a validated body mesh. It does not independently auto-bind every clothing layer using only inverse distance to bones.

## 13.5 Rigid animation before weighted deformation

The first rigged-cutout milestone uses rigid pieces and pivots. This immediately enables new poses, IK, hand/weapon alignment, and direction-specific motion without requiring every layer to bend.

Weighted meshes are added only after rigid cutout export, save/reopen, and clean-runtime playback are verified. This sequencing reduces hidden-pixel and topology failures without removing the committed weighted-deformation capability.

---

# 14. Weighted Skinning, Cages, and Advanced Deformation

## 14.1 Weight data

A weighted vertex records stable bone IDs and normalized influences. Validation enforces:

- valid referenced bones;
- configurable maximum influences;
- nonnegative finite weights;
- normalized sums within tolerance;
- explicit unweighted-vertex policy; and
- deterministic serialization.

## 14.2 Automatic initialization

Provide separate named initializers:

- nearest-bone rigid assignment;
- distance-to-segment weighting;
- adapter/shared-topology weight transfer; and
- optional heat/diffusion binding only after a real diffusion implementation exists.

The UI must not label distance weighting as heat binding.

## 14.3 Weight painting

Committed brush modes:

- Add;
- Subtract;
- Replace;
- Normalize;
- Rigid assign;
- Blur/Smooth using actual mesh-neighbor adjacency; and
- Mirror where adapter symmetry is declared.

Every stroke is one atomic command. The inspector shows exact influences for selected vertices.

## 14.4 Cage and soft-drag tools

- A true cage stores ordered cage geometry and a documented coordinate/interpolation model.
- Radial pins remain a separate tool.
- Soft drag operates on rest/evaluated state without destructively accumulating hidden errors.
- Fold prevention, locked anchors, and deformation quality limits remain active.
- Cage, pin, soft-drag, bone, and direct-vertex offsets have an explicit evaluation order.

## 14.5 Post-composite deformation

Whole-character effects are supported by explicitly creating a project-owned flattened composite cel and deforming that derivative. The UI explains that:

- source layers remain preserved in the project;
- the flattened cel has combined ancestry and credits;
- independent layer editing does not affect the already baked derivative until it is regenerated; and
- the effect can be reverted to the layered source.

A post-composite mesh is never silently substituted for per-layer authoring.

---

# 15. Clip and Track Architecture

## 15.1 Typed LPC tracks

The generic clip system must gain validated typed tracks rather than relying only on free-form dictionaries:

- source-frame track;
- image/cel swap track;
- layer transform track;
- visibility track;
- z-order track;
- palette track;
- rig/bone transform track;
- constraint/IK target track;
- mesh-control or vertex-offset track;
- event/sound/action-point track; and
- direction/facing track.

Unknown fields are preserved where feasible, but unknown executable behavior is never loaded.

## 15.2 Hybrid playback

The evaluator can play, in one clip:

- native body frames;
- rigged weapon arms;
- frame-swapped clothing;
- deformed hair;
- custom facial cels; and
- project-owned effects.

Every track resolves against stable layer, rig, bone, mesh, and frame IDs. Missing references create diagnostics and do not silently target another object.

## 15.3 Timing

- Import exact LPC source cycles, including repeated frame references.
- Store timing as references and durations, not duplicated bitmaps.
- Permit retiming without modifying source sheets.
- Support stepped, linear, and approved curve interpolation by property type.
- Quantize only in Stepped Pixel mode or where a track explicitly requests it.

---

# 16. Export and Runtime Delivery

## 16.1 Export modes

### Baked Frames — default reliable path

- PNG image sequence;
- sprite sheet/atlas;
- GIF/review package where supported;
- exact frame timing manifest;
- exact credits and license choices; and
- no dependency on editor-only deformation code.

### Editable Godot Runtime

For validated rig-ready assets:

- Godot scenes/resources;
- source or project-owned textures;
- bones, slots, constraints, meshes, weights, and typed tracks;
- runtime equipment swaps;
- source/derivative manifest; and
- versioned importer/runtime plugin data.

### Hybrid Runtime

Supports native frame tracks and rigged/deformed layers together. Unsupported runtime features fall back to baked frames only through an explicit export profile, never silently.

## 16.2 Clean-consumer gate

Every release candidate exports to a clean Godot 4.7.1 consumer project that contains only:

- the released runtime/importer plugin;
- the exported package; and
- a minimal test scene.

The clean consumer must:

- import without absolute developer paths;
- render every required direction and clip;
- match baked reference frames where applicable;
- swap at least one equipment item;
- replay after a fresh editor restart;
- report missing assets clearly; and
- expose credits/license data.

---

# 17. Project Schema, Storage, and Migration

## 17.1 `LpcProjectProfile`

The profile stores:

- schema version;
- project UUID and monotonic display-name index;
- selected source lock and policy profile;
- body family and direction set;
- selections and layer groups;
- selected license option per credited source;
- palette state;
- source-frame references;
- project-owned cel/derivative references;
- typed clips/tracks;
- frame meshes;
- rig adapters and overrides;
- bake caches and validation reports;
- export profiles;
- acceptance records; and
- exact credit manifest inputs.

Labels are editable. UUIDs are durable identities. Deleted display-name numbers are never reused.

## 17.2 Migration rules

- Back up before every schema or source-lock migration.
- Migrations are deterministic and fixture-tested.
- A source-lock update previews asset/hash/license/layout changes before applying.
- A changed source frame never silently keeps an old mesh binding. The user may rebind, keep the old project-owned derivative, or cancel.
- Legacy non-LPC projects remain untouched.
- Old LPC dashboard projects use an explicit conversion wizard.
- Generic old deformation data is imported only when its source binding can be proven; otherwise it is preserved as legacy data and reported.

## 17.3 Content-addressed storage

- Immutable blobs are keyed by content hash.
- Documents reference blobs rather than copying them per autosave.
- Duplicate derivatives are deduplicated.
- Cleanup is explicit, previewable, reversible where possible, and never removes a blob still referenced by a recovery snapshot.
- The project reports source size, derivative size, bake-cache size, orphan candidates, and missing references.

---

# 18. Focused Creator UX

## 18.1 Direct start

- Resume the last editable LPC project when valid.
- On first run/New Project, show only source policy/pack and compatible base-family choices.
- A missing LPC library offers Locate, Rebuild Catalog, or Open Non-LPC Project. It does not prevent the application from starting.

## 18.2 Three-column creator

- Left: body, face, hair, and base features.
- Center: verified front preview by default, direction/animation controls, capability badges, and diagnostics.
- Right: clothing, equipment, accessories, and layer strategy.
- Footer: Undo, Redo, Reset Body, Save state, Export, Credits, and validation status.

Thumbnail pickers are searchable, virtualized, keyboard/controller accessible, and filtered by the active compatibility resolver.

## 18.3 Animate and Deform workspaces

The user can enter advanced work without leaving the project:

- **Animate** exposes clips, directions, typed tracks, cels, timing, onion skins, events, and playback.
- **Deform** exposes frame mesh, controls, quality diagnostics, interactive/verified preview, and Bake.
- **Prepare for Rig** is a guided conversion flow reachable from either workspace.
- **Rig** exposes pieces, pivots, bones, slots, constraints, weights, and direction adapters.

Workspace changes do not create separate undo histories.

---

# 19. Revised Delivery Map

| Phase | Shippable outcome | Depends on | Exit gate |
| --- | --- | --- | --- |
| **0. Truth, source lock, and reference renderer** | Existing claims audited; pinned LPC adapter, policy resolver, layout model, and authoritative raster reference exist | None | Synthetic and local source fixtures build deterministically; reference layer rendering and strict triangle raster tests pass |
| **1. Direct start and validated library** | Start/resume LPC projects from a locked local catalog | 0 | Full catalog intake, migration, autosave/recovery, policy selection, and exact credits pass |
| **2. Focused creator and native animation** | Assemble a character and play/export all genuinely supported native LPC clips | 1 | Compatibility conflicts are explicit; native preview/save/reopen/export agree |
| **3. Pixel and cel editor** | Create project-owned edits and missing/replacement cels | 1–2 | Pixel edits and cels survive history, recovery, duplication, and lossless PNG round-trip |
| **4. Typed clips and hybrid animation** | Author timing, transforms, image swaps, cels, events, and hybrid layer tracks | 2–3 | Typed clips replay identically after reopen and in clean exported artifacts |
| **5. Strict frame deformation** | Per-frame/per-layer mesh warp with deterministic verified Bake | 0, 3–4 | Real PNG goldens prove no shared-edge cracks, deterministic hashes, source-color invariants, recovery, and export parity |
| **6. Rig-ready cutout and new poses** | Prepare LPC art as direction-specific cutout rigs and author new rigid animations | 3–5 | Conversion, hidden-pixel repair, weapon/hand posing, save/reopen, baked export, and clean runtime pass |
| **7. Weighted deformation, cages, eight-direction completion, and production release** | Weighted meshes, real cage/soft tools, diagonal authoring, and editable runtime export | 5–6 | Fixture matrix, performance, malformed input, clean consumer, compliance, and human visual review pass |

Later phases cannot delay an already shippable earlier phase. Unlike the prior plan, later deformation phases are committed product scope; gates determine readiness and implementation quality, not whether the product abandons the capability.

---

# 20. Implementation and Verification Task Map

Every implementation task runs in a new Codex thread. Its paired verification task runs in another new thread. An implementation thread may mark only `IMPLEMENTED_UNVERIFIED`; only the paired verification may mark `VERIFIED`.

| Implementation task | Verification task | Required deliverable |
| --- | --- | --- |
| `LPC-AUD-001` | `QA-LPC-AUD-001` | Reconcile current source, ledger claims, reachable UI, evidence, and real gaps; create new requirement IDs without rewriting historical records |
| `LPC-SRC-001` | `QA-LPC-SRC-001` | Pinned source lock, deterministic catalog builder, source-update diff report |
| `LPC-LIC-001` | `QA-LPC-LIC-001` | Per-source alternative-license resolver, policy profiles, exact credit manifest |
| `LPC-LAY-001` | `QA-LPC-LAY-001` | Versioned standard/custom/oversize sheet-layout adapters and frame references |
| `LPC-REN-001` | `QA-LPC-REN-001` | Unified render snapshot and reference CPU layer compositor parity |
| `LPC-PRO-001` | `QA-LPC-PRO-001` | LPC profile schema, migrations, backup, source rebind, recovery fixtures |
| `LPC-START-001` | `QA-LPC-START-001` | Direct start/resume, missing-library flow, monotonic naming |
| `LPC-CAT-001` | `QA-LPC-CAT-001` | Staged catalog, virtualization, search, compatibility filtering |
| `LPC-CRE-001` | `QA-LPC-CRE-001` | Three-column creator wired to real catalog/profile/commands |
| `LPC-PAL-001` | `QA-LPC-PAL-001` | Exact palette lookup in preview and CPU export |
| `LPC-NAT-001` | `QA-LPC-NAT-001` | Exact native animation cycles, directions, multilayer order, partial-support handling |
| `LPC-PIX-001` | `QA-LPC-PIX-001` | Content-addressed copy-on-edit and derivative ancestry |
| `LPC-PIX-002` | `QA-LPC-PIX-002` | Pixel-canvas core and atomic command history |
| `LPC-PIX-003` | `QA-LPC-PIX-003` | Production cels, timeline, onion skin, cut-mask/gap-patch tools |
| `LPC-ANM-001` | `QA-LPC-ANM-001` | Typed LPC track schemas and deterministic evaluator |
| `LPC-ANM-002` | `QA-LPC-ANM-002` | Clip/timeline authoring, timing, image swaps, transforms, events |
| `LPC-ANM-003` | `QA-LPC-ANM-003` | Hybrid native/cel/rig/mesh playback and persistence |
| `LPC-WRP-001` | `QA-LPC-WRP-001` | Frame-bound mesh schema v2 and migrations |
| `LPC-WRP-002` | `QA-LPC-WRP-002` | Rect-grid, alpha-aware, and manual topology paths with validation |
| `LPC-WRP-003` | `QA-LPC-WRP-003` | Direct, pin, lattice, and soft deformation controls with commands |
| `LPC-WRP-004` | `QA-LPC-WRP-004` | Deterministic triangle raster baker producing real PNG/hash/audit artifacts |
| `LPC-WRP-005` | `QA-LPC-WRP-005` | Interactive and verified preview model, render-snapshot parity |
| `LPC-WRP-006` | `QA-LPC-WRP-006` | Geometry, palette, alpha, stretch, coverage, and source-binding diagnostics |
| `LPC-RIG-001` | `QA-LPC-RIG-001` | LPC rig-adapter schema and direction/body-family registry |
| `LPC-RIG-002` | `QA-LPC-RIG-002` | Prepare for Rig wizard, project-owned pieces, masks, pivots, gap patches |
| `LPC-RIG-003` | `QA-LPC-RIG-003` | Rigid cutout animation, IK, slots, weapon/hand anchors |
| `LPC-RIG-004` | `QA-LPC-RIG-004` | Clothing/equipment layer strategies and frame-track fallback |
| `LPC-SKN-001` | `QA-LPC-SKN-001` | Weight schema, real initializers, shared-topology transfer |
| `LPC-SKN-002` | `QA-LPC-SKN-002` | Weight painter with actual neighbor smoothing and exact undo |
| `LPC-CAG-001` | `QA-LPC-CAG-001` | True cage model, radial pins, soft drag, explicit evaluation order |
| `LPC-DIR-001` | `QA-LPC-DIR-001` | Direction-set authoring, mirrored-source policy, diagonal completion workflow |
| `LPC-EXP-001` | `QA-LPC-EXP-001` | Baked, editable, and hybrid export profiles with exact manifests |
| `LPC-RUN-001` | `QA-LPC-RUN-001` | Clean Godot runtime/importer package and equipment swap playback |
| `LPC-REL-001` | `QA-LPC-REL-001` | Full release candidate, policy review, fixture matrix, performance and clean-machine evidence |

`CURRENT_HANDOFF.md` authorizes exactly one implementation or verification task. A completed thread writes a new handoff and closes itself. It does not begin the recommended next task.

---

# 21. Existing Code Remediation Map

| Existing area | Required action |
| --- | --- |
| `deformation/solvers/deformation_baker.gd` | Rename/redefine as a mesh pose snapshot utility or deprecate it; add a real raster baker |
| `export/review/character_raster_renderer.gd` | Preserve as CPU compositor foundation; add shared triangle-raster interfaces rather than forking export logic |
| `deformation/meshes/mesh_data.gd` | Migrate to frame-bound/rest-state/provenance-aware schema v2 |
| `deformation/meshes/auto_mesh_generator.gd` | Replace unverified custom production triangulation; add deterministic rect-grid and alpha-aware paths |
| `deformation/handles/grid_cage_deformation.gd` | Rename current radial behavior; implement a separate true cage model |
| `deformation/weights/bone_binder.gd` | Rename as distance initializer; add separate shared-topology and genuine diffusion options |
| `deformation/weights/weight_painter.gd` | Implement adjacency-based smoothing, rigid assign, exact influence inspection |
| `deformation/solvers/deformation_validator.gd` | Expand into geometry/source/raster/color diagnostics or split into focused validators |
| `tests/unit/test_mesh_deformation.gd` | Keep logic tests but add rendered fixtures, PNG/hash goldens, persistence, malformed cases, and clean export tests |
| Generic rig templates | Keep for Advanced Studio; add LPC adapter registry with source-frame masks and direction-specific rest poses |
| Generic animation clip dictionaries | Add typed LPC track schemas and validators while preserving migration compatibility |
| `project.godot` pixel settings | Do not depend on global snapping; enforce explicit mode settings in LPC evaluators/previews/baker |
| Task ledger/evidence | Add new LPC requirements/tasks; do not relabel prototype completion as production verification |

Production code files remain at or below 300 physical lines whenever practical. Any exception follows the repository’s documented split analysis and exception approval process.

---

# 22. Required Fixture Matrix

Tracked fixtures must be synthetic or verified redistributable. Full-catalog tests run against the local locked LPC source and publish reports/hashes rather than unapproved source art.

| Fixture | Purpose |
| --- | --- |
| Standard 64×64, 13-column, four-direction body | Standard layout and exact cycle verification |
| Multiple body families | Body-family filtering and adapter selection |
| Foreground/background multi-layer tail | Atomic layer groups and z ordering |
| Oversize/custom-frame weapon | Nonstandard frame rectangles and offsets |
| Asset with an explicit partial animation list | Missing-animation conflict workflow |
| Asset using default animation semantics | Correct inference of the upstream default subset |
| Multi-license source | Alternative license selection and policy resolution |
| Alias/renamed asset | Source update and migration |
| Disconnected opaque islands | Submesh/island generation |
| Sprite with an internal transparent hole | Hole/topology/raster coverage |
| Partial-alpha shadow | Strict composite labeling and alpha audit |
| Frame sequence with changing silhouette | Prohibition on silent topology reuse |
| Deliberately flipped triangle | Hard geometry failure |
| Shared-edge two-triangle warp | Crack-free deterministic rasterization |
| Extreme stretch | Quality warning/failure thresholds |
| Corrupt/missing/resized PNG | Intake, load, rebind, and export diagnostics |
| Project-owned pixel edit | Derivative ancestry and lossless round-trip |
| Prepared rigid cutout | New-pose animation and hidden-pixel patching |
| Weighted clothing layer | Shared topology/weight transfer |
| Hybrid clip | Native body + rigged equipment + deformed accessory + custom face cel |
| Eight-direction export profile | Cardinal/diagonal completeness and mirror policy |

---

# 23. Automated and Manual Acceptance Gates

## 23.1 Catalog and source

- deterministic catalog signature;
- full local catalog intake;
- every selected file hash and dimension verified;
- aliases resolve deterministically;
- source update produces an accurate diff;
- invalid individual assets fail with exact IDs/paths;
- application remains usable for non-LPC projects when the LPC source is missing.

## 23.2 Licensing and credits

- alternative licenses resolved correctly;
- policy accept/reject reasons are visible;
- derivatives retain all ancestors;
- exports include exact selected license options and credits;
- policy changes invalidate stale approval and require revalidation;
- no advertised release pack lacks a viable base/animation path;
- human final review recorded for public packs.

## 23.3 Native animation

- exact source rows, directions, cycles, repeats, and offsets;
- foreground/background groups remain synchronized;
- missing-animation layers never disappear silently;
- save/reopen keeps exact selection and playhead state;
- verified preview and baked frame hashes agree.

## 23.4 Pixel/cel editing

- stroke/fill/selection/import each form atomic commands;
- undo/redo crosses workspace boundaries;
- autosave/recovery restores exact pixels;
- duplicate/save-as preserves or intentionally forks blob references;
- PNG round-trip is byte- or pixel-equivalent under the declared format;
- source files remain unchanged.

## 23.5 Frame warp

- source-frame hash binding enforced;
- no silent topology reuse after source/mask change;
- no shared-edge holes;
- degenerate/flipped/self-intersecting geometry detected;
- strict per-layer output colors are a subset of post-palette source RGBA values;
- no new partial alpha in strict per-layer output;
- same render snapshot produces the same output hash across repeated runs;
- save/reopen and crash recovery preserve editable mesh/control state;
- interactive preview settles to exact verified preview;
- image sequence/sprite-sheet exporters receive the same verified frames.

## 23.6 Rig conversion and animation

- adapter source signatures match;
- all pieces have valid masks, pivots, z groups, and ancestry;
- missing hidden-pixel regions are reported and editable;
- rigid new poses do not require weighted deformation;
- unsupported layers stay on explicit frame tracks;
- weapon grips align both hands where required;
- each direction uses its approved adapter;
- mirror usage is recorded and editable;
- clean runtime plays the same pose/clip after restart.

## 23.7 Weighted deformation

- weight sums and bone references valid;
- actual neighbor smoothing proven with topology fixtures;
- shared-topology transfer produces expected fixture weights;
- extreme poses run stretch/fold diagnostics;
- weighted preview/bake/runtime paths agree within the declared mode;
- no tool destructively mutates rest geometry.

## 23.8 Export and clean consumer

- actual PNGs/resources exist and validate;
- manifest references resolve using relative paths;
- no developer absolute paths;
- output hashes and frame counts match expectations;
- credits/license manifest complete;
- blank Godot consumer imports and plays required clips;
- malformed package fails clearly;
- exporter never reports success after writing only metadata.

---

# 24. Performance Budgets

Phase 0 records exact baseline machines and publishes measured budgets. The following are provisional targets that may be tightened, but may be relaxed only through a documented benchmark decision:

- Creator input response: p95 under 100 ms.
- Warm catalog search/filter: p95 under 100 ms over the full locked catalog.
- First visible thumbnail batch: under 500 ms after the category is ready.
- Native preview: 60 FPS target at the supported 1280×720 minimum.
- Interactive deformation: 60 FPS target for common LPC-sized layers; never below 30 FPS at the published maximum supported mesh/layer load.
- Verified strict bake: p95 under 50 ms for one ordinary 64×64 composite frame on the reference CPU, excluding first-load disk I/O.
- Batch export: published frames-per-second target for a representative multilayer character.
- Save/autosave: no UI stall over the published threshold; blob hashing and large batch work may use worker threads where safe.
- Memory: bounded decoded-image and verified-frame caches with visible diagnostics and deterministic eviction.

If GDScript cannot meet the strict-bake budget, optimize behind the same interface with a reviewed GDExtension. The GDScript reference baker remains the correctness oracle.

---

# 25. Evidence Bundle Requirements

Every verification task produces an evidence bundle containing, as applicable:

- exact commit SHA and source-lock signature;
- requirement/task IDs;
- production files and reachable UI path;
- command/test logs;
- fixture IDs and hashes;
- before/after screenshots at integer zoom;
- actual PNG or runtime artifacts;
- visual golden comparisons;
- color/alpha/geometry audit reports;
- save/reopen and recovery evidence;
- performance traces;
- malformed/negative-case output;
- clean-consumer import/playback evidence;
- license/credit manifest; and
- known limitations or rejected warnings.

A unit test that repeats implementation logic is not sufficient evidence for rendering, persistence, export, runtime behavior, or licensing.

---

# 26. Residual Risk Register and Controlled Responses

| Risk | Controlled response |
| --- | --- |
| LPC assets have incomplete animation coverage | Compatibility intersection, explicit conflict UI, frame/cel/rig fallback |
| A flattened frame lacks hidden pixels | Prepare for Rig creates project-owned pieces and gap patches; pixel editor repairs |
| One topology does not fit every frame | Frame-bound meshes and validated topology groups only |
| GPU edge rules differ by hardware | CPU verified preview/export is authoritative |
| Warping duplicates or omits source pixels | Sampling/stretch heatmaps, quality thresholds, rig conversion for large changes |
| Automatic mesh bends badly | Explicit topology, internal vertices, manual editor, geometry diagnostics |
| Clothing does not follow a generic body rig | Adapter/shared-topology transfer or explicit frame-track fallback |
| Directional occlusion differs | Separate direction adapters and z groups |
| Eight-direction art is absent upstream | Author diagonal cels or rigged directions; no silent rotation claim |
| Source repository changes | Pinned lock, update diff, backup migration, source rebind choices |
| License metadata is complex or alternative | Per-source license-choice resolver and human release review |
| GDScript CPU bake is too slow | Cache first; then GDExtension with reference-hash parity |
| Existing “completed” tasks mask prototype gaps | New LPC requirement IDs, truth audit, independent evidence |

These risks no longer determine whether animation/deformation exists. They determine which explicit representation, tool, or fallback is used for a particular layer and pose.

---

# 27. Explicit Non-Goals and Prohibited Shortcuts

- Do not deform an entire spritesheet as one mesh.
- Do not assume every frame is 64×64 or every sheet has the standard row map.
- Do not infer full animation support from a missing `animations` field.
- Do not silently share a mesh across changing silhouettes.
- Do not call coordinate copying or metadata output a raster bake.
- Do not use linear filtering in Strict LPC Raster mode.
- Do not hide GPU/CPU mismatch.
- Do not auto-rig a flattened composite without masks, pieces, overlap review, and provenance.
- Do not force every clothing/accessory layer into a weight mesh.
- Do not flatten a layered character without creating an explicit project-owned derivative.
- Do not label a distance-weight initializer as heat binding.
- Do not label radial pins as a grid cage.
- Do not treat all listed alternative licenses as simultaneous obligations.
- Do not call share-alike/copyleft art noncommercial.
- Do not commit the full upstream LPC source library to this repository.
- Do not mark a task verified because a class, button, schema, unit test, or log exists.

---

# 28. Definition of Complete

The LPC creator/animator/deformation work is complete only when a user can demonstrate all of the following on production-shaped assets:

1. Start or resume an LPC project directly.
2. Build a valid character from a locked local catalog.
3. See exactly which native animations and directions the complete selection supports.
4. Play and export those native animations with correct layer ordering.
5. Resolve a missing-animation layer through substitution, hide-for-clip, custom cel, or rig conversion.
6. Make a pixel edit without changing the source library.
7. Create and reopen a custom cel clip.
8. Apply a frame-local warp and obtain a real deterministic strict PNG bake.
9. See geometry, stretch, color, and alpha diagnostics.
10. Prepare at least one body direction as a project-owned rigid cutout, repair a hidden-pixel gap, and author a new pose.
11. Keep at least one unsupported accessory as a frame track in the same hybrid clip.
12. Bind and pose a weapon with correct hand anchors.
13. Add and verify a weighted deformable layer.
14. Complete a required diagonal direction through authored cel or rigged animation.
15. Save, close, reopen, undo/redo, recover from an interrupted save, and retain exact state.
16. Export baked and editable/hybrid delivery formats.
17. Import the output into a clean Godot project and play it.
18. Produce exact source, derivative, credit, selected-license, validation, and output-hash manifests.
19. Pass the full fixture, malformed-input, performance, and human visual-review gates.
20. Show no source mutation, hidden placeholder path, or unverifiable completion claim.

---

# 29. Research Sources

The implementation team must pin and record the exact source revisions it relies on. Research for this revision included:

- Paper Quest repository at commit `065b90d0ce078af9b3b0e4b65b4f6d1b9fa7e104`
  - `DIRECT_START_LPC_CREATOR_PLAN.md`
  - `MODULAR_2D_CHARACTER_ANIMATION_STUDIO_MASTER_PLAN.md`
  - `deformation/meshes/mesh_data.gd`
  - `deformation/meshes/auto_mesh_generator.gd`
  - `deformation/solvers/deformation_baker.gd`
  - `deformation/solvers/deformation_validator.gd`
  - `deformation/handles/grid_cage_deformation.gd`
  - `deformation/handles/soft_drag_tool.gd`
  - `deformation/weights/bone_binder.gd`
  - `deformation/weights/weight_painter.gd`
  - `tests/unit/test_mesh_deformation.gd`
  - `export/review/character_raster_renderer.gd`
  - `export/image_sequences/image_sequence_exporter.gd`
  - `rigging/bones/rig_templates.gd`
  - `project.godot`
- Universal LPC Sprite Sheet Character Generator at commit `b2c85f98de52624b454dfdfac329bfee75795c2d`
  - `README.md`
  - `CONTRIBUTING.md`
  - `sources/state/constants.ts`
  - `sources/state/json.ts`
  - `sources/canvas/preview-animation.ts`
  - `sheet_definitions/body/body.json`
  - `sheet_definitions/body/lizard/tail_lizard.json`
- Godot documentation at commit `8be07b62c7abc0612dad5e75ffd1190243f85392`
  - `tutorials/animation/2d_skeletons.rst`
  - `classes/class_polygon2d.rst`
  - `classes/class_canvasitem.rst`
  - `classes/class_geometry2d.rst`

Permanent source links should use commit-pinned GitHub URLs in evidence documents so later upstream changes do not rewrite the basis of a verified decision.
