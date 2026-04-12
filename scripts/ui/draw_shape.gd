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


# ---------------------------------------------------------------
# Element Icon System
# ---------------------------------------------------------------


static func get_element_icon(element: String, center: Vector2, size: float) -> PackedVector2Array:
	var el := element if element != "" else "none"
	match el:
		"fire":
			return get_regular_polygon(center, size * 0.45, 3, 0.0)
		"water":
			var w := size * 0.8
			var h := size * 0.3
			var lx := center.x - w / 2.0
			var pts := PackedVector2Array()
			var wave_steps := 12
			for i in range(wave_steps + 1):
				var t := float(i) / float(wave_steps)
				var x := lx + t * w
				var y := center.y - h * sin(t * PI * 5.0)
				pts.append(Vector2(x, y))
			pts.append(Vector2(lx + w, center.y + h))
			pts.append(Vector2(lx, center.y + h))
			return pts
		"thunder":
			var hw := size * 0.2
			var hh := size * 0.4
			return PackedVector2Array([
				center + Vector2(0.0, -hh),
				center + Vector2(hw, -hh * 0.3),
				center + Vector2(-hw * 0.2, -hh * 0.05),
				center + Vector2(hw * 0.8, hh * 0.2),
				center + Vector2(0.0, hh),
				center + Vector2(-hw, hh * 0.15),
				center + Vector2(hw * 0.2, -hh * 0.2),
			])
		"wind":
			var s := size * 0.4
			return PackedVector2Array([
				center + Vector2(-s, -s * 0.3),
				center + Vector2(-s * 0.1, -s * 0.6),
				center + Vector2(s, s * 0.1),
				center + Vector2(s * 0.6, s * 0.4),
				center + Vector2(s * 0.1, s * 0.15),
				center + Vector2(-s * 0.7, -s * 0.1),
			])
		"earth":
			return get_regular_polygon(center, size * 0.4, 4, 0.0)
		"light":
			return get_star(center, size * 0.45, size * 0.18, 4)
		"dark":
			var outer_r := size * 0.45
			var inner_r := size * 0.35
			var inner_offset := Vector2(size * 0.15, 0.0)
			var pts := PackedVector2Array()
			var n := 6
			# Outer arc: left side of crescent (120 deg to 240 deg)
			for i in range(n):
				var a := deg_to_rad(120.0 + 120.0 * float(i) / float(n - 1))
				pts.append(center + Vector2(cos(a), sin(a)) * outer_r)
			# Inner arc: shadow edge (240 deg to 480 deg through right side)
			for i in range(n):
				var a := deg_to_rad(240.0 + 240.0 * float(i) / float(n - 1))
				pts.append(center + inner_offset + Vector2(cos(a), sin(a)) * inner_r)
			return pts
		_:
			return get_circle(center, size * 0.35, 16)


static func draw_element_icon(canvas: CanvasItem, element: String, center: Vector2, size: float, color: Color = Color.WHITE) -> void:
	var points := get_element_icon(element, center, size)
	if points.size() < 3:
		return
	canvas.draw_colored_polygon(points, color.darkened(0.1))
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	canvas.draw_polyline(closed, color, 1.5, true)


# ---------------------------------------------------------------
# Skill Type Icon System
# ---------------------------------------------------------------


static func get_skill_type_icon(skill_type: String, center: Vector2, size: float) -> PackedVector2Array:
	if skill_type.contains("attack_single"):
		# Sword kite shape
		var s := size * 0.4
		return PackedVector2Array([
			center + Vector2(0.0, -s),
			center + Vector2(s * 0.5, -s * 0.15),
			center + Vector2(0.0, s * 0.8),
			center + Vector2(-s * 0.5, -s * 0.15),
		])
	elif skill_type.contains("attack_all"):
		# Trident spread shape
		var s := size * 0.35
		return PackedVector2Array([
			center + Vector2(0.0, s * 0.4),
			center + Vector2(-s * 0.9, -s * 0.5),
			center + Vector2(-s * 0.2, 0.0),
			center + Vector2(0.0, -s * 0.7),
			center + Vector2(s * 0.2, 0.0),
			center + Vector2(s * 0.9, -s * 0.5),
		])
	elif skill_type.contains("heal"):
		# Plus/cross shape (12 points)
		var s := size * 0.35
		var t := s * 0.35
		return PackedVector2Array([
			center + Vector2(-t, -s),
			center + Vector2(t, -s),
			center + Vector2(t, -t),
			center + Vector2(s, -t),
			center + Vector2(s, t),
			center + Vector2(t, t),
			center + Vector2(t, s),
			center + Vector2(-t, s),
			center + Vector2(-t, t),
			center + Vector2(-s, t),
			center + Vector2(-s, -t),
			center + Vector2(-t, -t),
		])
	elif skill_type.contains("debuff"):
		# Downward triangle
		return get_regular_polygon(center, size * 0.3, 3, 180.0)
	elif skill_type.contains("buff"):
		# Upward triangle
		return get_regular_polygon(center, size * 0.3, 3, 0.0)
	elif skill_type.contains("status"):
		return get_hexagon(center, size * 0.3)
	elif skill_type.contains("shield"):
		# Kite shield
		var s := size * 0.35
		return PackedVector2Array([
			center + Vector2(0.0, -s),
			center + Vector2(s * 0.7, -s * 0.5),
			center + Vector2(s * 0.6, s * 0.2),
			center + Vector2(0.0, s),
			center + Vector2(-s * 0.6, s * 0.2),
			center + Vector2(-s * 0.7, -s * 0.5),
		])
	elif skill_type.contains("passive") or skill_type == "passive":
		# Interlocking rings (vesica piscis outline)
		var r := size * 0.2
		var d := size * 0.12
		var pts := PackedVector2Array()
		var ring_steps := 8
		# Left circle: left arc
		for i in range(ring_steps):
			var a := PI / 2.0 + PI * float(i) / float(ring_steps - 1)
			pts.append(center + Vector2(-d, 0.0) + Vector2(cos(a), sin(a)) * r)
		# Right circle: right arc
		for i in range(ring_steps):
			var a := -PI / 2.0 + PI * float(i) / float(ring_steps - 1)
			pts.append(center + Vector2(d, 0.0) + Vector2(cos(a), sin(a)) * r)
		return pts
	else:
		return get_diamond(center, size * 0.3, size * 0.3)


static func draw_skill_type_icon(canvas: CanvasItem, skill_type: String, center: Vector2, size: float, color: Color) -> void:
	var points := get_skill_type_icon(skill_type, center, size)
	if points.size() < 3:
		return
	canvas.draw_colored_polygon(points, color.darkened(0.1))
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	canvas.draw_polyline(closed, color, 1.5, true)


static func get_skill_type_display(skill_type: String) -> String:
	if skill_type.contains("all"):
		return "全體"
	elif skill_type.contains("heal"):
		return "回復"
	elif skill_type.contains("debuff"):
		return "弱化"
	elif skill_type.contains("buff") or skill_type.contains("self"):
		return "強化"
	elif skill_type.contains("status"):
		return "狀態"
	elif skill_type.contains("shield"):
		return "護盾"
	elif skill_type.contains("passive") or skill_type == "passive":
		return "被動"
	else:
		return "單體"
