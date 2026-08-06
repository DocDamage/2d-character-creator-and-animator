# Samples, Documentation, and Release Evidence

## Task IDs

`SMP-001` through `SMP-006`, `DOCS-001` through `DOCS-004`, and `REL-001`
through `REL-004`.

## Status

IMPLEMENTED_UNVERIFIED. The configured Windows package was compiled on
2026-08-06; `QA-REL-001` still owns the final clean Windows-machine smoke audit.

## Evidence

- Six valid `.chrproj` samples cover humanoid, pixel, deformable, 100-character,
  20-weapon, and animation/gameplay workflows.
- User, asset, weapon, runtime-plugin, and release-build documentation describe
  the current docks, APIs, samples, and validation boundaries.
- Release notes, known issues, license manifests, a Windows export preset, and
  `ReleaseBuilder.preflight` make platform release prerequisites reproducible.
- `release/windows/Modular2DCharacterStudio.exe` is a 64-bit Windows PE artifact
  with its companion `.pck`; hashes are recorded in `test-results.txt`.
- The packaged executable completed a native Windows `--headless --quit` launch
  with exit status 0; this is a packaging check, not final manual acceptance.
