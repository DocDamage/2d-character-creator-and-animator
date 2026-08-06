# TestIDService — Unit tests for IDService stable unique identifier generation (REQ-DOC-002)
extends Node

var _pass_count := 0
var _fail_count := 0
var _errors: Array[String] = []

func run_all_tests() -> Dictionary:
	_pass_count = 0
	_fail_count = 0
	_errors.clear()

	print("[TEST 15] Stable ID Service Workflows (REQ-DOC-002)...")

	test_generate()
	test_generate_short()
	test_generate_uuid_v4()
	test_collision_resistance()
	test_registration_and_lookup()
	test_format_validation()
	test_prefix_reservation()
	test_counter_and_reset()

	print("  IDService tests finished: %d PASS, %d FAIL" % [_pass_count, _fail_count])
	return {
		"passed": _pass_count,
		"failed": _fail_count,
		"errors": _errors
	}


func test_generate() -> void:
	IDService.clear_all()
	var id1 := IDService.generate("char")
	_assert(id1.begins_with("char_"), "Generated ID begins with specified prefix")
	_assert(IDService.is_registered(id1), "Generated ID is automatically registered")
	_assert(IDService.is_valid_id(id1), "Generated ID satisfies format validation")

	var id2 := IDService.generate("char")
	_assert(id1 != id2, "Consecutively generated IDs are distinct")


func test_generate_short() -> void:
	IDService.clear_all()
	var s1 := IDService.generate_short("node")
	_assert(s1.begins_with("node_"), "Generated short ID begins with specified prefix")
	_assert(IDService.is_registered(s1), "Generated short ID is registered")
	_assert(IDService.is_valid_id(s1), "Generated short ID satisfies format validation")

	var s2 := IDService.generate_short("node")
	_assert(s1 != s2, "Consecutive short IDs are unique")


func test_generate_uuid_v4() -> void:
	IDService.clear_all()
	var u1 := IDService.generate_uuid_v4(true)
	_assert(u1.length() == 36, "UUID v4 string has length 36")
	_assert(IDService.is_valid_uuid(u1), "Generated string passes UUID v4 validation")
	_assert(IDService.is_registered(u1), "UUID v4 registered when auto_register is true")

	var u2 := IDService.generate_uuid_v4(false)
	_assert(IDService.is_valid_uuid(u2), "UUID v4 without auto_register passes validation")
	_assert(not IDService.is_registered(u2), "UUID v4 not registered when auto_register is false")


func test_collision_resistance() -> void:
	IDService.clear_all()
	var generated := {}
	var collision_count := 0
	var count := 1000

	for _i in count:
		var id := IDService.generate("item", true)
		if generated.has(id):
			collision_count += 1
		generated[id] = true

	_assert(collision_count == 0, "Generated 1000 IDs with 0 collisions")
	_assert(IDService.get_registered_count() == count, "All 1000 IDs registered in IDService")


func test_registration_and_lookup() -> void:
	IDService.clear_all()
	var custom_id := "custom_bone_001"
	_assert(IDService.register(custom_id) == true, "New custom ID registers successfully")
	_assert(IDService.is_registered(custom_id) == true, "Registered custom ID is recognized")
	_assert(IDService.register(custom_id) == false, "Duplicate registration rejected")
	_assert(IDService.register("") == false, "Empty ID registration rejected")
	_assert(IDService.register("   ") == false, "Whitespace ID registration rejected")

	IDService.unregister(custom_id)
	_assert(IDService.is_registered(custom_id) == false, "Unregistered ID no longer recognized")


func test_format_validation() -> void:
	_assert(IDService.is_valid_uuid("12345678-1234-4234-8234-123456789abc") == true, "Valid UUID string accepted")
	_assert(IDService.is_valid_uuid("invalid-uuid-string") == false, "Invalid string rejected by is_valid_uuid")
	_assert(IDService.is_valid_uuid("12345678-1234-4234-8234-123456789abg") == false, "Non-hex character rejected by is_valid_uuid")

	_assert(IDService.is_valid_id("valid_id-123") == true, "Valid identifier accepted by is_valid_id")
	_assert(IDService.is_valid_id("") == false, "Empty string rejected by is_valid_id")
	_assert(IDService.is_valid_id("invalid id with spaces") == false, "Space-containing string rejected by is_valid_id")


func test_prefix_reservation() -> void:
	IDService.clear_reservations()
	_assert(IDService.reserve_range("slot", 50) == true, "Range reservation for 'slot' succeeded")
	_assert(IDService.get_reserved_count("slot") == 50, "Reserved count for 'slot' is 50")
	_assert(IDService.reserve_range("slot", 0) == false, "Invalid range count <= 0 rejected")

	IDService.clear_reservations()
	_assert(IDService.get_reserved_count("slot") == 0, "Reserved count cleared")


func test_counter_and_reset() -> void:
	IDService.clear_all()
	IDService.reset_counter(10)
	_assert(IDService.get_counter() == 10, "Counter reset to 10")

	IDService.set_seed(12345)
	var u_seeded1 := IDService.generate_uuid_v4()
	IDService.set_seed(12345)
	var u_seeded2 := IDService.generate_uuid_v4()
	_assert(u_seeded1 == u_seeded2, "Deterministic seed produces identical UUID output")

	IDService.clear_all()
	_assert(IDService.get_counter() == 0, "Counter reset to 0 by clear_all")
	_assert(IDService.get_registered_count() == 0, "Registered IDs cleared by clear_all")


func _assert(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % message)
	else:
		_fail_count += 1
		_errors.append(message)
		print("  FAIL: %s" % message)
