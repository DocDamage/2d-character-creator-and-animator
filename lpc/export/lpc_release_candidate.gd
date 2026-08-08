# LpcReleaseCandidate -- Produces an evidence-backed LPC release-candidate assessment without faking human review.
class_name LpcReleaseCandidate
extends RefCounted

const DeliveryExporterScript = preload("res://lpc/export/lpc_delivery_exporter.gd")
const HybridEvaluatorScript = preload("res://lpc/animation/lpc_hybrid_clip_evaluator.gd")
const LicenseResolverScript = preload("res://lpc/licensing/lpc_license_resolver.gd")


static func assess(catalog: Dictionary, profile: Dictionary, options: Dictionary = {}) -> Dictionary:
	var errors: Array[String] = DeliveryExporterScript.validate(catalog, profile, "HYBRID_RUNTIME")
	var warnings: Array[String] = []
	var metrics: Dictionary = {}
	var clip := _clip(profile, str(options.get("clip_id", "")))
	if clip.is_empty():
		errors.append("A typed LPC clip is required for release-candidate playback evidence.")
	else:
		var started := Time.get_ticks_usec()
		var evaluated := HybridEvaluatorScript.evaluate(catalog, profile, clip, 0.0)
		metrics["first_frame_ms"] = float(Time.get_ticks_usec() - started) / 1000.0
		metrics["clip_id"] = clip.get("clip_id", "")
		metrics["frame_output_hash"] = evaluated.get("output_hash", "")
		if not bool(evaluated.get("success", false)):
			errors.append_array(evaluated.get("errors", ["Release-candidate hybrid evaluation failed."]))
		var limit_ms := maxf(1.0, float(options.get("max_first_frame_ms", 500.0)))
		if float(metrics.get("first_frame_ms", 0.0)) > limit_ms:
			warnings.append("Release-candidate first frame exceeded %.1f ms." % limit_ms)
	var credits := _credits(catalog, profile)
	if (credits.get("credits", []) as Array).is_empty():
		errors.append("Release-candidate credits are empty.")
	var fixture_matrix: Dictionary = options.get("fixture_matrix", {})
	var required_fixtures: Array = options.get("required_fixture_ids", [])
	var missing_fixtures: Array[String] = []
	for fixture_id in required_fixtures:
		if not bool(fixture_matrix.get(str(fixture_id), false)):
			missing_fixtures.append(str(fixture_id))
	if not missing_fixtures.is_empty():
		warnings.append("Fixture evidence remains pending: " + ", ".join(missing_fixtures))
	var human_review: Dictionary = options.get("human_visual_review", {})
	var human_approved := bool(human_review.get("approved", false)) and not str(human_review.get("reviewer", "")).strip_edges().is_empty()
	if not human_approved:
		warnings.append("Human visual review is pending; this is an evidence-backed release candidate, not an approved public release.")
	return {
		"success": errors.is_empty(),
		"release_ready": errors.is_empty() and warnings.is_empty() and human_approved,
		"errors": errors,
		"warnings": warnings,
		"metrics": metrics,
		"credits": credits,
		"fixture_matrix": fixture_matrix.duplicate(true),
		"human_visual_review": human_review.duplicate(true),
	}


static func _clip(profile: Dictionary, clip_id: String) -> Dictionary:
	for raw_clip in profile.get("clips", []):
		if raw_clip is Dictionary and (clip_id.is_empty() or str((raw_clip as Dictionary).get("clip_id", "")) == clip_id):
			return (raw_clip as Dictionary).duplicate(true)
	return {}


static func _credits(catalog: Dictionary, profile: Dictionary) -> Dictionary:
	var assets: Array = []
	for raw_selection in profile.get("selections", []):
		if raw_selection is Dictionary:
			var asset: Dictionary = (catalog.get("assets", {}) as Dictionary).get(str((raw_selection as Dictionary).get("asset_id", "")), {})
			if not asset.is_empty(): assets.append(asset)
	var policy: Dictionary = profile.get("policy", {})
	return LicenseResolverScript.exact_credit_manifest(assets, str(policy.get("profile_id", "full_source")), profile.get("selected_license_options", {}), policy.get("custom", {}))
