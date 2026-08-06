# FacingFilenamePlacementModel -- Deterministic filename-to-direction batch planner.
class_name FacingFilenamePlacementModel
extends RefCounted


static func parse_entries(text: String) -> Dictionary:
	var entries: Array = []
	var diagnostics: Array = []
	for index in range(text.split("\n").size()):
		var line := str(text.split("\n")[index]).strip_edges()
		if line.is_empty():
			continue
		var separator := line.find("|")
		if separator < 1 or separator >= line.length() - 1:
			diagnostics.append("Line %d must use asset_id | filename." % (index + 1))
			continue
		var asset_id := line.left(separator).strip_edges()
		var filename := line.right(-separator - 1).strip_edges()
		if asset_id.is_empty() or filename.is_empty():
			diagnostics.append("Line %d needs both an asset ID and filename." % (index + 1))
			continue
		entries.append({"asset_id": asset_id, "filename": filename, "line": index + 1})
	return {"entries": entries, "diagnostics": diagnostics}


static func preview(grid: FacingGridDefinition, entries: Array, initial_diagnostics: Array = []) -> Dictionary:
	var diagnostics := initial_diagnostics.duplicate()
	var assignments: Dictionary = {}
	var matches: Array = []
	if grid == null:
		diagnostics.append("Choose a facing grid before previewing placement.")
		return _result(assignments, matches, diagnostics)
	var directions := grid.get_direction_ids()
	for entry_value in entries:
		var entry := entry_value as Dictionary
		var direction_matches := _longest_direction_matches(str(entry.get("filename", "")), directions)
		var line_number := int(entry.get("line", 0))
		if direction_matches.is_empty():
			diagnostics.append("Line %d does not contain a current direction name." % line_number)
			continue
		if direction_matches.size() > 1:
			diagnostics.append("Line %d is ambiguous: %s." % [line_number, ", ".join(direction_matches)])
			continue
		var direction_id := str(direction_matches[0])
		if assignments.has(direction_id):
			diagnostics.append("Line %d duplicates the %s assignment." % [line_number, direction_id])
			continue
		assignments[direction_id] = str(entry.get("asset_id", ""))
		matches.append({"direction_id": direction_id, "asset_id": assignments[direction_id], "filename": entry.get("filename", "")})
	if assignments.is_empty() and diagnostics.is_empty():
		diagnostics.append("Provide at least one asset_id | filename entry.")
	return _result(assignments, matches, diagnostics)


static func apply(grid: FacingGridDefinition, plan: Dictionary) -> Dictionary:
	if grid == null:
		return {"success": false, "diagnostics": ["Choose a facing grid before applying placement."], "applied": []}
	if not bool(plan.get("valid", false)):
		return {"success": false, "diagnostics": (plan.get("diagnostics", []) as Array).duplicate(), "applied": []}
	var assignments := plan.get("assignments", {}) as Dictionary
	for direction_id in assignments:
		if direction_id not in grid.get_direction_ids():
			return {"success": false, "diagnostics": ["Direction set changed; preview placement again."], "applied": []}
	for direction_id in assignments:
		var cell := grid.get_cell(direction_id)
		cell["asset_id"] = str(assignments[direction_id])
		grid.set_cell(direction_id, cell)
	return {"success": true, "diagnostics": [], "applied": assignments.keys()}


static func _longest_direction_matches(filename: String, directions: Array) -> Array:
	var stem := filename.get_file().get_basename().to_snake_case()
	var padded_stem := "_" + stem + "_"
	var longest_length := 0
	var matches: Array = []
	for direction_value in directions:
		var direction_id := str(direction_value).to_snake_case()
		if padded_stem.contains("_" + direction_id + "_"):
			if direction_id.length() > longest_length:
				longest_length = direction_id.length()
				matches = [direction_id]
			elif direction_id.length() == longest_length:
				matches.append(direction_id)
	return matches


static func _result(assignments: Dictionary, matches: Array, diagnostics: Array) -> Dictionary:
	return {
		"valid": diagnostics.is_empty() and not assignments.is_empty(),
		"assignments": assignments.duplicate(true),
		"matches": matches.duplicate(true),
		"diagnostics": diagnostics.duplicate(),
	}
