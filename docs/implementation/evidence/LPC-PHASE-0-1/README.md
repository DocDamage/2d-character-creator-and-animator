# LPC Phase 0–1 Evidence

This evidence bundle covers the direct-start LPC foundation and validated
library workflow described in `DIRECT_START_LPC_CREATOR_PLAN.md`.

Implemented requirements:

- Phase 0: pinned source lock, deterministic catalog builder/cache/diff,
  source/hash/metadata validation, policy and alternative-license resolution,
  versioned standard sheet layout/frame references, render snapshots, CPU
  reference compositing, and strict nearest-sampled triangle rasterization.
- Phase 1: versioned LPC project profiles, monotonic display-name indexes,
  migration backups, transactional save/autosave/recovery, local-library
  locate/rebuild flow, compatible policy/body-family filtering, resume flow,
  and staged catalog selection gating.

Verification command:

```powershell
godot --headless --path . --scene tests/lpc_phase01_runner.tscn
```

The acceptance test creates a synthetic locked source pack at runtime. It
proves deterministic source/catalog handling, strict shared-edge raster
coverage and palette preservation, exact credit output, staged catalog gating,
project create/reopen/autosave/resume, migration backup creation, and no source
mutation. The real upstream LPC source remains local and outside Git by design.

The separately imported legacy Character Creator 2D artwork is intentionally
not treated as LPC source art. Its copy-only provenance, checksums, and
unreviewed license status are recorded in
`assets/imported/character_creator_2d/IMPORT_MANIFEST.json`.

## Task ID

`LPC-PHASE-0-1`

## Status

AUTOMATED_VERIFICATION_COMPLETE; human visual and clean-machine release acceptance remain pending.

## Evidence

The focused acceptance runner and the full 556-assertion regression suite pass under Godot 4.7.1.
