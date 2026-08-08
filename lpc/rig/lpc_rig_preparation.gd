# LpcRigPreparation -- Converts one immutable LPC reference frame into project-owned cutout pieces.
class_name LpcRigPreparation
extends RefCounted

const PixelModelScript = preload("res://lpc/pixels/lpc_pixel_canvas_model.gd")
const DerivativeStoreScript = preload("res://lpc/pixels/lpc_derivative_store.gd")
const AdapterScript = preload("res://lpc/rig/lpc_rig_adapter.gd")


static func preview(catalog: Dictionary, profile: Dictionary, instance_id: String, options: Dictionary = {}) -> Dictionary:
	var pixels = PixelModelScript.new()
	var source_direction := str(options.get("source_direction_id", options.get("direction_id", "down")))
	var opened := pixels.open_native_frame(catalog, profile, instance_id, str(options.get("animation_id", "walk")), source_direction, int(options.get("logical_frame", 0)))
	if not bool(opened.get("success", false)):
		return opened
	var target_direction := str(options.get("target_direction_id", source_direction))
	var template: Dictionary = (options.get("template", {}) as Dictionary).duplicate(true)
	if template.is_empty():
		template = AdapterScript.standard_template(str(profile.get("body_family_id", "")), target_direction, options)
	var masks: Array = []
	for raw_piece in template.get("pieces", []):
		if raw_piece is Dictionary:
			var piece: Dictionary = raw_piece
			masks.append({"piece_id": piece.get("piece_id", ""), "mask_rect": piece.get("mask_rect", []), "bone_id": piece.get("bone_id", ""), "z_group": piece.get("z_group", "middle")})
	return {
		"success": true,
		"errors": [],
		"image": pixels.image.duplicate(),
		"source_context": pixels.source_context.duplicate(true),
		"template": template,
		"masks": masks,
		"bones": (template.get("bones", {}) as Dictionary).duplicate(true),
		"anchors": (template.get("anchors", {}) as Dictionary).duplicate(true),
		"z_groups": (template.get("z_groups", {}) as Dictionary).duplicate(true),
		"expected_hidden_regions": (template.get("gap_patch_regions", []) as Array).duplicate(true),
	}


static func prepare(catalog: Dictionary, profile: Dictionary, instance_id: String, options: Dictionary = {}) -> Dictionary:
	var pixels = PixelModelScript.new()
	var source_direction := str(options.get("source_direction_id", options.get("direction_id", "down")))
	var opened := pixels.open_native_frame(catalog, profile, instance_id, str(options.get("animation_id", "walk")), source_direction, int(options.get("logical_frame", 0)))
	if not bool(opened.get("success", false)): return opened
	var source: Image = pixels.image
	var context: Dictionary = pixels.source_context.duplicate(true)
	context["source_instance_id"] = instance_id
	context["source_frame_hash"] = _image_hash(source)
	var asset: Dictionary = _asset_for_instance(catalog, profile, instance_id)
	if asset.is_empty(): return {"success": false, "errors": ["The selected LPC layer is no longer available."]}
	var target_direction := str(options.get("target_direction_id", source_direction))
	var template: Dictionary = (options.get("template", {}) as Dictionary).duplicate(true)
	if template.is_empty(): template = AdapterScript.standard_template(str(profile.get("body_family_id", "")), target_direction, options)
	template["direction_id"] = target_direction
	var made := _make_pieces(profile, source, context, template.get("pieces", []), options)
	if not bool(made.get("success", false)): return made
	var next: Dictionary = made.get("profile", profile).duplicate(true)
	var adapter := AdapterScript.create_instance(template, context, made.get("pieces", []), {
		"instance_id": options.get("instance_id", "rig:%s:%s" % [instance_id, target_direction]),
		"mask_signature": str(made.get("mask_signature", "")),
	})
	adapter["source_binding"]["source_asset_id"] = str(asset.get("asset_id", ""))
	adapter["gap_patch_regions"] = made.get("gap_regions", [])
	adapter["layer_strategies"] = {instance_id: str(options.get("strategy", "RIGID_CUTOUT")).to_upper()}
	var errors := AdapterScript.validate(adapter, AdapterScript.derivative_id_map(next))
	if not errors.is_empty(): return {"success": false, "errors": errors}
	var adapters: Array = (next.get("rig_adapters", []) as Array).duplicate(true)
	adapters = adapters.filter(func(raw): return not (raw is Dictionary and str((raw as Dictionary).get("instance_id", "")) == str(adapter.get("instance_id", ""))))
	adapters.append(adapter); adapters.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.get("instance_id", "")) < str(b.get("instance_id", "")))
	next["rig_adapters"] = adapters
	var overrides: Dictionary = (next.get("rig_overrides", {}) as Dictionary).duplicate(true)
	overrides[instance_id] = {"representation": str(options.get("strategy", "RIGID_CUTOUT")).to_upper(), "adapter_instance_id": adapter.get("instance_id", ""), "source_fallback": "FRAME_NATIVE"}
	next["rig_overrides"] = overrides
	return {"success": true, "errors": [], "profile": next, "adapter": adapter, "source": source, "gap_regions": made.get("gap_regions", []), "command": {"command_id": "prepare_rig:" + str(adapter.get("instance_id", "")), "reversible": true, "description": "Prepare LPC cutout rig"}}


static func add_gap_patch(profile: Dictionary, adapter_id: String, source: Image, rect: Rect2i, options: Dictionary = {}) -> Dictionary:
	if source == null or source.is_empty() or rect.size.x <= 0 or rect.size.y <= 0: return {"success": false, "errors": ["Choose a non-empty gap-patch region."]}
	var adapter := _find_adapter(profile, adapter_id)
	if adapter.is_empty(): return {"success": false, "errors": ["Unknown LPC cutout rig."]}
	var clipped := rect.intersection(Rect2i(0, 0, source.get_width(), source.get_height()))
	if clipped.size.x <= 0 or clipped.size.y <= 0: return {"success": false, "errors": ["Gap-patch region falls outside the reference frame."]}
	var patch := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	patch.fill(Color(0, 0, 0, 0)); patch.blit_rect(source, clipped, clipped.position)
	var binding: Dictionary = adapter.get("source_binding", {})
	var stored := DerivativeStoreScript.store_image(profile, patch, {"source_asset_id": binding.get("source_asset_id", ""), "source_hash": binding.get("source_hash", ""), "source_frame_reference": binding.get("source_frame_reference", {}), "operation": "rig_gap_patch", "creation_tool": "lpc_prepare_for_rig"})
	if not bool(stored.get("success", false)): return stored
	var next := DerivativeStoreScript.attach(profile, stored.record)
	var pieces: Array = (adapter.get("pieces", []) as Array).duplicate(true)
	var piece_id := str(options.get("piece_id", "gap_patch_%d" % (pieces.size() + 1)))
	pieces.append({"piece_id": piece_id, "derivative_id": stored.record.derivative_id, "bone_id": str(options.get("bone_id", "torso")), "mask_rect": [clipped.position.x, clipped.position.y, clipped.size.x, clipped.size.y], "z_group": str(options.get("z_group", "front")), "strategy": "RIGID_CUTOUT", "gap_patch": true})
	adapter["pieces"] = pieces
	var regions: Array = (adapter.get("gap_patch_regions", []) as Array).duplicate(true)
	regions = regions.filter(func(raw): return not (raw is Dictionary and _rect_equals(raw.get("rect", []), clipped)))
	adapter["gap_patch_regions"] = regions
	next = _replace_adapter(next, adapter)
	return {"success": true, "errors": [], "profile": next, "adapter": adapter, "derivative": stored.record, "piece_id": piece_id}


static func _make_pieces(profile: Dictionary, source: Image, context: Dictionary, definitions: Array, options: Dictionary) -> Dictionary:
	if definitions.is_empty(): return {"success": false, "errors": ["The rig adapter has no semantic piece masks."]}
	var next := profile.duplicate(true); var pieces: Array = []; var covered: Dictionary = {}
	for raw_definition in definitions:
		if not raw_definition is Dictionary: return {"success": false, "errors": ["A rig adapter piece definition is invalid."]}
		var definition: Dictionary = raw_definition
		var rect := _rect(definition.get("mask_rect", []), source)
		if rect.size.x <= 0 or rect.size.y <= 0: return {"success": false, "errors": ["Piece '%s' has an empty mask." % definition.get("piece_id", "")]}
		var piece_image := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
		piece_image.fill(Color(0, 0, 0, 0)); piece_image.blit_rect(source, rect, rect.position)
		for y in range(rect.position.y, rect.end.y): for x in range(rect.position.x, rect.end.x): covered["%d:%d" % [x, y]] = true
		var stored := DerivativeStoreScript.store_image(next, piece_image, {"source_asset_id": context.get("source_asset_id", ""), "source_hash": context.get("source_hash", ""), "source_frame_reference": context.get("source_frame_reference", {}), "operation": "rig_cutout", "creation_tool": "lpc_prepare_for_rig"})
		if not bool(stored.get("success", false)): return stored
		next = DerivativeStoreScript.attach(next, stored.record)
		var piece := definition.duplicate(true); piece["derivative_id"] = stored.record.derivative_id; piece["strategy"] = str(piece.get("strategy", "RIGID_CUTOUT")).to_upper(); pieces.append(piece)
	var gaps: Array = _gap_regions(source, covered)
	return {"success": true, "errors": [], "profile": next, "pieces": pieces, "gap_regions": gaps, "mask_signature": JSON.stringify(definitions).sha256_text()}


static func _gap_regions(source: Image, covered: Dictionary) -> Array:
	var min_x := source.get_width(); var min_y := source.get_height(); var max_x := -1; var max_y := -1
	for y in range(source.get_height()):
		for x in range(source.get_width()):
			if source.get_pixel(x, y).a8 > 0 and not covered.has("%d:%d" % [x, y]): min_x = mini(min_x, x); min_y = mini(min_y, y); max_x = maxi(max_x, x); max_y = maxi(max_y, y)
	return [] if max_x < 0 else [{"rect": [min_x, min_y, max_x - min_x + 1, max_y - min_y + 1], "status": "needs_gap_patch", "reason": "Cut masks leave visible source pixels uncovered."}]


static func _asset_for_instance(catalog: Dictionary, profile: Dictionary, instance_id: String) -> Dictionary:
	for raw in profile.get("selections", []):
		if raw is Dictionary and str((raw as Dictionary).get("instance_id", "")) == instance_id: return ((catalog.get("assets", {}) as Dictionary).get(str((raw as Dictionary).get("asset_id", "")), {}) as Dictionary).duplicate(true)
	return {}
static func _find_adapter(profile: Dictionary, adapter_id: String) -> Dictionary:
	for raw in profile.get("rig_adapters", []):
		if raw is Dictionary and str((raw as Dictionary).get("instance_id", "")) == adapter_id: return (raw as Dictionary).duplicate(true)
	return {}
static func _replace_adapter(profile: Dictionary, adapter: Dictionary) -> Dictionary:
	var next := profile.duplicate(true); var adapters: Array = (next.get("rig_adapters", []) as Array).duplicate(true)
	for index in range(adapters.size()): if adapters[index] is Dictionary and str((adapters[index] as Dictionary).get("instance_id", "")) == str(adapter.get("instance_id", "")): adapters[index] = adapter.duplicate(true)
	next["rig_adapters"] = adapters; return next
static func _rect(value: Variant, source: Image) -> Rect2i:
	if not value is Array or (value as Array).size() < 4: return Rect2i()
	return Rect2i(int(value[0]), int(value[1]), int(value[2]), int(value[3])).intersection(Rect2i(0, 0, source.get_width(), source.get_height()))
static func _rect_equals(value: Variant, rect: Rect2i) -> bool:
	return value is Array and (value as Array).size() >= 4 and int(value[0]) == rect.position.x and int(value[1]) == rect.position.y and int(value[2]) == rect.size.x and int(value[3]) == rect.size.y
static func _image_hash(image: Image) -> String:
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(image.get_data()); return context.finish().hex_encode()
