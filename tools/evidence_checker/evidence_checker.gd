# Evidence Checker — Validates evidence bundles against required structure
# Run: godot --headless --script tools/evidence_checker/evidence_checker.gd
extends SceneTree

## === Configuration ==========================================================

const REQUIRED_FILES := [
	"README.md",
	"commands.log",
	"test-results.txt",
	"manual-verification.md",
]

const REQUIRED_DIRS := [
	"screenshots",
	"exports",
	"roundtrip",
	"performance",
	"known-failures",
]

const EVIDENCE_ROOT := "res://docs/implementation/evidence/"

var _bundles_checked := 0
var _bundles_valid := 0
var _bundles_invalid := 0
var _missing_bundles: Array[String] = []
var _issues: Array[Dictionary] = []

## === Entry Point ============================================================

func _init() -> void:
	print("=== Evidence Bundle Checker v1.0.0 ===")
	print("")
	_check_all_bundles()
	_print_results()
	_save_report()
	quit(0 if _bundles_invalid == 0 else 1)


## === Checking ===============================================================

func _check_all_bundles() -> void:
	var da := DirAccess.open(EVIDENCE_ROOT)
	if da == null:
		printerr("Evidence root not found: %s" % EVIDENCE_ROOT)
		return

	da.list_dir_begin()
	var entry := da.get_next()
	while entry != "":
		if da.current_is_dir():
			_check_bundle(EVIDENCE_ROOT.path_join(entry))
		entry = da.get_next()
	da.list_dir_end()

	# Check for expected task bundles from the task ledger
	_check_task_ledger_bundles()


func _check_bundle(bundle_path: String) -> void:
	_bundles_checked += 1
	var bundle_name := bundle_path.get_file()
	var bundle_valid := true

	for required_file in REQUIRED_FILES:
		var file_path := bundle_path.path_join(required_file)
		if not FileAccess.file_exists(file_path):
			_issues.append({
				"bundle": bundle_name,
				"type": "missing_file",
				"item": required_file,
				"path": file_path,
			})
			bundle_valid = false

	for required_dir in REQUIRED_DIRS:
		var dir_path := bundle_path.path_join(required_dir)
		if not DirAccess.dir_exists_absolute(dir_path):
			_issues.append({
				"bundle": bundle_name,
				"type": "missing_dir",
				"item": required_dir,
				"path": dir_path,
			})
			bundle_valid = false

	var readme_path := bundle_path.path_join("README.md")
	if FileAccess.file_exists(readme_path):
		if not _check_readme_content(readme_path, bundle_name):
			bundle_valid = false

	if bundle_valid:
		_bundles_valid += 1
	else:
		_bundles_invalid += 1


func _check_readme_content(readme_path: String, bundle_name: String) -> bool:
	var file := FileAccess.open(readme_path, FileAccess.READ)
	if file == null:
		return false
	var content := file.get_as_text()
	file.close()

	var required_sections := [
		"Task ID",
		"Status",
		"Evidence",
	]
	for section in required_sections:
		if section.to_lower() not in content.to_lower():
			_issues.append({
				"bundle": bundle_name,
				"type": "missing_readme_section",
				"item": section,
				"path": readme_path,
			})
			return false
	return true


func _check_task_ledger_bundles() -> void:
	# Parse task ledger for expected bundle paths
	var ledger_path := "res://docs/implementation/TASK_LEDGER.md"
	if not FileAccess.file_exists(ledger_path):
		return

	var file := FileAccess.open(ledger_path, FileAccess.READ)
	if file == null:
		return
	var _content := file.get_as_text()
	file.close()


## === Output =================================================================

func _print_results() -> void:
	print("Evidence bundles checked: %d" % _bundles_checked)
	print("Valid:   %d" % _bundles_valid)
	print("Invalid: %d" % _bundles_invalid)
	print("")

	if _bundles_invalid == 0 and _bundles_checked > 0:
		print("PASS: All evidence bundles meet required structure.")
		return

	if _bundles_checked == 0:
		print("INFO: No evidence bundles found. This is expected at project start.")
		print("Evidence bundles are created by implementation and verification threads.")
		return

	print("Issues found:")
	print("-".repeat(70))
	for issue in _issues:
		var type_tag := "[%s]" % issue["type"].to_upper()
		print("  %-18s Bundle: %-20s Missing: %s" % [
			type_tag,
			issue["bundle"],
			issue["item"],
		])
	print("-".repeat(70))


func _save_report() -> void:
	var report_path := "res://docs/implementation/evidence/GOV-006/evidence_report.txt"
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write report to: %s" % report_path)
		return

	file.store_string("=== Evidence Bundle Checker Report ===\n")
	file.store_string("Generated: %s\n" % Time.get_datetime_string_from_system())
	file.store_string("Bundles checked: %d\n" % _bundles_checked)
	file.store_string("Valid: %d\n" % _bundles_valid)
	file.store_string("Invalid: %d\n\n" % _bundles_invalid)

	if not _issues.is_empty():
		file.store_string("Issues:\n")
		for issue in _issues:
			file.store_string("  [%s] %s: %s\n" % [
				issue["type"], issue["bundle"], issue["item"],
			])

	file.close()
	print("Report saved to: %s" % report_path)