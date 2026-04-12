class_name ThemeBuilder
extends RefCounted

const ThemeConstantsClass = preload("res://scripts/ui/theme_constants.gd")
const DEFAULT_THEME_PATH := "res://assets/themes/geometric_theme.tres"


static func build_theme() -> Theme:
	var theme := Theme.new()

	var panel_style := _create_stylebox(
		ThemeConstantsClass.PANEL_BG,
		ThemeConstantsClass.ACCENT,
		ThemeConstantsClass.PANEL_BORDER_WIDTH,
		ThemeConstantsClass.PANEL_CORNER_RADIUS
	)
	theme.set_stylebox("panel", "Panel", panel_style)
	theme.set_stylebox("panel", "PanelContainer", panel_style.duplicate())

	var button_normal := _create_stylebox(
		ThemeConstantsClass.BG_MID,
		ThemeConstantsClass.TEXT_SECONDARY,
		1,
		ThemeConstantsClass.BUTTON_CORNER_RADIUS,
		ThemeConstantsClass.MARGIN_NORMAL,
		ThemeConstantsClass.MARGIN_SMALL
	)
	theme.set_stylebox("normal", "Button", button_normal)

	var button_hover := button_normal.duplicate() as StyleBoxFlat
	button_hover.bg_color = ThemeConstantsClass.PANEL_BG
	button_hover.border_color = ThemeConstantsClass.ACCENT
	theme.set_stylebox("hover", "Button", button_hover)

	var button_pressed := button_normal.duplicate() as StyleBoxFlat
	button_pressed.bg_color = ThemeConstantsClass.ACCENT
	button_pressed.border_color = ThemeConstantsClass.ACCENT
	theme.set_stylebox("pressed", "Button", button_pressed)

	var button_disabled := button_normal.duplicate() as StyleBoxFlat
	button_disabled.bg_color = ThemeConstantsClass.BG_DARK
	button_disabled.border_color = Color("#333333")
	theme.set_stylebox("disabled", "Button", button_disabled)

	var line_edit_normal := _create_stylebox(
		ThemeConstantsClass.BG_DARK,
		ThemeConstantsClass.TEXT_SECONDARY,
		1,
		4,
		ThemeConstantsClass.MARGIN_SMALL,
		ThemeConstantsClass.MARGIN_SMALL
	)
	theme.set_stylebox("normal", "LineEdit", line_edit_normal)
	theme.set_stylebox("focus", "LineEdit", line_edit_normal.duplicate())
	theme.set_stylebox("read_only", "LineEdit", line_edit_normal.duplicate())

	var progress_background := _create_stylebox(
		ThemeConstantsClass.BG_DARK,
		Color.TRANSPARENT,
		0,
		4
	)
	theme.set_stylebox("background", "ProgressBar", progress_background)

	var progress_fill := _create_stylebox(
		ThemeConstantsClass.HP_COLOR,
		Color.TRANSPARENT,
		0,
		4
	)
	theme.set_stylebox("fill", "ProgressBar", progress_fill)

	# HP ProgressBar Variation
	var hp_fill := _create_stylebox(ThemeConstantsClass.HP_COLOR, Color.TRANSPARENT, 0, 4)
	theme.set_type_variation("ProgressBarHP", "ProgressBar")
	theme.set_stylebox("fill", "ProgressBarHP", hp_fill)

	# MP ProgressBar Variation
	var mp_fill := _create_stylebox(ThemeConstantsClass.MP_COLOR, Color.TRANSPARENT, 0, 4)
	theme.set_type_variation("ProgressBarMP", "ProgressBar")
	theme.set_stylebox("fill", "ProgressBarMP", mp_fill)

	# EXP ProgressBar Variation
	var exp_fill := _create_stylebox(ThemeConstantsClass.EXP_COLOR, Color.TRANSPARENT, 0, 4)
	theme.set_type_variation("ProgressBarEXP", "ProgressBar")
	theme.set_stylebox("fill", "ProgressBarEXP", exp_fill)

	var popup_panel := _create_stylebox(
		ThemeConstantsClass.BG_MID,
		ThemeConstantsClass.PANEL_BG,
		1,
		6
	)
	theme.set_stylebox("panel", "PopupMenu", popup_panel)

	# Combatant Panel Variations
	var combatant_panel := _create_stylebox(
		ThemeConstantsClass.PANEL_BG.darkened(0.2),
		ThemeConstantsClass.ACCENT,
		2,
		8,
		8,
		8
	)
	theme.set_type_variation("CombatantPanel", "PanelContainer")
	theme.set_stylebox("panel", "CombatantPanel", combatant_panel)

	var enemy_panel := _create_stylebox(
		ThemeConstantsClass.BG_DARK,
		ThemeConstantsClass.TEXT_SECONDARY,
		1,
		8,
		6,
		6
	)
	theme.set_type_variation("EnemyPanel", "PanelContainer")
	theme.set_stylebox("panel", "EnemyPanel", enemy_panel)

	# Skill Card Variation — left accent stripe applied at runtime per element
	var skill_card := _create_stylebox(
		ThemeConstantsClass.BG_MID.darkened(0.1),
		ThemeConstantsClass.TEXT_SECONDARY.darkened(0.3),
		1,
		6,
		6,
		4
	)
	theme.set_type_variation("SkillCard", "PanelContainer")
	theme.set_stylebox("panel", "SkillCard", skill_card)

	theme.set_color("font_color", "Button", ThemeConstantsClass.TEXT_PRIMARY)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color("#555555"))
	theme.set_color("font_color", "Label", ThemeConstantsClass.TEXT_PRIMARY)
	theme.set_color("font_color", "LineEdit", ThemeConstantsClass.TEXT_PRIMARY)

	theme.set_font_size("font_size", "Button", ThemeConstantsClass.FONT_SIZE_NORMAL)
	theme.set_font_size("font_size", "Label", ThemeConstantsClass.FONT_SIZE_NORMAL)
	theme.set_font_size("font_size", "LineEdit", ThemeConstantsClass.FONT_SIZE_NORMAL)
	theme.set_font_size("title_font_size", "Window", ThemeConstantsClass.FONT_SIZE_LARGE)

	return theme


static func ensure_theme_resource(theme_path: String = DEFAULT_THEME_PATH) -> Error:
	# Always save during development to ensure theme changes are applied
	return save_theme_resource(theme_path)


static func save_theme_resource(theme_path: String = DEFAULT_THEME_PATH) -> Error:
	var error := ResourceSaver.save(build_theme(), theme_path)
	if error != OK:
		push_error("Failed to save theme resource: %s" % theme_path)

	return error


static func _create_stylebox(
	bg_color: Color,
	border_color: Color,
	border_width: int,
	corner_radius: int,
	h_margin: int = 0,
	v_margin: int = 0
) -> StyleBoxFlat:
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = bg_color
	stylebox.border_color = border_color
	stylebox.border_width_left = border_width
	stylebox.border_width_top = border_width
	stylebox.border_width_right = border_width
	stylebox.border_width_bottom = border_width
	stylebox.corner_radius_top_left = corner_radius
	stylebox.corner_radius_top_right = corner_radius
	stylebox.corner_radius_bottom_right = corner_radius
	stylebox.corner_radius_bottom_left = corner_radius
	stylebox.content_margin_left = h_margin
	stylebox.content_margin_right = h_margin
	stylebox.content_margin_top = v_margin
	stylebox.content_margin_bottom = v_margin
	return stylebox
