# AssetImportPreflight -- Import-first checks and provenance helpers.
#
# This service never changes pixels or chooses replacement artwork.  It gives
# the artist a deterministic report before an import, and a non-destructive
# audit of the artwork already registered in a project.
class_name AssetImportPreflight
extends RefCounted

const ImageImporterScript = preload("res://core/assets/image_importer.gd")

const MAX_IMPORT_DIMENSION := 8192
const LARGE_IMPORT_BYTES := 32 * 1024 * 1024
const LARGE_IMPORT_PIXELS := 16 * 1024 * 1024


static func inspect_paths(paths: Array, registry = null, options: Dictionary = {}) -> Dictionary:
	var files: Array = []
	var errors: Array = []
	var warnings: Array = []
	var seen: Dictionary = {}
	for raw_path in paths:
		var path := str(raw_path).strip_edges()
		if path.is_empty():
			var empty := _issue("empty_path", "error", "Choose an artwork file before importing.", "")
			files.append({"path": "", "valid": false, "errors": [empty], "warnings": [], "facts": {}})
			errors.append(empty)
			continue
		var normalized := _normalized_path(path)
		var report := inspect_path(path, registry, options)
		if seen.has(normalized):
			var duplicate_path := _issue("duplicate_selection", "warning", "This file was selected more than once; it will be imported only once.", path)
			report.warnings.append(duplicate_path)
			warnings.append(duplicate_path)
		seen[normalized] = true
		files.append(report)
		errors.append_array(report.get("errors", []))
		warnings.append_array(report.get("warnings", []))
	return {
		"success": errors.is_empty(),
		"files": files,
		"errors": errors,
		"warnings": warnings,
		"error_count": errors.size(),
		"warning_count": warnings.size(),
	}


static func inspect_path(source_path: String, registry = null, options: Dictionary = {}) -> Dictionary:
	var path := source_path.strip_edges()
	var report := {
		"path": path,
		"valid": false,
		"errors": [],
		"warnings": [],
		"facts": {},
		"duplicate_asset_ids": [],
		"provenance": {},
	}
	if path.is_empty():
		report.errors.append(_issue("empty_path", "error", "Choose an artwork file before importing.", path))
		return report
	if not FileAccess.file_exists(path):
		report.errors.append(_issue("missing_source", "error", "Artwork file no longer exists: " + path.get_file(), path))
		return report
	if not ImageImporterScript.is_supported_format(path):
		report.errors.append(_issue("unsupported_format", "error", "Use PNG, WebP, JPEG, or JPG artwork. '%s' is not supported." % path.get_extension(), path))
		return report
	var inspection: Dictionary = ImageImporterScript.inspect_image(path)
	if not bool(inspection.get("valid", false)):
		report.errors.append(_issue("unreadable_image", "error", str(inspection.get("error", "Artwork could not be read.")), path))
		return report
	var width := int(inspection.get("width", 0))
	var height := int(inspection.get("height", 0))
	var file_size := int(inspection.get("file_size", 0))
	var checksum := str(inspection.get("checksum", ""))
	report.facts = {
		"width": width,
		"height": height,
		"file_size": file_size,
		"checksum": checksum,
		"has_alpha": bool(inspection.get("has_alpha", false)),
		"format": str(path.get_extension()).to_lower(),
	}
	if width <= 0 or height <= 0:
		report.errors.append(_issue("empty_dimensions", "error", "Artwork has no usable pixel dimensions.", path))
		return report
	if width > int(options.get("max_dimension", MAX_IMPORT_DIMENSION)) or height > int(options.get("max_dimension", MAX_IMPORT_DIMENSION)):
		report.errors.append(_issue("dimensions_too_large", "error", "Artwork exceeds the supported 8192 px import dimension.", path, {"width": width, "height": height}))
	if width * height > LARGE_IMPORT_PIXELS:
		report.warnings.append(_issue("large_pixel_area", "warning", "This layer is large enough to make live preview and review packages slower.", path, {"pixels": width * height}))
	if file_size > LARGE_IMPORT_BYTES:
		report.warnings.append(_issue("large_file", "warning", "This artwork is larger than 32 MB; consider a smaller source copy for faster project saves.", path, {"bytes": file_size}))
	var image := Image.load_from_file(path)
	if image != null and not image.is_empty() and image.detect_alpha() != Image.ALPHA_NONE and image.get_used_rect().size == Vector2i.ZERO:
		report.errors.append(_issue("fully_transparent", "error", "This artwork is fully transparent and would not be visible in the character.", path))
	var canvas: Dictionary = options.get("canvas", {}) as Dictionary
	var canvas_width := int(canvas.get("width", 0))
	var canvas_height := int(canvas.get("height", 0))
	if canvas_width > 0 and canvas_height > 0 and (width > canvas_width * 4 or height > canvas_height * 4):
		report.warnings.append(_issue("oversized_for_canvas", "warning", "This layer is more than four times the selected canvas in one dimension; verify its intended scale.", path, {"canvas": [canvas_width, canvas_height]}))
	if registry != null and not checksum.is_empty():
		var excluded_id := str(options.get("exclude_asset_id", ""))
		for raw_asset in registry.list_assets():
			var asset: Dictionary = raw_asset
			var asset_id := str(asset.get("asset_id", ""))
			if asset_id == excluded_id:
				continue
			if str(asset.get("checksum", "")) == checksum:
				report.duplicate_asset_ids.append(asset_id)
		if not report.duplicate_asset_ids.is_empty():
			report.warnings.append(_issue("duplicate_artwork", "warning", "This file matches artwork already registered in the project. It will remain a separate imported reference unless you choose otherwise.", path, {"asset_ids": report.duplicate_asset_ids.duplicate()}))
	report.provenance = provenance_from_inspection(path, inspection)
	report.valid = (report.errors as Array).is_empty()
	return report


static func audit_registry(registry, options: Dictionary = {}) -> Dictionary:
	var assets: Array = []
	var errors: Array = []
	var warnings: Array = []
	if registry == null:
		return {"success": false, "assets": [], "errors": [_issue("no_registry", "error", "No project asset registry is available.", "")], "warnings": []}
	for raw_asset in registry.list_assets():
		var asset: Dictionary = raw_asset
		var asset_id := str(asset.get("asset_id", ""))
		var path := str(asset.get("path", ""))
		var category := str(asset.get("category", "source_art"))
		var asset_report := {"asset_id": asset_id, "path": path, "category": category, "errors": [], "warnings": [], "facts": {}}
		if path.is_empty() or not FileAccess.file_exists(path):
			asset_report.errors.append(_issue("missing_registered_asset", "error", "Registered %s is missing: %s" % ["audio" if category == "audio" else "artwork", path.get_file()], path, {"asset_id": asset_id}))
		elif category != "audio":
			var inspected := inspect_path(path, registry, {"canvas": options.get("canvas", {}), "exclude_asset_id": asset_id})
			asset_report.facts = inspected.get("facts", {})
			asset_report.errors.append_array(inspected.get("errors", []))
			asset_report.warnings.append_array(inspected.get("warnings", []))
			var on_disk_checksum := str((inspected.get("facts", {}) as Dictionary).get("checksum", ""))
			var registered_checksum := str(asset.get("checksum", ""))
			if not registered_checksum.is_empty() and not on_disk_checksum.is_empty() and registered_checksum != on_disk_checksum:
				asset_report.warnings.append(_issue("asset_changed_on_disk", "warning", "Artwork changed on disk since it was imported; review it before export.", path, {"asset_id": asset_id}))
		var metadata: Dictionary = asset.get("metadata", {}) as Dictionary
		var provenance: Dictionary = metadata.get("provenance", {}) as Dictionary
		if category in ["source_art", "audio"] and _provenance_is_incomplete(provenance):
			asset_report.warnings.append(_issue("provenance_incomplete", "warning", "Imported %s has no author, license, or source reference recorded." % ("audio" if category == "audio" else "artwork"), path, {"asset_id": asset_id}))
		assets.append(asset_report)
		errors.append_array(asset_report.errors)
		warnings.append_array(asset_report.warnings)
	return {"success": errors.is_empty(), "assets": assets, "errors": errors, "warnings": warnings, "error_count": errors.size(), "warning_count": warnings.size()}


static func provenance_from_inspection(source_path: String, inspection: Dictionary) -> Dictionary:
	return {
		"source_filename": source_path.get_file(),
		"source_checksum": str(inspection.get("checksum", "")),
		"source_format": source_path.get_extension().to_lower(),
		"imported_at": Time.get_unix_time_from_system(),
		"author": "",
		"license": "",
		"source_reference": "",
	}


static func merge_provenance(existing: Dictionary, updates: Dictionary) -> Dictionary:
	var merged := existing.duplicate(true)
	for key in ["author", "license", "source_reference"]:
		if updates.has(key):
			merged[key] = str(updates.get(key, "")).strip_edges()
	return merged


static func format_summary(report: Dictionary) -> String:
	var errors := int(report.get("error_count", (report.get("errors", []) as Array).size()))
	var warnings := int(report.get("warning_count", (report.get("warnings", []) as Array).size()))
	if errors > 0:
		return "%d blocking issue%s · %d warning%s" % [errors, "s" if errors != 1 else "", warnings, "s" if warnings != 1 else ""]
	if warnings > 0:
		return "Import check passed with %d warning%s" % [warnings, "s" if warnings != 1 else ""]
	return "Import check passed"


static func _provenance_is_incomplete(provenance: Dictionary) -> bool:
	return str(provenance.get("author", "")).strip_edges().is_empty() and str(provenance.get("license", "")).strip_edges().is_empty() and str(provenance.get("source_reference", "")).strip_edges().is_empty()


static func _normalized_path(path: String) -> String:
	return path.replace("\\", "/").simplify_path().to_lower()


static func _issue(id: String, severity: String, message: String, path: String, context: Dictionary = {}) -> Dictionary:
	var issue := {"id": id, "severity": severity, "message": message, "path": path}
	for key in context:
		issue[key] = context[key]
	return issue
