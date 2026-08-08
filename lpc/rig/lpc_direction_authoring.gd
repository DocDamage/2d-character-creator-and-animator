# LpcDirectionAuthoring -- Explicit cardinal/diagonal LPC direction records; never silently rotates pixel art.
class_name LpcDirectionAuthoring
extends RefCounted

const EIGHT_DIRECTIONS := ["up", "up_right", "right", "down_right", "down", "down_left", "left", "up_left"]
const REPRESENTATIONS := ["NATIVE", "CUSTOM_CEL", "RIGGED", "MIRROR", "MISSING"]


static func enable_eight_direction(profile: Dictionary, options: Dictionary = {}) -> Dictionary:
	var next := profile.duplicate(true); next["direction_set"] = {"id": "lpc_authored_8", "directions": EIGHT_DIRECTIONS.duplicate()}
	var authoring: Dictionary = (next.get("direction_authoring", {}) as Dictionary).duplicate(true); if not authoring.has("directions"): authoring["directions"] = {}
	var records: Dictionary = authoring.get("directions", {}).duplicate(true)
	for direction_id in EIGHT_DIRECTIONS:
		if not records.has(direction_id): records[direction_id] = {"direction_id": direction_id, "representation": "NATIVE" if direction_id in ["up", "right", "down", "left"] else "MISSING", "editable": true}
	authoring["directions"] = records; authoring["mirror_policy"] = (options.get("mirror_policy", authoring.get("mirror_policy", {"allowed": false, "editable": true})) as Dictionary).duplicate(true); next["direction_authoring"] = authoring
	return {"success": true, "errors": [], "profile": next, "completion": completion(next)}


static func author(profile: Dictionary, direction_id: String, representation: String, options: Dictionary = {}) -> Dictionary:
	if direction_id not in EIGHT_DIRECTIONS: return {"success": false, "errors": ["Unknown authored LPC direction '%s'." % direction_id]}
	var mode := representation.to_upper(); if mode not in REPRESENTATIONS or mode == "MISSING": return {"success": false, "errors": ["Choose an authored native, cel, rigged, or approved mirror direction."]}
	var next_result := enable_eight_direction(profile, options); var next: Dictionary = next_result.profile; var authoring: Dictionary = next.direction_authoring.duplicate(true); var records: Dictionary = authoring.directions.duplicate(true)
	if mode == "MIRROR" and not bool((authoring.get("mirror_policy", {}) as Dictionary).get("allowed", false)): return {"success": false, "errors": ["This LPC project has not approved mirrored-source directions."]}
	var record := {"direction_id": direction_id, "representation": mode, "editable": true, "source_direction_id": str(options.get("source_direction_id", "")), "adapter_instance_id": str(options.get("adapter_instance_id", "")), "derivative_id": str(options.get("derivative_id", "")), "mirror_axis": str(options.get("mirror_axis", "horizontal")), "notes": str(options.get("notes", ""))}
	if mode == "MIRROR" and record.source_direction_id.is_empty(): return {"success": false, "errors": ["A mirrored direction must record its approved source direction."]}
	if mode == "CUSTOM_CEL" and record.derivative_id.is_empty(): return {"success": false, "errors": ["A custom diagonal direction must reference its project-owned cel."]}
	if mode == "RIGGED" and record.adapter_instance_id.is_empty(): return {"success": false, "errors": ["A rigged direction must reference its direction-specific cutout rig."]}
	records[direction_id] = record; authoring["directions"] = records; next["direction_authoring"] = authoring
	return {"success": true, "errors": [], "profile": next, "record": record, "completion": completion(next)}


static func completion(profile: Dictionary) -> Dictionary:
	var records: Dictionary = ((profile.get("direction_authoring", {}) as Dictionary).get("directions", {}) as Dictionary); var missing: Array[String] = []; var authored: Array[String] = []
	for direction_id in EIGHT_DIRECTIONS:
		var record: Dictionary = records.get(direction_id, {}); var mode := str(record.get("representation", "MISSING")).to_upper()
		if mode == "MISSING" or record.is_empty(): missing.append(direction_id)
		else: authored.append(direction_id)
	return {"complete": missing.is_empty(), "missing": missing, "authored": authored, "required": EIGHT_DIRECTIONS.duplicate()}


static func validate(profile: Dictionary) -> Array[String]:
	var errors: Array[String] = []; var directions: Array = (profile.get("direction_set", {}) as Dictionary).get("directions", [])
	if str((profile.get("direction_set", {}) as Dictionary).get("id", "")) != "lpc_authored_8": return errors
	if directions != EIGHT_DIRECTIONS: errors.append("Eight-direction LPC projects must retain the declared authored direction order.")
	var records: Dictionary = ((profile.get("direction_authoring", {}) as Dictionary).get("directions", {}) as Dictionary); var derivative_ids: Dictionary = {}; var rig_ids: Dictionary = {}
	for raw in profile.get("derivative_references", []): if raw is Dictionary: derivative_ids[str((raw as Dictionary).get("derivative_id", ""))] = true
	for raw in profile.get("rig_adapters", []): if raw is Dictionary: rig_ids[str((raw as Dictionary).get("instance_id", ""))] = true
	for direction_id in EIGHT_DIRECTIONS:
		var record: Dictionary = records.get(direction_id, {}); var mode := str(record.get("representation", "MISSING")).to_upper()
		if mode not in REPRESENTATIONS: errors.append("Direction '%s' has an unknown representation." % direction_id)
		if mode == "MIRROR" and not bool(((profile.get("direction_authoring", {}) as Dictionary).get("mirror_policy", {}) as Dictionary).get("allowed", false)): errors.append("Direction '%s' uses an unapproved mirror." % direction_id)
		if mode == "CUSTOM_CEL" and not derivative_ids.has(str(record.get("derivative_id", ""))): errors.append("Direction '%s' references a missing custom cel." % direction_id)
		if mode == "RIGGED" and not rig_ids.has(str(record.get("adapter_instance_id", ""))): errors.append("Direction '%s' references a missing rig adapter." % direction_id)
	return errors
