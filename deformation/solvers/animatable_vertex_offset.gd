# AnimatableVertexOffset -- Keyframeable vertex offset animation track controller.
# DEF-004: Manages timeline animation keyframes for per-vertex offset vectors.
class_name AnimatableVertexOffset
extends RefCounted

const KeyframeDataScript = preload("res://animation/keys/keyframe_schema.gd")
const LinearSteppedEvaluatorScript = preload("res://animation/curves/linear_stepped_evaluator.gd")

var track_id: String = ""
var target_vertex_id: int = 0
var keys: Array = [] # Array of KeyframeData


func _init(p_track_id: String = "", p_vert_id: int = 0) -> void:
	track_id = p_track_id
	target_vertex_id = p_vert_id


## Adds an offset keyframe (Vector2 displacement) at specified time.
func add_offset_key(time: float, offset: Vector2, key_id: String = "") -> RefCounted:
	var k_id: String = key_id if not key_id.is_empty() else "voff_%d_%.2f" % [target_vertex_id, time]
	var k = KeyframeDataScript.new(k_id, time, offset)
	keys.append(k)
	keys.sort_custom(func(a, b): return float(a.time) < float(b.time))
	return k


## Evaluates vector displacement offset at given timeline time.
func evaluate_offset(t: float) -> Vector2:
	if keys.is_empty():
		return Vector2.ZERO
	if keys.size() == 1:
		return keys[0].value as Vector2 if typeof(keys[0].value) == TYPE_VECTOR2 else Vector2.ZERO

	# Find keyframe interval
	if t <= float(keys[0].time):
		return keys[0].value as Vector2
	if t >= float(keys.back().time):
		return keys.back().value as Vector2

	for i in range(keys.size() - 1):
		var k_curr = keys[i]
		var k_next = keys[i + 1]
		if t >= float(k_curr.time) and t <= float(k_next.time):
			var val = LinearSteppedEvaluatorScript.evaluate_linear(k_curr, k_next, t)
			return val as Vector2 if typeof(val) == TYPE_VECTOR2 else Vector2.ZERO

	return Vector2.ZERO
