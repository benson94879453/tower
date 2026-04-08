class_name ThemeConstants
extends RefCounted

const BG_DARK := Color("#1A1A2E")
const BG_MID := Color("#16213E")
const PANEL_BG := Color("#0F3460")
const ACCENT := Color("#E94560")
const TEXT_PRIMARY := Color("#EAEAEA")
const TEXT_SECONDARY := Color("#8B8B8B")

const ELEMENT_COLORS := {
	"fire": {"main": Color("#FF4444"), "sub": Color("#FF8800"), "glow": Color("#FFCC00")},
	"water": {"main": Color("#4488FF"), "sub": Color("#00CCFF"), "glow": Color("#88EEFF")},
	"thunder": {"main": Color("#FFDD00"), "sub": Color("#FFFF44"), "glow": Color("#FFFFFF")},
	"wind": {"main": Color("#44CC44"), "sub": Color("#88FF88"), "glow": Color("#CCFFCC")},
	"earth": {"main": Color("#AA7744"), "sub": Color("#CC9966"), "glow": Color("#DDBB88")},
	"light": {"main": Color("#FFFFFF"), "sub": Color("#FFFFCC"), "glow": Color("#FFFFF0")},
	"dark": {"main": Color("#8844CC"), "sub": Color("#AA66FF"), "glow": Color("#CC88FF")},
	"none": {"main": Color("#888888"), "sub": Color("#AAAAAA"), "glow": Color("#CCCCCC")},
}

const RARITY_COLORS := {
	"N": {"border": Color("#FFFFFF"), "bg": Color("#333333")},
	"R": {"border": Color("#44CC44"), "bg": Color("#1A3A1A")},
	"SR": {"border": Color("#4488FF"), "bg": Color("#1A2A4A")},
	"SSR": {"border": Color("#AA44FF"), "bg": Color("#2A1A4A")},
	"UR": {"border": Color("#FFD700"), "bg": Color("#3A3A1A")},
}

const HP_COLOR := Color("#44CC44")
const HP_BG_COLOR := Color("#1A3A1A")
const MP_COLOR := Color("#4488FF")
const MP_BG_COLOR := Color("#1A2A4A")
const EXP_COLOR := Color("#FFD700")
const EXP_BG_COLOR := Color("#3A3A1A")

const FONT_SIZE_SMALL := 12
const FONT_SIZE_NORMAL := 16
const FONT_SIZE_LARGE := 22
const FONT_SIZE_TITLE := 28

const PANEL_CORNER_RADIUS := 8
const BUTTON_CORNER_RADIUS := 6
const PANEL_BORDER_WIDTH := 2
const BUTTON_MIN_HEIGHT := 40
const MARGIN_SMALL := 8
const MARGIN_NORMAL := 16
const MARGIN_LARGE := 24


static func get_element_color(element: String, color_role: String = "main") -> Color:
	var palette: Dictionary = ELEMENT_COLORS.get(element, ELEMENT_COLORS["none"])
	return palette.get(color_role, ELEMENT_COLORS["none"]["main"])


static func get_rarity_border(rarity: String) -> Color:
	var palette: Dictionary = RARITY_COLORS.get(rarity, RARITY_COLORS["N"])
	return palette.get("border", RARITY_COLORS["N"]["border"])


static func get_rarity_bg(rarity: String) -> Color:
	var palette: Dictionary = RARITY_COLORS.get(rarity, RARITY_COLORS["N"])
	return palette.get("bg", RARITY_COLORS["N"]["bg"])


static func create_bar_style(fill_color: Color, bg_color: Color, radius: int = 4) -> Array:
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.corner_radius_top_left = radius
	fill.corner_radius_top_right = radius
	fill.corner_radius_bottom_right = radius
	fill.corner_radius_bottom_left = radius

	var bg := StyleBoxFlat.new()
	bg.bg_color = bg_color
	bg.corner_radius_top_left = radius
	bg.corner_radius_top_right = radius
	bg.corner_radius_bottom_right = radius
	bg.corner_radius_bottom_left = radius

	return [fill, bg]


static func apply_bar_style(bar: ProgressBar, fill_color: Color, bg_color: Color) -> void:
	var styles: Array = create_bar_style(fill_color, bg_color)
	bar.add_theme_stylebox_override("fill", styles[0])
	bar.add_theme_stylebox_override("background", styles[1])


static func create_panel_style(
	bg_color: Color = PANEL_BG,
	border_color: Color = ACCENT,
	border_width: int = 2,
	radius: int = PANEL_CORNER_RADIUS,
	margin: float = 0.0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	if margin > 0.0:
		style.content_margin_left = margin
		style.content_margin_top = margin
		style.content_margin_right = margin
		style.content_margin_bottom = margin
	return style


static func create_list_item_bg(index: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BG_MID if index % 2 == 0 else BG_DARK
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 8.0
	style.content_margin_top = 4.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 4.0
	return style
