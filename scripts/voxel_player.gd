extends CharacterBody3D
"""First-person control, mining, placement and local survival state. Some Java rules remain TODO."""

const DEFAULT_GRAVITY := 24.0
const WALK_SPEED := 5.0
const SPRINT_SPEED := 7.0
const JUMP_SPEED := 8.0
const REACH_DISTANCE := 5.5
const LOOK_SENSITIVITY := 0.0022
const SURVIVAL_TICK_SECONDS := 0.05
const ITEM_RENDERER_SCRIPT = preload("res://scripts/item_model_renderer.gd")

var world: Variant
var inventory: Variant
var game_mode := "survival"
var health := 20.0
var hunger := 20.0
var food_saturation := 5.0
var exhaustion := 0.0
var difficulty := "normal"
var armor_points := 0
var _survival_tick_accumulator := 0.0
var _natural_regeneration_ticks := 0
var _starvation_ticks := 0
var _peaceful_regeneration_ticks := 0
var _fall_distance := 0.0
var selected_block_id := 1
var creative_flight_enabled := false
var camera: Camera3D
var _held_item_anchor: Node3D
var _held_item_renderer: RefCounted
var _held_item_id := -1
var _camera_pitch := 0.0
var _virtual_buttons: Dictionary = {"forward": false, "back": false, "left": false, "right": false, "sprint": false, "sneak": false, "jump": false, "break": false}
var _mining_target := Vector3i(2147483647, 2147483647, 2147483647)
var _mining_progress := 0.0

func _ready() -> void:
	_ensure_input_actions()
	var collision := CollisionShape3D.new()
	collision.name = "PlayerCollision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.position = Vector3(0, 1.62, 0)
	camera.current = true
	camera.fov = 75.0
	add_child(camera)
	_held_item_anchor = Node3D.new()
	_held_item_anchor.name = "HeldItemAnchor"
	_held_item_anchor.position = Vector3(0.33, -0.28, -0.58)
	camera.add_child(_held_item_anchor)
	_held_item_renderer = ITEM_RENDERER_SCRIPT.new()
	floor_snap_length = 0.2
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED

func _ensure_input_actions() -> void:
	_bind_key("move_forward", KEY_W)
	_bind_key("move_back", KEY_S)
	_bind_key("move_left", KEY_A)
	_bind_key("move_right", KEY_D)
	_bind_key("jump", KEY_SPACE)
	_bind_key("sprint", KEY_SHIFT)
	_bind_key("sneak", KEY_CTRL)
	_bind_key("toggle_flight", KEY_F)
	_bind_key("inventory", KEY_E)
	_bind_mouse("break_block", MOUSE_BUTTON_LEFT)
	_bind_mouse("place_block", MOUSE_BUTTON_RIGHT)

func _bind_key(action_name: String, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var event := InputEventKey.new()
	event.keycode = keycode
	if not InputMap.action_has_event(action_name, event):
		InputMap.action_add_event(action_name, event)

func _bind_mouse(action_name: String, button: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var event := InputEventMouseButton.new()
	event.button_index = button
	if not InputMap.action_has_event(action_name, event):
		InputMap.action_add_event(action_name, event)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_look_delta(event.relative)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_F and game_mode == "creative":
			creative_flight_enabled = not creative_flight_enabled
		elif event.keycode >= KEY_1 and event.keycode <= KEY_9 and inventory != null:
			var selected := int(event.keycode) - int(KEY_1)
			inventory.set_selected(selected)
			var selected_stack: Dictionary = inventory.get_selected()
			selected_block_id = int(selected_stack.get("id", 0))
			update_held_item(selected_block_id)

func apply_look_delta(delta: Vector2) -> void:
	rotation.y -= delta.x * LOOK_SENSITIVITY
	_camera_pitch = clampf(_camera_pitch - delta.y * LOOK_SENSITIVITY, deg_to_rad(-88.0), deg_to_rad(88.0))
	camera.rotation.x = _camera_pitch

func set_virtual_button(button_name: String, pressed: bool) -> void:
	if _virtual_buttons.has(button_name):
		_virtual_buttons[button_name] = pressed

func _movement_axis() -> Vector2:
	var axis := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	axis += Vector2(
		float(_virtual_buttons["right"]) - float(_virtual_buttons["left"]),
		float(_virtual_buttons["back"]) - float(_virtual_buttons["forward"])
	)
	return axis.limit_length(1.0)

func _physics_process(delta: float) -> void:
	if world == null:
		return
	var previous_position := global_position
	var was_on_floor := is_on_floor()
	var sprinting := Input.is_action_pressed("sprint") or bool(_virtual_buttons["sprint"])
	var axis := _movement_axis()
	var local_direction := Vector3(axis.x, 0.0, axis.y)
	var direction := (global_transform.basis * local_direction).normalized()
	var speed := SPRINT_SPEED if sprinting else WALK_SPEED
	if Input.is_action_pressed("sneak") or bool(_virtual_buttons["sneak"]):
		speed *= 0.3
	velocity.x = move_toward(velocity.x, direction.x * speed, 25.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 25.0 * delta)
	var flying := game_mode == "creative" and creative_flight_enabled
	if flying:
		var vertical := 0.0
		if Input.is_action_pressed("jump") or bool(_virtual_buttons["jump"]):
			vertical += 1.0
		if Input.is_action_pressed("sneak") or bool(_virtual_buttons["sneak"]):
			vertical -= 1.0
		velocity.y = vertical * speed
	else:
		if not is_on_floor():
			velocity.y -= DEFAULT_GRAVITY * delta
		elif velocity.y < 0.0:
			velocity.y = 0.0
		if (Input.is_action_just_pressed("jump") or bool(_virtual_buttons["jump"])) and is_on_floor():
			velocity.y = JUMP_SPEED
			add_exhaustion(0.2 if sprinting else 0.05)
	move_and_slide()
	var horizontal_distance := Vector2(global_position.x - previous_position.x, global_position.z - previous_position.z).length()
	if game_mode == "survival" and sprinting:
		add_exhaustion(horizontal_distance * 0.1)
	if game_mode == "survival":
		if not was_on_floor and velocity.y <= 0.0:
			_fall_distance += maxf(0.0, previous_position.y - global_position.y)
		if is_on_floor():
			if not was_on_floor and _fall_distance > 0.0:
				apply_fall_damage(_fall_distance)
			_fall_distance = 0.0
		_survival_tick_accumulator += delta
		while _survival_tick_accumulator >= SURVIVAL_TICK_SECONDS:
			_survival_tick_accumulator -= SURVIVAL_TICK_SECONDS
			tick_survival()
	if Input.is_action_pressed("break_block") or bool(_virtual_buttons["break"]):
		_update_mining(delta)
	else:
		_mining_progress = 0.0
		_mining_target = Vector3i(2147483647, 2147483647, 2147483647)
	if Input.is_action_just_pressed("place_block"):
		use_selected_item()

func set_difficulty(value: String) -> void:
	difficulty = value if value in ["peaceful", "easy", "normal", "hard"] else "normal"

func add_exhaustion(amount: float) -> void:
	if game_mode != "survival" or health <= 0.0 or amount <= 0.0:
		return
	exhaustion = minf(40.0, exhaustion + amount)

func receive_damage(amount: float, _damage_source: String = "generic") -> bool:
	if game_mode == "creative" or health <= 0.0 or amount <= 0.0:
		return false
	health = maxf(0.0, health - amount)
	return true

func heal(amount: float) -> void:
	if amount <= 0.0 or health <= 0.0:
		return
	health = minf(20.0, health + amount)

func apply_fall_damage(fall_distance: float) -> float:
	if game_mode == "creative" or fall_distance <= 3.0:
		return 0.0
	var damage := maxf(0.0, ceilf(fall_distance - 3.0))
	if receive_damage(damage, "fall"):
		return damage
	return 0.0

func eat_selected_item() -> bool:
	if game_mode != "survival" or inventory == null:
		return false
	var stack: Dictionary = inventory.get_selected()
	var item_id := int(stack.get("id", 0))
	var count := int(stack.get("count", 0))
	if item_id <= 0 or count <= 0:
		return false
	var registry: Variant = get_tree().root.get_node_or_null("BlockRegistry")
	if registry == null:
		return false
	var definition: Dictionary = registry.get_definition(item_id)
	var food_points := int(definition.get("food", 0))
	if food_points <= 0 or (hunger >= 20.0 and not bool(definition.get("always_edible", false))):
		return false
	if not inventory.remove_item(item_id, 1):
		return false
	var saturation_modifier := clampf(float(definition.get("saturation_modifier", 0.0)), 0.0, 1.0)
	hunger = minf(20.0, hunger + float(food_points))
	food_saturation = minf(hunger, food_saturation + float(food_points) * saturation_modifier * 2.0)
	return true

func use_selected_item() -> bool:
	if eat_selected_item():
		return true
	return place_target_block()

func tick_survival() -> void:
	if game_mode != "survival" or health <= 0.0:
		return
	set_difficulty(difficulty)
	if difficulty == "peaceful":
		hunger = 20.0
		food_saturation = maxf(food_saturation, 5.0)
		exhaustion = 0.0
		_peaceful_regeneration_ticks += 1
		if _peaceful_regeneration_ticks >= 20:
			_peaceful_regeneration_ticks = 0
			heal(1.0)
		return
	_peaceful_regeneration_ticks = 0
	while exhaustion >= 4.0:
		exhaustion -= 4.0
		if food_saturation > 0.0:
			food_saturation = maxf(0.0, food_saturation - 1.0)
		elif hunger > 0.0:
			hunger = maxf(0.0, hunger - 1.0)
		food_saturation = minf(food_saturation, hunger)
	if hunger >= 18.0 and health < 20.0:
		_starvation_ticks = 0
		_natural_regeneration_ticks += 1
		var regen_period := 10 if food_saturation > 0.0 else 80
		if _natural_regeneration_ticks >= regen_period:
			_natural_regeneration_ticks = 0
			heal(1.0)
			add_exhaustion(6.0)
	else:
		_natural_regeneration_ticks = 0
	if hunger <= 0.0:
		_starvation_ticks += 1
		if _starvation_ticks >= 80:
			_starvation_ticks = 0
			var can_starve_damage := difficulty == "hard" or (difficulty == "normal" and health > 1.0) or (difficulty == "easy" and health > 10.0)
			if can_starve_damage:
				receive_damage(1.0, "starvation")
	else:
		_starvation_ticks = 0

func _raycast_target() -> Dictionary:
	if camera == null or get_world_3d() == null:
		return {}
	var origin := camera.global_position
	var endpoint := origin - camera.global_transform.basis.z * REACH_DISTANCE
	var query := PhysicsRayQueryParameters3D.create(origin, endpoint)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_3d().direct_space_state.intersect_ray(query)

func target_block_info() -> Dictionary:
	var hit := _raycast_target()
	if hit.is_empty():
		return {}
	var point: Vector3 = hit.get("position", Vector3.ZERO)
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	var block_position := Vector3i(floori(point.x - normal.x * 0.01), floori(point.y - normal.y * 0.01), floori(point.z - normal.z * 0.01))
	var place_position := Vector3i(floori(point.x + normal.x * 0.01), floori(point.y + normal.y * 0.01), floori(point.z + normal.z * 0.01))
	var block_id := int(world.get_block_at(block_position)) if world.has_method("get_block_at") else 0
	if block_id <= 0:
		return {}
	return {"position": block_position, "place_position": place_position, "block_id": block_id, "normal": normal}

func _update_mining(delta: float) -> void:
	var target := target_block_info()
	if target.is_empty():
		_mining_progress = 0.0
		return
	var position: Vector3i = target["position"]
	var block_id := int(target["block_id"])
	if position != _mining_target:
		_mining_target = position
		_mining_progress = 0.0
	var registry: Variant = get_tree().root.get_node_or_null("BlockRegistry")
	var definition: Dictionary = registry.get_definition(block_id) if registry != null else {}
	var hardness := float(definition.get("hardness", 1.0))
	if hardness < 0.0:
		_mining_progress = 0.0
		return
	if game_mode == "creative":
		_finish_mining(target)
		return
	var selected: Dictionary = inventory.get_selected() if inventory != null else {"id": 0, "count": 0}
	var tool_id := int(selected.get("id", 0))
	var speed := float(registry.mining_speed_for(block_id, tool_id)) if registry != null else 1.0
	var duration := maxf(0.15, hardness * 1.2 / maxf(speed, 0.1))
	_mining_progress += delta
	if _mining_progress >= duration:
		_finish_mining(target)

func _finish_mining(target: Dictionary) -> void:
	var position: Vector3i = target["position"]
	var block_id := int(target["block_id"])
	var registry := get_tree().root.get_node_or_null("BlockRegistry")
	var definition: Dictionary = registry.get_definition(block_id) if registry != null else {}
	var drop_id := int(definition.get("drop", block_id))
	if game_mode != "creative" and inventory != null and drop_id > 0 and not inventory.can_add(drop_id, 1):
		_mining_progress = 0.0
		return
	if not world.set_block_at(position, 0):
		_mining_progress = 0.0
		return
	if has_node("/root/SoundBank"):
		SoundBank.play_block(String(definition.get("name", "stone")), "break")
	if game_mode != "creative" and inventory != null and drop_id > 0:
		inventory.add_item(drop_id, 1)
	_mining_progress = 0.0
	_mining_target = Vector3i(2147483647, 2147483647, 2147483647)

func mine_target() -> void:
	var target := target_block_info()
	if not target.is_empty():
		_finish_mining(target)

func place_target_block() -> bool:
	if world == null or inventory == null:
		return false
	var target := target_block_info()
	if target.is_empty():
		return false
	var place_position: Vector3i = target["place_position"]
	if place_position.y < -64 or place_position.y > 319 or world.get_block_at(place_position) != 0:
		return false
	if _overlaps_player(place_position):
		return false
	var selected: Dictionary = inventory.get_selected()
	var item_id := int(selected.get("id", 0))
	var place_id := int(BlockRegistry.place_block_id(item_id))
	if place_id <= 0:
		return false
	if game_mode != "creative" and int(selected.get("count", 0)) <= 0:
		return false
	if not world.set_block_at(place_position, place_id):
		return false
	if game_mode != "creative":
		if not inventory.remove_item(item_id, 1):
			world.set_block_at(place_position, 0)
			return false
	if has_node("/root/SoundBank"):
		var placed_definition: Dictionary = BlockRegistry.get_definition(place_id)
		SoundBank.play_block(String(placed_definition.get("name", "stone")), "place")
	return true

func _overlaps_player(point: Vector3i) -> bool:
	var min_player_y := floori(global_position.y)
	var max_player_y := floori(global_position.y + 1.8)
	return point.x == floori(global_position.x) and point.z == floori(global_position.z) and point.y >= min_player_y and point.y < max_player_y

func update_held_item(item_id: int) -> void:
	if _held_item_id == item_id or _held_item_anchor == null:
		return
	_held_item_id = item_id
	for child in _held_item_anchor.get_children():
		_held_item_anchor.remove_child(child)
		child.queue_free()
	if item_id <= 0 or _held_item_renderer == null:
		return
	var visual: Node3D = _held_item_renderer.create_item_node(item_id, "firstperson_righthand")
	visual.name = "HeldItem_%d" % item_id
	for child in visual.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_held_item_anchor.add_child(visual)

func select_hotbar(index: int) -> void:
	if inventory == null:
		return
	inventory.set_selected(index)
	var stack: Dictionary = inventory.get_selected()
	selected_block_id = int(stack.get("id", 0))
	update_held_item(selected_block_id)

func serialize() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"rotation_y": rotation.y,
		"camera_pitch": _camera_pitch,
		"health": health,
		"hunger": hunger,
		"food_saturation": food_saturation,
		"exhaustion": exhaustion,
		"difficulty": difficulty,
		"natural_regeneration_ticks": _natural_regeneration_ticks,
		"starvation_ticks": _starvation_ticks,
		"peaceful_regeneration_ticks": _peaceful_regeneration_ticks,
		"fall_distance": _fall_distance,
		"creative_flight_enabled": creative_flight_enabled
	}

func deserialize(state: Dictionary) -> void:
	var saved_position: Variant = state.get("position", [0.0, 80.0, 0.0])
	if saved_position is Array and saved_position.size() >= 3:
		global_position = Vector3(float(saved_position[0]), float(saved_position[1]), float(saved_position[2]))
	rotation.y = float(state.get("rotation_y", 0.0))
	_camera_pitch = clampf(float(state.get("camera_pitch", 0.0)), deg_to_rad(-88.0), deg_to_rad(88.0))
	camera.rotation.x = _camera_pitch
	health = clampf(float(state.get("health", 20.0)), 0.0, 20.0)
	hunger = clampf(float(state.get("hunger", 20.0)), 0.0, 20.0)
	food_saturation = clampf(float(state.get("food_saturation", 5.0)), 0.0, hunger)
	exhaustion = clampf(float(state.get("exhaustion", 0.0)), 0.0, 40.0)
	set_difficulty(String(state.get("difficulty", difficulty)))
	_natural_regeneration_ticks = clampi(int(state.get("natural_regeneration_ticks", 0)), 0, 79)
	_starvation_ticks = clampi(int(state.get("starvation_ticks", 0)), 0, 79)
	_peaceful_regeneration_ticks = clampi(int(state.get("peaceful_regeneration_ticks", 0)), 0, 19)
	_fall_distance = maxf(0.0, float(state.get("fall_distance", 0.0)))
	creative_flight_enabled = bool(state.get("creative_flight_enabled", false))
