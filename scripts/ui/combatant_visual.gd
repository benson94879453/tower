@tool
class_name CombatantVisual
extends Control

const ThemeConstantsRef = preload("res://scripts/ui/theme_constants.gd")
const DrawShapeRef = preload("res://scripts/ui/draw_shape.gd")

@export var combatant_name: String = "" : set = set_combatant_name
@export var element: String = "none" : set = set_element
@export var visual: Dictionary = {} : set = set_visual
@export var is_player: bool = false : set = set_is_player
@export var show_glow: bool = true : set = set_show_glow

var _fill_color: Color
var _outline_color: Color
var _glow_color: Color


func _ready() -> void:
	_update_colors()
	queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var radius: float = min(size.x, size.y) * 0.4
	
	if is_player:
		var shapes: Dictionary = DrawShapeRef.get_player_shape(center, radius)
		if show_glow:
			DrawShapeRef.draw_glow(self, shapes.outline, center, _glow_color)
		DrawShapeRef.draw_outlined_polygon(self, shapes.outline, _fill_color, _outline_color)
		DrawShapeRef.draw_outlined_polygon(self, shapes.inner, _outline_color.lightened(0.5), Color.WHITE, 1.0)
	else:
		var points: PackedVector2Array = DrawShapeRef.get_shape_from_data(center, visual)
		if points.size() > 0:
			if show_glow:
				DrawShapeRef.draw_glow(self, points, center, _glow_color)
			DrawShapeRef.draw_outlined_polygon(self, points, _fill_color, _outline_color)
			# Draw small element icon below shape for enemies
			if element != "" and element != "none":
				var icon_pos := Vector2(center.x, center.y + min(size.x, size.y) * 0.38)
				DrawShapeRef.draw_element_icon(self, element, icon_pos, 12.0, _outline_color)
		else:
			# Fallback to circle if no points returned
			var circle_points: PackedVector2Array = DrawShapeRef.get_circle(center, radius)
			if show_glow:
				DrawShapeRef.draw_glow(self, circle_points, center, _glow_color)
			DrawShapeRef.draw_outlined_polygon(self, circle_points, _fill_color, _outline_color)


func _update_colors() -> void:
	_fill_color = ThemeConstantsRef.get_element_color(element, "main")
	_outline_color = ThemeConstantsRef.get_element_color(element, "sub")
	_glow_color = ThemeConstantsRef.get_element_color(element, "glow")
	
	if is_player:
		# Player might have special coloring logic, but for now use element
		pass


func set_combatant_name(val: String) -> void:
	combatant_name = val
	queue_redraw()


func set_element(val: String) -> void:
	element = val
	_update_colors()
	queue_redraw()


func set_visual(val: Dictionary) -> void:
	visual = val
	queue_redraw()


func set_is_player(val: bool) -> void:
	is_player = val
	queue_redraw()


func set_show_glow(val: bool) -> void:
	show_glow = val
	queue_redraw()
