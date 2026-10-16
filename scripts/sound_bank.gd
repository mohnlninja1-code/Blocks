extends Node
"""Sound event dispatch with a small voice pool. Missing optional clips fail quietly."""

const MAX_VOICES := 8
var _paths: Dictionary = {}
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _warned_missing: Dictionary = {}

func _ready() -> void:
	for index in range(MAX_VOICES):
		var player := AudioStreamPlayer.new()
		player.name = "Voice%02d" % index
		add_child(player)
		_players.append(player)
	_load_manifest()

func _load_manifest() -> void:
	var path := "res://data/sounds.json"
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		for event_name in parsed:
			var resource_path := String(parsed[event_name])
			if resource_path.begins_with("res://"):
				_paths[String(event_name)] = resource_path

func register_sound(event_name: String, resource_path: String) -> void:
	if event_name.is_empty() or resource_path.is_empty():
		return
	_paths[event_name] = resource_path
	_streams.erase(event_name)

func play(event_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> bool:
	if not _paths.has(event_name):
		return false
	var stream: AudioStream
	if _streams.has(event_name):
		stream = _streams[event_name]
	else:
		var path := String(_paths[event_name])
		if not ResourceLoader.exists(path):
			if not _warned_missing.has(event_name):
				push_warning("Sound event has no packaged clip: %s (%s)" % [event_name, path])
				_warned_missing[event_name] = true
			return false
		stream = load(path) as AudioStream
		if stream == null:
			return false
		_streams[event_name] = stream
	var player: AudioStreamPlayer
	for candidate in _players:
		if not candidate.playing:
			player = candidate
			break
	if player == null and _players.size() < MAX_VOICES:
		player = AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	if player == null:
		return false
	player.stream = stream
	player.volume_db = clampf(volume_db, -60.0, 6.0)
	player.pitch_scale = clampf(pitch_scale, 0.5, 2.0)
	player.play()
	return true

func stop_all() -> void:
	for player in _players:
		player.stop()
