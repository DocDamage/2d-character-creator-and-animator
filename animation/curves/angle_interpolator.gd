# AngleInterpolator -- Shortest-path and continuous angle interpolation controls.
# CRV-004: Prevents 360° spin flips via shortest path (-180°..+180°) and continuous angle controls.
class_name AngleInterpolator
extends RefCounted

enum Mode {
	SHORTEST_PATH = 0,
	CONTINUOUS = 1,
	CLOCKWISE = 2,
	COUNTER_CLOCKWISE = 3
}


## Interpolates between angle_a and angle_b in radians using factor (0..1) under the specified mode.
static func interpolate_radians(angle_a: float, angle_b: float, factor: float, mode: int = Mode.SHORTEST_PATH) -> float:
	match mode:
		Mode.SHORTEST_PATH:
			return lerp_angle(angle_a, angle_b, factor)
		Mode.CONTINUOUS:
			return lerpf(angle_a, angle_b, factor)
		Mode.CLOCKWISE:
			var diff: float = fmod(angle_b - angle_a, TAU)
			if diff < 0.0:
				diff += TAU
			return angle_a + diff * factor
		Mode.COUNTER_CLOCKWISE:
			var diff: float = fmod(angle_a - angle_b, TAU)
			if diff < 0.0:
				diff += TAU
			return angle_a - diff * factor
		_:
			return lerp_angle(angle_a, angle_b, factor)


## Interpolates between angle_a and angle_b in degrees using factor (0..1).
static func interpolate_degrees(deg_a: float, deg_b: float, factor: float, mode: int = Mode.SHORTEST_PATH) -> float:
	var rad_a: float = deg_to_rad(deg_a)
	var rad_b: float = deg_to_rad(deg_b)
	var res_rad: float = interpolate_radians(rad_a, rad_b, factor, mode)
	return rad_to_deg(res_rad)


## Normalizes angle in radians into range [-PI, PI].
static func normalize_radians(angle: float) -> float:
	var normalized: float = fmod(angle, TAU)
	if normalized > PI:
		normalized -= TAU
	elif normalized < -PI:
		normalized += TAU
	return normalized


## Normalizes angle in degrees into range [-180, 180].
static func normalize_degrees(deg: float) -> float:
	var normalized: float = fmod(deg, 360.0)
	if normalized > 180.0:
		normalized -= 360.0
	elif normalized < -180.0:
		normalized += 360.0
	return normalized
