# LpcCatalogBuilder -- Deterministic, read-only catalog intake for locked LPC sources.
class_name LpcCatalogBuilder
extends RefCounted

const SourceLockScript = preload("res://lpc/source/lpc_source_lock.gd")
const AssetRecordScript = preload("res://lpc/catalog/lpc_asset_record.gd")
const LayoutScript = preload("res://lpc/layout/lpc_sheet_layout.gd")
const LicenseResolverScript = preload("res://lpc/licensing/lpc_license_resolver.gd")
const SOURCE_MANIFEST_FILE := "lpc_catalog_source.json"
const CACHE_DIR := "user://lpc_catalog_cache"


static func build(source_root: String) -> Dictionary:
	var root := _absolute(source_root)
	if root.is_empty() or not DirAccess.dir_exists_absolute(root):
		return _failure(["LPC library folder is unavailable: %s" % source_root])
	var lock_path := root.path_join(SourceLockScript.LOCK_FILE_NAME)
	var lock_result := SourceLockScript.load_file(lock_path)
	if not lock_result.get("success", false): return _failure(lock_result.get("errors", []))
	var lock: Dictionary = lock_result.lock
	var errors: Array[String] = SourceLockScript.validate_source_root(lock, root)
	var source_result := _load_source_manifest(root)
	if not source_result.get("success", false): return _failure(errors + source_result.get("errors", []))
	var source: Dictionary = source_result.source
	var layouts := _normalize_layouts(source.get("layouts", []))
	for layout_id in layouts:
		for error in LayoutScript.validate(layouts[layout_id]): errors.append("Layout %s: %s" % [layout_id, error])
	var body_families: Array = source.get("body_families", [])
	var body_ids: Array[String] = []
	for raw_family in body_families:
		var id := str((raw_family as Dictionary).get("id", raw_family)) if raw_family is Dictionary else str(raw_family)
		if not id.is_empty() and id not in body_ids: body_ids.append(id)
	var palette_ids: Array[String] = []
	for raw_palette in source.get("palettes", []):
		var palette_id := str((raw_palette as Dictionary).get("id", raw_palette)) if raw_palette is Dictionary else str(raw_palette)
		if not palette_id.is_empty() and palette_id not in palette_ids: palette_ids.append(palette_id)
	var assets: Dictionary = {}
	var aliases: Dictionary = (source.get("aliases", {}) as Dictionary).duplicate(true)
	for raw_asset in source.get("assets", []):
		if not raw_asset is Dictionary:
			errors.append("Catalog contains a non-object asset record.")
			continue
		var record := AssetRecordScript.normalize(raw_asset, lock)
		_inspect_source(record, root, errors)
		var record_errors := AssetRecordScript.validate(record, body_ids, layouts, palette_ids)
		for error in record_errors: errors.append("Asset %s: %s" % [str(record.get("asset_id", "?")), error])
		var asset_id := str(record.get("asset_id", ""))
		if asset_id.is_empty() or assets.has(asset_id):
			errors.append("Catalog has a duplicate or blank asset ID: %s" % asset_id)
			continue
		assets[asset_id] = record
		for alias in record.get("upstream_aliases", []): aliases[str(alias)] = asset_id
	_validate_aliases(aliases, assets, errors)
	_validate_layer_groups(assets, errors)
	var rows := _rows(assets)
	var catalog := {
		"catalog_schema_version": "1.0.0", "source_root": root, "source_lock": lock,
		"source_lock_signature": str(lock.get("source_lock_signature", "")), "body_families": body_families,
		"layouts": layouts, "palettes": source.get("palettes", []), "assets": assets, "aliases": aliases,
		"rows": rows, "validation_errors": errors.duplicate(), "built_at": Time.get_unix_time_from_system(),
	}
	catalog["catalog_signature"] = _canonical_json(_signature_payload(catalog)).sha256_text()
	return {"success": errors.is_empty(), "catalog": catalog, "errors": errors}


static func write_cache(catalog: Dictionary) -> Dictionary:
	if catalog.is_empty() or str(catalog.get("catalog_signature", "")).is_empty():
		return _failure(["A validated catalog is required before caching."])
	var dir := _absolute(CACHE_DIR)
	if DirAccess.make_dir_recursive_absolute(dir) != OK: return _failure(["Unable to create LPC catalog cache."])
	var path := dir.path_join(_root_key(str(catalog.get("source_root", ""))) + ".json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return _failure(["Unable to write LPC catalog cache."])
	file.store_string(_canonical_json(catalog))
	file.close()
	return {"success": true, "path": path, "errors": []}


static func load_cache(source_root: String) -> Dictionary:
	var path := _absolute(CACHE_DIR).path_join(_root_key(_absolute(source_root)) + ".json")
	if not FileAccess.file_exists(path): return _failure(["No cached catalog exists for this LPC library."])
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text()) if file != null else null
	if file != null: file.close()
	if not parsed is Dictionary: return _failure(["Cached LPC catalog is malformed."])
	var catalog: Dictionary = parsed
	if str(catalog.get("catalog_signature", "")) != _canonical_json(_signature_payload(catalog)).sha256_text():
		return _failure(["Cached LPC catalog signature does not match its contents."])
	return {"success": true, "catalog": catalog, "errors": []}


static func diff(old_catalog: Dictionary, new_catalog: Dictionary, project_profiles: Array = []) -> Dictionary:
	var old_assets: Dictionary = old_catalog.get("assets", {})
	var new_assets: Dictionary = new_catalog.get("assets", {})
	var added: Array[String] = []
	var removed: Array[String] = []
	var changed: Array[Dictionary] = []
	for asset_id in new_assets:
		if not old_assets.has(asset_id): added.append(asset_id)
		elif _canonical_json(old_assets[asset_id]) != _canonical_json(new_assets[asset_id]):
			changed.append({"asset_id": asset_id, "source_hash_changed": str((old_assets[asset_id] as Dictionary).get("source_sha256", "")) != str((new_assets[asset_id] as Dictionary).get("source_sha256", "")), "old": old_assets[asset_id], "new": new_assets[asset_id]})
	for asset_id in old_assets:
		if not new_assets.has(asset_id): removed.append(asset_id)
	added.sort(); removed.sort()
	var affected_ids: Dictionary = {}
	for asset_id in removed + added: affected_ids[asset_id] = true
	for change in changed: affected_ids[str(change.get("asset_id", ""))] = true
	var affected_projects: Array[String] = []
	for raw_profile in project_profiles:
		if not raw_profile is Dictionary: continue
		var profile: Dictionary = raw_profile
		for selection in profile.get("selections", []):
			var asset_id := str((selection as Dictionary).get("asset_id", "")) if selection is Dictionary else str(selection)
			if affected_ids.has(asset_id):
				affected_projects.append(str(profile.get("project_uuid", profile.get("label", "Unknown project"))))
				break
	affected_projects.sort()
	return {"added": added, "removed": removed, "changed": changed, "projects_requiring_rebind": affected_projects, "old_signature": str(old_catalog.get("catalog_signature", "")), "new_signature": str(new_catalog.get("catalog_signature", ""))}


static func _load_source_manifest(root: String) -> Dictionary:
	var manifest_path := root.path_join(SOURCE_MANIFEST_FILE)
	if FileAccess.file_exists(manifest_path):
		var file := FileAccess.open(manifest_path, FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text()) if file != null else null
		if file != null: file.close()
		if parsed is Dictionary: return {"success": true, "source": parsed, "errors": []}
		return _failure(["%s must contain a JSON object." % SOURCE_MANIFEST_FILE])
	var discovered: Array = []
	_collect_definition_assets(root.path_join("sheet_definitions"), discovered)
	if discovered.is_empty(): return _failure(["No %s or readable sheet_definitions assets were found." % SOURCE_MANIFEST_FILE])
	return {"success": true, "source": {"assets": discovered, "layouts": [LayoutScript.standard_adapter()], "body_families": [], "palettes": [], "aliases": {}}, "errors": []}


static func _collect_definition_assets(folder: String, output: Array) -> void:
	if not DirAccess.dir_exists_absolute(folder): return
	var directory := DirAccess.open(folder)
	if directory == null: return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var path := folder.path_join(entry)
		if directory.current_is_dir(): _collect_definition_assets(path, output)
		elif entry.get_extension().to_lower() == "json":
			var file := FileAccess.open(path, FileAccess.READ)
			var parsed = JSON.parse_string(file.get_as_text()) if file != null else null
			if file != null: file.close()
			if parsed is Dictionary:
				var data: Dictionary = parsed
				if data.get("assets", null) is Array: output.append_array(data.assets)
		entry = directory.get_next()
		directory.list_dir_end()


static func _normalize_layouts(raw_layouts: Variant) -> Dictionary:
	var layouts: Dictionary = {LayoutScript.STANDARD_LAYOUT_ID: LayoutScript.standard_adapter()}
	if raw_layouts is Dictionary:
		for layout_id in (raw_layouts as Dictionary):
			if raw_layouts[layout_id] is Dictionary:
				var layout: Dictionary = (raw_layouts[layout_id] as Dictionary).duplicate(true)
				layout["layout_id"] = str(layout.get("layout_id", layout_id))
				layouts[str(layout.layout_id)] = layout
	elif raw_layouts is Array:
		for raw_layout in raw_layouts:
			if raw_layout is Dictionary:
				var layout: Dictionary = (raw_layout as Dictionary).duplicate(true)
				layouts[str(layout.get("layout_id", ""))] = layout
	return layouts


static func _inspect_source(record: Dictionary, root: String, errors: Array[String]) -> void:
	var relative := str(record.get("source_relative_path", ""))
	var path := root.path_join(relative)
	if not _is_within(root, path):
		errors.append("Asset %s resolves outside the source root." % record.get("asset_id", "?"))
		return
	if not FileAccess.file_exists(path):
		errors.append("Asset %s source PNG is missing: %s" % [record.get("asset_id", "?"), relative])
		return
	var actual_hash := _file_sha256(path)
	if not str(record.get("source_sha256", "")).is_empty() and str(record.source_sha256) != actual_hash:
		errors.append("Asset %s source hash does not match the locked PNG." % record.get("asset_id", "?"))
	record["source_sha256"] = actual_hash
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		errors.append("Asset %s source image cannot be decoded." % record.get("asset_id", "?"))
		return
	var info: Dictionary = record.get("image", {})
	if int(info.get("width", 0)) not in [0, image.get_width()] or int(info.get("height", 0)) not in [0, image.get_height()]:
		errors.append("Asset %s source dimensions do not match its record." % record.get("asset_id", "?"))
	info["width"] = image.get_width(); info["height"] = image.get_height(); info["format"] = "png"
	info["alpha"] = _alpha_stats(image)
	record["image"] = info


static func _alpha_stats(image: Image) -> Dictionary:
	var opaque := 0; var transparent := 0; var partial := 0
	var rgba := image
	if image.get_format() != Image.FORMAT_RGBA8:
		rgba = image.duplicate()
		rgba.convert(Image.FORMAT_RGBA8)
	var bytes := rgba.get_data()
	for index in range(3, bytes.size(), 4):
		var alpha := int(bytes[index])
		if alpha == 0: transparent += 1
		elif alpha == 255: opaque += 1
		else: partial += 1
	return {"opaque_pixels": opaque, "transparent_pixels": transparent, "partial_alpha_pixels": partial}


static func _validate_aliases(aliases: Dictionary, assets: Dictionary, errors: Array[String]) -> void:
	for alias in aliases:
		if str(alias).strip_edges().is_empty() or not assets.has(str(aliases[alias])):
			errors.append("Alias '%s' does not resolve to an asset." % alias)


static func _validate_layer_groups(assets: Dictionary, errors: Array[String]) -> void:
	var groups: Dictionary = {}
	for asset_id in assets:
		var asset: Dictionary = assets[asset_id]
		var group := str(asset.get("layer_group", ""))
		if group.is_empty(): continue
		if not groups.has(group): groups[group] = []
		groups[group].append(asset)
	for group in groups:
		var seen_layers: Dictionary = {}
		for asset in groups[group]:
			var layer := int((asset as Dictionary).get("layer_number", 0))
			if seen_layers.has(layer): errors.append("Layer group '%s' has duplicate layer number %d." % [group, layer])
			seen_layers[layer] = true


static func _rows(assets: Dictionary) -> Array:
	var rows: Array = []
	for asset_id in assets:
		var asset: Dictionary = assets[asset_id]
		rows.append({"asset_id": asset_id, "type_name": asset.get("type_name", ""), "body_family_ids": asset.get("body_family_ids", []), "layer_group": asset.get("layer_group", ""), "z": (asset.get("z_order", {}) as Dictionary).get("default", 0)})
	rows.sort_custom(func(a, b): return str(a.asset_id) < str(b.asset_id))
	return rows


static func _signature_payload(catalog: Dictionary) -> Dictionary:
	var copy := catalog.duplicate(true)
	copy.erase("built_at"); copy.erase("catalog_signature"); copy.erase("validation_errors"); copy.erase("source_root")
	return copy


static func _root_key(root: String) -> String:
	return root.simplify_path().to_lower().sha256_text().substr(0, 24)


static func _file_sha256(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(file.get_buffer(file.get_length()))
	var result := context.finish().hex_encode()
	file.close()
	return result


static func _is_within(root: String, path: String) -> bool:
	var normalized_root := root.simplify_path().replace("\\", "/").trim_suffix("/") + "/"
	var normalized_path := path.simplify_path().replace("\\", "/")
	return normalized_path.begins_with(normalized_root)


static func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path


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


static func _failure(errors: Array) -> Dictionary:
	var strings: Array[String] = []
	for error in errors: strings.append(str(error))
	return {"success": false, "catalog": {}, "errors": strings}
