class_name DrawShape
extends RefCounted


static func get_regular_polygon(center: Vector2, radius: float, sides: int, rotation_deg: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	if sides < 3:
		return points

	var angle_step := TAU / float(sides)
	var start_angle := deg_to_rad(rotation_deg) - PI / 2.0
	for index in range(sides):
		var angle := start_angle + angle_step * index
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)

	return points


static func get_star(center: Vector2, outer_radius: float, inner_radius: float, points_count: int, rotation_deg: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	if points_count < 2:
		return points

	var angle_step := TAU / float(points_count * 2)
	var start_angle := deg_to_rad(rotation_deg) - PI / 2.0
	for index in range(points_count * 2):
		var radius := outer_radius if index % 2 == 0 else inner_radius
		var angle := start_angle + angle_step * index
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)

	return points


static func get_diamond(center: Vector2, width: float, height: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0.0, -height / 2.0),
		center + Vector2(width / 2.0, 0.0),
		center + Vector2(0.0, height / 2.0),
		center + Vector2(-width / 2.0, 0.0),
	])


static func get_hexagon(center: Vector2, radius: float) -> PackedVector2Array:
	return get_regular_polygon(center, radius, 6, 0.0)


static func get_sharp_triangle(center: Vector2, size: float) -> PackedVector2Array:
	return get_regular_polygon(center, size, 3, 0.0)


static func get_circle(center: Vector2, radius: float, segments: int = 32) -> PackedVector2Array:
	return get_regular_polygon(center, radius, max(segments, 3), 0.0)


static func get_player_shape(center: Vector2, radius: float) -> Dictionary:
	return {
		"outline": get_regular_polygon(center, radius, 5),
		"inner": get_star(center, radius * 0.5, radius * 0.25, 5),
	}


static func get_shape_from_data(center: Vector2, visual_data: Dictionary) -> PackedVector2Array:
	var size_map := {
		"small": 16.0,
		"medium": 24.0,
		"large": 32.0,
		"boss": 48.0,
	}
	var radius: float = size_map.get(String(visual_data.get("size", "medium")), 24.0)
	var shape_type := String(visual_data.get("shape", "circle"))

	match shape_type:
		"triangle":
			return get_regular_polygon(center, radius, 3)
		"sharp_triangle":
			return get_sharp_triangle(center, radius)
		"square":
			return get_regular_polygon(center, radius, 4, 45.0)
		"pentagon":
			return get_regular_polygon(center, radius, 5)
		"hexagon":
			return get_hexagon(center, radius)
		"diamond":
			return get_diamond(center, radius * 1.2, radius * 1.6)
		"star":
			return get_star(center, radius, radius * 0.5, 5)
		_:
			return get_circle(center, radius)


static func draw_outlined_polygon(canvas: CanvasItem, points: PackedVector2Array, fill_color: Color, outline_color: Color, outline_width: float = 2.0) -> void:
	canvas.draw_colored_polygon(points, fill_color)
	for index in range(points.size()):
		var next_index := (index + 1) % points.size()
		canvas.draw_line(points[index], points[next_index], outline_color, outline_width, true)


static func draw_glow(canvas: CanvasItem, points: PackedVector2Array, center: Vector2, glow_color: Color, glow_radius: float = 4.0) -> void:
	var glow_points := PackedVector2Array()
	for point in points:
		var direction := (point - center).normalized()
		glow_points.append(point + direction * glow_radius)

	var faded := Color(glow_color.r, glow_color.g, glow_color.b, 0.3)
	canvas.draw_colored_polygon(glow_points, faded)


static func draw_bar(canvas: CanvasItem, pos: Vector2, width: float, height: float, ratio: float, fill_color: Color, bg_color: Color, border_color: Color = Color.TRANSPARENT) -> void:
	var clamped_ratio := clampf(ratio, 0.0, 1.0)
	var rect := Rect2(pos, Vector2(width, height))
	canvas.draw_rect(rect, bg_color)

	if clamped_ratio > 0.0:
		canvas.draw_rect(Rect2(pos, Vector2(width * clamped_ratio, height)), fill_color)

	if border_color.a > 0.0:
		canvas.draw_rect(rect, border_color, false, 1.0)
