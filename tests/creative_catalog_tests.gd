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
	if search_control is LineEdit and catalog_grid is GridContainer and catalog_status is Label:
		main_node.call("_filter_creative_catalog", "stone")
		await process_frame
		_check((catalog_grid as GridContainer).get_child_count() > 0, "search finds registered stone-like content")
		_check((catalog_grid as GridContainer).get_child_count() <= 72, "visible catalog list is capped for mobile performance")
		main_node.call("_filter_creative_catalog", "__no_such_block_or_item__")
		await process_frame
		_check((catalog_grid as GridContainer).get_child_count() == 0, "unknown query removes stale catalog results")
		_check(String((catalog_status as Label).text).contains("No matches"), "empty search result shows useful status")
	main_node.queue_free()
	await process_frame
	print("CATALOG TESTS: %d passed; %d failed" % [passes, failures])
	quit(1 if failures > 0 else 0)
