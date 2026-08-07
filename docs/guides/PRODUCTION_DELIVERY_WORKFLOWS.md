# Production delivery workflows

This guide covers the game-facing, automation, collaboration, and presentation
workflows added to the character studio. They all use the same authored project
data and deterministic runtime contract, so preview, QA, and package export do
not silently drift apart.

## Where to find the tools

Open a character project, then use the dock/workspace commands to reveal these
production panels:

- **Game Runtime Preview & Delivery** — runtime state, rules, equipment swaps,
  hitboxes, action points, events, engine exports, and runtime QA.
- **Motion Library & Secondary Motion** — reusable motion clips, retarget
  presets, time-warps, additive layers, spring chains, trails, impact frames,
  and event-driven effects.
- **Pipeline Automation & Collaboration** — approved watch folders, snapshots,
  Git status, milestone comparison, and portable asset packs.
- **Presentation & Approval** — turntable metadata, visemes and expressions,
  outfit sheets, pose-board references, and a reviewable approval package.

The **Preview / Export** workspace opens the runtime-delivery workflow directly.
The **Animation** workspace includes the motion-library panel.

## Runtime preview, QA, and export

The runtime panel builds a contract from the active project every time it
refreshes. That contract includes animation clips and tracks, state machine
states/transitions, rules, equipment data, rig data, hitboxes, action points,
events, motion-library settings, and authored secondary-motion parameters.

Use **Preview frame** to inspect a sampled runtime frame. Use **Advance
runtime** to run the same transition/rule/event path that QA consumes. State
parameters and equipment swaps can be supplied in the panel before advancing.
The result reports the selected state and clip, active rules, equipment, events,
hitboxes, action points, and secondary-motion output.

Use **Run runtime QA** to record collision playback, action-point checks, event
trace data, and deterministic debug PNGs under `runtime_regressions`. The QA
report is written alongside the chosen output directory when one is set.

Use **Export engine packages** to create:

- `character.chrpack` and `character.runtime.json` as the canonical runtime
  payload;
- a Godot package with the runtime addon and `sample_character_controller.gd`;
- a Unity `Assets/CharacterRuntime` package with a sample C# controller;
- an Unreal data package with a sample `CharacterRuntimeComponent`.

`runtime_export_report.json` carries the contract hash used for comparison. The
export validator verifies the canonical files, every requested sample
controller, and that each target's JSON has the exact same contract hash. It
also records a source-versus-`.chrpack` collision/event QA comparison. Secondary
motion stays data-only: spring, trail, impact, and event-effect parameters are
exported for the target runtime to evaluate rather than baked into generated
artwork.

## Motion library and polish

Add the active clip to the motion library, then tag and reuse it in other
projects or actions. Retarget presets map source and target bone IDs. Time-warp
curves, layer sets, blend weights, bone masks, sync groups, and additive modes
are saved as authored project metadata.

The secondary-motion buttons create exportable records for hair/cloth/jiggle
chains, dynamic weapon trails, impact frames, and event-driven effects. They
remain editable parameters and are evaluated for preview/QA without replacing
the source art.

## Pipeline automation

Run the headless CLI through its scene so project autoloads are available:

```powershell
godot --headless --path . --scene res://tools/studio_cli.tscn -- help
```

Commands return JSON and a nonzero exit code on failure:

```powershell
godot --headless --path . --scene res://tools/studio_cli.tscn -- validate --project C:\work\hero.chrproj --output C:\work\qa
godot --headless --path . --scene res://tools/studio_cli.tscn -- runtime-export --project C:\work\hero.chrproj --output C:\work\runtime --targets godot,unity,unreal
godot --headless --path . --scene res://tools/studio_cli.tscn -- review-export --project C:\work\hero.chrproj --output C:\work\review
godot --headless --path . --scene res://tools/studio_cli.tscn -- bulk-import --project C:\work\hero.chrproj --source C:\work\approved_layers
godot --headless --path . --scene res://tools/studio_cli.tscn -- watch-scan --project C:\work\hero.chrproj
godot --headless --path . --scene res://tools/studio_cli.tscn -- watch-apply --project C:\work\hero.chrproj
godot --headless --path . --scene res://tools/studio_cli.tscn -- template-create --template combat_2d --name Hero --output C:\work\hero.chrproj
godot --headless --path . --scene res://tools/studio_cli.tscn -- asset-pack-export --project C:\work\hero.chrproj --output C:\work\hero.assetpack
godot --headless --path . --scene res://tools/studio_cli.tscn -- asset-pack-import --source C:\work\hero.assetpack --output C:\work\hero_pack
```

Watch folders are deliberately opt-in. A changed source file is only
re-imported after its watch entry is marked **approved**; unapproved changes are
reported but not applied. Asset packs use a manifest-first ZIP format and reject
path-traversal entries during extraction. Templates available from the CLI are
`blank`, `combat_2d`, `dialogue`, and `pixel_fighter`.

## Collaboration and snapshots

The collaboration panel compares the current project with a saved milestone,
summarizes changed assets, and provides conflict guidance by metadata path. It
also reads local Git status without modifying the repository. For a merge, use
stable IDs for assets, clips, and production records; resolve overlapping
timeline edits consciously; then run runtime validation before committing.

Project data is structured and deterministically serialized to keep ordinary
project diffs reviewable. Snapshot comparison answers “what changed since this
milestone?” without mutating either version.

## Presentation and approval packages

The presentation panel exports a client-ready folder containing a presentation
manifest, authored turntable stops plus a rendered turntable contact sheet,
expression/viseme records, actual outfit batch sheets rendered from the
approved imported layers, per-board pose data pages, and `approval.html`. The
panel can also save expression/viseme entries, pose-board membership, and
turntable definitions before export. An optional approval URL is placed in that
page; it is not sent anywhere by the editor.

Before sharing a package, run runtime QA and confirm the runtime contract hash
in the package matches the approved export report.

## Verification

The production-delivery integration test exercises contract construction,
engine packages, runtime QA, motion/secondary data, templates, asset packs,
watch-folder safety, diffs, and presentation output. Run the full suite with:

```powershell
godot --headless --path . --scene res://tests/test_runner.tscn
```
