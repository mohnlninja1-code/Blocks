extends Node
"""Single source of truth for block/item metadata loaded from data JSON."""

var blocks: Dictionary = {}
var items: Dictionary = {}
var by_name: Dictionary = {}
var _materials: Dictionary = {}

func _ready() -> void:
	var raw_blocks := _load_json_dictionary("res://data/blocks.json")
	var raw_items := _load_json_dictionary("res://data/items.json")
	var expanded_blocks := _load_json_array("res://data/expanded_blocks.json")
	blocks = {}
	items = {}
	by_name = {}
	for key in raw_blocks.keys():
		var id := int(key)
		var entry: Dictionary = raw_blocks[key].duplicate(true)
		entry["id"] = id
		entry["kind"] = "block"
		blocks[id] = entry
		by_name[String(entry.get("name", ""))] = id
	for expanded in expanded_blocks:
		if not expanded is Dictionary:
			continue
		var entry: Dictionary = expanded.duplicate(true)
		var id := int(entry.get("id", 0))
		if id <= 0 or blocks.has(id):
			push_error("Invalid or duplicate expanded block ID: %d" % id)
			continue
		entry["kind"] = "block"
		blocks[id] = entry
		by_name[String(entry.get("name", ""))] = id
	for key in raw_items.keys():
		var id := int(key)
		var entry: Dictionary = raw_items[key].duplicate(true)
		entry["id"] = id
		entry["kind"] = "item"
		items[id] = entry
		by_name[String(entry.get("name", ""))] = id

func _load_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_error("Required registry is missing: %s" % path)
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Array:
		push_error("Registry must be a JSON array: %s" % path)
		return []
	return parsed

func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Required registry is missing: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Registry must be a JSON object: %s" % path)
		return {}
	return parsed

func get_definition(id: int) -> Dictionary:
	if blocks.has(id):
		return blocks[id]
	if items.has(id):
		return items[id]
	return {}

func block_id(name: String) -> int:
	return int(by_name.get(name, 0))

func all_definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value in blocks.values():
		result.append(value)
	for value in items.values():
		result.append(value)
	return result

func is_block_item(id: int) -> bool:
	return blocks.has(id) and id != 0

func place_block_id(item_id: int) -> int:
	if blocks.has(item_id) and item_id != 0:
		return item_id
	var def := get_definition(item_id)
	return int(def.get("place_block", 0))

func stack_limit(item_id: int) -> int:
	var def := get_definition(item_id)
	return int(def.get("stack_size", 64))

func get_display_name(item_id: int) -> String:
	if item_id == 0:
		return "Empty"
	var def := get_definition(item_id)
	return String(def.get("display_name", def.get("name", "Unknown item")))

func texture_path_for_face(block_id_value: int, face: String) -> String:
	var def := blocks.get(block_id_value, {}) as Dictionary
	var textures: Dictionary = def.get("textures", {})
	var texture_name := String(textures.get(face, textures.get("side", "")))
	if texture_name.is_empty():
		return ""
	return "res://assets/minecraft/textures/block/%s.png" % texture_name

func icon_path(item_id: int) -> String:
	var def := get_definition(item_id)
	if def.has("icon"):
		return String(def["icon"])
	if blocks.has(item_id):
		var textures: Dictionary = def.get("textures", {})
		var name := String(textures.get("top", textures.get("side", "")))
		if name.is_empty():
			return ""
		return "res://assets/minecraft/textures/block/%s.png" % name
	return ""

func material_for_texture(path: String, alpha_scissor: bool = false) -> StandardMaterial3D:
	var key := path + ("|cutout" if alpha_scissor else "|opaque")
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_BACK
	if not path.is_empty() and ResourceLoader.exists(path):
		material.albedo_texture = load(path)
	else:
		material.albedo_color = Color(1.0, 0.0, 1.0)
		push_warning("Texture reference is unresolved: %s" % path)
	if alpha_scissor:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.5
	_materials[key] = material
	return material

func preferred_tool(block_id_value: int) -> String:
	return String(blocks.get(block_id_value, {}).get("preferred_tool", ""))

func tool_tier(item_id: int) -> int:
	return int(items.get(item_id, {}).get("tool_tier", -1))

func mining_speed_for(block_id_value: int, item_id: int) -> float:
	var required := preferred_tool(block_id_value)
	var item_def: Dictionary = items.get(item_id, {})
	if not required.is_empty() and String(item_def.get("tool_tag", "")) == required:
		return maxf(1.0, float(item_def.get("mining_speed", 1.0)))
	return 1.0

func can_harvest(block_id_value: int, item_id: int) -> bool:
	var definition: Dictionary = blocks.get(block_id_value, {})
	if not bool(definition.get("requires_tool", false)):
		return true
	var preferred := String(definition.get("preferred_tool", ""))
	var item_def: Dictionary = items.get(item_id, {})
	if preferred.is_empty() or String(item_def.get("tool_tag", "")) != preferred:
		return false
	return tool_tier(item_id) >= int(definition.get("required_tool_tier", 0))

func tool_definition(item_id: int) -> Dictionary:
	return items.get(item_id, {}) as Dictionary
