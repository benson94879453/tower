class_name SafeZoneUI
extends Control

const ThemeConstantsClass = preload("res://scripts/ui/theme_constants.gd")
const InventoryPanelClass = preload("res://scripts/ui/inventory_panel.gd")
const ShopPanelClass = preload("res://scripts/safe_zone/shop_panel.gd")
const ForgePanelClass = preload("res://scripts/safe_zone/forge_panel.gd")
const FamiliarHousePanelClass = preload("res://scripts/safe_zone/familiar_house_panel.gd")
const LibraryPanelClass = preload("res://scripts/safe_zone/library_panel.gd")
const TavernPanelClass = preload("res://scripts/safe_zone/tavern_panel.gd")

signal explore_requested(floor_number: int)
signal teleport_requested(floor_number: int)
signal rest_requested
signal save_requested

var current_safe_floor: int = 1
var highest_floor: int = 1
var _inventory_panel = null
var _shop_panel = null
var _forge_panel = null
var _familiar_house_panel = null
var _library_panel = null
var _tavern_panel = null

@onready var zone_label: Label = $ZoneLabel
@onready var status_panel: PanelContainer = $MainLayout/LeftPanel/StatusPanel
@onready var player_name_label: Label = $MainLayout/LeftPanel/StatusPanel/Padding/StatusContent/PlayerNameLabel
@onready var hp_bar: ProgressBar = $MainLayout/LeftPanel/StatusPanel/Padding/StatusContent/HPRow/HPBar
@onready var hp_value: Label = $MainLayout/LeftPanel/StatusPanel/Padding/StatusContent/HPRow/HPValue
@onready var mp_bar: ProgressBar = $MainLayout/LeftPanel/StatusPanel/Padding/StatusContent/MPRow/MPBar
@onready var mp_value: Label = $MainLayout/LeftPanel/StatusPanel/Padding/StatusContent/MPRow/MPValue
@onready var gold_label: Label = $MainLayout/LeftPanel/StatusPanel/Padding/StatusContent/GoldLabel
@onready var title_status_label: Label = $MainLayout/LeftPanel/StatusPanel/Padding/StatusContent/TitleStatusLabel
@onready var familiar_label: Label = $MainLayout/LeftPanel/StatusPanel/Padding/StatusContent/FamiliarLabel
@onready var floor_label: Label = $MainLayout/LeftPanel/StatusPanel/Padding/StatusContent/FloorLabel
@onready var equip_summary: RichTextLabel = $MainLayout/LeftPanel/StatusPanel/Padding/StatusContent/EquipSummary
@onready var inventory_button: Button = $MainLayout/RightPanel/FacilityGrid/InventoryButton
@onready var shop_button: Button = $MainLayout/RightPanel/FacilityGrid/ShopButton
@onready var forge_button: Button = $MainLayout/RightPanel/FacilityGrid/ForgeButton
@onready var familiar_button: Button = $MainLayout/RightPanel/FacilityGrid/FamiliarButton
@onready var library_button: Button = $MainLayout/RightPanel/FacilityGrid/LibraryButton
@onready var tavern_button: Button = $MainLayout/RightPanel/FacilityGrid/TavernButton
@onready var explore_button: Button = $MainLayout/RightPanel/ActionRow/ExploreButton
@onready var teleport_button: Button = $MainLayout/RightPanel/ActionRow/TeleportButton
@onready var rest_button: Button = $MainLayout/RightPanel/SystemRow/RestButton
@onready var save_button: Button = $MainLayout/RightPanel/SystemRow/SaveButton
@onready var teleport_panel: PanelContainer = $TeleportPanel
@onready var teleport_list: VBoxContainer = $TeleportPanel/Padding/Content/TeleportScroll/TeleportList
@onready var teleport_close_button: Button = $TeleportPanel/Padding/Content/CloseButton


func _ready() -> void:
	_apply_theme_variations()
	inventory_button.pressed.connect(_on_inventory_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	forge_button.pressed.connect(_on_forge_pressed)
	familiar_button.pressed.connect(_on_familiar_pressed)
	library_button.pressed.connect(_on_library_pressed)
	tavern_button.pressed.connect(_on_tavern_pressed)
	explore_button.pressed.connect(_on_explore_pressed)
	teleport_button.pressed.connect(_on_teleport_pressed)
	rest_button.pressed.connect(_request_rest)
	save_button.pressed.connect(_request_save)
	teleport_close_button.pressed.connect(func(): teleport_panel.visible = false)
	teleport_panel.visible = false

	_style_hp_mp_bars()


func _style_hp_mp_bars() -> void:
	ThemeConstantsClass.apply_gradient_bar(hp_bar, ThemeConstantsClass.HP_COLOR, ThemeConstantsClass.HP_COLOR.darkened(0.4), ThemeConstantsClass.HP_BG_COLOR)
	ThemeConstantsClass.apply_gradient_bar(mp_bar, ThemeConstantsClass.MP_COLOR, ThemeConstantsClass.MP_COLOR.darkened(0.4), ThemeConstantsClass.MP_BG_COLOR)


func _apply_theme_variations() -> void:
	status_panel.theme_type_variation = "CombatantPanel"
	teleport_panel.theme_type_variation = "CombatantPanel"


func setup(safe_floor: int) -> void:
	current_safe_floor = safe_floor
	highest_floor = PlayerManager.player_data.highest_floor if PlayerManager.player_data != null else 1

	zone_label.text = "%dF - %s" % [safe_floor, _get_safe_zone_name(safe_floor)]

	var zone_id := _get_zone_id_for_floor(safe_floor)
	if ThemeConstantsClass.ZONE_AMBIENT.has(zone_id):
		var accent: Color = ThemeConstantsClass.ZONE_AMBIENT[zone_id].get("accent", ThemeConstantsClass.ACCENT)
		zone_label.add_theme_color_override("font_color", accent)

		var panel_bg := StyleBoxFlat.new()
		var tint: Color = ThemeConstantsClass.ZONE_AMBIENT[zone_id].get("bg", ThemeConstantsClass.PANEL_BG)
		panel_bg.bg_color = tint
		panel_bg.border_color = accent.darkened(0.5)
		panel_bg.border_width_left = 1
		panel_bg.border_width_top = 1
		panel_bg.border_width_right = 1
		panel_bg.border_width_bottom = 1
		panel_bg.corner_radius_top_left = 8
		panel_bg.corner_radius_top_right = 8
		panel_bg.corner_radius_bottom_right = 8
		panel_bg.corner_radius_bottom_left = 8
		panel_bg.content_margin_left = 12.0
		panel_bg.content_margin_top = 10.0
		panel_bg.content_margin_right = 12.0
		panel_bg.content_margin_bottom = 10.0
		status_panel.add_theme_stylebox_override("panel", panel_bg)

	var next_floor: int = _get_next_explore_floor(safe_floor)
	if next_floor > 0 and next_floor <= 100:
		explore_button.text = "探索 %dF" % next_floor
		explore_button.disabled = false
	else:
		explore_button.text = "已通關所有樓層"
		explore_button.disabled = true

	var teleports: Array = []
	if PlayerManager.player_data != null:
		teleports = PlayerManager.player_data.unlocked_teleports.duplicate()
	teleport_button.disabled = teleports.size() <= 1
	teleport_panel.visible = false

	_update_status()

	if QuestManager != null:
		QuestManager.check_auto_main_quests(current_safe_floor)


func _update_status() -> void:
	if PlayerManager.player_data == null:
		return

	var pd = PlayerManager.player_data

	player_name_label.text = "Lv.%d  %s" % [pd.level, pd.name]

	var max_hp: int = PlayerManager.get_max_hp()
	var max_mp: int = PlayerManager.get_max_mp()
	hp_bar.max_value = max_hp
	hp_bar.value = pd.current_hp
	hp_value.text = "%d/%d" % [pd.current_hp, max_hp]
	mp_bar.max_value = max_mp
	mp_bar.value = pd.current_mp
	mp_value.text = "%d/%d" % [pd.current_mp, max_mp]

	gold_label.text = "金幣: %d" % pd.gold
	title_status_label.text = "稱號: %s" % String(pd.title)
	familiar_label.text = "使魔: %s" % _get_active_familiar_status()
	floor_label.text = "最高樓層: %dF" % pd.highest_floor

	_update_equip_summary()


func _update_equip_summary() -> void:
	equip_summary.clear()
	var pd = PlayerManager.player_data
	if pd == null:
		return

	equip_summary.push_color(ThemeConstantsClass.TEXT_SECONDARY)
	equip_summary.push_font_size(ThemeConstantsClass.FONT_SIZE_SMALL)

	var weapon_name: String = "無"
	if not pd.weapon_id.is_empty():
		var w_data: Dictionary = DataManager.get_item(pd.weapon_id)
		weapon_name = String(w_data.get("name", pd.weapon_id))
	equip_summary.append_text("武器: %s\n" % weapon_name)

	var armor_name: String = "無"
	if not pd.armor_id.is_empty():
		var a_data: Dictionary = DataManager.get_item(pd.armor_id)
		armor_name = String(a_data.get("name", pd.armor_id))
	equip_summary.append_text("防具: %s" % armor_name)

	equip_summary.pop()
	equip_summary.pop()


func _on_explore_pressed() -> void:
	var next_floor: int = _get_next_explore_floor(current_safe_floor)
	if next_floor > 0:
		if get_signal_connection_list("explore_requested").is_empty():
			if GameManager != null:
				GameManager.start_exploration(next_floor)
			return
		explore_requested.emit(next_floor)


func _center_panel(panel: Control) -> void:
	var vp_size := get_viewport_rect().size
	panel.position = (vp_size - panel.custom_minimum_size) / 2.0


func _on_inventory_pressed() -> void:
	if _has_open_panel():
		return

	_inventory_panel = InventoryPanelClass.new()
	add_child(_inventory_panel)
	_inventory_panel.setup(InventoryPanelClass.Mode.SAFE_ZONE)
	_center_panel(_inventory_panel)
	_inventory_panel.panel_closed.connect(_close_inventory_panel)
	_inventory_panel.item_action_performed.connect(_on_inventory_action)


func _close_inventory_panel() -> void:
	if _inventory_panel != null:
		_inventory_panel.queue_free()
	_inventory_panel = null
	_update_status()


func _on_inventory_action(_item_id: String, _action: String) -> void:
	_update_status()


func _on_shop_pressed() -> void:
	if _has_open_panel():
		return

	_shop_panel = ShopPanelClass.new()
	add_child(_shop_panel)
	_shop_panel.setup(current_safe_floor)
	_center_panel(_shop_panel)
	_shop_panel.panel_closed.connect(_close_shop_panel)
	_shop_panel.transaction_completed.connect(_on_shop_transaction)


func _close_shop_panel() -> void:
	if _shop_panel != null:
		_shop_panel.queue_free()
	_shop_panel = null
	_update_status()


func _on_shop_transaction(_item_id: String, _action: String) -> void:
	_update_status()


func _on_forge_pressed() -> void:
	if _has_open_panel():
		return

	_forge_panel = ForgePanelClass.new()
	add_child(_forge_panel)
	_forge_panel.setup(current_safe_floor)
	_center_panel(_forge_panel)
	_forge_panel.panel_closed.connect(_close_forge_panel)
	_forge_panel.forge_action_performed.connect(_on_forge_action)


func _close_forge_panel() -> void:
	if _forge_panel != null:
		_forge_panel.queue_free()
	_forge_panel = null
	_update_status()


func _on_forge_action(_action: String, _detail: String) -> void:
	_update_status()


func _on_familiar_pressed() -> void:
	if _has_open_panel():
		return

	_familiar_house_panel = FamiliarHousePanelClass.new()
	add_child(_familiar_house_panel)
	_familiar_house_panel.setup()
	_center_panel(_familiar_house_panel)
	_familiar_house_panel.panel_closed.connect(_close_familiar_panel)
	_familiar_house_panel.familiar_action_performed.connect(_on_familiar_action)


func _close_familiar_panel() -> void:
	if _familiar_house_panel != null:
		_familiar_house_panel.queue_free()
	_familiar_house_panel = null
	_update_status()


func _on_familiar_action(_action: String, _detail: String) -> void:
	_update_status()


func _on_library_pressed() -> void:
	if _has_open_panel():
		return

	_library_panel = LibraryPanelClass.new()
	add_child(_library_panel)
	_library_panel.setup()
	_center_panel(_library_panel)
	_library_panel.panel_closed.connect(_close_library_panel)


func _close_library_panel() -> void:
	if _library_panel != null:
		_library_panel.queue_free()
	_library_panel = null


func _on_tavern_pressed() -> void:
	if _has_open_panel():
		return

	_tavern_panel = TavernPanelClass.new()
	add_child(_tavern_panel)
	_tavern_panel.setup(current_safe_floor)
	_center_panel(_tavern_panel)
	_tavern_panel.panel_closed.connect(_close_tavern_panel)
	_tavern_panel.quest_action_performed.connect(_on_tavern_action)


func _close_tavern_panel() -> void:
	if _tavern_panel != null:
		_tavern_panel.queue_free()
	_tavern_panel = null
	_update_status()


func _on_tavern_action(_action: String, _detail: String) -> void:
	_update_status()


func _on_teleport_pressed() -> void:
	for child in teleport_list.get_children():
		child.queue_free()

	var teleports: Array = []
	if PlayerManager.player_data != null:
		teleports = PlayerManager.player_data.unlocked_teleports.duplicate()

	for raw_floor in teleports:
		var tp_floor: int = int(raw_floor)
		if tp_floor == current_safe_floor:
			continue
		var button := Button.new()
		button.text = "%dF - %s" % [tp_floor, _get_safe_zone_name(tp_floor)]
		button.custom_minimum_size.y = 40.0
		var target_floor: int = tp_floor
		button.pressed.connect(func():
			teleport_panel.visible = false
			if get_signal_connection_list("teleport_requested").is_empty():
				if GameManager != null:
					GameManager.go_to_safe_zone(target_floor)
				return
			teleport_requested.emit(target_floor)
		)
		teleport_list.add_child(button)

	teleport_panel.visible = true


func _request_rest() -> void:
	if QuestManager != null:
		QuestManager.refresh_bounty_board(current_safe_floor)
		QuestManager.check_auto_main_quests(current_safe_floor)
	if get_signal_connection_list("rest_requested").is_empty():
		if PlayerManager.player_data != null:
			PlayerManager.player_data.current_hp = PlayerManager.get_max_hp()
			PlayerManager.player_data.current_mp = PlayerManager.get_max_mp()
			PlayerManager.player_hp_changed.emit(PlayerManager.player_data.current_hp, PlayerManager.get_max_hp())
			PlayerManager.player_mp_changed.emit(PlayerManager.player_data.current_mp, PlayerManager.get_max_mp())
		_update_status()
		return
	rest_requested.emit()


func _request_save() -> void:
	if get_signal_connection_list("save_requested").is_empty():
		SaveManager.save_game(1)
		_update_status()
		return
	save_requested.emit()


func _get_next_explore_floor(safe_floor: int) -> int:
	var candidate: int = safe_floor + 1
	if safe_floor == 1:
		candidate = 2

	if candidate > highest_floor:
		candidate = highest_floor

	while _is_safe_floor(candidate) and candidate <= 100:
		candidate += 1

	if candidate > 100:
		return -1

	return candidate


func _is_safe_floor(floor_number: int) -> bool:
	var config: Dictionary = DataManager.get_floor_config()
	var safe_floors: Array = Array(config.get("safe_floors", []))
	for raw_floor in safe_floors:
		if int(raw_floor) == floor_number:
			return true
	return false


func _has_open_panel() -> bool:
	return _inventory_panel != null or _shop_panel != null or _forge_panel != null \
		or _familiar_house_panel != null or _library_panel != null or _tavern_panel != null


func _get_active_familiar_status() -> String:
	var active_familiar: Dictionary = PlayerManager.get_active_familiar()
	if active_familiar.is_empty():
		return "無"

	var familiar_data: Dictionary = DataManager.get_familiar(String(active_familiar.get("id", "")))
	var base_name: String = String(familiar_data.get("name", active_familiar.get("id", "???")))
	var nickname: String = String(active_familiar.get("nickname", "")).strip_edges()
	if nickname.is_empty():
		return base_name
	return "%s（%s）" % [nickname, base_name]


static func _get_safe_zone_name(floor_number: int) -> String:
	match floor_number:
		1:
			return "黎明之城"
		10:
			return "冒險者前哨站"
		20:
			return "冰原營地"
		30:
			return "風之驛站"
		40:
			return "地底市集"
		50:
			return "中層都市"
		60:
			return "暗之避難所"
		70:
			return "雷霆要塞"
		80:
			return "聖域"
		90:
			return "最後營地"
		_:
			return "安全區"


static func _get_zone_id_for_floor(floor_number: int) -> String:
	if floor_number <= 10:
		return "zone1"
	elif floor_number <= 20:
		return "zone2"
	elif floor_number <= 30:
		return "zone3"
	elif floor_number <= 40:
		return "zone4"
	elif floor_number <= 50:
		return "zone5"
	elif floor_number <= 60:
		return "zone6"
	elif floor_number <= 70:
		return "zone7"
	elif floor_number <= 80:
		return "zone8"
	elif floor_number <= 90:
		return "zone9"
	else:
		return "zone10"
