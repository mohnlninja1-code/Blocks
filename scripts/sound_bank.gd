extends Node
"""Sound events resolved from the user-supplied Minecraft 1.18.2 sounds.json and OGG files."""

const MAX_VOICES := 12
const SOUND_MANIFEST := "res://assets/minecraft/sounds.json"
const MAX_EVENT_DEPTH := 12

var _events: Dictionary = {}
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _warned_missing: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	for index in range(MAX_VOICES):
		var player := AudioStreamPlayer.new()
		player.name = "Voice%02d" % index
		add_child(player)
		_players.append(player)
	_load_manifest()

func _load_manifest() -> bool:
	if not FileAccess.file_exists(SOUND_MANIFEST):
		_events.clear()
		return false
	var parser := JSON.new()
	var error := parser.parse(FileAccess.get_file_as_string(SOUND_MANIFEST))
	if error != OK or not parser.data is Dictionary:
		push_error("Invalid supplied sounds.json: %s" % parser.get_error_message())
		_events.clear()
		return false
	_events = parser.data
	return true

func reload_manifest() -> bool:
	_streams.clear()
	_warned_missing.clear()
	return _load_manifest()

func has_event(event_name: String) -> bool:
	return _events.has(event_name)

func event_names() -> PackedStringArray:
	var result := PackedStringArray()
	for key in _events.keys():
		result.append(String(key))
	result.sort()
	return result

func _sound_path(sound_name: String) -> String:
	var name := sound_name.trim_prefix("minecraft:")
	if name.is_empty() or name.begins_with("/") or ".." in name or "\\" in name:
		return ""
	if name.ends_with(".ogg"):
		name = name.trim_suffix(".ogg")
	return "res://assets/minecraft/sounds/%s.ogg" % name

func _expand_sound_entry(entry: Variant, base_volume: float, base_pitch: float, depth: int, visited: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if depth > MAX_EVENT_DEPTH:
		return result
	var name := ""
	var sound_type := "file"
	var volume := base_volume
	var pitch := base_pitch
	var weight := 1
	if entry is String:
		name = String(entry)
	elif entry is Dictionary:
		var definition: Dictionary = entry
		name = String(definition.get("name", ""))
		sound_type = String(definition.get("type", "file"))
		volume *= clampf(float(definition.get("volume", 1.0)), 0.0, 4.0)
		pitch *= clampf(float(definition.get("pitch", 1.0)), 0.25, 4.0)
		weight = clampi(int(definition.get("weight", 1)), 1, 1000000)
	else:
		return result
	if name.is_empty():
		return result
	if sound_type == "event":
		if name in visited or not _events.has(name):
			return result
		var chain := visited.duplicate()
		chain.append(name)
		var target: Variant = _events[name]
		if target is Dictionary:
			for nested in target.get("sounds", []):
				for resolved in _expand_sound_entry(nested, volume, pitch, depth + 1, chain):
					result.append(resolved)
		return result
	var path := _sound_path(name)
	if path.is_empty() or not ResourceLoader.exists(path):
		return result
	result.append({"path": path, "volume": volume, "pitch": pitch, "weight": weight})
	return result

func _choose_sample(event_name: String) -> Dictionary:
	var event_value: Variant = _events.get(event_name, {})
	if not event_value is Dictionary:
		return {}
	var event_definition: Dictionary = event_value
	var base_volume := clampf(float(event_definition.get("volume", 1.0)), 0.0, 4.0)
	var base_pitch := clampf(float(event_definition.get("pitch", 1.0)), 0.25, 4.0)
	var candidates: Array[Dictionary] = []
	for entry in event_definition.get("sounds", []):
		var expanded := _expand_sound_entry(entry, base_volume, base_pitch, 0, [event_name])
		for candidate in expanded:
			candidates.append(candidate)
	if candidates.is_empty():
		if not _warned_missing.has(event_name):
			push_warning("No packaged audio clip resolved from supplied 1.18.2 event: %s" % event_name)
			_warned_missing[event_name] = true
		return {}
	var total_weight := 0
	for candidate in candidates:
		total_weight += int(candidate.get("weight", 1))
	var roll := _rng.randi_range(1, maxi(total_weight, 1))
	for candidate in candidates:
		roll -= int(candidate.get("weight", 1))
		if roll <= 0:
			return candidate
	return candidates.back()

func _stream_for_path(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path] as AudioStream
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	if stream != null:
		_streams[path] = stream
	return stream

func _acquire_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	if _players.size() >= MAX_VOICES:
		return null
	var player := AudioStreamPlayer.new()
	player.name = "Voice%02d" % _players.size()
	add_child(player)
	_players.append(player)
	return player

func play(event_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> bool:
	var sample := _choose_sample(event_name)
	if sample.is_empty():
		return false
	var path := String(sample.get("path", ""))
	var stream := _stream_for_path(path)
	if stream == null:
		if not _warned_missing.has(path):
			push_warning("Supplied sound file could not be loaded: %s" % path)
			_warned_missing[path] = true
		return false
	var player := _acquire_player()
	if player == null:
		return false
	var linear_volume := clampf(float(sample.get("volume", 1.0)), 0.0, 4.0)
	var sample_volume_db := linear_to_db(maxf(linear_volume, 0.0001))
	player.stream = stream
	player.volume_db = clampf(volume_db + sample_volume_db, -60.0, 6.0)
	var source_pitch := clampf(float(sample.get("pitch", 1.0)), 0.25, 4.0)
	player.pitch_scale = clampf(pitch_scale * source_pitch * _rng.randf_range(0.96, 1.04), 0.5, 2.0)
	player.play()
	return true

func play_block(block_name: String, action: String) -> bool:
	var name := block_name.to_lower()
	var group := "stone"
	if name.contains("grass") or name == "dirt" or name.contains("rooted_dirt") or name.contains("mud"):
		group = "grass"
	elif name.contains("sand") or name.contains("gravel") or name.contains("suspicious_gravel"):
		group = "gravel"
	elif name.contains("log") or name.contains("wood") or name.contains("plank") or name.contains("crafting_table") or name.contains("chest"):
		group = "wood"
	elif name.contains("leaves") or name.contains("flower") or name.contains("fern") or name.contains("sapling") or name.contains("crop"):
		group = "grass"
	var event_name := "block.%s.%s" % [group, action]
	if has_event(event_name):
		return play(event_name)
	return play("block.stone.%s" % action) if has_event("block.stone.%s" % action) else false

func stop_all() -> void:
	for player in _players:
		player.stop()
