class_name ForgeLogic
extends RefCounted

const MAX_ENHANCE_LEVEL := 10
const ENHANCE_SUCCESS_RATE := {
	1: 1.0,
	2: 1.0,
	3: 1.0,
	4: 1.0,
	5: 1.0,
	6: 0.8,
	7: 0.8,
	8: 0.6,
	9: 0.6,
	10: 0.4,
}
const ENHANCE_MATERIAL := {
	"weapon": "mat_iron_ore",
	"armor": "mat_magic_crystal",
	"accessory": "mat_magic_crystal",
}
const ENHANCE_STONE_THRESHOLD := 6


static func get_enhance_cost(item_id: String, current_level: int) -> Dictionary:
	var target_level: int = current_level + 1
	if target_level > MAX_ENHANCE_LEVEL:
		return {}

	var item_data: Dictionary = DataManager.get_item(item_id)
	var item_type: String = String(item_data.get("type", ""))
	var base_price: int = int(item_data.get("buy_price", 100))
	var material_id: String = String(ENHANCE_MATERIAL.get(item_type, "mat_iron_ore"))
	var material_count: int = 1 + current_level
	var gold_cost: int = int(float(base_price) * 0.3 * float(target_level))
	var extra_materials: Array = []
	if target_level >= ENHANCE_STONE_THRESHOLD:
		var stone_count: int = target_level - ENHANCE_STONE_THRESHOLD + 1
		extra_materials.append({
			"id": "mat_enhance_stone",
			"count": stone_count,
		})

	return {
		"target_level": target_level,
		"material_id": material_id,
		"material_count": material_count,
		"extra_materials": extra_materials,
		"gold_cost": gold_cost,
		"success_rate": float(ENHANCE_SUCCESS_RATE.get(target_level, 0.4)),
	}


static func can_enhance(item_id: String, current_level: int) -> Dictionary:
	var cost: Dictionary = get_enhance_cost(item_id, current_level)
	if cost.is_empty():
		return {"can": false, "reason": "max_level"}

	var gold_cost: int = int(cost.get("gold_cost", 0))
	if PlayerManager.player_data == null or PlayerManager.player_data.gold < gold_cost:
		return {"can": false, "reason": "no_gold"}

	var material_id: String = String(cost.get("material_id", ""))
	var material_count: int = int(cost.get("material_count", 0))
	if not PlayerManager.has_item(material_id, material_count):
		return {"can": false, "reason": "no_material"}

	for raw_extra in Array(cost.get("extra_materials", [])):
		if raw_extra is not Dictionary:
			continue
		var extra: Dictionary = raw_extra
		if not PlayerManager.has_item(String(extra.get("id", "")), int(extra.get("count", 0))):
			return {"can": false, "reason": "no_material"}

	return {"can": true, "reason": ""}


static func execute_enhance(item_id: String, current_level: int) -> Dictionary:
	var check: Dictionary = can_enhance(item_id, current_level)
	if not bool(check.get("can", false)):
		return {
			"success": false,
			"enhanced": false,
			"reason": String(check.get("reason", "")),
		}

	var cost: Dictionary = get_enhance_cost(item_id, current_level)
	PlayerManager.spend_gold(int(cost.get("gold_cost", 0)))
	PlayerManager.remove_item(String(cost.get("material_id", "")), int(cost.get("material_count", 0)))
	for raw_extra in Array(cost.get("extra_materials", [])):
		if raw_extra is not Dictionary:
			continue
		var extra: Dictionary = raw_extra
		PlayerManager.remove_item(String(extra.get("id", "")), int(extra.get("count", 0)))

	var rate: float = float(cost.get("success_rate", 1.0))
	var roll: float = randf()
	var enhanced: bool = roll < rate
	return {
		"success": true,
		"enhanced": enhanced,
		"target_level": int(cost.get("target_level", 0)),
		"success_rate": rate,
		"roll": roll,
	}


static func get_dismantle_result(item_id: String, enhance_level: int) -> Dictionary:
	var item_data: Dictionary = DataManager.get_item(item_id)
	if item_data.is_empty():
		return {}

	var item_type: String = String(item_data.get("type", ""))
	if not ["weapon", "armor", "accessory"].has(item_type):
		return {}

	var rarity: String = String(item_data.get("rarity", "N"))
	var base_price: int = int(item_data.get("sell_price", 0))
	var gold: int = int(float(base_price) * 0.5)
	var materials: Array = []
	var primary_mat: String = String(ENHANCE_MATERIAL.get(item_type, "mat_iron_ore"))
	var material_count: int = 1
	match rarity:
		"R":
			material_count = 2
		"SR":
			material_count = 3
		"SSR":
			material_count = 5
		"UR":
			material_count = 8

	material_count += enhance_level
	materials.append({
		"id": primary_mat,
		"count": material_count,
	})

	if rarity != "N":
		var element: String = String(item_data.get("element", ""))
		var crystal_id: String = ""
		match element:
			"fire":
				crystal_id = "mat_fire_crystal"
			"ice", "water":
				crystal_id = "mat_ice_crystal"
			_:
				crystal_id = "mat_magic_crystal"
		materials.append({
			"id": crystal_id,
			"count": 1,
		})

	return {
		"gold": gold,
		"materials": materials,
	}


static func execute_dismantle(equipment_index: int) -> Dictionary:
	if PlayerManager.inventory == null:
		return {"success": false}

	var entry: Dictionary = PlayerManager.inventory.get_equipment_at(equipment_index)
	if entry.is_empty():
		return {"success": false}

	var item_id: String = String(entry.get("id", ""))
	var enhance_level: int = int(entry.get("enhance", 0))
	var result: Dictionary = get_dismantle_result(item_id, enhance_level)
	if result.is_empty():
		return {"success": false}

	PlayerManager.inventory.remove_equipment_at(equipment_index)
	PlayerManager.player_data.inventory_data = PlayerManager.inventory.to_save_dict()

	var gold: int = int(result.get("gold", 0))
	if gold > 0:
		PlayerManager.add_gold(gold)

	for raw_material in Array(result.get("materials", [])):
		if raw_material is not Dictionary:
			continue
		var material: Dictionary = raw_material
		PlayerManager.add_item(String(material.get("id", "")), int(material.get("count", 1)))

	var item_data: Dictionary = DataManager.get_item(item_id)
	return {
		"success": true,
		"item_name": String(item_data.get("name", item_id)),
		"enhance": enhance_level,
		"gold": gold,
		"materials": result.get("materials", []).duplicate(true),
	}


static func can_craft(recipe: Dictionary) -> Dictionary:
	if recipe.is_empty():
		return {"can": false, "reason": "no_recipe"}

	var gold_cost: int = int(recipe.get("gold_cost", 0))
	if PlayerManager.player_data == null or PlayerManager.player_data.gold < gold_cost:
		return {"can": false, "reason": "no_gold"}

	for raw_mat in Array(recipe.get("materials", [])):
		if raw_mat is not Dictionary:
			continue
		var material: Dictionary = raw_mat
		var material_id: String = String(material.get("id", ""))
		var material_count: int = int(material.get("count", 0))
		if not PlayerManager.has_item(material_id, material_count):
			return {"can": false, "reason": "no_material"}

	return {"can": true, "reason": ""}


static func execute_craft(recipe: Dictionary) -> Dictionary:
	var check: Dictionary = can_craft(recipe)
	if not bool(check.get("can", false)):
		return {"success": false, "reason": String(check.get("reason", ""))}

	PlayerManager.spend_gold(int(recipe.get("gold_cost", 0)))
	for raw_mat in Array(recipe.get("materials", [])):
		if raw_mat is not Dictionary:
			continue
		var material: Dictionary = raw_mat
		PlayerManager.remove_item(String(material.get("id", "")), int(material.get("count", 0)))

	var result_id: String = String(recipe.get("result_id", ""))
	PlayerManager.add_item(result_id)
	return {
		"success": true,
		"result_id": result_id,
		"result_name": String(recipe.get("result_name", result_id)),
	}


static func can_synthesize(recipe: Dictionary) -> Dictionary:
	return can_craft(recipe)


static func execute_synthesize(recipe: Dictionary) -> Dictionary:
	return execute_craft(recipe)
