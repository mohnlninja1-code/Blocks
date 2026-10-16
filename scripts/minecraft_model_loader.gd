extends RefCounted
"""JSON model/blockstate resolver for a local Minecraft-style resource tree.

This resolves source definitions, not proof of visual parity. Geometry construction, lighting,
UV locking, animated materials and item render contexts remain separate rendering concerns.
"""

const MAX_PARENT_DEPTH := 48
const BUILTIN_PARENTS := [
	"builtin/generated", "builtin/entity", "block/block", "block/cube", "block/cube_all",
	"block/cube_bottom_top", "block/cube_column", "block/cube_column_horizontal",
	"block/cube_mirrored", "block/cube_mirrored_all", "block/cube_directional",
	"block/orientable", "block/orientable_vertical", "block/cross", "block/tinted_cross",
	"block/torch", "block/torch_wall", "block/crop", "block/rail", "block/rail_flat",
	"block/rail_raised_ne", "block/rail_raised_sw", "block/stairs", "block/slab",
	"block/fence_post", "block/fence_side", "block/wall_post", "block/wall_side",
	"block/wall_inventory", "item/generated", "item/handheld", "item/handheld_rod",
	"item/template_spawn_egg", "item/template_skull"
]

var asset_root := "res://assets/minecraft"
var last_error := ""
var _model_cache: Dictionary = {}
var _blockstate_cache: Dictionary = {}

func _init(root_path: String = "res://assets/minecraft") -> void:
	asset_root = root_path.trim_suffix("/")

func clear_cache() -> void:
	_model_cache.clear()
	_blockstate_cache.clear()
	last_error = ""

func _normalize_id(value: String, default_group: String = "block") -> String:
	var result := value.strip_edges()
	if result.contains(":"):
		var namespace := result.get_slice(":", 0)
		if namespace != "minecraft":
			return ""
		result = result.get_slice(":", 1)
	if result.begins_with("/"):
		return ""
	if result.ends_with(".json"):
		result = result.trim_suffix(".json")
	if not result.contains("/"):
		result = default_group + "/" + result
	if ".." in result or "\\" in result:
		return ""
	return result

func _path_for_model(model_id: String) -> String:
	var normalized := _normalize_id(model_id)
	if normalized.is_empty():
		return ""
	return asset_root.path_join("models").path_join(normalized + ".json")

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = "Cannot open model resource: %s" % path
		return {}
	var content := file.get_as_text()
	file.close()
	var parser := JSON.new()
	var parse_error := parser.parse(content)
	if parse_error != OK:
		last_error = "Malformed JSON in %s: %s at line %d" % [path, parser.get_error_message(), parser.get_error_line()]
		return {}
	if not parser.data is Dictionary:
		last_error = "Expected a JSON object at %s" % path
		return {}
	return parser.data

func _merge_dicts(parent_value: Dictionary, child_value: Dictionary) -> Dictionary:
	var result: Dictionary = parent_value.duplicate(true)
	for key in child_value:
		var child: Variant = child_value[key]
		if child is Dictionary and result.get(key) is Dictionary:
			result[key] = _merge_dicts(result[key], child)
		else:
			result[key] = child.duplicate(true) if child is Dictionary or child is Array else child
	return result

func resolve_model(model_id: String) -> Dictionary:
	last_error = ""
	return _resolve_model(model_id, [], 0)

func _resolve_model(model_id: String, ancestry: Array[String], depth: int) -> Dictionary:
	var normalized := _normalize_id(model_id)
	if normalized.is_empty():
		last_error = "Unsupported model resource location: %s" % model_id
		return {}
	if _model_cache.has(normalized):
		return (_model_cache[normalized] as Dictionary).duplicate(true)
	if depth > MAX_PARENT_DEPTH:
		last_error = "Model parent chain exceeded depth limit at %s" % normalized
		return {}
	if normalized in ancestry:
		last_error = "Model parent cycle detected: %s -> %s" % [", ".join(ancestry), normalized]
		return {}
	var path := _path_for_model(normalized)
	var own := _read_json(path)
	if own.is_empty():
		if normalized in BUILTIN_PARENTS:
			return {"model_id": normalized, "parent": "", "textures": {}, "elements": [], "display": {}, "overrides": [], "builtin_parent": true, "generated_item": normalized in ["builtin/generated", "item/generated"]}
		if last_error.is_empty():
			last_error = "Model file not found: %s" % path
		return {}
	var next_ancestry := ancestry.duplicate()
	next_ancestry.append(normalized)
	var resolved: Dictionary = {
		"model_id": normalized,
		"parent": String(own.get("parent", "")),
		"textures": {},
		"elements": [],
		"display": {},
		"overrides": [],
		"ambientocclusion": true,
		"source_path": path,
		"builtin_parent": false,
		"generated_item": false
	}
	var parent_id := String(own.get("parent", ""))
	if not parent_id.is_empty():
		var parent := _resolve_model(parent_id, next_ancestry, depth + 1)
		if parent.is_empty():
			return {}
		resolved = parent.duplicate(true)
		resolved["model_id"] = normalized
		resolved["parent"] = parent_id
		resolved["source_path"] = path
		resolved["builtin_parent"] = bool(parent.get("builtin_parent", false))
		resolved["generated_item"] = bool(parent.get("generated_item", false)) or parent_id in ["builtin/generated", "item/generated"]
		if own.has("elements"):
			resolved["elements"] = own["elements"].duplicate(true) if own["elements"] is Array else []
		if own.has("ambientocclusion"):
			resolved["ambientocclusion"] = bool(own["ambientocclusion"])
		if own.has("display"):
			resolved["display"] = _merge_dicts(resolved.get("display", {}), own.get("display", {}))
		if own.has("overrides"):
			resolved["overrides"] = own["overrides"].duplicate(true)
		if own.has("textures"):
			resolved["textures"] = _merge_dicts(resolved.get("textures", {}), own.get("textures", {}))
	else:
		for key in ["textures", "display", "overrides", "elements"]:
			if own.has(key):
				resolved[key] = own[key].duplicate(true) if own[key] is Dictionary or own[key] is Array else own[key]
		if own.has("ambientocclusion"):
			resolved["ambientocclusion"] = bool(own["ambientocclusion"])
		if normalized in ["builtin/generated", "item/generated"]:
			resolved["generated_item"] = true
	if not resolved.get("textures") is Dictionary:
		resolved["textures"] = {}
	if not resolved.get("elements") is Array:
		resolved["elements"] = []
	if not resolved.get("display") is Dictionary:
		resolved["display"] = {}
	if not resolved.get("overrides") is Array:
		resolved["overrides"] = []
	_model_cache[normalized] = resolved.duplicate(true)
	return resolved

func resolve_texture(texture_reference: String, textures: Dictionary, max_depth: int = 24) -> String:
	var value := texture_reference.strip_edges()
	for _depth in range(max_depth):
		if value.begins_with("#"):
			var alias := value.substr(1)
			if not textures.has(alias):
				last_error = "Unresolved texture alias %s" % value
				return ""
			value = String(textures[alias]).strip_edges()
		else:
			break
	if value.begins_with("#"):
		last_error = "Texture alias chain exceeded depth limit at %s" % value
		return ""
	if value.contains(":"):
		if value.get_slice(":", 0) != "minecraft":
			last_error = "Unsupported texture namespace: %s" % value
			return ""
		value = value.get_slice(":", 1)
	if value.ends_with(".png"):
		value = value.trim_suffix(".png")
	if value.begins_with("/") or ".." in value or "\\" in value:
		last_error = "Unsafe texture location: %s" % value
		return ""
	return asset_root.path_join("textures").path_join(value + ".png")

func load_blockstate(block_name: String) -> Dictionary:
	var normalized := _normalize_id(block_name)
	if normalized.is_empty():
		last_error = "Unsupported blockstate resource location: %s" % block_name
		return {}
	var path := asset_root.path_join("blockstates").path_join(normalized.trim_prefix("block/") + ".json")
	if _blockstate_cache.has(path):
		return (_blockstate_cache[path] as Dictionary).duplicate(true)
	var value := _read_json(path)
	if value.is_empty():
		if last_error.is_empty():
			last_error = "Blockstate file not found: %s" % path
		_blockstate_cache[path] = {"_missing_resource": true}
		return {}
	value["_source_path"] = path
	_blockstate_cache[path] = value.duplicate(true)
	return value

func _selector_matches(selector: String, states: Dictionary) -> bool:
	if selector.is_empty():
		return true
	var fields := selector.split(",", false)
	for field in fields:
		var pair := field.split("=", false, 2)
		if pair.size() != 2:
			return false
		var key := String(pair[0]).strip_edges()
		var expected := String(pair[1]).strip_edges()
		if not states.has(key):
			return false
		var accepted := expected.split("|", false)
		if not String(states[key]) in accepted:
			return false
	return true

func _default_variant_key(variants: Dictionary) -> String:
	var preferences := {
		"axis": "y", "facing": "north", "half": "lower", "part": "foot",
		"open": "false", "powered": "false", "lit": "false", "waterlogged": "false",
		"snowy": "false", "age": "0", "level": "0", "shape": "north_south",
		"rotation": "0", "face": "wall", "attachment": "floor", "hanging": "false",
		"berries": "false", "moisture": "0", "distance": "1", "attached": "false",
		"conditional": "false", "persistent": "false", "in_wall": "false",
		"hinge": "left", "enabled": "true", "triggered": "false", "occupied": "false",
		"signal_fire": "false", "type": "bottom", "layers": "1", "bites": "0",
		"candles": "1", "eggs": "1", "cracked": "false", "unstable": "false",
		"extended": "false", "eye": "false", "north": "none", "east": "none",
		"south": "none", "west": "none", "up": "false"
	}
	var best_key := ""
	var best_score := -1
	for key_value in variants.keys():
		var selector := String(key_value)
		if selector.is_empty():
			return ""
		var score := 0
		var rejected := false
		for term in selector.split(",", false):
			var pair := term.split("=", false, 2)
			if pair.size() != 2:
				rejected = true
				break
			var state_name := String(pair[0])
			var state_value := String(pair[1])
			if preferences.has(state_name):
				if state_value == String(preferences[state_name]):
					score += 2
				else:
					rejected = true
					break
			else:
				# Unrecognized dimensions should not beat known Java default values.
				score -= 1
		if not rejected and score > best_score:
			best_key = selector
			best_score = score
	if best_score >= 0:
		return best_key
	if not variants.is_empty():
		return String(variants.keys()[0])
	return ""

func _pick_weighted_variant(value: Variant, seed: int, position: Vector3i) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	if not value is Array or value.is_empty():
		return {}
	var total_weight := 0
	for entry in value:
		if entry is Dictionary:
			total_weight += maxi(1, int(entry.get("weight", 1)))
	if total_weight <= 0:
		return value[0].duplicate(true) if value[0] is Dictionary else {}
	var mixed := int(seed) ^ (position.x * 73856093) ^ (position.y * 19349663) ^ (position.z * 83492791)
	var roll := posmod(mixed, total_weight)
	for entry in value:
		if not entry is Dictionary:
			continue
		roll -= maxi(1, int(entry.get("weight", 1)))
		if roll < 0:
			return entry.duplicate(true)
	return value.back().duplicate(true) if value.back() is Dictionary else {}

func _condition_matches(condition: Variant, states: Dictionary) -> bool:
	if not condition is Dictionary:
		return false
	for key_value in condition:
		var key := String(key_value)
		var expected: Variant = condition[key_value]
		if key == "OR":
			if not expected is Array:
				return false
			var any_matches := false
			for clause in expected:
				if _condition_matches(clause, states):
					any_matches = true
					break
			if not any_matches:
				return false
		elif key == "AND":
			if not expected is Array:
				return false
			for clause in expected:
				if not _condition_matches(clause, states):
					return false
		else:
			if not states.has(key):
				return false
			var accepted := String(expected).split("|", false)
			if not String(states[key]) in accepted:
				return false
	return true

func select_block_models(block_name: String, states: Dictionary = {}, seed: int = 0, position: Vector3i = Vector3i.ZERO) -> Array[Dictionary]:
	var blockstate := load_blockstate(block_name)
	if blockstate.is_empty():
		return []
	var selected: Array[Dictionary] = []
	var variants: Variant = blockstate.get("variants", {})
	if variants is Dictionary and not variants.is_empty():
		var matched_key := ""
		var matched_specificity := -1
		for selector_value in variants:
			var selector := String(selector_value)
			if not _selector_matches(selector, states):
				continue
			var specificity := selector.split(",", false).size() if not selector.is_empty() else 0
			if specificity > matched_specificity:
				matched_key = selector
				matched_specificity = specificity
		if matched_key.is_empty() and variants.has(""):
			matched_key = ""
			matched_specificity = 0
		if matched_specificity >= 0:
			var variant := _pick_weighted_variant(variants[matched_key], seed, position)
			if not variant.is_empty():
				selected.append(variant)
	if selected.is_empty() and variants is Dictionary and not variants.is_empty() and states.is_empty() and not variants.has(""):
		var default_key := _default_variant_key(variants)
		if variants.has(default_key):
			var default_value: Variant = variants[default_key]
			var fallback := _pick_weighted_variant(default_value, seed, position)
			if not fallback.is_empty():
				selected.append(fallback)
	var multipart: Variant = blockstate.get("multipart", [])
	if multipart is Array:
		for part in multipart:
			if not part is Dictionary:
				continue
			var when_value: Variant = part.get("when", {})
			if when_value is Dictionary and not when_value.is_empty() and not _condition_matches(when_value, states):
				continue
			var part_models := _pick_weighted_variant(part.get("apply", {}), seed, position)
			if not part_models.is_empty():
				selected.append(part_models)
	return selected

func resolve_block_models(block_name: String, states: Dictionary = {}, seed: int = 0, position: Vector3i = Vector3i.ZERO) -> Array[Dictionary]:
	var references := select_block_models(block_name, states, seed, position)
	var resolved: Array[Dictionary] = []
	for reference in references:
		var model_id := String(reference.get("model", ""))
		var model := resolve_model(model_id)
		if model.is_empty():
			continue
		model["blockstate_rotation_x"] = int(reference.get("x", 0))
		model["blockstate_rotation_y"] = int(reference.get("y", 0))
		model["blockstate_rotation_z"] = int(reference.get("z", 0))
		model["blockstate_uvlock"] = bool(reference.get("uvlock", false))
		model["blockstate_model_id"] = model_id
		resolved.append(model)
	return resolved
