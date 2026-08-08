# LpcCreatorModel -- Project-owned selections and native-preview/export operations for the focused creator.
class_name LpcCreatorModel
extends RefCounted

const BrowserScript = preload("res://lpc/catalog/lpc_catalog_browser_model.gd")
const ResolverScript = preload("res://lpc/animation/lpc_native_compatibility_resolver.gd")
const EvaluatorScript = preload("res://lpc/animation/lpc_native_clip_evaluator.gd")
const ExporterScript = preload("res://lpc/export/lpc_native_exporter.gd")
const LicenseResolverScript = preload("res://lpc/licensing/lpc_license_resolver.gd")
const ProjectStoreScript = preload("res://lpc/project/lpc_project_store.gd")

signal changed(description: String)

var catalog: Dictionary = {}
var profile: Dictionary = {}
var manifest: Dictionary = {}
var project_path := ""


func bind_context(next_catalog: Dictionary, next_profile: Dictionary, next_manifest: Dictionary = {}, path: String = "") -> Dictionary:
	if next_catalog.is_empty() or not (next_catalog.get("validation_errors", []) as Array).is_empty():
		return {"success": false, "errors": ["A validated LPC catalog is required."]}
	catalog = next_catalog.duplicate(true)
	profile = next_profile.duplicate(true)
	manifest = next_manifest.duplicate(true)
	project_path = path
	return {"success": true, "errors": []}


func browse(query: String = "", filters: Dictionary = {}, offset: int = 0, limit: int = 80) -> Dictionary:
	var browser := BrowserScript.new()
	var loaded := browser.load_catalog(catalog)
	if not bool(loaded.get("success", false)):
		return loaded
	return browser.search(query, _creator_filters(filters), offset, limit)


func select_asset(asset_id: String, slot_id: String = "", options: Dictionary = {}) -> Dictionary:
	var asset: Dictionary = (catalog.get("assets", {}) as Dictionary).get(asset_id, {})
	if asset.is_empty():
		return {"success": false, "errors": ["Unknown LPC asset '%s'." % asset_id]}
	var family_id := str(profile.get("body_family_id", ""))
	if family_id not in asset.get("body_family_ids", []):
		return {"success": false, "errors": ["This asset is not compatible with the active body family."]}
	var policy: Dictionary = profile.get("policy", {})
	var resolution := LicenseResolverScript.resolve_asset(asset, str(policy.get("profile_id", "full_source")), {}, policy.get("custom", {}))
	if not bool(resolution.get("success", false)):
		return {"success": false, "errors": resolution.get("errors", [])}
	var final_slot := slot_id if not slot_id.is_empty() else str(asset.get("layer_group", asset.get("type_name", asset_id)))
	if final_slot.is_empty(): final_slot = asset_id
	var selections: Array = (profile.get("selections", []) as Array).duplicate(true)
	if not bool(options.get("allow_multiple", false)):
		selections = selections.filter(func(raw): return not (raw is Dictionary and str((raw as Dictionary).get("slot_id", "")) == final_slot))
	var instance_id := str(options.get("instance_id", ""))
	if instance_id.is_empty(): instance_id = "%s:%s" % [final_slot, asset_id]
	selections.append({"instance_id": instance_id, "asset_id": asset_id, "slot_id": final_slot, "visible": true, "representation": "FRAME_NATIVE", "clip_actions": {}, "capabilities": asset.get("deformation", {}).get("capabilities", ["FRAME_NATIVE"])})
	profile["selections"] = selections
	var choices: Dictionary = (profile.get("selected_license_options", {}) as Dictionary).duplicate(true)
	var per_asset: Dictionary = {}
	for option in resolution.get("selected_options", []): per_asset[str((option as Dictionary).get("credit_id", "default"))] = str((option as Dictionary).get("license_id", ""))
	choices[asset_id] = per_asset; profile["selected_license_options"] = choices
	changed.emit("Selected " + asset_id)
	return {"success": true, "errors": [], "selection": selections[selections.size() - 1]}


func remove_selection(instance_id: String) -> bool:
	var before: Array = profile.get("selections", [])
	var after: Array = before.filter(func(raw): return not (raw is Dictionary and str((raw as Dictionary).get("instance_id", "")) == instance_id))
	if after.size() == before.size(): return false
	profile["selections"] = after
	changed.emit("Removed " + instance_id)
	return true


func set_missing_animation_action(instance_id: String, animation_id: String, action: String, substitute_asset_id: String = "") -> Dictionary:
	if action not in ResolverScript.RESOLUTION_ACTIONS:
		return {"success": false, "errors": ["Unknown native-animation resolution action."]}
	var selections: Array = (profile.get("selections", []) as Array).duplicate(true)
	for index in range(selections.size()):
		if not selections[index] is Dictionary or str((selections[index] as Dictionary).get("instance_id", "")) != instance_id: continue
		var selection: Dictionary = (selections[index] as Dictionary).duplicate(true)
		var actions: Dictionary = (selection.get("clip_actions", {}) as Dictionary).duplicate(true)
		actions[animation_id] = {"action": action, "asset_id": substitute_asset_id}
		selection["clip_actions"] = actions; selections[index] = selection; profile["selections"] = selections
		changed.emit("Resolved native animation conflict")
		return {"success": true, "errors": []}
	return {"success": false, "errors": ["The selected LPC layer is no longer present."]}


func capability_status(instance_id: String) -> Dictionary:
	for raw in profile.get("selections", []):
		if not raw is Dictionary or str((raw as Dictionary).get("instance_id", "")) != instance_id: continue
		var asset: Dictionary = (catalog.get("assets", {}) as Dictionary).get(str((raw as Dictionary).get("asset_id", "")), {})
		if asset.is_empty(): return {"status": "Source Missing", "capabilities": [], "reason": "The selected catalog asset cannot be found."}
		var capabilities: Array = (asset.get("deformation", {}) as Dictionary).get("capabilities", ["FRAME_NATIVE"])
		var status := "Native"
		if "RIG_PREPARED" in capabilities: status = "Rig Ready"
		elif "RIG_TEMPLATE_AVAILABLE" in capabilities: status = "Rig Template Available"
		elif "FRAME_WARPABLE" in capabilities: status = "Warpable"
		elif "FRAME_EDITABLE" in capabilities: status = "Editable Cel"
		elif not "FRAME_NATIVE" in capabilities: status = "Needs Setup"
		return {"status": status, "capabilities": capabilities.duplicate(), "reason": ""}
	return {"status": "Source Missing", "capabilities": [], "reason": "No selected layer has this ID."}


func native_animations(direction_id: String = "down") -> Array[String]:
	return ResolverScript.available_animations(catalog, profile, direction_id)


func preview(animation_id: String, direction_id: String, playhead: float = 0.0) -> Dictionary:
	return EvaluatorScript.evaluate(catalog, profile, animation_id, direction_id, playhead)


func export_native(animation_id: String, direction_id: String, output_directory: String, options: Dictionary = {}) -> Dictionary:
	return ExporterScript.export_clip(catalog, profile, animation_id, direction_id, output_directory, options)


func credit_manifest() -> Dictionary:
	var assets: Array = []
	for raw in profile.get("selections", []):
		if raw is Dictionary:
			var asset: Dictionary = (catalog.get("assets", {}) as Dictionary).get(str((raw as Dictionary).get("asset_id", "")), {})
			if not asset.is_empty(): assets.append(asset)
	var policy: Dictionary = profile.get("policy", {})
	return LicenseResolverScript.exact_credit_manifest(assets, str(policy.get("profile_id", "full_source")), profile.get("selected_license_options", {}), policy.get("custom", {}))


func save() -> Dictionary:
	if project_path.is_empty() or manifest.is_empty(): return {"success": false, "errors": ["Bind an LPC project before saving creator state."]}
	var saved := ProjectStoreScript.save(project_path, manifest, profile)
	if bool(saved.get("success", false)): manifest = saved.manifest.duplicate(true)
	return saved


func _creator_filters(filters: Dictionary) -> Dictionary:
	var result := filters.duplicate(true)
	result["body_family_id"] = str(profile.get("body_family_id", ""))
	result["policy_id"] = str((profile.get("policy", {}) as Dictionary).get("profile_id", "full_source"))
	return result
