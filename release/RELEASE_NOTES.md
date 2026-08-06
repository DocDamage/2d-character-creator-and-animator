# Release Notes — 0.1.0-dev

This build adds modular character creation, advanced composition, media and
gameplay metadata authoring, batch export, a portable Godot runtime addon, and
quality/recovery workflows. See the sample catalog and guides for reproducible
entry points.

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
