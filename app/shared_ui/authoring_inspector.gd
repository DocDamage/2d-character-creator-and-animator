# AuthoringInspector -- Contextual property editor for the selected document object.
class_name AuthoringInspector
extends VBoxContainer

const TrackDefinitionScript = preload("res://animation/tracks/track_schema.gd")

signal status_changed(message: String)

var _session = null
var _selection = null
var _preview_controller = null
var _title_label: Label = null
var _properties: VBoxContainer = null
var _status_label: Label = null
var _updating := false


func _ready() -> void:
	name = "AuthoringInspector"
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
	_refresh()


func bind_preview_controller(controller) -> void:
	if _preview_controller != null and is_instance_valid(_preview_controller) and _preview_controller.preview_evaluated.is_connected(_on_preview_evaluated):
		_preview_controller.preview_evaluated.disconnect(_on_preview_evaluated)
	_preview_controller = controller
	if _preview_controller != null and is_instance_valid(_preview_controller) and not _preview_controller.preview_evaluated.is_connected(_on_preview_evaluated):
		_preview_controller.preview_evaluated.connect(_on_preview_evaluated)
	_refresh()


func get_properties_container() -> VBoxContainer:
	return _properties


func _build_ui() -> void:
	_title_label = Label.new()
	_title_label.name = "InspectorTitle"
	_title_label.text = "Inspector"
	_title_label.add_theme_font_size_override("font_size", 16)
	add_child(_title_label)
	var scroll := ScrollContainer.new()
	scroll.name = "PropertyScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_properties = VBoxContainer.new()
	_properties.name = "Properties"
	_properties.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_properties.add_theme_constant_override("separation", 8)
	scroll.add_child(_properties)
	_status_label = Label.new()
	_status_label.name = "InspectorStatus"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 12)
	add_child(_status_label)


func _refresh() -> void:
	if _properties == null: return
	_updating = true
	for child in _properties.get_children():
		_properties.remove_child(child)
		child.queue_free()
	if _session == null or not is_instance_valid(_session):
		_title_label.text = "Inspector & Properties"
		_add_help("Open a project, then select a layer, bone, animation, or keyframe to edit its properties.")
		_set_status("No project selected.")
		_updating = false
		return
	if _selection == null or not is_instance_valid(_selection) or _selection.get_kind().is_empty():
		_title_label.text = "Inspector & Properties"
		_add_help("Select artwork in the Canvas, a bone in Hierarchy, or a key in Timeline.")
		_set_status("Nothing selected.")
		_updating = false
		return
	var kind: String = _selection.get_kind()
	var item_id: String = _selection.get_item_id()
	var context: Dictionary = _selection.get_context()
	match kind:
		"layer": _build_layer_properties(item_id)
		"bone": _build_bone_properties(item_id, context)
		"rig": _build_rig_properties(item_id)
		"animation_clip": _build_clip_properties(item_id)
		"animation_key": _build_key_properties(item_id, context)
		"animation_track": _build_track_properties(item_id, context)
		"action_point", "hitbox", "hurtbox": _build_gameplay_overlay_properties(kind, item_id, context)
		_:
			_title_label.text = "Inspector & Properties"
			_add_help("This selection has no editable document properties yet.")
			_set_status("Unsupported selection.")
	_updating = false


func _build_layer_properties(part_id: String) -> void:
	if _session.model == null:
		_add_help("No character model is available.")
		return
	var layer: Dictionary = _find_layer(part_id)
	if layer.is_empty():
		_add_help("The selected layer no longer exists.")
		return
	var rest_state: Dictionary = _session.model.get_layer_state(part_id)
	var state: Dictionary = _preview_layer_state(part_id, rest_state)
	var name := str(layer.get("name", part_id))
	_title_label.text = name + " Layer"
	_add_section("Transform")
	var position: Array = state.get("position", [0.0, 0.0])
	_add_keyed_spin("Position X", float(position[0]) if position.size() > 0 else 0.0, -8192.0, 8192.0, 1.0, part_id, "layer:" + part_id + ".position", [float(position[0]) if position.size() > 0 else 0.0, float(position[1]) if position.size() > 1 else 0.0], 0, func(value): _set_layer_position_component(part_id, 0, value))
	_add_keyed_spin("Position Y", float(position[1]) if position.size() > 1 else 0.0, -8192.0, 8192.0, 1.0, part_id, "layer:" + part_id + ".position", [float(position[0]) if position.size() > 0 else 0.0, float(position[1]) if position.size() > 1 else 0.0], 0, func(value): _set_layer_position_component(part_id, 1, value))
	var scale: Array = state.get("scale", [1.0, 1.0])
	_add_keyed_spin("Scale X", float(scale[0]) if scale.size() > 0 else 1.0, 0.01, 100.0, 0.01, part_id, "layer:" + part_id + ".scale", [float(scale[0]) if scale.size() > 0 else 1.0, float(scale[1]) if scale.size() > 1 else 1.0], 2, func(value): _set_layer_scale_component(part_id, 0, value))
	_add_keyed_spin("Scale Y", float(scale[1]) if scale.size() > 1 else 1.0, 0.01, 100.0, 0.01, part_id, "layer:" + part_id + ".scale", [float(scale[0]) if scale.size() > 0 else 1.0, float(scale[1]) if scale.size() > 1 else 1.0], 2, func(value): _set_layer_scale_component(part_id, 1, value))
	_add_keyed_spin("Rotation", float(state.get("rotation_degrees", 0.0)), -3600.0, 3600.0, 1.0, part_id, "layer:" + part_id + ".rotation_degrees", float(state.get("rotation_degrees", 0.0)), 1, func(value): _set_layer_rotation(part_id, value))
	var pivot: Array = state.get("pivot", [0.5, 0.5])
	_add_keyed_spin("Pivot X", float(pivot[0]) if pivot.size() > 0 else 0.5, -4.0, 4.0, 0.01, part_id, "layer:" + part_id + ".pivot", [float(pivot[0]) if pivot.size() > 0 else 0.5, float(pivot[1]) if pivot.size() > 1 else 0.5], 6, func(value): _set_layer_pivot_component(part_id, 0, value))
	_add_keyed_spin("Pivot Y", float(pivot[1]) if pivot.size() > 1 else 0.5, -4.0, 4.0, 0.01, part_id, "layer:" + part_id + ".pivot", [float(pivot[0]) if pivot.size() > 0 else 0.5, float(pivot[1]) if pivot.size() > 1 else 0.5], 6, func(value): _set_layer_pivot_component(part_id, 1, value))
	_add_keyed_spin("Opacity", float(state.get("opacity", 1.0)), 0.0, 1.0, 0.01, part_id, "layer:" + part_id + ".opacity", float(state.get("opacity", 1.0)), 6, func(value): _set_layer_opacity(part_id, value))
	var tint_values: Array = state.get("tint", [1.0, 1.0, 1.0, 1.0])
	var tint := Color(float(tint_values[0]), float(tint_values[1]), float(tint_values[2]), float(tint_values[3]))
	_add_keyed_color("Tint", tint, part_id, "layer:" + part_id + ".tint", [tint.r, tint.g, tint.b, tint.a], 6, func(color): _set_layer_tint(part_id, color))
	_add_section("Layer")
	_add_keyed_toggle("Visible", bool(state.get("visible", true)), part_id, "layer:" + part_id + ".visible", bool(state.get("visible", true)), 4, func(pressed): _set_layer_visibility(part_id, pressed))
	_add_toggle("Locked", bool(rest_state.get("locked", false)), func(pressed): _session.model.set_layer_locked(part_id, pressed))
	if bool(layer.get("missing", false)):
		_add_help("This layer's imported artwork is missing. Use the Quality & Recovery or Character Creator repair action.")
	_set_status("Changes use the document Undo/Redo history.")


func _build_bone_properties(bone_id: String, context: Dictionary) -> void:
	var rig_id := str(context.get("rig_id", _session.get_active_rig_id()))
	var rig: Dictionary = _session.get_rig(rig_id)
	var bone: Dictionary = rig.get("bones", {}).get(bone_id, {}) as Dictionary
	if bone.is_empty():
		_add_help("The selected bone no longer exists.")
		return
	bone = _preview_bone(rig_id, bone_id, bone)
	_title_label.text = str(bone.get("name", bone_id)) + " Bone"
	_add_line("Name", str(bone.get("name", "")), func(value): _session.set_rig_bone_name(rig_id, bone_id, value))
	_add_section("Transform")
	var position: Vector2 = bone.get("local_position", Vector2.ZERO) as Vector2
	var scale: Vector2 = bone.get("local_scale", Vector2.ONE) as Vector2
	var degrees := rad_to_deg(float(bone.get("local_rotation", 0.0)))
	_add_keyed_spin("Position X", position.x, -8192.0, 8192.0, 1.0, bone_id, "bone:" + bone_id + ".position", [position.x, position.y], 0, func(value): _set_bone_transform_component(rig_id, bone_id, "position_x", value))
	_add_keyed_spin("Position Y", position.y, -8192.0, 8192.0, 1.0, bone_id, "bone:" + bone_id + ".position", [position.x, position.y], 0, func(value): _set_bone_transform_component(rig_id, bone_id, "position_y", value))
	_add_keyed_spin("Rotation", degrees, -3600.0, 3600.0, 1.0, bone_id, "bone:" + bone_id + ".rotation_degrees", degrees, 1, func(value): _set_bone_transform_component(rig_id, bone_id, "rotation", value))
	_add_keyed_spin("Scale X", scale.x, 0.01, 100.0, 0.01, bone_id, "bone:" + bone_id + ".scale", [scale.x, scale.y], 2, func(value): _set_bone_transform_component(rig_id, bone_id, "scale_x", value))
	_add_keyed_spin("Scale Y", scale.y, 0.01, 100.0, 0.01, bone_id, "bone:" + bone_id + ".scale", [scale.x, scale.y], 2, func(value): _set_bone_transform_component(rig_id, bone_id, "scale_y", value))
	_add_spin("Length", float(bone.get("length", 50.0)), 1.0, 4096.0, 1.0, func(value): _session.set_rig_bone_length(rig_id, bone_id, value))
	_add_section("Bone")
	_add_toggle("Visible", bool(bone.get("visible", true)), func(pressed): _session.set_rig_bone_visibility(rig_id, bone_id, pressed))
	_add_toggle("Locked", bool(bone.get("locked", false)), func(pressed): _session.set_rig_bone_locked(rig_id, bone_id, pressed))
	_set_status("Bone edits are saved with the current project.")


func _build_rig_properties(rig_id: String) -> void:
	var rig: Dictionary = _session.get_rig(rig_id)
	if rig.is_empty():
		_add_help("The selected rig no longer exists.")
		return
	_title_label.text = str(rig.get("name", rig_id))
	_add_line("Rig Name", str(rig.get("name", "")), func(value): _session.rename_rig(rig_id, value))
	_add_readonly("Bones", str((rig.get("bones", {}) as Dictionary).size()))
	_add_readonly("Root", str(rig.get("root_bone_id", "None")))
	_set_status("Rig structure is edited in Hierarchy & Rig.")


func _build_clip_properties(clip_id: String) -> void:
	var clip: Dictionary = _session.get_animation_clip(clip_id)
	if clip.is_empty():
		_add_help("The selected animation no longer exists.")
		return
	_title_label.text = str(clip.get("clip_name", clip_id)) + " Animation"
	_add_line("Name", str(clip.get("clip_name", "")), func(value): _session.update_animation_clip(clip_id, {"clip_name": value}, "Renamed Animation"))
	_add_spin("Duration", float(clip.get("duration", 1.0)), 0.01, 3600.0, 0.01, func(value): _session.update_animation_clip(clip_id, {"duration": value}, "Changed Animation Duration"))
	_add_spin("FPS", float(clip.get("fps", 24.0)), 1.0, 240.0, 1.0, func(value): _session.update_animation_clip(clip_id, {"fps": value}, "Changed Animation FPS"))
	var loop_picker := OptionButton.new()
	loop_picker.name = "LoopMode"
	loop_picker.add_item("No Loop")
	loop_picker.add_item("Loop")
	loop_picker.add_item("Ping Pong")
	loop_picker.select(clampi(int(clip.get("loop_mode", 0)), 0, 2))
	loop_picker.item_selected.connect(func(index): if not _updating: _session.update_animation_clip(clip_id, {"loop_mode": index}, "Changed Animation Loop"))
	_add_row("Loop", loop_picker)
	_add_section("Markers")
	for raw_marker in clip.get("markers", []):
		_add_timeline_annotation_row(clip_id, raw_marker as Dictionary, false)
	_add_section("Regions")
	for raw_region in clip.get("regions", []):
		_add_timeline_annotation_row(clip_id, raw_region as Dictionary, true)
	_add_readonly("Tracks", str((clip.get("tracks", []) as Array).size()))
	_set_status("Clip settings are shared by Timeline and animation workspaces.")


func _add_timeline_annotation_row(clip_id: String, annotation: Dictionary, is_region: bool) -> void:
	var row := HBoxContainer.new()
	row.name = ("Region" if is_region else "Marker") + str(annotation.get("region_id" if is_region else "marker_id", ""))
	var name := LineEdit.new()
	name.custom_minimum_size = Vector2(74, 0)
	name.text = str(annotation.get("name", "Region" if is_region else "Marker"))
	name.tooltip_text = "Rename timeline " + ("region" if is_region else "marker")
	var identifier: String = str(annotation.get("region_id" if is_region else "marker_id", ""))
	name.focus_exited.connect(func():
		if _updating: return
		if is_region: _session.update_animation_region(clip_id, identifier, {"name": name.text})
		else: _session.update_animation_marker(clip_id, identifier, {"name": name.text}))
	row.add_child(name)
	var start := SpinBox.new()
	start.custom_minimum_size = Vector2(64, 0)
	start.min_value = 0.0
	start.max_value = 3600.0
	start.step = 0.01
	start.value = float(annotation.get("start_time" if is_region else "time", 0.0))
	start.value_changed.connect(func(next):
		if _updating: return
		if is_region: _session.update_animation_region(clip_id, identifier, {"start_time": next})
		else: _session.update_animation_marker(clip_id, identifier, {"time": next}))
	row.add_child(start)
	if is_region:
		var end := SpinBox.new()
		end.custom_minimum_size = Vector2(64, 0)
		end.min_value = 0.0
		end.max_value = 3600.0
		end.step = 0.01
		end.value = float(annotation.get("end_time", 0.0))
		end.value_changed.connect(func(next): if not _updating: _session.update_animation_region(clip_id, identifier, {"end_time": next}))
		row.add_child(end)
		var clip: Dictionary = _session.get_animation_clip(clip_id)
		var loop := CheckButton.new()
		loop.name = "LoopRegion"
		loop.text = "Loop"
		loop.tooltip_text = "Use this region as the animation playback loop"
		loop.button_pressed = bool(clip.get("loop_region_enabled", false)) and str(clip.get("loop_region_id", "")) == identifier
		loop.toggled.connect(func(enabled):
			if _updating: return
			if enabled: _session.set_animation_loop_region(clip_id, identifier)
			elif str(_session.get_animation_clip(clip_id).get("loop_region_id", "")) == identifier: _session.set_animation_loop_region(clip_id, ""))
		row.add_child(loop)
	var remove := Button.new()
	remove.name = "Delete" + ("Region" if is_region else "Marker")
	remove.text = "×"
	remove.tooltip_text = "Delete timeline " + ("region" if is_region else "marker")
	remove.pressed.connect(func():
		if is_region: _session.delete_animation_region(clip_id, identifier)
		else: _session.delete_animation_marker(clip_id, identifier))
	row.add_child(remove)
	_properties.add_child(row)


func _build_key_properties(key_id: String, context: Dictionary) -> void:
	var clip_id := str(context.get("clip_id", _session.get_active_animation_id()))
	var track_id := str(context.get("track_id", ""))
	var track: Dictionary = _session.get_animation_track(clip_id, track_id)
	var key: Dictionary = {}
	for raw_key in track.get("keys", []):
		if str((raw_key as Dictionary).get("key_id", "")) == key_id:
			key = raw_key as Dictionary
			break
	if key.is_empty():
		_add_help("The selected keyframe no longer exists.")
		return
	_title_label.text = "Keyframe · " + str(track.get("display_name", track_id))
	_add_spin("Time", float(key.get("time", 0.0)), 0.0, 3600.0, 0.01, func(value): _session.move_animation_key(clip_id, track_id, key_id, value))
	_add_section("Interpolation")
	var interpolation := OptionButton.new()
	interpolation.name = "Interpolation"
	for label in ["Stepped", "Linear", "Smooth", "Bezier"]:
		interpolation.add_item(label)
	interpolation.select(clampi(int(key.get("interpolation", TrackDefinitionScript.Interpolation.LINEAR)), TrackDefinitionScript.Interpolation.STEPPED, TrackDefinitionScript.Interpolation.BEZIER))
	interpolation.item_selected.connect(func(index):
		if not _updating: _session.set_animation_key_interpolation(clip_id, track_id, key_id, index))
	_add_row("Mode", interpolation)
	if int(key.get("interpolation", TrackDefinitionScript.Interpolation.LINEAR)) == TrackDefinitionScript.Interpolation.BEZIER:
		var out_handle := _key_handle(key.get("out_handle", [0.25, 0.0]), Vector2(0.25, 0.0))
		var in_handle := _key_handle(key.get("in_handle", [-0.25, 0.0]), Vector2(-0.25, 0.0))
		_add_spin("Bezier Out X", out_handle.x, -2.0, 2.0, 0.01, func(value): _set_key_handles(clip_id, track_id, key_id, Vector2(value, out_handle.y), in_handle))
		_add_spin("Bezier Out Y", out_handle.y, -4.0, 4.0, 0.01, func(value): _set_key_handles(clip_id, track_id, key_id, Vector2(out_handle.x, value), in_handle))
		_add_spin("Bezier In X", in_handle.x, -2.0, 2.0, 0.01, func(value): _set_key_handles(clip_id, track_id, key_id, out_handle, Vector2(value, in_handle.y)))
		_add_spin("Bezier In Y", in_handle.y, -4.0, 4.0, 0.01, func(value): _set_key_handles(clip_id, track_id, key_id, out_handle, Vector2(in_handle.x, value)))
	_add_section("Key Value")
	_build_type_specific_key_editor(clip_id, track_id, key_id, track, key)
	_add_readonly("Track", str(track.get("property_path", "")))
	_set_status("Edit the key's typed payload here, or drag it in Timeline. Bézier handles remain optional for older projects.")


func _build_type_specific_key_editor(clip_id: String, track_id: String, key_id: String, track: Dictionary, key: Dictionary) -> void:
	var kind: int = int(track.get("track_type", TrackDefinitionScript.TrackType.ATTRIBUTE))
	var value: Variant = key.get("value", null)
	match kind:
		TrackDefinitionScript.TrackType.IMAGE_SWAP:
			var assets := OptionButton.new()
			assets.name = "ImageSwapAsset"
			for raw_asset in _session.asset_registry.list_assets():
				var asset: Dictionary = raw_asset
				if str(asset.get("category", "")) == "audio": continue
				assets.add_item(str(asset.get("name", asset.get("asset_id", "Artwork"))))
				assets.set_item_metadata(assets.item_count - 1, str(asset.get("asset_id", "")))
				if str(asset.get("asset_id", "")) == str(value): assets.select(assets.item_count - 1)
			assets.item_selected.connect(func(index): if not _updating: _session.set_animation_key_value(clip_id, track_id, key_id, str(assets.get_item_metadata(index))))
			_add_row("Imported Art", assets)
		TrackDefinitionScript.TrackType.VISIBILITY:
			_add_toggle("Visible", bool(value), func(pressed): _session.set_animation_key_value(clip_id, track_id, key_id, pressed))
		TrackDefinitionScript.TrackType.Z_ORDER:
			_add_spin("Draw Order", float(value), -10000.0, 10000.0, 1.0, func(next): _session.set_animation_key_value(clip_id, track_id, key_id, int(next)))
		TrackDefinitionScript.TrackType.ACTION_POINT:
			_build_action_point_editor(clip_id, track_id, key_id, value as Dictionary if value is Dictionary else {})
		TrackDefinitionScript.TrackType.HITBOX, TrackDefinitionScript.TrackType.HURTBOX:
			_build_collision_editor(clip_id, track_id, key_id, value as Array if value is Array else [])
		TrackDefinitionScript.TrackType.EVENT:
			_build_event_editor(clip_id, track_id, key_id, value as Dictionary if value is Dictionary else {})
		TrackDefinitionScript.TrackType.AUDIO_CUE:
			_build_audio_cue_editor(clip_id, track_id, key_id, value as Dictionary if value is Dictionary else {})
		TrackDefinitionScript.TrackType.VISEME:
			_build_viseme_editor(clip_id, track_id, key_id, value as Dictionary if value is Dictionary else {})
		TrackDefinitionScript.TrackType.SCRIPT_PARAMETER:
			_add_readonly("Parameter", str(track.get("parameter_name", track.get("property_path", ""))))
			_add_line("Value", str(value), func(next): _session.set_animation_key_value(clip_id, track_id, key_id, next))
		TrackDefinitionScript.TrackType.TRANSFORM_POSITION, TrackDefinitionScript.TrackType.TRANSFORM_SCALE:
			_build_vector_key_editor(clip_id, track_id, key_id, value)
		TrackDefinitionScript.TrackType.TRANSFORM_ROTATION:
			_add_spin("Degrees", float(value), -3600.0, 3600.0, 0.1, func(next): _session.set_animation_key_value(clip_id, track_id, key_id, next))
		_:
			if value is float or value is int:
				_add_spin("Value", float(value), -100000.0, 100000.0, 0.01, func(next): _session.set_animation_key_value(clip_id, track_id, key_id, next))
			else:
				_add_line("Value", str(value), func(next): _session.set_animation_key_value(clip_id, track_id, key_id, next))


func _build_vector_key_editor(clip_id: String, track_id: String, key_id: String, value: Variant) -> void:
	var vector := _key_handle(value, Vector2.ZERO)
	_add_spin("X", vector.x, -8192.0, 8192.0, 0.01, func(next): _session.set_animation_key_value(clip_id, track_id, key_id, [next, vector.y]))
	_add_spin("Y", vector.y, -8192.0, 8192.0, 0.01, func(next): _session.set_animation_key_value(clip_id, track_id, key_id, [vector.x, next]))


func _build_action_point_editor(clip_id: String, track_id: String, key_id: String, value: Dictionary) -> void:
	var entry: Dictionary = value.duplicate(true)
	if str(entry.get("action_point_id", "")).is_empty(): entry["action_point_id"] = "point"
	var position := _key_handle(entry.get("local_position", [0.0, 0.0]), Vector2.ZERO)
	_add_line("Name", str(entry.get("display_name", "Action Point")), func(next): _set_key_dictionary_field(clip_id, track_id, key_id, entry, "display_name", next))
	_add_spin("Position X", position.x, -8192.0, 8192.0, 0.01, func(next): _set_key_dictionary_field(clip_id, track_id, key_id, entry, "local_position", [next, position.y]))
	_add_spin("Position Y", position.y, -8192.0, 8192.0, 0.01, func(next): _set_key_dictionary_field(clip_id, track_id, key_id, entry, "local_position", [position.x, next]))
	_add_spin("Rotation", float(entry.get("local_rotation", 0.0)), -3600.0, 3600.0, 0.1, func(next): _set_key_dictionary_field(clip_id, track_id, key_id, entry, "local_rotation", next))


func _build_collision_editor(clip_id: String, track_id: String, key_id: String, value: Array) -> void:
	var shapes: Array = value.duplicate(true)
	if shapes.is_empty():
		var add_shape := Button.new()
		add_shape.name = "AddCollisionRectangle"
		add_shape.text = "Add rectangle"
		add_shape.pressed.connect(func(): _session.set_animation_key_value(clip_id, track_id, key_id, [{"shape_id": "shape", "display_name": "Rectangle", "shape_type": 0, "local_position": [0.0, 0.0], "size": [16.0, 16.0], "radius": 8.0, "enabled": true}]))
		_properties.add_child(add_shape)
		return
	var shape: Dictionary = shapes[0] as Dictionary
	var position := _key_handle(shape.get("local_position", [0.0, 0.0]), Vector2.ZERO)
	var size := _key_handle(shape.get("size", [16.0, 16.0]), Vector2(16.0, 16.0))
	_add_readonly("Shapes", str(shapes.size()) + " (editing first)")
	_add_spin("Position X", position.x, -8192.0, 8192.0, 0.01, func(next): _set_first_shape_field(clip_id, track_id, key_id, shapes, "local_position", [next, position.y]))
	_add_spin("Position Y", position.y, -8192.0, 8192.0, 0.01, func(next): _set_first_shape_field(clip_id, track_id, key_id, shapes, "local_position", [position.x, next]))
	_add_spin("Width", size.x, 0.01, 8192.0, 0.01, func(next): _set_first_shape_field(clip_id, track_id, key_id, shapes, "size", [next, size.y]))
	_add_spin("Height", size.y, 0.01, 8192.0, 0.01, func(next): _set_first_shape_field(clip_id, track_id, key_id, shapes, "size", [size.x, next]))
	_add_spin("Radius", float(shape.get("radius", 8.0)), 0.01, 8192.0, 0.01, func(next): _set_first_shape_field(clip_id, track_id, key_id, shapes, "radius", next))
	_add_toggle("Enabled", bool(shape.get("enabled", true)), func(next): _set_first_shape_field(clip_id, track_id, key_id, shapes, "enabled", next))


func _build_event_editor(clip_id: String, track_id: String, key_id: String, value: Dictionary) -> void:
	var entry: Dictionary = value.duplicate(true)
	_add_line("Event Name", str(entry.get("event_name", "Event")), func(next): _set_key_dictionary_field(clip_id, track_id, key_id, entry, "event_name", next))
	_add_line("Event Type", str(entry.get("event_type", "notify")), func(next): _set_key_dictionary_field(clip_id, track_id, key_id, entry, "event_type", next))
	_add_line("Payload JSON", JSON.stringify(entry.get("payload", {})), func(next): _set_key_json_field(clip_id, track_id, key_id, entry, "payload", next))


func _build_audio_cue_editor(clip_id: String, track_id: String, key_id: String, value: Dictionary) -> void:
	var entry: Dictionary = value.duplicate(true)
	var picker := OptionButton.new()
	picker.name = "AudioCueAsset"
	for raw_asset in _session.asset_registry.list_assets("audio"):
		var asset: Dictionary = raw_asset
		picker.add_item(str(asset.get("name", asset.get("asset_id", "Audio"))))
		picker.set_item_metadata(picker.item_count - 1, str(asset.get("asset_id", "")))
		if str(asset.get("asset_id", "")) == str(entry.get("audio_asset_id", "")): picker.select(picker.item_count - 1)
	picker.item_selected.connect(func(index): if not _updating: _set_key_dictionary_field(clip_id, track_id, key_id, entry, "audio_asset_id", str(picker.get_item_metadata(index))))
	_add_row("Imported Audio", picker)
	_add_spin("Volume dB", float(entry.get("volume_db", 0.0)), -80.0, 24.0, 0.1, func(next): _set_key_dictionary_field(clip_id, track_id, key_id, entry, "volume_db", next))
	_add_spin("Pan", float(entry.get("pan", 0.0)), -1.0, 1.0, 0.01, func(next): _set_key_dictionary_field(clip_id, track_id, key_id, entry, "pan", next))


func _build_viseme_editor(clip_id: String, track_id: String, key_id: String, value: Dictionary) -> void:
	var entry: Dictionary = value.duplicate(true)
	_add_line("Viseme", str(entry.get("viseme_id", "neutral")), func(next): _set_key_dictionary_field(clip_id, track_id, key_id, entry, "viseme_id", next))
	_add_line("Mouth Layer", str(entry.get("mouth_attachment_id", "")), func(next): _set_key_dictionary_field(clip_id, track_id, key_id, entry, "mouth_attachment_id", next))
	var assets := OptionButton.new()
	assets.name = "VisemeAsset"
	assets.add_item("Use attachment artwork")
	assets.set_item_metadata(0, "")
	var selected_asset := str(entry.get("asset_id", entry.get("image_asset_id", "")))
	for raw_asset in _session.asset_registry.list_assets():
		var asset: Dictionary = raw_asset
		if str(asset.get("category", "")) == "audio": continue
		assets.add_item(str(asset.get("name", asset.get("asset_id", "Artwork"))))
		assets.set_item_metadata(assets.item_count - 1, str(asset.get("asset_id", "")))
		if str(asset.get("asset_id", "")) == selected_asset: assets.select(assets.item_count - 1)
	assets.item_selected.connect(func(index):
		if _updating: return
		_set_key_dictionary_field(clip_id, track_id, key_id, entry, "asset_id", str(assets.get_item_metadata(index))))
	_add_row("Imported Mouth Art", assets)


func _set_key_handles(clip_id: String, track_id: String, key_id: String, out_handle: Vector2, in_handle: Vector2) -> void:
	_session.set_animation_key_interpolation(clip_id, track_id, key_id, TrackDefinitionScript.Interpolation.BEZIER, [out_handle.x, out_handle.y], [in_handle.x, in_handle.y])


func _set_key_dictionary_field(clip_id: String, track_id: String, key_id: String, source: Dictionary, field: String, next_value: Variant) -> void:
	var next: Dictionary = source.duplicate(true)
	next[field] = next_value
	_session.set_animation_key_value(clip_id, track_id, key_id, next)


func _set_key_json_field(clip_id: String, track_id: String, key_id: String, source: Dictionary, field: String, raw: String) -> void:
	var parsed: Variant = JSON.parse_string(raw)
	if parsed == null:
		_set_status("Enter valid JSON before changing the event payload.")
		return
	_set_key_dictionary_field(clip_id, track_id, key_id, source, field, parsed)


func _set_first_shape_field(clip_id: String, track_id: String, key_id: String, source: Array, field: String, next_value: Variant) -> void:
	var shapes: Array = source.duplicate(true)
	if shapes.is_empty(): return
	var shape: Dictionary = (shapes[0] as Dictionary).duplicate(true)
	shape[field] = next_value
	shapes[0] = shape
	_session.set_animation_key_value(clip_id, track_id, key_id, shapes)


func _key_handle(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2: return value as Vector2
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return fallback


func _build_track_properties(track_id: String, context: Dictionary) -> void:
	var clip_id := str(context.get("clip_id", _session.get_active_animation_id()))
	var track: Dictionary = _session.get_animation_track(clip_id, track_id)
	if track.is_empty():
		_add_help("The selected track no longer exists.")
		return
	_title_label.text = str(track.get("display_name", track_id)) + " Track"
	_add_readonly("Object", str(track.get("object_id", "")))
	_add_readonly("Property", str(track.get("property_path", "")))
	_add_readonly("Keys", str((track.get("keys", []) as Array).size()))
	_set_status("Select a keyframe to edit its values.")


func _build_gameplay_overlay_properties(kind: String, overlay_id: String, context: Dictionary) -> void:
	var overlay: Dictionary = context.get("overlay", {}) as Dictionary
	_title_label.text = kind.replace("_", " ").capitalize() + " · " + overlay_id
	_add_readonly("ID", overlay_id)
	_add_readonly("Target", str(overlay.get("object_id", "")))
	_add_readonly("Track", str(overlay.get("track_id", "")))
	if kind == "action_point":
		_add_readonly("Position", str(overlay.get("local_position", [0.0, 0.0])))
		_add_readonly("Rotation", str(overlay.get("local_rotation", 0.0)))
	else:
		_add_readonly("Shape", "Circle" if int(overlay.get("shape_type", 0)) == 1 else "Rectangle")
		_add_readonly("Position", str(overlay.get("local_position", [0.0, 0.0])))
		_add_readonly("Size", str(overlay.get("size", [0.0, 0.0])))
	var track_id: String = str(overlay.get("track_id", ""))
	if not track_id.is_empty() and _selection != null and is_instance_valid(_selection):
		var open_track := Button.new()
		open_track.name = "OpenOverlayTrack"
		open_track.text = "Open track in Timeline"
		open_track.pressed.connect(func(): _selection.select("animation_track", track_id, {"clip_id": _session.get_active_animation_id(), "source": "overlay"}))
		_properties.add_child(open_track)
	_set_status("Selected live preview overlay. Its saved values remain editable through the linked timeline track.")


func _set_layer_position_component(part_id: String, component: int, value: float) -> void:
	if _updating or _session == null or _session.model == null: return
	var values: Array = _preview_layer_state(part_id, _session.model.get_layer_state(part_id)).get("position", [0.0, 0.0])
	var next := Vector2(float(values[0]) if values.size() > 0 else 0.0, float(values[1]) if values.size() > 1 else 0.0)
	if component == 0: next.x = value
	else: next.y = value
	_edit_animatable(part_id, "layer:" + part_id + ".position", [next.x, next.y], Callable(_session.model, "set_layer_position").bind(part_id, next), 0)


func _set_layer_scale_component(part_id: String, component: int, value: float) -> void:
	if _updating or _session == null or _session.model == null: return
	var values: Array = _preview_layer_state(part_id, _session.model.get_layer_state(part_id)).get("scale", [1.0, 1.0])
	var next := Vector2(float(values[0]) if values.size() > 0 else 1.0, float(values[1]) if values.size() > 1 else 1.0)
	if component == 0: next.x = value
	else: next.y = value
	_edit_animatable(part_id, "layer:" + part_id + ".scale", [next.x, next.y], Callable(_session.model, "set_layer_scale").bind(part_id, next), 2)


func _set_layer_pivot_component(part_id: String, component: int, value: float) -> void:
	if _updating or _session == null or _session.model == null: return
	var values: Array = _preview_layer_state(part_id, _session.model.get_layer_state(part_id)).get("pivot", [0.5, 0.5])
	var next := Vector2(float(values[0]) if values.size() > 0 else 0.5, float(values[1]) if values.size() > 1 else 0.5)
	if component == 0: next.x = value
	else: next.y = value
	_edit_animatable(part_id, "layer:" + part_id + ".pivot", [next.x, next.y], Callable(_session.model, "set_layer_pivot").bind(part_id, next), 6)


func _set_layer_rotation(part_id: String, value: float) -> void:
	if _updating or _session == null: return
	_edit_animatable(part_id, "layer:" + part_id + ".rotation_degrees", value, Callable(_session.model, "set_layer_rotation").bind(part_id, value), 1)


func _set_layer_opacity(part_id: String, value: float) -> void:
	if _updating or _session == null: return
	_edit_animatable(part_id, "layer:" + part_id + ".opacity", value, Callable(_session.model, "set_layer_opacity").bind(part_id, value), 6)


func _set_layer_tint(part_id: String, value: Color) -> void:
	if _updating or _session == null: return
	_edit_animatable(part_id, "layer:" + part_id + ".tint", [value.r, value.g, value.b, value.a], Callable(_session.model, "set_layer_tint").bind(part_id, value), 6)


func _set_layer_visibility(part_id: String, value: bool) -> void:
	if _updating or _session == null: return
	_edit_animatable(part_id, "layer:" + part_id + ".visible", value, Callable(_session.model, "set_layer_visibility").bind(part_id, value), 4)


func _set_bone_transform_component(rig_id: String, bone_id: String, component: String, value: float) -> void:
	if _updating or _session == null: return
	var rig: Dictionary = _session.get_rig(rig_id)
	var bone: Dictionary = rig.get("bones", {}).get(bone_id, {}) as Dictionary
	bone = _preview_bone(rig_id, bone_id, bone)
	if bone.is_empty() or bool(bone.get("locked", false)): return
	var position: Vector2 = bone.get("local_position", Vector2.ZERO) as Vector2
	var scale: Vector2 = bone.get("local_scale", Vector2.ONE) as Vector2
	var rotation := rad_to_deg(float(bone.get("local_rotation", 0.0)))
	var verb := "Changed"
	match component:
		"position_x": position.x = value; verb = "Moved"
		"position_y": position.y = value; verb = "Moved"
		"rotation": rotation = value; verb = "Rotated"
		"scale_x": scale.x = value; verb = "Scaled"
		"scale_y": scale.y = value; verb = "Scaled"
	var property_path := "bone:" + bone_id + ".transform"
	var track_type := 6
	var value_for_key: Variant = {"position": [position.x, position.y], "rotation_degrees": rotation, "scale": [scale.x, scale.y]}
	match component:
		"position_x", "position_y": property_path = "bone:" + bone_id + ".position"; track_type = 0; value_for_key = [position.x, position.y]
		"rotation": property_path = "bone:" + bone_id + ".rotation_degrees"; track_type = 1; value_for_key = rotation
		"scale_x", "scale_y": property_path = "bone:" + bone_id + ".scale"; track_type = 2; value_for_key = [scale.x, scale.y]
	_edit_animatable(bone_id, property_path, value_for_key, Callable(_session, "set_rig_bone_transform").bind(rig_id, bone_id, position, rotation, scale, "%s %s Bone" % [verb, str(bone.get("name", bone_id))]), track_type)


func _edit_animatable(object_id: String, property_path: String, value: Variant, rest_pose_edit: Callable, track_type: int) -> void:
	if _preview_controller != null and is_instance_valid(_preview_controller):
		_preview_controller.apply_property_edit(object_id, property_path, value, rest_pose_edit, track_type)
	elif rest_pose_edit.is_valid():
		rest_pose_edit.call()


func _preview_layer_state(part_id: String, fallback: Dictionary) -> Dictionary:
	if _preview_controller == null or not is_instance_valid(_preview_controller): return fallback.duplicate(true)
	var frame: Dictionary = _preview_controller.get_evaluated_frame()
	for raw_layer in frame.get("layers", []):
		var layer: Dictionary = raw_layer
		if str(layer.get("part_id", "")) == part_id:
			return (layer.get("state", fallback) as Dictionary).duplicate(true)
	return fallback.duplicate(true)


func _preview_bone(rig_id: String, bone_id: String, fallback: Dictionary) -> Dictionary:
	if _preview_controller == null or not is_instance_valid(_preview_controller): return fallback.duplicate(true)
	var frame: Dictionary = _preview_controller.get_evaluated_frame()
	var rig: Dictionary = frame.get("rig_pose", {}) as Dictionary
	if str(rig.get("id", "")) != rig_id: return fallback.duplicate(true)
	return (rig.get("bones", {}).get(bone_id, fallback) as Dictionary).duplicate(true)


func _find_layer(part_id: String) -> Dictionary:
	for raw_layer in _session.get_preview_layers():
		var layer: Dictionary = raw_layer
		if str(layer.get("part_id", "")) == part_id: return layer
	return {}


func _add_section(text: String) -> void:
	var label := Label.new()
	label.name = text.replace(" ", "") + "Section"
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	_properties.add_child(label)


func _add_help(text: String) -> void:
	var label := Label.new()
	label.name = "Help"
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_properties.add_child(label)


func _add_readonly(label_text: String, value: String) -> void:
	var label := Label.new()
	label.name = label_text.replace(" ", "")
	label.text = label_text + ": " + value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_properties.add_child(label)


func _add_row(label_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.name = label_text.replace(" ", "") + "Row"
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(92, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	_properties.add_child(row)


func _add_keyed_row(label_text: String, control: Control, object_id: String, property_path: String, value: Variant, track_type: int) -> void:
	var row := HBoxContainer.new()
	row.name = label_text.replace(" ", "") + "KeyedRow"
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(92, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	var diamond := Button.new()
	diamond.name = "Key" + label_text.replace(" ", "")
	diamond.custom_minimum_size = Vector2(30, 0)
	var keyed: Dictionary = _preview_controller.get_keyed_state(object_id, property_path) if _preview_controller != null and is_instance_valid(_preview_controller) else {"keyed": false}
	diamond.text = "◆" if bool(keyed.get("keyed", false)) else "◇"
	diamond.tooltip_text = "Remove key at playhead" if bool(keyed.get("keyed", false)) else "Add key at playhead"
	diamond.disabled = _preview_controller == null or not is_instance_valid(_preview_controller)
	diamond.pressed.connect(func():
		if _preview_controller == null or not is_instance_valid(_preview_controller): return
		_preview_controller.toggle_key(object_id, property_path, value, track_type)
		_refresh())
	row.add_child(diamond)
	_properties.add_child(row)


func _add_keyed_spin(label_text: String, value: float, minimum: float, maximum: float, step: float, object_id: String, property_path: String, key_value: Variant, track_type: int, callback: Callable) -> void:
	var spin := SpinBox.new()
	spin.name = label_text.replace(" ", "")
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.value = value
	spin.value_changed.connect(func(next_value): if not _updating: callback.call(next_value))
	_add_keyed_row(label_text, spin, object_id, property_path, key_value, track_type)


func _add_keyed_color(label_text: String, value: Color, object_id: String, property_path: String, key_value: Variant, track_type: int, callback: Callable) -> void:
	var picker := ColorPickerButton.new()
	picker.name = label_text.replace(" ", "")
	picker.color = value
	picker.color_changed.connect(func(next_value): if not _updating: callback.call(next_value))
	_add_keyed_row(label_text, picker, object_id, property_path, key_value, track_type)


func _add_keyed_toggle(label_text: String, value: bool, object_id: String, property_path: String, key_value: Variant, track_type: int, callback: Callable) -> void:
	var toggle := CheckButton.new()
	toggle.name = label_text.replace(" ", "")
	toggle.text = label_text
	toggle.button_pressed = value
	toggle.toggled.connect(func(next_value): if not _updating: callback.call(next_value))
	_add_keyed_row(label_text, toggle, object_id, property_path, key_value, track_type)


func _add_spin(label_text: String, value: float, minimum: float, maximum: float, step: float, callback: Callable) -> void:
	var spin := SpinBox.new()
	spin.name = label_text.replace(" ", "")
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.value = value
	spin.value_changed.connect(func(next_value): if not _updating: callback.call(next_value))
	_add_row(label_text, spin)


func _add_line(label_text: String, value: String, callback: Callable) -> void:
	var line := LineEdit.new()
	line.name = label_text.replace(" ", "")
	line.text = value
	line.text_submitted.connect(func(next_value): if not _updating: callback.call(next_value))
	line.focus_exited.connect(func(): if not _updating: callback.call(line.text))
	_add_row(label_text, line)


func _add_color(label_text: String, value: Color, callback: Callable) -> void:
	var picker := ColorPickerButton.new()
	picker.name = label_text.replace(" ", "")
	picker.color = value
	picker.color_changed.connect(func(next_value): if not _updating: callback.call(next_value))
	_add_row(label_text, picker)


func _add_toggle(label_text: String, value: bool, callback: Callable) -> void:
	var toggle := CheckButton.new()
	toggle.name = label_text.replace(" ", "")
	toggle.text = label_text
	toggle.button_pressed = value
	toggle.toggled.connect(func(next_value): if not _updating: callback.call(next_value))
	_properties.add_child(toggle)


func _on_session_changed(_description: String) -> void:
	_refresh()


func _on_preview_evaluated(_frame: Dictionary) -> void:
	_refresh()


func _on_selection_changed(_kind: String, _item_id: String, _context: Dictionary) -> void:
	_refresh()


func _set_status(message: String) -> void:
	if _status_label != null: _status_label.text = message
	status_changed.emit(message)
