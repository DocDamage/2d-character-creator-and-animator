# Release Build Guide

Run `ReleaseBuilder.preflight()` on the release machine first. It verifies the
sample catalog, manuals, release notes, recovery/update manifest, app icon, and
the Windows export presets. Install Godot’s matching Windows export templates on
that machine before building.

For the portable distribution, call
`build_portable_windows("release/windows/PaperQuestCharacterStudio.exe")`. The
resulting ZIP contains the EXE, its matching PCK, a short README, `VERSION.json`,
and `SHA256SUMS.txt`. Keep both EXE and PCK together when distributing or
testing it. Run `verify_windows_artifacts(exe_path, false)` before publishing.

For a single-file build, call
`build_single_file_windows("release/windows/PaperQuestCharacterStudio.exe")`.
That preset embeds the PCK in the EXE. Both presets carry the Paper Quest icon and
Windows product/version metadata.

An NSIS template is included at `release/windows/PaperQuestCharacterStudio.nsi`.
After producing a verified portable build, call
`build_windows_installer(exe_path, makensis_path)` on a Windows release machine
with NSIS installed. This creates a per-user installer with Start-menu and
desktop shortcuts plus a clean uninstaller. The installer is prepared locally;
it is not signed automatically.

Public builds should be Authenticode-signed after export. On a properly prepared
release machine, call `sign_windows_executable(exe_path, signtool_path,
certificate_selector, timestamp_url)`. A selector may be a certificate subject
or `file:C:/path/to/certificate.pfx`; the signing password remains with the
release machine/certificate store and is never committed to the project.

Use `write_update_manifest(...)` or update `release/update_manifest.json` with a
version, stable/beta channel, secure HTTPS download URL, SHA-256 when available,
and release notes before publishing. The in-app update check accepts HTTPS feeds
only, opens a release page only after an artist chooses it, and otherwise reports
that a development build has no public feed configured.

Run the generated binary on a clean Windows machine, open the six sample files,
exercise first-run onboarding and recovery, export a package, load the generated
runtime scene in a clean consumer project, and record the result in `QA-REL-001`
evidence. Do not claim the platform smoke test from a host that lacks matching
export templates or a signing certificate.
