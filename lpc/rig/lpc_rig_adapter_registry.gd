# LpcRigAdapterRegistry -- Finds only source-compatible, direction-local LPC cutout templates.
class_name LpcRigAdapterRegistry
extends RefCounted

const AdapterScript = preload("res://lpc/rig/lpc_rig_adapter.gd")


static func find(catalog: Dictionary, profile: Dictionary, instance_id: String, direction_id: String, options: Dictionary = {}) -> Dictionary:
	var asset := _asset_for_instance(catalog, profile, instance_id)
	if asset.is_empty():
		return {"success": false, "errors": ["The selected LPC layer is not available in the locked catalog."], "adapters": []}
	var candidates := _candidates(catalog, asset, options)
	var compatible: Array = []
	for raw_candidate in candidates:
		if not raw_candidate is Dictionary:
			continue
		var candidate: Dictionary = raw_candidate.duplicate(true)
		var compatibility := validate_compatibility(candidate, asset, str(profile.get("body_family_id", "")), direction_id, str(options.get("source_direction_id", direction_id)))
		if bool(compatibility.get("success", false)):
			compatible.append(candidate)
	compatible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("adapter_id", "")) < str(b.get("adapter_id", "")))
	return {
		"success": true,
		"errors": [],
		"adapters": compatible,
		"manual_setup_required": compatible.is_empty(),
		"manual_template": AdapterScript.standard_template(str(profile.get("body_family_id", "")), direction_id, {"manual_setup": true, "source_instance_id": instance_id}),
	}


static func validate_compatibility(template: Dictionary, asset: Dictionary, body_family_id: String, direction_id: String, source_direction_id: String = "") -> Dictionary:
	var errors: Array[String] = []
	if str(template.get("body_family_id", "")) != body_family_id:
		errors.append("Rig adapter body family does not match the active LPC project.")
	var adapter_direction := str(template.get("direction_id", ""))
	if not adapter_direction.is_empty() and adapter_direction != direction_id:
		errors.append("Rig adapter is authored for '%s', not '%s'." % [adapter_direction, direction_id])
	var source_direction := source_direction_id if not source_direction_id.is_empty() else direction_id
	if source_direction not in (asset.get("direction_ids", []) as Array):
		errors.append("The selected source has no explicit native '%s' direction for conversion." % source_direction)
	var signatures: Array = template.get("source_signatures", [])
	if not signatures.is_empty():
		var source_hash := str(asset.get("source_sha256", ""))
		var compatible := false
		for raw_signature in signatures:
			if raw_signature is Dictionary and str((raw_signature as Dictionary).get("source_hash", "")) == source_hash:
				compatible = true
			elif str(raw_signature) == source_hash:
				compatible = true
		if not compatible:
			errors.append("Rig adapter is not compatible with this locked source hash.")
	return {"success": errors.is_empty(), "errors": errors}


static func _candidates(catalog: Dictionary, asset: Dictionary, options: Dictionary) -> Array:
	var output: Array = []
	for raw in options.get("templates", []):
		output.append(raw)
	for raw in catalog.get("rig_adapters", []):
		output.append(raw)
	var embedded: Variant = asset.get("rig_adapters", asset.get("rig_adapter_templates", []))
	if embedded is Array:
		for raw in embedded:
			output.append(raw)
	elif embedded is Dictionary and not (embedded as Dictionary).is_empty():
		output.append(embedded)
	return output


static func _asset_for_instance(catalog: Dictionary, profile: Dictionary, instance_id: String) -> Dictionary:
	for raw_selection in profile.get("selections", []):
		if raw_selection is Dictionary and str((raw_selection as Dictionary).get("instance_id", "")) == instance_id:
			return ((catalog.get("assets", {}) as Dictionary).get(str((raw_selection as Dictionary).get("asset_id", "")), {}) as Dictionary).duplicate(true)
	return {}
