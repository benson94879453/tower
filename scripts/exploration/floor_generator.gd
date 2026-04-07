class_name FloorGenerator
extends RefCounted


static func generate_floor(floor_number: int) -> Dictionary:
	var config: Dictionary = _get_floor_config()
	var zone_info: Dictionary = _get_zone_for_floor(floor_number, config)
	var boss_floor: int = int(zone_info.get("boss_floor", -1))
	var is_boss: bool = floor_number == boss_floor

	var rows_range: Array = Array(config.get("rows_range", [3, 4]))
	var cols_range: Array = Array(config.get("cols_range", [2, 3]))

	var min_rows: int = 3
	var max_rows: int = 4
	if rows_range.size() >= 2:
		min_rows = int(rows_range[0])
		max_rows = int(rows_range[1])

	var min_cols: int = 2
	var max_cols: int = 3
	if cols_range.size() >= 2:
		min_cols = int(cols_range[0])
		max_cols = int(cols_range[1])

	var num_rows: int = randi_range(min(min_rows, max_rows), max(min_rows, max_rows))
	var node_weights: Dictionary = Dictionary(config.get("node_weights", {}))

	var nodes: Array = []
	var next_id: int = 0

	var entrance: Dictionary = {
		"id": next_id,
		"row": 0,
		"col": 0,
		"type": "entrance",
		"connections": [],
		"visited": false,
		"position": Vector2.ZERO,
	}
	nodes.append(entrance)
	next_id += 1

	var row_node_ids: Array = []
	row_node_ids.append([entrance["id"]])

	for row_idx in range(1, num_rows + 1):
		var num_cols: int = randi_range(min(min_cols, max_cols), max(min_cols, max_cols))
		var row_ids: Array = []

		for col_idx in range(num_cols):
			var node_type: String = ""
			if is_boss and row_idx == num_rows:
				node_type = "elite"
			else:
				node_type = _pick_node_type(node_weights, floor_number)

			var node: Dictionary = {
				"id": next_id,
				"row": row_idx,
				"col": col_idx,
				"type": node_type,
				"connections": [],
				"visited": false,
				"position": Vector2.ZERO,
			}
			nodes.append(node)
			row_ids.append(next_id)
			next_id += 1

		var prev_row_ids: Array = Array(row_node_ids[row_idx - 1])
		_connect_rows(nodes, prev_row_ids, row_ids)
		row_node_ids.append(row_ids)

	var exit_node: Dictionary = {
		"id": next_id,
		"row": num_rows + 1,
		"col": 0,
		"type": "boss" if is_boss else "exit",
		"connections": [],
		"visited": false,
		"position": Vector2.ZERO,
	}
	nodes.append(exit_node)

	var last_row_ids: Array = Array(row_node_ids[row_node_ids.size() - 1])
	for raw_node_id in last_row_ids:
		_add_connection(nodes, int(raw_node_id), next_id)

	return {
		"floor_number": floor_number,
		"zone_name": String(zone_info.get("name", "")),
		"zone_element": String(zone_info.get("element", "none")),
		"is_boss_floor": is_boss,
		"rows": num_rows,
		"nodes": nodes,
		"entrance_id": 0,
		"exit_id": int(exit_node.get("id", -1)),
	}


static func _connect_rows(nodes: Array, prev_ids: Array, curr_ids: Array) -> void:
	if prev_ids.is_empty() or curr_ids.is_empty():
		return

	for raw_prev_id in prev_ids:
		var prev_id: int = int(raw_prev_id)
		var target_index: int = randi() % curr_ids.size()
		var target_id: int = int(curr_ids[target_index])
		_add_connection(nodes, prev_id, target_id)

	for raw_curr_id in curr_ids:
		var curr_id: int = int(raw_curr_id)
		var connected: bool = false
		for raw_prev_id in prev_ids:
			if _has_connection(nodes, int(raw_prev_id), curr_id):
				connected = true
				break
		if not connected:
			var source_index: int = randi() % prev_ids.size()
			var source_id: int = int(prev_ids[source_index])
			_add_connection(nodes, source_id, curr_id)

	for raw_prev_id in prev_ids:
		var prev_id: int = int(raw_prev_id)
		for raw_curr_id in curr_ids:
			var curr_id: int = int(raw_curr_id)
			if randf() < 0.3:
				_add_connection(nodes, prev_id, curr_id)


static func _pick_node_type(weights: Dictionary, floor_number: int) -> String:
	var total_weight: int = 0
	var entries: Array = []

	for raw_node_type in weights.keys():
		var node_type: String = String(raw_node_type)
		var weight: int = int(weights.get(node_type, 0))
		if node_type == "elite" and floor_number < 5:
			weight = max(1, weight / 2)
		if node_type == "altar" and floor_number < 10:
			weight = 0
		entries.append({"type": node_type, "weight": weight})
		total_weight += weight

	if total_weight <= 0:
		return "battle"

	var roll: int = randi() % total_weight
	var cumulative: int = 0
	for raw_entry in entries:
		var entry: Dictionary = raw_entry
		cumulative += int(entry.get("weight", 0))
		if roll < cumulative:
			return String(entry.get("type", "battle"))

	return "battle"


static func _get_node_index_by_id(nodes: Array, node_id: int) -> int:
	for index in range(nodes.size()):
		var node: Dictionary = nodes[index]
		if int(node.get("id", -1)) == node_id:
			return index
	return -1


static func _get_node_by_id(nodes: Array, node_id: int) -> Dictionary:
	var node_index: int = _get_node_index_by_id(nodes, node_id)
	if node_index >= 0:
		return Dictionary(nodes[node_index])
	return {}


static func _add_connection(nodes: Array, from_id: int, to_id: int) -> void:
	var node_index: int = _get_node_index_by_id(nodes, from_id)
	if node_index < 0:
		return

	var node: Dictionary = nodes[node_index]
	var connections: Array = Array(node.get("connections", []))
	if not connections.has(to_id):
		connections.append(to_id)
		node["connections"] = connections
		nodes[node_index] = node


static func _has_connection(nodes: Array, from_id: int, to_id: int) -> bool:
	var node_index: int = _get_node_index_by_id(nodes, from_id)
	if node_index < 0:
		return false
	var node: Dictionary = nodes[node_index]
	var connections: Array = Array(node.get("connections", []))
	return connections.has(to_id)


static func _get_floor_config() -> Dictionary:
	return DataManager.get_floor_config()


static func _get_zone_for_floor(floor_number: int, config: Dictionary) -> Dictionary:
	var zones: Dictionary = Dictionary(config.get("zones", {}))
	for raw_zone_key in zones.keys():
		var zone: Dictionary = Dictionary(zones.get(raw_zone_key, {}))
		var floors: Array = Array(zone.get("floors", []))
		if floors.size() < 2:
			continue
		var min_floor: int = int(floors[0])
		var max_floor: int = int(floors[1])
		if floor_number >= min_floor and floor_number <= max_floor:
			return zone
	return {"name": "未知區域", "element": "none", "boss_floor": -1}


static func get_node_icon(node_type: String) -> String:
	match node_type:
		"entrance":
			return "🚪"
		"exit":
			return "🚪"
		"boss":
			return "💀"
		"battle":
			return "⚔️"
		"elite":
			return "🗡️"
		"event":
			return "❓"
		"chest":
			return "📦"
		"merchant":
			return "🏪"
		"rest":
			return "⛺"
		"altar":
			return "🔮"
		_:
			return "●"


static func get_node_type_name(node_type: String) -> String:
	match node_type:
		"entrance":
			return "入口"
		"exit":
			return "出口"
		"boss":
			return "Boss"
		"battle":
			return "戰鬥"
		"elite":
			return "精英戰"
		"event":
			return "事件"
		"chest":
			return "寶箱"
		"merchant":
			return "商人"
		"rest":
			return "中繼點"
		"altar":
			return "祭壇"
		_:
			return "未知"
