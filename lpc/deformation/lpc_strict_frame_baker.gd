# LpcStrictFrameBaker -- Authoritative CPU strict-raster bake for one LPC source frame.
class_name LpcStrictFrameBaker
extends RefCounted

const MeshScript = preload("res://lpc/deformation/lpc_frame_mesh.gd")
const ControlsScript = preload("res://lpc/deformation/lpc_frame_mesh_controls.gd")
const DiagnosticsScript = preload("res://lpc/deformation/lpc_deformation_diagnostics.gd")
const RasterizerScript = preload("res://lpc/render/lpc_strict_triangle_rasterizer.gd")
const SnapshotScript = preload("res://lpc/render/lpc_render_snapshot.gd")

const BAKER_VERSION := "lpc-strict-frame-1.0.0"


static func bake(mesh: Dictionary, source: Image, options: Dictionary = {}) -> Dictionary:
	var started := Time.get_ticks_usec()
	var errors := _source_binding_errors(mesh, source, options)
	var controls := ControlsScript.evaluate(mesh, options.get("control_state", {}))
	if not bool(controls.get("success", false)): errors.append_array(controls.get("errors", []))
	var vertices: Array = controls.get("vertices", [])
	var preliminary := DiagnosticsScript.inspect(mesh, source, vertices)
	errors.append_array(preliminary.get("errors", []))
	if not errors.is_empty(): return _failure(errors, preliminary.get("warnings", []), preliminary.get("metrics", {}))
	var dimensions: Array = mesh.get("source_image_dimensions", [])
	var canvas := _canvas_size(dimensions, options)
	var output_path := str(options.get("output_path", ""))
	var raster := RasterizerScript.bake(source, mesh.get("uvs", []), vertices, mesh.get("triangle_indices", []), canvas, output_path)
	var diagnostics := DiagnosticsScript.inspect(mesh, source, vertices, raster)
	var all_errors: Array = []
	all_errors.append_array(raster.get("errors", []))
	all_errors.append_array(diagnostics.get("errors", []))
	var deterministic := true
	var repeat_hash := str(raster.get("output_hash", ""))
	if bool(options.get("verify_determinism", true)) and all_errors.is_empty():
		var repeated := RasterizerScript.bake(source, mesh.get("uvs", []), vertices, mesh.get("triangle_indices", []), canvas)
		repeat_hash = str(repeated.get("output_hash", ""))
		deterministic = bool(repeated.get("success", false)) and repeat_hash == str(raster.get("output_hash", ""))
		if not deterministic: all_errors.append("Strict raster bake is nondeterministic for this render snapshot.")
	var snapshot := _snapshot(mesh, vertices, canvas, options)
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	var artifact := {
		"format": "lpc_strict_frame_bake",
		"baker_version": BAKER_VERSION,
		"mesh_id": mesh.get("mesh_id", ""),
		"source_asset_id": mesh.get("source_asset_id", ""),
		"source_asset_sha256": mesh.get("source_asset_sha256", ""),
		"source_frame_hash": mesh.get("source_frame_hash", ""),
		"output_hash": raster.get("output_hash", ""),
		"snapshot_hash": snapshot.get("snapshot_hash", ""),
		"output_path": output_path,
		"deterministic": deterministic,
		"repeat_hash": repeat_hash,
		"metrics": diagnostics.get("metrics", {}),
		"audit": raster.get("audit", {}),
		"elapsed_ms": elapsed_ms,
	}
	var audit_path := _write_artifact(output_path, str(options.get("audit_path", "")), artifact)
	if not audit_path.is_empty(): artifact["audit_path"] = audit_path
	return {
		"success": all_errors.is_empty() and bool(raster.get("success", false)),
		"errors": all_errors,
		"warnings": diagnostics.get("warnings", []),
		"image": raster.get("image", null),
		"output_hash": raster.get("output_hash", ""),
		"repeat_hash": repeat_hash,
		"deterministic": deterministic,
		"vertices": vertices,
		"snapshot": snapshot,
		"diagnostics": diagnostics,
		"audit": raster.get("audit", {}),
		"artifact": artifact,
		"output_path": output_path,
	}


static func preview(mesh: Dictionary, source: Image, options: Dictionary = {}) -> Dictionary:
	var preview_options := options.duplicate(true)
	preview_options["verify_determinism"] = false
	preview_options.erase("output_path")
	var result := bake(mesh, source, preview_options)
	result["verified"] = false
	return result


static func _source_binding_errors(mesh: Dictionary, source: Image, options: Dictionary) -> Array[String]:
	var errors := MeshScript.validate(mesh)
	if source == null or source.is_empty():
		errors.append("Strict bake requires a decoded source image.")
		return errors
	var expected_asset_hash := str(mesh.get("source_asset_sha256", ""))
	var actual_asset_hash := str(options.get("source_asset_sha256", ""))
	if not actual_asset_hash.is_empty() and not expected_asset_hash.is_empty() and expected_asset_hash != "legacy_unbound" and expected_asset_hash != actual_asset_hash:
		errors.append("Mesh source asset SHA-256 does not match the selected catalog asset.")
	var expected_asset_id := str(mesh.get("source_asset_id", ""))
	var actual_asset_id := str(options.get("source_asset_id", ""))
	if not actual_asset_id.is_empty() and not expected_asset_id.is_empty() and expected_asset_id != actual_asset_id:
		errors.append("Mesh source asset ID does not match the selected layer.")
	return errors


static func _canvas_size(dimensions: Array, options: Dictionary) -> Vector2i:
	var raw: Variant = options.get("canvas_size", dimensions)
	if raw is Vector2i: return raw
	if raw is Vector2: return Vector2i(raw)
	if raw is Array and (raw as Array).size() >= 2:
		return Vector2i(int((raw as Array)[0]), int((raw as Array)[1]))
	return Vector2i(64, 64)


static func _snapshot(mesh: Dictionary, vertices: Array, canvas: Vector2i, options: Dictionary) -> Dictionary:
	var profile: Dictionary = options.get("profile", {})
	var catalog: Dictionary = options.get("catalog", {})
	return SnapshotScript.create({
		"project_profile_version": profile.get("profile_schema_version", ""),
		"source_lock_signature": (profile.get("source_lock", {}) as Dictionary).get("signature", ""),
		"catalog_signature": catalog.get("catalog_signature", ""),
		"clip_id": str(options.get("clip_id", "")),
		"playhead": float(options.get("playhead", 0.0)),
		"direction_id": str(options.get("direction_id", "down")),
		"layers": [{"mesh_id": mesh.get("mesh_id", ""), "source_asset_id": mesh.get("source_asset_id", ""), "source_frame_hash": mesh.get("source_frame_hash", "")}],
		"evaluated_geometry": {"mesh_id": mesh.get("mesh_id", ""), "vertices": MeshScript.serialize_vectors(vertices), "triangle_indices": mesh.get("triangle_indices", [])},
		"layer_order": [str(mesh.get("source_asset_id", ""))],
		"strictness_mode": "strict_lpc_raster",
		"baker_version": BAKER_VERSION,
		"canvas": {"width": canvas.x, "height": canvas.y, "origin": [0, 0]},
		"credit_manifest_hash": str(options.get("credit_manifest_hash", "")),
	})


static func _write_artifact(output_path: String, requested_audit_path: String, artifact: Dictionary) -> String:
	var audit_path := requested_audit_path
	if audit_path.is_empty() and not output_path.is_empty(): audit_path = output_path.get_basename() + ".audit.json"
	if audit_path.is_empty(): return ""
	var directory := audit_path.get_base_dir()
	if not directory.is_empty():
		var absolute := ProjectSettings.globalize_path(directory) if directory.begins_with("res://") or directory.begins_with("user://") else directory
		if DirAccess.make_dir_recursive_absolute(absolute) != OK: return ""
	var file := FileAccess.open(audit_path, FileAccess.WRITE)
	if file == null: return ""
	file.store_string(JSON.stringify(artifact, "\t"))
	file.close()
	return audit_path


static func _failure(errors: Array, warnings: Array = [], metrics: Dictionary = {}) -> Dictionary:
	var messages: Array[String] = []
	for error in errors: messages.append(str(error))
	return {"success": false, "errors": messages, "warnings": warnings, "image": null, "diagnostics": {"success": false, "errors": messages, "warnings": warnings, "metrics": metrics}}
