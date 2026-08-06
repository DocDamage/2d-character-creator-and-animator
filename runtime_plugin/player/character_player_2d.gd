# CharacterPlayer2D -- Consumer-safe hardware-rendered character playback node.
class_name CharacterPlayer2D
extends Node2D

const FacingGridDefinitionScript = preload("res://facing/facing_grid_definition.gd")
const FacingGridEvaluatorScript = preload("res://facing/facing_grid_evaluator.gd")
const StateMachineDefinitionScript = preload("res://animation/state_machine/state_machine_definition.gd")
const StateMachineEvaluatorScript = preload("res://animation/state_machine/state_machine_evaluator.gd")
const RuleGraphScript = preload("res://animation/rules/rule_graph.gd")

signal state_changed(previous_state: String, current_state: String)
signal animation_event(event_data: Dictionary)
signal equipment_changed(slot_id: String, item: Variant)

@export var runtime_data: CharacterRuntimeData
@export var autoplay: bool = true
@export var pixel_mode: bool = false

var facing_direction: Vector2 = Vector2.DOWN
var facing_result: Dictionary = {}
var equipment: Dictionary = {}
var state_evaluator = StateMachineEvaluatorScript.new()
var rule_graph = null
var _facing_grid = null
var _last_state_id: String = ""
var _previous_time: float = 0.0
var _skeleton: Skeleton2D = null
var _bones: Dictionary = {}


func _ready() -> void:
	if runtime_data != null:
		load_runtime_data(runtime_data)
	set_process(autoplay)


func _process(delta: float) -> void:
	if state_evaluator.machine == null:
		return
	var previous_state: String = state_evaluator.current_state_id
	var snapshot: Dictionary = state_evaluator.update(delta, {"events": []})
	if previous_state != snapshot.get("state_id", ""):
		state_changed.emit(previous_state, str(snapshot.get("state_id", "")))
	_evaluate_rules(snapshot)
	_emit_timeline_events(_previous_time, state_evaluator.state_time)
	_previous_time = state_evaluator.state_time


func load_runtime_data(data: CharacterRuntimeData) -> bool:
	runtime_data = data
	return load_package(data.package_data)


func load_package(package: Dictionary) -> bool:
	var content: Dictionary = package.get("content", {})
	if content.is_empty():
		return false
	_configure_facing(content.get("facing_grid", content.get("facing_grids", {})))
	_configure_state_machine(content.get("state_machine", {}), content.get("clip_durations", {}))
	rebuild_skeleton(content.get("rig", content.get("skeleton", {})))
	if content.get("rule_graph", {}) is Dictionary and not (content.get("rule_graph", {}) as Dictionary).is_empty():
		rule_graph = RuleGraphScript.new().from_dict(content.get("rule_graph", {}) as Dictionary)
	return true


func set_facing_direction(direction: Vector2) -> Dictionary:
	if not direction.is_zero_approx():
		facing_direction = direction.normalized()
	if _facing_grid == null:
		return {}
	facing_result = FacingGridEvaluatorScript.evaluate(_facing_grid, facing_direction)
	return facing_result.duplicate(true)


func set_parameter(parameter_id: String, value: Variant) -> bool:
	return state_evaluator.set_parameter(parameter_id, value)


func trigger(parameter_id: String) -> bool:
	return state_evaluator.trigger(parameter_id)


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
		var position: Variant = (vertex as Dictionary).get("position", [0.0, 0.0])
		points.append(Vector2(float(position[0]), float(position[1])))
	node.polygon = points
	node.texture = texture
	if mesh_data.has("uvs"):
		var uvs := PackedVector2Array()
		for value in mesh_data.get("uvs", []) as Array:
			uvs.append(Vector2(float(value[0]), float(value[1])))
		node.uv = uvs
	add_child(node)
	return node


func rebuild_skeleton(rig: Variant) -> bool:
	if _skeleton != null:
		_skeleton.queue_free()
		_skeleton = null
	_bones.clear()
	if not (rig is Dictionary) or (rig as Dictionary).is_empty():
		return false
	var records: Dictionary = (rig as Dictionary).get("bones", {})
	if records.is_empty():
		return false
	_skeleton = Skeleton2D.new()
	_skeleton.name = "RuntimeSkeleton2D"
	add_child(_skeleton)
	var pending: Array = records.keys()
	while not pending.is_empty():
		var attached_any := false
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
			attached_any = true
		if not attached_any:
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


func _configure_facing(data: Variant) -> void:
	var grid_data: Dictionary = {}
	if data is Dictionary:
		grid_data = data
		if not grid_data.has("grid_id") and not grid_data.is_empty():
			grid_data = grid_data[grid_data.keys()[0]] as Dictionary
	if grid_data.is_empty():
		return
	_facing_grid = FacingGridDefinitionScript.new().from_dict(grid_data)
	_facing_grid.pixel_mode = pixel_mode or _facing_grid.pixel_mode
	set_facing_direction(facing_direction)


func _configure_state_machine(data: Variant, durations: Variant) -> void:
	if not (data is Dictionary) or (data as Dictionary).is_empty():
		return
	var definition: StateMachineDefinition = StateMachineDefinitionScript.new().from_dict(data as Dictionary)
	if state_evaluator.configure(definition, durations as Dictionary):
		_last_state_id = state_evaluator.current_state_id


func _evaluate_rules(snapshot: Dictionary) -> void:
	if rule_graph == null:
		return
	var result: Dictionary = rule_graph.evaluate({"state": snapshot.get("state_id", ""), "parameters": state_evaluator.parameters, "direction": facing_result.get("primary_direction", ""), "equipment": equipment})
	for action in result.get("actions", []) as Array:
		var record := action as Dictionary
		if str(record.get("type", "")) == "trigger_event":
			animation_event.emit(record.duplicate(true))
		elif str(record.get("type", "")) == "equip":
			equip(str(record.get("target", "")), record.get("value"))


func _emit_timeline_events(from_time: float, to_time: float) -> void:
	if runtime_data == null or to_time < from_time:
		return
	var content: Dictionary = runtime_data.get_content()
	for event in content.get("events", []) as Array:
		var time := float((event as Dictionary).get("time", -1.0))
		if time > from_time and time <= to_time:
			animation_event.emit((event as Dictionary).duplicate(true))


func _vector(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
