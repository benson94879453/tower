# 《魔導之塔 Mage's Ascent》首要主架構任務

> 基於完整企劃書拆分整理後的 Phase 0 + Phase 1 首要開發任務清單
> 目標：建立可運行的最小遊戲核心

---

## 首要任務總覽

### 第一優先：專案基礎建設（Phase 0）

#### T01. 建立 Godot 專案框架
- [ ] 建立 Godot 4.6.2 專案
- [ ] 建立資料夾結構（data/, scenes/, scripts/, assets/, shaders/）
- [ ] 設定 Autoload 單例腳本骨架
  - [ ] GameManager
  - [ ] DataManager
  - [ ] PlayerManager
  - [ ] SaveManager
  - [ ] AudioManager
  - [ ] SceneManager

#### T02. 建立資料管理框架
- [ ] 實作 DataManager（JSON 載入與快取）
- [ ] 建立技能資料範例檔（data/skills/fire_skills.json）
- [ ] 建立敵人資料範例檔（data/enemies/zone1_enemies.json）
- [ ] 建立道具資料範例檔（data/items/consumables.json）
- [ ] 建立使魔資料範例檔（data/familiars/familiars.json）
- [ ] 建立事件資料範例檔（data/events/discovery_events.json）
- [ ] 測試資料載入與解析

#### T03. 建立 UI 主題系統
- [ ] 建立幾何主題資源檔（geometric_theme.tres）
- [ ] 定義色彩系統（元素色、品質色、主色調）
- [ ] 實作幾何圖形繪製工具（DrawShape 類）
- [ ] 建立通用按鈕樣式
- [ ] 建立對話框樣式

#### T04. 建立玩家資料結構
- [ ] 實作 PlayerData（Resource 類別）
- [ ] 實作屬性計算邏輯（基礎值 + 裝備加成 + buff）
- [ ] 實作 PlayerManager（狀態讀寫、升級判定）

---

### 第二優先：核心戰鬥系統（Phase 1）

#### T05. 建立戰鬥場景框架
- [ ] 建立 Battle 場景（battle/battle.tscn）
- [ ] 建立 BattleManager 腳本
- [ ] 建立戰鬥 UI 骨架（BattleUI）
  - [ ] 敵方顯示區（HP 條、名稱、等級）
  - [ ] 我方顯示區（主角 HP/MP、使魔 HP）
  - [ ] 行動選單（技能/道具/使魔/逃跑）
  - [ ] 技能選擇面板

#### T06. 實作回合管理系統
- [ ] 實作 TurnManager
  - [ ] 速度排序邏輯
  - [ ] 優先度處理
  - [ ] 回合流程控制（玩家選擇 → 使魔行動 → 敵人行動 → 結算）
  - [ ] 勝負判定

#### T07. 實作傷害計算系統
- [ ] 實作 DamageCalculator
  - [ ] 基礎傷害公式
  - [ ] 屬性相剋倍率
  - [ ] 暴擊判定與計算
  - [ ] 隨機修正
  - [ ] buff/debuff 修正
  - [ ] 命中判定

#### T08. 實作技能系統基礎
- [ ] 實作 SkillData 結構
- [ ] 實作技能施放邏輯
- [ ] 實作 MP/PP 消耗
- [ ] 實作冷卻系統
- [ ] 實作技能效果類型：
  - [ ] 單體傷害
  - [ ] 全體傷害
  - [ ] 回復
  - [ ] 狀態賦予
  - [ ] 自身增益
  - [ ] 防禦/護盾

#### T09. 實作狀態異常系統
- [ ] 實作 StatusManager
  - [ ] 持續傷害型（燃燒、中毒、猛毒）
  - [ ] 控制型（凍結、麻痺、睡眠、混亂、魅惑）
  - [ ] 弱化型（攻擊/防禦/速度/命中下降、封印、詛咒）
  - [ ] 增益型（攻擊/防禦/速度提升、再生、護盾、反射、隱身）
  - [ ] 回合結束結算
  - [ ] 狀態解除判定

#### T10. 實作敵人 AI
- [ ] 實作 BattleAI
  - [ ] 狂暴型 AI
  - [ ] 謹慎型 AI
  - [ ] 狀態型 AI
  - [ ] 使魔 AI（攻擊/防禦/輔助/待命模式）

#### T11. 實作戰鬥結果系統
- [ ] 經驗值計算與分配
- [ ] 金幣掉落
- [ ] 道具掉落判定
- [ ] 技能領悟判定
- [ ] 升級判定

---

### 第三優先：探索系統骨架（Phase 2 起始）

#### T12. 建立探索場景框架
- [ ] 建立 Exploration 場景
- [ ] 實作 ExplorationManager
- [ ] 實作 FloorGenerator（節點地圖生成）
- [ ] 實作 NodeMap UI（節點繪製與互動）

#### T13. 實作節點互動系統
- [ ] 戰鬥節點 → 觸發 BattleManager
- [ ] 事件節點 → 觸發 EventManager
- [ ] 寶箱節點 → 觸發 ChestUI
- [ ] 中繼節點 → 觸發 RestUI

---

## 任務依賴關係

```
T01 (專案框架)
  └─→ T02 (資料管理)
        └─→ T04 (玩家資料)
              └─→ T05 (戰鬥場景)
                    ├─→ T06 (回合管理)
                    │     └─→ T07 (傷害計算)
                    │           └─→ T08 (技能系統)
                    │                 └─→ T09 (狀態異常)
                    └─→ T10 (敵人AI)
                          └─→ T11 (戰鬥結果)
                                └─→ T12 (探索框架)
                                      └─→ T13 (節點互動)

T03 (UI主題) → 貫穿所有需要 UI 的任務
```

---

## 可驗收標準（M1 里程碑）

完成 T01 ~ T11 後，應能：
1. 啟動遊戲並進入一場戰鬥
2. 選擇技能對敵人造成傷害（含屬性相剋）
3. 敵人自動反擊
4. 戰鬥結束後獲得經驗值與掉落物
5. 狀態異常正常運作

完成 T12 ~ T13 後，應能：
1. 生成一層節點地圖
2. 點擊節點觸發對應事件
3. 戰鬥節點進入戰鬥並返回

---

## 檔案產出對應

| 任務 | 主要產出檔案 |
|------|------------|
| T01 | project.godot, scripts/autoload/*.gd |
| T02 | data_manager.gd, data/**/*.json |
| T03 | themes/geometric_theme.tres, scripts/ui/draw_shape.gd |
| T04 | data/player_data.gd, scripts/autoload/player_manager.gd |
| T05 | scenes/battle/battle.tscn, scripts/battle/battle_manager.gd |
| T06 | scripts/battle/turn_manager.gd |
| T07 | scripts/battle/damage_calculator.gd |
| T08 | data/skill_data.gd, data/skills/*.json |
| T09 | scripts/battle/status_manager.gd |
| T10 | scripts/battle/battle_ai.gd |
| T11 | scripts/battle/battle_result.gd |
| T12 | scenes/exploration/exploration.tscn, scripts/exploration/*.gd |
| T13 | scripts/exploration/node_interaction.gd |
