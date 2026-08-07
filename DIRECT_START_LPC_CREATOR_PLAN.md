# Direct-Start LPC Creator — Phased Delivery and Risk Plan

> **Scope decision:** This is five separately shippable projects, not one
> feature. Each phase has a dependency, a risk level, and an exit gate. A later
> phase must not silently expand the scope or delay an earlier release.

## Product outcome

Open Paper Quest and immediately resume the most recent editable LPC character
or create a new one from a compatible base body. The first release focuses on
fast, license-aware character assembly. Pixel editing, clip authoring, and
deformation arrive only after their foundations and technical gates are proven.

The local LPC source remains outside Git. It is a development/release input,
not repository content.

## Delivery map

| Phase | Shippable outcome | Depends on | Risk | Exit gate |
| --- | --- | --- | --- | --- |
| 0. Contracts and feasibility | Validated data, licensing, rendering, migration, and performance decisions | None | **High** | Catalog and renderer prototypes pass their test gates. |
| 1. Direct start and library foundation | A user can start/resume an LPC project from a validated local library | 0 | **High** — licensing and data integrity | A pack-locked profile opens, saves, resumes, and exports complete credits. |
| 2. Focused creator | Three-column base-body creator over the phase 1 data model | 1 | **Medium** — UX and catalog scale | A user can assemble, palette, reset, save, and export a compatible character. |
| 3. Pixel editor | Project-owned pixel/cel editing without modifying bundled source art | 1, 2 | **Medium–high** — media, storage, history | Editing, undo, autosave, reload, and PNG round-trip are lossless. |
| 4. Clips and keyframes | Whole-character and per-layer animation on full LPC sheets and custom cels | 1–3 | **Medium** — timeline/data coupling | Clips replay identically after save/reopen and export. |
| 5. Deformation | Per-layer deformation only after a pixel-art feasibility spike; composite/cage/weights are gated follow-ons | 0, 1, 4 | **Very high** — rendering, usability, performance | A written go/no-go decision approves each successive deformation level. |

Phase 0 can begin immediately. Phase 5 research may run in parallel against
fixtures, but it does not block phases 1–4 and it does not commit the product
to full weight painting or bone binding.

## Phase 0 — contracts, constraints, and feasibility

This phase resolves the architectural questions before product UI commits to an
implementation.

### Rendering baseline

- This is a desktop Godot application, so the LPC preview uses Godot Canvas2D
  and CanvasItem rendering, not WebGL. The existing compatibility renderer and
  nearest-filter pixel path remain the baseline.
- The composite preview is rendered through a dedicated LPC composite renderer
  backed by CanvasItem/SubViewport resources as needed. It must support
  composited layers without changing source files.
- Phase 0 defines the supported-hardware baseline and measures catalog
  filtering, thumbnail display, layer composition, and live preview at the
  1280×720 authoring baseline. Performance budgets are set from those measured
  results, then enforced in later load tests.

### Project schema and migrations

- Introduce a versioned LPC project profile with an explicit LPC schema version,
  migration registry, migration fixtures, and backup-before-migrate behavior.
- Loading an older LPC profile runs a deterministic migration to the newest
  profile version; saves always write the latest version.
- Legacy non-LPC projects remain untouched. Older dashboard-flow LPC projects
  use an explicit **Migrate to Direct-Start LPC** flow that previews changes and
  creates a backup; no project is silently converted at launch.

### Library and license contracts

- Define LpcAssetCatalog, LpcProjectProfile, LpcCompositeRenderer, and a
  versioned asset-record schema before UI work begins.
- Every catalog record includes asset ID, source path, SHA-256, image
  dimensions, sheet/frame metadata, palette family, license, attribution,
  source record, compatibility tags, and commercial eligibility.
- Validate both the library root manifest and each distributable asset. Missing,
  corrupted, resized, or incorrectly attributed files fail library intake and
  release-pack builds with a precise diagnostic.
- Build the Personal Full and Commercial-safe packs from the same catalog:
  - **Personal Full** exposes eligible source assets only after the required
    per-asset acceptance is recorded.
  - **Commercial-safe** accepts only the stated approved licenses
    (CC0, CC-BY, and OGA-BY) and fails closed for missing, GPL, CC-BY-SA-only,
    or otherwise disallowed records.
- Add an automated license-compliance gate. A release or export cannot proceed
  unless every selected asset has a valid catalog record, required acceptance,
  and exportable credit entry. Human license review remains mandatory before a
  public release.

### Deformation feasibility spike

Create a disposable prototype using representative LPC-sized fixtures. It
compares the pixel-safe path below with a clearly separate smooth-art path and
records output, performance, and usability findings. The spike is not a promise
to ship cages, soft drag, bone binding, or weight painting.

The spike must answer:

1. Can a layer be mesh-warped at native resolution with nearest sampling,
   grid-snapped controls, no new colors, and no anti-aliased edges?
2. Does preview output match baked/exported output exactly in pixel-safe mode?
3. Are holes, overlaps, and distortion acceptable for the intended LPC art?
4. Can the result meet the phase 0 performance budget with representative
   layered characters?

If any answer is no, phase 5 falls back to bone/rigid-piece transforms and
discrete pixel-safe offsets. It does not grow into an unbounded custom mesh
editor.

## Phase 1 — direct start and library foundation

**Goal:** A validated LPC project opens directly into useful character work
without the old dashboard as a required first step.

- Copy only distributable LPC data into local-only third_party/lpc: spritesheets,
  generated catalog metadata, sheet/palette definitions, and credits. Exclude
  the old generator's UI, code, caches, and dependencies.
- Keep local source data ignored by Git. Track only a small source manifest and
  expected catalog signature so developers and release builds fail clearly when
  the library is absent or incorrect.
- On launch, resume the last editable LPC project. On first run and New Project,
  show only a pack/base-body chooser, then create a persistent profile.
- Generate My Character, My Character 2, and later names from a monotonic,
  profile-indexed sequence. Deleted or archived names are never reused; UUIDs,
  not labels, are the durable identity.
- Lock each project to its selected pack and compatible base family. Pack
  selection, source records, palettes, full-sheet references, credits,
  acceptance records, and project-owned overrides belong in the profile.
- Preserve non-LPC projects in Open Project and Advanced Studio. The user
  decides whether to migrate an older LPC project through the explicit wizard.

**Release gate:** library intake, pack filtering, resume, naming, migration,
autosave/recovery, and license/export tests pass on a full local catalog.

## Phase 2 — focused creator

**Goal:** Replace the dashboard-first LPC path with a fast, understandable
creator that depends only on phase 1 contracts.

- Build the Paper Quest-styled three-column creator: base/features on the left,
  a live front-facing composite preview in the center, and clothing/equipment
  on the right.
- Add searchable, virtualized thumbnail pickers that show only compatible
  assets. Keep full LPC sheets as the authoritative animation source behind the
  front preview.
- Use native LPC palettes with nearest filtering and palette-safe controls.
- The footer exposes Undo, Reset Body, Export, Credits, and clear Saving/Saved
  status.
- Reset Body is a named, one-step global undoable command. It asks for
  confirmation only when it would discard custom body overrides or cels; a
  standard starter-body reset stays immediate and undoable.
- Treat 1280×720 as the minimum authoring baseline, not a fixed-size-only UI.
  The creator must reflow or scale on larger/HiDPI windows and preserve usable
  controls at the supported minimum.

**Release gate:** a new user can choose a pack/base, assemble a compatible
front preview, change palettes, reset safely, resume after restart, and export
the correct credits.

## Phase 3 — pixel editor and project-owned artwork

**Goal:** Let artists make controlled pixel edits while preserving bundled LPC
assets and their provenance.

- Use copy-on-first-edit into content-addressed project-owned storage. A clone
  stores its source asset ID, source hash, original license/attribution,
  derivative relationship, and current content hash.
- Deduplicate identical project-owned copies by content hash. Autosave records
  document revisions, not a new bitmap per autosave. Storage accounting and a
  user-visible budget warn before growth becomes a problem; cleanup never
  removes recoverable assets without an explicit user action.
- Ship the pixel editor in two milestones:
  1. **Pixel-canvas core:** layers, cels, pencil, eraser, palette, transparent
     pixels, native-grid zoom, PNG import/export, and atomic stroke undo.
  2. **Production editing:** fill, selection, move, onion skin, frame timeline,
     and whole-character/per-layer cel creation.
- Use the single document command history described below. A brush stroke,
  fill, selection move, import, or cel operation becomes one named atomic
  command or macro rather than a separate private history stack.
- Carry provenance through share/review/runtime exports. An exported derivative
  contains its original source record, license, attribution, and project credit
  entry.

**Release gate:** pixel edits survive undo/redo, autosave, crash recovery,
save/reopen, PNG round-trip, and project duplication without source-art
mutation or lost credit data.

## Phase 4 — clips, keyframes, and custom cels

**Goal:** Add meaningful animation before attempting high-risk freeform mesh
deformation.

- Expose an **Animate** workspace that preserves full LPC sheets and supports
  clip timing, transform keyframes, image swaps, and preview/export playback.
- Support two explicit animation sources:
  - whole-character cels rendered into project-owned editable frames;
  - independently animated body, hair, clothing, and equipment cels.
- Store clip/keyframe changes in the shared document history and use command
  macros for multi-key operations. Workspace selection, playhead movement, and
  temporary previews remain transient and do not pollute undo.
- Export composite layers, copied edits, and custom cels into the existing
  image-sequence, sprite-sheet, GIF, review, and runtime delivery paths along
  with exact credits.

**Release gate:** clips and custom cels replay identically after save/reopen;
preview, Bake, and export agree; credits and license records follow every
selected/derived asset.

## Phase 5 — deformation, only by approved increments

**Goal:** Add deformation only where the phase 0 prototype proves it is
pixel-safe, performant, and maintainable.

### Pixel-art policy

- **Pixel-safe deformation** uses native-resolution rendering, nearest texture
  sampling, grid-snapped controls when enabled, and no automatic smoothing or
  palette re-quantization. Bake rasterizes at the native pixel grid and retains
  the editable mesh history plus the source/provenance chain.
- **Palette re-quantization** is an explicit optional post-process with preview
  and undo, never a hidden part of Bake. It is allowed only for palettes the
  project profile declares.
- **Smooth deformation** uses linear sampling and may introduce intermediate
  colors. It is labelled non-pixel-safe and is never substituted silently for
  LPC pixel output.

### Incremental scope

1. **5A — per-layer mesh MVP:** simple auto/manual topology, vertex movement,
   native-grid Bake, and keyframed vertex offsets. No cage, soft drag, skinning,
   bone binding, or weight painting.
2. **5B — optional composite/cage prototype:** whole-character composite mesh
   and cage controls only if 5A passes visual and performance gates.
3. **5C — separate approval required:** soft drag, bone binding, and weight
   painting are a new dedicated tool project. They are not committed scope in
   this plan and require a fresh UX, data, export, performance, and maintenance
   proposal before implementation.

Every level remains non-destructive. Bake creates a project-owned raster
derivative while keeping the editable deformation state, source record, and
command history available.

**Go/no-go gate:** each level requires documented prototype results, visual
goldens, load benchmarks, undo/recovery evidence, export parity, and explicit
approval before the next level begins.

## Shared systems and edge-case rules

### One document history

Paper Quest already has a shared CommandService. LPC work extends that single
global document undo/redo stack across creator, pixel, animation, and
deformation workspaces. Each tool contributes atomic commands or grouped
macros, gives the user a useful action label, and participates in the same
dirty/autosave state. No hidden per-workspace history may diverge from the
document.

### Asset storage, sharing, and recovery

- Bundled/source assets are immutable. Project-owned edits are content-addressed
  derivatives with retained source/credit/license metadata.
- Autosave snapshots only document state and references; they reuse immutable
  derivative blobs rather than copying pixel data repeatedly.
- A project reports total local asset size, derivative count, missing source
  files, and orphan candidates. Cleanup is an explicit, recoverable operation.
- Shared/exported projects retain their selected pack identifier, asset records,
  acceptance status, and exact credit/license manifest. Commercial-safe export
  fails if any derivative's ancestry is not commercially eligible.

### Compatibility and destructive actions

- Existing non-LPC documents stay available as they are. Old LPC documents get
  an explicit backup-producing conversion workflow rather than automatic import.
- A missing or corrupt single source asset is reported at library intake,
  first use, export, and build validation; a valid root manifest alone is not
  enough.
- Reset Body never silently drops custom edits. Confirmation is conditional on
  actual destructive impact, and Undo always restores the pre-reset state.

## Test and release gates

Every phase adds automated and manual evidence in these categories:

| Category | Required coverage |
| --- | --- |
| **Catalog and licensing** | Full-library indexing; per-asset hash/dimension/source checks; pack filtering; required acceptance; credit generation; personal/commercial export rejection cases. |
| **Schema and recovery** | Version migration fixtures; old-LPC conversion; legacy non-LPC preservation; autosave/recovery; duplicate/rename/archive; deleted-name sequence behavior. |
| **History and storage** | Global undo/redo across workspace changes; macro atomicity; reset confirmation; derivative deduplication; autosave reuse; size budgets; recoverable cleanup. |
| **Visual fidelity** | Layer composition, palette changes, custom cels, nearest-filter pixel output, Bake/preview/export parity, and goldens for every approved deformation level. |
| **Performance and load** | Full catalog search/thumbnail virtualization, large compatible layer stacks, many cels/keyframes, live preview, and each deformation prototype at the declared baseline hardware. |
| **Release compliance** | No pack/export with missing licensing data; manifests include every selected/derived asset; a human final review confirms the automated result before public release. |

## Explicitly deferred decisions

- The exact phase 5C scope, including professional-quality weight painting and
  bone binding, is deferred until the feasibility spike and 5A/5B evidence
  justify it.
- Performance thresholds are set after phase 0 measures a documented baseline
  machine; later phases must meet those published budgets rather than relying
  on subjective responsiveness.
- The local LPC library remains a required input only for LPC development and
  LPC release packs. It must not prevent legacy/non-LPC projects from opening.

For upstream LPC licensing and credit guidance, see
[Universal LPC Sprite Sheet Character Generator](https://github.com/liberatedpixelcup/Universal-LPC-Spritesheet-Character-Generator).
