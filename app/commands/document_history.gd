# DocumentHistory -- Records already-applied document edits on the shared undo/redo stack.
# Panels own their snapshots; this bridge makes their edits participate in the active project history.
class_name DocumentHistory
extends RefCounted


static func record_applied(target: Node, before: Dictionary, after: Dictionary, description: String, apply_method: StringName = &"_apply_document_snapshot") -> bool:
	if target == null or before == after or not target.has_method(apply_method):
		return false
	if AppState == null or not AppState.is_project_loaded() or CommandService == null:
		return false
	return CommandService.execute(
		{"target": target, "method": String(apply_method), "args": [after.duplicate(true), description]},
		{"target": target, "method": String(apply_method), "args": [before.duplicate(true), "Undid " + description]},
		description
	)
