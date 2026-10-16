extends Node
"""Single source of truth for block/item metadata loaded from data JSON."""

const NON_ITEM_MODEL_TEMPLATES := ["generated", "handheld", "handheld_rod", "template_banner", "template_bed", "template_shulker_box", "template_skull", "template_spawn_egg"]

var blocks: Dictionary = {}
var items: Dictionary = {}
var by_name: Dictionary = {}
var _materials: Dictionary = {}
var asset_catalog_loaded := false
var asset_catalog_counts: Dictionary = {"blocks_added": 0, "items_added": 0}
var _source_item_model_names: Dictionary = {}
var _source_blockstate_names: Dictionary = {}

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

	load_asset_catalog("res://assets/minecraft")

func _source_names_in_folder(folder_path: String) -> Array[String]:
	var result: Array[String] = []
	var directory := DirAccess.open(folder_path)
	if directory == null:
		return result
	for file_name in directory.get_files():
		var filename := String(file_name)
		if not filename.ends_with(".json") or filename in ["_all.json", "_list.json"]:
			continue
		result.append(filename.trim_suffix(".json"))
	result.sort()
	return result

func _display_name_for_source_id(name: String) -> String:
	return name.replace("_", " ").capitalize()

func _infer_non_solid_block(name: String) -> bool:
	if name in ["air", "cave_air", "void_air", "water", "lava", "bubble_column", "fire", "soul_fire", "short_grass", "tall_grass", "fern", "large_fern", "dead_bush", "vine", "glow_lichen", "seagrass", "tall_seagrass", "kelp", "kelp_plant", "sugar_cane", "cobweb", "redstone_wire", "tripwire", "torch", "soul_torch", "redstone_torch", "wall_torch", "soul_wall_torch", "redstone_wall_torch", "lever", "stone_button", "oak_button", "spruce_button", "birch_button", "jungle_button", "acacia_button", "dark_oak_button", "crimson_button", "warped_button", "polished_blackstone_button", "stone_pressure_plate", "oak_pressure_plate", "rail", "powered_rail", "detector_rail", "activator_rail"]:
		return true
	if name.ends_with("_flower") or name.ends_with("_sapling") or name.ends_with("_tulip") or name.ends_with("_orchid") or name.ends_with("_mushroom") or name.ends_with("_torchflower") or name.ends_with("_coral_fan") or name.ends_with("_coral_wall_fan"):
		return true
	if name in ["poppy", "dandelion", "allium", "azure_bluet", "blue_orchid", "cornflower", "lily_of_the_valley", "wither_rose", "sunflower", "lilac", "rose_bush", "peony", "pink_petals", "spore_blossom", "torchflower", "pitcher_plant"]:
		return true
	return false

func _infer_cutout_block(name: String) -> bool:
	return _infer_non_solid_block(name) or name.contains("leaves") or name.contains("glass") or name.contains("pane") or name.contains("ice") or name.contains("coral") or name.contains("bamboo") or name.contains("cactus") or name.contains("ladder") or name.contains("chain") or name.contains("bars") or name.contains("fence") or name.contains("door") or name.contains("trapdoor") or name.contains("sign") or name.contains("banner") or name.contains("flower") or name.contains("grass") or name.contains("fern") or name.contains("crop") or name.contains("sapling") or name.contains("vine") or name.contains("rail")

func _infer_stack_size_for_item(name: String) -> int:
	if name.ends_with("_pickaxe") or name.ends_with("_axe") or name.ends_with("_shovel") or name.ends_with("_hoe") or name.ends_with("_sword") or name.ends_with("_helmet") or name.ends_with("_chestplate") or name.ends_with("_leggings") or name.ends_with("_boots") or name in ["bow", "crossbow", "shield", "trident", "elytra", "fishing_rod", "flint_and_steel", "shears", "carrot_on_a_stick", "warped_fungus_on_a_stick", "brush", "debug_stick", "spyglass"]:
		return 1
	return 64

func load_asset_catalog(resource_root: String = "res://assets/minecraft") -> Dictionary:
	"""Index source model IDs for browsing/rendering; this does not implement their gameplay rules."""
	var root_path := resource_root.trim_suffix("/")
	var block_names := _source_names_in_folder(root_path.path_join("blockstates"))
	var item_model_names := _source_names_in_folder(root_path.path_join("models/item"))
	_source_item_model_names.clear()
	_source_blockstate_names.clear()
	for item_model_name in item_model_names:
		_source_item_model_names[String(item_model_name)] = true
	for source_block_name in block_names:
		_source_blockstate_names[String(source_block_name)] = true
	var added_blocks := 0
	var added_items := 0
	var next_block_id := 20000
	for block_name in block_names:
		if by_name.has(block_name):
			continue
		while blocks.has(next_block_id) or items.has(next_block_id):
			next_block_id += 1
		var definition := {
			"id": next_block_id,
			"name": block_name,
			"display_name": _display_name_for_source_id(block_name),
			"kind": "block",
			"solid": not _infer_non_solid_block(block_name),
			"opaque": not _infer_cutout_block(block_name),
			"hardness": 1.0,
			"drop": next_block_id,
			"stack_size": 64,
			"runtime_catalog_only": true,
			"creative_visible": item_model_names.has(block_name),
			"has_item_model": item_model_names.has(block_name),
			"behavior_status": "MODEL_AND_NAME_DISCOVERED_UNVERIFIED",
			"source_blockstate": root_path.path_join("blockstates").path_join(block_name + ".json")
		}
		blocks[next_block_id] = definition
		by_name[block_name] = next_block_id
		next_block_id += 1
		added_blocks += 1
	var next_item_id := 50000
	for item_name in item_model_names:
		if item_name in NON_ITEM_MODEL_TEMPLATES:
			continue
		if by_name.has(item_name):
			continue
		while blocks.has(next_item_id) or items.has(next_item_id):
			next_item_id += 1
		var definition := {
			"id": next_item_id,
			"name": item_name,
			"display_name": _display_name_for_source_id(item_name),
			"kind": "item",
			"stack_size": _infer_stack_size_for_item(item_name),
			"category": "source_model",
			"runtime_catalog_only": true,
			"creative_visible": true,
			"has_item_model": true,
			"behavior_status": "MODEL_AND_NAME_DISCOVERED_UNVERIFIED",
			"source_item_model": root_path.path_join("models/item").path_join(item_name + ".json")
		}
		items[next_item_id] = definition
		by_name[item_name] = next_item_id
		next_item_id += 1
		added_items += 1
	asset_catalog_counts = {"blocks_added": added_blocks, "items_added": added_items, "blockstate_models_found": block_names.size(), "item_models_found": item_model_names.size()}
	asset_catalog_loaded = not block_names.is_empty() or not item_model_names.is_empty()
	return asset_catalog_counts.duplicate(true)

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
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("name", "")).naturalnocasecmp_to(String(b.get("name", ""))) < 0)
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
