# 程式架構設計（Godot 4）

## 24.1 場景樹結構

```
Main (Node)
├── GameManager (Autoload Singleton)
│   ├── DataManager      -- 載入/管理所有JSON資料
│   ├── PlayerManager     -- 管理玩家狀態
│   ├── SaveManager       -- 存檔/讀檔
│   ├── AudioManager      -- BGM/SFX管理
│   └── SceneManager      -- 場景切換
│
├── UILayer (CanvasLayer)
│   ├── HUD              -- 常駐顯示
│   ├── DialogBox        -- 對話框
│   ├── NotificationQueue -- 通知佇列
│   └── TransitionEffect  -- 場景轉場特效
│
└── CurrentScene (Node)   -- 動態載入的場景
    ├── TitleScreen
    ├── SafeZone
    │   ├── TownUI
    │   ├── ShopUI
    │   ├── ForgeUI
    │   ├── LibraryUI
    │   ├── FamiliarHouseUI
    │   └── TeleportUI
    ├── Exploration
    │   ├── NodeMap       -- 節點地圖
    │   ├── EventUI       -- 事件介面
    │   └── NodeInteraction -- 節點互動
    └── Battle
        ├── BattleManager  -- 戰鬥主控
        ├── TurnManager    -- 回合管理
        ├── BattleUI       -- 戰鬥介面
        ├── SkillEffect    -- 技能特效
        └── BattleAI       -- 敵人/使魔AI
```

## 24.2 Autoload（全域單例）

| 單例名 | 檔案 | 職責 |
|--------|------|------|
| GameManager | game_manager.gd | 遊戲總管，協調各子系統 |
| DataManager | data_manager.gd | 載入並快取所有JSON資料 |
| PlayerManager | player_manager.gd | 玩家狀態讀寫、升級判定 |
| SaveManager | save_manager.gd | 存檔/讀檔/自動存檔 |
| AudioManager | audio_manager.gd | BGM切換、SFX播放 |
| SceneManager | scene_manager.gd | 場景載入/切換/轉場 |

## 24.3 關鍵系統架構

### 戰鬥系統

```
BattleManager
├── 初始化戰鬥（載入敵人資料、設定場地）
├── TurnManager
│   ├── 計算行動順序（速度排序+優先度）
│   ├── 輪詢每個行動者
│   │   ├── 玩家 -> 等待UI輸入
│   │   ├── 使魔 -> BattleAI.decide_familiar_action()
│   │   └── 敵人 -> BattleAI.decide_enemy_action()
│   └── 執行行動 -> DamageCalculator
├── DamageCalculator
│   ├── 計算基礎傷害
│   ├── 套用屬性倍率
│   ├── 判定暴擊
│   ├── 隨機修正
│   └── 套用buff/debuff修正
├── StatusManager
│   ├── 施加狀態
│   ├── 回合結束結算（DoT/控制/buff倒數）
│   └── 移除到期狀態
└── BattleResult
    ├── 計算獎勵（EXP/Gold/掉落）
    ├── 判定升級
    └── 判定技能領悟
```

### 探索系統

```
ExplorationManager
├── FloorGenerator
│   ├── 生成節點數量（3~4行 x 2~3列）
│   ├── 分配節點類型（按權重表）
│   ├── 生成連線（保證可達性）
│   └── 輸出 NodeMap 資料
├── NodeMap（UI）
│   ├── 繪製節點和連線
│   ├── 標記當前位置
│   ├── 處理點擊事件
│   └── 顯示已探索/未探索
├── NodeInteraction
│   ├── 戰鬥節點 -> 觸發 BattleManager
│   ├── 事件節點 -> 觸發 EventManager
│   ├── 寶箱節點 -> 觸發 ChestUI
│   ├── 商人節點 -> 觸發 ShopUI
│   ├── 中繼節點 -> 觸發 RestUI
│   └── 祭壇節點 -> 觸發 AltarUI
└── EventManager
    ├── 從事件池隨機抽取事件
    ├── 檢查條件選項（技能/道具/屬性）
    ├── 執行選項結果
    └── 發放獎勵/觸發戰鬥
```

## 24.4 資料夾結構

```
res://
├── project.godot
├── data/                    # JSON 資料檔
│   ├── skills/
│   │   ├── fire_skills.json
│   │   ├── water_skills.json
│   │   └── ...
│   ├── enemies/
│   │   ├── zone1_enemies.json
│   │   ├── zone2_enemies.json
│   │   └── ...
│   ├── items/
│   │   ├── consumables.json
│   │   ├── weapons.json
│   │   ├── armors.json
│   │   └── accessories.json
│   ├── familiars/
│   │   └── familiars.json
│   ├── events/
│   │   ├── discovery_events.json
│   │   ├── encounter_events.json
│   │   └── ...
│   ├── quests/
│   │   ├── main_quests.json
│   │   └── side_quests.json
│   └── floors/
│       └── floor_config.json
│
├── scenes/                  # 場景檔
│   ├── main.tscn
│   ├── title/
│   ├── safe_zone/
│   ├── exploration/
│   ├── battle/
│   └── ui/
│
├── scripts/                 # 腳本
│   ├── autoload/
│   │   ├── game_manager.gd
│   │   ├── data_manager.gd
│   │   ├── player_manager.gd
│   │   ├── save_manager.gd
│   │   ├── audio_manager.gd
│   │   └── scene_manager.gd
│   ├── battle/
│   │   ├── battle_manager.gd
│   │   ├── turn_manager.gd
│   │   ├── damage_calculator.gd
│   │   ├── status_manager.gd
│   │   └── battle_ai.gd
│   ├── exploration/
│   │   ├── exploration_manager.gd
│   │   ├── floor_generator.gd
│   │   ├── node_map.gd
│   │   └── event_manager.gd
│   ├── data/
│   │   ├── player_data.gd
│   │   ├── skill_data.gd
│   │   ├── enemy_data.gd
│   │   ├── item_data.gd
│   │   └── familiar_data.gd
│   └── ui/
│       ├── hud.gd
│       ├── dialog_box.gd
│       ├── shop_ui.gd
│       └── ...
│
├── assets/                  # 資源
│   ├── audio/
│   │   ├── bgm/
│   │   └── sfx/
│   ├── fonts/
│   └── themes/
│       └── geometric_theme.tres
│
└── shaders/                 # 著色器
    ├── element_glow.gdshader
    ├── particle_fire.gdshader
    └── transition.gdshader
```
