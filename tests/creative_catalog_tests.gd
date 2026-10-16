extends SceneTree
"""Smoke tests for the searchable source-backed Creative catalog UI."""

var passes := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _check(condition: bool, label: String) -> void:
	if condition:
		passes += 1
		print("PASS CATALOG: ", label)
	else:
		failures += 1
		push_error("FAIL CATALOG: " + label)

func _run_tests() -> void:
	await process_frame
	var main_script: Script = load("res://scripts/main.gd")
	var main_node: Node = main_script.new()
	main_node.name = "CatalogUITestMain"
	root.add_child(main_node)
	await process_frame

	var search_control: Variant = main_node.get("_creative_catalog_search")
	var catalog_grid: Variant = main_node.get("_creative_catalog_grid")
	var catalog_status: Variant = main_node.get("_creative_catalog_status")
	var mode_select: Variant = main_node.get("_mode_select")
	_check(search_control is LineEdit, "main scene constructs Creative catalog search input")
	_check(catalog_grid is GridContainer, "main scene constructs scrollable catalog grid")
	_check(catalog_status is Label, "catalog exposes asset/readiness status")
	_check(mode_select is OptionButton and (mode_select as OptionButton).selected == 1, "new world defaults to Creative mode")

	var registry: Variant = root.get_node_or_null("BlockRegistry")
	var item_catalog: Variant = root.get_node_or_null("ItemModelCatalog")
	_check(registry != null, "block registry autoload is available")
	_check(item_catalog != null, "item model catalog autoload is available")
	if registry == null or item_catalog == null:
		main_node.queue_free()
		quit(1)
		return
	var source_counts: Dictionary = registry.load_asset_catalog("res://tests/fixtures/minecraft")
	_check(int(source_counts.get("blockstate_models_found", 0)) >= 2, "registry discovers source blockstate filenames")
	_check(int(source_counts.get("item_models_found", 0)) >= 2, "registry discovers source item model filenames")
	_check(registry.by_name.has("test_item"), "source item model is mapped to a selectable catalog entry")
	_check(not registry.by_name.has("generated"), "built-in item model templates are not exposed as inventory items")
	if search_control is LineEdit and catalog_grid is GridContainer and catalog_status is Label:
		item_catalog.set_resource_root("res://tests/fixtures/minecraft")
		main_node.call("_filter_creative_catalog", "test item")
		await process_frame
		_check((catalog_grid as GridContainer).get_child_count() == 1, "catalog search shows a source-discovered item model")
		main_node.call("_filter_creative_catalog", "multipart_block")
		await process_frame
		_check((catalog_grid as GridContainer).get_child_count() == 0, "blockstate-only content without an inventory item model is hidden")
		main_node.call("_filter_creative_catalog", "stone")
		await process_frame
		_check((catalog_grid as GridContainer).get_child_count() > 0, "search finds registered stone-like content")
		_check((catalog_grid as GridContainer).get_child_count() <= 72, "visible catalog list is capped for mobile performance")
		main_node.call("_filter_creative_catalog", "__no_such_block_or_item__")
		await process_frame
		_check((catalog_grid as GridContainer).get_child_count() == 0, "unknown query removes stale catalog results")
		_check(String((catalog_status as Label).text).contains("No matches"), "empty search result shows useful status")
		item_catalog.set_resource_root("res://assets/minecraft")
	main_node.queue_free()
	await process_frame
	print("CATALOG TESTS: %d passed; %d failed" % [passes, failures])
	quit(1 if failures > 0 else 0)
