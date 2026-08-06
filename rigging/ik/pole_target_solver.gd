# PoleTargetSolver — Joint bend direction and plane solver using pole target coordinates
class_name PoleTargetSolver
extends RefCounted


static func solve_pole_direction(p_root_pos: Vector2, p_tip_pos: Vector2, p_pole_target_pos: Vector2) -> bool:
	var limb_line := p_tip_pos - p_root_pos
	if limb_line.length_squared() < 0.0001:
		return true
		
	var pole_dir := p_pole_target_pos - p_root_pos
	var cross := limb_line.x * pole_dir.y - limb_line.y * pole_dir.x
	return cross >= 0.0
