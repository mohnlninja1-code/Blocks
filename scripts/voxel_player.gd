extends CharacterBody3D
"""First-person control, mining, placement and local survival state. Some Java rules remain TODO."""

const DEFAULT_GRAVITY := 24.0
const WALK_SPEED := 5.0
const SPRINT_SPEED := 7.0
const JUMP_SPEED := 8.0
const REACH_DISTANCE := 5.5
const LOOK_SENSITIVITY := 0.0022

var world: Variant
var inventory: Variant
var game_mode := "survival"
var health := 20.0
var hunger := 20.0
var armor_points := 0
var selected_block_id := 1
var creative_flight_enabled := false
var camera: Camera3D
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
			selected_block_id = int(inventory.get_selected().get("id", 1))

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
	var axis := _movement_axis()
	var local_direction := Vector3(axis.x, 0.0, axis.y)
	var direction := (global_transform.basis * local_direction).normalized()
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") or bool(_virtual_buttons["sprint"]) else WALK_SPEED
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
	move_and_slide()
	if Input.is_action_pressed("break_block") or bool(_virtual_buttons["break"]):
		_update_mining(delta)
	else:
		_mining_progress = 0.0
		_mining_target = Vector3i(2147483647, 2147483647, 2147483647)
	if Input.is_action_just_pressed("place_block"):
		place_target_block()

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

func select_hotbar(index: int) -> void:
	if inventory == null:
		return
	inventory.set_selected(index)
	var stack: Dictionary = inventory.get_selected()
	selected_block_id = int(stack.get("id", 1))

func serialize() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"rotation_y": rotation.y,
		"camera_pitch": _camera_pitch,
		"health": health,
		"hunger": hunger,
		"armor_points": armor_points,
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
	armor_points = clampi(int(state.get("armor_points", 0)), 0, 20)
	creative_flight_enabled = bool(state.get("creative_flight_enabled", false))
