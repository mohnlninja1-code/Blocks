extends RefCounted
"""Build item scene nodes from supplied Java 1.18.2 JSON models/textures.

The resolver data and textures are sourced from the provided pack. This builder handles
model elements and layered generated-item quads, but visual parity still requires reference
screenshots and coverage for every model override/context.
"""

const TRIANGLES := [0, 1, 2, 0, 2, 3]
const FACE_ORDER := ["up", "down", "north", "south", "east", "west"]
const DEFAULT_CONTEXT_SCALE := {
	"firstperson_righthand": 0.35,
	"firstperson_lefthand": 0.35,
	"thirdperson_righthand": 0.35,
	"thirdperson_lefthand": 0.35,
	"gui": 0.62,
	"ground": 0.25,
	"fixed": 0.5,
	"head": 0.5
}

var _material_cache: Dictionary = {}

func create_item_node(item_id: int, context: String = "firstperson_righthand", predicate_values: Dictionary = {}) -> Node3D:
	var root := Node3D.new()
	root.name = "Item_%d" % item_id
	if item_id <= 0 or not is_instance_valid(Engine.get_main_loop()):
		return root
	var catalog: Variant = _catalog()
	if catalog == null:
		return root
	var model: Dictionary = catalog.resolve_item_model(item_id, predicate_values)
	if model.is_empty():
		return root
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "ItemModel"
	var elements: Variant = model.get("elements", [])
	if bool(model.get("generated_item", false)) or not elements is Array or elements.is_empty():
		mesh_instance.mesh = _build_generated_item_mesh(model, catalog)
	else:
		mesh_instance.mesh = _build_element_mesh(model, catalog)
	if mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
		mesh_instance.queue_free()
		return root
	root.add_child(mesh_instance)
	_apply_display_transform(root, model, context)
	return root

func _catalog() -> Variant:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("ItemModelCatalog")

func _texture_for_reference(reference: String, textures: Dictionary, catalog: Variant) -> String:
	var loader: Variant = catalog.model_loader if catalog != null else null
	if loader == null:
		return ""
	return String(loader.resolve_texture(reference, textures))

func _material_for_path(path: String, alpha_scissor: bool = false) -> StandardMaterial3D:
	var key := path + ("|cutout" if alpha_scissor else "|opaque")
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.roughness = 1.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if not path.is_empty() and ResourceLoader.exists(path):
		material.albedo_texture = load(path) as Texture2D
	else:
		# Do not synthesize a replacement texture: a missing source image is reported and remains visibly unresolved.
		material.albedo_color = Color(1.0, 0.0, 1.0)
	if alpha_scissor:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.1
	_material_cache[key] = material
	return material

func _face_corners(from_point: Vector3, to_point: Vector3, face: String) -> Array[Vector3]:
	var f := from_point
	var t := to_point
	match face:
		"up":
			return [Vector3(f.x, t.y, f.z), Vector3(f.x, t.y, t.z), Vector3(t.x, t.y, t.z), Vector3(t.x, t.y, f.z)]
		"down":
			return [Vector3(f.x, f.y, f.z), Vector3(t.x, f.y, f.z), Vector3(t.x, f.y, t.z), Vector3(f.x, f.y, t.z)]
		"north":
			return [Vector3(f.x, f.y, f.z), Vector3(f.x, t.y, f.z), Vector3(t.x, t.y, f.z), Vector3(t.x, f.y, f.z)]
		"south":
			return [Vector3(f.x, f.y, t.z), Vector3(t.x, f.y, t.z), Vector3(t.x, t.y, t.z), Vector3(f.x, t.y, t.z)]
		"east":
			return [Vector3(t.x, f.y, f.z), Vector3(t.x, t.y, f.z), Vector3(t.x, t.y, t.z), Vector3(t.x, f.y, t.z)]
		_:
			return [Vector3(f.x, f.y, f.z), Vector3(f.x, f.y, t.z), Vector3(f.x, t.y, t.z), Vector3(f.x, t.y, f.z)]

func _default_uv(face: String, from16: Vector3, to16: Vector3) -> Array[float]:
	match face:
		"up":
			return [from16.x, from16.z, to16.x, to16.z]
		"down":
			return [from16.x, 16.0 - to16.z, to16.x, 16.0 - from16.z]
		"north":
			return [16.0 - to16.x, 16.0 - to16.y, 16.0 - from16.x, 16.0 - from16.y]
		"south":
			return [from16.x, 16.0 - to16.y, to16.x, 16.0 - from16.y]
		"east":
			return [16.0 - to16.z, 16.0 - to16.y, 16.0 - from16.z, 16.0 - from16.y]
		_:
			return [from16.z, 16.0 - to16.y, to16.z, 16.0 - from16.y]

func _face_uvs(face: String, values: Array, rotation: int) -> Array[Vector2]:
	if values.size() < 4:
		values = [0.0, 0.0, 16.0, 16.0]
	var u1 := float(values[0])
	var v1 := float(values[1])
	var u2 := float(values[2])
	var v2 := float(values[3])
	var result: Array[Vector2]
	match face:
		"up":
			result = [Vector2(u1, v1), Vector2(u1, v2), Vector2(u2, v2), Vector2(u2, v1)]
		"down":
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
	for i in range(result.size()):
		var offset := result[i] - center
		for _turn in range(quarter_turns):
			offset = Vector2(-offset.y, offset.x)
		result[i] = (center + offset) / 16.0
	return result

func _element_rotation(element: Dictionary) -> Dictionary:
	var rotation_value: Variant = element.get("rotation", {})
	if not rotation_value is Dictionary:
		return {"enabled": false, "origin": Vector3(0.5, 0.5, 0.5), "basis": Basis.IDENTITY}
	var rotation: Dictionary = rotation_value
	var origin_value: Variant = rotation.get("origin", [8, 8, 8])
	if not origin_value is Array or origin_value.size() < 3:
		origin_value = [8, 8, 8]
	var origin := Vector3(float(origin_value[0]), float(origin_value[1]), float(origin_value[2])) / 16.0
	var axis := Vector3.UP
	match String(rotation.get("axis", "y")):
		"x": axis = Vector3.RIGHT
		"z": axis = Vector3.BACK
	var angle := deg_to_rad(float(rotation.get("angle", 0.0)))
	return {"enabled": true, "origin": origin, "basis": Basis(axis, angle)}

func _append_element(surfaces: Dictionary, element: Dictionary, model: Dictionary, catalog: Variant) -> void:
	var from_value: Variant = element.get("from", [0, 0, 0])
	var to_value: Variant = element.get("to", [16, 16, 16])
	if not from_value is Array or not to_value is Array or from_value.size() < 3 or to_value.size() < 3:
		return
	var from16 := Vector3(float(from_value[0]), float(from_value[1]), float(from_value[2]))
	var to16 := Vector3(float(to_value[0]), float(to_value[1]), float(to_value[2]))
	var from_point := from16 / 16.0 - Vector3.ONE * 0.5
	var to_point := to16 / 16.0 - Vector3.ONE * 0.5
	var rotation := _element_rotation(element)
	var faces: Variant = element.get("faces", {})
	var textures: Dictionary = model.get("textures", {})
	if not faces is Dictionary:
		return
	for face in FACE_ORDER:
		if not faces.has(face) or not faces[face] is Dictionary:
			continue
		var face_definition: Dictionary = faces[face]
		var texture_path := _texture_for_reference(String(face_definition.get("texture", "")), textures, catalog)
		var surface_key := texture_path if not texture_path.is_empty() else "missing:%s:%s" % [String(model.get("model_id", "")), face]
		if not surfaces.has(surface_key):
			surfaces[surface_key] = {"vertices": [], "normals": [], "uvs": [], "material": _material_for_path(texture_path, true)}
		var surface: Dictionary = surfaces[surface_key]
		var corners := _face_corners(from_point, to_point, face)
		var uv_value: Variant = face_definition.get("uv", _default_uv(face, from16, to16))
		var uv_rect: Array = uv_value if uv_value is Array else _default_uv(face, from16, to16)
		var uv_points := _face_uvs(face, uv_rect, int(face_definition.get("rotation", 0)))
		var normals: Array = surface["normals"]
		var vertices: Array = surface["vertices"]
		var uvs: Array = surface["uvs"]
		var face_normal := _normal_for_face(face)
		if bool(rotation.get("enabled", false)):
			face_normal = (rotation["basis"] as Basis) * face_normal
			face_normal = face_normal.normalized()
		for vertex_index in TRIANGLES:
			var corner: Vector3 = corners[vertex_index]
			if bool(rotation.get("enabled", false)):
				var origin: Vector3 = rotation["origin"]
				corner = origin + (rotation["basis"] as Basis) * (corner + Vector3.ONE * 0.5 - origin) - Vector3.ONE * 0.5
			vertices.append(corner)
			normals.append(face_normal)
			uvs.append(uv_points[vertex_index])
		surface["vertices"] = vertices
		surface["normals"] = normals
		surface["uvs"] = uvs
		surfaces[surface_key] = surface

func _normal_for_face(face: String) -> Vector3:
	match face:
		"up": return Vector3.UP
		"down": return Vector3.DOWN
		"north": return Vector3.FORWARD
		"south": return Vector3.BACK
		"east": return Vector3.RIGHT
		_: return Vector3.LEFT

func _build_element_mesh(model: Dictionary, catalog: Variant) -> ArrayMesh:
	var surfaces: Dictionary = {}
	var elements: Variant = model.get("elements", [])
	if not elements is Array:
		return ArrayMesh.new()
	for element in elements:
		if element is Dictionary:
			_append_element(surfaces, element, model, catalog)
	var mesh := ArrayMesh.new()
	for key in surfaces:
		var surface: Dictionary = surfaces[key]
		if (surface["vertices"] as Array).is_empty():
			continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(surface["vertices"])
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(surface["normals"])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(surface["uvs"])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, surface["material"] as Material)
	return mesh

func _build_generated_item_mesh(model: Dictionary, catalog: Variant) -> ArrayMesh:
	var textures: Variant = model.get("textures", {})
	var mesh := ArrayMesh.new()
	if not textures is Dictionary:
		return mesh
	var ordered_keys: Array[String] = []
	for key in ["layer0", "layer1", "layer2", "layer3", "layer4"]:
		if textures.has(key):
			ordered_keys.append(key)
	for key_value in textures.keys():
		var key := String(key_value)
		if not ordered_keys.has(key) and key != "particle":
			ordered_keys.append(key)
	var layer_index := 0
	for key in ordered_keys:
		var texture_path := _texture_for_reference(String(textures[key]), textures, catalog)
		if texture_path.is_empty() or not ResourceLoader.exists(texture_path):
			continue
		var offset_z := -0.002 * float(layer_index)
		var vertices := PackedVector3Array([
			Vector3(-0.5, -0.5, offset_z), Vector3(0.5, -0.5, offset_z),
			Vector3(0.5, 0.5, offset_z), Vector3(-0.5, 0.5, offset_z),
			Vector3(0.5, -0.5, offset_z + 0.001), Vector3(-0.5, -0.5, offset_z + 0.001),
			Vector3(-0.5, 0.5, offset_z + 0.001), Vector3(0.5, 0.5, offset_z + 0.001)
		])
		var uvs := PackedVector2Array([
			Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0),
			Vector2(1, 1), Vector2(0, 1), Vector2(0, 0), Vector2(1, 0)
		])
		var normals := PackedVector3Array([
			Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD,
			Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK
		])
		var indices := PackedInt32Array([0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7])
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material_for_path(texture_path, true))
		layer_index += 1
	return mesh

func _apply_display_transform(root: Node3D, model: Dictionary, context: String) -> void:
	var display: Variant = model.get("display", {})
	var transform_value: Variant = display.get(context, {}) if display is Dictionary else {}
	if not transform_value is Dictionary:
		transform_value = {}
	var transform: Dictionary = transform_value
	var rotation_value: Variant = transform.get("rotation", [0, 0, 0])
	var translation_value: Variant = transform.get("translation", [0, 0, 0])
	var scale_value: Variant = transform.get("scale", [DEFAULT_CONTEXT_SCALE.get(context, 0.5), DEFAULT_CONTEXT_SCALE.get(context, 0.5), DEFAULT_CONTEXT_SCALE.get(context, 0.5)])
	if not rotation_value is Array or rotation_value.size() < 3:
		rotation_value = [0, 0, 0]
	if not translation_value is Array or translation_value.size() < 3:
		translation_value = [0, 0, 0]
	if not scale_value is Array or scale_value.size() < 3:
		scale_value = [0.5, 0.5, 0.5]
	root.rotation_degrees = Vector3(float(rotation_value[0]), float(rotation_value[1]), float(rotation_value[2]))
	root.position = Vector3(float(translation_value[0]), float(translation_value[1]), float(translation_value[2])) / 16.0
	root.scale = Vector3(float(scale_value[0]), float(scale_value[1]), float(scale_value[2]))

func model_diagnostics(item_id: int, context: String = "firstperson_righthand") -> Dictionary:
	var catalog: Variant = _catalog()
	if catalog == null:
		return {"ok": false, "error": "ItemModelCatalog autoload is unavailable"}
	var model: Dictionary = catalog.resolve_item_model(item_id)
	if model.is_empty():
		return {"ok": false, "error": "Item model definition did not resolve"}
	var mesh: ArrayMesh = _build_generated_item_mesh(model, catalog) if bool(model.get("generated_item", false)) or (model.get("elements", []) as Array).is_empty() else _build_element_mesh(model, catalog)
	return {"ok": mesh != null and mesh.get_surface_count() > 0, "model_id": model.get("model_id", ""), "surface_count": mesh.get_surface_count() if mesh != null else 0, "context": context, "source_path": model.get("source_path", ""), "textures": catalog.texture_paths_for_model(model)}
