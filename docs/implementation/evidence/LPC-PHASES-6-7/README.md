# LPC Phases 6–7 Completion Record

The direct-start LPC creator now carries a locked source frame through
direction-specific cutout rigging, weighted deformation, eight-direction
authoring, and portable runtime delivery.

| Phase | Delivered outcome | Acceptance command |
| --- | --- | --- |
| 6 | Project-owned cutout pieces with masks, pivots, z groups, gap-patch derivatives, rigid bone posing, two-bone hand/weapon anchors, hybrid playback, save/reopen, and native-frame fallback | `godot --headless --path . --scene tests/lpc_phase6_runner.tscn` |
| 7 | Stable weighted meshes, named initializers, topology-aware paint strokes, ordered mean-value cages/radial pins/soft controls, explicit diagonal authoring, baked/editable/hybrid delivery, and a clean runtime consumer | `godot --headless --path . --scene tests/lpc_phase7_runner.tscn` |

The phase-7 clean consumer contains only the exported runtime addon, package,
runtime `.tres`, scene, and test script. It imports after two fresh editor
starts and checks runtime assets, skeleton, direction selection, clip access,
equipment state, credits, explicit baked fallback metadata, and a clear
missing-package error.

`LpcReleaseCandidate` records automated playback timing, resolved credits,
fixture evidence, and the human visual-review state. An absent human approval
is intentionally a pending gate; it is not represented as a completed public
release.

## Task ID

`LPC-PHASES-6-7`

## Status

AUTOMATED_VERIFICATION_COMPLETE; human visual and clean-machine release acceptance remain pending.

## Evidence

The focused acceptance runner and the full 556-assertion regression suite pass under Godot 4.7.1.
