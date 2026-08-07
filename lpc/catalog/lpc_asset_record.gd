# LpcAssetRecord -- Canonical catalog representation for one immutable LPC asset.
class_name LpcAssetRecord
extends RefCounted

const REQUIRED_FIELDS := [
	"asset_id", "upstream_item_id", "type_name", "source_relative_path", "source_sha256",
	"image", "body_family_ids", "layer_group", "layer_number", "z_order",
	"supported_animations", "direction_ids", "layout_id", "palette", "credits",
	"license_options", "deformation", "rig_adapter", "source_lock_commit", "adapter_version",
]


static func normalize(raw: Dictionary, lock: Dictionary) -> Dictionary:
	var record := raw.duplicate(true)
	record["asset_id"] = str(record.get("asset_id", record.get("id", ""))).strip_edges()
	record["upstream_item_id"] = str(record.get("upstream_item_id", record.asset_id)).strip_edges()
	record["type_name"] = str(record.get("type_name", "unknown")).strip_edges()
	record["upstream_aliases"] = _strings(record.get("upstream_aliases", record.get("aliases", [])))
	record["source_relative_path"] = str(record.get("source_relative_path", record.get("path", ""))).replace("\\", "/")
	record["source_sha256"] = str(record.get("source_sha256", "")).to_lower()
	var image: Dictionary = (record.get("image", {}) as Dictionary).duplicate(true)
	image["width"] = int(image.get("width", record.get("width", 0)))
	image["height"] = int(image.get("height", record.get("height", 0)))
	image["format"] = str(image.get("format", "png")).to_lower()
	image["alpha"] = (image.get("alpha", {}) as Dictionary).duplicate(true)
	record["image"] = image
	record["body_family_ids"] = _strings(record.get("body_family_ids", record.get("body_families", [])))
	record["layer_group"] = str(record.get("layer_group", ""))
	record["layer_number"] = int(record.get("layer_number", 0))
	record["z_order"] = (record.get("z_order", {"default": record.get("z_pos", 0), "overrides": {}}) as Dictionary).duplicate(true)
	record["supported_animations"] = _strings(record.get("supported_animations", record.get("animations", [])))
	record["direction_ids"] = _strings(record.get("direction_ids", record.get("directions", ["up", "left", "down", "right"])))
	record["layout_id"] = str(record.get("layout_id", "lpc_standard_v1"))
	record["palette"] = (record.get("palette", {"material": "", "allowed_palette_ids": []}) as Dictionary).duplicate(true)
	record["compatibility_tags"] = _strings(record.get("compatibility_tags", []))
	record["credits"] = _dict_array(record.get("credits", record.get("credited_sources", [])))
	record["license_options"] = _dict_array(record.get("license_options", []))
	record["distribution_policy"] = (record.get("distribution_policy", {"eligible": true, "reason": ""}) as Dictionary).duplicate(true)
	record["deformation"] = (record.get("deformation", {"capabilities": ["FRAME_NATIVE"]}) as Dictionary).duplicate(true)
	record["rig_adapter"] = (record.get("rig_adapter", {"available": false}) as Dictionary).duplicate(true)
	record["source_lock_commit"] = str(record.get("source_lock_commit", lock.get("upstream_commit_sha", "")))
	record["adapter_version"] = str(record.get("adapter_version", lock.get("catalog_adapter_version", "")))
	record["validation_status"] = str(record.get("validation_status", "pending"))
	record["diagnostics"] = _strings(record.get("diagnostics", []))
	return record


static func validate(record: Dictionary, body_family_ids: Array, layouts: Dictionary, palette_ids: Array[String]) -> Array[String]:
	var errors: Array[String] = []
	for field in REQUIRED_FIELDS:
		if not record.has(field):
			errors.append("Asset is missing '%s'." % field)
	var asset_id := str(record.get("asset_id", ""))
	if asset_id.is_empty(): errors.append("Asset ID cannot be empty.")
	var relative := str(record.get("source_relative_path", ""))
	if relative.is_empty() or relative.begins_with("/") or ":" in relative or ".." in relative.split("/"):
		errors.append("%s has an unsafe source path." % asset_id)
	var image: Dictionary = record.get("image", {})
	if int(image.get("width", 0)) <= 0 or int(image.get("height", 0)) <= 0:
		errors.append("%s has invalid image dimensions." % asset_id)
	if str(image.get("format", "")).to_lower() != "png":
		errors.append("%s must use PNG source art." % asset_id)
	if str(record.get("source_sha256", "")).length() != 64:
		errors.append("%s is missing a SHA-256 source hash." % asset_id)
	for family in record.get("body_family_ids", []):
		if str(family) not in body_family_ids:
			errors.append("%s refers to unknown body family '%s'." % [asset_id, family])
	if not layouts.has(str(record.get("layout_id", ""))):
		errors.append("%s refers to an unknown layout adapter." % asset_id)
	for palette_id in (record.get("palette", {}) as Dictionary).get("allowed_palette_ids", []):
		if str(palette_id) not in palette_ids:
			errors.append("%s refers to unknown palette '%s'." % [asset_id, palette_id])
	if (record.get("credits", []) as Array).is_empty():
		errors.append("%s has no credited source records." % asset_id)
	if (record.get("license_options", []) as Array).is_empty():
		errors.append("%s has no selectable license options." % asset_id)
	return errors


static func _strings(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			var text := str(item).strip_edges()
			if not text.is_empty() and text not in result: result.append(text)
	return result


static func _dict_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			if item is Dictionary: result.append((item as Dictionary).duplicate(true))
	return result
