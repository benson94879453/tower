class_name NodeMapUI
extends Control

const FloorGeneratorClass = preload("res://scripts/exploration/floor_generator.gd")
const ThemeConstantsClass = preload("res://scripts/ui/theme_constants.gd")

signal node_clicked(node_id: int)

const NODE_RADIUS: float = 24.0
const ROW_SPACING: float = 100.0
const COL_SPACING: float = 140.0
const MAP_MARGIN := Vector2(80, 60)

var _floor_data: Dictionary = {}
var _current_node_id: int = -1
var _reachable_ids: Array = []
var _node_positions: Dictionary = {}
var _hovered_node_id: int = -1
var _interaction_locked: bool = false
var _breath_time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	if not _reachable_ids.is_empty():
		_breath_time += delta * 2.0
		queue_redraw()


func update_map(floor_data: Dictionary, current_id: int, reachable_ids: Array) -> void:
	_floor_data = floor_data
	_current_node_id = current_id
	_reachable_ids = reachable_ids.duplicate()
	_calculate_positions()
	queue_redraw()


func set_interaction_locked(locked: bool) -> void:
	_interaction_locked = locked
	if locked:
		_hovered_node_id = -1
	queue_redraw()


func _calculate_positions() -> void:
	_node_positions.clear()

	var nodes: Array = Array(_floor_data.get("nodes", []))
	if nodes.is_empty():
		return

	var rows_dict: Dictionary = {}
	for raw_node in nodes:
		var node: Dictionary = raw_node
		var row: int = int(node.get("row", 0))
		if not rows_dict.has(row):
			rows_dict[row] = []
		var row_nodes: Array = Array(rows_dict.get(row, []))
		row_nodes.append(node)
		rows_dict[row] = row_nodes

	var row_keys: Array = rows_dict.keys()
	row_keys.sort()

	for raw_row in row_keys:
		var row: int = int(raw_row)
		var row_nodes: Array = Array(rows_dict.get(row, []))
		row_nodes.sort_custom(func(a, b): return int(Dictionary(a).get("col", 0)) < int(Dictionary(b).get("col", 0)))

		var count: int = row_nodes.size()
		var total_width: float = float(max(count - 1, 0)) * COL_SPACING
		var start_x: float = MAP_MARGIN.x + (size.x - MAP_MARGIN.x * 2.0 - total_width) / 2.0
		var y: float = MAP_MARGIN.y + float(row) * ROW_SPACING

		for index in range(count):
			var node: Dictionary = row_nodes[index]
			var x: float = start_x + float(index) * COL_SPACING
			var node_id: int = int(node.get("id", -1))
			var node_pos := Vector2(x, y)
			_node_positions[node_id] = node_pos


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), ThemeConstantsClass.BG_DARK)
	_draw_background_grid()

	var nodes: Array = Array(_floor_data.get("nodes", []))
	if nodes.is_empty():
		return

	_draw_connections(nodes)
	_draw_nodes(nodes)


func _draw_background_grid() -> void:
	var grid_color := Color(1, 1, 1, 0.03)
	var spacing: float = 60.0
	var x: float = 0.0
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color, 1.0)
		x += spacing
	var y: float = 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), grid_color, 1.0)
		y += spacing


func _draw_connections(nodes: Array) -> void:
	for raw_node in nodes:
		var node: Dictionary = raw_node
		var from_id: int = int(node.get("id", -1))
		if not _node_positions.has(from_id):
			continue
		var from_pos: Vector2 = _node_positions[from_id]
		var connections: Array = Array(node.get("connections", []))
		for raw_connection in connections:
			var connection_id: int = int(raw_connection)
			if not _node_positions.has(connection_id):
				continue
			var to_pos: Vector2 = _node_positions[connection_id]

			var line_color: Color = Color(1, 1, 1, 0.12)
			var line_width: float = 1.5
			if from_id == _current_node_id and _reachable_ids.has(connection_id):
				var breath_alpha: float = 0.6 + 0.4 * sin(_breath_time)
				line_color = Color(1.0, 0.84, 0.0, breath_alpha)
				line_width = 2.5
			elif bool(node.get("visited", false)):
				line_color = Color(1, 1, 1, 0.35)

			var mid := (from_pos + to_pos) / 2.0
			var offset := Vector2(0, -15.0) if abs(from_pos.x - to_pos.x) > 20.0 else Vector2.ZERO
			var curve_mid := mid + offset

			var points: PackedVector2Array = []
			var segments: int = 12
			for i in range(segments + 1):
				var t: float = float(i) / float(segments)
				var p: Vector2 = (1.0 - t) * (1.0 - t) * from_pos + 2.0 * (1.0 - t) * t * curve_mid + t * t * to_pos
				points.append(p)
			if points.size() >= 2:
				draw_polyline(points, line_color, line_width, true)


func _draw_nodes(nodes: Array) -> void:
	for raw_node in nodes:
		var node: Dictionary = raw_node
		var node_id: int = int(node.get("id", -1))
		if not _node_positions.has(node_id):
			continue

		var node_pos: Vector2 = _node_positions[node_id]
		var node_type: String = String(node.get("type", ""))
		var visited: bool = bool(node.get("visited", false))
		var fill_color: Color = _get_node_color(node_type)
		var border_color: Color = Color.WHITE

		var is_current: bool = node_id == _current_node_id
		var is_reachable: bool = _reachable_ids.has(node_id)
		var is_hovered: bool = node_id == _hovered_node_id and is_reachable

		if is_current:
			border_color = Color.GOLD
			draw_circle(node_pos, NODE_RADIUS + 6.0, Color(1, 0.84, 0, 0.25))
		elif is_reachable:
			var breath_alpha: float = 0.15 + 0.15 * sin(_breath_time)
			border_color = Color.GREEN
			draw_circle(node_pos, NODE_RADIUS + 4.0, Color(0, 1, 0, breath_alpha))
		elif visited:
			fill_color = fill_color.darkened(0.5)
			border_color = Color(1, 1, 1, 0.35)
		else:
			fill_color = fill_color.darkened(0.3)
			border_color = Color(1, 1, 1, 0.15)

		if is_hovered:
			draw_circle(node_pos, NODE_RADIUS + 8.0, Color(0, 1, 0, 0.2))

		_draw_node_shape(node_pos, node_type, fill_color, border_color, is_current)

		var icon: String = FloorGeneratorClass.get_node_icon(node_type)
		var font: Font = ThemeDB.fallback_font
		if font != null:
			var font_size: int = 16
			var text_size: Vector2 = font.get_string_size(icon, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
			var ascent: float = font.get_ascent(font_size)
			var baseline_pos: Vector2 = node_pos - Vector2(text_size.x / 2.0, text_size.y / 2.0) + Vector2(0, ascent)
			draw_string(
				font,
				baseline_pos,
				icon,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				font_size,
				ThemeConstantsClass.TEXT_PRIMARY
			)


func _draw_node_shape(pos: Vector2, node_type: String, fill: Color, border: Color, is_current: bool) -> void:
	var r: float = NODE_RADIUS
	if is_current:
		r += 2.0

	match node_type:
		"battle", "elite":
			var scale_factor: float = 1.2 if node_type == "elite" else 1.0
			var sr: float = r * scale_factor
			var points := PackedVector2Array([
				pos + Vector2(0, -sr),
				pos + Vector2(sr * 0.866, sr * 0.5),
				pos + Vector2(-sr * 0.866, sr * 0.5),
			])
			draw_colored_polygon(points, fill)
			draw_polyline(points + PackedVector2Array([points[0]]), border, 2.0, true)
		"boss":
			var points := _pentagon_points(pos, r * 1.15)
			draw_colored_polygon(points, fill)
			draw_polyline(points + PackedVector2Array([points[0]]), border, 2.5, true)
		"chest":
			var points := _hexagon_points(pos, r)
			draw_colored_polygon(points, fill)
			draw_polyline(points + PackedVector2Array([points[0]]), border, 2.0, true)
		"merchant":
			var points := PackedVector2Array([
				pos + Vector2(0, -r),
				pos + Vector2(r, 0),
				pos + Vector2(0, r),
				pos + Vector2(-r, 0),
			])
			draw_colored_polygon(points, fill)
			draw_polyline(points + PackedVector2Array([points[0]]), border, 2.0, true)
		"rest":
			var half := r * 0.75
			var rect := Rect2(pos - Vector2(half, half), Vector2(half * 2, half * 2))
			draw_rect(rect, fill)
			draw_rect(rect, border, false, 2.0)
		_:
			draw_circle(pos, r, fill)
			draw_arc(pos, r, 0.0, TAU, 32, border, 2.0, true)


func _pentagon_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(5):
		var angle: float = -PI / 2.0 + float(i) * TAU / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _hexagon_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(6):
		var angle: float = float(i) * TAU / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _get_node_color(node_type: String) -> Color:
	match node_type:
		"entrance":
			return Color("#336699")
		"exit":
			return Color("#336699")
		"boss":
			return Color("#CC2222")
		"battle":
			return Color("#CC4444")
		"elite":
			return Color("#FF6600")
		"event":
			return Color("#6666CC")
		"chest":
			return Color("#CCAA33")
		"merchant":
			return Color("#33AA66")
		"rest":
			return Color("#33AAAA")
		"altar":
			return Color("#AA33CC")
		_:
			return Color("#666666")


func _gui_input(event: InputEvent) -> void:
	if _interaction_locked:
		return

	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var clicked_id: int = _get_node_at_position(event.position)
			if clicked_id >= 0 and _reachable_ids.has(clicked_id):
				node_clicked.emit(clicked_id)
	elif event is InputEventMouseMotion:
		var previous_hover: int = _hovered_node_id
		_hovered_node_id = _get_node_at_position(event.position)
		if previous_hover != _hovered_node_id:
			queue_redraw()


func _get_node_at_position(pointer_position: Vector2) -> int:
	for raw_node_id in _node_positions.keys():
		var node_id: int = int(raw_node_id)
		var node_position: Vector2 = _node_positions[node_id]
		if pointer_position.distance_to(node_position) <= NODE_RADIUS + 4.0:
			return node_id
	return -1
