extends Node3D
"""Chunked, seed-driven voxel storage/rendering foundation. Vanilla parity is not yet implemented."""

const CHUNK_SIZE := 16
const MIN_Y := -64
const MAX_Y := 319
const CHUNK_HEIGHT := MAX_Y - MIN_Y + 1
const CHUNK_VOLUME := CHUNK_SIZE * CHUNK_SIZE * CHUNK_HEIGHT
const FACE_NAMES := ["top", "bottom", "north", "south", "east", "west"]
const FACE_OFFSETS := [Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, -1), Vector3i(0, 0, 1), Vector3i(1, 0, 0), Vector3i(-1, 0, 0)]
const FACE_NORMALS := [Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK, Vector3.RIGHT, Vector3.LEFT]
const TRIANGLE_ORDER := [0, 1, 2, 0, 2, 3]
const FACE_UVS := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]

var world_seed: int = 1
var terrain_mode := "overworld" # Java 1.18.2 default world type; Superflat remains an optional preset.
var _chunks: Dictionary = {}
var _edits: Dictionary = {} # Vector3i -> block ID; ID 0 explicitly records a removed block.
var _state_edits: Dictionary = {} # Vector3i -> exact authored block-state properties.
var _terrain_noise := FastNoiseLite.new()
var _cave_noise := FastNoiseLite.new()
var _continentalness_noise := FastNoiseLite.new()
var _erosion_noise := FastNoiseLite.new()
var _ridge_noise := FastNoiseLite.new()
var _temperature_noise := FastNoiseLite.new()
var _humidity_noise := FastNoiseLite.new()
var _river_noise := FastNoiseLite.new()
var _feature_noise := FastNoiseLite.new()
var _stream_center := Vector2i(2147483647, 2147483647)
var _view_radius := 1
var _materials: Dictionary = {}
var _model_loader: Variant
var _state_model_basis_cache: Dictionary = {}
var _build_meshes := true

func _ready() -> void:
	_configure_noise(world_seed)
	var blockstate_root := ProjectSettings.globalize_path("res://assets/minecraft/blockstates")
	if DirAccess.dir_exists_absolute(blockstate_root):
		var loader_script: Script = load("res://scripts/minecraft_model_loader.gd")
		if loader_script != null:
			_model_loader = loader_script.new("res://assets/minecraft")
	else:
		_model_loader = null

func configure_model_root(resource_root: String) -> void:
	var loader_script: Script = load("res://scripts/minecraft_model_loader.gd")
	if loader_script == null:
		_model_loader = null
		return
	_model_loader = loader_script.new(resource_root)

func _configure_noise(new_seed: int) -> void:
	# Keep the earlier noise generator configured for compatibility with existing test/prototype saves.
	_terrain_noise.seed = new_seed
	_terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_terrain_noise.frequency = 0.035
	_terrain_noise.fractal_octaves = 3
	_terrain_noise.fractal_lacunarity = 2.0
	_cave_noise.seed = new_seed + 7919
	_cave_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_cave_noise.frequency = 0.055
	_cave_noise.fractal_octaves = 2

	_continentalness_noise.seed = new_seed + 1013
	_continentalness_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_continentalness_noise.frequency = 0.0022
	_continentalness_noise.fractal_octaves = 4
	_continentalness_noise.fractal_lacunarity = 2.0
	_erosion_noise.seed = new_seed + 2017
	_erosion_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_erosion_noise.frequency = 0.009
	_erosion_noise.fractal_octaves = 3
	_ridge_noise.seed = new_seed + 3011
	_ridge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_ridge_noise.frequency = 0.0065
	_ridge_noise.fractal_octaves = 4
	_temperature_noise.seed = new_seed + 4001
	_temperature_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_temperature_noise.frequency = 0.0018
	_temperature_noise.fractal_octaves = 3
	_humidity_noise.seed = new_seed + 5003
	_humidity_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_humidity_noise.frequency = 0.0021
	_humidity_noise.fractal_octaves = 3
	_river_noise.seed = new_seed + 6007
	_river_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_river_noise.frequency = 0.008
	_river_noise.fractal_octaves = 2
	_feature_noise.seed = new_seed + 7001
	_feature_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_feature_noise.frequency = 0.13
	_feature_noise.fractal_octaves = 2

func set_terrain_mode(mode_name: String) -> void:
	# "noise" remains available only so older prototype saves can still be loaded.
	terrain_mode = mode_name if mode_name in ["overworld", "superflat", "noise"] else "overworld"

func _climate_temperature(world_x: int, world_z: int) -> float:
	var broad := _temperature_noise.get_noise_2d(float(world_x), float(world_z))
	var detail := _feature_noise.get_noise_2d(float(world_x) * 0.22, float(world_z) * 0.22)
	return clampf(broad * 0.78 + detail * 0.22, -1.0, 1.0)

func _climate_humidity(world_x: int, world_z: int) -> float:
	var broad := _humidity_noise.get_noise_2d(float(world_x), float(world_z))
	var detail := _ridge_noise.get_noise_2d(float(world_x) * 0.37, float(world_z) * 0.37)
	return clampf(broad * 0.8 - detail * 0.2, -1.0, 1.0)

func _continentalness(world_x: int, world_z: int) -> float:
	return _continentalness_noise.get_noise_2d(float(world_x), float(world_z))

func _is_river_location(world_x: int, world_z: int) -> bool:
	return absf(_river_noise.get_noise_2d(float(world_x), float(world_z))) < 0.045 and _continentalness(world_x, world_z) > -0.28

func _overworld_surface_height(world_x: int, world_z: int) -> int:
	var continent := _continentalness(world_x, world_z)
	if continent < -0.48:
		return clampi(42 + roundi((continent + 1.0) * 30.0), MIN_Y + 8, 62)
	if _is_river_location(world_x, world_z):
		return 60
	if continent < -0.25:
		return clampi(60 + roundi((continent + 0.48) * 12.0), 60, 65)
	var erosion := _erosion_noise.get_noise_2d(float(world_x), float(world_z))
	var ridges := _ridge_noise.get_noise_2d(float(world_x), float(world_z))
	var local_detail := _terrain_noise.get_noise_2d(float(world_x), float(world_z))
	var mountain_factor := maxf(0.0, ridges - 0.22) / 0.78
	var height := 64.0 + maxf(0.0, continent + 0.25) * 35.0 + erosion * 8.0 + mountain_factor * 88.0 + local_detail * 4.0
	return clampi(roundi(height), 58, 190)

func biome_at(world_x: int, world_z: int) -> String:
	"""Deterministic biome-family assignment using Java 1.18.2 biome names.
	This is an explicit worldgen prototype, not a claim of vanilla noise-settings parity."""
	var continent := _continentalness(world_x, world_z)
	var temperature := _climate_temperature(world_x, world_z)
	var humidity := _climate_humidity(world_x, world_z)
	var elevation := _overworld_surface_height(world_x, world_z)
	var ridges := _ridge_noise.get_noise_2d(float(world_x), float(world_z))

	if continent < -0.48:
		if continent < -0.68:
			if temperature > 0.55: return "deep_lukewarm_ocean"
			if temperature > 0.0: return "deep_ocean"
			if temperature > -0.55: return "deep_cold_ocean"
			return "deep_frozen_ocean"
		if temperature > 0.62: return "warm_ocean"
		if temperature > 0.24: return "lukewarm_ocean"
		if temperature > -0.22: return "ocean"
		if temperature > -0.62: return "cold_ocean"
		return "frozen_ocean"
	if continent < -0.28:
		if temperature < -0.45: return "snowy_beach"
		if elevation > 63: return "stony_shore"
		return "beach"
	if _is_river_location(world_x, world_z):
		return "frozen_river" if temperature < -0.58 else "river"
	if elevation > 145:
		if temperature < -0.35: return "frozen_peaks"
		if temperature < 0.15: return "jagged_peaks"
		return "stony_peaks"
	if elevation > 112:
		if temperature < -0.3: return "snowy_slopes"
		return "meadow" if humidity > -0.1 else "windswept_hills"
	if elevation > 94 and temperature < -0.25:
		return "grove"
	if temperature < -0.68:
		if humidity > 0.15: return "snowy_taiga"
		return "ice_spikes" if ridges > 0.45 else "snowy_plains"
	if temperature < -0.38:
		if humidity > 0.25: return "old_growth_spruce_taiga"
		return "taiga"
	if temperature < -0.08:
		if humidity > 0.45: return "old_growth_birch_forest"
		if humidity < -0.4: return "windswept_forest"
		return "forest"
	if temperature < 0.35:
		if humidity > 0.58: return "swamp"
		if humidity > 0.2 and ridges > 0.35: return "flower_forest"
		if humidity < -0.45: return "plains"
		if humidity > 0.45: return "birch_forest"
		return "plains" if ridges < 0.0 else "forest"
	if temperature < 0.63:
		if humidity < -0.38: return "savanna"
		if humidity > 0.65: return "jungle" if ridges > 0.2 else "sparse_jungle"
		if humidity > 0.32: return "forest"
		return "savanna"
	if humidity < -0.2:
		return "eroded_badlands" if ridges > 0.45 else "desert"
	if humidity < 0.1:
		return "badlands"
	if humidity > 0.5:
		return "bamboo_jungle" if ridges > 0.28 else "jungle"
	return "savanna"

func _runtime_block_id(block_name: String, fallback_id: int) -> int:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		var registry: Variant = tree.root.get_node_or_null("BlockRegistry")
		if registry != null:
			var resolved := int(registry.block_id(block_name))
			if resolved > 0:
				return resolved
	return fallback_id

func surface_height_at(world_x: int, world_z: int) -> int:
	if terrain_mode == "superflat":
		return 3
	if terrain_mode == "overworld":
		return _overworld_surface_height(world_x, world_z)
	return clampi(66 + roundi(_terrain_noise.get_noise_2d(float(world_x), float(world_z)) * 14.0), MIN_Y + 8, MAX_Y - 8)

func generate_world(new_seed: int, view_radius: int = 1, build_meshes: bool = true) -> void:
	_build_meshes = build_meshes
	for key in _chunks:
		var old_chunk: Dictionary = _chunks[key]
		var old_root: Node3D = old_chunk.get("root")
		if is_instance_valid(old_root):
			old_root.queue_free()
	_chunks.clear()
	_edits.clear()
	_state_edits.clear()
	world_seed = new_seed
	_view_radius = clampi(view_radius, 1, 4)
	_stream_center = Vector2i(2147483647, 2147483647)
	_configure_noise(world_seed)
	update_streaming(Vector3.ZERO, _view_radius)

func load_state(state: Dictionary, view_radius: int = 1, build_meshes: bool = true) -> bool:
	var new_seed := int(state.get("seed", 1))
	set_terrain_mode(String(state.get("terrain_mode", "noise")))
	generate_world(new_seed, view_radius, build_meshes)
	var raw_edits: Variant = state.get("edits", [])
	if not raw_edits is Array:
		return false
	for row in raw_edits:
		if not row is Array or row.size() != 4:
			continue
		var point := Vector3i(int(row[0]), int(row[1]), int(row[2]))
		var id := int(row[3])
		if point.y < MIN_Y or point.y > MAX_Y or id < 0:
			continue
		_edits[point] = id
	var raw_state_edits: Variant = state.get("state_edits", [])
	if raw_state_edits is Array:
		for row in raw_state_edits:
			if not row is Array or row.size() != 4 or not row[3] is Dictionary:
				continue
			var state_point := Vector3i(int(row[0]), int(row[1]), int(row[2]))
			if state_point.y < MIN_Y or state_point.y > MAX_Y:
				continue
			_state_edits[state_point] = (row[3] as Dictionary).duplicate(true)
	for key in _chunks:
		_apply_edits_to_chunk(key)
	for key in _chunks:
		_rebuild_chunk(key)
	return true

func save_state() -> Dictionary:
	var rows: Array = []
	for point_value in _edits.keys():
		var point: Vector3i = point_value
		rows.append([point.x, point.y, point.z, int(_edits[point])])
	rows.sort_custom(func(a: Array, b: Array) -> bool:
		if int(a[0]) != int(b[0]): return int(a[0]) < int(b[0])
		if int(a[1]) != int(b[1]): return int(a[1]) < int(b[1])
		return int(a[2]) < int(b[2]))
	var state_rows: Array = []
	for point_value in _state_edits.keys():
		var point: Vector3i = point_value
		state_rows.append([point.x, point.y, point.z, (_state_edits[point] as Dictionary).duplicate(true)])
	state_rows.sort_custom(func(a: Array, b: Array) -> bool:
		if int(a[0]) != int(b[0]): return int(a[0]) < int(b[0])
		if int(a[1]) != int(b[1]): return int(a[1]) < int(b[1])
		return int(a[2]) < int(b[2]))
	return {"seed": world_seed, "terrain_mode": terrain_mode, "edits": rows, "state_edits": state_rows, "min_y": MIN_Y, "max_y": MAX_Y}

func find_spawn_position(origin: Vector2i = Vector2i.ZERO, search_radius: int = 16) -> Vector3:
	var best_point := Vector3(float(origin.x) + 0.5, float(surface_height_at(origin.x, origin.y) + 2), float(origin.y) + 0.5)
	var best_score := -INF
	for radius in range(maxi(1, search_radius) + 1):
		for dz in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dz)) != radius:
					continue
				var world_x := origin.x + dx
				var world_z := origin.y + dz
				var biome := biome_at(world_x, world_z) if terrain_mode == "overworld" else ""
				var height := surface_height_at(world_x, world_z)
				var is_water_biome := biome in ["ocean", "deep_ocean", "warm_ocean", "lukewarm_ocean", "cold_ocean", "frozen_ocean", "deep_lukewarm_ocean", "deep_cold_ocean", "deep_frozen_ocean", "river", "frozen_river"]
				if terrain_mode == "overworld" and (is_water_biome or height < 63):
					continue
				var score := -float(dx * dx + dz * dz) + (2.0 if biome in ["plains", "forest", "birch_forest", "meadow"] else 0.0)
				if score > best_score:
					best_score = score
					best_point = Vector3(float(world_x) + 0.5, float(maxi(height, 63) + 2), float(world_z) + 0.5)
		if best_score > -INF:
			return best_point
	return best_point

func update_streaming(player_position: Vector3, radius: int = -1) -> void:
	var wanted_radius := _view_radius if radius < 0 else clampi(radius, 1, 4)
	var center := Vector2i(floori(player_position.x / float(CHUNK_SIZE)), floori(player_position.z / float(CHUNK_SIZE)))
	if center == _stream_center and wanted_radius == _view_radius:
		return
	_view_radius = wanted_radius
	_stream_center = center
	var wanted: Dictionary = {}
	for cz in range(center.y - wanted_radius, center.y + wanted_radius + 1):
		for cx in range(center.x - wanted_radius, center.x + wanted_radius + 1):
			wanted[Vector2i(cx, cz)] = true
	var removed_any := false
	for old_key in _chunks.keys():
		if not wanted.has(old_key):
			var old_chunk: Dictionary = _chunks[old_key]
			var old_root: Node3D = old_chunk.get("root")
			if is_instance_valid(old_root):
				old_root.queue_free()
			_chunks.erase(old_key)
			removed_any = true
	var added_any := false
	for new_key in wanted.keys():
		if not _chunks.has(new_key):
			_load_chunk(new_key)
			added_any = true
	if (added_any or removed_any) and _build_meshes:
		for key in _chunks.keys():
			_rebuild_chunk(key)

func _load_chunk(key: Vector2i) -> void:
	var data := PackedInt32Array()
	data.resize(CHUNK_VOLUME)
	data.fill(0)
	var chunk_root := Node3D.new()
	chunk_root.name = "Chunk_%d_%d" % [key.x, key.y]
	chunk_root.position = Vector3(key.x * CHUNK_SIZE, MIN_Y, key.y * CHUNK_SIZE)
	add_child(chunk_root)
	_chunks[key] = {"data": data, "occupied": {}, "root": chunk_root}
	_generate_chunk_data(key)
	_apply_edits_to_chunk(key)

func _cell_index(local_x: int, y_index: int, local_z: int) -> int:
	return (y_index * CHUNK_SIZE + local_z) * CHUNK_SIZE + local_x

func _generate_chunk_data(key: Vector2i) -> void:
	var chunk: Dictionary = _chunks[key]
	var data: PackedInt32Array = chunk["data"]
	var occupied: Dictionary = chunk.get("occupied", {})
	if terrain_mode == "superflat":
		# Java 1.18.2 Classic Flat preset: bedrock, two dirt layers, grass.
		for local_z in range(CHUNK_SIZE):
			for local_x in range(CHUNK_SIZE):
				for world_y in range(0, 4):
					var flat_block_id := 5 if world_y == 0 else (1 if world_y == 3 else 2)
					var flat_index := _cell_index(local_x, world_y - MIN_Y, local_z)
					data[flat_index] = flat_block_id
					occupied[flat_index] = true
		chunk["data"] = data
		chunk["occupied"] = occupied
		_chunks[key] = chunk
		return
	if terrain_mode == "overworld":
		_generate_overworld_chunk_data(key)
		return
	# Legacy prototype path is retained only for saves made before terrain presets existed.
	for local_z in range(CHUNK_SIZE):
		for local_x in range(CHUNK_SIZE):
			var world_x := key.x * CHUNK_SIZE + local_x
			var world_z := key.y * CHUNK_SIZE + local_z
			var surface_y := surface_height_at(world_x, world_z)
			for world_y in range(MIN_Y, surface_y + 1):
				var block_id := 3
				if world_y == MIN_Y:
					block_id = 5
				elif world_y == surface_y:
					block_id = 1
				elif world_y >= surface_y - 3:
					block_id = 2
				elif world_y < surface_y - 5 and world_y > MIN_Y + 1:
					var cave_value := _cave_noise.get_noise_3d(float(world_x), float(world_y), float(world_z))
					if cave_value > 0.62:
						continue
					if world_y < -24:
						var ore_value := _terrain_noise.get_noise_3d(float(world_x) * 1.7 + float(world_y), float(world_y) * 1.6, float(world_z) * 1.7)
						if ore_value > 0.79:
							block_id = 14 if world_y < -48 else 11
						elif ore_value < -0.82:
							block_id = 12
				var index := _cell_index(local_x, world_y - MIN_Y, local_z)
				data[index] = block_id
				if block_id != 0:
					occupied[index] = true
	chunk["data"] = data
	chunk["occupied"] = occupied
	_chunks[key] = chunk

func _generate_overworld_chunk_data(key: Vector2i) -> void:
	var chunk: Dictionary = _chunks[key]
	var data: PackedInt32Array = chunk["data"]
	var occupied: Dictionary = chunk.get("occupied", {})
	var base_x := key.x * CHUNK_SIZE
	var base_z := key.y * CHUNK_SIZE
	var sea_level := 63
	var bedrock_id := _runtime_block_id("bedrock", 5)
	var stone_id := _runtime_block_id("stone", 3)
	var deepslate_id := _runtime_block_id("deepslate", stone_id)
	var grass_id := _runtime_block_id("grass_block", 1)
	var dirt_id := _runtime_block_id("dirt", 2)
	var sand_id := _runtime_block_id("sand", 6)
	var gravel_id := _runtime_block_id("gravel", 7)
	var sandstone_id := _runtime_block_id("sandstone", 17)
	var red_sand_id := _runtime_block_id("red_sand", sand_id)
	var red_sandstone_id := _runtime_block_id("red_sandstone", sandstone_id)
	var terracotta_id := _runtime_block_id("terracotta", stone_id)
	var water_id := _runtime_block_id("water", 0)
	var snow_id := _runtime_block_id("snow", 0)
	var coal_ore_id := _runtime_block_id("coal_ore", 11)
	var iron_ore_id := _runtime_block_id("iron_ore", 12)
	var gold_ore_id := _runtime_block_id("gold_ore", 13)
	var diamond_ore_id := _runtime_block_id("diamond_ore", 14)

	for local_z in range(CHUNK_SIZE):
		for local_x in range(CHUNK_SIZE):
			var world_x := base_x + local_x
			var world_z := base_z + local_z
			var biome := biome_at(world_x, world_z)
			var surface_y := _overworld_surface_height(world_x, world_z)
			var surface_block := grass_id
			var subsurface_block := dirt_id
			if biome in ["desert", "beach", "snowy_beach"]:
				surface_block = sand_id
				subsurface_block = sand_id
			elif biome in ["badlands", "eroded_badlands", "wooded_badlands"]:
				surface_block = red_sand_id if biome != "eroded_badlands" else terracotta_id
				subsurface_block = terracotta_id
			elif biome in ["stony_shore", "stony_peaks", "windswept_gravelly_hills"]:
				surface_block = gravel_id if biome == "stony_shore" else stone_id
				subsurface_block = stone_id
			elif biome in ["ocean", "deep_ocean", "warm_ocean", "lukewarm_ocean", "cold_ocean", "frozen_ocean", "deep_lukewarm_ocean", "deep_cold_ocean", "deep_frozen_ocean", "river", "frozen_river"]:
				surface_block = gravel_id if biome in ["deep_ocean", "deep_cold_ocean", "deep_frozen_ocean"] else sand_id
				subsurface_block = stone_id
			elif biome in ["windswept_hills", "jagged_peaks", "frozen_peaks"]:
				surface_block = stone_id
				subsurface_block = stone_id
			for world_y in range(MIN_Y, maxi(surface_y + 1, sea_level + 1) if surface_y < sea_level else surface_y + 1):
				if world_y > surface_y and world_y <= sea_level:
					if water_id <= 0:
						continue
					var water_index := _cell_index(local_x, world_y - MIN_Y, local_z)
					data[water_index] = water_id
					occupied[water_index] = true
					continue
				if world_y > surface_y:
					continue
				var block_id := stone_id
				if world_y == MIN_Y:
					block_id = bedrock_id
				elif world_y == surface_y:
					block_id = surface_block
				elif world_y >= surface_y - 3:
					block_id = subsurface_block
				elif world_y < 0:
					block_id = deepslate_id
				if world_y < surface_y - 5 and world_y > MIN_Y + 1:
					var cave_value := _cave_noise.get_noise_3d(float(world_x), float(world_y), float(world_z))
					if cave_value > 0.62 and world_y < surface_y - 5:
						continue
					var ore_value := _terrain_noise.get_noise_3d(float(world_x) * 1.7 + float(world_y), float(world_y) * 1.6, float(world_z) * 1.7)
					if ore_value > 0.80:
						if world_y < -48:
							block_id = diamond_ore_id if ore_value > 0.91 else iron_ore_id
						elif world_y < 16:
							block_id = iron_ore_id if ore_value > 0.88 else coal_ore_id
						else:
							block_id = coal_ore_id if ore_value > 0.89 else block_id
					elif ore_value < -0.83 and world_y < 32:
						block_id = gold_ore_id
				var index := _cell_index(local_x, world_y - MIN_Y, local_z)
				data[index] = block_id
				occupied[index] = true
			if snow_id > 0 and biome in ["snowy_plains", "ice_spikes", "snowy_taiga", "old_growth_spruce_taiga", "snowy_slopes", "grove"] and surface_y < MAX_Y:
				var snow_index := _cell_index(local_x, surface_y + 1 - MIN_Y, local_z)
				data[snow_index] = snow_id
				occupied[snow_index] = true

	# Deterministic small tree features; candidates overlap neighboring chunk margins so canopies meet across seams.
	var first_tree_x := floori(float(base_x - 3) / 8.0) * 8
	var first_tree_z := floori(float(base_z - 3) / 8.0) * 8
	for tree_z in range(first_tree_z, base_z + CHUNK_SIZE + 4, 8):
		for tree_x in range(first_tree_x, base_x + CHUNK_SIZE + 4, 8):
			if tree_x < base_x - 3 or tree_x > base_x + CHUNK_SIZE + 3 or tree_z < base_z - 3 or tree_z > base_z + CHUNK_SIZE + 3:
				continue
			if _feature_noise.get_noise_2d(float(tree_x) + 31.0, float(tree_z) - 17.0) < 0.05:
				continue
			var tree_biome := biome_at(tree_x, tree_z)
			if tree_biome not in ["forest", "flower_forest", "birch_forest", "old_growth_birch_forest", "dark_forest", "taiga", "snowy_taiga", "old_growth_spruce_taiga", "old_growth_pine_taiga", "windswept_forest", "jungle", "sparse_jungle", "bamboo_jungle", "savanna", "swamp", "plains"]:
				continue
			var tree_y := _overworld_surface_height(tree_x, tree_z)
			if tree_y < sea_level or biome_at(tree_x, tree_z) in ["river", "frozen_river"]:
				continue
			var log_name := "oak_log"
			var leaves_name := "oak_leaves"
			if tree_biome in ["taiga", "snowy_taiga", "old_growth_spruce_taiga", "old_growth_pine_taiga"]:
				log_name = "spruce_log"
				leaves_name = "spruce_leaves"
			elif tree_biome in ["birch_forest", "old_growth_birch_forest"]:
				log_name = "birch_log"
				leaves_name = "birch_leaves"
			elif tree_biome == "dark_forest":
				log_name = "dark_oak_log"
				leaves_name = "dark_oak_leaves"
			elif tree_biome in ["jungle", "sparse_jungle", "bamboo_jungle"]:
				log_name = "jungle_log"
				leaves_name = "jungle_leaves"
			elif tree_biome == "savanna":
				log_name = "acacia_log"
				leaves_name = "acacia_leaves"
			var log_id := _runtime_block_id(log_name, _runtime_block_id("oak_log", 8))
			var leaves_id := _runtime_block_id(leaves_name, _runtime_block_id("oak_leaves", 10))
			var trunk_height := 4 + int(absf(_feature_noise.get_noise_2d(float(tree_x) + 101.0, float(tree_z) + 73.0)) * 3.0)
			for trunk_y in range(tree_y + 1, mini(tree_y + trunk_height, MAX_Y)):
				var lx := tree_x - base_x
				var lz := tree_z - base_z
				if lx >= 0 and lx < CHUNK_SIZE and lz >= 0 and lz < CHUNK_SIZE:
					var trunk_index := _cell_index(lx, trunk_y - MIN_Y, lz)
					if data[trunk_index] == 0 or data[trunk_index] == _runtime_block_id("snow", 0):
						data[trunk_index] = log_id
						occupied[trunk_index] = true
			for canopy_y in range(tree_y + trunk_height - 2, tree_y + trunk_height + 2):
				var canopy_radius := 2 if canopy_y < tree_y + trunk_height else 1
				for dz in range(-canopy_radius, canopy_radius + 1):
					for dx in range(-canopy_radius, canopy_radius + 1):
						if abs(dx) == canopy_radius and abs(dz) == canopy_radius and canopy_y < tree_y + trunk_height:
							continue
						var leaf_x := tree_x + dx
						var leaf_z := tree_z + dz
						var local_leaf_x := leaf_x - base_x
						var local_leaf_z := leaf_z - base_z
						if local_leaf_x < 0 or local_leaf_x >= CHUNK_SIZE or local_leaf_z < 0 or local_leaf_z >= CHUNK_SIZE:
							continue
						var leaf_y := clampi(canopy_y, MIN_Y, MAX_Y)
						var leaf_index := _cell_index(local_leaf_x, leaf_y - MIN_Y, local_leaf_z)
						if data[leaf_index] == 0 or data[leaf_index] == snow_id:
							data[leaf_index] = leaves_id
							occupied[leaf_index] = true
	chunk["data"] = data
	chunk["occupied"] = occupied
	_chunks[key] = chunk

func _apply_edits_to_chunk(key: Vector2i) -> void:
	var chunk: Dictionary = _chunks[key]
	var data: PackedInt32Array = chunk["data"]
	var occupied: Dictionary = chunk.get("occupied", {})
	for point_value in _edits.keys():
		var point: Vector3i = point_value
		if floori(point.x / float(CHUNK_SIZE)) != key.x or floori(point.z / float(CHUNK_SIZE)) != key.y:
			continue
		if point.y < MIN_Y or point.y > MAX_Y:
			continue
		var index := _cell_index(posmod(point.x, CHUNK_SIZE), point.y - MIN_Y, posmod(point.z, CHUNK_SIZE))
		var edited_id := int(_edits[point])
		data[index] = edited_id
		if edited_id == 0:
			occupied.erase(index)
		else:
			occupied[index] = true
	chunk["data"] = data
	chunk["occupied"] = occupied
	_chunks[key] = chunk

func _read_chunk_cell(key: Vector2i, local_x: int, y_index: int, local_z: int) -> int:
	if y_index < 0 or y_index >= CHUNK_HEIGHT or not _chunks.has(key):
		return 0
	var chunk: Dictionary = _chunks[key]
	var data: PackedInt32Array = chunk["data"]
	return int(data[_cell_index(local_x, y_index, local_z)])

func get_block_at(point: Vector3i) -> int:
	if point.y < MIN_Y or point.y > MAX_Y:
		return 0
	var key := Vector2i(floori(point.x / float(CHUNK_SIZE)), floori(point.z / float(CHUNK_SIZE)))
	return _read_chunk_cell(key, posmod(point.x, CHUNK_SIZE), point.y - MIN_Y, posmod(point.z, CHUNK_SIZE))

func set_block_at(point: Vector3i, block_id: int) -> bool:
	if point.y < MIN_Y or point.y > MAX_Y or block_id < 0:
		return false
	var key := Vector2i(floori(point.x / float(CHUNK_SIZE)), floori(point.z / float(CHUNK_SIZE)))
	if not _chunks.has(key):
		return false
	var chunk: Dictionary = _chunks[key]
	var data: PackedInt32Array = chunk["data"]
	var index := _cell_index(posmod(point.x, CHUNK_SIZE), point.y - MIN_Y, posmod(point.z, CHUNK_SIZE))
	var previous_id := int(data[index])
	data[index] = block_id
	var occupied: Dictionary = chunk.get("occupied", {})
	if block_id == 0:
		occupied.erase(index)
	else:
		occupied[index] = true
	chunk["data"] = data
	chunk["occupied"] = occupied
	_chunks[key] = chunk
	_edits[point] = block_id
	if previous_id != block_id or block_id == 0:
		_state_edits.erase(point)
	_rebuild_chunk(key)
	if posmod(point.x, CHUNK_SIZE) == 0:
		_rebuild_chunk(Vector2i(key.x - 1, key.y))
	elif posmod(point.x, CHUNK_SIZE) == CHUNK_SIZE - 1:
		_rebuild_chunk(Vector2i(key.x + 1, key.y))
	if posmod(point.z, CHUNK_SIZE) == 0:
		_rebuild_chunk(Vector2i(key.x, key.y - 1))
	elif posmod(point.z, CHUNK_SIZE) == CHUNK_SIZE - 1:
		_rebuild_chunk(Vector2i(key.x, key.y + 1))
	return true

func get_block_state_at(point: Vector3i) -> Dictionary:
	return (_state_edits.get(point, {}) as Dictionary).duplicate(true)

func set_block_state_at(point: Vector3i, properties: Dictionary) -> bool:
	var block_id := get_block_at(point)
	if block_id <= 0:
		return false
	var clean_state: Dictionary = {}
	for key_value in properties:
		var property_name := String(key_value).strip_edges()
		var property_value := String(properties[key_value]).strip_edges()
		if property_name.is_empty() or property_name.contains("=") or property_name.contains(","):
			continue
		if property_value.is_empty():
			continue
		clean_state[property_name] = property_value
	if clean_state.is_empty():
		_state_edits.erase(point)
	else:
		_state_edits[point] = clean_state
	var chunk_key := Vector2i(floori(point.x / float(CHUNK_SIZE)), floori(point.z / float(CHUNK_SIZE)))
	_rebuild_chunk(chunk_key)
	return true

func is_solid_at(point: Vector3i) -> bool:
	var id := get_block_at(point)
	if id == 0:
		return false
	var tree := get_tree()
	var registry: Variant = tree.root.get_node_or_null("BlockRegistry") if tree != null else null
	if registry != null and registry.blocks.has(id):
		return bool(registry.blocks[id].get("solid", true))
	return true

func _face_corners(x: int, y: int, z: int, face: String) -> Array:
	match face:
		"top":
			return [Vector3(x, y + 1, z), Vector3(x, y + 1, z + 1), Vector3(x + 1, y + 1, z + 1), Vector3(x + 1, y + 1, z)]
		"bottom":
			return [Vector3(x, y, z), Vector3(x + 1, y, z), Vector3(x + 1, y, z + 1), Vector3(x, y, z + 1)]
		"north":
			return [Vector3(x, y, z), Vector3(x, y + 1, z), Vector3(x + 1, y + 1, z), Vector3(x + 1, y, z)]
		"south":
			return [Vector3(x, y, z + 1), Vector3(x + 1, y, z + 1), Vector3(x + 1, y + 1, z + 1), Vector3(x, y + 1, z + 1)]
		"east":
			return [Vector3(x + 1, y, z), Vector3(x + 1, y + 1, z), Vector3(x + 1, y + 1, z + 1), Vector3(x + 1, y, z + 1)]
		_:
			return [Vector3(x, y, z), Vector3(x, y, z + 1), Vector3(x, y + 1, z + 1), Vector3(x, y + 1, z)]

func _fallback_color(block_id: int, face: String) -> Color:
	match block_id:
		1:
			return Color(0.31, 0.57, 0.22) if face != "top" else Color(0.32, 0.66, 0.24)
		2: return Color(0.40, 0.27, 0.15)
		3: return Color(0.43, 0.44, 0.45)
		4: return Color(0.38, 0.39, 0.40)
		5: return Color(0.16, 0.15, 0.16)
		6: return Color(0.83, 0.77, 0.55)
		7: return Color(0.55, 0.52, 0.48)
		8: return Color(0.42, 0.29, 0.16) if face != "top" and face != "bottom" else Color(0.61, 0.45, 0.25)
		9: return Color(0.61, 0.43, 0.24)
		10: return Color(0.22, 0.46, 0.19)
		11: return Color(0.29, 0.30, 0.31)
		12: return Color(0.45, 0.44, 0.42)
		13: return Color(0.66, 0.53, 0.20)
		14: return Color(0.30, 0.65, 0.70)
		15: return Color(0.54, 0.32, 0.16)
		16: return Color(0.34, 0.34, 0.35)
		17: return Color(0.78, 0.69, 0.48)
		18: return Color(0.48, 0.55, 0.60)
		_: return Color(0.7, 0.1, 0.7)

func _material_for_face(block_id: int, face: String) -> StandardMaterial3D:
	var material_key := "%d:%s" % [block_id, face]
	if _materials.has(material_key):
		return _materials[material_key]
	var material := StandardMaterial3D.new()
	material.roughness = 1.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var registry: Variant = get_tree().root.get_node_or_null("BlockRegistry")
	var texture_path := ""
	if registry != null and registry.has_method("texture_path_for_face"):
		texture_path = String(registry.texture_path_for_face(block_id, face))
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		var definition: Dictionary = registry.blocks.get(block_id, {})
		material = registry.material_for_texture(texture_path, bool(definition.get("alpha_scissor", false)))
	else:
		material.albedo_color = _fallback_color(block_id, face)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_materials[material_key] = material
	return material

func _append_face(surface: Dictionary, corners: Array, normal: Vector3) -> void:
	var vertices: Array = surface["vertices"]
	var normals: Array = surface["normals"]
	var uvs: Array = surface["uvs"]
	for vertex_index in TRIANGLE_ORDER:
		vertices.append(corners[vertex_index])
		normals.append(normal)
		uvs.append(FACE_UVS[vertex_index])
	surface["vertices"] = vertices
	surface["normals"] = normals
	surface["uvs"] = uvs

func _face_name_to_model_key(face: String) -> String:
	match face:
		"top": return "up"
		"bottom": return "down"
		_: return face

func _model_face_normal(face: String) -> Vector3:
	match face:
		"top", "up": return Vector3.UP
		"bottom", "down": return Vector3.DOWN
		"north": return Vector3.FORWARD
		"south": return Vector3.BACK
		"east": return Vector3.RIGHT
		_: return Vector3.LEFT

func _model_face_corners(from_point: Vector3, to_point: Vector3, face: String) -> Array[Vector3]:
	var f := from_point
	var t := to_point
	match face:
		"top", "up":
			return [Vector3(f.x, t.y, f.z), Vector3(f.x, t.y, t.z), Vector3(t.x, t.y, t.z), Vector3(t.x, t.y, f.z)]
		"bottom", "down":
			return [Vector3(f.x, f.y, f.z), Vector3(t.x, f.y, f.z), Vector3(t.x, f.y, t.z), Vector3(f.x, f.y, t.z)]
		"north":
			return [Vector3(f.x, f.y, f.z), Vector3(f.x, t.y, f.z), Vector3(t.x, t.y, f.z), Vector3(t.x, f.y, f.z)]
		"south":
			return [Vector3(f.x, f.y, t.z), Vector3(t.x, f.y, t.z), Vector3(t.x, t.y, t.z), Vector3(f.x, t.y, t.z)]
		"east":
			return [Vector3(t.x, f.y, f.z), Vector3(t.x, t.y, f.z), Vector3(t.x, t.y, t.z), Vector3(t.x, f.y, t.z)]
		_:
			return [Vector3(f.x, f.y, f.z), Vector3(f.x, f.y, t.z), Vector3(f.x, t.y, t.z), Vector3(f.x, t.y, f.z)]

func _default_element_uv(face: String, from16: Vector3, to16: Vector3) -> Array[float]:
	match face:
		"top", "up":
			return [from16.x, from16.z, to16.x, to16.z]
		"bottom", "down":
			return [from16.x, 16.0 - to16.z, to16.x, 16.0 - from16.z]
		"north":
			return [16.0 - to16.x, 16.0 - to16.y, 16.0 - from16.x, 16.0 - from16.y]
		"south":
			return [from16.x, 16.0 - to16.y, to16.x, 16.0 - from16.y]
		"east":
			return [16.0 - to16.z, 16.0 - to16.y, 16.0 - from16.z, 16.0 - from16.y]
		_:
			return [from16.z, 16.0 - to16.y, to16.z, 16.0 - from16.y]

func _face_uv_corners(face: String, uv_rect: Array, rotation: int) -> Array[Vector2]:
	if uv_rect.size() < 4:
		return [Vector2.ZERO, Vector2.ZERO, Vector2.ONE, Vector2.ONE]
	var u1 := float(uv_rect[0])
	var v1 := float(uv_rect[1])
	var u2 := float(uv_rect[2])
	var v2 := float(uv_rect[3])
	var result: Array[Vector2]
	match face:
		"top", "up":
			result = [Vector2(u1, v1), Vector2(u1, v2), Vector2(u2, v2), Vector2(u2, v1)]
		"bottom", "down":
			result = [Vector2(u1, v2), Vector2(u2, v2), Vector2(u2, v1), Vector2(u1, v1)]
		"north":
			result = [Vector2(u2, v2), Vector2(u2, v1), Vector2(u1, v1), Vector2(u1, v2)]
		"south":
			result = [Vector2(u1, v2), Vector2(u2, v2), Vector2(u2, v1), Vector2(u1, v1)]
		"east":
			result = [Vector2(u2, v2), Vector2(u2, v1), Vector2(u1, v1), Vector2(u1, v2)]
		_:
			result = [Vector2(u1, v2), Vector2(u2, v2), Vector2(u2, v1), Vector2(u1, v1)]
	var center := Vector2((u1 + u2) * 0.5, (v1 + v2) * 0.5)
	var quarter_turns := posmod(roundi(float(rotation) / 90.0), 4)
	for index in range(result.size()):
		var offset := result[index] - center
		for _turn in range(quarter_turns):
			offset = Vector2(-offset.y, offset.x)
		result[index] = (center + offset) / 16.0
	return result

func _basis_for_model_rotation(model: Dictionary) -> Basis:
	var x_angle := deg_to_rad(float(int(model.get("blockstate_rotation_x", 0))))
	var y_angle := deg_to_rad(float(int(model.get("blockstate_rotation_y", 0))))
	var z_angle := deg_to_rad(float(int(model.get("blockstate_rotation_z", 0))))
	return Basis(Vector3.BACK, z_angle) * Basis(Vector3.UP, y_angle) * Basis(Vector3.RIGHT, x_angle)

func _element_rotation(element: Dictionary) -> Dictionary:
	var rotation: Variant = element.get("rotation", {})
	if not rotation is Dictionary:
		return {"enabled": false, "origin": Vector3(0.5, 0.5, 0.5), "basis": Basis.IDENTITY, "axis": ""}
	var origin_values: Variant = rotation.get("origin", [8, 8, 8])
	if not origin_values is Array or origin_values.size() < 3:
		origin_values = [8, 8, 8]
	var origin := Vector3(float(origin_values[0]), float(origin_values[1]), float(origin_values[2])) / 16.0
	var axis_name := String(rotation.get("axis", "y"))
	var axis := Vector3.UP
	match axis_name:
		"x": axis = Vector3.RIGHT
		"z": axis = Vector3.BACK
	var angle := deg_to_rad(float(rotation.get("angle", 0.0)))
	return {"enabled": true, "origin": origin, "basis": Basis(axis, angle), "axis": axis_name, "angle": angle, "rescale": bool(rotation.get("rescale", false))}

func _transform_model_corner(corner: Vector3, local_x: int, y_index: int, local_z: int, element_rotation: Dictionary, block_rotation: Basis) -> Vector3:
	var result := corner
	if bool(element_rotation.get("enabled", false)):
		var origin: Vector3 = element_rotation.get("origin", Vector3(0.5, 0.5, 0.5))
		var relative := result - origin
		if bool(element_rotation.get("rescale", false)):
			var rescale_value := 1.0 / maxf(0.001, cos(float(element_rotation.get("angle", 0.0))))
			match String(element_rotation.get("axis", "y")):
				"x":
					relative.y *= rescale_value
					relative.z *= rescale_value
				"z":
					relative.x *= rescale_value
					relative.y *= rescale_value
				_:
					relative.x *= rescale_value
					relative.z *= rescale_value
		result = origin + (element_rotation.get("basis", Basis.IDENTITY) as Basis) * relative
	result = Vector3(0.5, 0.5, 0.5) + block_rotation * (result - Vector3(0.5, 0.5, 0.5))
	return Vector3(local_x, y_index, local_z) + result

func _model_face_cull_offset(cullface: String, block_rotation: Basis) -> Vector3i:
	var direction := Vector3.ZERO
	match cullface:
		"down": direction = Vector3.DOWN
		"up": direction = Vector3.UP
		"north": direction = Vector3.FORWARD
		"south": direction = Vector3.BACK
		"east": direction = Vector3.RIGHT
		"west": direction = Vector3.LEFT
		_: return Vector3i.ZERO
	var rotated := block_rotation * direction
	return Vector3i(roundi(rotated.x), roundi(rotated.y), roundi(rotated.z))

func _ensure_model_surface(surfaces: Dictionary, surface_key: String, material: Material) -> Dictionary:
	if not surfaces.has(surface_key):
		surfaces[surface_key] = {"vertices": [], "normals": [], "uvs": [], "material": material}
	return surfaces[surface_key]

func _append_model_element_faces(surfaces: Dictionary, block_id: int, block_point: Vector3i, local_x: int, y_index: int, local_z: int, element: Dictionary, model: Dictionary) -> int:
	var from_value: Variant = element.get("from", [0, 0, 0])
	var to_value: Variant = element.get("to", [16, 16, 16])
	if not from_value is Array or not to_value is Array or from_value.size() < 3 or to_value.size() < 3:
		return 0
	var from16 := Vector3(float(from_value[0]), float(from_value[1]), float(from_value[2]))
	var to16 := Vector3(float(to_value[0]), float(to_value[1]), float(to_value[2]))
	var from_point := from16 / 16.0
	var to_point := to16 / 16.0
	var rotation_info := _element_rotation(element)
	var block_rotation := _basis_for_model_rotation(model)
	var faces: Variant = element.get("faces", {})
	var textures: Dictionary = model.get("textures", {})
	if not faces is Dictionary:
		return 0
	var registry: Variant = get_tree().root.get_node_or_null("BlockRegistry")
	var block_definition: Dictionary = registry.get_definition(block_id) if registry != null else {}
	var appended_faces := 0
	var model_face_names := ["up", "down", "north", "south", "east", "west"]
	for face in model_face_names:
		if not faces.has(face) or not faces[face] is Dictionary:
			continue
		var face_definition: Dictionary = faces[face]
		var cullface := String(face_definition.get("cullface", ""))
		if not cullface.is_empty():
			var cull_offset := _model_face_cull_offset(cullface, block_rotation)
			if cull_offset != Vector3i.ZERO and get_block_at(block_point + cull_offset) != 0:
				continue
		var texture_reference := String(face_definition.get("texture", ""))
		var texture_path := String(_model_loader.resolve_texture(texture_reference, textures)) if _model_loader != null else ""
		var has_texture := not texture_path.is_empty() and ResourceLoader.exists(texture_path)
		var alpha_scissor := bool(block_definition.get("alpha_scissor", false))
		var material: Material
		var surface_key: String
		if has_texture and registry != null and registry.has_method("material_for_texture"):
			material = registry.material_for_texture(texture_path, alpha_scissor)
			surface_key = texture_path + ("|cutout" if alpha_scissor else "|opaque")
		else:
			var fallback_face := String(face)
			if fallback_face == "up": fallback_face = "top"
			elif fallback_face == "down": fallback_face = "bottom"
			material = _material_for_face(block_id, fallback_face)
			surface_key = "fallback:%d:%s" % [block_id, fallback_face]
		var surface: Dictionary = _ensure_model_surface(surfaces, surface_key, material)
		var corners := _model_face_corners(from_point, to_point, face)
		var uv_values: Variant = face_definition.get("uv", _default_element_uv(face, from16, to16))
		if not uv_values is Array or uv_values.size() < 4:
			uv_values = _default_element_uv(face, from16, to16)
		var face_uvs := _face_uv_corners(face, uv_values, int(face_definition.get("rotation", 0)))
		var element_basis: Basis = rotation_info["basis"]
		var face_normal: Vector3 = block_rotation * element_basis * _model_face_normal(face)
		if face_normal.length_squared() > 0.0:
			face_normal = face_normal.normalized()
		var vertices: Array = surface["vertices"]
		var normals: Array = surface["normals"]
		var uvs: Array = surface["uvs"]
		for vertex_index in TRIANGLE_ORDER:
			vertices.append(_transform_model_corner(corners[vertex_index], local_x, y_index, local_z, rotation_info, block_rotation))
			normals.append(face_normal)
			uvs.append(face_uvs[vertex_index])
		surface["vertices"] = vertices
		surface["normals"] = normals
		surface["uvs"] = uvs
		surfaces[surface_key] = surface
		appended_faces += 1
	return appended_faces

func _append_model_block(surfaces: Dictionary, block_id: int, block_point: Vector3i, local_x: int, y_index: int, local_z: int) -> int:
	if _model_loader == null:
		return 0
	var registry: Variant = get_tree().root.get_node_or_null("BlockRegistry")
	if registry == null:
		return 0
	var definition: Dictionary = registry.get_definition(block_id)
	var block_name := String(definition.get("name", ""))
	if block_name.is_empty():
		return 0
	var block_states: Dictionary = (_state_edits.get(block_point, {}) as Dictionary).duplicate(true)
	var models: Array[Dictionary] = _model_loader.resolve_block_models(block_name, block_states, world_seed, block_point)
	var appended_faces := 0
	for model in models:
		var elements: Variant = model.get("elements", [])
		if not elements is Array:
			continue
		for element in elements:
			if element is Dictionary:
				appended_faces += _append_model_element_faces(surfaces, block_id, block_point, local_x, y_index, local_z, element, model)
	return appended_faces

func _rebuild_chunk(key: Vector2i) -> void:
	if not _build_meshes:
		return
	if not _chunks.has(key):
		return
	var chunk: Dictionary = _chunks[key]
	var root: Node3D = chunk["root"]
	if not is_instance_valid(root):
		return
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
	var data: PackedInt32Array = chunk["data"]
	var occupied: Dictionary = chunk.get("occupied", {})
	if not chunk.has("occupied"):
		for index in range(data.size()):
			if int(data[index]) != 0:
				occupied[index] = true
		chunk["occupied"] = occupied
		_chunks[key] = chunk
	var occupied_indices: Array = occupied.keys()
	occupied_indices.sort()
	var surfaces: Dictionary = {}
	var base_x := key.x * CHUNK_SIZE
	var base_z := key.y * CHUNK_SIZE
	for index_value in occupied_indices:
		var cell_index := int(index_value)
		if cell_index < 0 or cell_index >= data.size():
			continue
		var block_id := int(data[cell_index])
		if block_id == 0:
			continue
		var local_x := posmod(cell_index, CHUNK_SIZE)
		var row_index := floori(float(cell_index) / float(CHUNK_SIZE))
		var local_z := posmod(row_index, CHUNK_SIZE)
		var y_index := floori(float(cell_index) / float(CHUNK_SIZE * CHUNK_SIZE))
		var world_y := MIN_Y + y_index
		var world_x := base_x + local_x
		var world_z := base_z + local_z
		var point := Vector3i(world_x, world_y, world_z)
		var model_face_count := _append_model_block(surfaces, block_id, point, local_x, y_index, local_z)
		if model_face_count > 0:
			continue
		for face_index in range(FACE_NAMES.size()):
			var face_offset: Vector3i = FACE_OFFSETS[face_index]
			var adjacent: Vector3i = point + face_offset
			if get_block_at(adjacent) != 0:
				continue
			var face := String(FACE_NAMES[face_index])
			var surface_key := "%d:%s" % [block_id, face]
			if not surfaces.has(surface_key):
				surfaces[surface_key] = {"block_id": block_id, "face": face, "vertices": [], "normals": [], "uvs": [], "material": _material_for_face(block_id, face)}
			var surface: Dictionary = surfaces[surface_key]
			_append_face(surface, _face_corners(local_x, y_index, local_z, face), FACE_NORMALS[face_index])
			surfaces[surface_key] = surface
	var mesh := ArrayMesh.new()
	for surface_key in surfaces.keys():
		var surface: Dictionary = surfaces[surface_key]
		if (surface["vertices"] as Array).is_empty():
			continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(surface["vertices"])
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(surface["normals"])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(surface["uvs"])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, surface["material"] as Material)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "TerrainMesh"
	mesh_instance.mesh = mesh
	root.add_child(mesh_instance)
	if mesh.get_surface_count() > 0:
		var body := StaticBody3D.new()
		body.name = "TerrainCollision"
		var collider := CollisionShape3D.new()
		collider.shape = mesh.create_trimesh_shape()
		body.add_child(collider)
		root.add_child(body)

func loaded_chunk_count() -> int:
	return _chunks.size()

func tracked_edit_count() -> int:
	return _edits.size()
