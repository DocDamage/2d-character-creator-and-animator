# LinearSteppedEvaluator -- Baseline stepped and linear value evaluation engine.
# CRV-001: Evaluates scalar, Vector2/Vector3, Color, and array values across keyframes.
class_name LinearSteppedEvaluator
extends RefCounted

## Evaluates stepped interpolation between key_a and key_b at time t.
## Stepped holds key_a.value until time reaches key_b.time.
static func evaluate_stepped(key_a: RefCounted, key_b: RefCounted, t: float) -> Variant:
	if key_a == null:
		return null if key_b == null else key_b.get("value")
	if key_b == null or t < float(key_b.get("time")):
		return key_a.get("value")
	return key_b.get("value")


## Evaluates linear interpolation between key_a and key_b at time t.
static func evaluate_linear(key_a: RefCounted, key_b: RefCounted, t: float) -> Variant:
	if key_a == null and key_b == null:
		return 0.0
	if key_a == null:
		return key_b.get("value")
	var time_a: float = float(key_a.get("time")) if key_a != null else 0.0
	var time_b: float = float(key_b.get("time")) if key_b != null else 0.0
	if key_b == null or time_a == time_b:
		return key_a.get("value")

	var time_span: float = time_b - time_a
	if time_span <= 0.0:
		return key_a.get("value")

	var factor: float = clampf((t - time_a) / time_span, 0.0, 1.0)
	return interpolate_values(key_a.get("value"), key_b.get("value"), factor)


## Interpolates between generic variants val_a and val_b using weight factor (0.0..1.0).
static func interpolate_values(val_a: Variant, val_b: Variant, factor: float) -> Variant:
	if typeof(val_a) != typeof(val_b):
		return val_a if factor < 1.0 else val_b

	match typeof(val_a):
		TYPE_FLOAT, TYPE_INT:
			return lerpf(float(val_a), float(val_b), factor)
		TYPE_VECTOR2:
			return (val_a as Vector2).lerp(val_b as Vector2, factor)
		TYPE_VECTOR3:
			return (val_a as Vector3).lerp(val_b as Vector3, factor)
		TYPE_COLOR:
			return (val_a as Color).lerp(val_b as Color, factor)
		TYPE_ARRAY:
			var arr_a: Array = val_a as Array
			var arr_b: Array = val_b as Array
			var result: Array = []
			var count: int = min(arr_a.size(), arr_b.size())
			for i in range(count):
				result.append(interpolate_values(arr_a[i], arr_b[i], factor))
			return result
		TYPE_BOOL:
			return val_a if factor < 0.5 else val_b
		TYPE_STRING:
			return val_a if factor < 1.0 else val_b
		_:
			return val_a if factor < 0.5 else val_b
