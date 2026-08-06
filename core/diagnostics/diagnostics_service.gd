# DiagnosticsService — Centralized diagnostics, logging, and error reporting
# Autoload: DiagnosticsService
# Collects, categorizes, and persists diagnostic messages for the diagnostics drawer.
extends Node

## === Constants ==============================================================

enum Level {
	TRACE,
	DEBUG,
	INFO,
	WARNING,
	ERROR,
	FATAL,
}

const LEVEL_NAMES := {
	Level.TRACE: "trace",
	Level.DEBUG: "debug",
	Level.INFO: "info",
	Level.WARNING: "warning",
	Level.ERROR: "error",
	Level.FATAL: "fatal",
}

const MAX_ENTRIES := 1000

## === Signals ================================================================

signal entry_added(entry: Dictionary)
signal count_changed(counts: Dictionary)
signal filter_changed(active_levels: Array)

## === State ==================================================================

var _entries: Array[Dictionary] = []
var _counts: Dictionary = {}
var _active_filter: Array[int] = [Level.INFO, Level.WARNING, Level.ERROR, Level.FATAL]
var _enabled: bool = true

## === Lifecycle ==============================================================

func _ready() -> void:
	_clear_counts()


## === Public API — Logging ==================================================

func trace(message: String, source: String = "") -> void:
	_add_entry(Level.TRACE, message, source)


func debug(message: String, source: String = "") -> void:
	_add_entry(Level.DEBUG, message, source)


func info(message: String, source: String = "") -> void:
	_add_entry(Level.INFO, message, source)


func warn(message: String, source: String = "") -> void:
	_add_entry(Level.WARNING, message, source)


func error(message: String, source: String = "") -> void:
	_add_entry(Level.ERROR, message, source)


func fatal(message: String, source: String = "") -> void:
	_add_entry(Level.FATAL, message, source)


func log(level: int, message: String, source: String = "") -> void:
	_add_entry(level, message, source)


## === Public API — Query =====================================================

func get_entries(filter_levels: Array = []) -> Array[Dictionary]:
	if filter_levels.is_empty():
		filter_levels = _active_filter
	var result: Array[Dictionary] = []
	for entry in _entries:
		if entry["level"] in filter_levels:
			result.append(entry)
	return result


func get_filtered_entries() -> Array[Dictionary]:
	return get_entries(_active_filter)


func get_count(level: int = -1) -> int:
	if level < 0:
		var total := 0
		for count in _counts.values():
			total += count
		return total
	return _counts.get(level, 0)


func get_counts() -> Dictionary:
	return _counts.duplicate()


func get_recent(count: int = 50) -> Array[Dictionary]:
	var start: int = max(0, _entries.size() - count)
	return _entries.slice(start)


func get_errors() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _entries:
		if entry["level"] >= Level.ERROR:
			result.append(entry)
	return result


## === Public API — Filter ====================================================

func set_filter(levels: Array) -> void:
	var typed_levels: Array[int] = []
	for l in levels:
		typed_levels.append(l as int)
	_active_filter = typed_levels
	filter_changed.emit(typed_levels)



func clear_filter() -> void:
	_active_filter = [Level.INFO, Level.WARNING, Level.ERROR, Level.FATAL]
	filter_changed.emit(_active_filter)


func get_active_filter() -> Array:
	return _active_filter.duplicate()


## === Public API — Management ================================================

func clear() -> void:
	_entries.clear()
	_clear_counts()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled


func is_enabled() -> bool:
	return _enabled


func export_entries() -> String:
	var lines := PackedStringArray()
	for entry in _entries:
		var ts := entry.get("timestamp", 0) as int
		var dt := Time.get_datetime_string_from_unix_time(ts)
		var level_name: String = LEVEL_NAMES.get(entry.get("level", Level.INFO), "unknown")
		var source: String = entry.get("source", "")
		var msg: String = entry.get("message", "")
		var line := "%s [%s] %s: %s" % [dt, level_name.to_upper(), source, msg]
		lines.append(line)
	return "\n".join(lines)


## === Internal ===============================================================

func _add_entry(level: int, message: String, source: String) -> void:
	if not _enabled:
		return
	var entry := {
		"level": level,
		"level_name": LEVEL_NAMES.get(level, "unknown"),
		"message": message,
		"source": source,
		"timestamp": Time.get_unix_time_from_system(),
		"frame": Engine.get_process_frames(),
	}
	_entries.append(entry)
	if _counts.has(level):
		_counts[level] += 1
	else:
		_counts[level] = 1
	if _entries.size() > MAX_ENTRIES:
		_entries.pop_front()
	entry_added.emit(entry)
	count_changed.emit(_counts.duplicate())


func _clear_counts() -> void:
	for lvl in Level.values():
		_counts[lvl] = 0