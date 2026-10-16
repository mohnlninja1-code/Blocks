extends SceneTree
"""Isolated tests for Java-style recipe, tag, output and cooker JSON paths."""

var passes := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _check(condition: bool, label: String) -> void:
	if condition:
		passes += 1
		print("PASS RECIPE: ", label)
	else:
		failures += 1
		push_error("FAIL RECIPE: " + label)

func _run_tests() -> void:
	await process_frame
	var registry: Variant = root.get_node_or_null("BlockRegistry")
	var recipe_registry: Variant = root.get_node_or_null("RecipeRegistry")
	_check(registry != null, "block/item registry autoload is available")
	_check(recipe_registry != null, "recipe registry autoload is available")
	if registry == null or recipe_registry == null:
		quit(1)
		return

	var had_item: bool = registry.items.has(9001)
	var old_item: Dictionary = registry.items.get(9001, {}).duplicate(true) if had_item else {}
	var had_name: bool = registry.by_name.has("test_item")
	var old_name_id := int(registry.by_name.get("test_item", 0))
	registry.items[9001] = {
		"id": 9001,
		"name": "test_item",
		"display_name": "Test Item",
		"stack_size": 64,
		"category": "test_fixture"
	}
	registry.by_name["test_item"] = 9001

	recipe_registry.set_source_data_root("res://tests/fixtures/reference_data/minecraft")
	_check(int(recipe_registry.source_recipe_count) == 3, "loads three named source recipes and ignores pack index files")
	_check(recipe_registry.by_id.has("minecraft:source_shaped"), "source recipe IDs preserve the Minecraft namespace")

	var shaped_grid: Array = [
		{"id": 8, "count": 1}, {"id": 8, "count": 1},
		{"id": 0, "count": 0}, {"id": 0, "count": 0}
	]
	var shaped: Dictionary = recipe_registry.find_matching_recipe(shaped_grid, 2, "")
	_check(String(shaped.get("id", "")) == "minecraft:source_shaped", "matches source shaped recipe by pattern and ingredient ID")
	_check(int(shaped.get("output", {}).get("id", 0)) == 9001 and int(shaped.get("output", {}).get("count", 0)) == 4, "source-shaped result is normalized to a runtime item stack")
	_check(shaped.get("inputs", []) == [{"id": 8, "count": 2}], "craft transaction consumes the exact occupied crafting inputs")

	var inventory_script: Script = load("res://scripts/inventory_model.gd")
	var craft_inventory: Variant = inventory_script.new(4)
	craft_inventory.add_item(8, 2)
	_check(craft_inventory.craft(shaped), "source-shaped recipe can be executed by inventory transaction service")
	_check(craft_inventory.count_item(8) == 0 and craft_inventory.count_item(9001) == 4, "source-shaped crafting consumes input and inserts declared output")

	var tagged_grid: Array = [
		{"id": 9, "count": 1}, {"id": 0, "count": 0},
		{"id": 0, "count": 0}, {"id": 0, "count": 0}
	]
	var tagged: Dictionary = recipe_registry.find_matching_recipe(tagged_grid, 2, "")
	_check(String(tagged.get("id", "")) == "minecraft:source_tagged", "tagged shapeless recipe matches one occupied grid slot")
	_check(int(tagged.get("output", {}).get("count", 0)) == 2, "tag-based recipe result count is preserved")
	_check(int(tagged.get("inputs", [])[0].get("id", 0)) == 9, "tag-based recipe creates a concrete transaction cost")
	_check(int(recipe_registry.catalog_diagnostics().get("cached_item_tag_count", 0)) >= 2, "nested vanilla item-tag files are traversed")

	var smelt: Dictionary = recipe_registry.smelting_result(9, "furnace")
	_check(int(smelt.get("id", 0)) == 9001, "Java smelting recipe result string resolves to runtime ID")
	_check(is_equal_approx(float(smelt.get("seconds", 0.0)), 10.0), "Java cookingtime ticks convert to seconds at 20 ticks per second")
	_check(String(smelt.get("station", "")) == "furnace", "source smelting recipe maps to furnace station")

	recipe_registry.set_source_data_root("res://assets/reference_data/minecraft")
	if had_item:
		registry.items[9001] = old_item
	else:
		registry.items.erase(9001)
	if had_name:
		registry.by_name["test_item"] = old_name_id
	else:
		registry.by_name.erase("test_item")
	print("RECIPE TESTS: %d passed; %d failed" % [passes, failures])
	quit(1 if failures > 0 else 0)
