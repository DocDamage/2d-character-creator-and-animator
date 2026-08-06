# Security and Release Audit

Release workflows accept only `res://` and `user://` paths without `..` path
segments. Reference media uses the same boundary validation. Plugin calls are
gated by a callable-method check, so an unavailable optional integration is a
diagnostic result instead of a dereference failure.

The quality audit verifies the selected video encoder and both required license
manifests. Release evidence records the audited encoder path and licence files;
do not run unreviewed external commands from project metadata.
