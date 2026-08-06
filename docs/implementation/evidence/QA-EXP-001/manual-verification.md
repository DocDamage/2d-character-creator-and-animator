# Verification Scenario

The export acceptance test does not trust exporter return values alone. It
reopens each emitted artifact through its intended consumer: Godot's package,
image, resource, and scene readers; JSON and XML manifest readers; and the
installed `ffprobe` decoder for animated/video containers.

The test uses transparent 8×8 samples so the spritesheet assertions can prove
the emitted source rectangle, one-pixel padding, and one-pixel edge extrusion.
It also runs twice through the atlas packer and compares placement signatures.

Video acceptance requires a discoverable `ffmpeg`/`ffprobe` installation. This
environment provides both; consumer environments retain the documented ffmpeg
dependency.
