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
	"user",
]
const EXCLUDED_FILES := [
	"project.godot",
	".gitignore",
]

var _results: Array[Dictionary] = []
var _violations := 0
var _total_files := 0

## === Entry Point ============================================================

func _init() -> void:
	print("=== LOC Checker v1.0.0 ===")
	print("Line limit: %d lines" % LINE_LIMIT)
	print("")
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

	var result := {
		"path": file_path,
		"lines": line_count,
		"violation": line_count > LINE_LIMIT,
	}
	_results.append(result)

	if result["violation"]:
		_violations += 1


## === Output =================================================================

func _print_results() -> void:
	print("Scanned %d files." % _total_files)
	print("")

	if _violations == 0:
		print("PASS: No files exceed the %d-line limit." % LINE_LIMIT)
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

	for result in _results:
		var status := "PASS" if not result["violation"] else "FAIL"
		file.store_string("%4s  %4d lines  %s\n" % [status, result["lines"], result["path"]])

	file.close()
	print("Report saved to: %s" % report_path)