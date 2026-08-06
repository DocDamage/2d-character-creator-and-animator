# IDService — Stable unique identifier generation
# Autoload: IDService
# Produces stable, unique, collision-resistant identifiers for all project objects.
extends Node

## === Constants ==============================================================

const ALLOWED_CHARS := "0123456789abcdefghijklmnopqrstuvwxyz"
const SHORT_LENGTH := 12
const LONG_LENGTH := 24
const ENCODE_BASE := 36

## === State ==================================================================

var _counter: int = 0
var _node_id: int = 0
var _existing_ids: Dictionary = {}
var _prefix_registry: Dictionary = {}

## === Public API =============================================================

func generate(prefix: String = "obj", auto_register: bool = true) -> String:
	var ts := Time.get_unix_time_from_system()
	var attempts := 0
	var candidate := ""

	while attempts < 100:
		var parts := PackedStringArray()
		parts.append(prefix)
		parts.append(_encode_int(int(ts), SHORT_LENGTH))
		parts.append(_encode_int(_counter, 4))
		parts.append(_encode_int(_node_id + attempts, 4))
		_counter += 1
		candidate = "_".join(parts)

		if not _existing_ids.has(candidate):
			if auto_register:
				_existing_ids[candidate] = true
			return candidate
		attempts += 1

	# Fallback to UUID-based string if collisions persist
	var fallback := "%s_%s" % [prefix, generate_uuid_v4().replace("-", "")]
	if auto_register:
		_existing_ids[fallback] = true
	return fallback


func generate_id(prefix: String = "obj", auto_register: bool = true) -> String:
	return generate(prefix, auto_register)



func generate_short(prefix: String = "id", auto_register: bool = true) -> String:
	var ts := Time.get_unix_time_from_system()
	var attempts := 0
	var candidate := ""

	while attempts < 100:
		var parts := PackedStringArray()
		parts.append(prefix)
		parts.append(_encode_int(int(ts) + _counter + attempts, 8))
		_counter += 1
		candidate = "_".join(parts)

		if not _existing_ids.has(candidate):
			if auto_register:
				_existing_ids[candidate] = true
			return candidate
		attempts += 1

	var fallback := "%s_%x" % [prefix, randi()]
	if auto_register:
		_existing_ids[fallback] = true
	return fallback


func generate_uuid_v4(auto_register: bool = false) -> String:
	# Generates a UUID v4-style string
	var bytes := PackedByteArray()
	bytes.resize(16)
	for i in 16:
		bytes[i] = randi() % 256
	bytes[6] = (bytes[6] & 0x0F) | 0x40  # Version 4
	bytes[8] = (bytes[8] & 0x3F) | 0x80  # Variant 1
	var uuid := "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
		bytes[0], bytes[1], bytes[2], bytes[3],
		bytes[4], bytes[5], bytes[6], bytes[7],
		bytes[8], bytes[9], bytes[10], bytes[11],
		bytes[12], bytes[13], bytes[14], bytes[15],
	]
	if auto_register:
		_existing_ids[uuid] = true
	return uuid


func register(id: String) -> bool:
	if id.strip_edges().is_empty():
		return false
	if _existing_ids.has(id):
		return false
	_existing_ids[id] = true
	return true


func unregister(id: String) -> void:
	_existing_ids.erase(id)


func is_registered(id: String) -> bool:
	return _existing_ids.has(id)


func get_registered_count() -> int:
	return _existing_ids.size()


func get_registered_ids() -> Array:
	return _existing_ids.keys()


func is_valid_uuid(id: String) -> bool:
	if id.length() != 36:
		return false
	if id[8] != "-" or id[13] != "-" or id[18] != "-" or id[23] != "-":
		return false
	var hex_chars := "0123456789abcdefABCDEF"
	for i in 36:
		if i == 8 or i == 13 or i == 18 or i == 23:
			continue
		if hex_chars.find(id[i]) == -1:
			return false
	return true


func is_valid_id(id: String) -> bool:
	var s := id.strip_edges()
	if s.is_empty() or s.length() > 128:
		return false
	var valid_chars := "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-"
	for i in s.length():
		if valid_chars.find(s[i]) == -1:
			return false
	return true


func reserve_range(prefix: String, count: int) -> bool:
	if count <= 0:
		return false
	if _prefix_registry.has(prefix):
		return _prefix_registry[prefix] > 0
	_prefix_registry[prefix] = count
	return true


func get_reserved_count(prefix: String) -> int:
	return _prefix_registry.get(prefix, 0) as int


func clear_reservations() -> void:
	_prefix_registry.clear()


func set_seed(seed_value: int) -> void:
	seed(seed_value)


func get_counter() -> int:
	return _counter


func reset_counter(value: int = 0) -> void:
	_counter = value


func clear_all() -> void:
	_existing_ids.clear()
	_prefix_registry.clear()
	_counter = 0


## === Internal ===============================================================

func _encode_int(value: int, min_length: int = 1) -> String:
	var result := ""
	var v := value
	for _i in max(min_length, 1):
		result = ALLOWED_CHARS[v % ENCODE_BASE] + result
		v /= ENCODE_BASE
		if v == 0 and result.length() >= min_length:
			break
	while result.length() < min_length:
		v = randi()
		result = ALLOWED_CHARS[v % ENCODE_BASE] + result
	return result


## === Lifecycle ==============================================================

func _enter_tree() -> void:
	_node_id = hash(str(get_instance_id())) & 0x7FFFFFFF
	randomize()


func _exit_tree() -> void:
	clear_all()