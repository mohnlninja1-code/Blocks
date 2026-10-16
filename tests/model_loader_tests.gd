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
	var gui_rotation: Variant = gui.get("rotation", [])
	print("MODEL TEST DISPLAY TRANSFORM: ", JSON.stringify(gui))
	_check(gui_rotation is Array and gui_rotation.size() == 3 and int(gui_rotation[0]) == 30 and int(gui_rotation[1]) == 225 and int(gui_rotation[2]) == 0, "display transform is inherited")
	print("MODEL TEST CHECKPOINT 3: generated item model")
	var item_model: Dictionary = model_loader.resolve_model("minecraft:item/test_item")
	_check(bool(item_model.get("generated_item", false)), "recognizes generated item parent")
	_check((item_model.get("overrides", []) as Array).size() == 1, "keeps model predicate overrides")
	print("MODEL TEST CHECKPOINT 4: state variants")
	var default_variants: Array[Dictionary] = model_loader.select_block_models("test_block", {})
	_check(default_variants.size() == 1 and String(default_variants[0].get("model", "")) == "minecraft:block/test_block", "default variant selects expected model")
	var default_with_unrelated_state: Array[Dictionary] = model_loader.select_block_models("test_block", {"powered": "true"})
	_check(default_with_unrelated_state.size() == 1 and String(default_with_unrelated_state[0].get("model", "")) == "minecraft:block/test_block", "empty-key blockstate variant remains a fallback for other state properties")
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
	print("MODEL TEST CHECKPOINT 6B: item catalog source textures")
	var registry_for_item_test: Variant = root.get_node_or_null("BlockRegistry")
	var catalog_for_item_test: Variant = root.get_node_or_null("ItemModelCatalog")
	var had_item_test_definition: bool = registry_for_item_test != null and registry_for_item_test.items.has(9001)
	var saved_item_test_definition: Dictionary = registry_for_item_test.items.get(9001, {}).duplicate(true) if had_item_test_definition else {}
	if registry_for_item_test != null:
		registry_for_item_test.items[9001] = {"id": 9001, "name": "test_item", "display_name": "Test Item", "stack_size": 64}
	if catalog_for_item_test != null and registry_for_item_test != null:
		catalog_for_item_test.set_resource_root("res://tests/fixtures/minecraft")
		var catalog_model: Dictionary = catalog_for_item_test.resolve_item_model(9001)
		_check(not catalog_model.is_empty(), "item catalog resolves item model by registered item ID")
		_check(String(catalog_for_item_test.primary_texture_path(9001)).ends_with("textures/item/test_item.png"), "item catalog picks source-model texture layer for icon")
		var diagnostics: Dictionary = catalog_for_item_test.diagnostics_for_item_id(9001)
		_check(bool(diagnostics.get("model_resolved", false)), "item model diagnostics expose resolved source data")
		catalog_for_item_test.set_resource_root("res://assets/minecraft")
	if registry_for_item_test != null:
		if had_item_test_definition:
			registry_for_item_test.items[9001] = saved_item_test_definition
		else:
			registry_for_item_test.items.erase(9001)
	print("MODEL TEST CHECKPOINT 7: isolated chunk mesh integration")
	var registry: Variant = root.get_node_or_null("BlockRegistry")
	var had_test_definition: bool = registry != null and registry.blocks.has(9000)
	var saved_test_definition: Dictionary = registry.blocks.get(9000, {}).duplicate(true) if had_test_definition else {}
	if registry != null:
		registry.blocks[9000] = {"id": 9000, "name": "test_block", "display_name": "Model Test Block", "solid": true, "hardness": 1.0}
	var world_script: Script = load("res://scripts/voxel_world.gd")
	var render_world: Variant = world_script.new()
	render_world.name = "ModelMeshIntegrationWorld"
	root.add_child(render_world)
	print("MODEL TEST CHECKPOINT 7A: world node attached")
	render_world.configure_model_root("res://tests/fixtures/minecraft")
	print("MODEL TEST CHECKPOINT 7B: model root configured")
	var chunk_root := Node3D.new()
	chunk_root.name = "Chunk_0_0_Test"
	chunk_root.position.y = render_world.MIN_Y
	render_world.add_child(chunk_root)
	var chunk_data := PackedInt32Array()
	chunk_data.resize(render_world.CHUNK_VOLUME)
	chunk_data.fill(0)
	var local_y: int = 200 - render_world.MIN_Y
	chunk_data[render_world._cell_index(2, local_y, 2)] = 9000
	var test_cell_index: int = render_world._cell_index(2, local_y, 2)
	render_world._chunks[Vector2i.ZERO] = {"data": chunk_data, "occupied": {test_cell_index: true}, "root": chunk_root}
	print("MODEL TEST CHECKPOINT 7C: starting sparse chunk model mesh build")
	render_world._rebuild_chunk(Vector2i.ZERO)
	print("MODEL TEST CHECKPOINT 7D: sparse chunk model mesh built")
	var mesh_instance := chunk_root.get_node_or_null("TerrainMesh") as MeshInstance3D
	_check(mesh_instance != null and mesh_instance.mesh != null, "chunk renderer builds a mesh from resolved model JSON")
	if mesh_instance != null and mesh_instance.mesh is ArrayMesh:
		var mesh: ArrayMesh = mesh_instance.mesh
		_check(mesh.get_surface_count() == 6, "one six-face model builds six texture-material surfaces")
		var complete_surface_geometry := true
		for surface_index in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if vertices.size() != 6:
				complete_surface_geometry = false
				break
		_check(complete_surface_geometry, "each emitted model face has two triangles and six vertices")
	render_world.queue_free()
	print("MODEL TEST CHECKPOINT 8: item model scene node")
	var item_catalog: Variant = root.get_node_or_null("ItemModelCatalog")
	if item_catalog != null and registry != null:
		item_catalog.set_resource_root("res://tests/fixtures/minecraft")
		var item_node: Node3D = load("res://scripts/item_model_renderer.gd").new().create_item_node(9000, "gui")
		_check(item_node != null, "item renderer creates a node from catalog model data")
		var item_mesh: MeshInstance3D = item_node.get_node_or_null("ItemModel") as MeshInstance3D
		_check(item_mesh != null and item_mesh.mesh != null, "block-backed item inherits element geometry for GUI context")
		_check(item_mesh.mesh.get_surface_count() == 6, "block-backed item mesh keeps six model face surfaces")
		item_node.free()
		item_catalog.set_resource_root("res://assets/minecraft")
	else:
		_check(false, "ItemModelCatalog autoload is available for item render integration tests")
	print("MODEL TEST CHECKPOINT 8B: generated item pixel-edge extrusion")
	var item_renderer_for_extrusion: Variant = load("res://scripts/item_model_renderer.gd").new()
	var one_pixel_image := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	one_pixel_image.fill(Color(0, 0, 0, 0))
	one_pixel_image.set_pixel(1, 1, Color.WHITE)
	var one_pixel_texture := ImageTexture.create_from_image(one_pixel_image)
	print("MODEL TEST CHECKPOINT 8C: extruding single-pixel source texture")
	var one_pixel_mesh: ArrayMesh = item_renderer_for_extrusion._build_generated_layer_mesh(one_pixel_texture, 0)
	print("MODEL TEST CHECKPOINT 8D: single-pixel texture mesh built")
	_check(one_pixel_mesh.get_surface_count() == 1, "generated-item layer builds one mesh surface from source texture data")
	if one_pixel_mesh.get_surface_count() == 1:
		var one_pixel_arrays: Array = one_pixel_mesh.surface_get_arrays(0)
		_check((one_pixel_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() == 24, "one opaque pixel extrudes four boundary sides plus front/back")
		_check((one_pixel_arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() == 36, "one-pixel generated model indices describe six quads")
	var filled_image := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	filled_image.fill(Color.WHITE)
	var filled_texture := ImageTexture.create_from_image(filled_image)
	print("MODEL TEST CHECKPOINT 8E: extruding opaque source texture")
	var filled_mesh: ArrayMesh = item_renderer_for_extrusion._build_generated_layer_mesh(filled_texture, 0)
	print("MODEL TEST CHECKPOINT 8F: opaque texture mesh built")
	if filled_mesh.get_surface_count() == 1:
		var filled_arrays: Array = filled_mesh.surface_get_arrays(0)
		_check((filled_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() == 56, "opaque 3x3 texture extrudes only its twelve outside pixel edges")
	else:
		_check(false, "opaque 3x3 texture produces a generated model surface")
	if registry != null:
		if had_test_definition:
			registry.blocks[9000] = saved_test_definition
		else:
			registry.blocks.erase(9000)
	print("MODEL TESTS: %d passed; %d failed" % [passes, failures])
	quit(1 if failures > 0 else 0)
