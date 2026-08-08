# LOC policy ratchet

`loc_baseline.json` records pre-existing production files above the 300-line
policy at the release-candidate audit. The checker reports these files as debt
but fails only when a baseline file grows or a new file crosses the limit.

This is not a permanent exception registry. Refactoring a baseline file below
its recorded count requires lowering or removing its baseline entry. Formal
exceptions, if any, still belong in `docs/implementation/LOC_EXCEPTIONS.md`.
