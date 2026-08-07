# ProjectWorkflowWizard -- Resumable artist-facing setup guide for new projects.
class_name ProjectWorkflowWizard
extends AcceptDialog

signal route_requested(workspace_id: String, panel_id: String)

var _session = null
var _step := 0
var _title_label: Label
var _progress_label: Label
var _body_label: Label
var _back_button: Button
var _next_button: Button
var _save_button: Button

const STEPS := [
	{"title": "Canvas and slot template", "copy": "Set the working canvas and choose the slot template before importing artwork.", "workspace": "character_creator", "panel": "panel_character_creator"},
	{"title": "Import artwork", "copy": "Bring in only artist-made PNG, WebP, or JPEG layers. Drag a folder or individual files into Create.", "workspace": "character_creator", "panel": "panel_character_creator"},
	{"title": "Map and review layers", "copy": "Review filename-to-slot mapping, missing-file indicators, layer order, and the assembled character.", "workspace": "character_creator", "panel": "panel_character_creator"},
	{"title": "Create a rig", "copy": "Create a rig and at least one bone in Hierarchy & Rig.", "workspace": "rigging_deformation", "panel": "panel_hierarchy"},
	{"title": "Make an idle animation", "copy": "Create an idle clip, add a track, and key at least one property. The canvas now previews the animation live.", "workspace": "animation_studio", "panel": "panel_timeline"},
	{"title": "Validate, preview, and export", "copy": "Resolve blockers, preview all imported appearances, then create a review package for handoff.", "workspace": "preview_export", "panel": "panel_review_package"},
]


func _ready() -> void:
	title = "Guided character setup"
	min_size = Vector2i(520, 330)
	exclusive = false
	_build_ui()


func bind_session(session) -> void:
	if _session != null and is_instance_valid(_session) and _session.session_changed.is_connected(_on_session_changed):
		_session.session_changed.disconnect(_on_session_changed)
	_session = session
	if _session != null and is_instance_valid(_session) and not _session.session_changed.is_connected(_on_session_changed):
		_session.session_changed.connect(_on_session_changed)
	var workflow: Dictionary = _session.get_workflow_state() if _session != null and is_instance_valid(_session) else {}
	_step = clampi(int(workflow.get("current_step", 0)), 0, STEPS.size() - 1)
	_refresh()


func open() -> void:
	if _session == null or not is_instance_valid(_session): return
	var workflow: Dictionary = _session.get_workflow_state()
	_step = clampi(int(workflow.get("current_step", 0)), 0, STEPS.size() - 1)
	_session.set_workflow_state({"deferred": false}, "Resumed Guided Setup")
	_refresh()
	popup_centered()
	_route_current_step()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.name = "WizardRoot"
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	_progress_label = Label.new()
	_progress_label.name = "Progress"
	_progress_label.add_theme_font_size_override("font_size", 12)
	root.add_child(_progress_label)
	_title_label = Label.new()
	_title_label.name = "StepTitle"
	_title_label.add_theme_font_size_override("font_size", 20)
	root.add_child(_title_label)
	_body_label = Label.new()
	_body_label.name = "StepCopy"
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_body_label)
	var criteria := Label.new()
	criteria.name = "Criteria"
	criteria.text = "You can save progress and work freely at any time. This guide returns automatically when the project is reopened."
	criteria.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	criteria.add_theme_font_size_override("font_size", 12)
	root.add_child(criteria)
	var actions := HBoxContainer.new()
	root.add_child(actions)
	_back_button = Button.new()
	_back_button.name = "Back"
	_back_button.text = "Back"
	_back_button.pressed.connect(_go_back)
	actions.add_child(_back_button)
	_save_button = Button.new()
	_save_button.name = "SaveProgress"
	_save_button.text = "Save progress and work freely"
	_save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_button.pressed.connect(_defer)
	actions.add_child(_save_button)
	_next_button = Button.new()
	_next_button.name = "Next"
	_next_button.text = "Next"
	_next_button.pressed.connect(_go_next)
	actions.add_child(_next_button)


func _refresh() -> void:
	if _title_label == null: return
	var data: Dictionary = STEPS[_step]
	_progress_label.text = "STEP %d OF %d" % [_step + 1, STEPS.size()]
	_title_label.text = str(data.get("title", "Guided setup"))
	var complete := _step_is_complete(_step)
	_body_label.text = str(data.get("copy", "")) + "\n\n" + ("Ready to continue." if complete else _incomplete_copy(_step))
	_back_button.disabled = _step == 0
	_next_button.text = "Finish" if _step == STEPS.size() - 1 else "Next"
	_next_button.disabled = not complete


func _go_back() -> void:
	if _step <= 0: return
	_step -= 1
	_persist_step()
	_refresh()
	_route_current_step()


func _go_next() -> void:
	if not _step_is_complete(_step):
		_refresh()
		return
	if _step >= STEPS.size() - 1:
		_session.set_workflow_state({"completed": true, "deferred": false, "current_step": _step}, "Completed Guided Setup")
		hide()
		return
	_step += 1
	_persist_step()
	_refresh()
	_route_current_step()


func _defer() -> void:
	if _session != null and is_instance_valid(_session):
		_session.set_workflow_state({"current_step": _step, "deferred": true}, "Saved Guided Setup Progress")
	hide()


func _persist_step() -> void:
	if _session != null and is_instance_valid(_session):
		_session.set_workflow_state({"current_step": _step, "deferred": false}, "Advanced Guided Setup")


func _route_current_step() -> void:
	var data: Dictionary = STEPS[_step]
	route_requested.emit(str(data.get("workspace", "character_creator")), str(data.get("panel", "")))


func _step_is_complete(step: int) -> bool:
	if _session == null or not is_instance_valid(_session) or _session.model == null: return false
	match step:
		0: return not _session.get_canvas_settings().is_empty() and not _session.get_selected_slot_template().is_empty()
		1: return not _session.get_preview_layers().is_empty()
		2:
			for layer in _session.get_preview_layers():
				if bool((layer as Dictionary).get("missing", false)): return false
			return not _session.get_preview_layers().is_empty()
		3:
			return not _session.get_active_rig().is_empty() and not (_session.get_active_rig().get("bones", {}) as Dictionary).is_empty()
		4:
			for clip in _session.get_animation_clips():
				for track in (clip as Dictionary).get("tracks", []):
					if not ((track as Dictionary).get("keys", []) as Array).is_empty(): return true
			return false
		5: return bool(_session.get_readiness_report({"require_clips": true}).get("can_export", false))
	return false


func _incomplete_copy(step: int) -> String:
	match step:
		0: return "Choose a template and canvas in Create to unlock import."
		1: return "Import at least one artist-made image layer to continue."
		2: return "Resolve missing layers and review the assembly before rigging."
		3: return "Create a rig with a root bone to continue."
		4: return "Create an animation clip and place at least one keyframe."
		5: return "Resolve the blocking readiness issues before review/export."
	return "Complete this step to continue."


func _on_session_changed(_description: String) -> void:
	# The dialog is intentionally non-exclusive so artists can work in the
	# routed dock while it is open. Keep its gate state current as they import,
	# rig, or key an animation.
	_refresh()
