extends SceneTree
"""Focused engine smoke tests for the foundational services. Not a Java parity suite."""

var failures := 0
var passes := 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _check(condition: bool, label: String) -> void:
	if condition:
		passes += 1
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _run_tests() -> void:
	await process_frame
	var block_registry: Variant = root.get_node_or_null("BlockRegistry")
	if block_registry == null:
		block_registry = load("res://scripts/block_registry.gd").new()
		block_registry.name = "BlockRegistry"
		root.add_child(block_registry)
		await process_frame
	_check(block_registry.blocks.size() >= 19, "starter block registry loads")
	_check(block_registry.items.size() >= 8, "starter item registry loads")

	var inventory_script: Script = load("res://scripts/inventory_model.gd")
	var inventory: Variant = inventory_script.new(2)
	var remainder := int(inventory.add_item(9, 130))
	_check(remainder == 2 and inventory.count_item(9) == 128, "stack insert reports remainder without item loss")
	var before_failed_cost := JSON.stringify(inventory.serialize())
	_check(not inventory.consume_costs([{"id": 8, "count": 3}]), "insufficient crafting cost is rejected")
	_check(JSON.stringify(inventory.serialize()) == before_failed_cost, "failed cost transaction leaves inventory unchanged")

	var recipe_registry: Variant = root.get_node_or_null("RecipeRegistry")
	if recipe_registry == null:
		recipe_registry = load("res://scripts/recipe_registry.gd").new()
		recipe_registry.name = "RecipeRegistry"
		root.add_child(recipe_registry)
		await process_frame
	var crafting_grid: Array = [
		{"id": 9, "count": 1}, {"id": 9, "count": 1},
		{"id": 0, "count": 0}, {"id": 0, "count": 0}
	]
	var matching_recipe: Dictionary = recipe_registry.find_matching_recipe(crafting_grid, 2, "")
	_check(String(matching_recipe.get("id", "")) == "sticks", "starter recipe matcher recognizes two-plank stick recipe")

	var craft_inventory: Variant = inventory_script.new(4)
	craft_inventory.add_item(9, 2)
	var sticks_recipe: Dictionary = recipe_registry.get_recipe("sticks")
	_check(craft_inventory.craft(sticks_recipe), "valid starter craft consumes ingredients and creates output")
	_check(craft_inventory.count_item(9) == 0 and craft_inventory.count_item(1001) == 4, "craft output and ingredient counts are correct")
	var tight_inventory: Variant = inventory_script.new(1)
	tight_inventory.add_item(9, 64)
	var impossible_output := {"id": "transaction_rollback_test", "inputs": [{"id": 9, "count": 1}], "output": {"id": 9, "count": 4}}
	var tight_before := JSON.stringify(tight_inventory.serialize())
	_check(not tight_inventory.craft(impossible_output), "craft that exceeds output capacity fails")
	_check(JSON.stringify(tight_inventory.serialize()) == tight_before, "failed output capacity craft rolls inventory back")

	var saved_state: Dictionary = craft_inventory.serialize()
	var inventory_roundtrip: Variant = inventory_script.new(4)
	_check(inventory_roundtrip.deserialize(saved_state), "inventory state deserializes")
	_check(inventory_roundtrip.count_item(1001) == 4, "inventory state preserves stack data")

	var save_store: Variant = root.get_node_or_null("SaveStore")
	var owns_save_store := false
	if save_store == null:
		save_store = load("res://scripts/save_store.gd").new()
		save_store.name = "SaveStoreForTests"
		root.add_child(save_store)
		owns_save_store = true
	var slot := "blocks_ci_test_%d" % OS.get_process_id()
	var first_save: Dictionary = save_store.save_world(slot, {"seed": 111, "world_name": "CI World"})
	var second_save: Dictionary = save_store.save_world(slot, {"seed": 222, "world_name": "CI World"})
	_check(bool(first_save.get("ok", false)) and bool(second_save.get("ok", false)), "save store writes primary save and rotates backup")
	var save_path := String(second_save.get("path", ""))
	var corrupt_file := FileAccess.open(save_path, FileAccess.WRITE)
	if corrupt_file != null:
		corrupt_file.store_string("{ invalid JSON")
		corrupt_file.close()
	var recovered: Dictionary = save_store.load_world(slot)
	_check(bool(recovered.get("ok", false)) and bool(recovered.get("recovered_from_backup", false)), "save store recovers from last-good backup")
	if bool(recovered.get("ok", false)):
		var recovered_world: Dictionary = recovered.get("world", {})
		_check(int(recovered_world.get("seed", 0)) == 111, "backup recovery returns the earlier intact save")
	var absolute_save := ProjectSettings.globalize_path(save_path)
	var absolute_backup := ProjectSettings.globalize_path(save_path + ".bak")
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(absolute_save)
	if FileAccess.file_exists(save_path + ".bak"):
		DirAccess.remove_absolute(absolute_backup)
	if owns_save_store:
		save_store.queue_free()

	var world_script: Script = load("res://scripts/voxel_world.gd")
	var test_world: Variant = world_script.new()
	test_world.name = "WorldGenerationIntegrationTest"
	root.add_child(test_world)
	test_world.generate_world(1182026, 1)
	var height_a := int(test_world.surface_height_at(0, 0))
	var height_b := int(test_world.surface_height_at(0, 0))
	_check(height_a == height_b, "same seed and coordinates produce deterministic surface height")
	_check(height_a >= -56 and height_a <= 311, "terrain height stays inside Java vertical limits")
	_check(test_world.loaded_chunk_count() == 9, "nearby chunk region streams in as a 3-by-3 area")
	_check(int(test_world.get_block_at(Vector3i(0, height_a, 0))) == 1, "generated terrain column has its declared grass surface")
	_check(int(test_world.get_block_at(Vector3i(0, -64, 0))) == 5, "generated terrain preserves the minimum bedrock layer")
	var negative_height := int(test_world.surface_height_at(-1, -1))
	_check(int(test_world.get_block_at(Vector3i(-1, negative_height, -1))) == 1, "negative world coordinates address the correct terrain column")
	var edit_position := Vector3i(0, height_a + 1, 0)
	_check(test_world.set_block_at(edit_position, 9), "placing a block records a world edit")
	_check(int(test_world.get_block_at(edit_position)) == 9, "placed block is observable in chunk storage")
	var world_snapshot: Dictionary = test_world.save_state()
	_check(world_snapshot.get("edits", []).size() == 1, "world save state contains explicit block edit delta")
	_check(test_world.load_state(world_snapshot, 1), "world snapshot reload succeeds")
	_check(int(test_world.get_block_at(edit_position)) == 9, "block edit survives deterministic world regeneration and reload")
	test_world.queue_free()


	print("FOUNDATION TESTS: %d passed; %d failed" % [passes, failures])
	quit(1 if failures > 0 else 0)
