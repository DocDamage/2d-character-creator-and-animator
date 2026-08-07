# RigHierarchyEditor -- Persistent project rig tree with structural editing and shared selection.
class_name RigHierarchyEditor
extends VBoxContainer

signal status_changed(message: String)

var _session = null
var _selection = null
var _rig_picker: OptionButton = null
var _tree: Tree = null
var _name_input: LineEdit = null
var _length_input: SpinBox = null
var _parent_picker: OptionButton = null
var _reparent_button: Button = null
var _add_root_button: Button = null
var _add_child_button: Button = null
var _delete_button: Button = null
var _visible_button: Button = null
var _locked_button: Button = null
var _status_label: Label = null
var _items_by_key: Dictionary = {}
var _updating := false


func _ready() -> void:
	name = "RigHierarchyEditor"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()
	_refresh()


func bind_session(session) -> void:
	if _session != null and is_instance_valid(_session) and _session.session_changed.is_connected(_on_session_changed):
		_session.session_changed.disconnect(_on_session_changed)
	_session = session
	if _session != null and is_instance_valid(_session) and not _session.session_changed.is_connected(_on_session_changed):
		_session.session_changed.connect(_on_session_changed)
	_refresh()


func bind_selection(selection) -> void:
	if _selection != null and is_instance_valid(_selection) and _selection.selection_changed.is_connected(_on_selection_changed):
		_selection.selection_changed.disconnect(_on_selection_changed)
	_selection = selection
	if _selection != null and is_instance_valid(_selection) and not _selection.selection_changed.is_connected(_on_selection_changed):
		_selection.selection_changed.connect(_on_selection_changed)
	_refresh_selection()


func get_hierarchy_tree() -> Tree:
	return _tree


func _build_ui() -> void:
	var rig_row := HBoxContainer.new()
	rig_row.name = "RigSelector"
	add_child(rig_row)
	_rig_picker = OptionButton.new()
	_rig_picker.name = "RigPicker"
	_rig_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rig_picker.item_selected.connect(_on_rig_selected)
	rig_row.add_child(_rig_picker)
	var new_rig := Button.new()
	new_rig.name = "NewRig"
	new_rig.text = "New Rig"
	new_rig.tooltip_text = "Create a persistent rig in this project"
	new_rig.pressed.connect(_on_new_rig_pressed)
	rig_row.add_child(new_rig)
	var tree_hint := Label.new()
	tree_hint.name = "HierarchyHint"
	tree_hint.text = "Bones"
	tree_hint.add_theme_font_size_override("font_size", 12)
	add_child(tree_hint)
	_tree = Tree.new()
	_tree.name = "RigTree"
	_tree.columns = 1
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_SINGLE
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.custom_minimum_size = Vector2(190, 180)
	_tree.item_selected.connect(_on_tree_item_selected)
	add_child(_tree)
	var name_row := HBoxContainer.new()
	name_row.name = "BoneNameRow"
	add_child(name_row)
	var name_label := Label.new()
	name_label.text = "Name"
	name_row.add_child(name_label)
	_name_input = LineEdit.new()
	_name_input.name = "SelectedName"
	_name_input.placeholder_text = "Bone name"
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_input.text_submitted.connect(func(_text): _rename_selected())
	_name_input.focus_exited.connect(_rename_selected)
	name_row.add_child(_name_input)
	var length_row := HBoxContainer.new()
	length_row.name = "BoneLengthRow"
	add_child(length_row)
	var length_label := Label.new()
	length_label.text = "Length"
	length_row.add_child(length_label)
	_length_input = SpinBox.new()
	_length_input.name = "BoneLength"
	_length_input.min_value = 1.0
	_length_input.max_value = 4096.0
	_length_input.step = 1.0
	_length_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_length_input.value_changed.connect(_on_length_changed)
	length_row.add_child(_length_input)
	var parent_row := HBoxContainer.new()
	parent_row.name = "BoneParentRow"
	add_child(parent_row)
	var parent_label := Label.new()
	parent_label.text = "Parent"
	parent_row.add_child(parent_label)
	_parent_picker = OptionButton.new()
	_parent_picker.name = "BoneParent"
	_parent_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent_row.add_child(_parent_picker)
	_reparent_button = Button.new()
	_reparent_button.name = "ReparentBone"
	_reparent_button.text = "Set"
	_reparent_button.tooltip_text = "Set the selected bone's parent"
	_reparent_button.pressed.connect(_on_reparent_pressed)
	parent_row.add_child(_reparent_button)
	var actions := HBoxContainer.new()
	actions.name = "RigActions"
	add_child(actions)
	_add_root_button = Button.new()
	_add_root_button.name = "AddRootBone"
	_add_root_button.text = "Add Root"
	_add_root_button.pressed.connect(_on_add_root_pressed)
	actions.add_child(_add_root_button)
	_add_child_button = Button.new()
	_add_child_button.name = "AddChildBone"
	_add_child_button.text = "Add Child"
	_add_child_button.pressed.connect(_on_add_child_pressed)
	actions.add_child(_add_child_button)
	_visible_button = Button.new()
	_visible_button.name = "ToggleBoneVisibility"
	_visible_button.text = "Hide"
	_visible_button.pressed.connect(_on_toggle_visibility_pressed)
	actions.add_child(_visible_button)
	_locked_button = Button.new()
	_locked_button.name = "ToggleBoneLock"
	_locked_button.text = "Lock"
	_locked_button.pressed.connect(_on_toggle_lock_pressed)
	actions.add_child(_locked_button)
	_delete_button = Button.new()
	_delete_button.name = "DeleteSelection"
	_delete_button.text = "Delete"
	_delete_button.pressed.connect(_on_delete_pressed)
	actions.add_child(_delete_button)
	_status_label = Label.new()
	_status_label.name = "RigStatus"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 12)
	add_child(_status_label)


func _refresh() -> void:
	if _tree == null: return
	_updating = true
	_rig_picker.clear()
	_tree.clear()
	_items_by_key.clear()
	if _session == null or not is_instance_valid(_session):
		_set_status("Open a project to create and edit a character rig.")
		_set_controls_enabled(false)
		_updating = false
		return
	var rigs: Array = _session.get_rigs()
	for rig in rigs:
		var data: Dictionary = rig
		_rig_picker.add_item(str(data.get("name", data.get("id", "Rig"))))
		_rig_picker.set_item_metadata(_rig_picker.item_count - 1, str(data.get("id", "")))
	var active_id: String = _session.get_active_rig_id()
	if active_id.is_empty() and not rigs.is_empty():
		active_id = str((rigs[0] as Dictionary).get("id", ""))
		_session.set_active_rig_id(active_id)
	for index in range(_rig_picker.item_count):
		if str(_rig_picker.get_item_metadata(index)) == active_id:
			_rig_picker.select(index)
			break
	var rig: Dictionary = _session.get_active_rig()
	if rig.is_empty():
		_set_status("Create a rig, then add a root bone for the character.")
		_set_controls_enabled(true, false)
		_updating = false
		return
	var root_item := _tree.create_item()
	root_item.set_text(0, str(rig.get("name", "Rig")))
	root_item.set_metadata(0, {"kind": "rig", "rig_id": active_id})
	root_item.set_tooltip_text(0, "Rig: " + active_id)
	_items_by_key["rig:" + active_id] = root_item
	var bones: Dictionary = rig.get("bones", {})
	var roots: Array = []
	for bone_id in bones:
		if str((bones[bone_id] as Dictionary).get("parent_id", "")).is_empty(): roots.append(str(bone_id))
	roots.sort()
	var visited := {}
	for bone_id in roots: _add_bone_item(root_item, bone_id, bones, active_id, visited)
	for bone_id in bones:
		if not visited.has(str(bone_id)): _add_bone_item(root_item, str(bone_id), bones, active_id, visited)
	_set_controls_enabled(true, true)
	_updating = false
	_refresh_selection()
	_set_status("%d bone%s in %s." % [bones.size(), "s" if bones.size() != 1 else "", str(rig.get("name", "this rig"))])


func _add_bone_item(parent: TreeItem, bone_id: String, bones: Dictionary, rig_id: String, visited: Dictionary) -> void:
	if visited.has(bone_id) or not bones.has(bone_id): return
	visited[bone_id] = true
	var bone: Dictionary = bones[bone_id]
	var item := _tree.create_item(parent)
	var flags := ""
	if not bool(bone.get("visible", true)): flags += " · hidden"
	if bool(bone.get("locked", false)): flags += " · locked"
	item.set_text(0, str(bone.get("name", bone_id)) + flags)
	item.set_metadata(0, {"kind": "bone", "rig_id": rig_id, "bone_id": bone_id})
	item.set_tooltip_text(0, "Bone: " + bone_id)
	item.set_collapsed(false)
	_items_by_key["bone:" + bone_id] = item
	var children: Array = bone.get("children", []).duplicate()
	children.sort()
	for child_id in children: _add_bone_item(item, str(child_id), bones, rig_id, visited)


func _refresh_selection() -> void:
	if _tree == null or _updating: return
	var selected: Dictionary = _selected_data()
	if _selection != null and is_instance_valid(_selection):
		var kind: String = _selection.get_kind()
		var item_id: String = _selection.get_item_id()
		if kind == "bone" and _items_by_key.has("bone:" + item_id):
			var bone_item: TreeItem = _items_by_key["bone:" + item_id]
			bone_item.select(0)
			selected = bone_item.get_metadata(0) as Dictionary
		elif kind == "rig" and _items_by_key.has("rig:" + item_id):
			var rig_item: TreeItem = _items_by_key["rig:" + item_id]
			rig_item.select(0)
			selected = rig_item.get_metadata(0) as Dictionary
	_update_selected_controls(selected)


func _selected_data() -> Dictionary:
	var item := _tree.get_selected() if _tree != null else null
	return item.get_metadata(0) as Dictionary if item != null and item.get_metadata(0) is Dictionary else {}


func _update_selected_controls(data: Dictionary) -> void:
	var has_bone := str(data.get("kind", "")) == "bone"
	var has_rig := str(data.get("kind", "")) == "rig"
	_name_input.editable = has_bone or has_rig
	_length_input.editable = has_bone
	_parent_picker.disabled = not has_bone
	_reparent_button.disabled = not has_bone
	_add_child_button.disabled = not has_bone
	_visible_button.disabled = not has_bone
	_locked_button.disabled = not has_bone
	_delete_button.disabled = not (has_bone or has_rig)
	if _session == null or not is_instance_valid(_session): return
	if has_bone:
		var rig: Dictionary = _session.get_rig(str(data.get("rig_id", "")))
		var bone: Dictionary = rig.get("bones", {}).get(str(data.get("bone_id", "")), {}) as Dictionary
		_name_input.text = str(bone.get("name", ""))
		_length_input.value = float(bone.get("length", 50.0))
		_populate_parent_picker(rig, str(data.get("bone_id", "")), str(bone.get("parent_id", "")))
		_visible_button.text = "Show" if not bool(bone.get("visible", true)) else "Hide"
		_locked_button.text = "Unlock" if bool(bone.get("locked", false)) else "Lock"
	elif has_rig:
		var selected_rig: Dictionary = _session.get_rig(str(data.get("rig_id", "")))
		_name_input.text = str(selected_rig.get("name", ""))
	else:
		_name_input.text = ""
		_parent_picker.clear()


func _set_controls_enabled(project_open: bool, rig_open: bool = false) -> void:
	_rig_picker.disabled = not project_open
	_name_input.editable = false
	_length_input.editable = false
	_parent_picker.disabled = true
	_reparent_button.disabled = true
	_add_root_button.disabled = not rig_open
	_add_child_button.disabled = true
	_visible_button.disabled = true
	_locked_button.disabled = true
	_delete_button.disabled = true


func _on_session_changed(_description: String) -> void:
	_refresh()


func _on_selection_changed(_kind: String, _item_id: String, _context: Dictionary) -> void:
	_refresh_selection()


func _on_rig_selected(index: int) -> void:
	if _updating or _session == null or index < 0: return
	var rig_id := str(_rig_picker.get_item_metadata(index))
	if _session.set_active_rig_id(rig_id):
		if _selection != null and is_instance_valid(_selection): _selection.select("rig", rig_id, {"source": "hierarchy"})
		_refresh()


func _on_new_rig_pressed() -> void:
	if _session == null: return
	var report: Dictionary = _session.create_rig("Character Rig")
	if report.get("success", false):
		if _selection != null and is_instance_valid(_selection): _selection.select("rig", str(report.get("rig_id", "")), {"source": "hierarchy"})
		_set_status("Created a rig. Add a root bone to begin.")
	else:
		_set_status(str(report.get("errors", ["Could not create rig."])[0]))


func _on_tree_item_selected() -> void:
	if _updating: return
	var data := _selected_data()
	if data.is_empty(): return
	if _selection != null and is_instance_valid(_selection):
		_selection.select(str(data.get("kind", "")), str(data.get("bone_id", data.get("rig_id", ""))), data)
	_update_selected_controls(data)


func _on_add_root_pressed() -> void:
	if _session == null: return
	var rig_id: String = _session.get_active_rig_id()
	var report: Dictionary = _session.create_rig_bone(rig_id, "Bone", "", _length_input.value)
	if report.get("success", false):
		if _selection != null and is_instance_valid(_selection): _selection.select("bone", str(report.get("bone_id", "")), {"rig_id": rig_id, "source": "hierarchy"})
	else:
		_set_status(str(report.get("errors", ["Could not add root bone."])[0]))


func _on_add_child_pressed() -> void:
	if _session == null: return
	var data := _selected_data()
	if str(data.get("kind", "")) != "bone": return
	var report: Dictionary = _session.create_rig_bone(str(data.get("rig_id", "")), "Bone", str(data.get("bone_id", "")), _length_input.value)
	if report.get("success", false) and _selection != null and is_instance_valid(_selection):
		_selection.select("bone", str(report.get("bone_id", "")), {"rig_id": str(data.get("rig_id", "")), "source": "hierarchy"})


func _on_delete_pressed() -> void:
	if _session == null: return
	var data := _selected_data()
	var kind := str(data.get("kind", ""))
	var success := false
	if kind == "bone": success = _session.delete_rig_bone(str(data.get("rig_id", "")), str(data.get("bone_id", "")))
	elif kind == "rig": success = _session.delete_rig(str(data.get("rig_id", "")))
	if success and _selection != null and is_instance_valid(_selection): _selection.clear()


func _rename_selected() -> void:
	if _updating or _session == null: return
	var data := _selected_data()
	var kind := str(data.get("kind", ""))
	if kind == "bone": _session.set_rig_bone_name(str(data.get("rig_id", "")), str(data.get("bone_id", "")), _name_input.text)
	elif kind == "rig": _session.rename_rig(str(data.get("rig_id", "")), _name_input.text)


func _on_length_changed(value: float) -> void:
	if _updating or _session == null: return
	var data := _selected_data()
	if str(data.get("kind", "")) == "bone": _session.set_rig_bone_length(str(data.get("rig_id", "")), str(data.get("bone_id", "")), value)


func _on_reparent_pressed() -> void:
	if _session == null or _parent_picker.selected < 0: return
	var data := _selected_data()
	if str(data.get("kind", "")) != "bone": return
	_session.reparent_rig_bone(str(data.get("rig_id", "")), str(data.get("bone_id", "")), str(_parent_picker.get_item_metadata(_parent_picker.selected)))


func _on_toggle_visibility_pressed() -> void:
	if _session == null: return
	var data := _selected_data()
	if str(data.get("kind", "")) != "bone": return
	var rig: Dictionary = _session.get_rig(str(data.get("rig_id", "")))
	var bone: Dictionary = rig.get("bones", {}).get(str(data.get("bone_id", "")), {}) as Dictionary
	_session.set_rig_bone_visibility(str(data.get("rig_id", "")), str(data.get("bone_id", "")), not bool(bone.get("visible", true)))


func _on_toggle_lock_pressed() -> void:
	if _session == null: return
	var data := _selected_data()
	if str(data.get("kind", "")) != "bone": return
	var rig: Dictionary = _session.get_rig(str(data.get("rig_id", "")))
	var bone: Dictionary = rig.get("bones", {}).get(str(data.get("bone_id", "")), {}) as Dictionary
	_session.set_rig_bone_locked(str(data.get("rig_id", "")), str(data.get("bone_id", "")), not bool(bone.get("locked", false)))


func _populate_parent_picker(rig: Dictionary, bone_id: String, selected_parent_id: String) -> void:
	_parent_picker.clear()
	_parent_picker.add_item("No parent")
	_parent_picker.set_item_metadata(0, "")
	var blocked := _descendant_ids(rig.get("bones", {}) as Dictionary, bone_id)
	blocked[bone_id] = true
	var bone_ids: Array = (rig.get("bones", {}) as Dictionary).keys()
	bone_ids.sort()
	for candidate_id in bone_ids:
		var candidate := str(candidate_id)
		if blocked.has(candidate): continue
		var candidate_bone: Dictionary = (rig.get("bones", {}) as Dictionary).get(candidate, {}) as Dictionary
		_parent_picker.add_item(str(candidate_bone.get("name", candidate)))
		_parent_picker.set_item_metadata(_parent_picker.item_count - 1, candidate)
		if candidate == selected_parent_id: _parent_picker.select(_parent_picker.item_count - 1)
	if selected_parent_id.is_empty(): _parent_picker.select(0)


func _descendant_ids(bones: Dictionary, bone_id: String) -> Dictionary:
	var descendants := {}
	if not bones.has(bone_id): return descendants
	for child_id in (bones[bone_id] as Dictionary).get("children", []):
		var child := str(child_id)
		descendants[child] = true
		for descendant in _descendant_ids(bones, child): descendants[descendant] = true
	return descendants


func _set_status(message: String) -> void:
	if _status_label != null: _status_label.text = message
	status_changed.emit(message)
