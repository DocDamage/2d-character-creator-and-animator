# LOC Checker — Line-of-code compliance scanner
# Scans production source files and reports any exceeding 300 lines.
# Run from command line: godot --headless --script tools/loc_checker/loc_checker.gd
extends SceneTree

## === Configuration ==========================================================

const LINE_LIMIT := 300
const SCAN_EXTENSIONS := ["gd", "cs", "py", "gdscript"]
const EXCLUDED_DIRS := [
	".godot",
	"addons",
	"autosave",
	"backups",
	"exported",
	"tests",
	"user",
]
const BASELINE_PATH := "res://tools/loc_checker/loc_baseline.json"
const EXCLUDED_FILES := [
	"project.godot",
	".gitignore",
]

var _results: Array[Dictionary] = []
var _violations := 0
var _total_files := 0
var _baseline: Dictionary = {}
var _baseline_debt := 0

## === Entry Point ============================================================

func _init() -> void:
	print("=== LOC Checker v1.0.0 ===")
	print("Line limit: %d lines" % LINE_LIMIT)
	print("")
	_load_baseline()
	_scan_directory("res://")
	_print_results()
	_save_report()
	quit(0 if _violations == 0 else 1)


## === Scanning ===============================================================

func _scan_directory(dir_path: String) -> void:
	var da := DirAccess.open(dir_path)
	if da == null:
		printerr("Cannot open directory: %s" % dir_path)
		return

	da.list_dir_begin()
	var entry := da.get_next()
	while entry != "":
		if da.current_is_dir():
			if entry not in EXCLUDED_DIRS and not entry.begins_with("."):
				_scan_directory(dir_path.path_join(entry))
		else:
			if entry in EXCLUDED_FILES:
				pass
			elif _has_scannable_extension(entry):
				_scan_file(dir_path.path_join(entry))
		entry = da.get_next()
	da.list_dir_end()


func _has_scannable_extension(file_name: String) -> bool:
	var ext := file_name.get_extension().to_lower()
	return ext in SCAN_EXTENSIONS


func _scan_file(file_path: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		printerr("Cannot read file: %s" % file_path)
		return

	var line_count := 0
	while file.get_position() < file.get_length():
		file.get_line()
		line_count += 1
	file.close()

	_total_files += 1

	var baseline_limit := int(_baseline.get(file_path, LINE_LIMIT))
	var result := {
		"path": file_path,
		"lines": line_count,
		"baseline_limit": baseline_limit,
		"baseline_debt": line_count > LINE_LIMIT and baseline_limit > LINE_LIMIT,
		"violation": line_count > baseline_limit,
	}
	_results.append(result)

	if result["violation"]:
		_violations += 1
	elif result["baseline_debt"]:
		_baseline_debt += 1


func _load_baseline() -> void:
	if not FileAccess.file_exists(BASELINE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(BASELINE_PATH))
	if parsed is Dictionary:
		_baseline = parsed as Dictionary


## === Output =================================================================

func _print_results() -> void:
	print("Scanned %d files." % _total_files)
	print("")

	if _violations == 0:
		print("PASS: No new or worsened files exceed the %d-line policy." % LINE_LIMIT)
		if _baseline_debt > 0:
			print("Baseline debt retained: %d file(s); increases remain blocked." % _baseline_debt)
		return

	print("FAIL: %d file(s) exceed the %d-line limit:" % [_violations, LINE_LIMIT])
	print("-".repeat(70))
	for result in _results:
		if result["violation"]:
			print("  %4d lines  %s" % [result["lines"], result["path"]])
	print("-".repeat(70))

	print("")
	print("These files require review. Options:")
	print("  1. Split the file into smaller modules.")
	print("  2. File an exception request in docs/implementation/LOC_EXCEPTIONS.md")
	print("     with a split analysis explaining why splitting would harm the project.")
	print("")
	print("See Section 3.4 of the Master Plan for the full LOC policy.")


func _save_report() -> void:
	var report_path := "res://docs/implementation/evidence/GOV-004/loc_report.txt"
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write report to: %s" % report_path)
		return

	file.store_string("=== LOC Checker Report ===\n")
	file.store_string("Generated: %s\n" % Time.get_datetime_string_from_system())
	file.store_string("Limit: %d lines per file\n" % LINE_LIMIT)
	file.store_string("Total scanned: %d\n" % _total_files)
	file.store_string("Violations: %d\n\n" % _violations)
	file.store_string("Baseline debt: %d\n\n" % _baseline_debt)

	for result in _results:
		var status := "FAIL" if result["violation"] else ("DEBT" if result["baseline_debt"] else "PASS")
		file.store_string("%4s  %4d lines  %s\n" % [status, result["lines"], result["path"]])

	file.close()
	print("Report saved to: %s" % report_path)
