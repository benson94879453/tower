class_name PlayerData
extends Resource

@export var name: String = "艾倫"
@export var level: int = 1
@warning_ignore("shadowed_global_identifier")
@export var exp: int = 0
@export var gold: int = 0

@export var base_hp: int = 100
@export var base_mp: int = 80
@export var base_matk: int = 15
@export var base_mdef: int = 10
@export var base_patk: int = 8
@export var base_pdef: int = 8
@export var base_speed: int = 15
@export var base_hit: int = 100
@export var base_dodge: float = 5.0
@export var base_crit: float = 5.0

@export var current_hp: int = 100
@export var current_mp: int = 80

@export var weapon_id: String = ""
@export var armor_id: String = ""
@export var accessory_ids: Array[String] = []

@export var active_skill_ids: Array[String] = []
@export var passive_skill_ids: Array[String] = []
@export var learned_skill_ids: Array[String] = []
@export var skill_proficiency: Dictionary = {}

@export var highest_floor: int = 1
@export var unlocked_teleports: Array[int] = [1]
@export var defeated_bosses: Array[int] = []
@export var title: String = "見習法師"
@export var titles_unlocked: Array[String] = ["見習法師"]
@export var inventory_data: Dictionary = {}
@export var weapon_enhance: int = 0
@export var armor_enhance: int = 0
@export var accessory_enhances: Array[int] = []
@export var owned_familiars: Array[Dictionary] = []
@export var active_familiar_index: int = -1
@export var discovered_familiar_ids: Array[String] = []
@export var discovered_item_ids: Array[String] = []
@export var discovered_enemy_ids: Array[String] = []
@export var active_quests: Array[Dictionary] = []
@export var completed_quests: Array[String] = []
@export var battle_victories: int = 0
@export var skill_element_usage: Dictionary = {}
