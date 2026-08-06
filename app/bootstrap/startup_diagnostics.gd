# StartupDiagnostics — Helper class for running startup health & environment checks
class_name StartupDiagnostics
extends RefCounted

## === Constants ==============================================================

const APP_NAME := "Modular 2D Character Studio"
const APP_VERSION := "0.1.0-dev"
const APP_BUILD_DATE := "2026-08-05"
const TARGET_GODOT_VERSION := "4.7"
const DEFAULT_THEME_PATH := "res://app/shared_ui/default_theme.tres"

const REQUIRED_DIRECTORIES: Array[String] = [
	"res://app", "res://core", "res://character", "res://rigging",
	"res://deformation", "res://animation", "res://weapons", "res://gameplay_metadata",
	"res://media", "res://export", "res://runtime_plugin", "res://editor_plugins",
	"res://tests", "res://tools", "res://docs", "res://samples"
]
const REQUIRED_PACKAGED_RESOURCES: Array[String] = [
	"res://app/bootstrap/startup.tscn", DEFAULT_THEME_PATH
]

## === Diagnostics Runner ======================================================

static func run_diagnostics(log_callback: Callable = Callable(), check_callback: Callable = Callable()) -> Dictionary:
	var passed_checks := 0
	var total_checks := 0
	var errors: Array[String] = []

	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null and tree.root.has_node("DiagnosticsService"):
		tree.root.get_node("DiagnosticsService").call("info", "=== %s v%s ===" % [APP_NAME, APP_VERSION], "Startup")

	# Check 1: Engine Version
	total_checks += 1
	var v_info := Engine.get_version_info()
	var v_str := "%d.%d.%d" % [v_info.major, v_info.minor, v_info.patch]
	if v_info.major == 4:
		passed_checks += 1
		_log(log_callback, "[OK] Godot engine version compatible: %s" % v_str)
		_notify_check(check_callback, "EngineVersion", true)
	else:
		var err := "Incompatible Godot version: " + v_str
		errors.append(err)
		_log(log_callback, "[FAIL] " + err)
		_notify_check(check_callback, "EngineVersion", false)

	# Check 2: Autoload Services
	total_checks += 1
	var services_ok := false
	if tree != null and tree.root != null:
		services_ok = tree.root.has_node("AppState") and tree.root.has_node("CommandService") and tree.root.has_node("IDService") and tree.root.has_node("SerializationService") and tree.root.has_node("DiagnosticsService")
	if services_ok:
		passed_checks += 1
		_log(log_callback, "[OK] Autoload services verified.")
		_notify_check(check_callback, "AutoloadServices", true)
	else:
		var err := "Missing required autoload service(s)."
		errors.append(err)
		_log(log_callback, "[FAIL] " + err)
		_notify_check(check_callback, "AutoloadServices", false)

	# Check 3: Theme Resource
	total_checks += 1
	if ResourceLoader.exists(DEFAULT_THEME_PATH):
		passed_checks += 1
		_log(log_callback, "[OK] Shared default theme loaded.")
		_notify_check(check_callback, "ThemeResource", true)
	else:
		var err := "Failed to load default theme resource."
		errors.append(err)
		_log(log_callback, "[FAIL] " + err)
		_notify_check(check_callback, "ThemeResource", false)

	# Check 4: Source layout in development, runtime resources in exported templates.
	total_checks += 1
	var structure := validate_structure()
	if structure.get("valid", false):
		passed_checks += 1
		var message := "[OK] Packaged runtime resources verified." if structure.get("packaged_runtime", false) else "[OK] Repository structure intact."
		_log(log_callback, message)
		_notify_check(check_callback, "DirectoryStructure", true)
	else:
		var kind := "packaged resources" if structure.get("packaged_runtime", false) else "directories"
		var err := "Missing %s: %s" % [kind, ", ".join(structure.get("missing", []))]
		errors.append(err)
		_log(log_callback, "[FAIL] " + err)
		_notify_check(check_callback, "DirectoryStructure", false)

	# Check 5: Environment Diagnostics
	total_checks += 1
	passed_checks += 1
	var os_name := OS.get_name()
	var proc_count := OS.get_processor_count()
	var env_info := "OS: %s | CPU Cores: %d" % [os_name, proc_count]
	_log(log_callback, "[OK] Environment diagnostics collected: %s" % env_info)
	_notify_check(check_callback, "EnvironmentDiagnostics", true)

	return {
		"passed": passed_checks,
		"total": total_checks,
		"errors": errors
	}


static func validate_structure(packaged_runtime: bool = OS.has_feature("template")) -> Dictionary:
	var missing: Array[String] = []
	if packaged_runtime:
		for path in REQUIRED_PACKAGED_RESOURCES:
			if not ResourceLoader.exists(path): missing.append(path)
	else:
		for path in REQUIRED_DIRECTORIES:
			if not DirAccess.dir_exists_absolute(path): missing.append(path)
	return {"valid": missing.is_empty(), "missing": missing, "packaged_runtime": packaged_runtime}


static func _log(callback: Callable, msg: String) -> void:
	if callback.is_valid():
		callback.call(msg)


static func _notify_check(callback: Callable, name: String, success: bool) -> void:
	if callback.is_valid():
		callback.call(name, success)
