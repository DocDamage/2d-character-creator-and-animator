# LpcHybridClipEvaluator -- Shared typed-track evaluator for hybrid LPC preview and export frames.
class_name LpcHybridClipEvaluator
extends RefCounted

const ClipSchemaScript = preload("res://lpc/animation/lpc_typed_clip_schema.gd")
const TrackSchemaScript = preload("res://lpc/animation/lpc_typed_track_schema.gd")
const NativeEvaluatorScript = preload("res://lpc/animation/lpc_native_clip_evaluator.gd")
const LayoutScript = preload("res://lpc/layout/lpc_sheet_layout.gd")
const PaletteMapperScript = preload("res://lpc/animation/lpc_palette_mapper.gd")
const DerivativeStoreScript = preload("res://lpc/pixels/lpc_derivative_store.gd")
const TransformRendererScript = preload("res://lpc/render/lpc_layer_transform_renderer.gd")
const ReferenceRendererScript = preload("res://lpc/render/lpc_reference_renderer.gd")
const SnapshotScript = preload("res://lpc/render/lpc_render_snapshot.gd")
const LicenseResolverScript = preload("res://lpc/licensing/lpc_license_resolver.gd")
const StrictFrameBakerScript = preload("res://lpc/deformation/lpc_strict_frame_baker.gd")


static func evaluate(catalog: Dictionary, profile: Dictionary, clip: Dictionary, time: float, previous_time: float = -1.0) -> Dictionary:
	var errors := ClipSchemaScript.validate(clip)
	if not errors.is_empty(): return {"success": false, "errors": errors, "warnings": [], "image": null}
	var duration := float(clip.get("duration", 0.1)); var playhead := clampf(time, 0.0, duration)
	if bool(clip.get("loop", true)) and duration > 0.0: playhead = fposmod(maxf(0.0, time), duration)
	var state := _initial_state(catalog, profile, clip)
	var warnings: Array[String] = []
	for raw_track in clip.get("tracks", []):
		if not raw_track is Dictionary: continue
		var track: Dictionary = raw_track
		if bool(track.get("muted", false)): continue
		_apply_track(state, track, playhead, previous_time, profile, warnings)
	var render_layers: Array = []; var records: Array = []; var credit_assets: Array = []
	for instance_id in state.layers:
		var layer_state: Dictionary = state.layers[instance_id]
		if not bool(layer_state.get("visible", true)): continue
		var rendered := _render_layer(catalog, profile, str(instance_id), layer_state, playhead, str(state.get("direction_id", "down")), state.get("mesh_state", {}))
		if not bool(rendered.get("success", false)):
			warnings.append_array(rendered.get("warnings", [])); continue
		var record: Dictionary = rendered.record; records.append(record); credit_assets.append(rendered.asset)
		render_layers.append({"layer_id": instance_id, "z": int(layer_state.get("z", record.get("z", 0))), "image": rendered.image, "offset": [0, 0]})
	var canvas := _canvas(profile)
	var composed := ReferenceRendererScript.render(render_layers, Vector2i(int(canvas.width), int(canvas.height)))
	if not bool(composed.get("success", false)): return {"success": false, "errors": composed.get("errors", []), "warnings": warnings, "image": null}
	var policy: Dictionary = profile.get("policy", {})
	var credits := LicenseResolverScript.exact_credit_manifest(credit_assets, str(policy.get("profile_id", "full_source")), profile.get("selected_license_options", {}), policy.get("custom", {}))
	var snapshot := SnapshotScript.create({"project_profile_version": profile.get("profile_schema_version", ""), "source_lock_signature": (profile.get("source_lock", {}) as Dictionary).get("signature", ""), "catalog_signature": catalog.get("catalog_signature", ""), "clip_id": clip.get("clip_id", ""), "playhead": playhead, "direction_id": state.direction_id, "layers": records, "palette_maps": _palette_state(state), "evaluated_geometry": {"rig": state.rig_state, "mesh": state.mesh_state}, "layer_order": records.map(func(value): return str((value as Dictionary).get("instance_id", ""))), "strictness_mode": "strict_lpc_raster", "baker_version": "hybrid-clip-1.0.0", "canvas": canvas, "credit_manifest_hash": JSON.stringify(credits.get("credits", [])).sha256_text()})
	return {"success": true, "errors": [], "warnings": warnings, "image": composed.image, "output_hash": composed.output_hash, "snapshot": snapshot, "layers": records, "events": state.events, "direction_id": state.direction_id, "credits": credits, "track_state": state}


static func _initial_state(catalog: Dictionary, profile: Dictionary, clip: Dictionary) -> Dictionary:
	var layers: Dictionary = {}; var assets: Dictionary = catalog.get("assets", {})
	for raw_selection in profile.get("selections", []):
		if not raw_selection is Dictionary: continue
		var selection: Dictionary = raw_selection; var instance_id := str(selection.get("instance_id", "")); var asset: Dictionary = assets.get(str(selection.get("asset_id", "")), {})
		if instance_id.is_empty() or asset.is_empty(): continue
		layers[instance_id] = {"instance_id": instance_id, "asset_id": str(asset.get("asset_id", "")), "animation_id": str(clip.get("default_animation_id", "walk")), "visible": bool(selection.get("visible", true)), "z": int((asset.get("z_order", {}) as Dictionary).get("default", 0)), "transform": {}, "palette_map": {}, "cel_derivative_id": "", "representation": str(selection.get("representation", "FRAME_NATIVE"))}
	return {"layers": layers, "direction_id": str(clip.get("default_direction_id", "down")), "events": [], "rig_state": {}, "mesh_state": {}}


static func _apply_track(state: Dictionary, track: Dictionary, time: float, previous_time: float, profile: Dictionary, warnings: Array[String]) -> void:
	var kind := str(track.get("track_type", "")).to_lower(); var target_id := str(track.get("target_id", ""))
	if kind == "event":
		for event in TrackSchemaScript.events_between(track, previous_time, time): state.events.append({"track_id": track.get("track_id", ""), "target_id": target_id, "event": event.get("value")})
		return
	var value = TrackSchemaScript.value_at(track, time)
	if value == null: return
	if kind == "direction": state.direction_id = str(value); return
	if kind in ["rig_bone_transform", "ik_target"]:
		if not _known_rig_target(profile, target_id): warnings.append("Track '%s' targets missing rig/bone '%s'." % [track.get("track_id", ""), target_id])
		else: state.rig_state[target_id] = value
		return
	if kind == "mesh_control":
		if not _known_mesh(profile, target_id): warnings.append("Track '%s' targets missing frame mesh '%s'." % [track.get("track_id", ""), target_id])
		else: state.mesh_state[target_id] = value
		return
	if not state.layers.has(target_id):
		warnings.append("Track '%s' targets missing layer '%s'." % [track.get("track_id", ""), target_id]); return
	var layer: Dictionary = state.layers[target_id]
	match kind:
		"source_frame":
			if value is Dictionary:
				layer["animation_id"] = str((value as Dictionary).get("animation_id", layer.get("animation_id", "walk")))
				if (value as Dictionary).has("asset_id"): layer["asset_id"] = str((value as Dictionary).get("asset_id", ""))
			else: layer["animation_id"] = str(value)
		"image_cel_swap":
			if value is Dictionary:
				layer["cel_derivative_id"] = str((value as Dictionary).get("derivative_id", "")); if (value as Dictionary).has("asset_id"): layer["asset_id"] = str((value as Dictionary).get("asset_id", ""))
			else: layer["cel_derivative_id"] = str(value)
		"layer_transform": layer["transform"] = _merge(layer.get("transform", {}), value as Dictionary if value is Dictionary else {})
		"visibility": layer["visible"] = bool(value)
		"z_order": layer["z"] = int(value)
		"palette": layer["palette_map"] = (value as Dictionary).get("mappings", value) if value is Dictionary else {}
		_: warnings.append("Track '%s' has unsupported executable type '%s'." % [track.get("track_id", ""), kind])
	state.layers[target_id] = layer


static func _render_layer(catalog: Dictionary, profile: Dictionary, instance_id: String, state: Dictionary, time: float, direction_id: String, mesh_state: Dictionary = {}) -> Dictionary:
	var asset: Dictionary = (catalog.get("assets", {}) as Dictionary).get(str(state.get("asset_id", "")), {})
	if asset.is_empty(): return {"success": false, "warnings": ["Layer '%s' references an unavailable asset." % instance_id]}
	var frame: Image = null; var frame_record: Dictionary = {}; var derivative_id := str(state.get("cel_derivative_id", ""))
	if not derivative_id.is_empty():
		var derivative := _derivative(profile, derivative_id); frame = DerivativeStoreScript.load_image(derivative)
		if frame == null or frame.is_empty(): return {"success": false, "warnings": ["Layer '%s' references missing project-owned cel '%s'." % [instance_id, derivative_id]]}
		frame_record = {"instance_id": instance_id, "asset_id": asset.get("asset_id", ""), "derivative_id": derivative_id, "mode": "cel", "z": state.get("z", 0)}
	else:
		var layout: Dictionary = (catalog.get("layouts", {}) as Dictionary).get(str(asset.get("layout_id", "")), {})
		if str(state.get("animation_id", "")) not in LayoutScript.normalize_supported_animations(asset, layout) or direction_id not in asset.get("direction_ids", []): return {"success": false, "warnings": ["Layer '%s' has no explicit native source for %s/%s." % [instance_id, state.get("animation_id", ""), direction_id]]}
		var native := NativeEvaluatorScript.frame_for_layer(catalog, profile, {"instance_id": instance_id, "asset": asset}, str(state.get("animation_id", "walk")), direction_id, time)
		if not bool(native.get("success", false)): return {"success": false, "warnings": native.get("errors", [])}
		frame = native.image; frame_record = native.record
	if not (state.get("palette_map", {}) as Dictionary).is_empty(): frame = PaletteMapperScript.apply(frame, state.get("palette_map", {}))
	var warped := _apply_frame_warp(profile, asset, frame, mesh_state)
	var layer_warnings: Array = warped.get("warnings", [])
	if warped.has("image") and warped.image != null:
		frame = warped.image
		frame_record["mesh_id"] = warped.get("mesh_id", "")
		frame_record["mesh_snapshot_hash"] = warped.get("snapshot_hash", "")
	frame = TransformRendererScript.render(frame, Vector2i(int(_canvas(profile).width), int(_canvas(profile).height)), state.get("transform", {}))
	frame_record["instance_id"] = instance_id; frame_record["asset_id"] = asset.get("asset_id", ""); frame_record["z"] = state.get("z", 0); frame_record["transform"] = state.get("transform", {}); frame_record["cel_derivative_id"] = derivative_id
	return {"success": true, "warnings": layer_warnings, "image": frame, "record": frame_record, "asset": asset}


static func _apply_frame_warp(profile: Dictionary, asset: Dictionary, frame: Image, mesh_state: Dictionary) -> Dictionary:
	if mesh_state.is_empty(): return {"success": true}
	var meshes: Array = profile.get("frame_meshes", [])
	var selected_mesh: Dictionary = {}
	var control_override: Dictionary = {}
	for mesh_id in mesh_state:
		for raw_mesh in meshes:
			if not raw_mesh is Dictionary or str((raw_mesh as Dictionary).get("mesh_id", "")) != str(mesh_id): continue
			var mesh: Dictionary = raw_mesh
			if str(mesh.get("source_asset_id", "")) != str(asset.get("asset_id", "")): continue
			selected_mesh = mesh.duplicate(true)
			if mesh_state[mesh_id] is Dictionary: control_override = (mesh_state[mesh_id] as Dictionary).duplicate(true)
			break
		if not selected_mesh.is_empty(): break
	if selected_mesh.is_empty(): return {"success": true}
	if str(selected_mesh.get("source_frame_hash", "")) != _frame_hash(frame):
		return {"success": true, "warnings": ["Frame mesh '%s' is bound to a different source frame; hybrid playback left this layer native." % selected_mesh.get("mesh_id", "")]}
	var baked := StrictFrameBakerScript.bake(selected_mesh, frame, {
		"control_state": control_override,
		"source_asset_id": asset.get("asset_id", ""),
		"source_asset_sha256": asset.get("source_sha256", ""),
		"profile": profile,
	})
	if not bool(baked.get("success", false)):
		return {"success": true, "warnings": baked.get("errors", ["Strict frame warp failed; hybrid playback left this layer native."])}
	return {"success": true, "image": baked.image, "mesh_id": selected_mesh.get("mesh_id", ""), "snapshot_hash": (baked.get("snapshot", {}) as Dictionary).get("snapshot_hash", "")}


static func _frame_hash(image: Image) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(image.get_data())
	return hashing.finish().hex_encode()


static func _canvas(profile: Dictionary) -> Dictionary:
	var canvas: Dictionary = profile.get("native_canvas", {}); return {"width": int(canvas.get("width", 64)), "height": int(canvas.get("height", 64)), "origin": [0, 0]}
static func _derivative(profile: Dictionary, derivative_id: String) -> Dictionary:
	for raw in profile.get("derivative_references", []): if raw is Dictionary and str((raw as Dictionary).get("derivative_id", "")) == derivative_id: return raw
	return {}
static func _known_rig_target(profile: Dictionary, target_id: String) -> bool:
	for raw in profile.get("rig_adapters", []): if raw is Dictionary and (str((raw as Dictionary).get("adapter_id", "")) == target_id or target_id in (raw as Dictionary).get("bone_ids", [])): return true
	return false
static func _known_mesh(profile: Dictionary, target_id: String) -> bool:
	for raw in profile.get("frame_meshes", []): if raw is Dictionary and str((raw as Dictionary).get("mesh_id", "")) == target_id: return true
	return false
static func _merge(left: Dictionary, right: Dictionary) -> Dictionary:
	var result: Dictionary = left.duplicate(true)
	for key in right:
		result[key] = right[key]
	return result
static func _palette_state(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for instance_id in state.layers:
		result[instance_id] = (state.layers[instance_id] as Dictionary).get("palette_map", {})
	return result
