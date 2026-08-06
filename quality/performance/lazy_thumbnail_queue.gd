# LazyThumbnailQueue -- Dedupe-aware thumbnail work queue with bounded per-frame processing.
class_name LazyThumbnailQueue
extends RefCounted

var _pending: Array = []
var _cached: Dictionary = {}


func enqueue(key: String, payload: Variant = null) -> bool:
	if key.is_empty() or _cached.has(key): return false
	for item in _pending:
		if str((item as Dictionary).get("key", "")) == key: return false
	_pending.append({"key": key, "payload": payload})
	return true


func process(max_items: int, renderer: Callable) -> Array:
	var results: Array = []
	for _index in range(mini(maxi(0, max_items), _pending.size())):
		var item := _pending.pop_front() as Dictionary
		var value = renderer.call(item.get("payload")) if renderer.is_valid() else item.get("payload")
		_cached[str(item.get("key", ""))] = value
		results.append({"key": item.get("key", ""), "value": value})
	return results


func get_cached(key: String) -> Variant: return _cached.get(key)
func pending_count() -> int: return _pending.size()
