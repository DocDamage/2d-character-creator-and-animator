# Release Build Guide

Run `ReleaseBuilder.preflight()` on the release machine first. It verifies the
sample catalog, manuals, release notes, recovery/update manifest, app icon, and
the Windows export presets. Install Godot’s matching Windows export templates on
that machine before building.

For the portable distribution, call
`build_portable_windows("release/windows/PaperQuestCharacterStudio.exe")`. The
resulting ZIP contains the EXE, its matching PCK, and a short README. Keep both
EXE and PCK together when distributing or testing it.

For a single-file build, call
`build_single_file_windows("release/windows/PaperQuestCharacterStudio.exe")`.
That preset embeds the PCK in the EXE. Both presets carry the Paper Quest icon and
Windows product/version metadata.

Public builds should be Authenticode-signed after export. On a properly prepared
release machine, call `sign_windows_executable(exe_path, signtool_path,
certificate_selector, timestamp_url)`. A selector may be a certificate subject
or `file:C:/path/to/certificate.pfx`; the signing password remains with the
release machine/certificate store and is never committed to the project.

Set the download URL and release notes in `release/update_manifest.json` before
publishing. The in-app update check reads a configured HTTPS feed when available,
and otherwise reports the bundled manifest status without downloading anything.

Run the generated binary on a clean Windows machine, open the six sample files,
exercise first-run onboarding and recovery, export a package, load the generated
runtime scene in a clean consumer project, and record the result in `QA-REL-001`
evidence. Do not claim the platform smoke test from a host that lacks matching
export templates or a signing certificate.
