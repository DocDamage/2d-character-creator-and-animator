# Release Build Guide

Run `ReleaseBuilder.preflight()` on the release machine first. It requires the
sample catalog, manuals, release notes, known issues, license manifests, and the
Windows Desktop export preset. Install Godot’s matching Windows export templates
on that machine, then call `build_windows("release/windows/Modular2DCharacterStudio.exe")`.

Run the generated binary on a clean Windows machine, open the six sample files,
export a package, load the generated runtime scene in a clean consumer project,
and record the result in `QA-REL-001` evidence. Do not claim the platform smoke
test from a host that lacks the matching export templates.
