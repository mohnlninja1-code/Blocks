extends SceneTree
"""Focused tests for the current Survival hunger and damage implementation."""

var passes := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _check(condition: bool, label: String) -> void:
	if condition:
		passes += 1
		print("PASS SURVIVAL: ", label)
	else:
		failures += 1
		push_error("FAIL SURVIVAL: " + label)

func _run_tests() -> void:
	await process_frame
	var registry: Variant = root.get_node_or_null("BlockRegistry")
	_check(registry != null, "block/item registry autoload exists")
	var inventory_script: Script = load("res://scripts/inventory_model.gd")
	var player_script: Script = load("res://scripts/voxel_player.gd")
	var inventory: Variant = inventory_script.new(36)
	var player: Variant = player_script.new()
	player.inventory = inventory
	player.game_mode = "survival"
	player.set_difficulty("normal")
	root.add_child(player)
	await process_frame

	_check(is_equal_approx(player.health, 20.0) and is_equal_approx(player.hunger, 20.0), "new Survival player starts with full health and hunger")
	if registry != null:
		_check(is_equal_approx(float(registry.get_definition(1003).get("saturation_modifier", 0.0)), 0.3), "apple source definition has saturation modifier")
		_check(int(registry.get_definition(1008).get("food", 0)) == 4, "rotten flesh food value is four")

	inventory.add_item(1003, 2)
	inventory.set_selected(0)
	player.hunger = 12.0
	player.food_saturation = 1.0
	_check(player.eat_selected_item(), "Survival player eats a selected valid food")
	_check(is_equal_approx(player.hunger, 16.0), "apple restores four hunger points")
	_check(is_equal_approx(player.food_saturation, 3.4), "apple adds food saturation using its source value")
	_check(inventory.count_item(1003) == 1, "eating consumes exactly one item")
	player.hunger = 20.0
	_check(not player.eat_selected_item(), "ordinary food cannot be eaten at full hunger")
	_check(inventory.count_item(1003) == 1, "rejected eating leaves inventory unchanged")

	player.hunger = 10.0
	player.food_saturation = 3.0
	player.exhaustion = 3.9
	player.add_exhaustion(0.2)
	player.tick_survival()
	_check(is_equal_approx(player.food_saturation, 2.0), "exhaustion consumes saturation before hunger")
	_check(is_equal_approx(player.hunger, 10.0), "remaining saturation protects the hunger bar")
	_check(player.exhaustion < 0.2, "exhaustion threshold removes four exhaustion points")

	player.hunger = 10.0
	player.food_saturation = 0.0
	player.exhaustion = 4.0
	player.tick_survival()
	_check(is_equal_approx(player.hunger, 9.0), "exhaustion lowers hunger when saturation is empty")

	player.health = 10.0
	player.hunger = 20.0
	player.food_saturation = 5.0
	player.exhaustion = 0.0
	player._natural_regeneration_ticks = 9
	player.tick_survival()
	_check(is_equal_approx(player.health, 11.0), "saturated regeneration heals one health point at its interval")
	_check(is_equal_approx(player.exhaustion, 6.0), "natural regeneration adds exhaustion")

	player.health = 2.0
	player.hunger = 0.0
	player.food_saturation = 0.0
	player._starvation_ticks = 79
	player.difficulty = "normal"
	player.tick_survival()
	_check(is_equal_approx(player.health, 1.0), "Normal starvation does not lower health below one")

	player.health = 10.0
	player.difficulty = "easy"
	player._starvation_ticks = 79
	player.tick_survival()
	_check(is_equal_approx(player.health, 10.0), "Easy starvation does not lower health below ten")

	player.health = 20.0
	player.difficulty = "normal"
	_check(is_equal_approx(player.apply_fall_damage(2.9), 0.0), "fall below three blocks deals no damage")
	_check(is_equal_approx(player.apply_fall_damage(5.0), 2.0), "five-block fall deals two damage points")
	_check(is_equal_approx(player.health, 18.0), "fall damage reduces health")

	player.game_mode = "creative"
	player.health = 20.0
	_check(is_equal_approx(player.apply_fall_damage(12.0), 0.0), "Creative mode ignores fall damage")
	_check(not player.receive_damage(5.0, "test"), "Creative mode ignores direct damage")

	player.game_mode = "survival"
	player.difficulty = "hard"
	player.hunger = 7.0
	player.food_saturation = 2.5
	player.exhaustion = 1.25
	var snapshot: Dictionary = player.serialize()
	player.hunger = 1.0
	player.food_saturation = 0.0
	player.exhaustion = 0.0
	player.difficulty = "easy"
	player.deserialize(snapshot)
	_check(is_equal_approx(player.hunger, 7.0) and is_equal_approx(player.food_saturation, 2.5), "hunger and saturation survive player serialization")
	_check(String(player.difficulty) == "hard", "difficulty survives player serialization")
	player.queue_free()
	await process_frame
	print("SURVIVAL TESTS: %d passed; %d failed" % [passes, failures])
	quit(1 if failures > 0 else 0)
