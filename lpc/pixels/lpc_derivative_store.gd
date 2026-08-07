# LpcDerivativeStore -- Content-addressed, project-owned PNG blobs with complete source ancestry.
class_name LpcDerivativeStore
extends RefCounted

const STORE_VERSION := "1.0.0"
const ROOT := "user://lpc_derivatives"


static func store_image(profile: Dictionary, image: Image, metadata: Dictionary = {}) -> Dictionary:
	if image == null or image.is_empty(): return {"success": false, "errors": ["A non-empty image is required for a derivative."]}
	var project_id := str(profile.get("project_uuid", "")).strip_edges()
	if project_id.is_empty(): return {"success": false, "errors": ["A durable LPC project UUID is required for derivatives."]}
	var hash := image_hash(image)
	var folder := ROOT.path_join(project_id).path_join("blobs")
	var absolute := ProjectSettings.globalize_path(folder)
	if DirAccess.make_dir_recursive_absolute(absolute) != OK: return {"success": false, "errors": ["Could not create the project-owned derivative store."]}
	var blob_path := folder.path_join(hash + ".png")
	var already_stored := FileAccess.file_exists(blob_path)
	if not already_stored and image.save_png(blob_path) != OK:
		return {"success": false, "errors": ["Could not save the project-owned derivative PNG."]}
	var parent: Dictionary = metadata.get("parent_derivative", {})
	var source_asset_id := str(metadata.get("source_asset_id", parent.get("source_asset_id", "")))
	var source_hash := str(metadata.get("source_hash", parent.get("source_hash", "")))
	var ancestry: Array = (parent.get("ancestor_derivative_ids", []) as Array).duplicate()
	if not parent.is_empty(): ancestry.append(str(parent.get("derivative_id", "")))
	ancestry = ancestry.filter(func(value): return not str(value).is_empty())
	var operation := str(metadata.get("operation", "pixel_edit"))
	var record := {
		"derivative_id": "drv_" + (hash + operation + str(parent.get("derivative_id", ""))).sha256_text().substr(0, 20), "content_hash": hash,
		"blob_path": blob_path, "source_asset_id": source_asset_id, "source_hash": source_hash,
		"source_frame_reference": (metadata.get("source_frame_reference", parent.get("source_frame_reference", {})) as Dictionary).duplicate(true),
		"operation": operation, "parent_derivative_id": str(parent.get("derivative_id", "")), "ancestor_derivative_ids": ancestry,
		"width": image.get_width(), "height": image.get_height(), "alpha_statistics": alpha_statistics(image), "palette_audit": palette_audit(image),
		"creation_tool": str(metadata.get("creation_tool", "lpc_pixel_editor")), "tool_version": STORE_VERSION, "created_at": Time.get_unix_time_from_system(),
	}
	return {"success": true, "errors": [], "record": record, "blob_reused": already_stored}


static func attach(profile: Dictionary, record: Dictionary) -> Dictionary:
	var next := profile.duplicate(true)
	var records: Array = (next.get("derivative_references", []) as Array).duplicate(true)
	var found := false
	for index in range(records.size()):
		if records[index] is Dictionary and str((records[index] as Dictionary).get("derivative_id", "")) == str(record.get("derivative_id", "")):
			records[index] = record.duplicate(true); found = true
	if not found: records.append(record.duplicate(true))
	next["derivative_references"] = records
	return next


static func load_image(record: Dictionary) -> Image:
	var path := str(record.get("blob_path", ""))
	return Image.load_from_file(path) if not path.is_empty() and FileAccess.file_exists(path) else null


static func image_hash(image: Image) -> String:
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256)
	context.update(("%d:%d:%d:" % [image.get_width(), image.get_height(), image.get_format()]).to_utf8_buffer())
	context.update(image.get_data())
	return context.finish().hex_encode()


static func alpha_statistics(image: Image) -> Dictionary:
	var opaque := 0; var transparent := 0; var partial := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var alpha := image.get_pixel(x, y).a8
			if alpha == 0: transparent += 1
			elif alpha == 255: opaque += 1
			else: partial += 1
	return {"opaque_pixels": opaque, "transparent_pixels": transparent, "partial_alpha_pixels": partial}


static func palette_audit(image: Image) -> Dictionary:
	var colors: Dictionary = {}
	for y in range(image.get_height()):
		for x in range(image.get_width()): colors[image.get_pixel(x, y).to_html(true).to_lower()] = true
	var values: Array[String] = []
	for value in colors: values.append(str(value))
	values.sort()
	return {"color_count": values.size(), "rgba_values": values, "has_partial_alpha": bool(alpha_statistics(image).get("partial_alpha_pixels", 0) > 0)}


static func blob_count(profile: Dictionary) -> int:
	var seen: Dictionary = {}
	for raw in profile.get("derivative_references", []):
		if raw is Dictionary: seen[str((raw as Dictionary).get("blob_path", ""))] = true
	return seen.size()
