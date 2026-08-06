# CurvePresets -- Preset easing curve library for quick keyframe animation styling.
# CRV-006: Provides standard easing curve definitions, handle values, and preset evaluation.
class_name CurvePresets
extends RefCounted

const BezierEvaluatorScript = preload("res://animation/curves/bezier_evaluator.gd")

enum PresetType {
	LINEAR = 0,
	EASE_IN = 1,
	EASE_OUT = 2,
	EASE_IN_OUT = 3,
	BOUNCE = 4,
	ELASTIC = 5,
	BACK = 6,
	CUBIC = 7
}


## Returns dictionary of tangent handle parameters (in_handle, out_handle) for a preset type.
static func get_preset_handles(preset: int) -> Dictionary:
	match preset:
		PresetType.LINEAR:
			return {"out_handle": Vector2(0.0, 0.0), "in_handle": Vector2(0.0, 0.0)}
		PresetType.EASE_IN:
			return {"out_handle": Vector2(0.42, 0.0), "in_handle": Vector2(0.0, 0.0)}
		PresetType.EASE_OUT:
			return {"out_handle": Vector2(0.0, 0.0), "in_handle": Vector2(-0.42, 0.0)}
		PresetType.EASE_IN_OUT:
			return {"out_handle": Vector2(0.42, 0.0), "in_handle": Vector2(-0.42, 0.0)}
		PresetType.BACK:
			return {"out_handle": Vector2(0.3, -0.3), "in_handle": Vector2(-0.3, 0.3)}
		_:
			return {"out_handle": Vector2(0.25, 0.0), "in_handle": Vector2(-0.25, 0.0)}


## Evaluates easing preset factor for normalized factor t in range [0, 1].
static func evaluate_preset(preset: int, t: float) -> float:
	var factor: float = clampf(t, 0.0, 1.0)
	match preset:
		PresetType.LINEAR:
			return factor
		PresetType.EASE_IN:
			return factor * factor * factor
		PresetType.EASE_OUT:
			var f: float = factor - 1.0
			return f * f * f + 1.0
		PresetType.EASE_IN_OUT:
			if factor < 0.5:
				return 4.0 * factor * factor * factor
			else:
				var f: float = (2.0 * factor) - 2.0
				return 0.5 * f * f * f + 1.0
		PresetType.BOUNCE:
			return evaluate_bounce(factor)
		PresetType.ELASTIC:
			return evaluate_elastic(factor)
		PresetType.BACK:
			var c1: float = 1.70158
			var c3: float = c1 + 1.0
			return c3 * factor * factor * factor - c1 * factor * factor
		PresetType.CUBIC:
			return BezierEvaluatorScript.evaluate_bezier_1d(factor, Vector2(0.25, 0.1), Vector2(-0.25, 0.9))
		_:
			return factor


## Evaluates bounce easing function.
static func evaluate_bounce(t: float) -> float:
	var n1: float = 7.5625
	var d1: float = 2.75

	if t < 1.0 / d1:
		return n1 * t * t
	elif t < 2.0 / d1:
		t -= 1.5 / d1
		return n1 * t * t + 0.75
	elif t < 2.5 / d1:
		t -= 2.25 / d1
		return n1 * t * t + 0.9375
	else:
		t -= 2.625 / d1
		return n1 * t * t + 0.984375


## Evaluates elastic easing function.
static func evaluate_elastic(t: float) -> float:
	if t <= 0.0:
		return 0.0
	if t >= 1.0:
		return 1.0
	var c4: float = (2.0 * PI) / 3.0
	return -pow(2.0, 10.0 * t - 10.0) * sin((t * 10.0 - 10.75) * c4)


## Returns array of standard preset names.
static func get_preset_names() -> Array[String]:
	return ["Linear", "Ease In", "Ease Out", "Ease In-Out", "Bounce", "Elastic", "Back", "Cubic"]
