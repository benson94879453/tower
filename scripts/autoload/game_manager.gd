extends Node

const ThemeBuilderClass = preload("res://scripts/ui/theme_builder.gd")
const ThemeConstantsClass = preload("res://scripts/ui/theme_constants.gd")
const DrawShapeClass = preload("res://scripts/ui/draw_shape.gd")
const CombatantDataClass = preload("res://scripts/data/combatant_data.gd")
const DamageCalculatorClass = preload("res://scripts/battle/damage_calculator.gd")
const SkillExecutorClass = preload("res://scripts/battle/skill_executor.gd")
const StatusProcessorClass = preload("res://scripts/battle/status_processor.gd")
const BattleAIClass = preload("res://scripts/battle/battle_ai.gd")
const BattleResultClass = preload("res://scripts/battle/battle_result.gd")
const TurnManagerScript = preload("res://scripts/battle/turn_manager.gd")
const InventoryClass = preload("res://scripts/data/inventory.gd")
const InventoryPanelClass = preload("res://scripts/ui/inventory_panel.gd")
const ShopPanelClass = preload("res://scripts/safe_zone/shop_panel.gd")
const ForgeLogicClass = preload("res://scripts/safe_zone/forge_logic.gd")
const ForgePanelClass = preload("res://scripts/safe_zone/forge_panel.gd")
const FloorGeneratorClass = preload("res://scripts/exploration/floor_generator.gd")
const NodeHandlerClass = preload("res://scripts/exploration/node_handler.gd")

enum GameState { TITLE, SAFE_ZONE, EXPLORATION, BATTLE, CUTSCENE }

signal state_changed(old_state: int, new_state: int)
signal game_paused
signal game_resumed

var current_state: int = -1
var is_paused := false
var _exploration_state: Dictionary = {}


func _ready() -> void:
	ThemeBuilderClass.ensure_theme_resource()
	DataManager.load_all_data()
	_test_data_loading()
	_test_theme()
	_test_player_system()
	_test_battle_framework()
	_test_turn_manager()
	_test_damage_calculator()
	_test_skill_executor()
	_test_status_processor()
	_test_battle_ai()
	_test_battle_result()
	_test_floor_generator()
	_test_node_handler()
	_test_inventory()
	_test_inventory_panel()
	_test_shop()
	_test_forge()
	_test_craft_synthesis()
	_test_game_flow()
	if false:
		_test_full_battle()
	change_state(GameState.TITLE)
	_go_to_title()


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


func start_new_game() -> void:
	PlayerManager.init_new_game()
	if not PlayerManager.player_data.unlocked_teleports.has(1):
		PlayerManager.player_data.unlocked_teleports.append(1)
	go_to_safe_zone(1)


func load_saved_game(slot: int) -> void:
	SaveManager.load_game(slot)
	var safe_floor: int = _get_nearest_safe_floor(PlayerManager.player_data.highest_floor)
	go_to_safe_zone(safe_floor)


func go_to_safe_zone(safe_floor: int) -> void:
	change_state(GameState.SAFE_ZONE)
	PlayerManager.heal_all_familiars()
	await SceneManager.change_scene("res://scenes/safe_zone/safe_zone.tscn")

	var scene = SceneManager.get_current_scene()
	if scene != null:
		if scene.has_method("setup"):
			scene.setup(safe_floor)
		if scene.has_signal("explore_requested"):
			scene.explore_requested.connect(_on_explore_requested, CONNECT_ONE_SHOT)
		if scene.has_signal("teleport_requested"):
			scene.teleport_requested.connect(_on_teleport_requested, CONNECT_ONE_SHOT)
		if scene.has_signal("rest_requested"):
			scene.rest_requested.connect(_on_rest_requested.bind(safe_floor), CONNECT_ONE_SHOT)
		if scene.has_signal("save_requested"):
			scene.save_requested.connect(_on_save_requested.bind(safe_floor), CONNECT_ONE_SHOT)
		if scene.has_signal("save_slot_requested"):
			scene.save_slot_requested.connect(_on_save_slot_requested, CONNECT_ONE_SHOT)

	SaveManager.auto_save()


func start_exploration(floor_number: int) -> void:
	change_state(GameState.EXPLORATION)
	await SceneManager.change_scene("res://scenes/exploration/exploration.tscn")

	var scene = SceneManager.get_current_scene()
	if scene != null and scene.has_method("enter_floor"):
		if scene.has_signal("floor_entered"):
			scene.floor_entered.connect(_on_floor_entered, CONNECT_ONE_SHOT)
		if scene.has_signal("floor_completed"):
			scene.floor_completed.connect(_on_floor_completed, CONNECT_ONE_SHOT)
		if scene.has_signal("exploration_ended"):
			scene.exploration_ended.connect(_on_exploration_ended, CONNECT_ONE_SHOT)
		scene.enter_floor(floor_number)


func advance_to_next_floor(completed_floor: int) -> void:
	var next_floor: int = completed_floor + 1
	var safe_floors: Array = _get_safe_floors()

	if safe_floors.has(next_floor):
		go_to_safe_zone(next_floor)
	elif next_floor > 100:
		go_to_safe_zone(90)
	else:
		start_exploration(next_floor)


func start_exploration_battle(enemy_ids: Array, config: Dictionary, exploration_state: Dictionary) -> void:
	_exploration_state = exploration_state.duplicate(true)
	change_state(GameState.BATTLE)
	await SceneManager.change_scene("res://scenes/battle/battle.tscn")

	var battle_scene = SceneManager.get_current_scene()
	if battle_scene != null and battle_scene.has_method("start_battle"):
		battle_scene.battle_ended.connect(_on_exploration_battle_ended, CONNECT_ONE_SHOT)
		battle_scene.start_battle(enemy_ids, config)


func _on_exploration_battle_ended(result: String) -> void:
	_exploration_state["battle_result"] = result
	change_state(GameState.EXPLORATION)
	await SceneManager.change_scene("res://scenes/exploration/exploration.tscn")

	var scene = SceneManager.get_current_scene()
	if scene != null:
		if scene.has_signal("floor_completed"):
			scene.floor_completed.connect(_on_floor_completed, CONNECT_ONE_SHOT)
		if scene.has_signal("exploration_ended"):
			scene.exploration_ended.connect(_on_exploration_ended, CONNECT_ONE_SHOT)
		if scene.has_method("restore_state"):
			scene.restore_state(_exploration_state)

	_exploration_state.clear()


func _on_explore_requested(floor_number: int) -> void:
	start_exploration(floor_number)


func _on_floor_entered(floor_number: int) -> void:
	if QuestManager != null:
		QuestManager.on_floor_reached(floor_number)


func _on_teleport_requested(floor_number: int) -> void:
	go_to_safe_zone(floor_number)


func _on_rest_requested(safe_floor: int) -> void:
	if PlayerManager.player_data != null:
		PlayerManager.player_data.current_hp = PlayerManager.get_max_hp()
		PlayerManager.player_data.current_mp = PlayerManager.get_max_mp()
		PlayerManager.player_hp_changed.emit(PlayerManager.player_data.current_hp, PlayerManager.get_max_hp())
		PlayerManager.player_mp_changed.emit(PlayerManager.player_data.current_mp, PlayerManager.get_max_mp())
	PlayerManager.heal_all_familiars()
	go_to_safe_zone(safe_floor)


func _on_save_requested(safe_floor: int) -> void:
	SaveManager.save_game(1)
	go_to_safe_zone(safe_floor)


func _on_save_slot_requested(slot: int) -> void:
	SaveManager.save_game(slot)
	if PlayerManager.player_data != null:
		var safe_floor: int = _get_nearest_safe_floor(PlayerManager.player_data.highest_floor)
		go_to_safe_zone(safe_floor)


func _on_floor_completed(floor_number: int) -> void:
	if PlayerManager.player_data != null and _is_boss_floor(floor_number):
		if not PlayerManager.player_data.defeated_bosses.has(floor_number):
			PlayerManager.player_data.defeated_bosses.append(floor_number)
	if PlayerManager.player_data != null:
		PlayerManager.check_title_unlocks()
	advance_to_next_floor(floor_number)


func _on_exploration_ended(_reason: String) -> void:
	var safe_floor: int = _get_nearest_safe_floor(
		PlayerManager.player_data.highest_floor if PlayerManager.player_data != null else 1
	)
	go_to_safe_zone(safe_floor)


func _setup_title_scene() -> void:
	var scene = SceneManager.get_current_scene()
	if scene == null:
		return
	if scene.has_signal("new_game_requested"):
		scene.new_game_requested.connect(start_new_game, CONNECT_ONE_SHOT)
	if scene.has_signal("load_game_requested"):
		scene.load_game_requested.connect(load_saved_game, CONNECT_ONE_SHOT)
	if scene.has_signal("quit_requested"):
		scene.quit_requested.connect(quit_game, CONNECT_ONE_SHOT)


func _go_to_title() -> void:
	await SceneManager.change_scene("res://scenes/title/title.tscn")
	_setup_title_scene()


func _get_nearest_safe_floor(current_floor: int) -> int:
	var safe_floors: Array = _get_safe_floors()
	var best: int = 1
	for raw_floor in safe_floors:
		var safe_floor: int = int(raw_floor)
		if safe_floor <= current_floor and safe_floor > best:
			best = safe_floor
	return best


func _get_safe_floors() -> Array:
	var config: Dictionary = DataManager.get_floor_config()
	var raw_safe_floors: Array = Array(config.get("safe_floors", [1]))
	var safe_floors: Array = []
	for raw_floor in raw_safe_floors:
		safe_floors.append(int(raw_floor))
	return safe_floors


func _is_boss_floor(floor_number: int) -> bool:
	var zones: Dictionary = Dictionary(DataManager.get_floor_config().get("zones", {}))
	for raw_zone in zones.values():
		var zone: Dictionary = Dictionary(raw_zone)
		if int(zone.get("boss_floor", -1)) == floor_number:
			return true
	return false


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


func _test_turn_manager() -> void:
	print("=== Turn Manager Test ===")

	PlayerManager.init_new_game()
	PlayerManager.learn_skill("skill_fireball")
	PlayerManager.equip_active_skill("skill_fireball", 0)
	PlayerManager.learn_skill("skill_spark")
	PlayerManager.equip_active_skill("skill_spark", 1)

	var player_combatant := CombatantDataClass.from_player()
	var enemy_combatant := CombatantDataClass.from_enemy("enemy_fire_sprite")
	var familiar_combatant := CombatantDataClass.from_familiar("familiar_fire_imp", 3)

	var combatants: Array = [player_combatant, enemy_combatant, familiar_combatant]
	combatants.sort_custom(func(a, b): return TurnManagerScript._compare_speed(a, b))
	print("Speed order: %s(%d), %s(%d), %s(%d)" % [
		combatants[0].display_name, combatants[0].speed,
		combatants[1].display_name, combatants[1].speed,
		combatants[2].display_name, combatants[2].speed,
	])

	print("Player speed: %d, Enemy speed: %d" % [player_combatant.speed, enemy_combatant.speed])
	print("Flee bonus: %s" % ("speed < enemy -> -10%" if player_combatant.speed < enemy_combatant.speed else "+20%"))

	print("Player skill_fireball PP: %d" % int(player_combatant.skill_pp.get("skill_fireball", -1)))
	print("Player skill_spark PP: %d" % int(player_combatant.skill_pp.get("skill_spark", -1)))
	print("Enemy skill_spark PP: %d" % int(enemy_combatant.skill_pp.get("skill_spark", -1)))
	print("Enemy skill_flame_shot PP: %d" % int(enemy_combatant.skill_pp.get("skill_flame_shot", -1)))

	PlayerManager.init_new_game()
	print("=== End Turn Manager Test ===")


func _test_damage_calculator() -> void:
	print("=== Damage Calculator Test ===")

	print("fire vs wind: ", DamageCalculatorClass.get_element_multiplier("fire", "wind"))
	print("fire vs water: ", DamageCalculatorClass.get_element_multiplier("fire", "water"))
	print("fire vs fire: ", DamageCalculatorClass.get_element_multiplier("fire", "fire"))
	print("light vs dark: ", DamageCalculatorClass.get_element_multiplier("light", "dark"))
	print("none vs fire: ", DamageCalculatorClass.get_element_multiplier("none", "fire"))
	print("fire vs ice(norm): ", DamageCalculatorClass.get_element_multiplier("fire", "ice"))

	print("normalize ice: ", DamageCalculatorClass.normalize_element("ice"))
	print("normalize xyz: ", DamageCalculatorClass.normalize_element("xyz"))
	print("normalize fire: ", DamageCalculatorClass.normalize_element("fire"))

	print("fire in fire env: ", DamageCalculatorClass.get_environment_modifier("fire", "fire"))
	print("water in fire env: ", DamageCalculatorClass.get_environment_modifier("water", "fire"))
	print("thunder in fire env: ", DamageCalculatorClass.get_environment_modifier("thunder", "fire"))
	print("fire in none env: ", DamageCalculatorClass.get_environment_modifier("fire", "none"))

	print("effectiveness 2.0: ", DamageCalculatorClass.get_effectiveness_text(2.0))
	print("effectiveness 0.5: ", DamageCalculatorClass.get_effectiveness_text(0.5))
	print("effectiveness 1.0: ", DamageCalculatorClass.get_effectiveness_text(1.0))

	PlayerManager.init_new_game()
	PlayerManager.learn_skill("skill_fireball")
	PlayerManager.equip_active_skill("skill_fireball", 0)

	var player_combatant := CombatantDataClass.from_player()
	var enemy_combatant := CombatantDataClass.from_enemy("enemy_fire_sprite")
	var fireball_data := DataManager.get_skill("skill_fireball")

	var total_damage := 0
	var hit_count := 0
	var crit_count := 0
	for _index in range(100):
		var calc_result := DamageCalculatorClass.calculate_damage(
			player_combatant,
			enemy_combatant,
			fireball_data,
			"none"
		)
		if bool(calc_result.get("is_hit", false)):
			total_damage += int(calc_result.get("damage", 0))
			hit_count += 1
			if bool(calc_result.get("is_crit", false)):
				crit_count += 1

	var avg_damage: float = float(total_damage) / max(float(hit_count), 1.0)
	print("Fireball vs Fire Sprite (100 trials): avg_dmg=%.1f hits=%d crits=%d" % [
		avg_damage,
		hit_count,
		crit_count,
	])
	print("  element_multi=0.5, expected_avg≈28-37")

	var wind_enemy := CombatantDataClass.from_enemy("enemy_fire_sprite")
	wind_enemy.element = "wind"
	var result_super := DamageCalculatorClass.calculate_damage(player_combatant, wind_enemy, fireball_data, "none")
	print("Fireball vs Wind enemy: hit=%s dmg=%d effectiveness='%s'" % [
		result_super.get("is_hit", false),
		int(result_super.get("damage", 0)),
		String(result_super.get("effectiveness_text", "")),
	])

	var result_env := DamageCalculatorClass.calculate_damage(player_combatant, wind_enemy, fireball_data, "fire")
	print("Fireball vs Wind in fire env: hit=%s dmg=%d env_mod=%.1f" % [
		result_env.get("is_hit", false),
		int(result_env.get("damage", 0)),
		float(result_env.get("environment_mod", 1.0)),
	])

	var accuracy_enemy := CombatantDataClass.from_enemy("enemy_fire_sprite")
	accuracy_enemy.dodge = 50.0
	player_combatant.status_effects.clear()
	seed(424242)
	var baseline_hits := 0
	for _index in range(5000):
		if DamageCalculatorClass.calc_hit(player_combatant, accuracy_enemy, fireball_data):
			baseline_hits += 1
	player_combatant.status_effects.append({"id": "hit_down", "turns": 3})
	seed(424242)
	var debuffed_hits := 0
	for _index in range(5000):
		if DamageCalculatorClass.calc_hit(player_combatant, accuracy_enemy, fireball_data):
			debuffed_hits += 1
	print("Fireball hit rate vs dodge=50: baseline=%.3f hit_down=%.3f" % [
		float(baseline_hits) / 5000.0,
		float(debuffed_hits) / 5000.0,
	])

	print("Stat helper matk: ", DamageCalculatorClass.get_effective_stat(player_combatant, "matk"))

	PlayerManager.init_new_game()
	print("=== End Damage Calculator Test ===")


func _test_skill_executor() -> void:
	print("=== Skill Executor Test ===")

	PlayerManager.init_new_game()
	PlayerManager.learn_skill("skill_fireball")
	PlayerManager.equip_active_skill("skill_fireball", 0)
	PlayerManager.learn_skill("skill_heal")
	PlayerManager.equip_active_skill("skill_heal", 1)
	PlayerManager.learn_skill("skill_fire_storm")
	PlayerManager.equip_active_skill("skill_fire_storm", 2)
	PlayerManager.learn_skill("skill_magic_shield")
	PlayerManager.equip_active_skill("skill_magic_shield", 3)

	var player_combatant = CombatantDataClass.from_player()
	var enemy1 = CombatantDataClass.from_enemy("enemy_fire_sprite")
	var enemy2 = CombatantDataClass.from_enemy("enemy_ice_sprite")
	var all_enemies: Array = [enemy1, enemy2]
	var all_allies: Array = [player_combatant]

	var result1: Dictionary = SkillExecutorClass.execute_skill(
		player_combatant,
		"skill_fireball",
		enemy1,
		all_enemies,
		all_allies,
		"none"
	)
	var result1_entries: Array = Array(result1.get("results", []))
	print("Fireball success: %s, results: %d" % [result1.get("success", false), result1_entries.size()])
	if result1_entries.size() > 0:
		var dmg_r: Dictionary = result1_entries[0]
		print("  damage effect: hit=%s dmg=%d crit=%s" % [
			dmg_r.get("is_hit", false),
			int(dmg_r.get("damage", 0)),
			dmg_r.get("is_crit", false),
		])
	if result1_entries.size() > 1:
		var status_r: Dictionary = result1_entries[1]
		print("  status effect: %s applied=%s" % [
			String(status_r.get("status_id", "")),
			status_r.get("applied", false),
		])

	player_combatant.current_mp = player_combatant.max_mp
	player_combatant.current_hp = 50
	var result2: Dictionary = SkillExecutorClass.execute_skill(
		player_combatant,
		"skill_heal",
		player_combatant,
		all_enemies,
		all_allies,
		"none"
	)
	print("Heal success: %s, hp_after: %d/%d" % [
		result2.get("success", false),
		player_combatant.current_hp,
		player_combatant.max_hp,
	])
	var result2_entries: Array = Array(result2.get("results", []))
	if result2_entries.size() > 0:
		print("  heal_amount: %d" % int(Dictionary(result2_entries[0]).get("heal_amount", 0)))

	player_combatant.current_mp = player_combatant.max_mp
	enemy1 = CombatantDataClass.from_enemy("enemy_fire_sprite")
	enemy2 = CombatantDataClass.from_enemy("enemy_ice_sprite")
	all_enemies = [enemy1, enemy2]
	var result3: Dictionary = SkillExecutorClass.execute_skill(
		player_combatant,
		"skill_fire_storm",
		enemy1,
		all_enemies,
		all_allies,
		"none"
	)
	print("Fire Storm success: %s, results: %d" % [
		result3.get("success", false),
		Array(result3.get("results", [])).size(),
	])
	var damage_count := 0
	var status_count := 0
	for raw_result in Array(result3.get("results", [])):
		var result_dict: Dictionary = raw_result
		if String(result_dict.get("effect_type", "")) == "damage":
			damage_count += 1
		elif String(result_dict.get("effect_type", "")) == "status":
			status_count += 1
	print("  damage_results: %d, status_results: %d" % [damage_count, status_count])

	player_combatant.current_mp = player_combatant.max_mp
	player_combatant.cooldowns.clear()
	var result4: Dictionary = SkillExecutorClass.execute_skill(
		player_combatant,
		"skill_magic_shield",
		player_combatant,
		all_enemies,
		all_allies,
		"none"
	)
	print("Shield success: %s, shield_hp: %d" % [result4.get("success", false), player_combatant.shield_hp])

	var cd_check: Dictionary = SkillExecutorClass.can_use_skill(player_combatant, "skill_magic_shield")
	print("Magic Shield usable after cast: %s (reason: %s)" % [
		cd_check.get("usable", false),
		String(cd_check.get("reason", "")),
	])

	SkillExecutorClass.tick_cooldowns(player_combatant)
	var cd_check2: Dictionary = SkillExecutorClass.can_use_skill(player_combatant, "skill_magic_shield")
	print("After 1 tick: usable=%s cd=%d" % [
		cd_check2.get("usable", false),
		int(player_combatant.cooldowns.get("skill_magic_shield", 0)),
	])

	SkillExecutorClass.tick_cooldowns(player_combatant)
	var cd_check3: Dictionary = SkillExecutorClass.can_use_skill(player_combatant, "skill_magic_shield")
	print("After 2 ticks: usable=%s" % cd_check3.get("usable", false))

	player_combatant.skill_pp["skill_magic_shield"] = 0
	var cd_check4: Dictionary = SkillExecutorClass.can_use_skill(player_combatant, "skill_magic_shield")
	print("Shield with 0 PP: usable=%s (reason: %s)" % [
		cd_check4.get("usable", false),
		String(cd_check4.get("reason", "")),
	])

	print("Fireball priority: %d" % SkillExecutorClass.get_skill_priority("skill_fireball"))
	print("Heal priority: %d" % SkillExecutorClass.get_skill_priority("skill_heal"))
	print("Magic Shield priority: %d" % SkillExecutorClass.get_skill_priority("skill_magic_shield"))

	PlayerManager.init_new_game()
	print("=== End Skill Executor Test ===")


func _test_status_processor() -> void:
	print("=== Status Processor Test ===")

	PlayerManager.init_new_game()
	var player_combatant = CombatantDataClass.from_player()
	var enemy1 = CombatantDataClass.from_enemy("enemy_fire_sprite")
	var enemy2 = CombatantDataClass.from_enemy("enemy_ice_sprite")

	player_combatant.status_effects.append({"id": "burn", "turns": 3})
	print("Has burn: %s" % player_combatant.has_status("burn"))
	var hp_before: int = player_combatant.current_hp
	var dot_results: Array = StatusProcessorClass.process_end_of_turn(player_combatant)
	var burn_damage := 0
	for raw_result in dot_results:
		var result_dict: Dictionary = raw_result
		if String(result_dict.get("type", "")) == "dot_damage" and String(result_dict.get("status_id", "")) == "burn":
			burn_damage = int(result_dict.get("value", 0))
	var expected_burn: int = max(1, int(float(player_combatant.max_hp) * 0.08))
	print("Burn damage: %d (expected: %d)" % [burn_damage, expected_burn])
	print("HP after burn: %d (was %d)" % [player_combatant.current_hp, hp_before])

	var burn_status: Dictionary = player_combatant.get_status("burn")
	print("Burn turns remaining: %d" % int(burn_status.get("turns", -1)))

	player_combatant.current_hp = 50
	player_combatant.status_effects.append({"id": "regen", "turns": 5})
	var regen_results: Array = StatusProcessorClass.process_end_of_turn(player_combatant)
	var regen_amount := 0
	for raw_result in regen_results:
		var result_dict: Dictionary = raw_result
		if String(result_dict.get("type", "")) == "regen":
			regen_amount = int(result_dict.get("value", 0))
	var expected_regen: int = max(1, int(float(player_combatant.max_hp) * 0.05))
	print("Regen heal: %d (expected: %d)" % [regen_amount, expected_regen])
	print("HP after regen: %d" % player_combatant.current_hp)

	enemy1.status_effects.clear()
	enemy1.status_effects.append({"id": "freeze", "turns": 2})
	var freeze_check: Dictionary = StatusProcessorClass.check_before_action(enemy1, [], [player_combatant])
	print("Frozen enemy can_act: %s (reason: %s)" % [
		freeze_check.get("can_act", true),
		String(freeze_check.get("reason", "")),
	])

	var unfreeze_logs: Array = StatusProcessorClass.on_damage_received(enemy1, "fire")
	print("Fire hit frozen: removed freeze=%s, logs=%d" % [
		not enemy1.has_status("freeze"),
		unfreeze_logs.size(),
	])

	enemy2.status_effects.clear()
	enemy2.status_effects.append({"id": "sleep", "turns": 3})
	var sleep_check: Dictionary = StatusProcessorClass.check_before_action(enemy2, [], [player_combatant])
	print("Sleeping enemy can_act: %s" % sleep_check.get("can_act", true))
	var _wake_logs: Array = StatusProcessorClass.on_damage_received(enemy2, "none")
	print("Damage woke up: removed sleep=%s" % (not enemy2.has_status("sleep")))

	player_combatant.status_effects.clear()
	player_combatant.status_effects.append({"id": "atk_up", "turns": 3})
	var atk_mod: float = StatusProcessorClass.get_status_stat_modifier(player_combatant, "matk")
	var expected_mod: float = float(player_combatant.matk) * 0.25
	print("ATK up modifier: %.1f (expected: %.1f)" % [atk_mod, expected_mod])

	player_combatant.status_effects.append({"id": "atk_down", "turns": 3})
	var net_mod: float = StatusProcessorClass.get_status_stat_modifier(player_combatant, "matk")
	print("ATK up + down net modifier: %.1f (expected: 0.0)" % [net_mod])

	player_combatant.status_effects.clear()
	PlayerManager.learn_skill("skill_fireball")
	PlayerManager.equip_active_skill("skill_fireball", 0)
	player_combatant = CombatantDataClass.from_player()
	var sealed: String = StatusProcessorClass.apply_seal(player_combatant)
	print("Sealed skill: %s (sealed_skill_id: %s)" % [sealed, player_combatant.sealed_skill_id])

	print("Has curse (no): %s" % StatusProcessorClass.has_curse(player_combatant))
	player_combatant.status_effects.append({"id": "curse", "turns": 3})
	print("Has curse (yes): %s" % StatusProcessorClass.has_curse(player_combatant))

	enemy1.status_effects.clear()
	enemy1.status_effects.append({"id": "reflect", "turns": 1})
	var reflect_check: Dictionary = StatusProcessorClass.check_reflect(enemy1, "fire", "magic")
	print("Reflect magic: %s, consumed=%s" % [
		reflect_check.get("reflected", false),
		not enemy1.has_status("reflect"),
	])

	enemy2.status_effects.clear()
	enemy2.status_effects.append({"id": "stealth", "turns": 1})
	var stealth_check: Dictionary = StatusProcessorClass.check_stealth_dodge(enemy2)
	print("Stealth dodge: %s, consumed=%s" % [
		stealth_check.get("dodged", false),
		not enemy2.has_status("stealth"),
	])

	player_combatant.status_effects.clear()
	player_combatant.status_effects.append({"id": "poison", "turns": 5})
	print("Has poison: %s" % player_combatant.has_status("poison"))
	player_combatant.remove_status("poison")
	print("After remove poison: %s" % player_combatant.has_status("poison"))

	PlayerManager.init_new_game()
	print("=== End Status Processor Test ===")


func _test_battle_ai() -> void:
	print("=== Battle AI Test ===")

	PlayerManager.init_new_game()
	var player_combatant = CombatantDataClass.from_player()
	var fire_sprite = CombatantDataClass.from_enemy("enemy_fire_sprite")
	var ice_sprite = CombatantDataClass.from_enemy("enemy_ice_sprite")

	var player_side: Array = [player_combatant]
	var enemy_side: Array = [fire_sprite, ice_sprite]

	print("--- Aggressive AI ---")
	print("fire_sprite ai_type: %s" % fire_sprite.ai_type)
	var agg_actions: Dictionary = {}
	for _index in range(20):
		var action: Dictionary = BattleAIClass.decide_enemy_action(fire_sprite, player_side, enemy_side)
		var skill_id: String = String(action.get("skill_id", ""))
		agg_actions[skill_id] = int(agg_actions.get(skill_id, 0)) + 1
	print("Aggressive action distribution (20 trials):")
	var agg_keys: Array = agg_actions.keys()
	agg_keys.sort()
	for raw_skill_id in agg_keys:
		var skill_id: String = String(raw_skill_id)
		var skill_name: String = skill_id if not skill_id.is_empty() else "basic_attack"
		print("  %s: %d" % [skill_name, int(agg_actions.get(skill_id, 0))])

	print("--- Cautious AI ---")
	print("ice_sprite ai_type: %s" % ice_sprite.ai_type)
	var cautious_normal: Dictionary = BattleAIClass.decide_enemy_action(ice_sprite, player_side, enemy_side)
	print("Cautious (full HP) action: skill=%s" % String(cautious_normal.get("skill_id", "")))
	ice_sprite.current_hp = int(float(ice_sprite.max_hp) * 0.3)
	var cautious_low: Dictionary = BattleAIClass.decide_enemy_action(ice_sprite, player_side, enemy_side)
	print("Cautious (30%% HP) action: skill=%s" % String(cautious_low.get("skill_id", "")))
	ice_sprite.current_hp = ice_sprite.max_hp

	print("--- Familiar AI (Attack) ---")
	var fire_imp = CombatantDataClass.from_familiar("familiar_fire_imp", 3)
	fire_imp.familiar_mode = CombatantDataClass.FamiliarMode.ATTACK
	var fam_attack: Dictionary = BattleAIClass.decide_familiar_action(fire_imp, enemy_side, player_side)
	var fam_attack_target = fam_attack.get("target", null)
	print("Familiar attack mode: skill=%s, target=%s" % [
		String(fam_attack.get("skill_id", "")),
		fam_attack_target.display_name if fam_attack_target != null else "null",
	])

	print("--- Familiar AI (Support) ---")
	fire_imp.familiar_mode = CombatantDataClass.FamiliarMode.SUPPORT
	var fam_support: Dictionary = BattleAIClass.decide_familiar_action(fire_imp, enemy_side, player_side)
	print("Familiar support mode (no heal skill): skill=%s" % String(fam_support.get("skill_id", "")))

	print("--- Familiar AI (Support with buff) ---")
	var ice_guard = CombatantDataClass.from_familiar("familiar_ice_guard", 3)
	ice_guard.familiar_mode = CombatantDataClass.FamiliarMode.SUPPORT
	var guard_support: Dictionary = BattleAIClass.decide_familiar_action(ice_guard, enemy_side, player_side)
	print("Ice guard support mode: skill=%s" % String(guard_support.get("skill_id", "")))

	print("--- No usable skills ---")
	fire_sprite.current_mp = 0
	for skill_id in fire_sprite.skill_ids:
		fire_sprite.skill_pp[skill_id] = 0
	var no_skill_action: Dictionary = BattleAIClass.decide_enemy_action(fire_sprite, player_side, enemy_side)
	var no_skill_id: String = String(no_skill_action.get("skill_id", ""))
	print("No skills available: skill_id='%s' (empty=basic attack)" % no_skill_id)

	print("--- Target selection ---")
	fire_sprite = CombatantDataClass.from_enemy("enemy_fire_sprite")
	player_combatant.current_hp = 30
	var target_action: Dictionary = BattleAIClass.decide_enemy_action(fire_sprite, player_side, enemy_side)
	var chosen_target = target_action.get("target", null)
	print("Aggressive targets lowest HP: target=%s (hp=%d)" % [
		chosen_target.display_name if chosen_target != null else "null",
		int(chosen_target.current_hp) if chosen_target != null else 0,
	])

	PlayerManager.init_new_game()
	print("=== End Battle AI Test ===")


func _test_battle_result() -> void:
	print("=== Battle Result Test ===")

	PlayerManager.init_new_game()
	var old_level: int = PlayerManager.player_data.level
	var old_exp: int = PlayerManager.player_data.exp
	var old_gold: int = PlayerManager.player_data.gold
	print("Before: level=%d, exp=%d, gold=%d" % [old_level, old_exp, old_gold])

	var enemy1 = CombatantDataClass.from_enemy("enemy_fire_sprite")
	var enemy2 = CombatantDataClass.from_enemy("enemy_ice_sprite")
	var enemies_arr: Array = [enemy1, enemy2]

	var rewards: Dictionary = BattleResultClass.calculate_victory_rewards(enemies_arr, 5, [])
	print("--- Victory Rewards (floor=5, 2 enemies) ---")
	print("EXP: %d" % int(rewards.get("exp", 0)))

	var expected_raw: int = 25 + 20
	var expected_count_mod: float = 1.0 + float(2 - 1) * 0.1
	var expected_floor_mod: float = 1.0 + float(5) * 0.01
	var expected_exp: int = max(1, int(float(expected_raw) * expected_count_mod * expected_floor_mod))
	print("Expected EXP: %d (raw=%d, count_mod=%.2f, floor_mod=%.2f)" % [
		expected_exp,
		expected_raw,
		expected_count_mod,
		expected_floor_mod,
	])

	print("Gold: %d (range: ~%d-%d)" % [
		int(rewards.get("gold", 0)),
		int((15 + 12) * 0.8),
		int((15 + 12) * 1.2),
	])
	print("Drops count: %d" % Array(rewards.get("dropped_items", [])).size())
	print("Familiar EXP: %d" % int(rewards.get("familiar_exp", 0)))

	var level_result: Dictionary = BattleResultClass.apply_victory_rewards(rewards)
	print("After apply: level=%d, exp=%d, gold=%d" % [
		PlayerManager.player_data.level,
		PlayerManager.player_data.exp,
		PlayerManager.player_data.gold,
	])
	print("Leveled up: %s" % bool(level_result.get("leveled_up", false)))

	print("--- Skill Learning ---")
	PlayerManager.init_new_game()
	var received: Array[String] = ["skill_flame_shot", "skill_ice_shard"]
	var learn_count: int = 0
	for _index in range(200):
		PlayerManager.init_new_game()
		var learn_rewards: Dictionary = BattleResultClass.calculate_victory_rewards(enemies_arr, 1, received)
		learn_count += Array(learn_rewards.get("learned_skills", [])).size()
	var avg_learn: float = float(learn_count) / 200.0
	print("Avg skills learned per battle (200 trials, 2 skills, 5%% each): %.2f (expected ~0.10)" % avg_learn)

	print("--- Defeat Penalty ---")
	PlayerManager.init_new_game()
	PlayerManager.add_gold(1000)
	print("Gold before defeat: %d" % PlayerManager.player_data.gold)
	PlayerManager.player_data.current_hp = 0
	PlayerManager.player_data.current_mp = 10

	var penalty: Dictionary = BattleResultClass.calculate_defeat_penalty()
	print("Gold penalty: %d (expected: %d)" % [
		int(penalty.get("gold_lost", 0)),
		int(1000 * 0.2),
	])

	BattleResultClass.apply_defeat_penalty(penalty)
	print("Gold after penalty: %d (expected: %d)" % [
		PlayerManager.player_data.gold,
		1000 - 200,
	])
	print("HP after defeat: %d/%d (expected full)" % [
		PlayerManager.player_data.current_hp,
		PlayerManager.get_max_hp(),
	])
	print("MP after defeat: %d/%d (expected full)" % [
		PlayerManager.player_data.current_mp,
		PlayerManager.get_max_mp(),
	])

	print("--- Level Up Test ---")
	PlayerManager.init_new_game()
	print("Level before big EXP: %d" % PlayerManager.player_data.level)
	var big_rewards: Dictionary = {
		"exp": 60,
		"gold": 0,
		"dropped_items": [],
		"learned_skills": [],
		"level_before": 1,
	}
	var lv_result: Dictionary = BattleResultClass.apply_victory_rewards(big_rewards)
	print("Level after 60 EXP: %d (leveled_up=%s)" % [
		PlayerManager.player_data.level,
		bool(lv_result.get("leveled_up", false)),
	])

	PlayerManager.init_new_game()
	print("=== End Battle Result Test ===")


func _test_floor_generator() -> void:
	print("=== Floor Generator Test ===")

	var exploration_scene := load("res://scenes/exploration/exploration.tscn") as PackedScene
	if exploration_scene != null:
		var exploration_instance := exploration_scene.instantiate()
		add_child(exploration_instance)
		if exploration_instance.has_method("enter_floor"):
			exploration_instance.call("enter_floor", 2)
		exploration_instance.queue_free()

	print("--- Floor 2 generation ---")
	var floor2: Dictionary = FloorGeneratorClass.generate_floor(2)
	print("Floor: %d" % int(floor2.get("floor_number", 0)))
	print("Zone: %s (element: %s)" % [
		String(floor2.get("zone_name", "")),
		String(floor2.get("zone_element", "")),
	])
	print("Is boss floor: %s" % bool(floor2.get("is_boss_floor", false)))

	var nodes: Array = Array(floor2.get("nodes", []))
	print("Total nodes: %d" % nodes.size())

	var type_count: Dictionary = {}
	for raw_node in nodes:
		var node: Dictionary = raw_node
		var node_type: String = String(node.get("type", ""))
		type_count[node_type] = int(type_count.get(node_type, 0)) + 1
	print("Node types: %s" % str(type_count))
	print("Has entrance: %s" % (int(type_count.get("entrance", 0)) == 1))
	print("Has exit: %s" % (int(type_count.get("exit", 0)) >= 1 or int(type_count.get("boss", 0)) >= 1))

	print("--- Connectivity check ---")
	var entrance_id: int = int(floor2.get("entrance_id", 0))
	var exit_id: int = int(floor2.get("exit_id", -1))
	var reachable: Array = _flood_fill(nodes, entrance_id)
	print("Reachable from entrance: %d / %d nodes" % [reachable.size(), nodes.size()])
	print("Exit reachable: %s" % reachable.has(exit_id))

	print("--- Boss floor (9F) ---")
	var floor9: Dictionary = FloorGeneratorClass.generate_floor(9)
	print("Floor 9 is_boss: %s" % bool(floor9.get("is_boss_floor", false)))
	var nodes9: Array = Array(floor9.get("nodes", []))
	var has_boss_exit: bool = false
	for raw_node in nodes9:
		var node: Dictionary = raw_node
		if String(node.get("type", "")) == "boss":
			has_boss_exit = true
			break
	print("Has boss exit node: %s" % has_boss_exit)

	print("--- Randomness check (10 floors) ---")
	var node_counts: Array = []
	for _index in range(10):
		var generated_floor: Dictionary = FloorGeneratorClass.generate_floor(5)
		node_counts.append(Array(generated_floor.get("nodes", [])).size())
	print("Node counts across 10 generations: %s" % str(node_counts))

	print("--- Floor 55 (zone 6) ---")
	var floor55: Dictionary = FloorGeneratorClass.generate_floor(55)
	print("Zone: %s (element: %s)" % [
		String(floor55.get("zone_name", "")),
		String(floor55.get("zone_element", "")),
	])

	print("=== End Floor Generator Test ===")


func _test_node_handler() -> void:
	print("=== Node Handler Test ===")
	PlayerManager.init_new_game()
	PlayerManager.add_gold(1000)

	print("--- Battle enemy generation ---")
	var enemies_f5: Array = NodeHandlerClass.generate_battle_enemies(5, false)
	print("Floor 5 enemies: %s (count=%d)" % [str(enemies_f5), enemies_f5.size()])
	var enemies_elite: Array = NodeHandlerClass.generate_battle_enemies(5, true)
	print("Floor 5 elite: %s (count=%d, expected 1)" % [str(enemies_elite), enemies_elite.size()])

	print("--- Event picking ---")
	var event_data: Dictionary = NodeHandlerClass.pick_event(5)
	print("Picked event: %s (type=%s)" % [
		String(event_data.get("name", "")),
		String(event_data.get("type", "")),
	])
	var options: Array = Array(event_data.get("options", []))
	print("Options count: %d" % options.size())
	for raw_option in options:
		if raw_option is not Dictionary:
			continue
		var option: Dictionary = raw_option
		if not NodeHandlerClass.evaluate_option_condition(option):
			continue
		var outcomes: Array = NodeHandlerClass.execute_event_results(option)
		print("Option '%s' outcomes: %d" % [String(option.get("text", "")), outcomes.size()])
		for raw_outcome in outcomes:
			var outcome: Dictionary = raw_outcome
			print("  -> %s" % String(outcome.get("text", "")))
		break

	print("--- Chest reward ---")
	var old_gold: int = PlayerManager.player_data.gold
	var chest: Dictionary = NodeHandlerClass.generate_chest_reward(5)
	print("Chest rarity: %s, gold: %d" % [
		String(chest.get("rarity", "")),
		int(chest.get("gold", 0)),
	])
	print("Gold after chest: %d (was %d)" % [PlayerManager.player_data.gold, old_gold])

	print("--- Merchant ---")
	var stock: Array = NodeHandlerClass.generate_merchant_stock(5)
	print("Merchant stock count: %d" % stock.size())
	for raw_item in stock:
		var item: Dictionary = raw_item
		print("  %s - %dG" % [String(item.get("name", "")), int(item.get("price", 0))])
	if not stock.is_empty():
		var buy_result: Dictionary = NodeHandlerClass.buy_item(stock[0])
		print("Buy result: success=%s, item=%s" % [
			bool(buy_result.get("success", false)),
			String(buy_result.get("item_name", "")),
		])

	print("--- Rest node ---")
	PlayerManager.player_data.current_hp = 50
	PlayerManager.player_data.current_mp = 20
	print("Before rest: HP=%d, MP=%d" % [50, 20])
	var rest_result: Dictionary = NodeHandlerClass.apply_rest()
	print("After rest: HP=%d/%d (+%d), MP=%d/%d (+%d)" % [
		int(rest_result.get("current_hp", 0)),
		int(rest_result.get("max_hp", 0)),
		int(rest_result.get("hp_restored", 0)),
		int(rest_result.get("current_mp", 0)),
		int(rest_result.get("max_mp", 0)),
		int(rest_result.get("mp_restored", 0)),
	])

	print("--- Altar ---")
	PlayerManager.player_data.current_hp = 100
	PlayerManager.player_data.current_mp = 60
	PlayerManager.add_gold(500)
	var altar_options: Array = NodeHandlerClass.get_altar_options()
	print("Altar options: %d" % altar_options.size())

	var blood_result: Dictionary = NodeHandlerClass.execute_altar("blood_altar")
	print("Blood altar: %s (HP now=%d)" % [
		String(blood_result.get("text", "")),
		PlayerManager.player_data.current_hp,
	])

	var mana_result: Dictionary = NodeHandlerClass.execute_altar("mana_altar")
	print("Mana altar: %s (base_mp now=%d)" % [
		String(mana_result.get("text", "")),
		PlayerManager.player_data.base_mp,
	])

	PlayerManager.init_new_game()
	print("=== End Node Handler Test ===")


func _test_inventory() -> void:
	print("=== Inventory Test ===")

	PlayerManager.init_new_game()
	var inv = PlayerManager.inventory

	print("--- Add / Remove ---")
	print("add hp_potion_s x3: %s" % PlayerManager.add_item("item_hp_potion_s", 3))
	print("count hp_potion_s: %d (expected 3)" % PlayerManager.get_item_count("item_hp_potion_s"))
	print("has hp_potion_s x2: %s (expected true)" % PlayerManager.has_item("item_hp_potion_s", 2))
	print("remove hp_potion_s x1: %s" % PlayerManager.remove_item("item_hp_potion_s"))
	print("count hp_potion_s: %d (expected 2)" % PlayerManager.get_item_count("item_hp_potion_s"))
	print("remove hp_potion_s x5 (over): %s (expected false)" % PlayerManager.remove_item("item_hp_potion_s", 5))
	print("count hp_potion_s: %d (expected 2, unchanged)" % PlayerManager.get_item_count("item_hp_potion_s"))

	print("--- Stack limit ---")
	print("add hp_potion_s x20: %s" % PlayerManager.add_item("item_hp_potion_s", 20))
	print("count hp_potion_s: %d (expected 10, max_stack)" % PlayerManager.get_item_count("item_hp_potion_s"))

	print("--- Equipment ---")
	print("add weapon_apprentice_staff: %s" % PlayerManager.add_item("weapon_apprentice_staff"))
	print("add weapon_apprentice_staff again: %s" % PlayerManager.add_item("weapon_apprentice_staff"))
	print("count weapon_apprentice_staff: %d (expected 2)" % PlayerManager.get_item_count("weapon_apprentice_staff"))
	print("remove weapon_apprentice_staff: %s" % PlayerManager.remove_item("weapon_apprentice_staff"))
	print("count weapon_apprentice_staff: %d (expected 1)" % PlayerManager.get_item_count("weapon_apprentice_staff"))

	print("--- Use item ---")
	PlayerManager.player_data.current_hp = 50
	var use_result: Dictionary = PlayerManager.use_item("item_hp_potion_s")
	print("use hp_potion_s: success=%s effects=%s" % [
		use_result.get("success", false),
		str(use_result.get("effects", [])),
	])
	print("hp after use: %d (expected ~100, was 50 +50)" % PlayerManager.player_data.current_hp)
	print("count hp_potion_s after use: %d (expected 9)" % PlayerManager.get_item_count("item_hp_potion_s"))

	print("--- Serialize ---")
	var save_dict: Dictionary = inv.to_save_dict()
	print("save_dict keys: %s" % str(save_dict.keys()))
	var inv2 = InventoryClass.new()
	inv2.load_from_dict(save_dict)
	print("loaded hp_potion_s: %d (expected %d)" % [
		inv2.count("item_hp_potion_s"),
		inv.count("item_hp_potion_s"),
	])
	print("loaded weapon_apprentice_staff: %d (expected %d)" % [
		inv2.count("weapon_apprentice_staff"),
		inv.count("weapon_apprentice_staff"),
	])

	print("--- All items ---")
	var all_items: Array = inv.get_all_items()
	print("total item entries: %d" % all_items.size())
	for raw_entry in all_items:
		var entry: Dictionary = raw_entry
		print("  %s x%d" % [String(entry.get("id", "")), int(entry.get("count", 0))])

	PlayerManager.init_new_game()
	print("=== End Inventory Test ===")


func _test_inventory_panel() -> void:
	print("=== Inventory Panel Test ===")

	PlayerManager.init_new_game()
	PlayerManager.add_item("item_hp_potion_s", 3)
	PlayerManager.add_item("item_mp_potion_s", 2)
	PlayerManager.add_item("weapon_apprentice_staff")
	PlayerManager.add_item("armor_apprentice_robe")

	print("--- Item list before ---")
	var all_items: Array = PlayerManager.inventory.get_all_items()
	for raw_entry in all_items:
		var entry: Dictionary = raw_entry
		print("  %s x%d" % [String(entry.get("id", "")), int(entry.get("count", 0))])

	print("--- Use item ---")
	PlayerManager.player_data.current_hp = 50
	var use_result: Dictionary = PlayerManager.use_item("item_hp_potion_s")
	print("use hp_potion_s: success=%s" % use_result.get("success", false))
	print("hp after: %d" % PlayerManager.player_data.current_hp)
	print("hp_potion_s count: %d (expected 2)" % PlayerManager.get_item_count("item_hp_potion_s"))

	print("--- Equip weapon ---")
	var old_weapon: String = PlayerManager.equip_weapon("weapon_apprentice_staff")
	PlayerManager.remove_item("weapon_apprentice_staff")
	if not old_weapon.is_empty():
		PlayerManager.add_item(old_weapon)
	print("equipped weapon: %s" % PlayerManager.player_data.weapon_id)
	print("weapon in bag: %d (expected 0)" % PlayerManager.get_item_count("weapon_apprentice_staff"))
	print("matk with weapon: %d (expected base+5)" % PlayerManager.get_matk())

	print("--- Unequip weapon ---")
	var removed_weapon: String = PlayerManager.unequip_weapon()
	PlayerManager.add_item(removed_weapon)
	print("weapon slot: '%s' (expected empty)" % PlayerManager.player_data.weapon_id)
	print("weapon in bag: %d (expected 1)" % PlayerManager.get_item_count("weapon_apprentice_staff"))

	print("--- Panel instantiation ---")
	var panel = InventoryPanelClass.new()
	panel.setup(InventoryPanelClass.Mode.SAFE_ZONE)
	print("panel created: %s (expected true)" % (panel != null))
	print("panel type: %s" % panel.get_class())
	panel.free()

	print("--- Category filter ---")
	var consumable_count: int = 0
	var equipment_count: int = 0
	for raw_entry in PlayerManager.inventory.get_all_items():
		var entry: Dictionary = raw_entry
		var item_id: String = String(entry.get("id", ""))
		var item_data: Dictionary = DataManager.get_item(item_id)
		var item_type: String = String(item_data.get("type", ""))
		match item_type:
			"consumable":
				consumable_count += 1
			"weapon", "armor", "accessory":
				equipment_count += 1
	print("consumable entries: %d (expected 2)" % consumable_count)
	print("equipment entries: %d (expected 2)" % equipment_count)

	PlayerManager.init_new_game()
	print("=== End Inventory Panel Test ===")


func _test_shop() -> void:
	print("=== Shop Test ===")

	PlayerManager.init_new_game()
	PlayerManager.add_gold(500)

	print("--- get_items_for_shop ---")
	var floor1_items: Array = DataManager.get_items_for_shop(1)
	print("floor 1 shop items: %d" % floor1_items.size())
	for raw_item in floor1_items:
		var item: Dictionary = raw_item
		print("  %s  buy=%d" % [String(item.get("id", "")), int(item.get("buy_price", 0))])

	var floor10_items: Array = DataManager.get_items_for_shop(10)
	print("floor 10 shop items: %d (expected >= floor 1)" % floor10_items.size())

	print("--- Buy ---")
	var gold_before: int = PlayerManager.player_data.gold
	var buy_price: int = 30
	PlayerManager.spend_gold(buy_price)
	PlayerManager.add_item("item_hp_potion_s")
	print("gold after buy: %d (expected %d)" % [PlayerManager.player_data.gold, gold_before - buy_price])
	print("hp_potion_s count: %d (expected 1)" % PlayerManager.get_item_count("item_hp_potion_s"))

	PlayerManager.spend_gold(buy_price)
	PlayerManager.add_item("item_hp_potion_s")
	print("hp_potion_s count: %d (expected 2)" % PlayerManager.get_item_count("item_hp_potion_s"))

	print("--- Sell ---")
	var gold_before_sell: int = PlayerManager.player_data.gold
	var sell_price: int = 15
	PlayerManager.remove_item("item_hp_potion_s")
	PlayerManager.add_gold(sell_price)
	print("gold after sell: %d (expected %d)" % [PlayerManager.player_data.gold, gold_before_sell + sell_price])
	print("hp_potion_s count: %d (expected 1)" % PlayerManager.get_item_count("item_hp_potion_s"))

	print("--- Insufficient gold ---")
	PlayerManager.player_data.gold = 10
	var can_buy: bool = PlayerManager.spend_gold(100)
	print("spend 100 with 10 gold: %s (expected false)" % can_buy)
	print("gold unchanged: %d (expected 10)" % PlayerManager.player_data.gold)

	print("--- Panel instantiation ---")
	var panel = ShopPanelClass.new()
	panel.setup(1)
	print("shop panel created: %s" % (panel != null))
	panel.free()

	PlayerManager.init_new_game()
	print("=== End Shop Test ===")


func _test_forge() -> void:
	print("=== Forge Test ===")

	PlayerManager.init_new_game()
	PlayerManager.add_gold(2000)

	print("--- Material data ---")
	var iron: Dictionary = DataManager.get_item("mat_iron_ore")
	print("iron_ore: name=%s type=%s" % [iron.get("name", ""), iron.get("type", "")])
	var fire_crystal: Dictionary = DataManager.get_item("mat_fire_crystal")
	print("fire_crystal: name=%s rarity=%s" % [fire_crystal.get("name", ""), fire_crystal.get("rarity", "")])

	print("--- Equipment enhance tracking ---")
	PlayerManager.add_item("weapon_apprentice_staff")
	var eq_list: Array = PlayerManager.inventory.get_equipment_list()
	print("equipment in bag: %d (expected 1)" % eq_list.size())
	print("enhance level: %d (expected 0)" % int(eq_list[0].get("enhance", -1)))

	print("--- Equip with enhance ---")
	PlayerManager.inventory.set_equipment_enhance(0, 3)
	PlayerManager.player_data.inventory_data = PlayerManager.inventory.to_save_dict()
	var equip_entry: Dictionary = PlayerManager.inventory.get_equipment_at(0)
	print("bag enhance before equip: %d (expected 3)" % int(equip_entry.get("enhance", 0)))
	PlayerManager.equip_weapon("weapon_apprentice_staff", 3)
	PlayerManager.inventory.remove_equipment_at(0)
	PlayerManager.player_data.inventory_data = PlayerManager.inventory.to_save_dict()
	print("weapon_enhance on player: %d (expected 3)" % PlayerManager.player_data.weapon_enhance)
	print("matk with +3 weapon: %d (expected 15+5+3=23)" % PlayerManager.get_matk())

	var old_id: String = PlayerManager.unequip_weapon()
	var old_enh: int = PlayerManager.get_last_unequip_enhance()
	PlayerManager.inventory.add_equipment(old_id, old_enh)
	PlayerManager.player_data.inventory_data = PlayerManager.inventory.to_save_dict()
	print("unequip enhance: %d (expected 3)" % old_enh)
	var bag_entry: Dictionary = PlayerManager.inventory.get_equipment_at(0)
	print("bag enhance after unequip: %d (expected 3)" % int(bag_entry.get("enhance", 0)))

	print("--- Enhance logic ---")
	PlayerManager.equip_weapon("weapon_apprentice_staff", 0)
	PlayerManager.inventory.remove_equipment_at(0)
	PlayerManager.player_data.inventory_data = PlayerManager.inventory.to_save_dict()
	PlayerManager.add_item("mat_iron_ore", 20)
	PlayerManager.add_item("mat_enhance_stone", 10)

	var cost: Dictionary = ForgeLogicClass.get_enhance_cost("weapon_apprentice_staff", 0)
	print("enhance +0→+1 cost: gold=%d mat=%s x%d rate=%.0f%%" % [
		int(cost.get("gold_cost", 0)),
		String(cost.get("material_id", "")),
		int(cost.get("material_count", 0)),
		float(cost.get("success_rate", 0.0)) * 100.0,
	])

	var check: Dictionary = ForgeLogicClass.can_enhance("weapon_apprentice_staff", 0)
	print("can enhance: %s" % bool(check.get("can", false)))

	var enhance_result: Dictionary = ForgeLogicClass.execute_enhance("weapon_apprentice_staff", 0)
	print("enhance result: success=%s enhanced=%s" % [
		bool(enhance_result.get("success", false)),
		bool(enhance_result.get("enhanced", false)),
	])

	print("--- Dismantle logic ---")
	PlayerManager.add_item("weapon_fire_staff")
	var dismantle_preview: Dictionary = ForgeLogicClass.get_dismantle_result("weapon_fire_staff", 0)
	print("dismantle fire_staff: gold=%d materials=%s" % [
		int(dismantle_preview.get("gold", 0)),
		str(dismantle_preview.get("materials", [])),
	])

	var equipment_list: Array = PlayerManager.inventory.get_equipment_list()
	var eq_index: int = int(equipment_list[0].get("index", -1))
	var dismantle_result: Dictionary = ForgeLogicClass.execute_dismantle(eq_index)
	print("dismantle executed: success=%s" % bool(dismantle_result.get("success", false)))
	print("iron_ore count after dismantle: %d" % PlayerManager.get_item_count("mat_iron_ore"))

	print("--- Panel ---")
	var panel = ForgePanelClass.new()
	panel.setup()
	print("forge panel created: %s" % (panel != null))
	panel.free()

	PlayerManager.init_new_game()
	print("=== End Forge Test ===")


func _test_craft_synthesis() -> void:
	print("=== Craft & Synthesis Test ===")

	PlayerManager.init_new_game()
	PlayerManager.add_gold(5000)

	print("--- Recipe data ---")
	var craft_recipes: Array = DataManager.get_recipes_by_type("craft", 1)
	print("craft recipes at floor 1: %d" % craft_recipes.size())
	for raw_recipe in craft_recipes:
		var recipe: Dictionary = raw_recipe
		print("  %s -> %s" % [String(recipe.get("id", "")), String(recipe.get("result_name", ""))])

	var craft_recipes_10: Array = DataManager.get_recipes_by_type("craft", 10)
	print("craft recipes at floor 10: %d (expected >= floor 1)" % craft_recipes_10.size())

	var synth_recipes: Array = DataManager.get_recipes_by_type("synthesis", 1)
	print("synthesis recipes at floor 1: %d" % synth_recipes.size())
	for raw_recipe in synth_recipes:
		var recipe_s: Dictionary = raw_recipe
		print("  %s -> %s" % [String(recipe_s.get("id", "")), String(recipe_s.get("result_name", ""))])

	var synth_recipes_10: Array = DataManager.get_recipes_by_type("synthesis", 10)
	print("synthesis recipes at floor 10: %d (expected >= floor 1)" % synth_recipes_10.size())

	print("--- Craft: insufficient materials ---")
	var staff_recipe: Dictionary = {}
	for raw_recipe in craft_recipes:
		var recipe_staff: Dictionary = raw_recipe
		if String(recipe_staff.get("result_id", "")) == "weapon_apprentice_staff":
			staff_recipe = recipe_staff
			break
	var check: Dictionary = ForgeLogicClass.can_craft(staff_recipe)
	print("can craft apprentice_staff without mats: %s (expected false)" % bool(check.get("can", false)))

	print("--- Craft: success ---")
	PlayerManager.add_item("mat_iron_ore", 10)
	check = ForgeLogicClass.can_craft(staff_recipe)
	print("can craft with mats: %s (expected true)" % bool(check.get("can", false)))
	var gold_before: int = PlayerManager.player_data.gold
	var result: Dictionary = ForgeLogicClass.execute_craft(staff_recipe)
	print("craft success: %s" % bool(result.get("success", false)))
	print("result_name: %s" % String(result.get("result_name", "")))
	print("gold after craft: %d (expected %d)" % [
		PlayerManager.player_data.gold,
		gold_before - int(staff_recipe.get("gold_cost", 0)),
	])
	print("iron_ore after craft: %d (expected 7)" % PlayerManager.get_item_count("mat_iron_ore"))
	print("apprentice_staff in bag: %d (expected 1)" % PlayerManager.get_item_count("weapon_apprentice_staff"))

	print("--- Synthesis ---")
	PlayerManager.add_item("mat_magic_crystal", 10)
	PlayerManager.add_item("mat_ice_crystal", 5)
	var regen_recipe: Dictionary = {}
	for raw_recipe in synth_recipes_10:
		var recipe_regen_10: Dictionary = raw_recipe
		if String(recipe_regen_10.get("result_id", "")) == "acc_regen_ring":
			regen_recipe = recipe_regen_10
			break
	if regen_recipe.is_empty():
		for raw_recipe in synth_recipes:
			var recipe_regen_1: Dictionary = raw_recipe
			if String(recipe_regen_1.get("result_id", "")) == "acc_regen_ring":
				regen_recipe = recipe_regen_1
				break

	if not regen_recipe.is_empty():
		check = ForgeLogicClass.can_synthesize(regen_recipe)
		print("can synthesize regen_ring: %s (expected true)" % bool(check.get("can", false)))
		result = ForgeLogicClass.execute_synthesize(regen_recipe)
		print("synthesis success: %s" % bool(result.get("success", false)))
		print("regen_ring in bag: %d (expected 1)" % PlayerManager.get_item_count("acc_regen_ring"))
	else:
		print("regen_ring recipe not found (check floor filter)")

	print("--- Multiple craft ---")
	var result2: Dictionary = ForgeLogicClass.execute_craft(staff_recipe)
	print("second craft success: %s" % bool(result2.get("success", false)))
	print("apprentice_staff in bag: %d (expected 2)" % PlayerManager.get_item_count("weapon_apprentice_staff"))
	print("iron_ore after 2nd craft: %d (expected 4)" % PlayerManager.get_item_count("mat_iron_ore"))

	PlayerManager.init_new_game()
	print("=== End Craft & Synthesis Test ===")


func _test_game_flow() -> void:
	print("=== Game Flow Test ===")

	PlayerManager.init_new_game()

	var title_scene := load("res://scenes/title/title.tscn") as PackedScene
	if title_scene != null:
		var title_instance = title_scene.instantiate()
		title_instance.free()

	var safe_zone_scene := load("res://scenes/safe_zone/safe_zone.tscn") as PackedScene
	if safe_zone_scene != null:
		var safe_zone_instance = safe_zone_scene.instantiate()
		add_child(safe_zone_instance)
		if safe_zone_instance.has_method("setup"):
			safe_zone_instance.call("setup", 1)
		safe_zone_instance.queue_free()

	print("--- Nearest safe floor ---")
	print("Floor 1 -> safe: %d (expected 1)" % _get_nearest_safe_floor(1))
	print("Floor 5 -> safe: %d (expected 1)" % _get_nearest_safe_floor(5))
	print("Floor 10 -> safe: %d (expected 10)" % _get_nearest_safe_floor(10))
	print("Floor 15 -> safe: %d (expected 10)" % _get_nearest_safe_floor(15))
	print("Floor 55 -> safe: %d (expected 50)" % _get_nearest_safe_floor(55))

	print("--- Teleport unlock ---")
	print("Initial teleports: %s" % str(PlayerManager.player_data.unlocked_teleports))
	PlayerManager.player_data.unlocked_teleports.append(10)
	print("After unlock 10F: %s" % str(PlayerManager.player_data.unlocked_teleports))

	print("--- Floor advance logic ---")
	var safe_floors: Array = _get_safe_floors()
	print("Safe floors: %s" % str(safe_floors))
	var next_after_9: int = 10
	print("After 9F: next=%d, is_safe=%s (expected 10, true)" % [
		next_after_9,
		safe_floors.has(next_after_9),
	])
	var next_after_2: int = 3
	print("After 2F: next=%d, is_safe=%s (expected 3, false)" % [
		next_after_2,
		safe_floors.has(next_after_2),
	])

	print("--- Save check ---")
	print("Has save slot 1: %s" % SaveManager.has_save(1))

	PlayerManager.init_new_game()
	print("=== End Game Flow Test ===")


func _flood_fill(nodes: Array, start_id: int) -> Array:
	var visited: Array = []
	var queue: Array = [start_id]

	while not queue.is_empty():
		var current: int = int(queue.pop_front())
		if visited.has(current):
			continue

		visited.append(current)
		for raw_node in nodes:
			var node: Dictionary = raw_node
			if int(node.get("id", -1)) != current:
				continue

			var connections: Array = Array(node.get("connections", []))
			for raw_connection in connections:
				var connection_id: int = int(raw_connection)
				if not visited.has(connection_id):
					queue.append(connection_id)
			break

	return visited


func _test_full_battle() -> void:
	PlayerManager.init_new_game()
	PlayerManager.learn_skill("skill_fireball")
	PlayerManager.equip_active_skill("skill_fireball", 0)
	PlayerManager.learn_skill("skill_spark")
	PlayerManager.equip_active_skill("skill_spark", 1)

	await SceneManager.change_scene("res://scenes/battle/battle.tscn")

	var battle_scene = SceneManager.get_current_scene()
	if battle_scene != null and battle_scene.has_method("start_battle"):
		battle_scene.start_battle(
			["enemy_fire_sprite"],
			{
				"floor": 5,
				"familiar_id": "familiar_fire_imp",
				"familiar_level": 3,
			}
		)
