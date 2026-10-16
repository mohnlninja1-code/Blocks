extends RefCounted
"""Authoritative stack inventory. Mutations are all-or-nothing where requested."""

var slots: Array = []
var selected_hotbar_index: int = 0

func _init(slot_count: int = 36) -> void:
	reset(slot_count)

func reset(slot_count: int = 36) -> void:
	slots.clear()
	for _i in range(maxi(slot_count, 1)):
		slots.append({"id": 0, "count": 0})

func slot_count() -> int:
	return slots.size()

func get_slot(index: int) -> Dictionary:
	if index < 0 or index >= slots.size():
		return {"id": 0, "count": 0}
	return (slots[index] as Dictionary).duplicate(true)

func get_selected() -> Dictionary:
	return get_slot(selected_hotbar_index)

func set_selected(index: int) -> void:
	selected_hotbar_index = clampi(index, 0, mini(8, maxi(0, slots.size() - 1)))

func count_item(item_id: int) -> int:
	var total := 0
	for value in slots:
		var stack: Dictionary = value
		if int(stack.get("id", 0)) == item_id:
			total += maxi(0, int(stack.get("count", 0)))
	return total

func _stack_limit(item_id: int) -> int:
	if item_id <= 0:
		return 0
	if is_instance_valid(Engine.get_main_loop()) and Engine.get_main_loop() is SceneTree:
		var tree := Engine.get_main_loop() as SceneTree
		var registry := tree.root.get_node_or_null("BlockRegistry")
		if registry != null and registry.has_method("stack_limit"):
			return maxi(1, int(registry.stack_limit(item_id)))
	return 64

func can_add(item_id: int, count: int) -> bool:
	if item_id <= 0 or count < 0:
		return false
	if count == 0:
		return true
	var remaining := count
	var limit := _stack_limit(item_id)
	for value in slots:
		var stack: Dictionary = value
		var current_id := int(stack.get("id", 0))
		var current_count := int(stack.get("count", 0))
		if current_id == item_id:
			remaining -= maxi(0, limit - current_count)
		elif current_id == 0 or current_count <= 0:
			remaining -= limit
		if remaining <= 0:
			return true
	return false

func add_item(item_id: int, count: int) -> int:
	"""Add as much as possible and return the uninserted remainder."""
	if item_id <= 0 or count <= 0:
		return maxi(0, count)
	var remaining := count
	var limit := _stack_limit(item_id)
	for i in range(slots.size()):
		var stack: Dictionary = slots[i]
		if int(stack.get("id", 0)) != item_id:
			continue
		var free := maxi(0, limit - int(stack.get("count", 0)))
		var moved := mini(free, remaining)
		if moved > 0:
			stack["count"] = int(stack.get("count", 0)) + moved
			slots[i] = stack
			remaining -= moved
		if remaining == 0:
			return 0
	for i in range(slots.size()):
		var stack: Dictionary = slots[i]
		if int(stack.get("id", 0)) != 0 and int(stack.get("count", 0)) > 0:
			continue
		var moved := mini(limit, remaining)
		slots[i] = {"id": item_id, "count": moved}
		remaining -= moved
		if remaining == 0:
			return 0
	return remaining

func remove_item(item_id: int, count: int) -> bool:
	"""Remove only if the entire cost can be paid."""
	if item_id <= 0 or count < 0 or count_item(item_id) < count:
		return false
	var remaining := count
	for i in range(slots.size()):
		if remaining == 0:
			break
		var stack: Dictionary = slots[i]
		if int(stack.get("id", 0)) != item_id:
			continue
		var take := mini(int(stack.get("count", 0)), remaining)
		stack["count"] = int(stack.get("count", 0)) - take
		remaining -= take
		if int(stack["count"]) <= 0:
			slots[i] = {"id": 0, "count": 0}
		else:
			slots[i] = stack
	return remaining == 0

func consume_costs(costs: Array) -> bool:
	"""Atomically remove an array of {id,count} requirements."""
	var next_slots: Array = slots.duplicate(true)
	for cost_value in costs:
		if not cost_value is Dictionary:
			return false
		var cost: Dictionary = cost_value
		var item_id := int(cost.get("id", 0))
		var count := int(cost.get("count", 0))
		if item_id <= 0 or count < 0:
			return false
		var available := 0
		for value in next_slots:
			var stack: Dictionary = value
			if int(stack.get("id", 0)) == item_id:
				available += int(stack.get("count", 0))
		if available < count:
			return false
		for i in range(next_slots.size()):
			if count == 0:
				break
			var stack: Dictionary = next_slots[i]
			if int(stack.get("id", 0)) != item_id:
				continue
			var take := mini(int(stack.get("count", 0)), count)
			stack["count"] = int(stack.get("count", 0)) - take
			count -= take
			if int(stack["count"]) <= 0:
				next_slots[i] = {"id": 0, "count": 0}
			else:
				next_slots[i] = stack
	slots = next_slots
	return true

func craft(recipe: Dictionary, creative: bool = false) -> bool:
	"""Craft a legacy inputs/output recipe atomically; unsupported remainders are not silently invented."""
	var inputs: Variant = recipe.get("inputs", [])
	var output: Variant = recipe.get("output", {})
	if not inputs is Array or not output is Dictionary:
		return false
	var item_id := int(output.get("id", 0))
	var output_count := int(output.get("count", 0))
	if item_id <= 0 or output_count <= 0:
		return false
	var before: Array = slots.duplicate(true)
	if not creative and not consume_costs(inputs):
		return false
	if not can_add(item_id, output_count):
		slots = before
		return false
	if add_item(item_id, output_count) != 0:
		slots = before
		return false
	return true

func serialize() -> Dictionary:
	return {"slots": slots.duplicate(true), "selected_hotbar_index": selected_hotbar_index}

func deserialize(state: Dictionary) -> bool:
	var values: Variant = state.get("slots", [])
	if not values is Array or values.size() != slots.size():
		return false
	var rebuilt: Array = []
	for value in values:
		if not value is Dictionary:
			return false
		var stack: Dictionary = value
		var item_id := int(stack.get("id", 0))
		var count := int(stack.get("count", 0))
		if item_id < 0 or count < 0 or (item_id == 0 and count != 0):
			return false
		if item_id > 0 and count > _stack_limit(item_id):
			return false
		rebuilt.append({"id": item_id, "count": count})
	slots = rebuilt
	set_selected(int(state.get("selected_hotbar_index", 0)))
	return true
