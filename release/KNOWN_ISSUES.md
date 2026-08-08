# Known Issues

- Final interactive Windows clean-machine acceptance remains an independent
  release QA step; fresh portable and single-file candidates pass automated
  build, checksum, and headless startup checks.
- The NSIS installer and Authenticode signatures require release-machine tools
  and credentials that are not installed in this workspace.
- Twelve pre-existing oversized production files remain under a no-growth LOC
  ratchet and should be reduced after the release candidate.
- Video export requires a locally installed `ffmpeg`/`ffprobe` binary.
- Only `QA-REL-001` remains open; non-release verification rows are recorded in
  `docs/implementation/evidence/QA-COMPLETION-001/`.
