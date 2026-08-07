# AnimationTimelineEditor -- Project-bound clip, track, keyframe, and playback editor.
class_name AnimationTimelineEditor
extends VBoxContainer

const PlaybackClockScript = preload("res://animation/timeline/playback_clock.gd")
const TimelineTrackCanvasScript = preload("res://animation/timeline/timeline_track_canvas.gd")
const TrackDefinitionScript = preload("res://animation/tracks/track_schema.gd")

signal status_changed(message: String)
signal onion_frames_changed(past_layers: Array, future_layers: Array)

var _session = null
var _selection = null
var _preview_controller = null
var _clock = PlaybackClockScript.new()
var _clip_picker: OptionButton = null
var _play_button: Button = null
var _time_slider: HSlider = null
var _time_label: Label = null
var _track_property_picker: OptionButton = null
var _target_label: Label = null
var _add_key_button: Button = null
var _delete_key_button: Button = null
var _delete_track_button: Button = null
var _canvas: Control = null
var _status_label: Label = null
var _active_track_id := ""
var _active_key_id := ""
var _selected_keys: Array = []
var _key_clipboard: Array = []
var _updating := false
var _snap_to_frames := true
var _onion_skin := false
var _timeline_mode := "dope_sheet"
var _speed_picker: OptionButton = null
var _auto_key_button: CheckButton = null
var _snap_button: CheckButton = null
var _onion_button: CheckButton = null
var _mode_picker: OptionButton = null
var _loop_region_button: CheckButton = null


func _ready() -> void:
	name = "AnimationTimelineEditor"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_clock.time_changed.connect(_on_clock_time_changed)
	_clock.playback_stopped.connect(_on_clock_playback_stopped)
	_build_ui()
	set_process(true)
	_refresh()


func _process(delta: float) -> void:
	if _clock.is_playing:
		_clock.advance(delta)


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
	_refresh_target_label()
	_refresh_canvas_selection()


func bind_preview_controller(controller) -> void:
	if _preview_controller != null and is_instance_valid(_preview_controller) and _preview_controller.auto_key_changed.is_connected(_on_auto_key_changed):
		_preview_controller.auto_key_changed.disconnect(_on_auto_key_changed)
	_preview_controller = controller
	if _preview_controller != null and is_instance_valid(_preview_controller) and not _preview_controller.auto_key_changed.is_connected(_on_auto_key_changed):
		_preview_controller.auto_key_changed.connect(_on_auto_key_changed)
	if _preview_controller != null and is_instance_valid(_preview_controller):
		_preview_controller.set_clip(_session.get_active_animation_id() if _session != null and is_instance_valid(_session) else "")
		if _auto_key_button != null: _auto_key_button.button_pressed = _preview_controller.is_auto_key_enabled()


func get_timeline_canvas() -> Control:
	return _canvas


func _build_ui() -> void:
	var clip_row := HBoxContainer.new()
	clip_row.name = "ClipRow"
	add_child(clip_row)
	var clip_label := Label.new()
	clip_label.text = "Clip"
	clip_row.add_child(clip_label)
	_clip_picker = OptionButton.new()
	_clip_picker.name = "ClipPicker"
	_clip_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clip_picker.item_selected.connect(_on_clip_selected)
	clip_row.add_child(_clip_picker)
	var new_clip := Button.new()
	new_clip.name = "NewClip"
	new_clip.text = "New"
	new_clip.tooltip_text = "Create animation clip"
	new_clip.pressed.connect(_on_new_clip_pressed)
	clip_row.add_child(new_clip)
	var delete_clip := Button.new()
	delete_clip.name = "DeleteClip"
	delete_clip.text = "Delete"
	delete_clip.pressed.connect(_on_delete_clip_pressed)
	clip_row.add_child(delete_clip)
	var playback_row := HFlowContainer.new()
	playback_row.name = "PlaybackRow"
	add_child(playback_row)
	_play_button = Button.new()
	_play_button.name = "PlayPause"
	_play_button.text = "Play"
	_play_button.pressed.connect(_on_play_pause_pressed)
	playback_row.add_child(_play_button)
	var previous_frame := Button.new()
	previous_frame.name = "PreviousFrame"
	previous_frame.text = "◀"
	previous_frame.tooltip_text = "Step one frame backward"
	previous_frame.pressed.connect(func(): _step_frame(-1))
	playback_row.add_child(previous_frame)
	var next_frame := Button.new()
	next_frame.name = "NextFrame"
	next_frame.text = "▶"
	next_frame.tooltip_text = "Step one frame forward"
	next_frame.pressed.connect(func(): _step_frame(1))
	playback_row.add_child(next_frame)
	var stop := Button.new()
	stop.name = "Stop"
	stop.text = "Stop"
	stop.pressed.connect(_on_stop_pressed)
	playback_row.add_child(stop)
	_speed_picker = OptionButton.new()
	_speed_picker.name = "PlaybackSpeed"
	for entry in [["0.25×", 0.25], ["0.5×", 0.5], ["1×", 1.0], ["1.5×", 1.5], ["2×", 2.0]]:
		_speed_picker.add_item(str(entry[0]))
		_speed_picker.set_item_metadata(_speed_picker.item_count - 1, float(entry[1]))
	_speed_picker.select(2)
	_speed_picker.item_selected.connect(func(index): _clock.speed = float(_speed_picker.get_item_metadata(index)))
	playback_row.add_child(_speed_picker)
	_snap_button = CheckButton.new()
	_snap_button.name = "FrameSnap"
	_snap_button.text = "Snap"
	_snap_button.button_pressed = true
	_snap_button.toggled.connect(func(value): _snap_to_frames = value)
	playback_row.add_child(_snap_button)
	_auto_key_button = CheckButton.new()
	_auto_key_button.name = "AutoKey"
	_auto_key_button.text = "Auto Key"
	_auto_key_button.button_pressed = false
	_auto_key_button.toggled.connect(func(value): if _preview_controller != null and is_instance_valid(_preview_controller): _preview_controller.set_auto_key(value))
	playback_row.add_child(_auto_key_button)
	_onion_button = CheckButton.new()
	_onion_button.name = "OnionSkin"
	_onion_button.text = "Onion"
	_onion_button.toggled.connect(_on_onion_toggled)
	playback_row.add_child(_onion_button)
	_loop_region_button = CheckButton.new()
	_loop_region_button.name = "LoopRegion"
	_loop_region_button.text = "Loop Region"
	_loop_region_button.tooltip_text = "Loop the first saved timeline region (or clear the active loop region)"
	_loop_region_button.toggled.connect(_on_loop_region_toggled)
	playback_row.add_child(_loop_region_button)
	_time_slider = HSlider.new()
	_time_slider.name = "Playhead"
	_time_slider.min_value = 0.0
	_time_slider.max_value = 1.0
	_time_slider.step = 0.001
	_time_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_time_slider.value_changed.connect(_on_playhead_changed)
	playback_row.add_child(_time_slider)
	_time_label = Label.new()
	_time_label.name = "TimeLabel"
	_time_label.custom_minimum_size = Vector2(90, 0)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	playback_row.add_child(_time_label)
	var track_row := HFlowContainer.new()
	track_row.name = "TrackActions"
	add_child(track_row)
	_track_property_picker = OptionButton.new()
	_track_property_picker.name = "TrackProperty"
	_add_track_type_menu_item("Transform", "transform", TrackDefinitionScript.TrackType.ATTRIBUTE)
	_add_track_type_menu_item("Position", "position", TrackDefinitionScript.TrackType.TRANSFORM_POSITION)
	_add_track_type_menu_item("Rotation", "rotation_degrees", TrackDefinitionScript.TrackType.TRANSFORM_ROTATION)
	_add_track_type_menu_item("Scale", "scale", TrackDefinitionScript.TrackType.TRANSFORM_SCALE)
	_add_track_type_menu_item("Visibility", "visible", TrackDefinitionScript.TrackType.VISIBILITY)
	_add_track_type_menu_item("Opacity", "opacity", TrackDefinitionScript.TrackType.ATTRIBUTE)
	_add_track_type_menu_item("Tint / Attribute", "attribute", TrackDefinitionScript.TrackType.ATTRIBUTE)
	_add_track_type_menu_item("Image Swap", "image_swap", TrackDefinitionScript.TrackType.IMAGE_SWAP)
	_add_track_type_menu_item("Z Order", "z_order", TrackDefinitionScript.TrackType.Z_ORDER)
	_add_track_type_menu_item("Action Point", "action_point", TrackDefinitionScript.TrackType.ACTION_POINT)
	_add_track_type_menu_item("Hitbox", "hitbox", TrackDefinitionScript.TrackType.HITBOX)
	_add_track_type_menu_item("Hurtbox", "hurtbox", TrackDefinitionScript.TrackType.HURTBOX)
	_add_track_type_menu_item("Event", "event", TrackDefinitionScript.TrackType.EVENT)
	_add_track_type_menu_item("Audio Cue", "audio_cue", TrackDefinitionScript.TrackType.AUDIO_CUE)
	_add_track_type_menu_item("Viseme", "viseme", TrackDefinitionScript.TrackType.VISEME)
	_add_track_type_menu_item("Script Parameter", "script_parameter", TrackDefinitionScript.TrackType.SCRIPT_PARAMETER)
	track_row.add_child(_track_property_picker)
	var add_track := Button.new()
	add_track.name = "AddTrack"
	add_track.text = "Add Track"
	add_track.pressed.connect(_on_add_track_pressed)
	track_row.add_child(add_track)
	_add_key_button = Button.new()
	_add_key_button.name = "AddKey"
	_add_key_button.text = "Add Key"
	_add_key_button.pressed.connect(_on_add_key_pressed)
	track_row.add_child(_add_key_button)
	_delete_key_button = Button.new()
	_delete_key_button.name = "DeleteKey"
	_delete_key_button.text = "Delete Key"
	_delete_key_button.pressed.connect(_on_delete_key_pressed)
	track_row.add_child(_delete_key_button)
	_delete_track_button = Button.new()
	_delete_track_button.name = "DeleteTrack"
	_delete_track_button.text = "Delete Track"
	_delete_track_button.pressed.connect(_on_delete_track_pressed)
	track_row.add_child(_delete_track_button)
	var copy_keys := Button.new()
	copy_keys.name = "CopyKeys"
	copy_keys.text = "Copy"
	copy_keys.pressed.connect(_copy_selected_keys)
	track_row.add_child(copy_keys)
	var paste_keys := Button.new()
	paste_keys.name = "PasteKeys"
	paste_keys.text = "Paste"
	paste_keys.pressed.connect(_paste_selected_keys)
	track_row.add_child(paste_keys)
	var nudge_keys := Button.new()
	nudge_keys.name = "NudgeKeys"
	nudge_keys.text = "Nudge"
	nudge_keys.tooltip_text = "Move selected keys one frame"
	nudge_keys.pressed.connect(func(): _move_selected_keys(1.0))
	track_row.add_child(nudge_keys)
	var scale_keys := Button.new()
	scale_keys.name = "ScaleKeys"
	scale_keys.text = "Scale"
	scale_keys.tooltip_text = "Scale selected-key timing 110% around the playhead"
	scale_keys.pressed.connect(func(): _scale_selected_keys(1.1))
	track_row.add_child(scale_keys)
	var ripple_keys := Button.new()
	ripple_keys.name = "RippleKeys"
	ripple_keys.text = "Ripple"
	ripple_keys.tooltip_text = "Shift selected and following keys one frame"
	ripple_keys.pressed.connect(_ripple_selected_keys)
	track_row.add_child(ripple_keys)
	var marker := Button.new()
	marker.name = "AddMarker"
	marker.text = "Marker"
	marker.pressed.connect(_add_marker)
	track_row.add_child(marker)
	var region := Button.new()
	region.name = "AddRegion"
	region.text = "Region"
	region.pressed.connect(_add_region)
	track_row.add_child(region)
	_mode_picker = OptionButton.new()
	_mode_picker.name = "TimelineMode"
	_mode_picker.add_item("Dope Sheet")
	_mode_picker.set_item_metadata(0, "dope_sheet")
	_mode_picker.add_item("Curve Editor")
	_mode_picker.set_item_metadata(1, "curve_editor")
	_mode_picker.item_selected.connect(_on_mode_selected)
	track_row.add_child(_mode_picker)
	_target_label = Label.new()
	_target_label.name = "TrackTarget"
	_target_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	track_row.add_child(_target_label)
	_canvas = TimelineTrackCanvasScript.new()
	_canvas.name = "TimelineTrackCanvas"
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.scrubbed.connect(func(time): _clock.seek(time))
	_canvas.track_selected.connect(_on_canvas_track_selected)
	_canvas.key_selected.connect(_on_canvas_key_selected)
	_canvas.keys_drag_committed.connect(_on_canvas_keys_drag_committed)
	_canvas.keys_selected.connect(_on_canvas_keys_selected)
	add_child(_canvas)
	_status_label = Label.new()
	_status_label.name = "TimelineStatus"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 12)
	add_child(_status_label)


func _refresh() -> void:
	if _canvas == null: return
	_updating = true
	_clip_picker.clear()
	if _session == null or not is_instance_valid(_session):
		_canvas.call("set_clip", {})
		_set_status("Open a project to create animation clips and keyframes.")
		_update_controls({})
		_updating = false
		return
	var clips: Array = _session.get_animation_clips()
	var active_id: String = _session.get_active_animation_id()
	if active_id.is_empty() and not clips.is_empty():
		active_id = str((clips[0] as Dictionary).get("clip_id", ""))
		_session.set_active_animation_id(active_id)
	for clip in clips:
		var data: Dictionary = clip
		_clip_picker.add_item(str(data.get("clip_name", data.get("clip_id", "Animation"))))
		_clip_picker.set_item_metadata(_clip_picker.item_count - 1, str(data.get("clip_id", "")))
	for index in range(_clip_picker.item_count):
		if str(_clip_picker.get_item_metadata(index)) == active_id:
			_clip_picker.select(index)
			break
	var active_clip: Dictionary = _session.get_animation_clip(active_id)
	_clock.duration = maxf(0.01, float(active_clip.get("duration", 1.0)))
	_clock.loop_mode = clampi(int(active_clip.get("loop_mode", 0)), 0, 2)
	_clock.loop_start = 0.0
	_clock.loop_end = _clock.duration
	if not (active_clip.get("regions", []) as Array).is_empty() and bool(active_clip.get("loop_region_enabled", false)):
		var loop_region: Dictionary = _get_loop_region(active_clip)
		_clock.loop_start = float(loop_region.get("start_time", 0.0))
		_clock.loop_end = float(loop_region.get("end_time", _clock.duration))
	if _loop_region_button != null:
		_loop_region_button.set_pressed_no_signal(bool(active_clip.get("loop_region_enabled", false)))
	_clock.seek(minf(_clock.current_time, _clock.duration))
	_canvas.call("set_clip", active_clip)
	_canvas.call("set_mode", _timeline_mode)
	if _preview_controller != null and is_instance_valid(_preview_controller):
		_preview_controller.set_clip(active_id)
		_preview_controller.set_time(_clock.current_time, _clock.is_playing)
	_update_controls(active_clip)
	_refresh_target_label()
	_refresh_canvas_selection()
	_set_status("Create a track for the selected layer or bone, then add keyframes at the playhead." if active_clip.is_empty() else "%d track%s · %s" % [(active_clip.get("tracks", []) as Array).size(), "s" if (active_clip.get("tracks", []) as Array).size() != 1 else "", str(active_clip.get("clip_name", "Animation"))])
	_updating = false


func _update_controls(clip: Dictionary) -> void:
	var has_clip := not clip.is_empty()
	_clip_picker.disabled = not has_clip and (_session == null or not is_instance_valid(_session))
	_play_button.disabled = not has_clip
	_time_slider.editable = has_clip
	_time_slider.max_value = maxf(0.01, float(clip.get("duration", 1.0)))
	_add_key_button.disabled = not has_clip or _active_track_id.is_empty()
	_delete_key_button.disabled = not has_clip or _active_track_id.is_empty() or _active_key_id.is_empty()
	_delete_track_button.disabled = _active_track_id.is_empty()
	if not has_clip:
		_active_track_id = ""
		_active_key_id = ""


func _refresh_target_label() -> void:
	if _target_label == null: return
	if _selection == null or not is_instance_valid(_selection):
		_target_label.text = "Select a layer or bone to add a track"
		return
	var kind: String = _selection.get_kind()
	if kind == "layer" or kind == "bone":
		_target_label.text = "Target: " + kind.capitalize() + " " + _selection.get_item_id()
	else:
		_target_label.text = "Select a layer or bone to add a track"


func _refresh_canvas_selection() -> void:
	if _canvas == null: return
	if _selection != null and is_instance_valid(_selection):
		var kind: String = _selection.get_kind()
		var context: Dictionary = _selection.get_context()
		if kind == "animation_key":
			_active_track_id = str(context.get("track_id", ""))
			_active_key_id = _selection.get_item_id()
			_canvas.call("set_selection", str(context.get("track_id", "")), _selection.get_item_id())
			return
		if kind == "animation_track":
			_active_track_id = _selection.get_item_id()
			_active_key_id = ""
			_canvas.call("set_selection", _selection.get_item_id(), "")
			return
	_canvas.call("set_selection", _active_track_id, "")


func _on_session_changed(_description: String) -> void:
	_refresh()


func _on_selection_changed(kind: String, item_id: String, context: Dictionary) -> void:
	if kind == "animation_track":
		_active_track_id = item_id
		_active_key_id = ""
	elif kind == "animation_key":
		_active_track_id = str(context.get("track_id", ""))
		_active_key_id = item_id
	_refresh_target_label()
	_refresh_canvas_selection()
	_update_controls(_session.get_active_animation_clip() if _session != null and is_instance_valid(_session) else {})


func _on_clip_selected(index: int) -> void:
	if _updating or _session == null or index < 0: return
	var clip_id := str(_clip_picker.get_item_metadata(index))
	_active_track_id = ""
	_active_key_id = ""
	if _session.set_active_animation_id(clip_id) and _selection != null and is_instance_valid(_selection):
		_selection.select("animation_clip", clip_id, {"source": "timeline"})
	if _preview_controller != null and is_instance_valid(_preview_controller): _preview_controller.set_clip(clip_id)


func _on_new_clip_pressed() -> void:
	if _session == null: return
	var report: Dictionary = _session.create_animation_clip("New Animation")
	if report.get("success", false):
		if _selection != null and is_instance_valid(_selection): _selection.select("animation_clip", str(report.get("clip_id", "")), {"source": "timeline"})
	else:
		_set_status(str(report.get("errors", ["Could not create animation."])[0]))


func _on_delete_clip_pressed() -> void:
	if _session == null: return
	var clip_id: String = _session.get_active_animation_id()
	if _session.delete_animation_clip(clip_id) and _selection != null and is_instance_valid(_selection): _selection.clear()


func _on_play_pause_pressed() -> void:
	if _clock.is_playing: _clock.pause()
	else: _clock.play()
	_play_button.text = "Pause" if _clock.is_playing else "Play"
	if _preview_controller != null and is_instance_valid(_preview_controller): _preview_controller.set_time(_clock.current_time, _clock.is_playing)


func _on_stop_pressed() -> void:
	_clock.stop()
	if _preview_controller != null and is_instance_valid(_preview_controller): _preview_controller.stop_preview()
	if _play_button != null: _play_button.text = "Play"


func _on_playhead_changed(value: float) -> void:
	if not _updating: _clock.seek(value)


func _on_clock_time_changed(time: float) -> void:
	if _time_slider == null: return
	_updating = true
	_time_slider.value = time
	_time_label.text = "%.3f / %.3f" % [time, _clock.duration]
	if _canvas != null: _canvas.call("set_playhead", time)
	_updating = false
	if not _clock.is_playing and _play_button != null: _play_button.text = "Play"
	if _preview_controller != null and is_instance_valid(_preview_controller):
		_preview_controller.set_time(time, _clock.is_playing)
	_update_onion_skin()


func _on_clock_playback_stopped() -> void:
	# Let the final time-change publish first, then clear preview overrides so
	# the stopped canvas and Inspector return to the document rest pose.
	if _preview_controller != null and is_instance_valid(_preview_controller):
		_preview_controller.call_deferred("stop_preview")


func _on_add_track_pressed() -> void:
	if _session == null or _selection == null or not is_instance_valid(_selection): return
	var target := _track_target_for_selection()
	if target.is_empty():
		_set_status("Select a layer in Canvas or a bone in Hierarchy before adding a track.")
		return
	var clip_id: String = _session.get_active_animation_id()
	if clip_id.is_empty():
		_set_status("Create an animation clip before adding tracks.")
		return
	var metadata: Dictionary = _track_property_picker.get_item_metadata(_track_property_picker.selected) as Dictionary
	var property := str(metadata.get("property", "attribute"))
	var track_type := int(metadata.get("track_type", TrackDefinitionScript.TrackType.ATTRIBUTE))
	var report: Dictionary = _session.add_animation_track(clip_id, str(target.get("object_id", "")), str(target.get("prefix", "")) + "." + property, str(target.get("label", "")) + " " + _track_property_picker.get_item_text(_track_property_picker.selected), track_type)
	if report.get("success", false):
		_active_track_id = str(report.get("track_id", ""))
		_active_key_id = ""
		if _selection != null and is_instance_valid(_selection): _selection.select("animation_track", _active_track_id, {"clip_id": clip_id, "source": "timeline"})
	else:
		_set_status(str(report.get("errors", ["Could not add track."])[0]))


func _on_add_key_pressed() -> void:
	if _session == null or _active_track_id.is_empty(): return
	var clip_id: String = _session.get_active_animation_id()
	var track: Dictionary = _session.get_animation_track(clip_id, _active_track_id)
	var report: Dictionary = _session.add_animation_key(clip_id, _active_track_id, _clock.current_time, _default_key_value(track))
	if report.get("success", false) and _selection != null and is_instance_valid(_selection):
		_active_key_id = str(report.get("key_id", ""))
		_selection.select("animation_key", str(report.get("key_id", "")), {"clip_id": clip_id, "track_id": _active_track_id, "source": "timeline"})
	elif not report.get("success", false):
		_set_status(str(report.get("errors", ["Could not add keyframe."])[0]))


func _on_delete_key_pressed() -> void:
	if _session == null or _active_track_id.is_empty() or _active_key_id.is_empty(): return
	var clip_id: String = _session.get_active_animation_id()
	if _session.delete_animation_key(clip_id, _active_track_id, _active_key_id):
		_active_key_id = ""
		if _selection != null and is_instance_valid(_selection):
			_selection.select("animation_track", _active_track_id, {"clip_id": clip_id, "source": "timeline"})


func _on_delete_track_pressed() -> void:
	if _session == null or _active_track_id.is_empty(): return
	var clip_id: String = _session.get_active_animation_id()
	if _session.delete_animation_track(clip_id, _active_track_id):
		_active_track_id = ""
		_active_key_id = ""
		if _selection != null and is_instance_valid(_selection): _selection.select("animation_clip", clip_id, {"source": "timeline"})


func _on_canvas_track_selected(track_id: String) -> void:
	_active_track_id = track_id
	_active_key_id = ""
	if _selection != null and is_instance_valid(_selection):
		_selection.select("animation_track", track_id, {"clip_id": _session.get_active_animation_id() if _session != null else "", "source": "timeline"})


func _on_canvas_key_selected(track_id: String, key_id: String) -> void:
	_active_track_id = track_id
	_active_key_id = key_id
	if _selection != null and is_instance_valid(_selection):
		_selection.select("animation_key", key_id, {"clip_id": _session.get_active_animation_id() if _session != null else "", "track_id": track_id, "source": "timeline"})


func _on_canvas_keys_drag_committed(selected_keys: Array, _anchor_track_id: String, _anchor_key_id: String, origin_time: float, target_time: float) -> void:
	if _session == null or selected_keys.is_empty(): return
	var snapped_origin := _snap_time(origin_time)
	var snapped_target := _snap_time(target_time)
	var delta := snapped_target - snapped_origin
	if absf(delta) <= 0.0001: return
	var clip_id: String = _session.get_active_animation_id()
	var edits: Array = []
	for raw_selected in selected_keys:
		var selected: Dictionary = raw_selected
		var track_id := str(selected.get("track_id", ""))
		var key_id := str(selected.get("key_id", ""))
		var track: Dictionary = _session.get_animation_track(clip_id, track_id)
		for raw_key in track.get("keys", []):
			var key: Dictionary = raw_key
			if str(key.get("key_id", "")) == key_id:
				edits.append({"track_id": track_id, "key_id": key_id, "time": _snap_time(float(key.get("time", 0.0)) + delta)})
				break
	if edits.is_empty(): return
	var description := "Moved Selected Keyframes" if edits.size() > 1 else "Moved Keyframe"
	var report: Dictionary = _session.edit_animation_keys_batch(clip_id, edits, description)
	if report.get("success", false):
		_clock.seek(snapped_target)
		_set_status("Moved %d keyframe%s." % [int(report.get("changed", 0)), "s" if int(report.get("changed", 0)) != 1 else ""])


func _track_target_for_selection() -> Dictionary:
	if _selection == null or not is_instance_valid(_selection): return {}
	var kind: String = _selection.get_kind()
	var item_id: String = _selection.get_item_id()
	if kind == "layer":
		return {"object_id": item_id, "prefix": "layer:" + item_id, "label": "Layer"}
	if kind == "bone":
		return {"object_id": item_id, "prefix": "bone:" + item_id, "label": "Bone"}
	return {}


func _default_key_value(track: Dictionary) -> Variant:
	if _session == null: return 0.0
	var object_id := str(track.get("object_id", ""))
	var path := str(track.get("property_path", ""))
	var kind := int(track.get("track_type", TrackDefinitionScript.TrackType.ATTRIBUTE))
	if kind == TrackDefinitionScript.TrackType.IMAGE_SWAP:
		var part = _session.part_registry.get_part(object_id)
		return part.asset_id if part != null else ""
	if kind == TrackDefinitionScript.TrackType.Z_ORDER:
		return _session.model.get_layer_ids_in_order().find(object_id) if _session.model != null else 0
	if kind == TrackDefinitionScript.TrackType.ACTION_POINT:
		return {"action_point_id": "point", "display_name": "Action Point", "local_position": [0.0, 0.0], "local_rotation": 0.0}
	if kind == TrackDefinitionScript.TrackType.HITBOX or kind == TrackDefinitionScript.TrackType.HURTBOX:
		return []
	if kind == TrackDefinitionScript.TrackType.EVENT:
		return {"event_id": "event", "event_name": "Event", "event_type": "notify", "payload": {}}
	if kind == TrackDefinitionScript.TrackType.AUDIO_CUE:
		var audio_id := ""
		for asset in _session.asset_registry.list_assets("audio"):
			audio_id = str((asset as Dictionary).get("asset_id", ""))
			break
		return {"cue_id": "cue", "audio_asset_id": audio_id, "volume_db": 0.0, "pan": 0.0}
	if kind == TrackDefinitionScript.TrackType.VISEME:
		return {"viseme_id": "neutral", "mouth_attachment_id": object_id, "asset_id": ""}
	if kind == TrackDefinitionScript.TrackType.SCRIPT_PARAMETER:
		return 0.0
	if path.begins_with("layer:") and _session.model != null:
		var state: Dictionary = _session.model.get_layer_state(object_id)
		if path.ends_with(".visible"): return bool(state.get("visible", true))
		if path.ends_with(".opacity"): return float(state.get("opacity", 1.0))
		return {"position": state.get("position", [0.0, 0.0]), "rotation_degrees": state.get("rotation_degrees", 0.0), "scale": state.get("scale", [1.0, 1.0])}
	if path.begins_with("bone:"):
		var rig: Dictionary = _session.get_active_rig()
		var bone: Dictionary = rig.get("bones", {}).get(object_id, {}) as Dictionary
		if path.ends_with(".visible"): return bool(bone.get("visible", true))
		return {"position": bone.get("local_position", Vector2.ZERO), "rotation_degrees": rad_to_deg(float(bone.get("local_rotation", 0.0))), "scale": bone.get("local_scale", Vector2.ONE)}
	return 0.0


func _add_track_type_menu_item(label: String, property_name: String, track_type: int) -> void:
	_track_property_picker.add_item(label)
	_track_property_picker.set_item_metadata(_track_property_picker.item_count - 1, {"property": property_name, "track_type": track_type})


func _step_frame(direction: int) -> void:
	var clip: Dictionary = _session.get_active_animation_clip() if _session != null and is_instance_valid(_session) else {}
	var fps := maxf(1.0, float(clip.get("fps", 24.0)))
	_clock.pause()
	_clock.seek(_snap_time(_clock.current_time + float(direction) / fps))


func _snap_time(time: float) -> float:
	if not _snap_to_frames: return clampf(time, 0.0, _clock.duration)
	var clip: Dictionary = _session.get_active_animation_clip() if _session != null and is_instance_valid(_session) else {}
	var fps := maxf(1.0, float(clip.get("fps", 24.0)))
	return clampf(round(time * fps) / fps, 0.0, _clock.duration)


func _on_auto_key_changed(enabled: bool) -> void:
	if _auto_key_button != null and _auto_key_button.button_pressed != enabled: _auto_key_button.button_pressed = enabled


func _on_onion_toggled(enabled: bool) -> void:
	_onion_skin = enabled
	_update_onion_skin()


func _on_loop_region_toggled(enabled: bool) -> void:
	if _updating or _session == null or not is_instance_valid(_session): return
	var clip: Dictionary = _session.get_active_animation_clip()
	if clip.is_empty(): return
	var regions: Array = clip.get("regions", [])
	if enabled and regions.is_empty():
		_set_status("Add a timeline region before enabling region looping.")
		_loop_region_button.set_pressed_no_signal(false)
		return
	var region_id: String = str((regions[0] as Dictionary).get("region_id", "")) if enabled else ""
	if not _session.set_animation_loop_region(str(clip.get("clip_id", "")), region_id):
		_loop_region_button.set_pressed_no_signal(not enabled)


func _get_loop_region(clip: Dictionary) -> Dictionary:
	var wanted: String = str(clip.get("loop_region_id", ""))
	for raw_region in clip.get("regions", []):
		var region: Dictionary = raw_region
		if wanted.is_empty() or str(region.get("region_id", "")) == wanted:
			return region
	return {}


func _on_mode_selected(index: int) -> void:
	_timeline_mode = str(_mode_picker.get_item_metadata(index))
	if _canvas != null: _canvas.call("set_mode", _timeline_mode)
	_set_status("Curve Editor shows numeric key tangents." if _timeline_mode == "curve_editor" else "Dope Sheet mode.")


func _update_onion_skin() -> void:
	if not _onion_skin or _session == null or not is_instance_valid(_session):
		onion_frames_changed.emit([], [])
		return
	var clip: Dictionary = _session.get_active_animation_clip()
	if clip.is_empty():
		onion_frames_changed.emit([], [])
		return
	var evaluator: RefCounted = preload("res://animation/preview/animation_preview_evaluator.gd").new()
	var fps := maxf(1.0, float(clip.get("fps", 24.0)))
	var step := 1.0 / fps
	var past: Dictionary = evaluator.evaluate(_session, clip, maxf(0.0, _clock.current_time - step))
	var future: Dictionary = evaluator.evaluate(_session, clip, minf(float(clip.get("duration", 1.0)), _clock.current_time + step))
	onion_frames_changed.emit(past.get("layers", []), future.get("layers", []))


func _on_canvas_keys_selected(keys: Array) -> void:
	_selected_keys = keys.duplicate(true)
	if not _selected_keys.is_empty():
		var latest: Dictionary = _selected_keys[_selected_keys.size() - 1]
		_on_canvas_key_selected(str(latest.get("track_id", "")), str(latest.get("key_id", "")))


func _copy_selected_keys() -> void:
	if _session == null: return
	var clip: Dictionary = _session.get_active_animation_clip()
	var selected: Array = _selected_keys.duplicate(true)
	if selected.is_empty() and not _active_track_id.is_empty() and not _active_key_id.is_empty(): selected = [{"track_id": _active_track_id, "key_id": _active_key_id}]
	var copied: Array = []
	var origin: float = INF
	for selection in selected:
		var track_id := str((selection as Dictionary).get("track_id", ""))
		var key_id := str((selection as Dictionary).get("key_id", ""))
		for raw_track in clip.get("tracks", []):
			var track: Dictionary = raw_track
			if str(track.get("track_id", "")) != track_id: continue
			for raw_key in track.get("keys", []):
				var key: Dictionary = raw_key
				if str(key.get("key_id", "")) != key_id: continue
				origin = minf(origin, float(key.get("time", 0.0)))
				copied.append({"track_id": track_id, "key": key.duplicate(true)})
	for entry in copied:
		(entry as Dictionary)["offset"] = float(((entry as Dictionary).get("key", {}) as Dictionary).get("time", 0.0)) - origin
	_key_clipboard = copied
	_set_status("Copied %d key%s." % [copied.size(), "s" if copied.size() != 1 else ""])


func _paste_selected_keys() -> void:
	if _session == null or _key_clipboard.is_empty(): return
	var report: Dictionary = _session.paste_animation_keys(_session.get_active_animation_id(), _key_clipboard, _clock.current_time)
	_set_status("Pasted %d key%s." % [int(report.get("pasted", 0)), "s" if int(report.get("pasted", 0)) != 1 else ""] if report.get("success", false) else str(report.get("errors", ["Could not paste keys."])[0]))


func _move_selected_keys(frame_count: float) -> void:
	if _session == null or _selected_keys.is_empty(): return
	var fps := maxf(1.0, float(_session.get_active_animation_clip().get("fps", 24.0)))
	var edits: Array = []
	for selection in _selected_keys:
		var item: Dictionary = selection
		var track: Dictionary = _session.get_animation_track(_session.get_active_animation_id(), str(item.get("track_id", "")))
		for raw_key in track.get("keys", []):
			var key: Dictionary = raw_key
			if str(key.get("key_id", "")) == str(item.get("key_id", "")): edits.append({"track_id": item.get("track_id", ""), "key_id": item.get("key_id", ""), "time": _snap_time(float(key.get("time", 0.0)) + frame_count / fps)})
	_session.edit_animation_keys_batch(_session.get_active_animation_id(), edits, "Moved Selected Keyframes")


func _scale_selected_keys(factor: float) -> void:
	if _session == null or _selected_keys.is_empty(): return
	var edits: Array = []
	for selection in _selected_keys:
		var item: Dictionary = selection
		var track: Dictionary = _session.get_animation_track(_session.get_active_animation_id(), str(item.get("track_id", "")))
		for raw_key in track.get("keys", []):
			var key: Dictionary = raw_key
			if str(key.get("key_id", "")) == str(item.get("key_id", "")): edits.append({"track_id": item.get("track_id", ""), "key_id": item.get("key_id", ""), "time": _snap_time(_clock.current_time + (float(key.get("time", 0.0)) - _clock.current_time) * factor)})
	_session.edit_animation_keys_batch(_session.get_active_animation_id(), edits, "Scaled Selected Keyframes")


func _ripple_selected_keys() -> void:
	if _session == null: return
	var clip: Dictionary = _session.get_active_animation_clip()
	var fps := maxf(1.0, float(clip.get("fps", 24.0)))
	var threshold: float = _clock.current_time
	if not _selected_keys.is_empty():
		threshold = INF
		for selection in _selected_keys:
			var track: Dictionary = _session.get_animation_track(_session.get_active_animation_id(), str((selection as Dictionary).get("track_id", "")))
			for raw_key in track.get("keys", []):
				if str((raw_key as Dictionary).get("key_id", "")) == str((selection as Dictionary).get("key_id", "")): threshold = minf(threshold, float((raw_key as Dictionary).get("time", 0.0)))
	var edits: Array = []
	for raw_track in clip.get("tracks", []):
		var track: Dictionary = raw_track
		for raw_key in track.get("keys", []):
			var key: Dictionary = raw_key
			if float(key.get("time", 0.0)) >= threshold: edits.append({"track_id": str(track.get("track_id", "")), "key_id": str(key.get("key_id", "")), "time": _snap_time(float(key.get("time", 0.0)) + 1.0 / fps)})
	_session.edit_animation_keys_batch(_session.get_active_animation_id(), edits, "Rippled Keyframes")


func _add_marker() -> void:
	if _session == null: return
	_session.add_animation_marker(_session.get_active_animation_id(), "Marker", _clock.current_time)


func _add_region() -> void:
	if _session == null: return
	var fps := maxf(1.0, float(_session.get_active_animation_clip().get("fps", 24.0)))
	_session.add_animation_region(_session.get_active_animation_id(), "Region", _clock.current_time, minf(_clock.duration, _clock.current_time + 12.0 / fps))


func _set_status(message: String) -> void:
	if _status_label != null: _status_label.text = message
	status_changed.emit(message)
