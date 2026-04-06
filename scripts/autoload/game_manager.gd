extends Node

const ThemeBuilderClass = preload("res://scripts/ui/theme_builder.gd")
const ThemeConstantsClass = preload("res://scripts/ui/theme_constants.gd")
const DrawShapeClass = preload("res://scripts/ui/draw_shape.gd")
const CombatantDataClass = preload("res://scripts/data/combatant_data.gd")

enum GameState { TITLE, SAFE_ZONE, EXPLORATION, BATTLE, CUTSCENE }

signal state_changed(old_state: int, new_state: int)
signal game_paused
signal game_resumed

var current_state: int = -1
var is_paused := false


func _ready() -> void:
	ThemeBuilderClass.ensure_theme_resource()
	DataManager.load_all_data()
	_test_data_loading()
	_test_theme()
	_test_player_system()
	_test_battle_framework()
	change_state(GameState.TITLE)


func change_state(new_state: GameState) -> void:
	if current_state == new_state:
		return

	var old_state := current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)


func pause_game() -> void:
	if is_paused:
		return

	is_paused = true
	get_tree().paused = true
	game_paused.emit()


func resume_game() -> void:
	if not is_paused:
		return

	is_paused = false
	get_tree().paused = false
	game_resumed.emit()


func quit_game() -> void:
	resume_game()
	get_tree().quit()


func _test_data_loading() -> void:
	print("=== Data Loading Test ===")

	var fireball := DataManager.get_skill("skill_fireball")
	print("Fireball loaded: ", fireball.get("name", "FAILED"))

	var fire_sprite := DataManager.get_enemy("enemy_fire_sprite")
	print("Fire Sprite loaded: ", fire_sprite.get("name", "FAILED"))

	var hp_potion := DataManager.get_item("item_hp_potion_s")
	print("HP Potion loaded: ", hp_potion.get("name", "FAILED"))

	var fire_imp := DataManager.get_familiar("familiar_fire_imp")
	print("Fire Imp loaded: ", fire_imp.get("name", "FAILED"))

	var magic_circle := DataManager.get_event("event_magic_circle")
	print("Magic Circle loaded: ", magic_circle.get("name", "FAILED"))

	var fire_skills := DataManager.get_skills_by_element("fire")
	print("Fire skills count: ", fire_skills.size())

	var floor_5_enemies := DataManager.get_enemies_by_floor(5)
	print("Floor 5 enemies count: ", floor_5_enemies.size())

	print("=== End Test ===")


func _test_theme() -> void:
	print("=== Theme Test ===")

	var theme := ThemeBuilderClass.build_theme()
	print("Theme styleboxes: Panel=", theme.has_stylebox("panel", "Panel"))
	print("Theme styleboxes: Button normal=", theme.has_stylebox("normal", "Button"))
	print("Theme colors: Label font=", theme.get_color("font_color", "Label"))
	print("Element color fire=", ThemeConstantsClass.get_element_color("fire"))
	print("Rarity border SR=", ThemeConstantsClass.get_rarity_border("SR"))

	var triangle := DrawShapeClass.get_regular_polygon(Vector2.ZERO, 24.0, 3)
	print("Triangle points: ", triangle.size())

	var star := DrawShapeClass.get_star(Vector2.ZERO, 24.0, 12.0, 5)
	print("Star points: ", star.size())

	var player_shape := DrawShapeClass.get_player_shape(Vector2.ZERO, 24.0)
	var outline_points = player_shape.get("outline", PackedVector2Array())
	print("Player outline points: ", outline_points.size())

	var enemy_data := DataManager.get_enemy("enemy_fire_sprite")
	if enemy_data.has("visual"):
		var fire_sprite_shape := DrawShapeClass.get_shape_from_data(Vector2.ZERO, enemy_data["visual"])
		print("Fire Sprite shape points: ", fire_sprite_shape.size())

	print("=== End Theme Test ===")


func _test_player_system() -> void:
	print("=== Player System Test ===")

	PlayerManager.init_new_game()
	print("Initial MATK (base only): ", PlayerManager.get_matk())

	PlayerManager.equip_weapon("weapon_apprentice_staff")
	print("MATK with staff: ", PlayerManager.get_matk())

	PlayerManager.equip_armor("armor_apprentice_robe")
	print("Max HP with robe: ", PlayerManager.get_max_hp())
	print("MDEF with staff + robe: ", PlayerManager.get_mdef())

	PlayerManager.equip_accessory("acc_burn_ring", 0)
	print("MATK with ring: ", PlayerManager.get_matk())

	PlayerManager.add_buff("matk", 10, 3, "test_buff")
	print("MATK with buff: ", PlayerManager.get_matk())
	PlayerManager.tick_buffs()
	PlayerManager.tick_buffs()
	PlayerManager.tick_buffs()
	print("MATK after buff expired: ", PlayerManager.get_matk())

	var old_matk := PlayerManager.player_data.base_matk
	PlayerManager.add_exp(100)
	print("Level after 100 exp: ", PlayerManager.player_data.level)
	print("Base MATK grew: ", old_matk, " -> ", PlayerManager.player_data.base_matk)

	var returned := PlayerManager.unequip_weapon()
	print("Unequipped: ", returned)
	print("MATK after unequip: ", PlayerManager.get_matk())

	var save := PlayerManager.to_save_dict()
	PlayerManager.init_new_game()
	PlayerManager.load_from_save(save)
	print("After reload level: ", PlayerManager.player_data.level)

	PlayerManager.clear_buffs()
	PlayerManager.init_new_game()
	print("=== End Player System Test ===")


func _test_battle_framework() -> void:
	print("=== Battle Framework Test ===")

	PlayerManager.init_new_game()

	var battle_scene := load("res://scenes/battle/battle.tscn") as PackedScene
	if battle_scene != null:
		var battle_instance := battle_scene.instantiate()
		battle_instance.free()

	var player_combatant := CombatantDataClass.from_player()
	print("Player combatant: %s HP=%d/%d MATK=%d" % [
		player_combatant.display_name,
		player_combatant.current_hp,
		player_combatant.max_hp,
		player_combatant.matk,
	])

	var enemy_combatant := CombatantDataClass.from_enemy("enemy_fire_sprite")
	print("Enemy combatant: %s HP=%d/%d MATK=%d element=%s" % [
		enemy_combatant.display_name,
		enemy_combatant.current_hp,
		enemy_combatant.max_hp,
		enemy_combatant.matk,
		enemy_combatant.element,
	])

	var familiar_combatant := CombatantDataClass.from_familiar("familiar_fire_imp", 5)
	print("Familiar combatant: %s HP=%d/%d MATK=%d (Lv.5)" % [
		familiar_combatant.display_name,
		familiar_combatant.current_hp,
		familiar_combatant.max_hp,
		familiar_combatant.matk,
	])

	var all_combatants: Array = []
	all_combatants.append(player_combatant)
	all_combatants.append(enemy_combatant)
	all_combatants.append(familiar_combatant)

	var alive_count := 0
	for combatant in all_combatants:
		if combatant.is_alive:
			alive_count += 1
	print("All alive: ", alive_count)

	enemy_combatant.current_hp = 0
	enemy_combatant.is_alive = false

	alive_count = 0
	for combatant in all_combatants:
		if combatant.is_alive:
			alive_count += 1
	print("After enemy defeated, alive: ", alive_count)

	print("=== End Battle Framework Test ===")
