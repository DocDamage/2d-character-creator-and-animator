# BezierEvaluator -- Cubic Bézier curve evaluation engine with control handles.
# CRV-003: Solves parametric 2D Bézier curve X(u)=x for u, returning Y(u).
class_name BezierEvaluator
extends RefCounted

const LinearSteppedEvaluatorScript = preload("res://animation/curves/linear_stepped_evaluator.gd")

## Precision threshold for Newton-Raphson iteration.
const EPSILON := 1e-6
const MAX_ITERATIONS := 12


## Evaluates 1D cubic Bézier curve value at normalized time x (0..1).
static func evaluate_bezier_1d(x: float, handle_out: Vector2 = Vector2(0.25, 0.0), handle_in: Vector2 = Vector2(-0.25, 0.0)) -> float:
	var clamped_x: float = clampf(x, 0.0, 1.0)
	if clamped_x <= 0.0:
		return 0.0
	if clamped_x >= 1.0:
		return 1.0

	var p1: Vector2 = Vector2(clampf(handle_out.x, 0.0, 1.0), handle_out.y)
	var p2: Vector2 = Vector2(clampf(1.0 + handle_in.x, 0.0, 1.0), 1.0 + handle_in.y)

	var u: float = solve_bezier_u(clamped_x, p1.x, p2.x)
	return calculate_bezier_y(u, p1.y, p2.y)


## Solves parametric parameter u in [0,1] such that X(u) == target_x.
static func solve_bezier_u(target_x: float, p1x: float, p2x: float) -> float:
	var u: float = target_x

	for _i in range(MAX_ITERATIONS):
		var current_x: float = calculate_bezier_x(u, p1x, p2x) - target_x
		if absf(current_x) < EPSILON:
			return u
		var dx: float = calculate_bezier_dx(u, p1x, p2x)
		if absf(dx) < 1e-8:
			break
		u -= current_x / dx

	var u_min: float = 0.0
	var u_max: float = 1.0
	u = target_x

	for _j in range(16):
		var x_eval: float = calculate_bezier_x(u, p1x, p2x)
		if absf(x_eval - target_x) < EPSILON:
			return u
		if target_x > x_eval:
			u_min = u
		else:
			u_max = u
		u = 0.5 * (u_min + u_max)

	return u


## Evaluates X(u) for cubic Bézier with P0.x=0, P3.x=1.
static func calculate_bezier_x(u: float, p1x: float, p2x: float) -> float:
	var one_minus_u: float = 1.0 - u
	return 3.0 * one_minus_u * one_minus_u * u * p1x + 3.0 * one_minus_u * u * u * p2x + u * u * u


## Evaluates dX/du derivative for Newton-Raphson.
static func calculate_bezier_dx(u: float, p1x: float, p2x: float) -> float:
	var one_minus_u: float = 1.0 - u
	return 3.0 * one_minus_u * one_minus_u * p1x + 6.0 * one_minus_u * u * (p2x - p1x) + 3.0 * u * u * (1.0 - p2x)


## Evaluates Y(u) for cubic Bézier with P0.y=0, P3.y=1.
static func calculate_bezier_y(u: float, p1y: float, p2y: float) -> float:
	var one_minus_u: float = 1.0 - u
	return 3.0 * one_minus_u * one_minus_u * u * p1y + 3.0 * one_minus_u * u * u * p2y + u * u * u


## Evaluates Bézier curve between key_a and key_b at time t.
static func evaluate_bezier_keys(key_a: RefCounted, key_b: RefCounted, t: float, out_handle: Vector2 = Vector2(0.25, 0.0), in_handle: Vector2 = Vector2(-0.25, 0.0)) -> Variant:
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
	var bezier_factor: float = evaluate_bezier_1d(factor, out_handle, in_handle)
	return LinearSteppedEvaluatorScript.interpolate_values(key_a.get("value"), key_b.get("value"), bezier_factor)
