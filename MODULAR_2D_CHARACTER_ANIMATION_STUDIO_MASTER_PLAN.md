# Modular 2D Character Creator and Animation Studio
## Production Master Implementation Plan

**Document status:** Authoritative replacement for all earlier character-creator plans  
**Target engine:** Godot 4.7.1  
**Primary platform:** Windows desktop authoring application with a separate Godot runtime/importer plugin  
**License target:** Open source under a permissive license, subject to a completed dependency-license audit  
**Product target:** Full practical Spriter Pro parity, selected publicly documented Spriter 2 beta capabilities, and stronger character-creation, weapon-authoring, validation, and native-Godot workflows  
**Scale target:** At least 100 interchangeable characters, 2,000 modular parts, 500 weapon definitions, and reusable multi-project animation libraries  
**Source-size rule:** Keep authored production code files at or below 300 physical lines whenever practical. Exceeding 300 lines requires a documented necessity and approved exception.

---

# 1. Executive Mandate

Build a complete, production-usable 2D character creation and animation application. Do not build a thin appearance picker, a collection of disconnected editor demos, or a runtime that assumes all animation was authored elsewhere.

The finished application must allow an artist or developer to complete this real workflow:

```text
Create project
→ import modular art
→ assemble character
→ create or apply a rig
→ configure pivots, slots, bones, meshes, weights, and constraints
→ add any supported weapon or tool
→ position both arms and hands correctly on its grips
→ create directional animations
→ add hitboxes, events, action points, sounds, and variables
→ save and close the application
→ reopen with no data loss
→ export editable runtime data or baked output
→ import into a clean Godot project
→ play, blend, and change equipment at runtime
```

The application must include six integrated workspaces:

1. Project and Asset Workspace
2. Character Creator Workspace
3. Rigging and Deformation Workspace
4. Animation Studio Workspace
5. Weapon and Equipment Pose Studio
6. Preview, Rules, Runtime, and Export Workspace

This plan is not considered implemented until those workspaces operate together on production-shaped sample assets.

---

# 2. Product Scope and Capability Target

## 2.1 Practical Spriter Pro Parity

The application must implement and verify the practical capabilities associated with Spriter Pro:

- Modular sprite-piece animation
- Sprite transforms, opacity, pivots, and image replacement
- Bone creation and parent-child hierarchies
- Keyframes and automatic interpolation
- Per-object timelines
- Z-order editing and animation
- Character maps and stacked character variants
- Sound cues
- Lip-sync or viseme authoring
- Collision rectangles and additional gameplay shapes
- Action points
- Variables and tags
- Event triggers
- Indexed-color customization
- Sequential-image, spritesheet, and GIF export
- Batch export
- Reusable runtime animation data
- Project merging or linked reusable projects

## 2.2 Selected Spriter 2-Style Capabilities

The enhanced target includes these publicly documented Spriter 2 beta concepts:

- Deformable meshes
- Bone weights
- Arbitrary deformation handles or attractors
- Facing grids and directional image placement
- Optional blending between neighboring directional meshes
- IK influence and ground/contact anchoring
- Animatable inheritance, visibility, and z-order
- Interactive onion skins
- Bézier easing curves
- Sound waveform scrubbing
- Video, GIF, and image-sequence references
- MP4, GIF, and image-sequence export
- Interactive animation rules, events, and time windows
- Multi-project character and accessory workflows
- Sketch-to-pose assistance
- Progressive project loading

## 2.3 Capabilities That Must Exceed Those Baselines

- Built-in modular character creator
- Deterministic seeded NPC generation
- Body-type and equipment compatibility rules
- Automatic validation of imported assets and authored animation data
- Native Godot scene/resource/runtime export
- Runtime equipment swapping
- Data-driven weapon definitions
- Weapon grip and hand-pose authoring
- Automatic arm, elbow, wrist, and hand alignment
- Body-type and direction-specific weapon retargeting
- Pixel-safe weapon posing and baked output
- Independent verification gates and evidence bundles
- Open, versioned project format
- Extensible constraint and weapon plugin API

## 2.4 Two Rendering and Authoring Pipelines

### Modular Skeletal Pipeline

Use for smooth cutout animation:

- Sprite pieces
- Bone hierarchies
- IK and constraints
- Pivot animation
- Mesh deformation
- Weight painting
- Runtime interpolation
- Blending and state machines

### Frame and Pixel-Safe Pipeline

Use for pixel art and hand-drawn replacements:

- Layered frame animation
- Integer-position snapping
- Optional discrete angle snapping
- Per-frame image replacement
- Direction-specific art
- Pre-drawn arms and hands where necessary
- Shared authoritative playback clock
- Nearest-neighbor rendering
- Baked spritesheet output

A character may use either pipeline or a hybrid.

---

# 3. Non-Negotiable Engineering Rules

## 3.1 No False Completion

A feature is not complete merely because:

- A script, scene, class, method, or button exists.
- A unit test passes.
- A mock returns the expected result.
- A log prints `success`.
- A sample manifest was generated.
- A button changes only UI state without changing project data.
- An exporter writes metadata but not the actual animation or assets.
- Codex states that it implemented the requirement.

A feature requires observable production behavior, persistence, edge-case handling, and independent verification.

## 3.2 No Accepted Placeholders

Accepted production paths may not contain:

- Empty handlers
- Hard-coded fake responses
- Demo-only implementations presented as general systems
- Disabled controls presented as finished
- Placeholder exporters
- TODO-only implementation
- Silent failure
- Unreachable alternate implementations
- Tests that merely repeat the implementation logic

## 3.3 Data-Driven Extension

Adding a normal character part, palette, outfit, weapon, grip, hand pose, body mapping, animation, or export profile must not require editing core runtime code.

A genuinely novel weapon mechanic may require a plugin that implements a documented interface, but must not require modifying the editor core.

## 3.4 Source File Size

All handwritten production code, tests, tools, build scripts, and editor scripts should be at or below 300 physical lines.

A file may exceed 300 lines only when all of the following exist:

1. A split analysis explains the responsibilities in the file.
2. The analysis explains why splitting would harm correctness, clarity, performance, generated-code integrity, or engine compatibility.
3. The exact line count is recorded.
4. A verification task approves the exception.
5. The exception is listed in `docs/implementation/LOC_EXCEPTIONS.md`.

Generated files, lockfiles, imported third-party sources, binary assets, and authoritative long-form design documents are exempt.

## 3.5 Stable, Open Data

- Stable immutable IDs
- Relative asset paths
- Versioned schemas
- Deterministic serialization
- Explicit migrations
- Transactional saves
- No executable code in project data
- Unknown fields preserved where feasible
- Missing references reported instead of silently discarded

---

# 4. Truthful Implementation and Verification System

## 4.0 Task Numbering Reconciliation

The authoritative mapping between this master plan and the historical task
ledger is maintained in
`docs/implementation/MASTER_PLAN_RECONCILIATION.md`. The ledger must add a
dedicated row for each master-plan task before implementation starts; legacy
task IDs never substitute for unfinished authoring, validation, or
clean-consumer acceptance work.

This system is part of the project from the first task. It is not release polish.

## 4.1 Requirement Statuses

```text
PLANNED
IN_PROGRESS
IMPLEMENTED_UNVERIFIED
VERIFIED
BLOCKED
REJECTED
DEFERRED_WITH_APPROVAL
```

An implementation thread may advance a requirement only to `IMPLEMENTED_UNVERIFIED`. A separate verification thread is required to mark it `VERIFIED`.

## 4.2 Required Evidence Layers

### A. Source Evidence

- Exact production files identified
- Feature reachable from production UI or API
- No inactive duplicate implementation
- Public interfaces match architecture
- Error handling exists
- Persisted fields are actually read and written
- No hidden placeholder path

### B. Automated Behavioral Evidence

- Unit tests for pure logic
- Integration tests with real resources
- Save/reload tests
- Export/import round trips
- Regression tests
- Malformed-input and negative tests
- Performance tests where relevant

Mocks may support unit tests but cannot be the only evidence for file I/O, import, export, rendering, or runtime integration.

### C. Interactive Workflow Evidence

Use the actual application UI or supported production CLI. Record:

- Exact steps
- Expected result
- Actual result
- Input files
- Output files
- Screenshot or artifact when visual
- Any discrepancy

### D. Persistence Evidence

For persisted features:

1. Create or edit the data.
2. Save.
3. Close the application.
4. Restart.
5. Reopen the project.
6. Confirm exact state.
7. Export where applicable.
8. Import into a clean consumer project.
9. Confirm behavior again.

### E. Adversarial Evidence

Exercise at least one realistic failure:

- Missing asset
- Duplicate ID
- Corrupt metadata
- Invalid schema
- Unreachable weapon grip
- Impossible constraint cycle
- Unsupported direction cell
- Save interruption
- Invalid export path
- Missing plugin

### F. Independent Verification

A new Codex thread must independently inspect and reproduce the behavior without trusting the implementation handoff.

## 4.3 Evidence Bundles

Every task stores evidence under:

```text
docs/implementation/evidence/<TASK_ID>/
```

Typical contents:

```text
README.md
commands.log
test-results.txt
manual-verification.md
screenshots/
exports/
roundtrip/
performance/
known-failures/
```

## 4.4 Requirement Traceability

Maintain:

```text
docs/implementation/REQUIREMENTS_TRACEABILITY.md
```

Every row must include:

- Requirement ID
- Description
- Implementation task
- Verification task
- Source files
- Tests
- Manual scenario
- Evidence path
- Current status
- Known limitations
- Last verified commit

No milestone closes while a mandatory requirement is below `VERIFIED`.

## 4.5 Anti-Superficial-Test Controls

- Critical tests must be mutation-checked by temporarily breaking the implementation and confirming the relevant test fails.
- UI reachability must be audited by following the real menu/button path.
- Export tests must open and inspect the exported result.
- Runtime tests must use a clean consumer project.
- Visual systems require visual regression evidence.
- Save tests must restart the process, not merely serialize and deserialize in memory.
- A passing test may not override a failed manual production workflow.

---

# 5. Repository Architecture

```text
project-root/
├── app/
│   ├── bootstrap/
│   ├── commands/
│   ├── services/
│   ├── workspaces/
│   ├── shared_ui/
│   └── application_state/
├── core/
│   ├── documents/
│   ├── assets/
│   ├── ids/
│   ├── serialization/
│   ├── migrations/
│   ├── validation/
│   └── diagnostics/
├── character/
│   ├── definitions/
│   ├── assembly/
│   ├── compatibility/
│   ├── palettes/
│   ├── randomization/
│   └── layer_order/
├── rigging/
│   ├── bones/
│   ├── slots/
│   ├── constraints/
│   ├── ik/
│   ├── retargeting/
│   └── poses/
├── deformation/
│   ├── meshes/
│   ├── weights/
│   ├── handles/
│   └── solvers/
├── animation/
│   ├── clips/
│   ├── tracks/
│   ├── keys/
│   ├── curves/
│   ├── timeline/
│   ├── onion_skin/
│   ├── blending/
│   └── rules/
├── weapons/
│   ├── definitions/
│   ├── grips/
│   ├── poses/
│   ├── constraints/
│   ├── solver/
│   ├── authoring/
│   ├── validation/
│   └── runtime/
├── gameplay_metadata/
│   ├── events/
│   ├── variables/
│   ├── tags/
│   ├── action_points/
│   ├── hitboxes/
│   └── hurtboxes/
├── media/
│   ├── audio/
│   ├── references/
│   └── lip_sync/
├── export/
│   ├── project_format/
│   ├── spritesheets/
│   ├── image_sequences/
│   ├── gif/
│   ├── video/
│   ├── atlases/
│   └── godot/
├── runtime_plugin/
│   ├── importer/
│   ├── player/
│   ├── state_machine/
│   ├── equipment/
│   └── samples/
├── editor_plugins/
├── tests/
│   ├── unit/
│   ├── integration/
│   ├── roundtrip/
│   ├── visual/
│   ├── stress/
│   ├── fixtures/
│   └── golden/
├── tools/
│   ├── verify_task/
│   ├── loc_checker/
│   ├── schema_validator/
│   ├── evidence_checker/
│   ├── stub_scanner/
│   └── visual_diff/
├── docs/
│   ├── architecture/
│   ├── user/
│   ├── asset_authoring/
│   ├── formats/
│   └── implementation/
│       ├── handoffs/
│       ├── evidence/
│       ├── tasks/
│       ├── REQUIREMENTS_TRACEABILITY.md
│       ├── TASK_LEDGER.md
│       └── LOC_EXCEPTIONS.md
└── samples/
```

Responsibilities may be mapped to an existing repository convention, but may not be collapsed into one oversized global script.

---

# 6. Core Project Format and Persistence

## 6.1 Primary Objects

```text
StudioProject
AssetLibrary
CharacterDefinition
CharacterVariant
BodyTypeDefinition
PartDefinition
PaletteDefinition
RigDefinition
BoneDefinition
SlotDefinition
ConstraintDefinition
MeshDefinition
DeformationHandleDefinition
AnimationClip
TrackDefinition
Keyframe
CurveDefinition
FacingGridDefinition
WeaponDefinition
GripDefinition
WeaponPoseProfile
HandPoseDefinition
EventDefinition
CollisionShapeTrack
RuleGraph
ExportProfile
```

## 6.2 Transactional Saving

1. Serialize to a temporary file.
2. Validate the complete result.
3. Flush it to disk.
4. Keep a rolling backup.
5. Atomically replace the prior manifest.
6. Record a journal entry.
7. Clear dirty state only after success.

Autosave must never overwrite the last known-good manual save.

## 6.3 Schema Migration

Every schema change requires:

- Source version
- Target version
- Migration implementation
- Old-version fixture
- Migration test
- Failure behavior
- Release note

## 6.4 Recovery

- Rolling manual backups
- Separate autosave files
- Crash journal
- Recovery browser
- Compare recovered state to manual save
- Corrupt-save quarantine
- Test that terminates the app during save

---

# 7. Application Shell and Asset Workspace

## 7.1 Application Shell

- Dockable and resizable panels
- Workspace presets
- Multi-document tabs
- Recent projects
- Command palette
- Search
- Undo/redo history
- Dirty-state indicators
- Status and diagnostics panels
- Rebindable shortcuts
- Keyboard and controller navigation
- Light/dark appearance
- DPI scaling
- Crash recovery prompt

Workspace changes must preserve project, selection, animation, playhead, zoom, and unsaved state.

## 7.2 Asset Workspace

- Create/open/close projects
- Import PNG, WebP, reference JPEG, supported SVG, spritesheets, image sequences, audio, video, and GIF
- Folder watching and manual refresh
- Thumbnail generation
- Search, tags, favorites, and filters
- Duplicate detection
- Missing-file repair
- Asset relocation and path rebasing
- Dependency view
- Unused-asset report
- Source replacement while preserving stable IDs, pivots, meshes, and bindings
- Batch metadata editing
- Drag-and-drop
- External-editor round trip
- Pixel-art and smooth-art import presets

The browser must distinguish source art, runtime art, reference media, generated previews, exports, and cache data.

---

# 8. Canvas, Selection, and Undo

Required canvas behavior:

- Pan, zoom, frame selection, frame all
- Pixel grid, rulers, and guides
- Origin and anchors
- Box/lasso selection
- Overlap cycling
- Lock, hide, and solo
- Local/world transforms
- Move, rotate, scale, and supported skew
- Numeric transform entry
- Pivot editing
- Copy, paste, duplicate, and clone subtree
- Z-order editing
- Onion-skin and reference overlays
- Pixel-perfect preview
- Selection sets

Every data-changing action must run through the command system and support undo/redo.

Undo must cover character parts, rig edits, mesh edits, weights, keys, curves, events, hitboxes, facing-grid cells, weapon grips, pose profiles, state machines, and rules.

---

# 9. Rigging and Constraint System

## 9.1 Bone Authoring

- Create, rename, duplicate, delete, reparent, and reorder bones
- Visual hierarchy
- Bone length and rest angle
- Local/global transform views
- Rotation and scale inheritance
- Locking and visibility
- Bone colors and groups
- Mirrored left/right hierarchies
- Symmetry editing
- Copy/paste sub-rigs
- Restore rest pose
- Rig templates

## 9.2 Slots and Attachments

Each slot supports:

- Parent bone
- Local transform
- Direction override
- Z-order rule
- Allowed asset types
- Mirrored partner
- Runtime attachment
- Visibility conditions
- Multiple attachment variants

## 9.3 Constraint Framework

- Position
- Rotation
- Scale
- Aim/look-at
- Distance
- Angle limits
- Copy transform
- Parent blend
- Two-bone IK
- Pole target
- Ground/contact pin
- Path
- Spring/secondary motion
- Weapon grip
- Hand pose
- Custom plugin constraints

All constraints require influence, enabled state, animatable parameters, evaluation order, cycle detection, diagnostics, and bake-to-keys support.

## 9.4 Retargeting

- Skeleton profiles
- Bone aliases
- Rest-pose normalization
- Proportion compensation
- Body-type offsets
- Retarget preview
- Batch retarget
- Correction layers
- Validation report

---

# 10. Animation Studio

## 10.1 Timeline and Dope Sheet

- Multiple clips
- Per-object tracks
- Expand/collapse groups
- Search/filter
- Key all and key selected
- Auto-key
- Add, remove, move, duplicate, and multi-select keys
- Timing stretch/compress
- Ripple edits
- Copy/paste between clips
- Copy attributes to all keys
- Markers and regions
- Loop and playback ranges
- Frame/time display
- Audio waveform
- Scrubbing
- Track mute, solo, lock, and colors
- Image-swap tracks
- Visibility tracks
- Animatable z-order

## 10.2 Interpolation and Curves

- Stepped
- Linear
- Smooth/cubic
- Bézier
- Custom curves
- Per-key easing
- Hold before/after
- Angle shortest-path and explicit spin
- Tangent editing
- Curve presets
- Multi-curve overlay
- Curve simplification
- Bake/sampling with tolerance

## 10.3 Onion Skinning

- Previous/next frames
- Previous/next keys
- Pinned times
- Adjustable count, color, and opacity
- Per-part visibility
- Interactive onion selection
- Edit-at-onion-time workflow
- Obstruction cycling
- Direction-aware display

## 10.4 Pose Tools

- Pose library
- Mirror and paste mirrored
- Blend poses
- Restore rig pose
- Additive poses
- Pose thumbnails
- Sketch-to-pose assistance
- Pose comparison

---

# 11. Mesh Deformation

## 11.1 Mesh Editing

- Automatic mesh generation
- Manual vertices and edges
- Triangulation
- UV editing
- Boundary preservation
- Pixel-safe mesh option
- Symmetry
- Mesh validation

## 11.2 Weight Painting

- Brush size, strength, and falloff
- Add, subtract, smooth
- Normalize
- Lock influences
- Influence limits
- Heatmap
- Mirror/copy weights
- Extreme-pose preview
- Diagnostics

## 11.3 Deformation Handles and Attractors

- Arbitrary handles
- Influence radius and falloff
- Parent relationships
- Soft drag
- Timeline animation
- Facing-grid integration
- Restore to rig
- Copy/paste and mirror
- Bake deformation

Verification must detect tearing, inverted triangles, unweighted vertices, unstable interpolation, unexpected UV drift, and runtime mismatch.

---

# 12. Facing Grid and Directional Animation

Support 4, 8, 16, and custom direction sets.

Each cell may define:

- Alternate sprite or mesh
- Offset, rotation, and scale
- Mirror rule
- Visibility
- Z-order
- Deformation state
- Handedness swap
- Left/right slot swap

Direction behavior:

- Hard switching
- Nearest direction
- Optional sprite crossfade
- Optional deformable-mesh crossfade
- Per-part opt-out
- Pixel mode with no crossfade
- Runtime quantization

Authoring tools:

- Filename-convention auto-fill
- Mirroring
- `_left`/`_right` slot exchange
- Folder batch placement
- Radial direction preview
- Continuous direction scrub
- Missing-cell validator
- Direction-specific pivot and weapon correction


---

# 13. Character Creator Workspace

## 13.1 Modular Slot Registry

Initial slots include:

```text
body
body_overlay
head
eyes
eyebrows
ears
nose
mouth
facial_hair
back_hair
front_hair
headwear
neck
torso
torso_overlay
shoulder_left
shoulder_right
upper_arm_left
upper_arm_right
forearm_left
forearm_right
hand_left
hand_right
glove_left
glove_right
legs
legs_overlay
shoe_left
shoe_right
back_accessory
front_accessory
main_hand
off_hand
back_weapon
hip_weapon
aura
shadow
```

Users must be able to define new slot types in data without editing core code.

Every slot definition includes:

- Stable ID and display name
- Default render layer
- Required/optional status
- Allowed categories
- Single or multiple occupancy
- Recolor support
- Hidden and conflicting slots
- Directional layer-order rules
- Runtime attachment behavior

## 13.2 Character Part Definition

Each part includes:

```text
schema_version
part_id
display_name
slot_id
category_id
compatible_body_types
compatible_rig_profiles
sprite_or_mesh_assets
facing_grid_id
preview_icon
tags
required_tags
excluded_tags
hidden_slots
conflicting_parts
palette_channels
attachment_profile_id
animation_coverage
unlock_metadata
sort_order
```

## 13.3 Compatibility Engine

Rules may evaluate:

- Body type
- Rig profile
- Species or silhouette category
- Required and excluded tags
- Hidden and required slots
- Mutually exclusive groups
- Size class
- Direction coverage
- Animation coverage
- Weapon-grip compatibility
- Layer conflicts

The UI must explain incompatibility. It must not silently remove items unless the rule explicitly defines an automatic resolution and the user is notified.

## 13.4 Appearance and Palette Tools

- Part thumbnails
- Search and filters
- Favorites and recents
- Category locks
- Global and per-part colors
- Indexed-color/palette channels
- Material/shader parameters
- Character maps
- Stacked character maps
- Outfit sets
- Equipment sets
- Variant comparison
- Copy/paste appearance
- Undo/redo

Recommended palette channels:

```text
skin_primary
skin_shadow
hair_primary
hair_secondary
eyes
fabric_primary
fabric_secondary
trim
leather
metal
accent
magic_glow
```

Recoloring must not require duplicate textures for each color.

## 13.5 Character Presets

A preset stores:

- Schema version
- Appearance ID
- Character name
- Body type
- Rig profile
- Selected parts
- Colors
- Material parameters
- Equipped weapons
- Weapon pose profile selections
- Random seed
- Metadata

Unknown optional fields must not crash loading. Missing asset IDs must generate visible warnings and preserve recoverable references.

## 13.6 Deterministic Randomization

- Seeded generation
- Weighted rarity
- Category locks
- Compatibility-safe selection
- Bounded retry and fallback
- Duplicate-appearance avoidance
- Batch generation without rendering every character
- Stable output for the same schema version and seed

## 13.7 Creator Interface

Recommended layout:

```text
┌─────────────────────────────────────────────────────────────────────┐
│ Name  Body  Rig  Undo  Redo  Randomize  Save  Export              │
├───────────────┬──────────────────────────────┬──────────────────────┤
│ Categories    │ Character Preview            │ Part/Weapon Options  │
│ Body          │ Direction and animation      │ Search and filters   │
│ Face          │ Play, pause, frame step      │ Thumbnails           │
│ Hair          │ Zoom and overlays            │ Colors               │
│ Clothing      │ Grip and IK diagnostics      │ Compatibility        │
│ Weapons       │ Hitbox/action-point display  │ Pose profiles        │
│ Accessories   │                              │                      │
├───────────────┴──────────────────────────────┴──────────────────────┤
│ Validation, conflicts, missing coverage, and save state             │
└─────────────────────────────────────────────────────────────────────┘
```

Required controls:

- Body type and rig profile
- Category tabs
- Part and weapon grids
- Search and tags
- Compatible-only filter
- Palette editor
- Direction selector
- Animation selector
- Play/pause and frame step
- Zoom
- Randomize all or selected categories
- Lock categories
- Reset category or character
- Undo/redo
- Save/load/duplicate/delete preset
- Export
- Validation status

## 13.8 Character Validation

Validate:

- Required slots
- Body/rig compatibility
- Direction and animation coverage
- Layer ordering
- Palette channels
- Missing assets
- Duplicate IDs
- Weapon compatibility
- Hand-pose availability
- Export support
- Runtime support

## 13.9 Character-Creator Scale Acceptance

The production sample must contain enough validated parts to create at least 100 visibly distinct valid characters, including at least:

- 2 body types
- 10 heads per body type
- 20 hairstyles
- 10 facial-hair options
- 20 torso options
- 15 leg options
- 10 footwear options
- 15 headwear options
- 15 accessories
- 20 validated weapons
- 10 curated complete presets

The count alone is not sufficient. A uniqueness report and visual sample grid are required.

---

# 14. Weapon and Equipment Pose Studio

This subsystem is a foundation requirement. It must not be postponed until after animation and character creation, because rig, slot, timeline, facing-grid, and export architecture all depend on it.

## 14.1 Required Outcome

A user must be able to import, configure, equip, remove, and replace weapons without modifying core code. The system must position the shoulders, upper arms, elbows, forearms, wrists, hands, and optional fingers correctly for each weapon, body type, direction, stance, and animation.

The system must support both automatic solving and authored overrides. Automatic solving provides a usable starting pose; authored profiles provide exact production quality.

## 14.2 Weapon Interaction Families

The core registry must include:

- Unarmed
- Fist/gauntlet/claw
- One-handed melee
- Two-handed melee
- Polearm/spear
- Staff
- One-handed firearm
- Two-handed firearm
- Shoulder-fired weapon
- Bow
- Crossbow
- Slingshot
- Shield
- Dual wield
- Paired weapon set
- Throwable weapon
- Flexible whip/chain/flail
- Carried tool or instrument
- Lantern or prop
- Floating/orbiting weapon
- Transforming/multi-state weapon
- Mounted/turret weapon
- Back, hip, chest, and custom holster
- Left-handed, right-handed, and ambidextrous variants
- Custom plugin-defined family

## 14.3 Weapon Definition Schema

```text
schema_version
weapon_id
display_name
category
interaction_family
asset_set_id
facing_grid_id
default_scale
handedness
dominant_hand
primary_grip_id
secondary_grip_id
optional_grip_ids
guard_point
stock_point
shoulder_contact_point
string_anchor_points
muzzle_point
projectile_origin
blade_root
blade_tip
impact_origin
throw_origin
holster_profiles
draw_path
sheath_path
collision_shapes
hitbox_profiles
pose_profile_ids
hand_pose_ids
animation_override_ids
constraint_plugin_id
runtime_behavior_metadata
body_type_compatibility
rig_profile_compatibility
tags
```

Fields irrelevant to a weapon family may be omitted, but required family fields must be validated.

## 14.4 Grip Definition

Each grip includes:

- Stable ID
- Position and rotation
- Allowed hand
- Grip role
- Required hand pose
- Position tolerance
- Angular tolerance
- Sliding allowance
- Release allowance
- Priority
- Direction override
- Animation override
- Body-type override
- Rig-profile override

## 14.5 Required Humanoid Arm Chain

A standard humanoid profile defines:

```text
clavicle_left
upper_arm_left
forearm_left
wrist_left
hand_left
hand_pose_slot_left

clavicle_right
upper_arm_right
forearm_right
wrist_right
hand_right
hand_pose_slot_right
```

Optional shoulder helpers, palm bones, twist bones, finger bones, and hand sprites are supported.

## 14.6 Explicit Drive Modes

Cyclic dependencies must be prevented by choosing one evaluation mode.

### Mode A — Primary-Hand Driven

- Primary hand or socket drives the weapon.
- Secondary hand solves to a grip on the weapon.
- Appropriate for swords, pistols, and many rifles.

### Mode B — Weapon-Controller Driven

- A weapon controller drives the weapon.
- Both hands solve to weapon grips.
- Appropriate for heavy weapons, precise two-hand poses, and mounted devices.

### Mode C — Body-Socket Driven

- Weapon attaches to a back, hip, shoulder, chest, or custom socket.
- Hands are free or optionally constrained.
- Appropriate for holstered and carried equipment.

### Mode D — Flexible/Path Driven

- A curve, chain, or segment solver drives the weapon.
- One or more handles attach to hands or world targets.
- Appropriate for whips, chains, flails, ropes, and slings.

### Mode E — Floating/World Driven

- Weapon moves independently of the hands.
- Hands may point, cast, or remain free.
- Appropriate for magical, telekinetic, and orbiting equipment.

### Mode F — Custom Plugin

- A plugin implements the documented constraint interface.
- It may add authoring controls and runtime data.
- Core code remains unchanged.

## 14.7 Automatic Arm and Hand Solver

Evaluation order:

1. Resolve body type, rig profile, direction, animation, and weapon state.
2. Select the drive mode.
3. Resolve the weapon transform.
4. Resolve primary and secondary grip targets.
5. Select hand-pose sprites or finger poses.
6. Apply clavicle and shoulder allowance.
7. Solve upper arm and forearm using two-bone IK.
8. Apply elbow pole targets and preferred bend directions.
9. Enforce joint limits.
10. Apply wrist orientation.
11. Detect unreachable or unstable solutions.
12. Apply fallback or authored override.
13. Evaluate z-order and visibility.
14. Produce diagnostics.

## 14.8 Pose Profile Resolution

Resolve profiles in this order:

```text
weapon + body type + rig + direction + animation exact override
→ weapon + body type + direction profile
→ weapon-specific generic profile
→ interaction-family profile
→ automatic solver fallback
```

Authored correction keys must layer on top of a base profile and remain editable.

## 14.9 Hand Pose Library

Initial named poses:

```text
open
relaxed
fist
sword_grip
pistol_grip
rifle_trigger
rifle_support
bow_hold
bow_draw
staff_grip
shield_handle
shield_strap
pinch
carry_under
carry_over
two_hand_heavy
```

Smooth rigs may drive finger bones or swap hand art. Pixel rigs may replace the entire hand or hand-and-forearm sprite.

## 14.10 Pixel-Art Weapon Mode

- Integer grip targets
- Optional discrete angle steps
- Direction-specific arm sprites
- Pre-drawn bend variants
- Hand overlays
- Explicit front/behind weapon rules
- Manual correction frames
- Nearest-neighbor rendering
- Zero-pixel visible grip gap in baked exports
- No accidental subpixel interpolation

## 14.11 Weapon Authoring Wizard

The production wizard must guide the user through:

1. Import art or select an existing asset set.
2. Choose interaction family.
3. Choose handedness and dominant hand.
4. Place primary grip.
5. Place secondary and optional grips.
6. Place muzzle, blade, impact, projectile, string, or throw points when relevant.
7. Configure holster sockets and draw/sheath paths.
8. Select hand poses.
9. Select or generate a pose profile.
10. Preview all body types.
11. Preview all directions.
12. Preview required animations.
13. Run reachability analysis.
14. Display grip gaps and joint-limit violations.
15. Create exact overrides for failures.
16. Validate.
17. Save and register.
18. Use the weapon immediately in the creator and animation studio.

The normal wizard path must require no code editing.

## 14.12 Equip, Remove, and Replace

Equipping must:

- Add visuals
- Activate grip constraints
- Select hand poses
- Apply stance/animation overlays
- Recompute z-order
- Activate weapon metadata and events

Unequipping must:

- Remove visuals
- Release constraints
- Restore unarmed hand poses
- Restore base arm animation
- Clear weapon-only events and hitboxes
- Recompute z-order
- Avoid dangling references

Replacing a weapon during playback must preserve the playhead and safely recompute constraints.

## 14.13 Dual Wield and Weapon Pairing

- Independent left/right definitions
- Pair profile
- Handedness resolution
- Collision and overlap diagnostics
- Separate attack tracks
- Combined animation override
- Runtime independent equip/unequip

## 14.14 Bow and String Requirements

- Bow-hand grip
- Draw-hand grip
- Top and bottom string anchors
- Draw amount parameter
- Arrow nock and projectile point
- String deformation
- Release event
- Direction/body-specific correction

## 14.15 Flexible Weapon Requirements

- Segment or curve representation
- Hand/world attachment handles
- Length constraint
- Collision approximation
- Authorable path keys
- Optional secondary physics
- Deterministic baked export
- Runtime fallback when physics is disabled

## 14.16 Weapon Validation

Block production registration or export when:

- A required grip is missing.
- A two-handed profile has no valid secondary grip.
- A hand cannot reach within limits.
- Elbows violate configured limits.
- Wrist angle exceeds tolerance.
- The weapon intersects the body beyond the profile allowance.
- A muzzle, blade, projectile, or string point is invalid.
- A required holster transform is absent.
- Direction cells are missing without a fallback.
- Required hand poses are unavailable.
- A custom runtime plugin is missing.
- Runtime export cannot reproduce the authored pose.

Diagnostic overlays:

- Grip gap
- Reach circles
- Joint-limit violations
- Shoulder stretch
- Wrist mismatch
- Body intersection
- Missing direction data
- Z-order conflict

## 14.17 Weapon Acceptance Matrix

Before release, create and verify these production examples:

1. One-handed sword
2. Dagger
3. Pistol
4. Revolver
5. Shield
6. Sword and shield
7. Dual pistols
8. Dual swords
9. Two-handed greatsword
10. Spear
11. Staff
12. Bow
13. Crossbow
14. Rifle
15. Shotgun
16. Shoulder launcher
17. Oversized hammer
18. Throwable axe
19. Whip or chain
20. Floating magical focus

Each must be verified for:

- Equip
- Unequip
- Runtime replacement
- Every required direction
- Every supported body type
- Idle
- Locomotion
- At least one use/attack animation
- Save/reopen
- Export/import
- Clean Godot runtime playback

---

# 15. Gameplay Metadata

Timeline-authorable data:

- Action points
- Sockets
- Hitboxes
- Hurtboxes
- Push boxes
- Detection areas
- Projectile spawn points
- Footstep points
- Camera cues
- Events
- Variables
- Tags
- Boolean, numeric, string, and color values
- Sound cues
- Animation notifies
- Custom plugin tracks

Supported collision shapes:

- Rectangle
- Circle
- Capsule
- Convex polygon
- Segment
- Bone-following shape

Runtime interpolation is allowed only for data types where interpolation is meaningful.

---

# 16. Audio, Lip Sync, and Reference Media

## 16.1 Audio

- Import supported audio formats
- Waveform cache
- Timeline placement
- Volume and pan
- Mute/solo
- Smooth scrubbing
- Playback-speed behavior
- Multiple simultaneous cues
- Runtime event export
- Missing-file repair

## 16.2 Lip Sync

- Viseme track
- Phoneme/viseme mapping
- Papagayo-compatible import where legally and technically practical
- Manual mouth-key editing
- Audio-aligned preview
- Character-map-compatible mouth variants
- Runtime export

## 16.3 Reference Media

- Video
- GIF
- Image sequence
- Still images
- Synced playhead
- Offset and speed
- Opacity, scale, and placement
- Frame step
- Hidden from export
- Missing-reference repair

---

# 17. Animation Blending, State Machines, and Rules

## 17.1 Blending

- Crossfade
- Additive layers
- Body-region masks
- Upper/lower body separation
- One-shot overlays
- Direction blend
- Aim offsets
- Weapon stance overlays
- Sync groups
- Time scaling
- Blend preview

## 17.2 State Machines

- States
- Transitions
- Conditions
- Exit times
- Priorities
- Interrupt rules
- Blend durations
- Nested machines
- Parameters
- Preview controls
- Runtime export

## 17.3 Interactive Rules

Conditions may evaluate:

- Current state
- Current time or time window
- Events
- Variables
- Tags
- Equipped weapon
- Direction
- Input parameter
- Body type
- Animation completion
- Random seed
- Plugin condition

Actions may:

- Change animation
- Blend to state
- Set variable
- Trigger event
- Change character map
- Equip or remove an item
- Change visibility
- Select facing cell
- Activate constraint
- Play sound

Rules require cycle protection, diagnostics, deterministic order, and runtime parity.

---

# 18. Multi-Project Character and Accessory Workflows

- Open multiple projects
- Link shared rigs
- Link shared animations
- Reference accessory projects
- Local overrides
- Dependency refresh
- Change detection
- Version compatibility report
- Multi-character preview
- Parent a prop or character to another
- Merge projects with conflict resolution
- Package dependencies for export

A broken or unavailable linked project must produce recoverable diagnostics rather than data loss.

---

# 19. Export and Native Godot Runtime

## 19.1 Open Runtime Package

Export:

- Rig
- Sprites and meshes
- Weights and deformation
- Animations and curves
- Character maps
- Facing grids
- Events and gameplay shapes
- Weapons and grips
- State machines and rules
- Version metadata

## 19.2 Baked Export

- PNG sequence
- Spritesheet
- Texture atlas
- GIF
- MP4 when a legally compatible encoder is available
- Transparent-capable video where supported
- Per-animation or shared crop
- Padding and extrusion
- Scale
- Nearest-neighbor
- Background color
- Loop count
- Frame rate
- Batch variants
- Batch weapons
- Cancellation and progress

## 19.3 Godot Export

Generate, where representable:

- Godot scenes
- Custom resources
- AnimationLibrary
- AnimationPlayer tracks
- AnimationTree/state-machine data
- Skeleton2D/Bone2D
- Polygon2D meshes and weights
- Sprite2D nodes
- Marker2D sockets
- Area2D hitboxes/hurtboxes
- Weapon resources
- Character appearance resources
- Runtime player configuration
- Import report

## 19.4 Runtime Plugin

The runtime must:

- Load compiled packages
- Reconstruct modular characters
- Evaluate tracks and curves
- Evaluate bones, constraints, and deformation
- Select facing-grid cells
- Blend animations
- Evaluate rules
- Fire events
- Update action points and collision shapes
- Equip and remove parts and weapons
- Solve weapon grips where enabled
- Use baked fallback where configured
- Provide deterministic playback
- Provide debug visualization
- Avoid editor-only dependencies

## 19.5 Clean Consumer Project Gate

A release candidate must export to a newly created Godot project containing no authoring-tool source. The consumer project must:

- Import successfully
- Run
- Play clips
- Change direction
- Blend states
- Equip and remove weapons
- Receive events
- Display debug hitboxes
- Save and reload an appearance

---

# 20. Performance, Accessibility, Security, and Licensing

## 20.1 Performance Targets

- 60 FPS normal canvas interaction
- Smooth timeline scrubbing
- No full-project reload for one changed asset
- Progressive image loading
- Lazy thumbnail loading
- Background cache generation
- 2,000+ parts
- 500+ weapons
- 500+ animation clips across linked projects
- 100-character batch generation
- Instrumented save, load, export, and solver timing

Benchmarks record project open time, time to interactive, memory, scrub latency, weapon-solver latency, weapon-switch latency, export throughput, and save duration.

## 20.2 Accessibility

- Mouse, keyboard, and modern controller
- Rebinding
- Visible focus
- Scalable UI
- High contrast
- Reduced motion
- Color-independent diagnostics
- Text representation for colors and numeric values
- Tooltips
- Destructive-action confirmation
- No focus traps
- Focus restoration

## 20.3 Security

- Never execute project data
- Prevent path traversal
- Sanitize archive extraction
- Validate media dimensions and decompression limits
- Restrict export paths to user choices
- Preserve unsupported plugin data where possible
- A broken plugin must not prevent project recovery

## 20.4 Licensing

- Do not copy proprietary Spriter code or assets
- Maintain dependency and asset license manifests
- Record third-party attribution
- Audit optional media encoders separately
- Publish the project-format documentation


---

# 21. Validation and Verification Infrastructure

Create these tools before feature development becomes broad:

```text
tools/verify_task
tools/loc_checker
tools/schema_validator
tools/evidence_checker
tools/stub_scanner
tools/roundtrip_runner
tools/visual_diff
tools/ui_reachability_audit
```

## 21.1 Stub Scanner

Scan production paths for:

- TODO
- FIXME
- placeholder
- not implemented
- dummy
- mock-only
- temporary return value
- disabled feature flag
- empty callback
- debug-only success path

Every finding must be classified. A text match is not automatically a failure, but no match may be ignored.

## 21.2 UI Reachability Audit

For every user-facing requirement:

1. Record the menu, shortcut, or button path.
2. Confirm the control is visible and enabled in the correct context.
3. Perform the action.
4. Confirm project data changes.
5. Undo.
6. Redo.
7. Save and restart.
8. Confirm the change remains.
9. Record evidence.

## 21.3 Visual Regression

Use deterministic sample projects and store expected, actual, and diff images for:

- Character assembly
- Direction cells
- Weapon grip alignment
- Arm and hand pose
- Mesh deformation
- Z-order
- Palette output
- Onion skins where feasible
- Baked spritesheets

## 21.4 Round-Trip Runner

Automate when possible:

```text
open sample
→ edit or load expected data
→ save
→ close process
→ reopen
→ export
→ create clean consumer project
→ import
→ run verification scene
→ capture logs and images
```

## 21.5 Failure Injection

Critical systems require controlled failure tests:

- Kill process during save
- Remove an asset
- Corrupt a manifest field
- Remove a runtime plugin
- Create a constraint cycle
- Create an unreachable two-hand grip
- Use an invalid export path
- Exceed a known resource threshold

---

# 22. Mandatory Codex Thread and Handoff Protocol

## 22.1 Exactly One Task Per Thread

Every implementation, verification, repair, audit, documentation, or release task must run in a new Codex thread.

A thread may work on one task ID only. It may not begin cleanup, a follow-up, the next task, or an unrelated fix after its task ends.

## 22.2 Thread Types

```text
IMPLEMENTATION
VERIFICATION
REPAIR
AUDIT
DOCUMENTATION
RELEASE
```

Implementation and verification must never occur in the same thread.

## 22.3 Required Handoff File

```text
docs/implementation/handoffs/<TASK_ID>_HANDOFF.md
```

Every thread creates its own handoff file. A different task must never reuse another task’s handoff.

## 22.4 Required Handoff Template

```markdown
# <TASK_ID> Handoff

## Thread Identity
- Task ID:
- Task title:
- Thread type:
- Status:
- Date:
- Repository:
- Branch:
- Starting commit:
- Ending commit:

## Scope
### In scope
### Out of scope

## Requirements Addressed
List requirement IDs.

## Repository Preflight
- Branch verified:
- Working tree verified:
- Previous handoff claims checked:
- Conflicts found:

## Files Created
Full repository-relative paths.

## Files Modified
Full repository-relative paths.

## Files Deleted
Full repository-relative paths.

## Work Performed
Describe only work actually performed.

## Real Behavior Demonstrated
Describe the production workflow actually used.

## Acceptance Criteria
For each criterion:
- PASS
- FAIL
- BLOCKED
- NOT TESTED

Include evidence paths.

## Automated Tests
- Exact command
- Result
- Relevant output

## Manual Verification
- Exact steps
- Expected
- Actual
- Evidence

## Persistence and Round Trip
- Save/reopen:
- Export/import:
- Clean consumer project:
- Evidence:

## Negative and Edge Cases
List each case and result.

## Stub and Reachability Scan
- Commands:
- Findings:
- Classification:

## LOC Compliance
- Files over 300 lines:
- Exception records:
- Split analysis:

## Known Issues
Do not hide warnings or limitations.

## Remaining Work
Write `None` only when nothing remains within this task’s scope.

## Out-of-Scope Findings
Record without fixing them in this thread.

## Traceability Updates
List changed requirement rows and statuses.

## Git Summary
- Commit:
- Push status:
- Remote branch:
- Uncommitted changes:

## Required Files for Next Thread
Exact paths.

## Next Task Recommendation
- Task ID:
- Thread type:
- Reason:

## New Thread Start Prompt
Provide a complete ready-to-paste prompt.
```

## 22.5 Implementation Thread Rule

An implementation thread may mark a requirement only:

```text
IMPLEMENTED_UNVERIFIED
BLOCKED
REJECTED
```

It may not self-approve as `VERIFIED`.

## 22.6 Verification Thread Rule

A verification thread must:

1. Read the prior handoff.
2. Verify branch, commit, and working tree.
3. Inspect the actual source.
4. Confirm production UI/API reachability.
5. Rerun automated tests.
6. Perform manual workflow checks.
7. Perform save/restart checks.
8. Perform export/import checks where relevant.
9. Exercise negative cases.
10. Run stub and LOC checks.
11. Update traceability.
12. Mark `VERIFIED` or fail the task and recommend a separate repair task.

It must not quietly make major repairs and still claim independent verification.

## 22.7 New Thread Start Prompt

```text
You are starting a new Codex thread for task <TASK_ID>.

Thread type:
<IMPLEMENTATION | VERIFICATION | REPAIR | AUDIT | DOCUMENTATION | RELEASE>

Repository:
<PATH_OR_URL>

Branch:
<BRANCH>

Before editing or reviewing:

1. Read:
   - docs/implementation/handoffs/<PREVIOUS_TASK_ID>_HANDOFF.md
   - docs/implementation/REQUIREMENTS_TRACEABILITY.md
   - docs/implementation/TASK_LEDGER.md
   - every architecture or rules file listed by the handoff

2. Verify:
   - current branch
   - latest commit
   - working tree status
   - required files exist
   - previous completion claims match repository state
   - claimed tests can be reproduced where applicable

3. Record any discrepancy before proceeding.

Your only task in this thread is:

<TASK_ID> — <TITLE>

In scope:
<SCOPE>

Out of scope:
<OUT_OF_SCOPE>

Acceptance criteria:
<CRITERIA>

Required evidence:
<EVIDENCE>

Rules:
- Work only on <TASK_ID>.
- Do not start another task.
- Do not claim completion from file existence or a passing test alone.
- Demonstrate behavior through the production workflow.
- Use real files and real export/import paths for integration evidence.
- Keep authored production files at or below 300 lines where practical.
- Record every necessary LOC exception.
- Do not add placeholders or fake implementations.
- Update traceability and the task ledger.
- Before stopping, create docs/implementation/handoffs/<TASK_ID>_HANDOFF.md.
- End with the mandatory thread-closure notice.
```

## 22.8 Mandatory Closure Notice

```text
THREAD CLOSED — NEW CODEX THREAD REQUIRED

Task <TASK_ID> has ended with status <STATUS> as recorded in:
docs/implementation/handoffs/<TASK_ID>_HANDOFF.md

Do not begin another implementation, verification, repair, audit, documentation, release, or follow-on task in this conversation.

Start a new Codex thread and paste the NEW THREAD START PROMPT from that handoff file.
```

---

# 23. Task Ledger

Maintain:

```text
docs/implementation/TASK_LEDGER.md
```

Each row records:

- Task ID
- Title
- Thread type
- Dependencies
- Branch and commit
- Status
- Handoff path
- Evidence path
- Requirement IDs
- Recommended next task

Tasks may not skip unverified dependencies.

---

# 24. Implementation Milestones and Codex Tasks

Every line below is a separate Codex thread and requires its own handoff. Each milestone ends with a separate independent verification thread.

## Milestone 0 — Governance and Evidence

- `GOV-001` Initialize repository structure and authoritative rules
- `GOV-002` Create requirement IDs and traceability matrix
- `GOV-003` Create task ledger and handoff templates
- `GOV-004` Implement LOC checker and exception registry
- `GOV-005` Implement stub scanner
- `GOV-006` Implement evidence-bundle checker
- `GOV-007` Define dependency and asset license manifests
- `GOV-008` Create baseline sample and malformed fixtures
- `QA-GOV-001` Verify governance controls in a clean thread

## Milestone 1 — Application Shell

- `APP-001` Bootstrap the Godot application and startup diagnostics
- `APP-002` Implement main window and dock layout
- `APP-003` Implement workspace manager
- `APP-004` Implement command palette and shortcut registry
- `APP-005` Implement dirty state and application-state service
- `APP-006` Implement diagnostics drawer
- `APP-007` Implement theme and DPI scaling
- `APP-008` Implement keyboard/controller focus framework
- `APP-009` Implement startup and recent-project screen
- `QA-APP-001` Verify application-shell workflows

## Milestone 2 — Project Format and Persistence

- `DOC-001` Define project-manifest schema
- `DOC-002` Implement stable ID service
- `DOC-003` Implement deterministic serialization
- `DOC-004` Implement transactional save
- `DOC-005` Implement project load and diagnostics
- `DOC-006` Implement rolling backups
- `DOC-007` Implement autosave and recovery journal
- `DOC-008` Implement schema migrations
- `DOC-009` Implement corrupt-project recovery
- `DOC-010` Implement clone and save-as
- `QA-DOC-001` Verify save, restart, migration, and recovery

## Milestone 3 — Asset Library

- `AST-001` Implement asset registry
- `AST-002` Implement image importer
- `AST-003` Implement pixel-art import profile
- `AST-004` Implement smooth-art import profile
- `AST-005` Implement thumbnail cache
- `AST-006` Implement asset browser
- `AST-007` Implement search, tags, favorites, and filters
- `AST-008` Implement drag-and-drop
- `AST-009` Implement missing-file repair
- `AST-010` Implement external-file refresh
- `AST-011` Implement duplicate and unused-asset reports
- `AST-012` Implement batch metadata editing
- `QA-AST-001` Verify real asset workflows

## Milestone 4 — Canvas and Command System

- `CAN-001` Implement canvas camera, pan, and zoom
- `CAN-002` Implement selection and overlap cycling
- `CAN-003` Implement transform gizmos
- `CAN-004` Implement numeric transform editing
- `CAN-005` Implement pivots and anchors
- `CAN-006` Implement snapping, grid, rulers, and guides
- `CAN-007` Implement lock, hide, solo, and selection sets
- `CAN-008` Implement z-order editing
- `CAN-009` Implement copy, paste, duplicate, and clone subtree
- `CAN-010` Implement central command and undo system
- `CAN-011` Implement undo-history UI
- `CAN-012` Implement pixel-perfect canvas mode
- `QA-CAN-001` Verify canvas, commands, and persistence

## Milestone 5 — Rigging

- `RIG-001` Define rig, bone, and slot schemas
- `RIG-002` Implement bone creation and transform editing
- `RIG-003` Implement hierarchy panel
- `RIG-004` Implement rest pose
- `RIG-005` Implement reparent and reorder
- `RIG-006` Implement groups, colors, locks, and visibility
- `RIG-007` Implement left/right mirror hierarchy
- `RIG-008` Implement slot authoring
- `RIG-009` Implement inheritance controls
- `RIG-010` Implement rig templates
- `RIG-011` Implement rig validator
- `RIG-012` Verify rig save/reload internally
- `QA-RIG-001` Independently verify rigging

## Milestone 6 — Constraints and IK

- `IK-001` Define constraint interface and evaluation order
- `IK-002` Implement transform constraints
- `IK-003` Implement aim/look-at
- `IK-004` Implement distance and angle limits
- `IK-005` Implement two-bone IK
- `IK-006` Implement pole targets
- `IK-007` Implement animatable IK influence
- `IK-008` Implement pinned/contact IK
- `IK-009` Implement cycle detection
- `IK-010` Implement diagnostics
- `IK-011` Implement bake-to-keys
- `QA-IK-001` Verify constraint solving and failure cases

## Milestone 7 — Timeline and Animation Data

- `ANM-001` Define clip, track, key, and property schemas
- `ANM-002` Implement clip browser
- `ANM-003` Implement dope sheet
- `ANM-004` Implement per-object tracks
- `ANM-005` Implement key creation and auto-key
- `ANM-006` Implement multi-key editing
- `ANM-007` Implement timing scale, stretch, and ripple
- `ANM-008` Implement cross-clip copy/paste
- `ANM-009` Implement image-swap tracks
- `ANM-010` Implement visibility tracks
- `ANM-011` Implement animatable z-order
- `ANM-012` Implement playback and looping
- `ANM-013` Implement markers and regions
- `ANM-014` Implement timeline persistence
- `QA-ANM-001` Verify timeline behavior through the UI

## Milestone 8 — Curves and Onion Skinning

- `CRV-001` Implement stepped and linear interpolation
- `CRV-002` Implement smooth and cubic interpolation
- `CRV-003` Implement Bézier curves
- `CRV-004` Implement angle interpolation controls
- `CRV-005` Implement curve editor
- `CRV-006` Implement curve presets
- `CRV-007` Implement curve bake and simplification
- `ONI-001` Implement adjacent-frame onion skins
- `ONI-002` Implement key and pinned onion skins
- `ONI-003` Implement interactive onion editing
- `ONI-004` Implement obstruction cycling
- `QA-CRV-001` Verify curves and onion skins visually

## Milestone 9 — Mesh and Deformation

- `MSH-001` Define mesh and weight schemas
- `MSH-002` Implement automatic mesh generation
- `MSH-003` Implement manual mesh editing
- `MSH-004` Implement UV editing
- `MSH-005` Implement bone binding
- `MSH-006` Implement weight painting
- `MSH-007` Implement normalization and mirroring
- `MSH-008` Implement extreme-pose preview
- `DEF-001` Implement deformation handles
- `DEF-002` Implement attractor solver
- `DEF-003` Implement soft drag
- `DEF-004` Implement animatable deformation
- `DEF-005` Implement bake
- `DEF-006` Implement deformation validator
- `QA-DEF-001` Verify deformation quality and runtime parity

## Milestone 10 — Facing Grid

- `FAC-001` Define facing-grid schema
- `FAC-002` Implement direction-set editor
- `FAC-003` Implement cell asset assignment
- `FAC-004` Implement filename-based batch placement
- `FAC-005` Implement left/right slot swapping
- `FAC-006` Implement mirroring
- `FAC-007` Implement hard direction switching
- `FAC-008` Implement optional sprite crossfade
- `FAC-009` Implement deformable-mesh direction blending
- `FAC-010` Implement direction-scrub preview
- `FAC-011` Implement missing-cell diagnostics
- `FAC-012` Implement pixel no-crossfade mode
- `QA-FAC-001` Verify all direction workflows

## Milestone 11 — Poses and Retargeting

- `POS-001` Define pose schema
- `POS-002` Implement save/apply pose
- `POS-003` Implement mirror pose
- `POS-004` Implement pose blending
- `POS-005` Implement additive poses
- `POS-006` Implement pose thumbnails
- `POS-007` Implement sketch-to-pose assistance
- `RET-001` Define skeleton profiles
- `RET-002` Implement bone mapping
- `RET-003` Implement proportion compensation
- `RET-004` Implement preview
- `RET-005` Implement batch retarget
- `RET-006` Implement correction layers
- `QA-POS-001` Verify pose and retarget workflows

## Milestone 12 — Weapon Data and Drive Modes

- `WPN-001` Define weapon, grip, and pose-profile schemas
- `WPN-002` Implement interaction-family registry
- `WPN-003` Implement weapon asset registration
- `WPN-004` Implement grip editor
- `WPN-005` Implement muzzle, blade, projectile, string, and impact points
- `WPN-006` Implement holster and draw/sheath sockets
- `WPN-007` Implement hand-pose library
- `WPN-008` Implement primary-hand drive mode
- `WPN-009` Implement weapon-controller drive mode
- `WPN-010` Implement body-socket drive mode
- `WPN-011` Implement flexible/path drive mode
- `WPN-012` Implement floating/world drive mode
- `WPN-013` Implement custom weapon plugin interface
- `QA-WPN-001` Verify schemas, authoring, and drive modes

## Milestone 13 — Weapon Arm and Hand Solver

- `SOL-001` Implement clavicle and shoulder allowance
- `SOL-002` Implement arm two-bone solve
- `SOL-003` Implement elbow pole and bend preferences
- `SOL-004` Implement wrist orientation
- `SOL-005` Implement hand-pose selection
- `SOL-006` Implement two-hand grip solve
- `SOL-007` Implement joint limits
- `SOL-008` Implement unreachable-grip diagnostics
- `SOL-009` Implement pose-profile override hierarchy
- `SOL-010` Implement body-type offsets
- `SOL-011` Implement direction offsets
- `SOL-012` Implement animation offsets
- `SOL-013` Implement pixel discrete solver
- `SOL-014` Implement grip-gap overlays
- `SOL-015` Implement solver instrumentation
- `QA-SOL-001` Verify hands and arms visually and numerically

## Milestone 14 — Weapon Wizard and Runtime Equipment

- `WPA-001` Implement weapon authoring wizard
- `WPA-002` Implement all-body preview
- `WPA-003` Implement all-direction preview
- `WPA-004` Implement animation-coverage preview
- `WPA-005` Implement reachability batch analysis
- `WPA-006` Implement weapon validation report
- `WPA-007` Implement equip
- `WPA-008` Implement unequip and constraint release
- `WPA-009` Implement live weapon replacement
- `WPA-010` Implement dual-wield pairing
- `WPA-011` Implement shield pairing
- `WPA-012` Implement bow/string workflow
- `WPA-013` Implement flexible weapon sample
- `WPA-014` Implement transforming states
- `WPA-015` Implement holster/draw/sheath workflow
- `QA-WPA-001` Verify the 20-weapon acceptance matrix

## Milestone 15 — Character Creator

- `CHR-001` Define part and body-type schemas
- `CHR-002` Implement slot registry
- `CHR-003` Implement part registry
- `CHR-004` Implement character assembly
- `CHR-005` Implement compatibility engine
- `CHR-006` Implement conflict explanations
- `CHR-007` Implement category and part browser
- `CHR-008` Implement palettes and color channels
- `CHR-009` Implement character maps and stacking
- `CHR-010` Implement outfit and equipment sets
- `CHR-011` Implement deterministic randomizer
- `CHR-012` Implement category locks and rarity weights
- `CHR-013` Implement presets
- `CHR-014` Implement batch NPC generation
- `CHR-015` Integrate weapons and pose profiles
- `CHR-016` Complete creator undo/redo
- `QA-CHR-001` Verify at least 100 distinct valid characters

## Milestone 16 — Gameplay Metadata

- `GMD-001` Implement action-point tracks
- `GMD-002` Implement event tracks
- `GMD-003` Implement variables and tags
- `GMD-004` Implement hitbox tracks
- `GMD-005` Implement hurtbox tracks
- `GMD-006` Implement additional collision shapes
- `GMD-007` Implement debug visualization
- `GMD-008` Implement runtime event delivery
- `QA-GMD-001` Verify gameplay metadata and runtime timing

## Milestone 17 — Audio and References

- `MED-001` Implement audio import
- `MED-002` Implement waveform cache
- `MED-003` Implement sound-cue tracks
- `MED-004` Implement smooth scrubbing
- `MED-005` Implement viseme tracks
- `MED-006` Implement lip-sync import
- `MED-007` Implement video references
- `MED-008` Implement GIF references
- `MED-009` Implement image-sequence references
- `MED-010` Implement synchronized playhead
- `QA-MED-001` Verify audio and reference workflows

## Milestone 18 — Blending, States, and Rules

- `BLD-001` Implement crossfades
- `BLD-002` Implement additive layers
- `BLD-003` Implement body masks
- `BLD-004` Implement sync groups
- `BLD-005` Implement weapon stance overlays
- `STM-001` Define state-machine schema
- `STM-002` Implement state-machine editor
- `STM-003` Implement transitions
- `STM-004` Implement nested machines
- `RUL-001` Implement rule graph
- `RUL-002` Implement events and time windows
- `RUL-003` Implement rule actions
- `RUL-004` Implement cycle protection
- `RUL-005` Implement deterministic evaluation
- `QA-RUL-001` Verify blending, states, and rules

## Milestone 19 — Multi-Project Workflows

- `LNK-001` Implement linked-project references
- `LNK-002` Implement shared-character workflow
- `LNK-003` Implement shared-accessory workflow
- `LNK-004` Implement dependency refresh
- `LNK-005` Implement local overrides
- `LNK-006` Implement merge and conflict resolution
- `LNK-007` Implement dependency packaging
- `LNK-008` Implement multi-character preview
- `QA-LNK-001` Verify linked projects and recovery

## Milestone 20 — Export

- `EXP-001` Define runtime package format
- `EXP-002` Implement runtime-data exporter
- `EXP-003` Implement PNG-sequence export
- `EXP-004` Implement spritesheet export
- `EXP-005` Implement atlas packing
- `EXP-006` Implement GIF export
- `EXP-007` Implement video export
- `EXP-008` Implement crop, padding, and extrusion
- `EXP-009` Implement batch character variants
- `EXP-010` Implement batch weapon variants
- `EXP-011` Implement cancellation and progress
- `EXP-012` Implement export validator
- `QA-EXP-001` Verify every export by opening the output

## Milestone 21 — Godot Runtime and Importer

- `GDT-001` Define Godot resource mappings
- `GDT-002` Implement runtime-package importer
- `GDT-003` Implement modular animation player
- `GDT-004` Implement Skeleton2D reconstruction
- `GDT-005` Implement mesh/deformation runtime
- `GDT-006` Implement facing-grid runtime
- `GDT-007` Implement events and action points
- `GDT-008` Implement hitbox/hurtbox runtime
- `GDT-009` Implement equipment runtime
- `GDT-010` Implement weapon-solver runtime
- `GDT-011` Implement state/rule runtime
- `GDT-012` Implement appearance save/load example
- `GDT-013` Implement clean consumer sample
- `GDT-014` Write runtime API documentation
- `QA-GDT-001` Verify clean-project round trip

## Milestone 22 — Recovery, Scale, Accessibility, and Packaging

- `REC-001` Implement recovery browser
- `REC-002` Verify interrupted-save recovery
- `PRF-001` Implement profiler overlay
- `PRF-002` Implement progressive project loading
- `PRF-003` Implement lazy thumbnails
- `PRF-004` Optimize timeline scrubbing
- `PRF-005` Optimize weapon solver
- `PRF-006` Run large-project stress suite
- `ACC-001` Complete keyboard navigation
- `ACC-002` Complete controller navigation
- `ACC-003` Implement reduced motion and contrast
- `ACC-004` Perform focus and label audit
- `QA-PRF-001` Verify recovery, performance, and accessibility

## Milestone 23 — Samples, Documentation, and Release

- `SMP-001` Create validated humanoid sample rig
- `SMP-002` Create pixel-art sample rig
- `SMP-003` Create smooth deformable sample rig
- `SMP-004` Create 100-character sample library
- `SMP-005` Create 20-weapon sample library
- `SMP-006` Create animation and gameplay-metadata sample
- `DOCS-001` Write user manual
- `DOCS-002` Write asset-authoring manual
- `DOCS-003` Write weapon-authoring manual
- `DOCS-004` Write plugin API manual
- `REL-001` Complete license and attribution audit
- `REL-002` Package Windows build
- `REL-003` Run clean-machine smoke test
- `REL-004` Create release notes and known issues
- `QA-REL-001` Perform final independent release audit

---

# 25. Milestone Gate Rules

A milestone may close only when:

- Every task has a dedicated handoff.
- Every required evidence bundle exists.
- The independent QA task is `VERIFIED`.
- Traceability rows are updated.
- No blocking issue remains.
- No unapproved file over 300 lines remains.
- Real UI/API workflows were performed.
- Save/restart was tested.
- Export/import was tested where applicable.
- Acceptance criteria were not weakened after implementation to hide a failure.

When QA fails:

1. Preserve the failed QA handoff.
2. Create a new repair task.
3. Perform repair in a new thread.
4. Run a new verification task in another new thread.
5. Preserve all prior evidence and history.

---

# 26. Required End-to-End Scenarios

## E2E-001 — First Character

- Create project
- Import body parts
- Assemble character
- Create rig
- Author idle and walk
- Save
- Restart
- Reopen
- Export to clean Godot project
- Verify playback

## E2E-002 — Character Variant

- Create character map
- Swap hair, outfit, and colors
- Save preset
- Export two variants sharing animation data
- Switch appearance at runtime

## E2E-003 — One-Handed Sword

- Import sword
- Set grip
- Select hand pose
- Preview eight directions
- Animate attack
- Add hitbox
- Export
- Runtime equip and remove
- Confirm hand remains on grip

## E2E-004 — Two-Handed Rifle

- Set primary grip, secondary grip, stock, and muzzle
- Solve both arms
- Aim in eight directions
- Animate recoil and reload
- Save/reopen
- Export
- Runtime replace with pistol
- Confirm no dangling constraints

## E2E-005 — Bow

- Configure bow hand, draw hand, string anchors, and projectile point
- Animate draw and release
- Validate hand/string contact
- Export
- Verify runtime event timing

## E2E-006 — Pixel Weapon

- Use pixel body
- Use pre-drawn arm and hand variants
- Equip weapon
- Verify integer alignment
- Bake spritesheet
- Confirm zero-pixel grip gap

## E2E-007 — Deformable Character

- Create mesh
- Paint weights
- Add attractors
- Animate deformation
- Change facing direction
- Export runtime data
- Confirm visual match

## E2E-008 — Crash Recovery

- Edit project
- Interrupt save
- Restart
- Recover
- Compare against last manual save
- Confirm no silent loss

## E2E-009 — 100 Characters

- Generate 100 seeded appearances
- Validate all
- Generate uniqueness report
- Save/reopen
- Batch export samples
- Record performance

## E2E-010 — Invalid Weapon

- Create a two-hand weapon with unreachable grip
- Confirm blocking diagnostic
- Confirm export is prevented
- Correct the pose
- Revalidate
- Export successfully

## E2E-011 — Undo and Redo Across Systems

- Change character part
- Move bone
- edit mesh
- add key
- move grip
- add hitbox
- undo every action
- redo every action
- save/restart
- confirm final state

## E2E-012 — Linked Accessory Project

- Link an accessory project
- Attach an item
- update source project
- refresh dependency
- preserve local override
- package and export

---

# 27. Final Definition of Done

The product is complete only when:

- The practical Spriter Pro baseline is implemented and independently verified.
- The selected Spriter 2-style capabilities in this plan are implemented and independently verified.
- The character creator produces at least 100 distinct valid appearances.
- A normal new weapon can be added without editing core code.
- Plugin-defined constraints support novel weapon behavior.
- Arms and hands align with grips across required body types, directions, stances, and animations.
- Pixel output has no unintended filtering, subpixel drift, or visible grip gap.
- Smooth rigs support bones, IK, meshes, weights, and deformation.
- Timeline editing, curves, events, sounds, and gameplay metadata are real authoring features.
- Facing grids work for character parts, meshes, and weapons.
- Save, close, restart, export, and clean-project import preserve required behavior.
- Runtime equipment switching works.
- Undo/redo covers every major edit class.
- Crash recovery is verified through interruption.
- Accessibility and controller navigation are usable.
- Performance is measured and meets approved targets.
- Every mandatory traceability row is `VERIFIED`.
- Every task has its own handoff file.
- Every implementation claim has independent verification evidence.
- No blocking placeholder remains.
- No unapproved LOC exception remains.
- A clean Windows build passes a clean-machine smoke test.
- User, asset-authoring, weapon-authoring, runtime, and plugin documentation are complete.

---

# 28. Required First Task

Begin with:

```text
GOV-001 — Initialize repository structure and authoritative rules
```

Do not begin application feature implementation until traceability, evidence, LOC enforcement, one-task-per-thread handoffs, and independent verification rules are operational.

---

# 29. Research Basis

This specification was informed by publicly documented Spriter Pro capabilities, Spriter 2 beta updates available through July 2026, and Godot’s documented 2D skeleton and animation systems.

Primary references:

- Spriter Pro User Manual: https://brashmonkey.com/spriter_manual/Spriter_Manual.pdf
- Spriter Pro product information: https://brashmonkey.com/forum/index.php?/store/product/3-spriter-pro/
- Spriter 2 Beta 2026-04-26: https://brashmonkey.com/forum/index.php?/topic/41051-spriter-2-beta-release-20260426/
- Spriter 2 news, including the 2026-07-26 beta feature list: https://steamcommunity.com/app/332360/allnews/
- Godot 2D skeleton documentation: https://docs.godotengine.org/en/latest/tutorials/animation/2d_skeletons.html
- Godot AnimationTree documentation: https://docs.godotengine.org/en/latest/tutorials/animation/animation_tree.html

The project must independently implement concepts and workflows. It must not copy proprietary source code, project data, examples, or copyrighted art from Spriter.
