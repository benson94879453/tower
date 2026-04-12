# UI Overhaul Plan — Mage's Ascent (魔導之塔)

> **Created**: 2026-04-11
> **Scope**: Element icons, color depth, layout compactness, visual polish
> **Constraint**: All visual = procedural geometry, zero external images

---

## Design Decisions

| Question | Decision |
|----------|----------|
| Node map element icons? | Show zone element as subtle background tint behind battle nodes, NOT individual element icons per node |
| Wind spiral at small sizes? | Use simplified "swoosh" — 3-point curved arc with hook, not a true spiral |
| Non-element items in inventory? | No icon — only show element icon when item has an `element` property |
| Water shape? | Sine wave (3-peak wave) as per GDD "波浪形" |

---

## Phase 1: Foundation — Element Icon System + Color Expansion

> **Goal**: Build the reusable drawing primitives and color constants that all later phases depend on.
> **Complexity**: Medium
> **Files**: `draw_shape.gd`, `theme_constants.gd`

### Task 1.1: Add 8 element icon shape functions to `draw_shape.gd`

Add these static functions. Each returns `PackedVector2Array` for the element's icon shape:

```gdscript
static func get_element_icon(element: String, center: Vector2, size: float) -> PackedVector2Array
```

**Shapes per element** (centered on `center`, fits in bounding box `size x size`):

| Element | Shape | Construction |
|---------|-------|-------------|
| **fire** | Triangle pointing UP | 3-point regular polygon (3 sides), the existing `get_sharp_triangle` |
| **water** | Sine wave (3 peaks) | 7-point polyline: bottom-left → wave crest/trough ×3 → bottom-right, filled as polygon with flat bottom |
| **thunder** | Lightning bolt | 6-point zigzag polygon: top → right-jog → left-jog → bottom, like ⚡ |
| **wind** | Swoosh arc | 5-point curved shape: a thick arc with a hook tail, like a simplified Gust |
| **earth** | Square (rotated 0°) | 4-point regular polygon (4 sides, no rotation), solid square |
| **light** | 4-point star | `get_star(center, size*0.45, size*0.2, 4)` — 4-pointed star |
| **dark** | Crescent moon | Two overlapping circles offset horizontally; return the outer arc points of the crescent (approximate with 10+ points) |
| **none** | Circle | `get_circle(center, size*0.4, 16)` — simple circle |

Also add a **draw helper**:

```gdscript
static func draw_element_icon(canvas: CanvasItem, element: String, center: Vector2, size: float, color: Color = Color.WHITE) -> void
```

This draws the shape filled with `color` and a thin outline. Size maps:
- `size = 14.0` → small icon (skill cards, inline)
- `size = 20.0` → medium (enemy panels, turn order)
- `size = 28.0` → large (detail views)

### Task 1.2: Add skill type indicator functions to `draw_shape.gd`

```gdstack
static func get_skill_type_icon(skill_type: String, center: Vector2, size: float) -> PackedVector2Array
static func draw_skill_type_icon(canvas: CanvasItem, skill_type: String, center: Vector2, size: float, color: Color) -> void
```

| Skill Type | Shape | Description |
|-----------|-------|-------------|
| `attack_single` | Small sword (line + crossguard) | Vertical line + small horizontal crossbar near top |
| `attack_all` | 3 horizontal lines | Stacked dash marks suggesting "spread" |
| `heal` | Plus/cross | `+` shape |
| `buff` | Upward triangle | Small ▲ |
| `debuff` | Downward triangle | Small ▼ |
| `status` | Exclamation mark | `!` simplified as line + dot |
| `shield` | Shield outline | Rounded top + pointed bottom (like a kite shield) |
| `passive` | Interlocking rings | Two small overlapping circles |

### Task 1.3: Expand `theme_constants.gd` color constants

Add to existing file:

```gdscript
# Element-specific background tints (very subtle, for panel backgrounds)
const ELEMENT_BG_TINT := {
    "fire": Color("#2A1515"),
    "water": Color("#152035"),
    "thunder": Color("#2A2A15"),
    "wind": Color("#152A1A"),
    "earth": Color("#2A2215"),
    "light": Color("#252530"),
    "dark": Color("#1A1528"),
    "none": Color("#1A1A2E"),
}

# Zone ambient colors (10 zones, matches GDD chapter 5)
const ZONE_AMBIENT := {
    "zone1": {"bg": Color("#1A1A2E"), "accent": Color("#888888")},
    "zone2": {"bg": Color("#2E1A1A"), "accent": Color("#FF4444")},
    "zone3": {"bg": Color("#1A2E2E"), "accent": Color("#4488FF")},
    "zone4": {"bg": Color("#1A2E1A"), "accent": Color("#44CC44")},
    "zone5": {"bg": Color("#2E2A1A"), "accent": Color("#AA7744")},
    "zone6": {"bg": Color("#2E2E1A"), "accent": Color("#FFDD00")},
    "zone7": {"bg": Color("#1A1A2E"), "accent": Color("#8844CC")},
    "zone8": {"bg": Color("#2A2A2A"), "accent": Color("#FFFFFF")},
    "zone9": {"bg": Color("#1E1A28"), "accent": Color("#AA66FF")},
    "zone10": {"bg": Color("#251A20"), "accent": Color("#FFD700")},
}

# Status effect colors (for icon rendering)
const STATUS_COLORS := {
    "burn": Color("#FF6633"),
    "poison": Color("#AA44AA"),
    "heavy_poison": Color("#880088"),
    "freeze": Color("#66CCFF"),
    "paralyze": Color("#FFDD00"),
    "sleep": Color("#8888CC"),
    "confuse": Color("#FF88FF"),
    "charm": Color("#FF66AA"),
    "seal": Color("#666666"),
    "curse": Color("#660066"),
    "atk_up": Color("#44CC44"),
    "def_up": Color("#4488FF"),
    "spd_up": Color("#44CCCC"),
    "atk_down": Color("#CC4444"),
    "def_down": Color("#CC6644"),
    "spd_down": Color("#CC8844"),
    "regen": Color("#33FF66"),
    "mp_regen": Color("#3388FF"),
    "reflect": Color("#AAAAFF"),
    "stealth": Color("#88AAAA"),
}
```

**Verification**: Run Godot, confirm no parse errors in theme_constants.gd and draw_shape.gd. Call `DrawShape.get_element_icon("fire", Vector2(100,100), 20.0)` from test.gd and confirm it returns a non-empty PackedVector2Array.

---

## Phase 2: Battle UI — Skill Cards + Enemy Panels

> **Goal**: Apply element icons and color depth to the battle screen (most-seen screen).
> **Dependencies**: Phase 1 complete
> **Complexity**: High
> **Files**: `battle_ui.gd`, `draw_shape.gd`

### Task 2.1: Redesign skill cards in `_populate_skill_list()`

Current skill card structure: `PanelContainer → VBoxContainer → [top_row (HBox: name, type_label), info_row (HBox: MP, PP, CD)]`

**New layout** (more compact, more visual):

```
┌──┬──────────────────────────────────┐
│  │ Skill Name              [Type ▲] │
│🔥│ MP:12  PP:8  CD:0        65 POW  │
│  │                              │
└──┴──────────────────────────────┴──┘
  ↑ element icon (drawn), colored left border stripe
```

Changes:
1. **Left element icon column**: Add a custom Control (30px wide) that draws the element icon via `_draw()`. Use `DrawShape.draw_element_icon()`.
2. **Left border stripe**: Modify card StyleBoxFlat to have `border_width_left = 3` and `border_color = element_color` (keep other borders at 1px with darker color)
3. **Rarity background tint**: Set card `bg_color` to blend between `BG_MID` and `RARITY_COLORS[rarity].bg` based on rarity
4. **Skill type icon**: Replace text `[單體]` with a small drawn icon + abbreviated text. Add `DrawShape.draw_skill_type_icon()` in the top-right area.
5. **Compact spacing**: Reduce content_margin from 10/6 to 6/4, reduce separation from 2 to 1
6. **Power display**: Add base_power value to info_row if > 0

Implementation approach:
- Create a helper class `SkillCardIcon` (inner class or separate small script) extending `Control` that stores element and draws the icon
- Modify `_populate_skill_list()` to use new layout
- The card is still built programmatically (no .tscn change needed)

### Task 2.2: Redesign enemy panels in `_create_enemy_panel()`

Current: 200×150 min size, simple VBox with name + level + spacer + HP bar + HP label + status.

Changes:
1. **Reduce min size** to 160×120 — reduce spacer height, tighten padding
2. **Element icon**: Draw element icon (size 16) to the LEFT of the name label using a small custom Control
3. **Element-tinted background**: Blend `PANEL_BG.darkened(0.2)` with `ELEMENT_BG_TINT[element]`
4. **HP bar gradient**: Replace single-color fill with 3-segment gradient (full HP = bright element color → mid → low HP = darkened). Draw using `draw_bar()` with additional overlapping rects.
5. **Compact spacing**: Reduce VBox separation from 6 to 4, reduce spacer from 4 to 2

### Task 2.3: Add element icons to turn order display

Current: Just colored text labels.

Changes:
1. For each combatant in turn order, draw a small element icon (size 12) before the name
2. Use a HBoxContainer per entry: [icon Control (20px)] [Label]
3. Icon Control is a minimal custom class that draws via `_draw()`

**Verification**: Start a battle. Confirm:
- Skill cards show element icons, left border stripe, rarity-tinted backgrounds
- Enemy panels show element icons, compact layout, gradient HP bars
- Turn order shows small element icons

---

## Phase 3: Color Depth + Visual Polish (All Screens)

> **Goal**: Apply color depth improvements across all UI screens.
> **Dependencies**: Phase 1 (for colors), Phase 2 (for patterns already proven in battle)
> **Complexity**: Medium
> **Files**: `theme_builder.gd`, `battle_ui.gd`, `safe_zone_ui.gd`, `node_map_ui.gd`, `inventory_panel.gd`

### Task 3.1: Enhance `theme_builder.gd` with new type variations

Add these theme type variations:

```gdstack
# Skill card with left accent stripe
set_type_variation("SkillCard", "PanelContainer")

# Gradient progress bars (HP/MP with darker base)
set_type_variation("ProgressBarGradient", "ProgressBar")
```

For SkillCard: bg_color varies by element, left border 3px in element color, other borders 1px subtle.

### Task 3.2: Improve HP/MP bar rendering across all screens

Create a shared utility function:

```gdscript
# In theme_constants.gd
static func apply_gradient_bar(bar: ProgressBar, color_primary: Color, color_dark: Color, bg_color: Color) -> void
```

Implementation: Override `fill` StyleBoxFlat with a color that's the primary, and add a subtle darker overlay at the bottom 30% of the bar height.

Apply to:
- `battle_ui.gd` → `_style_progress_bars()`, `_apply_bar_style()`
- `safe_zone_ui.gd` → `_style_hp_mp_bars()`

### Task 3.3: Node map zone ambient colors

In `node_map_ui.gd`:

1. `_draw_background_grid()`: Change grid color to use zone-specific ambient color (lighter version of zone accent)
2. `_draw_connections()`: Tint connection lines toward zone ambient accent for visited paths
3. Current node glow: Use zone accent color instead of hardcoded gold

Pass zone info to NodeMapUI (add a `zone_id: String` property set during `update_map()` or a separate setter).

### Task 3.4: Inventory panel element icons

In `inventory_panel.gd`:

1. `_refresh_item_list()`: For items with `element` property, draw a small element icon (size 14) before the item name in each row
2. `_show_detail()`: In detail panel, draw a larger element icon (size 24) next to the item name

### Task 3.5: Safe zone visual refresh

In `safe_zone_ui.gd`:

1. Zone label: Color using `ZONE_AMBIENT` accent color
2. Status panel: Add subtle zone-tinted background
3. Facility buttons: Slightly vary button colors per zone (optional, low priority)

**Verification**:
- Run battle: bars have gradient, skill cards have element stripe
- Run exploration: node map uses zone colors for grid and paths
- Open inventory: items with elements show icons
- Visit different safe zones: zone label and background tint change

---

## Phase 4: Edge Cases + Final Polish

> **Goal**: Handle remaining edge cases and ensure visual consistency.
> **Dependencies**: Phase 1-3 complete
> **Complexity**: Low-Medium

### Task 4.1: Element icon fallback handling

Ensure `get_element_icon()` gracefully handles:
- Unknown element string → fallback to "none" circle
- Empty string → fallback to "none"
- Draw with `Color.GRAY` if element color lookup fails

### Task 4.2: Combatant visual update

In `combatant_visual.gd`: Add a small element icon drawn below the main shape when `is_player == false`. This gives enemies an identifiable element marker beyond just color.

### Task 4.3: Responsive sizing audit

Check all panels at different window sizes (1280×720, 1920×1080, 2560×1440):
- Skill cards don't overflow or truncate text
- Enemy panels don't stack weirdly
- Node map nodes remain clickable at smaller sizes

### Task 4.4: Performance check

Element icon drawing uses `_draw()` which redraws every frame. Ensure:
- Icon Controls only `queue_redraw()` when data changes, NOT in `_process()`
- No element icon draws in hidden panels

**Verification**: Full play session test — battle → explore → safe zone → inventory → repeat. No visual glitches, no performance issues.

---

## Execution Order Summary

```
Phase 1 (Foundation)     ─── Parallel: T1.1 + T1.2 + T1.3
                              ↓
Phase 2 (Battle UI)      ─── T2.1 (skill cards) → T2.2 (enemy panels) → T2.3 (turn order)
                              ↓
Phase 3 (All Screens)    ─── Parallel: T3.1 + T3.2 + T3.3 + T3.4 + T3.5
                              ↓
Phase 4 (Polish)         ─── T4.1 → T4.2 → T4.3 + T4.4
```

## Estimated Complexity

| Task | Lines Changed | Difficulty | Subagent Category |
|------|--------------|------------|-------------------|
| T1.1 Element icons | ~120 new | Medium | `deep` |
| T1.2 Skill type icons | ~80 new | Medium | `deep` |
| T1.3 Color constants | ~50 new | Easy | `quick` |
| T2.1 Skill cards redesign | ~100 modified | Hard | `deep` |
| T2.2 Enemy panels | ~60 modified | Medium | `deep` |
| T2.3 Turn order icons | ~40 modified | Easy | `quick` |
| T3.1 Theme variations | ~40 new | Medium | `quick` |
| T3.2 Gradient bars | ~30 new + 20 modified | Medium | `quick` |
| T3.3 Node map colors | ~30 modified | Medium | `quick` |
| T3.4 Inventory icons | ~30 modified | Medium | `quick` |
| T3.5 Safe zone refresh | ~20 modified | Easy | `quick` |
| T4.1-4.4 Edge cases | ~40 modified | Easy | `quick` |

**Total estimated**: ~700 lines changed/added across 8 files.
