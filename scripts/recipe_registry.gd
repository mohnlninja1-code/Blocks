extends Node
"""Reference recipe loading and starter-format matching. Unimplemented ingredient tags stay non-matching."""

var recipes: Array = []
var smelting_recipes: Array = []
var by_id: Dictionary = {}
var _warned_once: Dictionary = {}

func _ready() -> void:
	_reload()

func _reload() -> void:
	recipes = _read_array("res://data/recipes.json")
	smelting_recipes = _read_smelting("res://data/smelting_recipes.json")
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
			push_error("Duplicate recipe ID: %s" % recipe_id)
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
		var key := "tag:" + String(definition["tag"])
		if not _warned_once.has(key):
			push_warning("Recipe ingredient tag requires the not-yet-integrated 1.18.2 tag registry: %s" % definition["tag"])
			_warned_once[key] = true
		return false
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

func find_matching_recipe(grid: Array, grid_width: int = 2, station: String = "") -> Dictionary:
	if grid.is_empty():
		return {}
	for value in recipes:
		if not value is Dictionary:
			continue
		var recipe: Dictionary = value
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
			return recipe.duplicate(true)
	return {}

func smelting_result(item_id: int, station: String = "furnace") -> Dictionary:
	for value in smelting_recipes:
		if not value is Dictionary:
			continue
		var recipe: Dictionary = value
		var required_station := String(recipe.get("station", recipe.get("type", "furnace")))
		if required_station.begins_with("minecraft:"):
			required_station = required_station.get_slice(":", 1)
		if required_station != station and not (station == "furnace" and required_station in ["smelting", "furnace"]):
			continue
		var input_id := int(recipe.get("input", recipe.get("ingredient", 0)))
		if input_id == item_id:
			var output_id := int(recipe.get("output", 0))
			var output_count := int(recipe.get("count", 1))
			if recipe.get("result", {}) is Dictionary:
				var output: Dictionary = recipe["result"]
				output_id = int(output.get("id", output_id))
				output_count = int(output.get("count", output_count))
			return {"id": output_id, "count": output_count}
	return {}
