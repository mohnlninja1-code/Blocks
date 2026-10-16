extends Node
"""Cached source-model lookup for item UI textures and predicate-selected model definitions."""

const LOADER_SCRIPT = preload("res://scripts/minecraft_model_loader.gd")
const TEXTURE_KEY_PRIORITY := ["layer0", "layer1", "all", "texture", "particle", "side", "top", "front", "bottom"]

var resource_root := "res://assets/minecraft"
var model_loader: Variant
var _texture_cache: Dictionary = {}
var _resolved_cache: Dictionary = {}

func _ready() -> void:
	_create_loader()

func _create_loader() -> void:
	model_loader = LOADER_SCRIPT.new(resource_root)

func set_resource_root(path: String) -> void:
	resource_root = path.trim_suffix("/")
	_texture_cache.clear()
	_resolved_cache.clear()
	_create_loader()

func clear_caches() -> void:
	_texture_cache.clear()
	_resolved_cache.clear()
	if model_loader != null:
		model_loader.clear_cache()

func _definition_for_id(item_id: int) -> Dictionary:
	var registry: Variant = get_tree().root.get_node_or_null("BlockRegistry")
	if registry == null:
		return {}
	var definition: Dictionary = registry.get_definition(item_id)
	return definition

func _item_model_id(item_id: int) -> String:
	var definition := _definition_for_id(item_id)
	var name := String(definition.get("name", ""))
	if name.is_empty() or item_id == 0:
		return ""
	return "minecraft:item/" + name

func _override_matches(predicate: Dictionary, values: Dictionary) -> bool:
	for key_value in predicate:
		var key := String(key_value)
		var minimum := float(predicate[key_value])
		if float(values.get(key, 0.0)) < minimum:
			return false
	return true

func resolve_item_model(item_id: int, predicate_values: Dictionary = {}) -> Dictionary:
	if model_loader == null:
		_create_loader()
	var base_id := _item_model_id(item_id)
	if base_id.is_empty():
		return {}
	var cache_key := "%d|%s" % [item_id, JSON.stringify(predicate_values)]
	if _resolved_cache.has(cache_key):
		return (_resolved_cache[cache_key] as Dictionary).duplicate(true)
	var model := model_loader.resolve_model(base_id)
	if model.is_empty():
		# Some block-backed items use the block model directly when the item model file is absent.
		var block_fallback := "minecraft:block/" + String(_definition_for_id(item_id).get("name", ""))
		model = model_loader.resolve_model(block_fallback)
	if model.is_empty():
		return {}
	var overrides: Variant = model.get("overrides", [])
	if overrides is Array:
		for override_value in overrides:
			if not override_value is Dictionary:
				continue
			var override_definition: Dictionary = override_value
			var predicate: Variant = override_definition.get("predicate", {})
			if not predicate is Dictionary or not _override_matches(predicate, predicate_values):
				continue
			var override_id := String(override_definition.get("model", ""))
			if override_id.is_empty():
				continue
			var overridden := model_loader.resolve_model(override_id)
			if not overridden.is_empty():
				model = overridden
	model["requested_item_id"] = item_id
	model["requested_predicates"] = predicate_values.duplicate(true)
	_resolved_cache[cache_key] = model.duplicate(true)
	return model

func texture_paths_for_model(model: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if model_loader == null:
		_create_loader()
	var textures: Variant = model.get("textures", {})
	if not textures is Dictionary:
		return result
	var seen: Dictionary = {}
	for preferred_key in TEXTURE_KEY_PRIORITY:
		if textures.has(preferred_key):
			var path := String(model_loader.resolve_texture(String(textures[preferred_key]), textures))
			if not path.is_empty() and not seen.has(path):
				result.append(path)
				seen[path] = true
	for key in textures:
		var path := String(model_loader.resolve_texture(String(textures[key]), textures))
		if not path.is_empty() and not seen.has(path):
			result.append(path)
			seen[path] = true
	return result

func primary_texture_path(item_id: int, predicate_values: Dictionary = {}) -> String:
	var model := resolve_item_model(item_id, predicate_values)
	var paths := texture_paths_for_model(model)
	for path in paths:
		if ResourceLoader.exists(path):
			return path
	if not paths.is_empty():
		return paths[0]
	var definition := _definition_for_id(item_id)
	var icon_path := String(definition.get("icon", ""))
	if not icon_path.is_empty():
		return icon_path
	return ""

func texture_for_item_id(item_id: int, predicate_values: Dictionary = {}) -> Texture2D:
	if item_id <= 0:
		return null
	var key := "%d|%s" % [item_id, JSON.stringify(predicate_values)]
	if _texture_cache.has(key):
		return _texture_cache[key] as Texture2D
	var path := primary_texture_path(item_id, predicate_values)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var texture := load(path) as Texture2D
	if texture != null:
		_texture_cache[key] = texture
	return texture

func diagnostics_for_item_id(item_id: int) -> Dictionary:
	var model_id := _item_model_id(item_id)
	var model := resolve_item_model(item_id)
	return {
		"item_id": item_id,
		"model_id": model_id,
		"model_resolved": not model.is_empty(),
		"parent": String(model.get("parent", "")),
		"generated_item": bool(model.get("generated_item", false)),
		"element_count": (model.get("elements", []) as Array).size(),
		"texture_paths": texture_paths_for_model(model),
		"override_count": (model.get("overrides", []) as Array).size(),
		"source_path": String(model.get("source_path", "")),
		"resolver_error": String(model_loader.last_error) if model_loader != null else "Resolver not created"
	}
