# Manual Verification

1. Bind audio and viseme tracks with `MainWindow.bind_media_authoring_context`.
2. Open the Media Authoring dock, enter a time, and press Scrub; inspect cue,
   viseme, reference, and missing-source counts.
3. Add reference media through `MediaTimelineModel`; confirm it follows its
   offset and is omitted by `export_data` while `exclude_from_export` is true.
4. Use a safe replacement source for missing media and re-scrub the playhead.
