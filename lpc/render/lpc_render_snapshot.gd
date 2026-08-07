# LpcRenderSnapshot -- Immutable render input shared by preview, bake, and export paths.
class_name LpcRenderSnapshot
extends RefCounted

const SNAPSHOT_VERSION := "1.0.0"


static func create(data: Dictionary) -> Dictionary:
	var snapshot := {
		"snapshot_version": SNAPSHOT_VERSION,
		"project_profile_version": str(data.get("project_profile_version", "")),
		"source_lock_signature": str(data.get("source_lock_signature", "")),
		"catalog_signature": str(data.get("catalog_signature", "")),
		"clip_id": str(data.get("clip_id", "")), "playhead": float(data.get("playhead", 0.0)),
		"direction_id": str(data.get("direction_id", "down")), "layers": (data.get("layers", []) as Array).duplicate(true),
		"palette_maps": (data.get("palette_maps", {}) as Dictionary).duplicate(true),
		"evaluated_geometry": (data.get("evaluated_geometry", {}) as Dictionary).duplicate(true),
		"layer_order": (data.get("layer_order", []) as Array).duplicate(true),
		"strictness_mode": str(data.get("strictness_mode", "strict_lpc_raster")),
		"baker_version": str(data.get("baker_version", "1.0.0")),
		"canvas": (data.get("canvas", {"width": 64, "height": 64, "origin": [0, 0]}) as Dictionary).duplicate(true),
		"credit_manifest_hash": str(data.get("credit_manifest_hash", "")),
	}
	snapshot["snapshot_hash"] = signature(snapshot)
	return snapshot


static func validate(snapshot: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in ["snapshot_version", "source_lock_signature", "layers", "canvas", "strictness_mode", "baker_version"]:
		if not snapshot.has(key): errors.append("Render snapshot is missing '%s'." % key)
	var canvas: Dictionary = snapshot.get("canvas", {})
	if int(canvas.get("width", 0)) <= 0 or int(canvas.get("height", 0)) <= 0:
		errors.append("Render snapshot canvas must have positive dimensions.")
	if not str(snapshot.get("strictness_mode", "")) in ["strict_lpc_raster", "stepped_pixel_motion", "smooth_art"]:
		errors.append("Render snapshot has an unknown strictness mode.")
	return errors


static func signature(snapshot: Dictionary) -> String:
	var copy := snapshot.duplicate(true)
	copy.erase("snapshot_hash")
	return _canonical_json(copy).sha256_text()


static func _canonical_json(value: Variant) -> String:
	return JSON.stringify(_canonicalize(value), "", false)


static func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var keys := (value as Dictionary).keys(); keys.sort()
		var result := {}
		for key in keys: result[key] = _canonicalize((value as Dictionary)[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value: result.append(_canonicalize(item))
		return result
	if value is float:
		var snapped: float = round(float(value))
		return int(snapped) if is_equal_approx(float(value), snapped) else value
	return value
