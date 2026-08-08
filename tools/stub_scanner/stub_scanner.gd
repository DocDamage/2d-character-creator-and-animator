# Stub Scanner — Placeholder detection in production source files
# Scans for TODO, FIXME, placeholder, dummy, and other incomplete implementations.
# Run: godot --headless --script tools/stub_scanner/stub_scanner.gd
extends SceneTree

## === Configuration ==========================================================

const PATTERNS := [
	{"regex": "(?i)todo\\b", "label": "TODO", "severity": "warning"},
	{"regex": "(?i)fixme\\b", "label": "FIXME", "severity": "error"},
	{"regex": "(?i)placeholder", "label": "PLACEHOLDER", "severity": "error"},
	{"regex": "(?i)not.?implemented", "label": "NOT_IMPLEMENTED", "severity": "error"},
	{"regex": "(?i)\\bdummy\\b", "label": "DUMMY", "severity": "error"},
	{"regex": "(?i)mock.?only", "label": "MOCK_ONLY", "severity": "error"},
	{"regex": "(?i)temporary\\s+return", "label": "TEMPORARY_RETURN", "severity": "error"},
	{"regex": "(?i)disabled\\s+feature", "label": "DISABLED_FEATURE", "severity": "error"},
	{"regex": "(?i)empty\\s+callback", "label": "EMPTY_CALLBACK", "severity": "warning"},
	{"regex": "(?i)debug.?only\\s+success", "label": "DEBUG_ONLY_SUCCESS", "severity": "error"},
	{"regex": "(?i)stub\\b", "label": "STUB", "severity": "error"},
	{"regex": "(?i)hack\\b", "label": "HACK", "severity": "warning"},
	{"regex": "(?i)workaround", "label": "WORKAROUND", "severity": "warning"},
]

const SCAN_EXTENSIONS := ["gd", "cs", "py"]
const EXCLUDED_DIRS := [
	".godot",
	"addons",
	"autosave",
	"backups",
	"exported",
	"user",
	"docs",
	"samples",
	"tests",
	"tools",
]
const EXCLUDED_FILES := [
	"project.godot",
	".gitignore",
]

var _findings: Array[Dictionary] = []
var _classified: Dictionary = {}
var _files_scanned := 0

## === Entry Point ============================================================

func _init() -> void:
	print("=== Stub Scanner v1.0.0 ===")
	print("Patterns: %d" % PATTERNS.size())
	print("")
	_scan_directory("res://")
	_print_results()
	_save_report()
	var has_errors := false
	for finding in _findings:
		if finding["severity"] == "error":
			has_errors = true
			break
	quit(0 if not has_errors else 1)


## === Scanning ===============================================================

func _scan_directory(dir_path: String) -> void:
	var da := DirAccess.open(dir_path)
	if da == null:
		return

	da.list_dir_begin()
	var entry := da.get_next()
	while entry != "":
		if da.current_is_dir():
			if entry not in EXCLUDED_DIRS and not entry.begins_with("."):
				_scan_directory(dir_path.path_join(entry))
		else:
			if entry not in EXCLUDED_FILES and _has_scannable_extension(entry):
				_scan_file(dir_path.path_join(entry))
		entry = da.get_next()
	da.list_dir_end()


func _has_scannable_extension(file_name: String) -> bool:
	var ext := file_name.get_extension().to_lower()
	return ext in SCAN_EXTENSIONS


func _scan_file(file_path: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return

	var line_number := 0
	while file.get_position() < file.get_length():
		var line := file.get_line()
		line_number += 1
		for pattern in PATTERNS:
			var regex := RegEx.new()
			var err := regex.compile(pattern["regex"])
			if err != OK:
				continue
			var result := regex.search(line)
			if result:
				if _is_allowed_usage(str(pattern["label"]), line):
					continue
				var match_text := result.get_string().strip_edges()
				var context := _get_context(line)
				var finding := {
					"file": file_path,
					"line": line_number,
					"label": pattern["label"],
					"severity": pattern["severity"],
					"match": match_text,
					"context": context,
				}
				_findings.append(finding)
				_classify(finding)
				break  # One classification per line
	file.close()
	_files_scanned += 1


## UI placeholder copy and helper parameter names describe real input guidance;
## they are not incomplete implementation markers.
func _is_allowed_usage(label: String, line: String) -> bool:
	if label != "PLACEHOLDER":
		return false
	return "placeholder_text" in line or "placeholder: String" in line


func _get_context(line: String) -> String:
	var stripped := line.strip_edges()
	if stripped.length() > 120:
		stripped = stripped.substr(0, 120) + "..."
	return stripped


func _classify(finding: Dictionary) -> void:
	var label: String = finding["label"]
	if not _classified.has(label):
		_classified[label] = 0
	_classified[label] += 1


## === Output =================================================================

func _print_results() -> void:
	print("Scanned %d files." % _files_scanned)
	print("")

	if _findings.is_empty():
		print("PASS: No stubs or placeholders found.")
		return

	print("Found %d potential stub(s) / placeholder(s):" % _findings.size())
	print("-".repeat(80))
	for finding in _findings:
		var severity_tag := "[%s]" % finding["severity"].to_upper()
		print("  %-10s %s:%d  %s" % [severity_tag, finding["file"], finding["line"], finding["label"]])
		print("           %s" % finding["context"])
	print("-".repeat(80))

	print("")
	print("Classification summary:")
	for label in _classified:
		print("  %-25s %d occurrence(s)" % [label, _classified[label]])

	print("")
	print("Findings must be classified and addressed:")
	print("  - TODO/FIXME: Must have a tracking task or be resolved.")
	print("  - PLACEHOLDER/NOT_IMPLEMENTED/DUMMY/STUB: Must be replaced with real implementation.")
	print("  - MOCK_ONLY/TEMPORARY_RETURN/EMPTY_CALLBACK: Must not exist in production paths.")
	print("  - HACK/WORKAROUND: Must have documented justification.")


func _save_report() -> void:
	var report_path := "res://docs/implementation/evidence/GOV-005/stub_report.txt"
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write report to: %s" % report_path)
		return

	file.store_string("=== Stub Scanner Report ===\n")
	file.store_string("Generated: %s\n" % Time.get_datetime_string_from_system())
	file.store_string("Files scanned: %d\n" % _files_scanned)
	file.store_string("Findings: %d\n\n" % _findings.size())

	for finding in _findings:
		file.store_string("  [%s] %s:%d  %s\n" % [
			finding["severity"].to_upper(),
			finding["file"],
			finding["line"],
			finding["label"],
		])
		file.store_string("       %s\n" % finding["context"])

	file.store_string("\nClassification:\n")
	for label in _classified:
		file.store_string("  %s: %d\n" % [label, _classified[label]])

	file.close()
	print("Report saved to: %s" % report_path)
