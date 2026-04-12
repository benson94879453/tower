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

const ELEMENT_BG_TINT := {
	"fire": Color("#2A1515"),
	"water": Color("#152035"),
	"thunder": Color("#2A2A15"),
	"wind": Color("#152A1A"),
	"earth": Color("#2A2215"),
	"light": Color("#252530"),
	"dark": Color("#1A1528"),
	"none": Color("#1A1A2E"),
}

const ZONE_AMBIENT := {
	"zone1": {"bg": Color("#1A1A2E"), "accent": Color("#888888"), "name": "廢墟入口"},
	"zone2": {"bg": Color("#2E1A1A"), "accent": Color("#FF4444"), "name": "熔岩鍛爐"},
	"zone3": {"bg": Color("#1A2E2E"), "accent": Color("#4488FF"), "name": "極寒冰域"},
	"zone4": {"bg": Color("#1A2E1A"), "accent": Color("#44CC44"), "name": "暴風迴廊"},
	"zone5": {"bg": Color("#2E2A1A"), "accent": Color("#AA7744"), "name": "大地迷宮"},
	"zone6": {"bg": Color("#2E2E1A"), "accent": Color("#FFDD00"), "name": "雷鳴雲海"},
	"zone7": {"bg": Color("#1A1A2E"), "accent": Color("#8844CC"), "name": "暗影深淵"},
	"zone8": {"bg": Color("#2A2A2A"), "accent": Color("#FFFFFF"), "name": "聖光殿堂"},
	"zone9": {"bg": Color("#1E1A28"), "accent": Color("#AA66FF"), "name": "虛空之境"},
	"zone10": {"bg": Color("#251A20"), "accent": Color("#FFD700"), "name": "混沌領域"},
}

const STATUS_COLORS := {
	"burn": Color("#FF6633"),
	"poison": Color("#AA44AA"),
	"heavy_poison": Color("#880088"),
	"freeze": Color("#66CCFF"),
	"paralyze": Color("#FFDD00"),
	"sleep": Color("#8888CC"),
	"confuse": Color("#FF88FF"),
	"charm": Color("#FF66AA"),
	"seal": Color("#666666"),
	"curse": Color("#660066"),
	"atk_up": Color("#44CC44"),
	"def_up": Color("#4488FF"),
	"spd_up": Color("#44CCCC"),
	"atk_down": Color("#CC4444"),
	"def_down": Color("#CC6644"),
	"spd_down": Color("#CC8844"),
	"acc_down": Color("#AA6644"),
	"regen": Color("#33FF66"),
	"mp_regen": Color("#3388FF"),
	"reflect": Color("#AAAAFF"),
	"stealth": Color("#88AAAA"),
}


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


static func apply_gradient_bar(bar: ProgressBar, color_primary: Color, color_dark: Color, bg_color: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color_primary
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_right = 4
	fill.corner_radius_bottom_left = 4
	fill.shadow_color = Color(color_dark, 0.35)
	fill.shadow_size = 2
	fill.shadow_offset = Vector2(0, 1)
	bar.add_theme_stylebox_override("fill", fill)

	var bg := StyleBoxFlat.new()
	bg.bg_color = bg_color
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_right = 4
	bg.corner_radius_bottom_left = 4
	bar.add_theme_stylebox_override("background", bg)
