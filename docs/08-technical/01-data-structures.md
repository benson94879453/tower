# 資料結構設計

## 23.1 資料驅動設計原則

所有遊戲內容（技能、敵人、道具、事件）使用 **JSON 資料檔**定義，程式邏輯讀取資料後動態生成內容。這樣的設計便於新增、修改和平衡調整。

## 23.2 核心資料結構

### 角色資料（PlayerData）

```gdscript
# player_data.gd
class_name PlayerData extends Resource

@export var name: String = "艾倫"
@export var level: int = 1
@export var exp: int = 0
@export var gold: int = 0

# 基礎屬性
@export var base_hp: int = 100
@export var base_mp: int = 60
@export var base_matk: int = 15
@export var base_mdef: int = 10
@export var base_patk: int = 8
@export var base_pdef: int = 8
@export var base_speed: int = 15
@export var base_hit: int = 100
@export var base_dodge: float = 5.0
@export var base_crit: float = 5.0

# 當前狀態
@export var current_hp: int = 100
@export var current_mp: int = 60

# 裝備
@export var weapon_id: String = ""
@export var armor_id: String = ""
@export var accessory_ids: Array[String] = []

# 技能
@export var active_skill_ids: Array[String] = []
@export var passive_skill_ids: Array[String] = []
@export var learned_skill_ids: Array[String] = []
@export var skill_proficiency: Dictionary = {}  # skill_id -> proficiency

# 進度
@export var highest_floor: int = 1
@export var unlocked_teleports: Array[int] = [1]
@export var defeated_bosses: Array[int] = []
@export var title: String = "見習法師"
@export var titles_unlocked: Array[String] = ["見習法師"]
```

### 技能資料（SkillData）

```json
{
  "id": "skill_fireball",
  "name": "火球術",
  "element": "fire",
  "type": "attack_single",
  "rarity": "N",
  "base_power": 65,
  "mp_cost": 12,
  "pp_max": 10,
  "hit_rate": 95,
  "priority": 0,
  "cooldown": 0,
  "effects": [
    {"type": "damage", "target": "single_enemy", "power": 65},
    {"type": "status", "target": "single_enemy", "status": "burn", "chance": 10, "duration": 3}
  ],
  "level_scaling": {
    "2": {"power": 75, "effects_override": []},
    "3": {"power": 85, "mp_cost": 14, "effects_override": [
      {"type": "damage", "target": "single_enemy", "power": 85},
      {"type": "status", "target": "single_enemy", "status": "burn", "chance": 20, "duration": 3}
    ]},
    "max": {"power": 95, "mp_cost": 15}
  },
  "mutations": {
    "A": {
      "id": "skill_meteor",
      "name": "隕石術",
      "required_proficiency": 500,
      "required_items": [{"id": "mat_fire_crystal", "count": 5}]
    },
    "B": {
      "id": "skill_exploding_fireball",
      "name": "爆裂火球",
      "required_proficiency": 500,
      "required_items": [{"id": "mat_burst_core", "count": 3}]
    }
  },
  "description": "基礎火系攻擊魔法，對單一目標發射火球"
}
```

### 敵人資料（EnemyData）

```json
{
  "id": "enemy_fire_sprite",
  "name": "火焰精靈",
  "element": "fire",
  "level": 12,
  "stats": {
    "hp": 120, "mp": 50,
    "matk": 30, "mdef": 15,
    "patk": 10, "pdef": 10,
    "speed": 22
  },
  "ai_type": "aggressive",
  "skills": ["skill_spark", "skill_flame_shot"],
  "drops": [
    {"id": "mat_fire_crystal", "rate": 0.30},
    {"id": "item_hp_potion_s", "rate": 0.20},
    {"id": "scroll_spark", "rate": 0.05},
    {"id": "core_fire_imp", "rate": 0.01}
  ],
  "exp": 25,
  "gold": 15,
  "visual": {
    "shape": "triangle",
    "color": "#FF4444",
    "size": "medium",
    "effects": ["flame_top"]
  },
  "floor_range": [11, 19]
}
```

### 道具資料（ItemData）

```json
{
  "id": "item_hp_potion_m",
  "name": "回復藥水（中）",
  "type": "consumable",
  "subtype": "healing",
  "rarity": "N",
  "stackable": true,
  "max_stack": 10,
  "buy_price": 80,
  "sell_price": 40,
  "usable_in_battle": true,
  "usable_in_explore": true,
  "effects": [
    {"type": "heal_hp", "value": 150}
  ],
  "description": "回復 150 HP",
  "available_from_floor": 10
}
```

### 飾品資料（AccessoryData）

```json
{
  "id": "acc_burn_ring",
  "name": "燃燒之戒",
  "rarity": "R",
  "passive_effects": [
    {
      "trigger": "on_fire_skill_hit",
      "effect": "apply_status",
      "status": "burn",
      "duration": 2,
      "chance": 100
    }
  ],
  "description": "火系技能附帶「燃燒」2回合",
  "obtain_info": "熔岩區掉落"
}
```

### 事件資料（EventData）

```json
{
  "id": "event_magic_circle",
  "name": "神秘的魔法陣",
  "type": "discovery",
  "floor_range": [11, 49],
  "weight": 10,
  "description": "地面上有一個殘破的魔法陣...",
  "options": [
    {
      "text": "嘗試修復魔法陣",
      "condition": {"has_skill": "skill_repair"},
      "results": [
        {"type": "item_reward", "item_id": "core_random", "chance": 0.7},
        {"type": "battle", "enemy_id": "enemy_golem", "chance": 0.3}
      ]
    },
    {
      "text": "注入魔力啟動",
      "condition": {"min_mp": 30},
      "cost": {"mp": 30},
      "results": [
        {"type": "item_reward", "item_id": "random_rare_item", "chance": 0.5},
        {"type": "battle", "enemy_id": "enemy_random_elite", "chance": 0.5}
      ]
    },
    {
      "text": "研究魔法陣紋路",
      "condition": null,
      "results": [
        {"type": "research_points", "value": 10}
      ]
    },
    {
      "text": "不理會，繼續前進",
      "condition": null,
      "results": []
    }
  ],
  "conditional_options": [
    {
      "text": "使用鑑定術分析",
      "condition": {"has_skill": "skill_identify"},
      "results": [
        {"type": "reveal_all_options", "description": "看穿魔法陣類型"}
      ]
    }
  ]
}
```

### 使魔資料（FamiliarData）

```json
{
  "id": "familiar_fire_imp",
  "name": "火焰小鬼",
  "element": "fire",
  "type": "attack",
  "base_stats": {
    "hp": 80, "mp": 30,
    "matk": 35, "mdef": 12,
    "patk": 20, "pdef": 10,
    "speed": 28
  },
  "growth_per_level": {
    "hp": 8, "mp": 3,
    "matk": 3, "mdef": 1,
    "patk": 2, "pdef": 1,
    "speed": 2
  },
  "max_level": 50,
  "skill_slots": 2,
  "default_skills": ["skill_flame_claw"],
  "evolution": {
    "target_id": "familiar_inferno_demon",
    "required_level": 25,
    "required_items": [{"id": "mat_fire_crystal", "count": 10}]
  },
  "visual": {
    "shape": "sharp_triangle",
    "color": "#FF6644",
    "size": "small"
  },
  "obtain_source": "熔岩鍛爐區域掉落"
}
```

## 23.3 存檔資料結構

```json
{
  "save_version": "1.0",
  "timestamp": "2025-01-15T14:30:00",
  "play_time_seconds": 36000,
  "player": { "...PlayerData..." },
  "familiars": {
    "party": "familiar_fire_imp_001",
    "storage": ["familiar_fire_imp_001", "familiar_ice_guard_001"]
  },
  "familiar_instances": {
    "familiar_fire_imp_001": {
      "base_id": "familiar_fire_imp",
      "nickname": "",
      "level": 25,
      "exp": 1200,
      "current_hp": 240,
      "skills": ["skill_flame_claw", "skill_fireball"],
      "feed_bonuses": {"matk": 10, "speed": 4}
    }
  },
  "inventory": {
    "consumables": [{"id": "item_hp_potion_m", "count": 5}],
    "materials": [{"id": "mat_fire_crystal", "count": 12}],
    "key_items": ["key_ancient_page_1"],
    "magic_books": ["book_fireball"]
  },
  "equipment": {
    "weapon": {"id": "weapon_fire_staff", "enhance_level": 3},
    "armor": {"id": "armor_apprentice_robe", "enhance_level": 2},
    "accessories": ["acc_burn_ring", "acc_regen_ring", ""]
  },
  "progress": {
    "highest_floor": 25,
    "cleared_floors": [1,2,3,4,5,6,7,8,9,10,11,12],
    "unlocked_teleports": [1, 10, 20],
    "defeated_bosses": [9, 19],
    "main_quest_chapter": 3,
    "completed_quests": ["quest_lost_herbs"],
    "active_quests": ["quest_forge_challenge"],
    "achievements": {"battles_won": 150, "skills_learned": 12}
  },
  "settings": {
    "bgm_volume": 0.8,
    "sfx_volume": 1.0,
    "text_speed": "normal"
  }
}
```
