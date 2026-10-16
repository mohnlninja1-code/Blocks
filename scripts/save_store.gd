extends Node
"""Crash-conscious single-player save storage. World data remains JSON-serializable."""

const FORMAT_VERSION := 2
const SAVE_ROOT := "user://worlds"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_ROOT))

func _safe_slot(slot: String) -> String:
	var result := slot.strip_edges().to_lower()
	result = result.replace("/", "_").replace("\\", "_").replace(":", "_")
	result = result.replace("..", "_")
	if result.is_empty():
		result = "world"
	return result

func _path_for(slot: String) -> String:
	return SAVE_ROOT.path_join(_safe_slot(slot) + ".json")

func save_world(slot: String, world_state: Dictionary) -> Dictionary:
	var path := _path_for(slot)
	var temporary := path + ".tmp"
	var backup := path + ".bak"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_ROOT))
	var document := {
		"format_version": FORMAT_VERSION,
		"slot": _safe_slot(slot),
		"saved_unix_time": int(Time.get_unix_time_from_system()),
		"world": world_state.duplicate(true)
	}
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Cannot open temporary save: %s" % error_string(FileAccess.get_open_error())}
	file.store_string(JSON.stringify(document))
	file.flush()
	file.close()

	var absolute_path := ProjectSettings.globalize_path(path)
	var absolute_backup := ProjectSettings.globalize_path(backup)
	var absolute_temporary := ProjectSettings.globalize_path(temporary)
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(absolute_backup)
		var rotate_error := DirAccess.rename_absolute(absolute_path, absolute_backup)
		if rotate_error != OK:
			DirAccess.remove_absolute(absolute_temporary)
			return {"ok": false, "error": "Cannot rotate previous save: %s" % error_string(rotate_error)}

	var move_error := DirAccess.rename_absolute(absolute_temporary, absolute_path)
	if move_error != OK:
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(absolute_backup, absolute_path)
		if FileAccess.file_exists(temporary):
			DirAccess.remove_absolute(absolute_temporary)
		return {"ok": false, "error": "Cannot commit save: %s" % error_string(move_error)}

	return {"ok": true, "path": path, "format_version": FORMAT_VERSION}

func _read_document(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var raw := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(raw) != OK:
		return {}
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return {}
	var version := int(parsed.get("format_version", 0))
	if version < 1 or version > FORMAT_VERSION:
		return {}
	if not parsed.get("world", {}) is Dictionary:
		return {}
	return parsed

func load_world(slot: String) -> Dictionary:
	var primary := _read_document(_path_for(slot))
	if not primary.is_empty():
		return {"ok": true, "recovered_from_backup": false, "world": primary["world"], "format_version": int(primary["format_version"])}
	var backup := _read_document(_path_for(slot) + ".bak")
	if not backup.is_empty():
		return {"ok": true, "recovered_from_backup": true, "world": backup["world"], "format_version": int(backup["format_version"])}
	return {"ok": false, "error": "No valid primary or backup save exists for '%s'." % _safe_slot(slot)}

func list_worlds() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_ROOT))
	var dir := DirAccess.open(SAVE_ROOT)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir() and entry.ends_with(".json") and not entry.ends_with(".bak.json"):
			var slot := entry.trim_suffix(".json")
			var document := _read_document(SAVE_ROOT.path_join(entry))
			if not document.is_empty():
				var world: Dictionary = document.get("world", {})
				result.append({
					"slot": slot,
					"label": String(world.get("world_name", slot)),
					"saved_unix_time": int(document.get("saved_unix_time", 0)),
					"seed": int(world.get("seed", 0)),
					"game_mode": String(world.get("game_mode", "survival"))
				})
		entry = dir.get_next()
	dir.list_dir_end()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("saved_unix_time", 0)) > int(b.get("saved_unix_time", 0)))
	return result
