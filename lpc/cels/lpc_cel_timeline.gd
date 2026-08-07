# LpcCelTimeline -- Typed project-owned cels, frame timing, reference layers, and onion-skin queries.
class_name LpcCelTimeline
extends RefCounted


static func add_cel(profile: Dictionary, derivative: Dictionary, options: Dictionary = {}) -> Dictionary:
	if str(derivative.get("derivative_id", "")).is_empty(): return {"success": false, "errors": ["A stored derivative is required for a cel."]}
	var target_id := str(options.get("target_id", "")).strip_edges()
	if target_id.is_empty(): return {"success": false, "errors": ["A cel must target a layer or whole character."]}
	var cels: Array = (profile.get("cels", []) as Array).duplicate(true)
	var frame: int = max(0, int(options.get("frame", 0)))
	var cel: Dictionary = {
		"cel_id": str(options.get("cel_id", "cel_" + str(profile.get("project_uuid", "")) + "_" + str(cels.size() + 1))), "target_id": target_id,
		"track_id": str(options.get("track_id", target_id)), "frame": frame, "duration_frames": max(1, int(options.get("duration_frames", 1))),
		"derivative_id": str(derivative.get("derivative_id", "")), "kind": str(options.get("kind", derivative.get("operation", "pixel_edit"))),
		"source_frame_reference": derivative.get("source_frame_reference", {}).duplicate(true), "reference_layers": (options.get("reference_layers", []) as Array).duplicate(true), "visible": bool(options.get("visible", true)),
	}
	var replaced := false
	for index in range(cels.size()):
		if cels[index] is Dictionary and str((cels[index] as Dictionary).get("cel_id", "")) == str(cel.get("cel_id", "")):
			cels[index] = cel; replaced = true
	if not replaced: cels.append(cel)
	cels.sort_custom(func(a: Dictionary, b: Dictionary): return "%s:%08d:%s" % [a.get("track_id", ""), int(a.get("frame", 0)), a.get("cel_id", "")] < "%s:%08d:%s" % [b.get("track_id", ""), int(b.get("frame", 0)), b.get("cel_id", "")])
	var next: Dictionary = profile.duplicate(true); next["cels"] = cels
	return {"success": true, "errors": [], "profile": next, "cel": cel}


static func evaluate(profile: Dictionary, target_id: String, frame: int) -> Dictionary:
	var candidates: Array = []
	for raw in profile.get("cels", []):
		if not raw is Dictionary: continue
		var cel: Dictionary = raw
		if not bool(cel.get("visible", true)) or str(cel.get("target_id", "")) != target_id: continue
		var start_frame: int = int(cel.get("frame", 0)); var end_frame: int = start_frame + max(1, int(cel.get("duration_frames", 1)))
		if frame >= start_frame and frame < end_frame: candidates.append(cel.duplicate(true))
	candidates.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.get("cel_id", "")) < str(b.get("cel_id", "")))
	return {"success": true, "cels": candidates, "frame": frame, "target_id": target_id}


static func onion_layers(profile: Dictionary, target_id: String, frame: int, before: int = 1, after: int = 1) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for offset in range(-maxi(0, before), maxi(0, after) + 1):
		if offset == 0: continue
		for cel in evaluate(profile, target_id, frame + offset).get("cels", []):
			var ghost: Dictionary = (cel as Dictionary).duplicate(true)
			ghost["onion_offset"] = offset; ghost["opacity"] = 0.35 / float(abs(offset)); ghost["tint"] = "past" if offset < 0 else "future"
			result.append(ghost)
	return result


static func validate(profile: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var derivative_ids: Dictionary = {}
	for raw in profile.get("derivative_references", []):
		if raw is Dictionary: derivative_ids[str((raw as Dictionary).get("derivative_id", ""))] = true
	for raw in profile.get("cels", []):
		if not raw is Dictionary: errors.append("Project contains an invalid cel."); continue
		var cel: Dictionary = raw
		if str(cel.get("cel_id", "")).is_empty() or str(cel.get("target_id", "")).is_empty(): errors.append("Cel is missing its stable ID or target.")
		if not derivative_ids.has(str(cel.get("derivative_id", ""))): errors.append("Cel '%s' references a missing derivative." % cel.get("cel_id", ""))
	return errors
