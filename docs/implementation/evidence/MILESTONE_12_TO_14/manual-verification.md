# Manual Verification

## Directional and animation runtime

1. Instantiate `CharacterPlayer2D` and load a package containing a facing grid and state machine.
2. Call `set_facing_direction(Vector2.UP)` and then a diagonal vector.
3. Set state parameters or triggers and observe the returned evaluator snapshot.

Expected: the facing cell resolves deterministically, cross-fades only outside pixel mode, and state transitions expose their blend progress.

## Export and import

1. Export `Image` frames with `SpritesheetExporter`, `ImageSequenceExporter`, and `GifExporter`.
2. Export a package with `GodotResourceExporter`.
3. Import project data through `ChrprojImporter`.

Expected: image artifacts and manifests are written; Godot `.tres` and `.tscn` resources load; the imported resource retains package content.

## Video

MP4 and WebM image sequences were rendered successfully through the installed, discoverable `ffmpeg` executable.
