# LpcNativeCompatibilityResolver -- Makes native LPC clip support explicit per selected layer.
class_name LpcNativeCompatibilityResolver
extends RefCounted

const LayoutScript = preload("res://lpc/layout/lpc_sheet_layout.gd")
const LicenseResolverScript = preload("res://lpc/licensing/lpc_license_resolver.gd")

const RESOLUTION_ACTIONS := ["hide_for_clip", "substitute", "custom_cel", "rig_conversion", "cancel"]


static func resolve(catalog: Dictionary, profile: Dictionary, animation_id: String, direction_id: String) -> Dictionary:
	var errors: Array[String] = []
	var conflicts: Array[Dictionary] = []
	var layers: Array[Dictionary] = []
	var assets: Dictionary = catalog.get("assets", {})
	var layouts: Dictionary = catalog.get("layouts", {})
	var policy: Dictionary = profile.get("policy", {})
	var policy_id := str(policy.get("profile_id", ""))
	var choices: Dictionary = profile.get("selected_license_options", {})
	for raw_selection in profile.get("selections", []):
		if not raw_selection is Dictionary:
			errors.append("LPC project contains an invalid layer selection.")
			continue
		var selection: Dictionary = raw_selection
		if not bool(selection.get("visible", true)):
			continue
		var instance_id := str(selection.get("instance_id", selection.get("asset_id", "")))
		var asset_id := str(selection.get("asset_id", ""))
		var asset: Dictionary = assets.get(asset_id, {})
		if asset.is_empty():
			conflicts.append(_conflict(instance_id, asset_id, "source_missing", "The selected source asset is unavailable."))
			continue
		var action: Dictionary = _action(selection, animation_id)
		if str(action.get("action", "")) == "hide_for_clip":
			layers.append({"instance_id": instance_id, "asset": asset.duplicate(true), "selection": selection.duplicate(true), "hidden": true})
			continue
		var reason := _unsupported_reason(asset, layouts, profile, policy_id, choices, animation_id, direction_id)
		if not reason.is_empty():
			if str(action.get("action", "")) == "substitute":
				var substitute := str(action.get("asset_id", ""))
				var substitute_asset: Dictionary = assets.get(substitute, {})
				var substitute_reason := _unsupported_reason(substitute_asset, layouts, profile, policy_id, choices, animation_id, direction_id)
				if not substitute_asset.is_empty() and substitute_reason.is_empty():
					var substituted := selection.duplicate(true)
					substituted["asset_id"] = substitute
					layers.append({"instance_id": instance_id, "asset": substitute_asset.duplicate(true), "selection": substituted, "substituted_from": asset_id})
					continue
			conflicts.append(_conflict(instance_id, asset_id, reason, _message(reason, animation_id, direction_id)))
			continue
		layers.append({"instance_id": instance_id, "asset": asset.duplicate(true), "selection": selection.duplicate(true)})
	_validate_declared_groups(layers, conflicts)
	layers.sort_custom(func(a: Dictionary, b: Dictionary): return _sort_key(a) < _sort_key(b))
	return {
		"success": errors.is_empty() and conflicts.is_empty(), "errors": errors, "conflicts": conflicts,
		"layers": layers, "animation_id": animation_id, "direction_id": direction_id,
		"actions": RESOLUTION_ACTIONS.duplicate(),
	}


static func available_animations(catalog: Dictionary, profile: Dictionary, direction_id: String = "down") -> Array[String]:
	var all_ids: Dictionary = {}
	for layout_id in (catalog.get("layouts", {}) as Dictionary):
		for animation_id in ((catalog.layouts[layout_id] as Dictionary).get("animations", {}) as Dictionary):
			all_ids[str(animation_id)] = true
	var result: Array[String] = []
	for animation_id in all_ids:
		var resolution := resolve(catalog, profile, str(animation_id), direction_id)
		if bool(resolution.get("success", false)) and not (resolution.get("layers", []) as Array).is_empty():
			result.append(str(animation_id))
	result.sort()
	return result


static func _unsupported_reason(asset: Dictionary, layouts: Dictionary, profile: Dictionary, policy_id: String, choices: Dictionary, animation_id: String, direction_id: String) -> String:
	if asset.is_empty():
		return "source_missing"
	if str(profile.get("body_family_id", "")) not in asset.get("body_family_ids", []):
		return "body_family"
	if direction_id not in asset.get("direction_ids", []):
		return "direction"
	var layout: Dictionary = layouts.get(str(asset.get("layout_id", "")), {})
	if layout.is_empty() or not LayoutScript.validate(layout).is_empty():
		return "layout"
	if animation_id not in LayoutScript.normalize_supported_animations(asset, layout):
		return "animation"
	var asset_choices: Dictionary = choices.get(str(asset.get("asset_id", "")), {})
	if not LicenseResolverScript.resolve_asset(asset, policy_id, asset_choices, (profile.get("policy", {}) as Dictionary).get("custom", {})).get("success", false):
		return "policy"
	return ""


static func _action(selection: Dictionary, animation_id: String) -> Dictionary:
	var actions: Dictionary = selection.get("clip_actions", {})
	var raw: Variant = actions.get(animation_id, {})
	if raw is Dictionary:
		return (raw as Dictionary).duplicate(true)
	if raw is String:
		return {"action": str(raw)}
	return {}


static func _conflict(instance_id: String, asset_id: String, reason: String, message: String) -> Dictionary:
	return {"instance_id": instance_id, "asset_id": asset_id, "reason": reason, "message": message, "actions": RESOLUTION_ACTIONS.duplicate()}


static func _message(reason: String, animation_id: String, direction_id: String) -> String:
	match reason:
		"animation": return "This layer has no native '%s' animation. Choose an explicit fallback." % animation_id
		"direction": return "This layer has no authored '%s' direction." % direction_id
		"body_family": return "This layer is incompatible with the active body family."
		"layout": return "This layer has no valid sheet-layout adapter."
		"policy": return "This layer is blocked by the selected license policy."
		_: return "This layer's source is unavailable."


static func _validate_declared_groups(layers: Array, conflicts: Array[Dictionary]) -> void:
	var selected_ids: Dictionary = {}
	for layer in layers:
		selected_ids[str((layer as Dictionary).get("asset", {}).get("asset_id", ""))] = true
	for layer in layers:
		var item: Dictionary = layer
		var asset: Dictionary = item.get("asset", {})
		for required_id in asset.get("required_group_members", []):
			if not selected_ids.has(str(required_id)):
				conflicts.append(_conflict(str(item.get("instance_id", "")), str(asset.get("asset_id", "")), "layer_group", "This multi-layer group is incomplete; '%s' is required." % required_id))


static func _sort_key(layer: Dictionary) -> String:
	var asset: Dictionary = layer.get("asset", {})
	var z_order: Dictionary = asset.get("z_order", {})
	return "%010d:%010d:%s" % [int(z_order.get("default", 0)), int(asset.get("layer_number", 0)), str(layer.get("instance_id", ""))]
