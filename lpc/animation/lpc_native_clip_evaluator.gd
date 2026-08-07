# LpcNativeClipEvaluator -- Shared native-frame evaluation for creator preview and exports.
class_name LpcNativeClipEvaluator
extends RefCounted

const ResolverScript = preload("res://lpc/animation/lpc_native_compatibility_resolver.gd")
const LayoutScript = preload("res://lpc/layout/lpc_sheet_layout.gd")
const PaletteMapperScript = preload("res://lpc/animation/lpc_palette_mapper.gd")
const SnapshotScript = preload("res://lpc/render/lpc_render_snapshot.gd")
const RendererScript = preload("res://lpc/render/lpc_reference_renderer.gd")
const LicenseResolverScript = preload("res://lpc/licensing/lpc_license_resolver.gd")


static func evaluate(catalog: Dictionary, profile: Dictionary, animation_id: String, direction_id: String, playhead: float = 0.0) -> Dictionary:
	var resolution := ResolverScript.resolve(catalog, profile, animation_id, direction_id)
	if not (resolution.get("errors", []) as Array).is_empty() or not (resolution.get("conflicts", []) as Array).is_empty():
		return {"success": false, "errors": resolution.get("errors", []), "conflicts": resolution.get("conflicts", []), "image": null, "layers": []}
	var render_layers: Array = []
	var layer_records: Array = []
	var assets: Array = []
	var errors: Array[String] = []
	for raw_layer in resolution.get("layers", []):
		var layer: Dictionary = raw_layer
		if bool(layer.get("hidden", false)):
			continue
		var frame := _frame_for_layer(catalog, profile, layer, animation_id, direction_id, playhead)
		if not bool(frame.get("success", false)):
			errors.append_array(frame.get("errors", []))
			continue
		var asset: Dictionary = layer.get("asset", {})
		assets.append(asset)
		render_layers.append({"layer_id": str(layer.get("instance_id", "")), "z": int((asset.get("z_order", {}) as Dictionary).get("default", 0)), "image": frame.image, "offset": frame.get("offset", [0, 0]), "visible": true})
		layer_records.append(frame.get("record", {}))
	if not errors.is_empty():
		return {"success": false, "errors": errors, "conflicts": [], "image": null, "layers": layer_records}
	var canvas := _canvas(profile, layer_records)
	var composed := RendererScript.render(render_layers, Vector2i(int(canvas.width), int(canvas.height)))
	if not bool(composed.get("success", false)):
		return {"success": false, "errors": composed.get("errors", []), "conflicts": [], "image": null, "layers": layer_records}
	var policy: Dictionary = profile.get("policy", {})
	var credits := LicenseResolverScript.exact_credit_manifest(assets, str(policy.get("profile_id", "full_source")), profile.get("selected_license_options", {}), policy.get("custom", {}))
	var snapshot := SnapshotScript.create({
		"project_profile_version": profile.get("profile_schema_version", ""), "source_lock_signature": (profile.get("source_lock", {}) as Dictionary).get("signature", ""),
		"catalog_signature": catalog.get("catalog_signature", ""), "clip_id": animation_id, "playhead": playhead, "direction_id": direction_id,
		"layers": layer_records, "palette_maps": profile.get("palette_state", {}), "layer_order": layer_records.map(func(value): return str((value as Dictionary).get("instance_id", ""))),
		"strictness_mode": "strict_lpc_raster", "baker_version": "native-frame-1.0.0", "canvas": canvas,
		"credit_manifest_hash": JSON.stringify(credits.get("credits", [])).sha256_text(),
	})
	return {"success": true, "errors": [], "conflicts": [], "image": composed.image, "output_hash": composed.output_hash, "layers": layer_records, "snapshot": snapshot, "credits": credits, "canvas": canvas}


static func frame_count(catalog: Dictionary, profile: Dictionary, animation_id: String, direction_id: String) -> int:
	var resolution := ResolverScript.resolve(catalog, profile, animation_id, direction_id)
	if not bool(resolution.get("success", false)) or (resolution.get("layers", []) as Array).is_empty():
		return 0
	var layer: Dictionary = resolution.layers[0]
	var asset: Dictionary = layer.get("asset", {})
	var layout: Dictionary = (catalog.get("layouts", {}) as Dictionary).get(str(asset.get("layout_id", "")), {})
	var resolved := LayoutScript.resolve_animation_id(animation_id, layout)
	return ((layout.get("animations", {}) as Dictionary).get(resolved, {}) as Dictionary).get("cycle", []).size()


static func frame_for_layer(catalog: Dictionary, profile: Dictionary, layer: Dictionary, animation_id: String, direction_id: String, playhead: float) -> Dictionary:
	return _frame_for_layer(catalog, profile, layer, animation_id, direction_id, playhead)


static func _frame_for_layer(catalog: Dictionary, profile: Dictionary, layer: Dictionary, animation_id: String, direction_id: String, playhead: float) -> Dictionary:
	var asset: Dictionary = layer.get("asset", {})
	var layout: Dictionary = (catalog.get("layouts", {}) as Dictionary).get(str(asset.get("layout_id", "")), {})
	var resolved := LayoutScript.resolve_animation_id(animation_id, layout)
	var definition: Dictionary = (layout.get("animations", {}) as Dictionary).get(resolved, {})
	var cycle: Array = definition.get("cycle", [])
	if cycle.is_empty():
		return {"success": false, "errors": ["Asset '%s' has no playable '%s' cycle." % [asset.get("asset_id", ""), animation_id]]}
	var duration := maxf(0.001, float(definition.get("frame_duration", 0.1)))
	var index := posmod(int(floor(maxf(0.0, playhead) / duration)), cycle.size())
	var reference := LayoutScript.frame_ref(asset, layout, animation_id, direction_id, index)
	if not bool(reference.get("success", false)):
		return {"success": false, "errors": reference.get("errors", [])}
	var source_path := str(catalog.get("source_root", "")).path_join(str(asset.get("source_relative_path", "")))
	var source := Image.load_from_file(source_path)
	if source == null or source.is_empty():
		return {"success": false, "errors": ["Could not load immutable LPC source '%s'." % source_path]}
	var rect_values: Array = reference.get("source_rect", [])
	var rect := Rect2i(int(rect_values[0]), int(rect_values[1]), int(rect_values[2]), int(rect_values[3]))
	if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > source.get_width() or rect.end.y > source.get_height():
		return {"success": false, "errors": ["Frame reference for '%s' is outside its source image." % asset.get("asset_id", "")]}
	var frame := source.get_region(rect)
	frame = PaletteMapperScript.apply(frame, PaletteMapperScript.mapping_for(profile, str(asset.get("asset_id", ""))))
	var offset: Array = reference.get("logical_origin", [0, 0])
	var record := {
		"instance_id": str(layer.get("instance_id", "")), "asset_id": str(asset.get("asset_id", "")), "source_hash": str(asset.get("source_sha256", "")),
		"frame_ref": reference.duplicate(true), "source_path": str(asset.get("source_relative_path", "")), "z": int((asset.get("z_order", {}) as Dictionary).get("default", 0)), "offset": offset.duplicate(),
	}
	return {"success": true, "image": frame, "offset": offset, "record": record, "errors": []}


static func _canvas(profile: Dictionary, layer_records: Array) -> Dictionary:
	var configured: Dictionary = profile.get("native_canvas", {})
	var width := int(configured.get("width", 64))
	var height := int(configured.get("height", 64))
	for record in layer_records:
		var rect: Array = ((record as Dictionary).get("frame_ref", {}) as Dictionary).get("source_rect", [])
		if rect.size() == 4:
			width = maxi(width, int(rect[2])); height = maxi(height, int(rect[3]))
	return {"width": width, "height": height, "origin": [0, 0]}
