# Skeleton Profile Evidence

## Task ID

`RET-001`

## Status

IMPLEMENTED_UNVERIFIED. `RigSkeletonProfile` now serializes the semantic bone
contract used to compare and retarget rigs. `QA-POS-001` remains the
independent pose/retarget acceptance gate.

## Evidence

- Profiles identify a rig and give semantic roles (`root`, `hand_left`, etc.)
  unique bone IDs.
- Validation requires identity/name/root, disallows duplicate assignments, and
  can validate entries against bound rig bone IDs.
- Serialization sorts role keys so profile persistence is deterministic.
- Integration coverage validates role normalization, malformed profiles, and
  full metadata round-trip.

## Scope Boundary

Bone mapping, proportion compensation, preview, batch retargeting, and
correction layers remain `RET-002` through `RET-006` scope.
