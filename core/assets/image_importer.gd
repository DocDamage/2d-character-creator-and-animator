# ImageImporter — Handles validation, metadata extraction, and loading for image assets
class_name ImageImporter
extends RefCounted


static func is_supported_format(p_path: String) -> bool:
	var ext := p_path.get_extension().to_lower()
	return ext in ["png", "webp", "jpg", "jpeg"]


static func inspect_image(p_path: String) -> Dictionary:
	if not FileAccess.file_exists(p_path):
		return {"valid": false, "error": "File does not exist: " + p_path}
	
	if not is_supported_format(p_path):
		return {"valid": false, "error": "Unsupported file format: " + p_path.get_extension()}
	
	var img := Image.load_from_file(p_path)
	if img == null or img.is_empty():
		return {"valid": false, "error": "Failed to load image data from: " + p_path}
	
	var bytes := FileAccess.get_file_as_bytes(p_path)
	var checksum := FileAccess.get_file_as_bytes(p_path).hex_encode()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	var hash_bytes := ctx.finish()
	checksum = hash_bytes.hex_encode()
	
	return {
		"valid": true,
		"width": img.get_width(),
		"height": img.get_height(),
		"format": img.get_format(),
		"has_alpha": img.detect_alpha() != Image.ALPHA_NONE,
		"checksum": checksum,
		"file_size": bytes.size()
	}


static func import_image(p_path: String, p_registry: AssetRegistry = null, p_category: String = AssetRegistry.CATEGORY_SOURCE_ART) -> Dictionary:
	var info := inspect_image(p_path)
	if not info.get("valid", false):
		return info
	
	var metadata := {
		"width": info["width"],
		"height": info["height"],
		"checksum": info["checksum"],
		"format": info["format"],
		"has_alpha": info["has_alpha"],
		"file_size": info["file_size"],
		"profile": AssetRegistry.PROFILE_PIXEL
	}
	
	if p_registry != null:
		return p_registry.register_asset(p_path, p_category, metadata)
	
	return metadata
