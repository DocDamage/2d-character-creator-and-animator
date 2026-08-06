# Retarget Bone Mapping Evidence

## Task ID

`RET-002`

## Status

IMPLEMENTED_UNVERIFIED. Retargeting now builds an explicit source-bone to
target-bone map from semantic skeleton profiles and reports incomplete roles
without guessing. `QA-POS-001` remains the independent acceptance gate.

## Evidence

- Matching semantic roles generate a deterministic source-bone → target-bone map.
- Root mapping is required; partial maps list unsupported source/target roles.
- Validation detects unavailable and many-to-one custom mappings.
- Tests cover complete mapping, partial diagnostics, and invalid map rejection.

## Scope Boundary

Proportion compensation, preview, batch retargeting, and correction layers
remain `RET-003` through `RET-006` scope.
