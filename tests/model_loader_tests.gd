extends SceneTree
"""Isolated tests for the Minecraft JSON model and blockstate resolver."""

var failures := 0
var passes := 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _check(condition: bool, label: String) -> void:
	if condition:
		passes += 1
		print("PASS MODEL: ", label)
	else:
		failures += 1
		push_error("FAIL MODEL: " + label)

func _run_tests() -> void:
	await process_frame
	print("MODEL TEST CHECKPOINT 1: loading resolver")
	var loader_script: Script = load("res://scripts/minecraft_model_loader.gd")
	var model_loader: Variant = loader_script.new("res://tests/fixtures/minecraft")
	print("MODEL TEST CHECKPOINT 2: resolving block parent chain")
	var resolved_block_model: Dictionary = model_loader.resolve_model("minecraft:block/test_block")
	_check(not resolved_block_model.is_empty(), "resolves child block model")
	_check((resolved_block_model.get("elements", []) as Array).size() == 1, "inherits parent element geometry")
	var texture_layers: Dictionary = resolved_block_model.get("textures", {})
	_check(String(texture_layers.get("all", "")) == "minecraft:block/test_block", "child texture overrides parent alias")
	var texture_path := String(model_loader.resolve_texture("#all", texture_layers))
	_check(texture_path == "res://tests/fixtures/minecraft/textures/block/test_block.png", "texture alias resolves resource path")
	var display: Dictionary = resolved_block_model.get("display", {})
	var gui: Dictionary = display.get("gui", {})
	_check(String(gui.get("rotation", [])) == "[30, 225, 0]", "display transform is inherited")
	print("MODEL TEST CHECKPOINT 3: generated item model")
	var item_model: Dictionary = model_loader.resolve_model("minecraft:item/test_item")
	_check(bool(item_model.get("generated_item", false)), "recognizes generated item parent")
	_check((item_model.get("overrides", []) as Array).size() == 1, "keeps model predicate overrides")
	print("MODEL TEST CHECKPOINT 4: state variants")
	var default_variants: Array[Dictionary] = model_loader.select_block_models("test_block", {})
	_check(default_variants.size() == 1 and String(default_variants[0].get("model", "")) == "minecraft:block/test_block", "default variant selects expected model")
	var north_variants: Array[Dictionary] = model_loader.select_block_models("test_block", {"facing": "north"})
	_check(north_variants.size() == 1 and int(north_variants[0].get("y", 0)) == 90, "specific selector includes state rotation")
	var axis_first: Array[Dictionary] = model_loader.select_block_models("test_block", {"axis": "x"}, 7, Vector3i(2, 3, 4))
	var axis_second: Array[Dictionary] = model_loader.select_block_models("test_block", {"axis": "x"}, 7, Vector3i(2, 3, 4))
	_check(axis_first.size() == 1 and JSON.stringify(axis_first) == JSON.stringify(axis_second), "weighted model choice is deterministic for fixed seed and position")
	print("MODEL TEST CHECKPOINT 5: multipart")
	var multipart_default: Array[Dictionary] = model_loader.select_block_models("multipart_block", {})
	_check(multipart_default.size() == 1, "selects unconditional multipart application")
	var multipart_east: Array[Dictionary] = model_loader.select_block_models("multipart_block", {"facing": "east"})
	_check(multipart_east.size() == 2, "matches multipart OR condition")
	print("MODEL TEST CHECKPOINT 6: negative paths")
	var cycle_model: Dictionary = model_loader.resolve_model("cycle_a")
	_check(cycle_model.is_empty() and model_loader.last_error.contains("cycle"), "rejects parent cycles with diagnostic")
	var missing_model: Dictionary = model_loader.resolve_model("missing_model")
	_check(missing_model.is_empty() and not model_loader.last_error.is_empty(), "reports missing model file")
	print("MODEL TESTS: %d passed; %d failed" % [passes, failures])
	quit(1 if failures > 0 else 0)
