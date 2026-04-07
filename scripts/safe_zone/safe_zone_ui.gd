class_name SafeZoneUI
extends Control

const ThemeConstantsClass = preload("res://scripts/ui/theme_constants.gd")
const InventoryPanelClass = preload("res://scripts/ui/inventory_panel.gd")
const ShopPanelClass = preload("res://scripts/safe_zone/shop_panel.gd")
const ForgePanelClass = preload("res://scripts/safe_zone/forge_panel.gd")

signal explore_requested(floor_number: int)
signal teleport_requested(floor_number: int)
signal rest_requested
signal save_requested

var current_safe_floor: int = 1
var highest_floor: int = 1
var _inventory_panel = null
var _shop_panel = null
var _forge_panel = null

@onready var zone_label: Label = $ZoneLabel
@onready var status_label: RichTextLabel = $StatusPanel/StatusLabel
@onready var inventory_button: Button = $ActionContainer/InventoryButton
@onready var shop_button: Button = $ActionContainer/ShopButton
@onready var forge_button: Button = $ActionContainer/ForgeButton
@onready var explore_button: Button = $ActionContainer/ExploreButton
@onready var teleport_button: Button = $ActionContainer/TeleportButton
@onready var rest_button: Button = $ActionContainer/RestButton
@onready var save_button: Button = $ActionContainer/SaveButton
@onready var teleport_panel: PanelContainer = $TeleportPanel
@onready var teleport_list: VBoxContainer = $TeleportPanel/Content/TeleportList
@onready var teleport_close_button: Button = $TeleportPanel/Content/CloseButton


func _ready() -> void:
	inventory_button.pressed.connect(_on_inventory_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	forge_button.pressed.connect(_on_forge_pressed)
	explore_button.pressed.connect(_on_explore_pressed)
	teleport_button.pressed.connect(_on_teleport_pressed)
	rest_button.pressed.connect(func(): rest_requested.emit())
	save_button.pressed.connect(func(): save_requested.emit())
	teleport_close_button.pressed.connect(func(): teleport_panel.visible = false)
	teleport_panel.visible = false


func setup(safe_floor: int) -> void:
	current_safe_floor = safe_floor
	highest_floor = PlayerManager.player_data.highest_floor if PlayerManager.player_data != null else 1

	var zone_name: String = _get_safe_zone_name(safe_floor)
	zone_label.text = "%dF - %s" % [safe_floor, zone_name]

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


func _update_status() -> void:
	if PlayerManager.player_data == null:
		return

	var pd = PlayerManager.player_data
	status_label.clear()
	status_label.push_color(ThemeConstantsClass.TEXT_PRIMARY)
	status_label.append_text("Lv.%d  %s\n" % [pd.level, pd.name])
	status_label.append_text("HP: %d/%d\n" % [pd.current_hp, PlayerManager.get_max_hp()])
	status_label.append_text("MP: %d/%d\n" % [pd.current_mp, PlayerManager.get_max_mp()])
	status_label.append_text("Gold: %d\n" % pd.gold)
	status_label.append_text("最高樓層: %dF" % pd.highest_floor)
	status_label.pop()


func _on_explore_pressed() -> void:
	var next_floor: int = _get_next_explore_floor(current_safe_floor)
	if next_floor > 0:
		explore_requested.emit(next_floor)


func _on_inventory_pressed() -> void:
	if _inventory_panel != null or _shop_panel != null or _forge_panel != null:
		return

	_inventory_panel = InventoryPanelClass.new()
	_inventory_panel.position = Vector2(80, 40)
	add_child(_inventory_panel)
	_inventory_panel.setup(InventoryPanelClass.Mode.SAFE_ZONE)
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
	if _shop_panel != null or _inventory_panel != null or _forge_panel != null:
		return

	_shop_panel = ShopPanelClass.new()
	_shop_panel.position = Vector2(60, 30)
	add_child(_shop_panel)
	_shop_panel.setup(current_safe_floor)
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
	if _forge_panel != null or _inventory_panel != null or _shop_panel != null:
		return

	_forge_panel = ForgePanelClass.new()
	_forge_panel.position = Vector2(60, 30)
	add_child(_forge_panel)
	_forge_panel.setup(current_safe_floor)
	_forge_panel.panel_closed.connect(_close_forge_panel)
	_forge_panel.forge_action_performed.connect(_on_forge_action)


func _close_forge_panel() -> void:
	if _forge_panel != null:
		_forge_panel.queue_free()
	_forge_panel = null
	_update_status()


func _on_forge_action(_action: String, _detail: String) -> void:
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
			teleport_requested.emit(target_floor)
		)
		teleport_list.add_child(button)

	teleport_panel.visible = true


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
