# Release Notes — 0.1.0-dev

This build adds modular character creation, advanced composition, media and
gameplay metadata authoring, batch export, a portable Godot runtime addon, and
quality/recovery workflows. See the sample catalog and guides for reproducible
entry points.

## Import-first character authoring

Character Creator now starts with canvas and slot-template choices, then builds
only from imported PNG/WebP/JPEG layers. Folder and drag-and-drop imports map
filenames to slots. Layers support thumbnails, missing-file status, ordering,
lock/hide/solo, duplication, replacement, deletion, transforms, pivot, opacity,
and tint. No generated character workflow is included.

## Project safety and distribution

The Project hub now manages rename, independent duplicate, archive, reveal, and
locate actions. Autosave age, crash recovery candidates, bundled-sample warnings,
and duplicate/missing asset reporting are visible in the application. Windows
exports include app icon/version metadata and support a portable EXE+PCK ZIP or
an embedded-PCK single-file build; signing is available through the release
builder when release credentials are configured.

## Windows package fix

Startup diagnostics in exported templates now validate packaged runtime
resources rather than development-only folders such as `docs` and
`editor_plugins`.

New Project, Open Project, Open Sample, and Continue Last now enter the main
editor workspace after loading or creating the selected project.

## Workspace layout

Each dock region now uses labeled tabs rather than stacking every tool on one
page. Selecting a workspace focuses its primary tab: Character Creator,
Animation Composition, Weapon Authoring, or Batch Export as appropriate.
