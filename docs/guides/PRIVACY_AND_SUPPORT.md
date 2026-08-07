# Privacy and support

Paper Quest Character Studio is an import-first desktop editor. It does not
generate character art, upload project files, or send analytics by default.

## Project and artwork data

Projects, copied artwork, audio, snapshots, autosaves, recovery files, review
packages, and Appearance Sets stay on the local filesystem. A project can store
optional artist, license, and source-reference details for imported assets so a
handoff retains provenance without duplicating artwork.

## Updates

The update checker reads a configured HTTPS manifest and opens the supplied
download page only after the artist chooses to do so. It never downloads or
installs an update automatically. Development builds with no configured feed
state clearly that an update source is unavailable.

## Support bundles

The Project Hub can create a local support ZIP on request. It contains recent
diagnostics, application/environment details, and a redacted project summary.
It deliberately excludes imported art, audio, copied project assets, and the
full project manifest. Nothing is uploaded; share the ZIP only with a support
contact you trust.
