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
var _chunks: Dictionary = {}
var _edits: Dictionary = {} # Vector3i -> block ID; ID 0 explicitly records a removed block.
var _terrain_noise := FastNoiseLite.new()
var _cave_noise := FastNoiseLite.new()
var _stream_center := Vector2i(2147483647, 2147483647)
var _view_radius := 1
var _materials: Dictionary = {}

func _ready() -> void:
	_configure_noise(world_seed)

func _configure_noise(new_seed: int) -> void:
	_terrain_noise.seed = new_seed
	_terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_terrain_noise.frequency = 0.035
	_terrain_noise.fractal_octaves = 3
	_terrain_noise.fractal_lacunarity = 2.0
	_cave_noise.seed = new_seed + 7919
	_cave_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_cave_noise.frequency = 0.055
	_cave_noise.fractal_octaves = 2

func surface_height_at(world_x: int, world_z: int) -> int:
	return clampi(66 + roundi(_terrain_noise.get_noise_2d(float(world_x), float(world_z)) * 14.0), MIN_Y + 8, MAX_Y - 8)

func generate_world(new_seed: int, view_radius: int = 1) -> void:
	for key in _chunks:
		var old_chunk: Dictionary = _chunks[key]
		var old_root: Node3D = old_chunk.get("root")
		if is_instance_valid(old_root):
			old_root.queue_free()
	_chunks.clear()
	_edits.clear()
	world_seed = new_seed
	_view_radius = clampi(view_radius, 1, 4)
	_stream_center = Vector2i(2147483647, 2147483647)
	_configure_noise(world_seed)
	update_streaming(Vector3.ZERO, _view_radius)

func load_state(state: Dictionary, view_radius: int = 1) -> bool:
	var new_seed := int(state.get("seed", 1))
	generate_world(new_seed, view_radius)
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
	return {"seed": world_seed, "edits": rows, "min_y": MIN_Y, "max_y": MAX_Y}

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
	if added_any or removed_any:
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
	_chunks[key] = {"data": data, "root": chunk_root}
	_generate_chunk_data(key)
	_apply_edits_to_chunk(key)

func _cell_index(local_x: int, y_index: int, local_z: int) -> int:
	return (y_index * CHUNK_SIZE + local_z) * CHUNK_SIZE + local_x

func _generate_chunk_data(key: Vector2i) -> void:
	var chunk: Dictionary = _chunks[key]
	var data: PackedInt32Array = chunk["data"]
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
				data[_cell_index(local_x, world_y - MIN_Y, local_z)] = block_id
	chunk["data"] = data
	_chunks[key] = chunk

func _apply_edits_to_chunk(key: Vector2i) -> void:
	var chunk: Dictionary = _chunks[key]
	var data: PackedInt32Array = chunk["data"]
	for point_value in _edits.keys():
		var point: Vector3i = point_value
		if floori(point.x / float(CHUNK_SIZE)) != key.x or floori(point.z / float(CHUNK_SIZE)) != key.y:
			continue
		if point.y < MIN_Y or point.y > MAX_Y:
			continue
		data[_cell_index(posmod(point.x, CHUNK_SIZE), point.y - MIN_Y, posmod(point.z, CHUNK_SIZE))] = int(_edits[point])
	chunk["data"] = data
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
	data[_cell_index(posmod(point.x, CHUNK_SIZE), point.y - MIN_Y, posmod(point.z, CHUNK_SIZE))] = block_id
	chunk["data"] = data
	_chunks[key] = chunk
	_edits[point] = block_id
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

func _rebuild_chunk(key: Vector2i) -> void:
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
	var surfaces: Dictionary = {}
	var base_x := key.x * CHUNK_SIZE
	var base_z := key.y * CHUNK_SIZE
	for y_index in range(CHUNK_HEIGHT):
		var world_y := MIN_Y + y_index
		for local_z in range(CHUNK_SIZE):
			var world_z := base_z + local_z
			for local_x in range(CHUNK_SIZE):
				var block_id := int(data[_cell_index(local_x, y_index, local_z)])
				if block_id == 0:
					continue
				var world_x := base_x + local_x
				var point := Vector3i(world_x, world_y, world_z)
				for face_index in range(FACE_NAMES.size()):
					var adjacent := point + FACE_OFFSETS[face_index]
					if get_block_at(adjacent) != 0:
						continue
					var face := String(FACE_NAMES[face_index])
					var surface_key := "%d:%s" % [block_id, face]
					if not surfaces.has(surface_key):
						surfaces[surface_key] = {"block_id": block_id, "face": face, "vertices": [], "normals": [], "uvs": []}
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
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material_for_face(int(surface["block_id"]), String(surface["face"])))
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
