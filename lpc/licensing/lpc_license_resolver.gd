# LpcLicenseResolver -- Resolves one explicit alternative license per credited source.
class_name LpcLicenseResolver
extends RefCounted

const POLICY_VERSION := "1.0.0"
const PROFILES := {
	"full_source": {"name": "Full Source", "allowed": [], "allow_share_alike": true, "allow_copyleft": true, "allow_anti_drm": true},
	"drm_friendly": {"name": "DRM-Friendly", "allowed": ["CC0-1.0", "OGA-BY-3.0"], "allow_share_alike": false, "allow_copyleft": false, "allow_anti_drm": false},
	"attribution_oriented": {"name": "Attribution-Oriented", "allowed": ["CC0-1.0", "OGA-BY-3.0", "CC-BY-4.0"], "allow_share_alike": false, "allow_copyleft": false, "allow_anti_drm": true},
	"share_alike_allowed": {"name": "Share-Alike Allowed", "allowed": ["CC0-1.0", "OGA-BY-3.0", "CC-BY-4.0", "CC-BY-SA-4.0"], "allow_share_alike": true, "allow_copyleft": false, "allow_anti_drm": true},
}


static func profile(profile_id: String, custom: Dictionary = {}) -> Dictionary:
	if profile_id == "custom":
		var result := custom.duplicate(true)
		result["id"] = "custom"
		result["name"] = str(result.get("name", "Custom"))
		result["allowed"] = result.get("allowed", [])
		result["allow_share_alike"] = bool(result.get("allow_share_alike", false))
		result["allow_copyleft"] = bool(result.get("allow_copyleft", false))
		result["allow_anti_drm"] = bool(result.get("allow_anti_drm", false))
		return result
	var result: Dictionary = (PROFILES.get(profile_id, {}) as Dictionary).duplicate(true)
	result["id"] = profile_id
	result["version"] = POLICY_VERSION
	return result


static func list_profiles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for profile_id in PROFILES:
		result.append(profile(profile_id))
	result.sort_custom(func(a, b): return str(a.get("name", "")) < str(b.get("name", "")))
	return result


static func resolve_asset(asset: Dictionary, profile_id: String, choices: Dictionary = {}, custom: Dictionary = {}) -> Dictionary:
	var policy := profile(profile_id, custom)
	if policy.is_empty(): return _failure("Unknown LPC policy profile '%s'." % profile_id)
	var options: Array = asset.get("license_options", [])
	var grouped: Dictionary = {}
	for raw_option in options:
		if not raw_option is Dictionary: continue
		var option: Dictionary = raw_option
		var credit_id := str(option.get("credit_id", option.get("source_id", "default")))
		if not grouped.has(credit_id): grouped[credit_id] = []
		grouped[credit_id].append(option.duplicate(true))
	var selected: Array = []
	var errors: Array[String] = []
	for credit_id in grouped:
		var choice_id := str(choices.get(credit_id, choices.get(str(asset.get("asset_id", "")) + ":" + credit_id, "")))
		var selected_option := _pick_option(grouped[credit_id], policy, choice_id)
		if selected_option.is_empty():
			errors.append("No license option for %s is allowed by %s." % [credit_id, str(policy.get("name", profile_id))])
		else:
			selected.append(selected_option)
	if grouped.is_empty(): errors.append("Asset has no license options.")
	if not errors.is_empty(): return {"success": false, "errors": errors, "selected_options": [], "policy": policy}
	return {"success": true, "errors": [], "policy": policy, "selected_options": selected, "asset_id": str(asset.get("asset_id", ""))}


static func exact_credit_manifest(assets: Array, profile_id: String, choices: Dictionary = {}, custom: Dictionary = {}) -> Dictionary:
	var rows: Array = []
	var errors: Array[String] = []
	for raw_asset in assets:
		if not raw_asset is Dictionary: continue
		var asset: Dictionary = raw_asset
		var resolved := resolve_asset(asset, profile_id, choices, custom)
		if not resolved.get("success", false):
			errors.append_array(resolved.get("errors", []))
			continue
		var credit_by_id: Dictionary = {}
		for raw_credit in asset.get("credits", []):
			if raw_credit is Dictionary:
				var credit: Dictionary = raw_credit
				credit_by_id[str(credit.get("credit_id", credit.get("source_id", "default")))] = credit
		for raw_option in resolved.get("selected_options", []):
			var option: Dictionary = raw_option
			var credit_id := str(option.get("credit_id", option.get("source_id", "default")))
			var credit: Dictionary = (credit_by_id.get(credit_id, {}) as Dictionary).duplicate(true)
			rows.append({
				"asset_id": str(asset.get("asset_id", "")), "credit_id": credit_id,
				"author": str(credit.get("author", "")), "source_url": str(credit.get("source_url", "")),
				"notice": str(credit.get("notice", "")), "license_id": str(option.get("license_id", "")),
				"license_url": str(option.get("license_url", "")), "derivative_notice": str(option.get("derivative_notice", "")),
				"share_alike": bool(option.get("share_alike", false)), "copyleft": bool(option.get("copyleft", false)),
			})
	rows.sort_custom(func(a, b): return "%s:%s" % [a.asset_id, a.credit_id] < "%s:%s" % [b.asset_id, b.credit_id])
	return {"success": errors.is_empty(), "errors": errors, "policy_id": profile_id, "policy_version": POLICY_VERSION, "credits": rows}


static func _pick_option(options: Array, policy: Dictionary, requested_id: String) -> Dictionary:
	var ordered := options.duplicate(true)
	ordered.sort_custom(func(a, b): return str(a.get("license_id", "")) < str(b.get("license_id", "")))
	for raw_option in ordered:
		var option: Dictionary = raw_option
		if not requested_id.is_empty() and str(option.get("license_id", "")) != requested_id: continue
		if _is_allowed(option, policy): return option.duplicate(true)
	return {}


static func _is_allowed(option: Dictionary, policy: Dictionary) -> bool:
	var allowed: Array = policy.get("allowed", [])
	if not allowed.is_empty() and str(option.get("license_id", "")) not in allowed: return false
	if bool(option.get("share_alike", false)) and not bool(policy.get("allow_share_alike", false)): return false
	if bool(option.get("copyleft", false)) and not bool(policy.get("allow_copyleft", false)): return false
	if bool(option.get("anti_drm", false)) and not bool(policy.get("allow_anti_drm", false)): return false
	return true


static func _failure(error: String) -> Dictionary:
	return {"success": false, "errors": [error], "selected_options": []}
