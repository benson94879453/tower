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
