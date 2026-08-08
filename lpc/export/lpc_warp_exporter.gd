# LpcWarpExporter -- Exports a verified strict frame-warp PNG with replayable manifest data.
class_name LpcWarpExporter
extends RefCounted

const BakerScript = preload("res://lpc/deformation/lpc_strict_frame_baker.gd")


static func export_mesh(catalog: Dictionary, profile: Dictionary, mesh: Dictionary, source: Image, output_directory: String, options: Dictionary = {}) -> Dictionary:
	if source == null or source.is_empty(): return {"success": false, "errors": ["A decoded source frame is required for strict warp export."]}
	var absolute := ProjectSettings.globalize_path(output_directory) if output_directory.begins_with("user://") or output_directory.begins_with("res://") else output_directory
	if DirAccess.make_dir_recursive_absolute(absolute) != OK: return {"success": false, "errors": ["Could not create strict-warp export folder."]}
	var filename := str(options.get("filename", str(mesh.get("mesh_id", "lpc_warp")).replace(":", "_") + ".png"))
	if not filename.to_lower().ends_with(".png"): filename += ".png"
	var output_path := output_directory.path_join(filename)
	var bake_options := options.duplicate(true)
	bake_options["output_path"] = output_path
	bake_options["profile"] = profile
	bake_options["catalog"] = catalog
	bake_options["source_asset_id"] = str(options.get("source_asset_id", mesh.get("source_asset_id", "")))
	bake_options["source_asset_sha256"] = str(options.get("source_asset_sha256", mesh.get("source_asset_sha256", "")))
	var baked := BakerScript.bake(mesh, source, bake_options)
	if not bool(baked.get("success", false)): return baked
	var manifest := {
		"format": "lpc_strict_frame_warp",
		"mesh": mesh.duplicate(true),
		"artifact": baked.get("artifact", {}),
		"source_lock": profile.get("source_lock", {}),
		"catalog_signature": catalog.get("catalog_signature", ""),
		"selected_license_options": profile.get("selected_license_options", {}),
	}
	var manifest_path := output_directory.path_join(filename.get_basename() + ".manifest.json")
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null: return {"success": false, "errors": ["Could not write strict-warp export manifest."]}
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	return {"success": true, "errors": [], "output_path": output_path, "manifest": manifest_path, "bake": baked, "artifact": baked.get("artifact", {})}
