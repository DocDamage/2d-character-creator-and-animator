# CycleDetector — Detects circular dependency cycles in bone constraint target chains
class_name CycleDetector
extends RefCounted


static func detect_cycles(p_constraints: Array[ConstraintInterface]) -> Array[String]:
	var graph := {}
	for c in p_constraints:
		if not c.owner_bone_id.is_empty() and not c.target_bone_id.is_empty():
			if not graph.has(c.owner_bone_id):
				graph[c.owner_bone_id] = []
			graph[c.owner_bone_id].append(c.target_bone_id)
			
	var cycles: Array[String] = []
	var visited := {}
	var rec_stack := {}
	
	for node in graph:
		if _dfs(node, graph, visited, rec_stack):
			cycles.append("Cycle detected starting at bone '%s'." % node)
			
	return cycles


static func _dfs(node: String, graph: Dictionary, visited: Dictionary, rec_stack: Dictionary) -> bool:
	visited[node] = true
	rec_stack[node] = true
	
	var neighbors: Array = graph.get(node, [])
	for neighbor in neighbors:
		if not visited.get(neighbor, false):
			if _dfs(neighbor, graph, visited, rec_stack):
				return true
		elif rec_stack.get(neighbor, false):
			return true
			
	rec_stack[node] = false
	return false
