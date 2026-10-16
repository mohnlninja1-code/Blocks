extends Node3D
"""Playable runtime entry point. The current world rules are a foundation, not Java parity."""

const WORLD_SCRIPT = preload("res://scripts/voxel_world.gd")
const PLAYER_SCRIPT = preload("res://scripts/voxel_player.gd")
const INVENTORY_SCRIPT = preload("res://scripts/inventory_model.gd")

var world: Variant
var player: Variant
var inventory: Variant
var sun: DirectionalLight3D
var environment: WorldEnvironment
var _world_name := "New World"
var _active_slot := "new_world"
var _game_mode := "survival"
var _world_clock := 0.25
var _stream_timer := 0.0
var _autosave_timer := 0.0
var _hud_refresh_timer := 0.0
var _ui_layer: CanvasLayer
var _ui_root: Control
var _menu_root: Control
var _hud_root: Control
var _pause_root: Control
var _inventory_panel: PanelContainer
var _inventory_slots_view: GridContainer
var _creative_catalog_view: VBoxContainer
var _inventory_tab_button: Button
var _catalog_tab_button: Button
var _creative_catalog_search: LineEdit
var _creative_catalog_grid: GridContainer
var _creative_catalog_status: Label
var _creative_catalog_buttons: Array[Button] = []
var _creative_catalog_max_visible := 72
var _world_name_input: LineEdit
var _seed_input: LineEdit
var _mode_select: OptionButton
var _world_type_select: OptionButton
var _save_list: VBoxContainer
var _hotbar_buttons: Array[Button] = []
var _inventory_buttons: Array[Button] = []
var _status_label: Label
var _health_label: Label
var _selected_label: Label
var _touch_controls: Array[Button] = []
var _is_menu_visible := true

func _ready() -> void:
	_setup_environment()
	_create_ui()
	_show_main_menu()

func _setup_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	environment = world_environment
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.39, 0.57, 0.76)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.66, 0.70, 0.77)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = env
	add_child(world_environment)
	sun = DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(-32.0), 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

func _create_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "GameUI"
	add_child(_ui_layer)
	_ui_root = Control.new()
	_ui_root.name = "UIRoot"
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_ui_layer.add_child(_ui_root)
	_create_main_menu()
	_create_hud()
	_create_pause_menu()
	_create_inventory_panel()

func _style_panel(panel: PanelContainer, color: Color = Color(0.075, 0.085, 0.10, 0.97)) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.34, 0.39, 0.43, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", style)

func _style_button(button: Button, min_size: Vector2 = Vector2(0, 42)) -> void:
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color(0.94, 0.95, 0.97))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(0.74, 0.84, 0.68))
	button.focus_mode = Control.FOCUS_NONE

func _create_main_menu() -> void:
	_menu_root = Control.new()
	_menu_root.name = "MainMenu"
	_menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.add_child(_menu_root)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 500)
	_style_panel(panel)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)

	var title := Label.new()
	title.text = "BLOCKS: VOXEL FRONTIER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.81, 0.88, 0.72))
	content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Survival • Biome-rich Overworld • Java 1.18.2 target"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.72, 0.76, 0.81))
	content.add_child(subtitle)

	content.add_child(_field_label("World name"))
	_world_name_input = LineEdit.new()
	_world_name_input.text = "New World"
	_world_name_input.placeholder_text = "World name"
	_world_name_input.custom_minimum_size.y = 38
	content.add_child(_world_name_input)
	content.add_child(_field_label("Seed"))
	_seed_input = LineEdit.new()
	_seed_input.text = "1182026"
	_seed_input.placeholder_text = "Enter an integer seed"
	_seed_input.custom_minimum_size.y = 38
	content.add_child(_seed_input)
	content.add_child(_field_label("World type"))
	_world_type_select = OptionButton.new()
	_world_type_select.add_item("Overworld (biomes)", 0)
	_world_type_select.add_item("Superflat", 1)
	_world_type_select.select(0)
	content.add_child(_world_type_select)
	_mode_select = OptionButton.new()
	_mode_select.add_item("Survival", 0)
	_mode_select.add_item("Creative", 1)
	_mode_select.select(0)
	content.add_child(_mode_select)
	var start_button := Button.new()
	start_button.text = "Create New World"
	_style_button(start_button, Vector2(0, 46))
	start_button.pressed.connect(_on_create_world)
	content.add_child(start_button)

	var saved_header := Label.new()
	saved_header.text = "SAVED WORLDS"
	saved_header.add_theme_font_size_override("font_size", 13)
	saved_header.add_theme_color_override("font_color", Color(0.79, 0.83, 0.87))
	content.add_child(saved_header)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 96)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	_save_list = VBoxContainer.new()
	_save_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_save_list)

func _field_label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_color_override("font_color", Color(0.83, 0.86, 0.88))
	return label

func _create_hud() -> void:
	_hud_root = Control.new()
	_hud_root.name = "HUD"
	_hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_root.visible = false
	_hud_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_ui_root.add_child(_hud_root)

	_health_label = Label.new()
	_health_label.position = Vector2(18, 14)
	_health_label.add_theme_font_size_override("font_size", 18)
	_health_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.84))
	_hud_root.add_child(_health_label)

	_selected_label = Label.new()
	_selected_label.position = Vector2(18, 42)
	_selected_label.add_theme_font_size_override("font_size", 15)
	_selected_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.95))
	_hud_root.add_child(_selected_label)

	var pause_button := Button.new()
	pause_button.text = "Ⅱ"
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_button.offset_left = -58
	pause_button.offset_right = -14
	pause_button.offset_top = 14
	pause_button.offset_bottom = 58
	_style_button(pause_button, Vector2(44, 44))
	pause_button.pressed.connect(_show_pause_menu)
	_hud_root.add_child(pause_button)

	var inventory_button := Button.new()
	inventory_button.text = "Inventory"
	inventory_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	inventory_button.offset_left = -166
	inventory_button.offset_right = -68
	inventory_button.offset_top = 14
	inventory_button.offset_bottom = 58
	_style_button(inventory_button, Vector2(98, 44))
	inventory_button.pressed.connect(_toggle_inventory)
	_hud_root.add_child(inventory_button)

	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -12
	crosshair.offset_right = 12
	crosshair.offset_top = -18
	crosshair.offset_bottom = 18
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.add_theme_font_size_override("font_size", 25)
	crosshair.add_theme_color_override("font_color", Color(1, 1, 1, 0.86))
	_hud_root.add_child(crosshair)

	var hotbar_positioner := CenterContainer.new()
	hotbar_positioner.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hotbar_positioner.offset_top = -82
	hotbar_positioner.offset_bottom = -10
	hotbar_positioner.mouse_filter = Control.MOUSE_FILTER_PASS
	_hud_root.add_child(hotbar_positioner)
	var hotbar_panel := PanelContainer.new()
	hotbar_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_style_panel(hotbar_panel, Color(0.06, 0.065, 0.07, 0.82))
	hotbar_positioner.add_child(hotbar_panel)
	var hotbar := HBoxContainer.new()
	hotbar.add_theme_constant_override("separation", 3)
	hotbar_panel.add_child(hotbar)
	for index in range(9):
		var button := Button.new()
		_style_button(button, Vector2(68, 54))
		button.add_theme_font_size_override("font_size", 11)
		button.pressed.connect(_select_hotbar.bind(index))
		hotbar.add_child(button)
		_hotbar_buttons.append(button)

	_create_touch_controls()

func _create_touch_controls() -> void:
	# On-screen controls are shown on mobile only; all state uses press/release signals.
	var movement_controls := [
		{"name": "forward", "text": "▲", "x": 82, "top": -194},
		{"name": "left", "text": "◀", "x": 20, "top": -132},
		{"name": "right", "text": "▶", "x": 144, "top": -132},
		{"name": "back", "text": "▼", "x": 82, "top": -132}
	]
	for definition in movement_controls:
		var button := Button.new()
		button.text = String(definition["text"])
		button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		button.offset_left = float(definition["x"])
		button.offset_right = float(definition["x"]) + 56.0
		button.offset_top = float(definition["top"])
		button.offset_bottom = float(definition["top"]) + 56.0
		button.modulate = Color(1, 1, 1, 0.72)
		_style_button(button, Vector2(56, 56))
		button.button_down.connect(_set_player_button.bind(String(definition["name"]), true))
		button.button_up.connect(_set_player_button.bind(String(definition["name"]), false))
		_hud_root.add_child(button)
		_touch_controls.append(button)

	var break_button := _touch_button("BREAK", Control.PRESET_BOTTOM_RIGHT, -202, -180, Vector2(84, 64))
	break_button.button_down.connect(_set_player_button.bind("break", true))
	break_button.button_up.connect(_set_player_button.bind("break", false))
	var place_button := _touch_button("PLACE", Control.PRESET_BOTTOM_RIGHT, -108, -180, Vector2(84, 64))
	place_button.pressed.connect(_place_block)
	var jump_button := _touch_button("JUMP", Control.PRESET_BOTTOM_RIGHT, -108, -258, Vector2(84, 64))
	jump_button.button_down.connect(_set_player_button.bind("jump", true))
	jump_button.button_up.connect(_set_player_button.bind("jump", false))
	var sprint_button := _touch_button("RUN", Control.PRESET_BOTTOM_RIGHT, -202, -258, Vector2(84, 64))
	sprint_button.button_down.connect(_set_player_button.bind("sprint", true))
	sprint_button.button_up.connect(_set_player_button.bind("sprint", false))

func _touch_button(text_value: String, preset: Control.LayoutPreset, left_offset: float, top_offset: float, min_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text_value
	button.set_anchors_preset(preset)
	button.offset_left = left_offset
	button.offset_right = left_offset + min_size.x
	button.offset_top = top_offset
	button.offset_bottom = top_offset + min_size.y
	button.modulate = Color(1, 1, 1, 0.72)
	_style_button(button, min_size)
	_hud_root.add_child(button)
	_touch_controls.append(button)
	return button

func _create_pause_menu() -> void:
	_pause_root = Control.new()
	_pause_root.name = "PauseMenu"
	_pause_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_root.visible = false
	_pause_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui_root.add_child(_pause_root)
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.01, 0.015, 0.025, 0.72)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_root.add_child(dimmer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 230)
	_style_panel(panel)
	center.add_child(panel)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	panel.add_child(buttons)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	buttons.add_child(title)
	var resume := Button.new()
	resume.text = "Resume"
	_style_button(resume)
	resume.pressed.connect(_hide_pause_menu)
	buttons.add_child(resume)
	var save_button := Button.new()
	save_button.text = "Save World"
	_style_button(save_button)
	save_button.pressed.connect(_save_world)
	buttons.add_child(save_button)
	var menu_button := Button.new()
	menu_button.text = "Save & Return to Menu"
	_style_button(menu_button)
	menu_button.pressed.connect(_save_and_return_to_menu)
	buttons.add_child(menu_button)

func _create_inventory_panel() -> void:
	_inventory_panel = PanelContainer.new()
	_inventory_panel.name = "InventoryPanel"
	_inventory_panel.set_anchors_preset(Control.PRESET_CENTER)
	_inventory_panel.offset_left = -490
	_inventory_panel.offset_right = 490
	_inventory_panel.offset_top = -315
	_inventory_panel.offset_bottom = 315
	_inventory_panel.visible = false
	_inventory_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_panel(_inventory_panel)
	_ui_root.add_child(_inventory_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	_inventory_panel.add_child(content)

	var title_row := HBoxContainer.new()
	content.add_child(title_row)
	var title := Label.new()
	title.text = "INVENTORY & CREATIVE CATALOG"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 21)
	title_row.add_child(title)
	var close := Button.new()
	close.text = "Close"
	_style_button(close, Vector2(75, 34))
	close.pressed.connect(_toggle_inventory)
	title_row.add_child(close)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	content.add_child(tabs)
	_inventory_tab_button = Button.new()
	_inventory_tab_button.text = "Inventory Slots"
	_style_button(_inventory_tab_button, Vector2(160, 36))
	_inventory_tab_button.pressed.connect(_show_inventory_slots_tab)
	tabs.add_child(_inventory_tab_button)
	_catalog_tab_button = Button.new()
	_catalog_tab_button.text = "Creative Catalog"
	_style_button(_catalog_tab_button, Vector2(180, 36))
	_catalog_tab_button.visible = false
	_catalog_tab_button.pressed.connect(_show_creative_catalog_tab)
	tabs.add_child(_catalog_tab_button)

	_inventory_slots_view = GridContainer.new()
	_inventory_slots_view.name = "InventorySlotsView"
	_inventory_slots_view.columns = 9
	_inventory_slots_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inventory_slots_view.add_theme_constant_override("h_separation", 4)
	_inventory_slots_view.add_theme_constant_override("v_separation", 4)
	content.add_child(_inventory_slots_view)
	for index in range(36):
		var button := Button.new()
		_style_button(button, Vector2(86, 52))
		button.add_theme_font_size_override("font_size", 10)
		button.pressed.connect(_select_inventory_slot.bind(index))
		_inventory_slots_view.add_child(button)
		_inventory_buttons.append(button)

	_creative_catalog_view = VBoxContainer.new()
	_creative_catalog_view.name = "CreativeCatalogView"
	_creative_catalog_view.visible = false
	_creative_catalog_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_creative_catalog_view)
	var search_row := HBoxContainer.new()
	_creative_catalog_view.add_child(search_row)
	_creative_catalog_search = LineEdit.new()
	_creative_catalog_search.placeholder_text = "Search blocks and items from the supplied asset pack…"
	_creative_catalog_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_creative_catalog_search.custom_minimum_size.y = 38
	_creative_catalog_search.text_changed.connect(_filter_creative_catalog)
	search_row.add_child(_creative_catalog_search)
	var clear_search := Button.new()
	clear_search.text = "Clear"
	_style_button(clear_search, Vector2(75, 38))
	clear_search.pressed.connect(func() -> void: _creative_catalog_search.clear())
	search_row.add_child(clear_search)
	_creative_catalog_status = Label.new()
	_creative_catalog_status.add_theme_font_size_override("font_size", 12)
	_creative_catalog_status.add_theme_color_override("font_color", Color(0.72, 0.78, 0.83))
	_creative_catalog_view.add_child(_creative_catalog_status)
	var catalog_scroll := ScrollContainer.new()
	catalog_scroll.name = "CreativeCatalogScroll"
	catalog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog_scroll.custom_minimum_size = Vector2(0, 350)
	_creative_catalog_view.add_child(catalog_scroll)
	_creative_catalog_grid = GridContainer.new()
	_creative_catalog_grid.name = "CreativeCatalogGrid"
	_creative_catalog_grid.columns = 8
	_creative_catalog_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_creative_catalog_grid.add_theme_constant_override("h_separation", 4)
	_creative_catalog_grid.add_theme_constant_override("v_separation", 4)
	catalog_scroll.add_child(_creative_catalog_grid)

func _show_inventory_slots_tab() -> void:
	if _inventory_slots_view == null or _creative_catalog_view == null:
		return
	_inventory_slots_view.visible = true
	_creative_catalog_view.visible = false
	if _inventory_tab_button != null:
		_inventory_tab_button.modulate = Color(1.0, 0.95, 0.72)
	if _catalog_tab_button != null:
		_catalog_tab_button.modulate = Color.WHITE

func _show_creative_catalog_tab() -> void:
	if _game_mode != "creative" or _inventory_slots_view == null or _creative_catalog_view == null:
		return
	_inventory_slots_view.visible = false
	_creative_catalog_view.visible = true
	if _inventory_tab_button != null:
		_inventory_tab_button.modulate = Color.WHITE
	if _catalog_tab_button != null:
		_catalog_tab_button.modulate = Color(1.0, 0.95, 0.72)
	_filter_creative_catalog(_creative_catalog_search.text if _creative_catalog_search != null else "")

func _filter_creative_catalog(query: String) -> void:
	if _creative_catalog_grid == null or _creative_catalog_status == null:
		return
	for child in _creative_catalog_grid.get_children():
		_creative_catalog_grid.remove_child(child)
		child.queue_free()
	_creative_catalog_buttons.clear()
	var normalized_query := query.strip_edges().to_lower()
	var all_definitions: Array[Dictionary] = BlockRegistry.all_definitions()
	var matches: Array[Dictionary] = []
	for definition in all_definitions:
		var item_id := int(definition.get("id", 0))
		var item_name := String(definition.get("name", ""))
		if item_id <= 0 or item_name in ["air", "cave_air", "void_air", "structure_void"]:
			continue
		if bool(definition.get("runtime_catalog_only", false)) and not bool(definition.get("creative_visible", true)):
			continue
		var display_name := String(definition.get("display_name", item_name))
		if not normalized_query.is_empty() and not (item_name.to_lower().contains(normalized_query) or display_name.to_lower().contains(normalized_query)):
			continue
		matches.append(definition)
	var shown := mini(matches.size(), _creative_catalog_max_visible)
	for index in range(shown):
		var definition: Dictionary = matches[index]
		var item_id := int(definition.get("id", 0))
		var item_name := String(definition.get("display_name", definition.get("name", "Item")))
		var button := Button.new()
		button.custom_minimum_size = Vector2(102, 70)
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		button.text = item_name + "\n" + ("BLOCK" if String(definition.get("kind", "")) == "block" else "ITEM")
		button.tooltip_text = "%s (ID %d)" % [item_name, item_id]
		button.add_theme_font_size_override("font_size", 10)
		button.focus_mode = Control.FOCUS_NONE
		button.icon = ItemModelCatalog.texture_for_item_id(item_id)
		button.pressed.connect(_choose_creative_catalog_item.bind(item_id))
		_creative_catalog_grid.add_child(button)
		_creative_catalog_buttons.append(button)
	var source_root := "res://assets/minecraft"
	var source_present := DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(source_root.path_join("blockstates")))
	if matches.is_empty():
		_creative_catalog_status.text = "No matches. Search by a block or item name."
	elif not source_present:
		_creative_catalog_status.text = "%d entries available; ZIP-derived asset folder is not extracted, so source icons/models are unavailable." % matches.size()
	elif matches.size() > shown:
		_creative_catalog_status.text = "Showing %d of %d results. Narrow the search to find more." % [shown, matches.size()]
	else:
		_creative_catalog_status.text = "%d blocks/items in this result. Icons use source-pack textures only." % matches.size()

func _choose_creative_catalog_item(item_id: int) -> void:
	if _game_mode != "creative" or inventory == null or item_id <= 0 or not is_instance_valid(player):
		return
	var selected_index := clampi(inventory.selected_hotbar_index, 0, mini(8, inventory.slot_count() - 1))
	var stack_limit := maxi(1, int(BlockRegistry.stack_limit(item_id)))
	inventory.slots[selected_index] = {"id": item_id, "count": stack_limit}
	player.select_hotbar(selected_index)
	_refresh_hud()
	_set_status("Selected %s" % BlockRegistry.get_display_name(item_id))


func _show_main_menu() -> void:
	_is_menu_visible = true
	_menu_root.visible = true
	_hud_root.visible = false
	_pause_root.visible = false
	_inventory_panel.visible = false
	if is_instance_valid(player):
		player.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_saves_list()

func _refresh_saves_list() -> void:
	for child in _save_list.get_children():
		child.queue_free()
	var saves: Array[Dictionary] = SaveStore.list_worlds()
	if saves.is_empty():
		var empty := Label.new()
		empty.text = "No saved worlds yet."
		empty.add_theme_color_override("font_color", Color(0.66, 0.70, 0.73))
		_save_list.add_child(empty)
		return
	for save_value in saves.slice(0, 5):
		var save_info: Dictionary = save_value
		var button := Button.new()
		button.text = "%s  •  %s" % [String(save_info.get("label", save_info.get("slot", "World"))), String(save_info.get("game_mode", "survival")).capitalize()]
		_style_button(button, Vector2(0, 36))
		button.pressed.connect(_load_saved_world.bind(String(save_info.get("slot", ""))))
		_save_list.add_child(button)

func _on_create_world() -> void:
	var name := _world_name_input.text.strip_edges()
	if name.is_empty():
		name = "New World"
	var seed_text := _seed_input.text.strip_edges()
	var seed_value := int(seed_text) if not seed_text.is_empty() and seed_text.is_valid_int() else int(Time.get_unix_time_from_system())
	var mode := "creative" if _mode_select.selected == 1 else "survival"
	_start_world(name, seed_value, mode, {})

func _safe_slot(value: String) -> String:
	var slot := value.strip_edges().to_lower()
	for character in ["/", "\\", ":", ".", " "]:
		slot = slot.replace(character, "_")
	while slot.contains("__"):
		slot = slot.replace("__", "_")
	return slot if not slot.is_empty() else "world"

func _clear_world_nodes() -> void:
	if is_instance_valid(player):
		if player.get_parent() == self:
			remove_child(player)
		player.queue_free()
	if is_instance_valid(world):
		if world.get_parent() == self:
			remove_child(world)
		world.queue_free()
	player = null
	world = null
	inventory = null
	_hotbar_buttons.clear()
	_inventory_buttons.clear()

func _start_world(name: String, seed_value: int, mode: String, saved: Dictionary) -> void:
	_clear_world_nodes()
	_world_name = name
	_active_slot = _safe_slot(name)
	_game_mode = mode
	_world_clock = float(saved.get("world_clock", 0.25))
	var selected_terrain_mode := "overworld"
	if _world_type_select != null and _world_type_select.selected == 1:
		selected_terrain_mode = "superflat"
	if saved.has("terrain_mode"):
		selected_terrain_mode = String(saved.get("terrain_mode", "overworld"))
	elif saved.has("world_state"):
		selected_terrain_mode = "noise" # Preserve old prototype saves without rewriting their terrain.
	world = WORLD_SCRIPT.new()
	world.name = "VoxelWorld"
	world.set_terrain_mode(selected_terrain_mode)
	add_child(world)
	if saved.has("world_state") and saved["world_state"] is Dictionary:
		world.load_state(saved["world_state"], 1)
	else:
		world.generate_world(seed_value, 1)

	inventory = INVENTORY_SCRIPT.new(36)
	if saved.has("inventory") and saved["inventory"] is Dictionary:
		inventory.deserialize(saved["inventory"])
	elif mode == "creative":
		inventory.add_item(1, 64)
		inventory.add_item(2, 64)
		inventory.add_item(3, 64)
		inventory.add_item(4, 64)
		inventory.add_item(6, 64)
		inventory.add_item(8, 64)
		inventory.add_item(9, 64)
		inventory.add_item(17, 64)

	player = PLAYER_SCRIPT.new()
	player.name = "Player"
	player.world = world
	player.inventory = inventory
	player.game_mode = mode
	add_child(player)
	if saved.has("player_state") and saved["player_state"] is Dictionary:
		player.deserialize(saved["player_state"])
	else:
		if world.terrain_mode == "overworld":
			player.global_position = world.find_spawn_position(Vector2i.ZERO, 16)
		else:
			var terrain_height := int(world.surface_height_at(0, 0))
			player.global_position = Vector3(0.5, terrain_height + 2.0, 0.5)
	player.select_hotbar(int(inventory.selected_hotbar_index))
	_is_menu_visible = false
	_menu_root.visible = false
	_hud_root.visible = true
	_pause_root.visible = false
	_inventory_panel.visible = false
	_catalog_tab_button.visible = _game_mode == "creative"
	_show_inventory_slots_tab()
	player.set_physics_process(true)
	_update_touch_visibility()
	_refresh_hud()
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _load_saved_world(slot: String) -> void:
	var result: Dictionary = SaveStore.load_world(slot)
	if not bool(result.get("ok", false)):
		_status_label.text = String(result.get("error", "Could not load world."))
		return
	var saved: Dictionary = result.get("world", {})
	var mode := String(saved.get("game_mode", "survival"))
	_start_world(String(saved.get("world_name", slot)), int(saved.get("seed", 1)), mode, saved)

func _update_touch_visibility() -> void:
	var show_controls := OS.has_feature("mobile")
	for button in _touch_controls:
		button.visible = show_controls

func _set_player_button(button_name: String, pressed: bool) -> void:
	if is_instance_valid(player):
		player.set_virtual_button(button_name, pressed)

func _select_hotbar(index: int) -> void:
	if not is_instance_valid(player):
		return
	player.select_hotbar(index)
	_refresh_hud()

func _select_inventory_slot(index: int) -> void:
	if not is_instance_valid(player) or inventory == null:
		return
	if index < 9:
		player.select_hotbar(index)
	_refresh_hud()

func _toggle_inventory() -> void:
	if not is_instance_valid(player):
		return
	_inventory_panel.visible = not _inventory_panel.visible
	if _inventory_panel.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		player.set_physics_process(false)
		_catalog_tab_button.visible = _game_mode == "creative"
		if _game_mode == "creative":
			_show_creative_catalog_tab()
		else:
			_show_inventory_slots_tab()
		_refresh_hud()
	else:
		player.set_physics_process(true)
		if not OS.has_feature("mobile") and not _pause_root.visible:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _place_block() -> void:
	if is_instance_valid(player):
		player.place_target_block()
		_refresh_hud()

func _show_pause_menu() -> void:
	if not is_instance_valid(player):
		return
	_save_world()
	_pause_root.visible = true
	_inventory_panel.visible = false
	player.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _hide_pause_menu() -> void:
	_pause_root.visible = false
	if is_instance_valid(player):
		player.set_physics_process(true)
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _save_and_return_to_menu() -> void:
	_save_world()
	_show_main_menu()

func _save_world() -> void:
	if not is_instance_valid(world) or not is_instance_valid(player) or inventory == null:
		return
	var state := {
		"world_name": _world_name,
		"seed": int(world.world_seed),
		"game_mode": _game_mode,
		"terrain_mode": String(world.terrain_mode),
		"world_state": world.save_state(),
		"player_state": player.serialize(),
		"inventory": inventory.serialize(),
		"world_clock": _world_clock
	}
	var result: Dictionary = SaveStore.save_world(_active_slot, state)
	if bool(result.get("ok", false)):
		_set_status("Saved")
	else:
		_set_status("Save failed: " + String(result.get("error", "unknown error")))

func _set_status(value: String) -> void:
	if _status_label == null:
		_status_label = Label.new()
		_status_label.position = Vector2(18, 68)
		_status_label.add_theme_font_size_override("font_size", 14)
		_status_label.add_theme_color_override("font_color", Color(0.88, 0.91, 0.83))
		_hud_root.add_child(_status_label)
	_status_label.text = value

func _refresh_hud() -> void:
	if not is_instance_valid(player) or inventory == null:
		return
	_health_label.text = "♥ %d/20     FOOD %d/20" % [roundi(player.health), roundi(player.hunger)]
	var selected: Dictionary = inventory.get_selected()
	var selected_id := int(selected.get("id", 0))
	player.update_held_item(selected_id)
	_selected_label.text = "Selected: %s" % (BlockRegistry.get_display_name(selected_id) if selected_id > 0 else "Empty")
	for index in range(mini(9, _hotbar_buttons.size())):
		var stack: Dictionary = inventory.get_slot(index)
		var item_id := int(stack.get("id", 0))
		var count := int(stack.get("count", 0))
		var name := "—"
		if item_id > 0:
			name = String(BlockRegistry.get_display_name(item_id)).replace(" Block", "")
		_hotbar_buttons[index].text = "%d  %s\n%d" % [index + 1, name, count]
		_hotbar_buttons[index].tooltip_text = "Slot %d — %s ×%d" % [index + 1, BlockRegistry.get_display_name(item_id) if item_id > 0 else "Empty", count]
		var icon_texture: Texture2D = ItemModelCatalog.texture_for_item_id(item_id) if item_id > 0 else null
		_hotbar_buttons[index].icon = icon_texture
		_hotbar_buttons[index].modulate = Color(1.0, 0.95, 0.72) if index == inventory.selected_hotbar_index else Color.WHITE
	for index in range(mini(_inventory_buttons.size(), inventory.slot_count())):
		var stack: Dictionary = inventory.get_slot(index)
		var item_id := int(stack.get("id", 0))
		var name := "Empty" if item_id == 0 else BlockRegistry.get_display_name(item_id)
		var stack_count := int(stack.get("count", 0))
		_inventory_buttons[index].text = "%s\n×%d" % [name, stack_count]
		_inventory_buttons[index].tooltip_text = "%s ×%d" % [name, stack_count]
		_inventory_buttons[index].icon = ItemModelCatalog.texture_for_item_id(item_id) if item_id > 0 else null

func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(world) or _is_menu_visible:
		return
	_world_clock = fposmod(_world_clock + delta / 1200.0, 1.0)
	sun.rotation.x = -PI * _world_clock * 2.0
	var daylight := maxf(0.10, sin(_world_clock * TAU) * 0.75 + 0.35)
	sun.light_energy = daylight
	environment.environment.background_color = Color(0.025, 0.035, 0.10).lerp(Color(0.39, 0.57, 0.76), clampf(daylight, 0.0, 1.0))
	_stream_timer += delta
	if _stream_timer >= 0.45:
		_stream_timer = 0.0
		world.update_streaming(player.global_position, 1)
	_autosave_timer += delta
	if _autosave_timer >= 60.0:
		_autosave_timer = 0.0
		_save_world()
	_hud_refresh_timer += delta
	if _hud_refresh_timer >= 0.18:
		_hud_refresh_timer = 0.0
		_refresh_hud()

func _unhandled_input(event: InputEvent) -> void:
	if _is_menu_visible:
		return
	if event is InputEventScreenDrag and is_instance_valid(player):
		var viewport_width := get_viewport().get_visible_rect().size.x
		if event.position.x > viewport_width * 0.34:
			player.apply_look_delta(event.relative)
	if event.is_action_pressed("ui_cancel"):
		if _pause_root.visible:
			_hide_pause_menu()
		elif _inventory_panel.visible:
			_toggle_inventory()
		else:
			_show_pause_menu()
