# ConstraintStack — Ordered constraint stack evaluation and priority sorting
class_name ConstraintStack
extends RefCounted

var _constraints: Array[ConstraintInterface] = []


func add_constraint(p_constraint: ConstraintInterface) -> void:
	_constraints.append(p_constraint)
	_sort_stack()


func remove_constraint(p_id: String) -> bool:
	for i in range(_constraints.size()):
		if _constraints[i].id == p_id:
			_constraints.remove_at(i)
			return true
	return false


func get_constraints() -> Array[ConstraintInterface]:
	return _constraints


func evaluate_stack(p_rig: Dictionary, p_delta: float) -> void:
	for c in _constraints:
		if c.enabled and c.influence > 0.0:
			c.evaluate(p_rig, p_delta)


func _sort_stack() -> void:
	_constraints.sort_custom(func(a: ConstraintInterface, b: ConstraintInterface) -> bool:
		return a.priority < b.priority
	)
