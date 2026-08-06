# Verification Scenario

The acceptance test constructs the full directional workflow from public grid
and evaluator APIs instead of reusing the narrow legacy unit-test fixture. It
uses a 22.5° vector to prove a real 50/50 north/northeast crossfade, then turns
on pixel mode and disables a neighbor to prove both fallback paths.

The grid is mirrored from north to south with two slot values, checks the
left/right exchange, and is serialized, reloaded, and sorted before comparing
the two persisted forms. Master-facing authoring UI, correction controls, and
visual previews are intentionally outside this legacy runtime acceptance.
