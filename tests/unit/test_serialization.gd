# TestSerialization — Unit tests for deterministic serialization and hashing (REQ-DOC-003)
extends Node

const ProjectSchema = preload("res://core/documents/project_schema.gd")

var _pass_count := 0
var _fail_count := 0
var _errors: Array[String] = []

func run_all_tests() -> Dictionary:
	_pass_count = 0
	_fail_count = 0
	_errors.clear()

	print("[TEST 16] Deterministic Serialization Workflows (REQ-DOC-003)...")

	test_key_order_independence()
	test_nested_structure_sorting()
	test_float_normalization()
	test_line_ending_normalization()
	test_sha256_hash_determinism()
	test_save_load_roundtrip_determinism()
	test_special_float_handling()

	print("  Serialization tests finished: %d PASS, %d FAIL" % [_pass_count, _fail_count])
	return {
		"passed": _pass_count,
		"failed": _fail_count,
		"errors": _errors
	}


func test_key_order_independence() -> void:
	var dict_a := {
		"zebra": 100,
		"alpha": "hello",
		"mid": true,
		"beta": 3.14159
	}
	var dict_b := {
		"alpha": "hello",
		"beta": 3.14159,
		"zebra": 100,
		"mid": true
	}

	var json_a := SerializationService.serialize_deterministic(dict_a)
	var json_b := SerializationService.serialize_deterministic(dict_b)

	_assert(json_a == json_b, "Dictionaries with different key insertion orders serialize to byte-identical string")


func test_nested_structure_sorting() -> void:
	var dict_a := {
		"outer_b": {
			"z": 1,
			"a": 2
		},
		"outer_a": [
			{"y": 10, "x": 20},
			{"b": 30, "a": 40}
		]
	}
	var dict_b := {
		"outer_a": [
			{"x": 20, "y": 10},
			{"a": 40, "b": 30}
		],
		"outer_b": {
			"a": 2,
			"z": 1
		}
	}

	var json_a := SerializationService.serialize_deterministic(dict_a)
	var json_b := SerializationService.serialize_deterministic(dict_b)

	_assert(json_a == json_b, "Nested dictionaries and arrays in dictionaries serialize byte-identically")


func test_float_normalization() -> void:
	var dict_a := {"val": 1.5000000000000002}
	var dict_b := {"val": 1.5}

	var json_a := SerializationService.serialize_deterministic(dict_a)
	var json_b := SerializationService.serialize_deterministic(dict_b)

	_assert(json_a == json_b, "Floats with epsilon noise normalize to identical output")


func test_line_ending_normalization() -> void:
	var manifest := ProjectSchema.create_default_manifest("Line Test")
	var serialized := SerializationService.serialize_deterministic(manifest)

	_assert(not ("\r\n" in serialized), "Serialized string contains no CRLF line endings")
	_assert("\n" in serialized, "Serialized string uses standard LF line endings")


func test_sha256_hash_determinism() -> void:
	var dict_a := {"id": "123", "name": "Hero", "stats": {"hp": 100, "mp": 50}}
	var dict_b := {"stats": {"mp": 50, "hp": 100}, "name": "Hero", "id": "123"}

	var hash_a := SerializationService.compute_hash(dict_a)
	var hash_b := SerializationService.compute_hash(dict_b)

	_assert(hash_a.length() == 64, "compute_hash returns 64-character SHA-256 hex string")
	_assert(hash_a == hash_b, "compute_hash produces byte-identical hash regardless of key order")


func test_save_load_roundtrip_determinism() -> void:
	var manifest := ProjectSchema.create_default_manifest("Roundtrip Test", "rt-100200300")
	var hash_orig := SerializationService.compute_hash(manifest)

	var temp_file := "user://test_roundtrip_det.chrproj"
	var saved := SerializationService.save_project(manifest, temp_file)
	_assert(saved == true, "Save project to temp file succeeded")

	var reloaded := SerializationService.load_project(temp_file)
	_assert(not reloaded.is_empty(), "Load project from temp file returned non-empty dictionary")

	var hash_reloaded := SerializationService.compute_hash(reloaded)
	_assert(hash_orig == hash_reloaded, "Save-load roundtrip produces identical SHA-256 hash")

	if FileAccess.file_exists(temp_file):
		DirAccess.remove_absolute(temp_file)


func test_special_float_handling() -> void:
	var dict_special := {"inf_val": INF, "nan_val": NAN}
	var canonical: Dictionary = SerializationService.canonicalize(dict_special)

	_assert(canonical.get("inf_val") == 0.0, "INF float canonicalized to 0.0 safely")
	_assert(canonical.get("nan_val") == 0.0, "NAN float canonicalized to 0.0 safely")


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: " + message)
		_pass_count += 1
	else:
		printerr("  FAIL: " + message)
		_fail_count += 1
		_errors.append(message)
