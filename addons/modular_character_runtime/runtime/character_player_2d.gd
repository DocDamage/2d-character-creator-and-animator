# Portable CharacterPlayer2D implementation with no authoring-project imports.
extends Node2D

const RuntimeStateMachineScript = preload("res://addons/modular_character_runtime/runtime/runtime_state_machine.gd")
const RuntimeRuleGraphScript = preload("res://addons/modular_character_runtime/runtime/runtime_rule_graph.gd")
const RuntimeSceneBuilderScript = preload("res://addons/modular_character_runtime/runtime/runtime_scene_builder.gd")
const RuntimeTrackPlayerScript = preload("res://addons/modular_character_runtime/runtime/runtime_track_player.gd")

signal state_changed(previous_state: String, current_state: String)
signal animation_event(event_data: Dictionary)
signal equipment_changed(slot_id: String, item: Variant)

@export var runtime_data: Resource
@export var autoplay: bool = true
@export var pixel_mode: bool = false

var facing_direction: Vector2 = Vector2.DOWN
var facing_result: Dictionary = {}
var equipment: Dictionary = {}
var state_evaluator = RuntimeStateMachineScript.new()
var rule_graph = null
var _content: Dictionary = {}
var _previous_time := 0.0
var _skeleton: Skeleton2D
var _bones: Dictionary = {}
var _runtime_report: Dictionary = {}
var _appearance: Dictionary = {}
var _debug_views_enabled: bool = false
var _animation_player: AnimationPlayer
var _track_state: Dictionary = {}


func _ready() -> void:
	if runtime_data != null:
		load_runtime_data(runtime_data)
	set_process(autoplay)


func _process(delta: float) -> void:
	if state_evaluator.current_state_id.is_empty():
		return
	var previous: String = state_evaluator.current_state_id
	var snapshot: Dictionary = state_evaluator.update(delta, {"events": []})
	_play_clip(str(snapshot.get("clip_id", "")))
	_track_state = RuntimeTrackPlayerScript.new().evaluate(_content.get("runtime_tracks", _content.get("tracks", [])) as Array, state_evaluator.state_time)
	if previous != snapshot.get("state_id", ""):
		state_changed.emit(previous, str(snapshot.get("state_id", "")))
		_evaluate_rules(snapshot)
	_emit_timeline_events(_previous_time, state_evaluator.state_time)
	_previous_time = state_evaluator.state_time


func load_runtime_data(data: Resource) -> bool:
	runtime_data = data
	var package: Variant = data.get("package_data")
	return load_package(package as Dictionary if package is Dictionary else {})


func load_package(package: Dictionary) -> bool:
	_content = (package.get("content", {}) as Dictionary).duplicate(true)
	if _content.is_empty():
		return false
	_previous_time = 0.0
	rule_graph = null
	_configure_state_machine(_content.get("state_machine", {}), _content.get("clip_durations", {}))
	rebuild_skeleton(_content.get("rig", _content.get("skeleton", {})))
	_runtime_report = RuntimeSceneBuilderScript.new().build(self, _runtime_mapping(), Callable(self, "add_mesh"))
	_animation_player = get_node_or_null("RuntimeAnimationPlayer") as AnimationPlayer
	set_appearance((_runtime_mapping().get("appearance", {}) as Dictionary))
	if _content.get("rule_graph", {}) is Dictionary and not (_content.get("rule_graph", {}) as Dictionary).is_empty():
		rule_graph = RuntimeRuleGraphScript.new()
		rule_graph.configure(_content.get("rule_graph", {}))
	set_facing_direction(facing_direction)
	return true


func set_facing_direction(direction: Vector2) -> Dictionary:
	if not direction.is_zero_approx():
		facing_direction = direction.normalized()
	var grid: Dictionary = _facing_grid()
	var direction_ids: Array = _direction_ids(grid)
	if direction_ids.is_empty():
		facing_result = {}
		return {}
	var angle := fposmod(atan2(facing_direction.x, -facing_direction.y), TAU)
	var position := angle / (TAU / float(direction_ids.size()))
	var lower := int(floor(position)) % direction_ids.size()
	var upper := (lower + 1) % direction_ids.size()
	var fraction: float = position - floor(position)
	var pixel_safe := pixel_mode or bool(grid.get("pixel_mode", false))
	var crossfade := int(grid.get("default_blend_mode", 0)) == 2 and not pixel_safe
	var cells: Dictionary = grid.get("cells", {})
	facing_result = {
		"valid": true,
		"mode": "crossfade" if crossfade else "hard_switch",
		"primary_direction": str(direction_ids[lower] if crossfade else direction_ids[lower if fraction < 0.5 else upper]),
		"secondary_direction": str(direction_ids[upper]) if crossfade else "",
		"weight": fraction if crossfade else 0.0,
	}
	facing_result["primary_cell"] = (cells.get(facing_result["primary_direction"], {}) as Dictionary).duplicate(true)
	facing_result["secondary_cell"] = (cells.get(facing_result["secondary_direction"], {}) as Dictionary).duplicate(true)
	return facing_result.duplicate(true)


func set_parameter(parameter_id: String, value: Variant) -> bool:
	return state_evaluator.set_parameter(parameter_id, value)


func trigger(parameter_id: String) -> bool:
	return state_evaluator.trigger(parameter_id)


func get_current_state_id() -> String:
	return state_evaluator.current_state_id


func equip(slot_id: String, item: Variant) -> void:
	equipment[slot_id] = item
	equipment_changed.emit(slot_id, item)


func unequip(slot_id: String) -> Variant:
	var item: Variant = equipment.get(slot_id)
	equipment.erase(slot_id)
	equipment_changed.emit(slot_id, null)
	return item


func add_mesh(mesh_data: Dictionary, texture: Texture2D = null) -> Polygon2D:
	var node := Polygon2D.new()
	var points := PackedVector2Array()
	for vertex in mesh_data.get("vertices", []) as Array:
		points.append(_vector((vertex as Dictionary).get("position", [0.0, 0.0])))
	node.polygon = points
	node.texture = texture
	if mesh_data.has("uvs"):
		var uvs := PackedVector2Array()
		for value in mesh_data.get("uvs", []) as Array:
			uvs.append(_vector(value))
		node.uv = uvs
	add_child(node)
	if mesh_data.has("bone_ids") and mesh_data.has("weights"):
		for bone_id in mesh_data.get("bone_ids", []) as Array:
			if _bones.has(bone_id): node.add_bone(node.get_path_to(_bones[bone_id] as Node), PackedFloat32Array(mesh_data.get("weights", []) as Array))
		if _skeleton != null: node.skeleton = node.get_path_to(_skeleton)
	return node


func rebuild_skeleton(rig: Variant) -> bool:
	if _skeleton != null:
		_skeleton.queue_free()
		_bones.clear()
	if not rig is Dictionary or (rig as Dictionary).is_empty():
		return false
	var records: Dictionary = (rig as Dictionary).get("bones", {})
	if records.is_empty():
		return false
	_skeleton = Skeleton2D.new()
	_skeleton.name = "RuntimeSkeleton2D"
	add_child(_skeleton)
	var pending: Array = records.keys()
	while not pending.is_empty():
		var attached := false
		for bone_id in pending.duplicate():
			var record: Dictionary = records[bone_id]
			var parent_id := str(record.get("parent_id", ""))
			if not parent_id.is_empty() and not _bones.has(parent_id):
				continue
			var bone := Bone2D.new()
			bone.name = str(record.get("name", bone_id))
			bone.auto_calculate_length_and_angle = false
			bone.position = _vector(record.get("local_position", [0.0, 0.0]))
			bone.rotation = float(record.get("local_rotation", 0.0))
			(_bones[parent_id] as Bone2D).add_child(bone) if not parent_id.is_empty() else _skeleton.add_child(bone)
			_bones[bone_id] = bone
			pending.erase(bone_id)
			attached = true
		if not attached:
			return false
	return true


func solve_two_bone_ik(root_id: String, mid_id: String, target: Vector2, bend_positive: bool = true) -> bool:
	if not _bones.has(root_id) or not _bones.has(mid_id):
		return false
	var root: Bone2D = _bones[root_id]
	var mid: Bone2D = _bones[mid_id]
	var root_position := root.global_position
	var first_length := root_position.distance_to(mid.global_position)
	var second_length := 1.0
	for child in mid.get_children():
		if child is Bone2D:
			second_length = mid.global_position.distance_to((child as Bone2D).global_position)
			break
	var distance := clampf(root_position.distance_to(target), 0.001, first_length + second_length - 0.001)
	var elbow := acos(clampf((first_length * first_length + second_length * second_length - distance * distance) / (2.0 * first_length * second_length), -1.0, 1.0))
	var shoulder := acos(clampf((first_length * first_length + distance * distance - second_length * second_length) / (2.0 * first_length * distance), -1.0, 1.0))
	var sign := 1.0 if bend_positive else -1.0
	root.global_rotation = (target - root_position).angle() + shoulder * sign
	mid.rotation = (PI - elbow) * sign
	return true


func _configure_state_machine(data: Variant, durations: Variant) -> void:
	state_evaluator.configure(data, durations)


func set_appearance(data: Dictionary) -> void:
	_appearance = data.duplicate(true)
	for slot_id in _appearance.get("equipment", {}) as Dictionary: equip(str(slot_id), _appearance.equipment[slot_id])


func get_appearance() -> Dictionary:
	var result := _appearance.duplicate(true)
	result["equipment"] = equipment.duplicate(true)
	return result


func save_appearance() -> Dictionary: return get_appearance()
func restore_appearance(data: Dictionary) -> void: set_appearance(data)
func set_debug_views_enabled(enabled: bool) -> void: _debug_views_enabled = enabled


func get_debug_snapshot() -> Dictionary:
	return {"enabled": _debug_views_enabled, "state": state_evaluator.snapshot(), "facing": facing_result.duplicate(true), "runtime_nodes": _runtime_report.duplicate(true), "equipment": equipment.duplicate(true), "tracks": _track_state.duplicate(true), "baked_fallback": _runtime_mapping().get("baked_fallback", {}), "bones": _bones.keys()}


func resolve_grip_target(weapon_id: String, grip_id: String) -> Dictionary:
	for weapon in _runtime_mapping().get("weapons", []) as Array:
		var record := weapon as Dictionary
		if str(record.get("weapon_id", "")) == weapon_id:
			var grip: Dictionary = (record.get("grips", {}) as Dictionary).get(grip_id, {})
			var bone_id := str(grip.get("bone_id", ""))
			return {"valid": _bones.has(bone_id), "position": (_bones[bone_id] as Bone2D).global_position if _bones.has(bone_id) else Vector2.ZERO, "weapon_id": weapon_id, "grip_id": grip_id}
	return {"valid": false, "weapon_id": weapon_id, "grip_id": grip_id}


func _play_clip(clip_id: String) -> void:
	if _animation_player != null and not clip_id.is_empty() and _animation_player.has_animation(clip_id) and _animation_player.current_animation != clip_id: _animation_player.play(clip_id)


func _runtime_mapping() -> Dictionary:
	var mapping: Dictionary = _content.get("godot_runtime", {})
	if not mapping.is_empty(): return mapping
	return {"animation_library": _content.get("clips", _content.get("animations", {})), "meshes": _content.get("meshes", []), "sprites": _content.get("sprites", []), "markers": _content.get("markers", _content.get("action_points", [])), "collision_shapes": _content.get("collision_shapes", _content.get("collisions", [])), "weapons": _content.get("weapons", []), "appearance": _content.get("appearance", {}), "baked_fallback": _content.get("baked_fallback", {})}


func _evaluate_rules(snapshot: Dictionary) -> void:
	if rule_graph == null:
		return
	var context := {"state": snapshot.get("state_id", ""), "parameters": state_evaluator.parameters, "direction": facing_result.get("primary_direction", ""), "equipment": equipment, "time": state_evaluator.state_time}
	for action in (rule_graph.evaluate(context).get("actions", []) as Array):
		var record := action as Dictionary
		if str(record.get("type", "")) == "trigger_event":
			animation_event.emit(record.duplicate(true))
		elif str(record.get("type", "")) == "equip":
			equip(str(record.get("target", "")), record.get("value"))


func _emit_timeline_events(from_time: float, to_time: float) -> void:
	if to_time < from_time:
		return
	for event in _content.get("events", []) as Array:
		var record := event as Dictionary
		var time := float(record.get("time", -1.0))
		if time > from_time and time <= to_time:
			animation_event.emit(record.duplicate(true))


func _facing_grid() -> Dictionary:
	var data: Variant = _content.get("facing_grid", _content.get("facing_grids", {}))
	if data is Dictionary and (data as Dictionary).has("grid_id"):
		return (data as Dictionary).duplicate(true)
	if data is Dictionary and not (data as Dictionary).is_empty():
		return ((data as Dictionary)[(data as Dictionary).keys()[0]] as Dictionary).duplicate(true)
	return {}


func _direction_ids(grid: Dictionary) -> Array:
	match int(grid.get("direction_set", 8)):
		4: return ["north", "east", "south", "west"]
		8: return ["north", "north_east", "east", "south_east", "south", "south_west", "west", "north_west"]
		16:
			var output: Array = []
			for index in range(16):
				output.append("direction_%02d" % index)
			return output
		_: return (grid.get("custom_directions", []) as Array).duplicate()


func _vector(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
