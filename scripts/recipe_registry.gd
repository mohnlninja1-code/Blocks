extends Node
"""Reference recipe loading and starter-format matching. Unimplemented ingredient tags stay non-matching."""

var recipes: Array = []
var smelting_recipes: Array = []
var by_id: Dictionary = {}
var _warned_once: Dictionary = {}
var _tag_cache: Dictionary = {}
var _source_data_root := "res://assets/reference_data/minecraft"
var source_recipe_count := 0
var source_tag_count := 0

func _ready() -> void:
	_reload()

func set_source_data_root(path: String) -> void:
	_source_data_root = path.trim_suffix("/")
	_reload()

func _reload() -> void:
	recipes = _read_array("res://data/recipes.json")
	smelting_recipes = _read_smelting("res://data/smelting_recipes.json")
	_tag_cache.clear()
	_warned_once.clear()
	source_recipe_count = 0
	source_tag_count = 0
	_load_source_recipes()
	by_id.clear()
	for value in recipes:
		if not value is Dictionary:
			continue
		var recipe: Dictionary = value
		var recipe_id := String(recipe.get("id", ""))
		if recipe_id.is_empty():
			push_warning("Ignoring recipe without stable ID.")
			continue
		if by_id.has(recipe_id):
			# Starter-format records take priority only when the source has the exact same ID.
			continue
		by_id[recipe_id] = recipe

func _read_smelting(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_warning("Optional smelting recipe source is missing: %s" % path)
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Array:
		return parsed
	if parsed is Dictionary:
		var result: Array = []
		for input_key in parsed:
			var row: Variant = parsed[input_key]
			if not row is Dictionary or not String(input_key).is_valid_int():
				continue
			var definition: Dictionary = row
			result.append({
				"input": int(input_key),
				"output": int(definition.get("output_id", 0)),
				"count": int(definition.get("output_count", 1)),
				"seconds": float(definition.get("seconds", 5.0)),
				"station": "furnace"
			})
		return result
	push_error("Smelting recipe source must be an array or an object keyed by input ID: %s" % path)
	return []

func _read_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_warning("Optional recipe source is missing: %s" % path)
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Array:
		return parsed
	push_error("Recipe source must be a JSON array: %s" % path)
	return []

func _collect_json_paths(current_path: String, output: Array[String]) -> void:
	var directory := DirAccess.open(current_path)
	if directory == null:
		return
	var files := directory.get_files()
	files.sort()
	for file_value in files:
		var file_name := String(file_value)
		if file_name.ends_with(".json") and not file_name.begins_with("_"):
			output.append(current_path.path_join(file_name))
	var folders := directory.get_directories()
	folders.sort()
	for folder_value in folders:
		_collect_json_paths(current_path.path_join(String(folder_value)), output)

func _relative_data_id(path: String, root_path: String) -> String:
	var relative := path.trim_prefix(root_path.trim_suffix("/") + "/")
	return relative.trim_suffix(".json").replace("\\", "/")

func _load_source_recipes() -> void:
	var recipe_root := _source_data_root.path_join("recipes")
	var paths: Array[String] = []
	_collect_json_paths(recipe_root, paths)
	paths.sort()
	for path in paths:
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
			push_warning("Skipping invalid supplied recipe JSON: %s" % path)
			continue
		var source_recipe: Dictionary = parser.data.duplicate(true)
		var recipe_type := String(source_recipe.get("type", ""))
		var source_id := "minecraft:" + _relative_data_id(path, recipe_root)
		source_recipe["id"] = source_id
		source_recipe["source_path"] = path
		source_recipe["source_pack_recipe"] = true
		if recipe_type in ["minecraft:smelting", "minecraft:blasting", "minecraft:smoking", "minecraft:campfire_cooking"]:
			smelting_recipes.append(source_recipe)
		else:
			recipes.append(source_recipe)
		source_recipe_count += 1

func _resolve_source_tag_id(tag_value: String) -> String:
	var tag_name := tag_value.strip_edges()
	if tag_name.begins_with("#"):
		tag_name = tag_name.substr(1)
	if tag_name.contains(":"):
		if tag_name.get_slice(":", 0) != "minecraft":
			return ""
		tag_name = tag_name.get_slice(":", 1)
	if tag_name.begins_with("/") or ".." in tag_name or "\\" in tag_name:
		return ""
	return tag_name

func _tag_contains_item(tag_value: String, item_id: int, visited: Array[String] = []) -> bool:
	var tag_name := _resolve_source_tag_id(tag_value)
	if tag_name.is_empty() or tag_name in visited:
		return false
	var cache_key := tag_name
	if _tag_cache.has(cache_key):
		var cached: Dictionary = _tag_cache[cache_key]
		source_tag_count = maxi(source_tag_count, int(cached.get("known_tag_count", source_tag_count)))
		var ids: Array = cached.get("item_ids", [])
		return item_id in ids
	var tag_path := _source_data_root.path_join("tags/items").path_join(tag_name + ".json")
	if not FileAccess.file_exists(tag_path):
		_tag_cache[cache_key] = {"item_ids": [], "missing": true, "known_tag_count": source_tag_count}
		return false
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(tag_path)) != OK or not parser.data is Dictionary:
		_tag_cache[cache_key] = {"item_ids": [], "invalid": true, "known_tag_count": source_tag_count}
		return false
	source_tag_count += 1
	var definition: Dictionary = parser.data
	var ids: Array[int] = []
	var next_visited: Array[String] = visited.duplicate()
	next_visited.append(tag_name)
	var values: Variant = definition.get("values", [])
	if values is Array:
		for value in values:
			var value_name := ""
			var required := true
			if value is String:
				value_name = String(value)
			elif value is Dictionary:
				value_name = String(value.get("id", ""))
				required = bool(value.get("required", true))
			else:
				continue
			if value_name.begins_with("#"):
				var nested_name := _resolve_source_tag_id(value_name)
				if nested_name.is_empty():
					continue
				var nested_ids := _resolve_source_tag_items(nested_name, next_visited)
				for nested_id in nested_ids:
					if not nested_id in ids:
						ids.append(nested_id)
			else:
				var resolved_id := _resolve_item_name(value_name)
				if resolved_id > 0 and not resolved_id in ids:
					ids.append(resolved_id)
				elif required and resolved_id == 0:
					# Required entries are present in the source tag, but the current runtime
					# catalog cannot reference that item yet. It remains a catalog gap.
					pass
	_tag_cache[cache_key] = {"item_ids": ids, "missing": false, "known_tag_count": source_tag_count}
	return item_id in ids

func _resolve_source_tag_items(tag_name: String, visited: Array[String]) -> Array[int]:
	var normalized := _resolve_source_tag_id(tag_name)
	if normalized.is_empty() or normalized in visited:
		return []
	var tag_path := _source_data_root.path_join("tags/items").path_join(normalized + ".json")
	if not FileAccess.file_exists(tag_path):
		return []
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(tag_path)) != OK or not parser.data is Dictionary:
		return []
	source_tag_count += 1
	var result: Array[int] = []
	var next_visited := visited.duplicate()
	next_visited.append(normalized)
	var definition: Dictionary = parser.data
	var values: Variant = definition.get("values", [])
	if not values is Array:
		return result
	for value in values:
		var value_name := ""
		if value is String:
			value_name = String(value)
		elif value is Dictionary:
			value_name = String(value.get("id", ""))
		else:
			continue
		if value_name.begins_with("#"):
			for nested_id in _resolve_source_tag_items(value_name.substr(1), next_visited):
				if not nested_id in result:
					result.append(nested_id)
		else:
			var resolved_id := _resolve_item_name(value_name)
			if resolved_id > 0 and not resolved_id in result:
				result.append(resolved_id)
	return result

func catalog_diagnostics() -> Dictionary:
	return {
		"starter_and_source_crafting_recipe_count": recipes.size(),
		"source_recipe_count": source_recipe_count,
		"source_cooking_recipe_count": maxi(0, smelting_recipes.size() - 2),
		"cached_item_tag_count": source_tag_count,
		"source_data_root": _source_data_root,
		"tag_status": "PARTIAL_SOURCE_TAG_RESOLVER_UNVERIFIED"
	}

func get_recipe(recipe_id: String) -> Dictionary:
	if not by_id.has(recipe_id):
		return {}
	return (by_id[recipe_id] as Dictionary).duplicate(true)

func _resolve_item_name(name: String) -> int:
	var bare_name := name
	if name.contains(":"):
		bare_name = name.get_slice(":", 1)
	if bare_name.is_empty():
		return 0
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		var registry: Variant = tree.root.get_node_or_null("BlockRegistry")
		if registry != null and registry.has_method("block_id"):
			return int(registry.block_id(bare_name))
	return 0

func _ingredient_matches(stack: Dictionary, ingredient: Variant) -> bool:
	var stack_id := int(stack.get("id", 0))
	if stack_id <= 0:
		return false
	if ingredient is int:
		return stack_id == int(ingredient)
	if ingredient is String:
		return stack_id == _resolve_item_name(String(ingredient))
	if ingredient is Array:
		for option in ingredient:
			if _ingredient_matches(stack, option):
				return true
		return false
	if not ingredient is Dictionary:
		return false
	var definition: Dictionary = ingredient
	if definition.has("item"):
		return stack_id == _resolve_item_name(String(definition["item"]))
	if definition.has("items"):
		var options: Variant = definition["items"]
		if options is Array:
			for option in options:
				if _ingredient_matches(stack, option):
					return true
		return false
	if definition.has("tag"):
		return _tag_contains_item(String(definition["tag"]), stack_id)
	return false

func _available_count(grid: Array, item_id: int) -> int:
	var amount := 0
	for value in grid:
		if value is Dictionary and int(value.get("id", 0)) == item_id:
			amount += maxi(0, int(value.get("count", 0)))
	return amount

func _matches_legacy_inputs(recipe: Dictionary, grid: Array) -> bool:
	var inputs: Variant = recipe.get("inputs", [])
	if not inputs is Array:
		return false
	var required: Dictionary = {}
	var required_item_count := 0
	for value in inputs:
		if not value is Dictionary:
			return false
		var item_id := int(value.get("id", 0))
		var count := int(value.get("count", 0))
		if item_id <= 0 or count <= 0:
			return false
		required[item_id] = int(required.get(item_id, 0)) + count
		required_item_count += count
	for item_id in required:
		if _available_count(grid, int(item_id)) < int(required[item_id]):
			return false
	var occupied := 0
	for stack_value in grid:
		if stack_value is Dictionary and int(stack_value.get("id", 0)) > 0 and int(stack_value.get("count", 0)) > 0:
			occupied += 1
	return occupied == required_item_count

func _key_ingredient(key: Dictionary, symbol: String) -> Variant:
	if not key.has(symbol):
		return null
	return key[symbol]

func _matches_shape_at(grid: Array, grid_width: int, grid_height: int, pattern: Array, key: Dictionary, offset_x: int, offset_y: int, mirrored: bool) -> bool:
	var shape_height := pattern.size()
	if shape_height == 0:
		return false
	var shape_width := 0
	for line in pattern:
		shape_width = maxi(shape_width, String(line).length())
	if shape_width == 0 or offset_x + shape_width > grid_width or offset_y + shape_height > grid_height:
		return false
	for y in range(grid_height):
		for x in range(grid_width):
			var slot_index := y * grid_width + x
			var stack: Dictionary = grid[slot_index] if slot_index < grid.size() and grid[slot_index] is Dictionary else {"id": 0, "count": 0}
			if int(stack.get("id", 0)) <= 0 or int(stack.get("count", 0)) <= 0:
				stack = {"id": 0, "count": 0}
			var in_shape := x >= offset_x and x < offset_x + shape_width and y >= offset_y and y < offset_y + shape_height
			var symbol := " "
			if in_shape:
				var line := String(pattern[y - offset_y])
				var pattern_x := x - offset_x
				if mirrored:
					pattern_x = shape_width - 1 - pattern_x
				if pattern_x < line.length():
					symbol = line.substr(pattern_x, 1)
			if symbol == " ":
				if int(stack.get("id", 0)) > 0:
					return false
			else:
				var ingredient: Variant = _key_ingredient(key, symbol)
				if ingredient == null or not _ingredient_matches(stack, ingredient):
					return false
	return true

func _matches_shaped(recipe: Dictionary, grid: Array, grid_width: int) -> bool:
	var pattern: Variant = recipe.get("pattern", [])
	var key: Variant = recipe.get("key", {})
	if not pattern is Array or not key is Dictionary or pattern.is_empty():
		return false
	var width := maxi(1, grid_width)
	var height := ceili(float(grid.size()) / float(width))
	var max_pattern_width := 0
	for line in pattern:
		max_pattern_width = maxi(max_pattern_width, String(line).length())
	if pattern.size() > height or max_pattern_width > width:
		return false
	for y in range(height - pattern.size() + 1):
		for x in range(width - max_pattern_width + 1):
			if _matches_shape_at(grid, width, height, pattern, key, x, y, false):
				return true
			if _matches_shape_at(grid, width, height, pattern, key, x, y, true):
				return true
	return false

func _matches_shapeless(recipe: Dictionary, grid: Array) -> bool:
	var ingredients: Variant = recipe.get("ingredients", [])
	if not ingredients is Array or ingredients.is_empty():
		return false
	var occupied: Array[int] = []
	for index in range(grid.size()):
		var stack: Dictionary = grid[index] if grid[index] is Dictionary else {"id": 0, "count": 0}
		if int(stack.get("id", 0)) > 0 and int(stack.get("count", 0)) > 0:
			occupied.append(index)
	if occupied.size() != ingredients.size():
		return false
	var candidates: Array = []
	for ingredient in ingredients:
		var found := -1
		for candidate_index in occupied:
			if candidate_index in candidates:
				continue
			var stack: Dictionary = grid[candidate_index]
			if _ingredient_matches(stack, ingredient):
				found = candidate_index
				break
		if found < 0:
			return false
		candidates.append(found)
	return true

func _station_matches(recipe: Dictionary, station: String) -> bool:
	var required := String(recipe.get("requires_station", ""))
	if required.is_empty():
		return true
	return required == station

func _grid_costs(grid: Array) -> Array:
	var costs: Dictionary = {}
	for value in grid:
		if not value is Dictionary:
			continue
		var stack: Dictionary = value
		var item_id := int(stack.get("id", 0))
		if item_id > 0 and int(stack.get("count", 0)) > 0:
			costs[item_id] = int(costs.get(item_id, 0)) + 1
	var result: Array = []
	for item_id in costs:
		result.append({"id": int(item_id), "count": int(costs[item_id])})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["id"]) < int(b["id"]))
	return result

func _normalize_matched_recipe(recipe: Dictionary, grid: Array) -> Dictionary:
	var result := recipe.duplicate(true)
	if result.has("output") and result.get("output") is Dictionary:
		return result
	var source_result: Variant = result.get("result", {})
	var result_name := ""
	var result_count := 1
	if source_result is Dictionary:
		result_name = String(source_result.get("item", ""))
		result_count = maxi(1, int(source_result.get("count", 1)))
	elif source_result is String:
		result_name = String(source_result)
	if result_name.is_empty():
		return {}
	var result_id := _resolve_item_name(result_name)
	if result_id <= 0:
		if not _warned_once.has("missing-output:" + result_name):
			push_warning("Source recipe output is not in the current runtime catalog: %s" % result_name)
			_warned_once["missing-output:" + result_name] = true
		return {}
	result["source_result"] = source_result.duplicate(true) if source_result is Dictionary or source_result is Array else source_result
	result["output"] = {"id": result_id, "count": result_count}
	result["inputs"] = _grid_costs(grid)
	result["source_recipe"] = true
	result["runtime_output_item_id"] = result_id
	return result

func find_matching_recipe(grid: Array, grid_width: int = 2, station: String = "") -> Dictionary:
	if grid.is_empty():
		return {}
	# Prefer actual Java source recipes: the starter catalog contains deliberately simplified
	# count-only recipes and must not override a source recipe's shaped grid semantics.
	for source_pass in [true, false]:
		for value in recipes:
			if not value is Dictionary:
				continue
			var recipe: Dictionary = value
			if bool(recipe.get("source_pack_recipe", false)) != source_pass:
				continue
			if not _station_matches(recipe, station):
				continue
			var matches := false
			if recipe.has("inputs"):
				matches = _matches_legacy_inputs(recipe, grid)
			elif String(recipe.get("type", "")).ends_with("_crafting_shaped") or recipe.has("pattern"):
				matches = _matches_shaped(recipe, grid, grid_width)
			elif String(recipe.get("type", "")).ends_with("_crafting_shapeless") or recipe.has("ingredients"):
				matches = _matches_shapeless(recipe, grid)
			if matches:
				var normalized := _normalize_matched_recipe(recipe, grid)
				if not normalized.is_empty():
					return normalized
	return {}

func _station_for_cooking_type(recipe_type: String) -> String:
	match recipe_type:
		"minecraft:smelting", "smelting": return "furnace"
		"minecraft:blasting", "blasting": return "blast_furnace"
		"minecraft:smoking", "smoking": return "smoker"
		"minecraft:campfire_cooking", "campfire_cooking": return "campfire"
		_: return ""

func smelting_result(item_id: int, station: String = "furnace") -> Dictionary:
	for value in smelting_recipes:
		if not value is Dictionary:
			continue
		var recipe: Dictionary = value
		var recipe_type := String(recipe.get("type", ""))
		var required_station := String(recipe.get("station", ""))
		if required_station.is_empty():
			required_station = _station_for_cooking_type(recipe_type)
		elif required_station.begins_with("minecraft:"):
			required_station = _station_for_cooking_type(required_station)
			if required_station.is_empty():
				required_station = String(recipe["station"]).get_slice(":", 1)
		if not required_station.is_empty() and required_station != station:
			continue
		var input_id := int(recipe.get("input", 0))
		var ingredient: Variant = recipe.get("ingredient", null)
		if recipe.has("input"):
			if input_id != item_id:
				continue
		elif ingredient != null:
			if not _ingredient_matches({"id": item_id, "count": 1}, ingredient):
				continue
		else:
			continue

		var output_id := int(recipe.get("output", 0))
		var output_count := int(recipe.get("count", 1))
		var result_value: Variant = recipe.get("result", null)
		if result_value is Dictionary:
			var output_definition: Dictionary = result_value
			if output_definition.has("item"):
				output_id = _resolve_item_name(String(output_definition["item"]))
				output_count = maxi(1, int(output_definition.get("count", output_count)))
			elif output_definition.has("id"):
				output_id = int(output_definition.get("id", output_id))
				output_count = maxi(1, int(output_definition.get("count", output_count)))
		elif result_value is String:
			output_id = _resolve_item_name(String(result_value))
		if output_id <= 0:
			continue
		var cooking_seconds := float(recipe.get("seconds", 5.0))
		if recipe.has("cookingtime"):
			cooking_seconds = maxf(0.05, float(recipe["cookingtime"]) / 20.0)
		return {
			"id": output_id,
			"count": output_count,
			"seconds": cooking_seconds,
			"experience": float(recipe.get("experience", 0.0)),
			"recipe_id": String(recipe.get("id", "")),
			"source_recipe": bool(recipe.get("source_pack_recipe", false)),
			"station": required_station if not required_station.is_empty() else station
		}
	return {}
