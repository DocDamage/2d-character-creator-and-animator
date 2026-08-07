# TimelineTrackCanvas -- Draws a compact dope sheet and exposes scrubbing/key drag interactions.
class_name TimelineTrackCanvas
extends Control

signal scrubbed(time: float)
signal track_selected(track_id: String)
signal key_selected(track_id: String, key_id: String)
signal key_dragged(track_id: String, key_id: String, time: float)
## Emitted once when a key drag is released.  The editor can turn the entire
## selected-key move into one document-history command instead of recording a
## command for every mouse-motion event.
signal keys_drag_committed(selected_keys: Array, anchor_track_id: String, anchor_key_id: String, origin_time: float, target_time: float)
signal keys_selected(keys: Array)

const LABEL_WIDTH := 158.0
const RULER_HEIGHT := 28.0
const ROW_HEIGHT := 30.0
const KEY_RADIUS := 6.0

var _clip: Dictionary = {}
var _playhead := 0.0
var _selected_track_id := ""
var _selected_key_id := ""
var _selected_keys: Array = []
var _drag_track_id := ""
var _drag_key_id := ""
var _drag_origin_time := 0.0
var _drag_preview_time := 0.0
var _is_box_selecting := false
var _box_start := Vector2.ZERO
var _box_rect := Rect2()
var _mode := "dope_sheet"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	queue_redraw()


func set_clip(clip: Dictionary) -> void:
	_clip = clip.duplicate(true)
	_drag_track_id = ""
	_drag_key_id = ""
	# The bottom dock owns height. Avoid inflating every workspace merely because a
	# hidden timeline tab has many tracks; additional rows are clipped until opened.
	custom_minimum_size.y = 0.0
	queue_redraw()


func set_playhead(time: float) -> void:
	_playhead = clampf(time, 0.0, _duration())
	queue_redraw()


func set_selection(track_id: String, key_id: String = "") -> void:
	_selected_track_id = track_id
	_selected_key_id = key_id
	_selected_keys = [{"track_id": track_id, "key_id": key_id}] if not key_id.is_empty() else []
	queue_redraw()


func set_mode(mode: String) -> void:
	_mode = mode
	queue_redraw()


func get_time_at_position(position: Vector2) -> float:
	var width := maxf(1.0, size.x - LABEL_WIDTH)
	return clampf((position.x - LABEL_WIDTH) / width, 0.0, 1.0) * _duration()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var track_index := _track_index_at(event.position.y)
			if track_index < 0:
				scrubbed.emit(get_time_at_position(event.position))
				accept_event()
				return
			var tracks: Array = _clip.get("tracks", [])
			var track: Dictionary = tracks[track_index]
			var track_id := str(track.get("track_id", ""))
			track_selected.emit(track_id)
			var key_id := _key_at_position(track, event.position)
			if not key_id.is_empty():
				_selected_track_id = track_id
				_selected_key_id = key_id
				if event.shift_pressed:
					var already := false
					for entry in _selected_keys:
						if str((entry as Dictionary).get("track_id", "")) == track_id and str((entry as Dictionary).get("key_id", "")) == key_id: already = true
					if not already: _selected_keys.append({"track_id": track_id, "key_id": key_id})
				else:
					_selected_keys = [{"track_id": track_id, "key_id": key_id}]
				_drag_track_id = track_id
				_drag_key_id = key_id
				_drag_origin_time = _key_time(track, key_id)
				_drag_preview_time = _drag_origin_time
				key_selected.emit(track_id, key_id)
				keys_selected.emit(_selected_keys.duplicate(true))
			elif event.shift_pressed:
				_is_box_selecting = true
				_box_start = event.position
				_box_rect = Rect2(event.position, Vector2.ZERO)
			else:
				scrubbed.emit(get_time_at_position(event.position))
			queue_redraw()
			accept_event()
		else:
			if not _drag_key_id.is_empty():
				keys_drag_committed.emit(_selected_keys.duplicate(true), _drag_track_id, _drag_key_id, _drag_origin_time, _drag_preview_time)
			_drag_track_id = ""
			_drag_key_id = ""
			_drag_origin_time = 0.0
			_drag_preview_time = 0.0
			if _is_box_selecting:
				_is_box_selecting = false
				_select_keys_in_box()
				_box_rect = Rect2()
				queue_redraw()
	elif event is InputEventMouseMotion and not _drag_key_id.is_empty() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_drag_preview_time = get_time_at_position(event.position)
		# Retain the lightweight legacy signal for integrations that only need a
		# live cursor, but defer the document mutation until mouse release.
		key_dragged.emit(_drag_track_id, _drag_key_id, _drag_preview_time)
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and _is_box_selecting and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_box_rect = Rect2(_box_start, event.position - _box_start).abs()
		queue_redraw()
		accept_event()


func _draw() -> void:
	var background := _theme_color("bg_panel", Color("151820"))
	var border := _theme_color("border", Color("343b4a"))
	var secondary := _theme_color("text_secondary", Color("8e98aa"))
	var primary := _theme_color("text_primary", Color("dbe6f5"))
	var blue := _theme_color("blue", Color("5ebcff"))
	draw_rect(Rect2(Vector2.ZERO, size), background)
	draw_rect(Rect2(Vector2.ZERO, size), border, false, 1.0)
	if _clip.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(16, 40), "Create an animation clip to add tracks and keyframes.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, secondary)
		return
	var duration := _duration()
	var track_area := Rect2(LABEL_WIDTH, 0, maxf(1.0, size.x - LABEL_WIDTH), size.y)
	draw_rect(Rect2(0, 0, LABEL_WIDTH, size.y), Color(border, 0.16))
	draw_line(Vector2(LABEL_WIDTH, 0), Vector2(LABEL_WIDTH, size.y), border, 1.0)
	_draw_ruler(track_area, duration, secondary, border)
	_draw_regions(track_area, duration, border)
	var tracks: Array = _clip.get("tracks", [])
	for index in range(tracks.size()):
		_draw_track_row(index, tracks[index] as Dictionary, track_area, duration, primary, secondary, border, blue)
	var playhead_x := _time_to_x(_playhead, duration)
	draw_line(Vector2(playhead_x, 0), Vector2(playhead_x, size.y), blue, 2.0)
	if _is_box_selecting: draw_rect(_box_rect, Color(blue, 0.12), true); draw_rect(_box_rect, blue, false, 1.0)


func _draw_ruler(track_area: Rect2, duration: float, text_color: Color, border: Color) -> void:
	draw_rect(Rect2(track_area.position, Vector2(track_area.size.x, RULER_HEIGHT)), Color(border, 0.12))
	var ticks := clampi(int(track_area.size.x / 90.0), 2, 12)
	for index in range(ticks + 1):
		var fraction := float(index) / float(ticks)
		var x := track_area.position.x + track_area.size.x * fraction
		draw_line(Vector2(x, RULER_HEIGHT - 7), Vector2(x, RULER_HEIGHT), border, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(x + 3, 16), "%.2fs" % (duration * fraction), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, text_color)
	for raw_marker in _clip.get("markers", []):
		var marker: Dictionary = raw_marker
		var x := _time_to_x(float(marker.get("time", 0.0)), duration)
		draw_line(Vector2(x, 1), Vector2(x, RULER_HEIGHT), Color("ffd166"), 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(x + 3, RULER_HEIGHT - 10), str(marker.get("name", "Marker")), HORIZONTAL_ALIGNMENT_LEFT, 80, 10, Color("ffd166"))


func _draw_regions(track_area: Rect2, duration: float, border: Color) -> void:
	for raw_region in _clip.get("regions", []):
		var region: Dictionary = raw_region
		var start_x := _time_to_x(float(region.get("start_time", 0.0)), duration)
		var end_x := _time_to_x(float(region.get("end_time", 0.0)), duration)
		var color := Color("5ebcff")
		color.a = 0.11
		draw_rect(Rect2(start_x, RULER_HEIGHT, maxf(1.0, end_x - start_x), maxf(1.0, size.y - RULER_HEIGHT)), color)
		draw_line(Vector2(start_x, RULER_HEIGHT), Vector2(start_x, size.y), border, 1.0)
		draw_line(Vector2(end_x, RULER_HEIGHT), Vector2(end_x, size.y), border, 1.0)


func _draw_track_row(index: int, track: Dictionary, track_area: Rect2, duration: float, primary: Color, secondary: Color, border: Color, blue: Color) -> void:
	var y := RULER_HEIGHT + float(index) * ROW_HEIGHT
	var row_rect := Rect2(0, y, size.x, ROW_HEIGHT)
	var track_id := str(track.get("track_id", ""))
	if track_id == _selected_track_id:
		var selected := blue
		selected.a = 0.13
		draw_rect(row_rect, selected)
	draw_line(Vector2(0, y + ROW_HEIGHT), Vector2(size.x, y + ROW_HEIGHT), border, 1.0)
	var label := str(track.get("display_name", track.get("property_path", track_id)))
	if bool(track.get("locked", false)): label += "  🔒"
	elif bool(track.get("muted", false)): label += "  muted"
	draw_string(ThemeDB.fallback_font, Vector2(10, y + 20), label, HORIZONTAL_ALIGNMENT_LEFT, LABEL_WIDTH - 16, 12, primary)
	for raw_key in track.get("keys", []):
		var key: Dictionary = raw_key
		var x := _time_to_x(_display_key_time(track_id, key), duration)
		var center := Vector2(x, y + ROW_HEIGHT * 0.5)
		var selected := str(key.get("key_id", "")) == _selected_key_id and track_id == _selected_track_id
		for entry in _selected_keys:
			if str((entry as Dictionary).get("track_id", "")) == track_id and str((entry as Dictionary).get("key_id", "")) == str(key.get("key_id", "")): selected = true
		var color := blue if selected else secondary
		var diamond := PackedVector2Array([center + Vector2(0, -KEY_RADIUS), center + Vector2(KEY_RADIUS, 0), center + Vector2(0, KEY_RADIUS), center + Vector2(-KEY_RADIUS, 0)])
		draw_colored_polygon(diamond, color)
	if _mode == "curve_editor": _draw_numeric_curve(track, y, duration, blue)


func _track_index_at(y: float) -> int:
	if y < RULER_HEIGHT: return -1
	var index := int(floor((y - RULER_HEIGHT) / ROW_HEIGHT))
	return index if index >= 0 and index < (_clip.get("tracks", []) as Array).size() else -1


func _key_at_position(track: Dictionary, position: Vector2) -> String:
	var row_index := (_clip.get("tracks", []) as Array).find(track)
	if row_index < 0: return ""
	var center_y := RULER_HEIGHT + float(row_index) * ROW_HEIGHT + ROW_HEIGHT * 0.5
	for raw_key in track.get("keys", []):
		var key: Dictionary = raw_key
		var center := Vector2(_time_to_x(float(key.get("time", 0.0)), _duration()), center_y)
		if center.distance_to(position) <= KEY_RADIUS + 3.0: return str(key.get("key_id", ""))
	return ""


func _key_time(track: Dictionary, key_id: String) -> float:
	for raw_key in track.get("keys", []):
		var key: Dictionary = raw_key
		if str(key.get("key_id", "")) == key_id:
			return float(key.get("time", 0.0))
	return 0.0


func _display_key_time(track_id: String, key: Dictionary) -> float:
	if _drag_key_id.is_empty(): return float(key.get("time", 0.0))
	var key_id := str(key.get("key_id", ""))
	for raw_selected in _selected_keys:
		var selected: Dictionary = raw_selected
		if str(selected.get("track_id", "")) == track_id and str(selected.get("key_id", "")) == key_id:
			return clampf(float(key.get("time", 0.0)) + (_drag_preview_time - _drag_origin_time), 0.0, _duration())
	return float(key.get("time", 0.0))


func _select_keys_in_box() -> void:
	_selected_keys.clear()
	var tracks: Array = _clip.get("tracks", [])
	for track_index in range(tracks.size()):
		var track: Dictionary = tracks[track_index]
		var center_y := RULER_HEIGHT + float(track_index) * ROW_HEIGHT + ROW_HEIGHT * 0.5
		for raw_key in track.get("keys", []):
			var key: Dictionary = raw_key
			var center := Vector2(_time_to_x(float(key.get("time", 0.0)), _duration()), center_y)
			if _box_rect.has_point(center): _selected_keys.append({"track_id": str(track.get("track_id", "")), "key_id": str(key.get("key_id", ""))})
	keys_selected.emit(_selected_keys.duplicate(true))


func _draw_numeric_curve(track: Dictionary, y: float, duration: float, color: Color) -> void:
	var points := PackedVector2Array()
	for raw_key in track.get("keys", []):
		var key: Dictionary = raw_key
		var value = key.get("value", null)
		if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT: continue
		var normalized := clampf(float(value) / 180.0, -0.45, 0.45)
		points.append(Vector2(_time_to_x(float(key.get("time", 0.0)), duration), y + ROW_HEIGHT * 0.5 - normalized * ROW_HEIGHT))
	if points.size() >= 2:
		var curve_color := color
		curve_color.a = 0.75
		draw_polyline(points, curve_color, 1.5, true)


func _duration() -> float:
	return maxf(0.01, float(_clip.get("duration", 1.0)))


func _time_to_x(time: float, duration: float) -> float:
	return LABEL_WIDTH + clampf(time / maxf(0.01, duration), 0.0, 1.0) * maxf(1.0, size.x - LABEL_WIDTH)


func _theme_color(token: String, fallback: Color) -> Color:
	return ThemeService.get_color_token(token) if ThemeService != null else fallback
