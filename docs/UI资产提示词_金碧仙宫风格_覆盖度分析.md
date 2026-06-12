# 《轮回仙途》UI 资产提示词 — 覆盖度分析报告

**分析日期：** 2026-06-12  
**分析范围：** `docs/UI资产提示词_金碧仙宫风格.md` vs 全部 UI 代码（`asset_paths.gd`、所有 `ui/` 场景/脚本、`ui_tokens.gd`、`hud_styles.gd`、`generate_2d_sprites.py`）  
**对照基准：** `docs/UIUX_轮回仙途_v1.0.md`（UI/UX 设计规范）

---

## 一、总体评估

| 维度 | 结论 |
|------|------|
| **覆盖度** | **85%** — 61 个资产覆盖了核心 UI 路径，但遗漏了约 10 个功能必需的资产 |
| **代码对齐** | **良好** — 与 `asset_paths.gd` 常量一一对应，大部分尺寸/名称匹配 |
| **优先级准确性** | **合理** — P0 资产基本正确，但部分 P1 资产实际应为 P0 |
| **风格一致性** | **有问题** — 色彩体系描述与实际代码 Token 不统一（见 §三） |

---

## 二、遗漏资产清单（按优先级）

### 🔴 P0 — 功能必需，当前用占位符或缺失

#### 2.1 因果（Karma）倾向图标 × 5

| 项目 | 详情 |
|------|------|
| **文件名** | `karma_good_16.png` / `karma_evil_16.png` / `karma_greed_16.png` / `karma_rebellion_16.png` / `karma_dao_heart_16.png` |
| **尺寸** | 16×16（或 20×20） |
| **代码位置** | `event_panel.gd:36` — 当前用 `elem_wood_32.png` **硬编码为所有选项图标** |
| **规范依据** | UIUX §5.6：「选项按钮最多 3 个，带 karma 倾向色点（善/恶/贪/逆）」 |
| **当前状态** | **完全缺失** — 所有事件选项用同一个木头图标占位 |

**提示词建议：**
- **善 (Good)**: 一枚温润白玉环，柔和金色 (#FFD700) 内发光，透明底
- **恶 (Evil)**: 一滴暗红血珠，深红 (#C45C5C) 核心，暗色晕染
- **贪 (Greed)**: 一枚带裂纹的金币，琥珀金 (#F59E0B) 高光
- **逆 (Rebellion)**: 一道逆飞的剑影，暗紫 (#B57EDC) 向上轨迹
- **道心 (Dao Heart)**: 一颗微小金色星辰，明金 (#FFD700) 十字光芒

#### 2.2 治疗/恢复图标

| 项目 | 详情 |
|------|------|
| **文件名** | `icon_heal_32.png` |
| **尺寸** | 32×32 |
| **代码位置** | `shop_panel.gd:73` — 当前用 `PROGRESS_HP`（**HP 条的九宫格纹理**）作为治疗图标 |
| **说明** | 这是明显的占位 hack；HP 条纹理作为图标完全不适合 |
| **当前状态** | **完全缺失** |

**提示词建议：**
> A healing/recovery icon for Chinese xianxia game UI, 32x32 pixels. A luminous teal-green (#4ECDC4) lotus flower or spirit herb with gentle golden (#FFD700) inner glow. The shape is elegant and medicinal — suggesting vitality restoration. Transparent background, game UI icon.

#### 2.3 闪避（御风步）指示器

| 项目 | 详情 |
|------|------|
| **文件名** | `icon_dodge_32.png` |
| **尺寸** | 32×32 |
| **代码位置** | `hud.gd:61` — 仅在 HintLabel 文字中提及 "空格闪避" |
| **规范依据** | GDD §4：「WASD 移动，spacebar 闪避（invincibility frames）」；UIUX §5.1 HUD 底部应有操作提示 |
| **当前状态** | **完全缺失** — 无可视化的闪避冷却/充能指示器 |

**提示词建议：**
> A dodge/dash icon for Chinese xianxia game UI, 32x32 pixels. A stylized afterimage or wind-trail figure in translucent jade-green (#4FD6B8) with motion blur lines. Suggests swift movement and evasion. Transparent background, game UI icon.

#### 2.4 重随（Reroll）图标

| 项目 | 详情 |
|------|------|
| **文件名** | `icon_reroll_24.png` |
| **尺寸** | 24×24 |
| **代码位置** | `affix_choice_panel.gd:16` — RerollButton 纯文本 "重随 (N 灵石)" |
| **当前状态** | **完全缺失** |

#### 2.5 已拥有（已备）角标

| 项目 | 详情 |
|------|------|
| **文件名** | `badge_owned_32.png` |
| **尺寸** | 32×32（角标） |
| **代码位置** | 尚未实现 — `affix_card.gd` / `affix_choice_panel.gd` 均无相关逻辑 |
| **规范依据** | UIUX §5.2：「已拥有词条：卡片角标 '已备'」 |
| **当前状态** | **代码 + 资产均缺失** |

---

### 🟡 P1 — 提升体验，建议补充

#### 2.6 Boss 阶段横幅

| 项目 | 详情 |
|------|------|
| **文件名** | `boss_banner_640x80.png` |
| **尺寸** | 640×80 |
| **代码位置** | `hud.gd:229-234` — Boss 房间标签用普通 Label 显示 "BOSS · 关底" |
| **规范依据** | UIUX §5.8：「Boss 阶段 | 顶栏 Boss 名 + 阶段名 | 2s | boss」 |
| **当前状态** | `top_announcement_overlay.tscn` 复用 `SCROLL_TOAST`，无专用 Boss 横幅 |

#### 2.7 心魔试炼激活指示器

| 项目 | 详情 |
|------|------|
| **文件名** | `icon_heart_demon_trial_24.png` |
| **尺寸** | 24×24 |
| **代码位置** | `hud.gd:302-319` — 试炼状态仅用文本显示在天气面板 `meta_label` |
| **当前状态** | **缺失** — 玩家可能在战斗中忘记已开启心魔试炼 |

#### 2.8 跳过/放弃图标

| 项目 | 详情 |
|------|------|
| **文件名** | `icon_skip_24.png` |
| **尺寸** | 24×24 |
| **代码位置** | `affix_choice_panel.gd:17` — SkipButton 纯文本 "跳过 (+N 灵石)" |
| **当前状态** | **缺失** |

#### 2.9 灵宠协同 CD 环

| 项目 | 详情 |
|------|------|
| **文件名** | `pet_cd_ring_48.png`（或由代码绘制，类似 `SpellIconFrame`） |
| **尺寸** | 48×48 |
| **代码位置** | `hud.gd:322-342` — CD 仅显示为文本 "· 3s" |
| **规范依据** | UIUX §5.1：「灵宠 | 小头像 + 协同 CD 环」 |
| **当前状态** | **缺失** — `pet_avatar_ring_40.png` 仅提供头像外环，无 CD 指示 |

---

### 🟢 P2 — 锦上添花

#### 2.10 关卡章节横幅 × 5

当前 `hud.gd:224` 用普通 Label 显示关卡名。可为每关设计独立横幅（关 1 翠绿山林 / 关 2 灵石洞窟 / ...），尺寸 480×48。

#### 2.11 胜利/道消专用装饰

`run_result_panel.gd` 对胜利和死亡使用同一面板样式（仅文字颜色不同）。建议：
- **胜利** (`victory_beam.png`): 金色光柱/飞升光束叠加层
- **道消** (`death_shatter.png`): 碎裂玉简/暗色褪晕叠加层

#### 2.12 道统觉醒专属图标 × 13（7 通用 + 6 角色专属）

`dao_tradition_overlay.gd` 当前无图标。每个道统可有一枚 64×64 徽章。

#### 2.13 训练模式标识

`RunContext.training_mode` 仅通过文本 "· 训练" 显示。可增设小角标 `badge_training_48x16.png`。

#### 2.14 自动瞄准/自动攻击 HUD 状态灯

暂停菜单可开关 auto-aim / auto-attack（`pause_overlay.gd:14-15`），但 HUD 上无视觉反馈。可增设 8×8 小圆点指示器。

---

## 三、提示词质量问题

### 3.1 🔴 色彩体系描述与实际代码不一致

| 位置 | 提示词文档所述 | 实际代码 (`ui_tokens.gd`) | 差异 |
|------|---------------|--------------------------|------|
| "深翡翠绿底" | `#0D0D0D ~ #1A1A2E` | `BG_DEEP: #06140F` / `BG_PANEL: #0F2A22` | 提示词用了**蓝调暗色**而非翡翠绿 |
| 风格前缀背景 | `deep jade-green (#0D2A22)` | `BG_PANEL: #0F2A22` | 提示词 `#0D2A22` 不存在于任何 Token |
| 面板背景 | `#1A1A2E` | `BG_PANEL_ALT: #1B4438` | `#1A1A2E` 是 UIUX v1.0 的旧色值，已更新为 `#1B4438` |

**建议：** 提示词文档的色彩体系应全面更新为 `ui_tokens.gd` 的实际 金碧仙宫 色板：

```
深翡翠绿底: BG_DEEP #06140F
面板底色:   BG_PANEL #0F2A22
次级面板:   BG_PANEL_ALT #1B4438
鎏金强调:   ACCENT_GOLD #FFD700
玉石绿:     ELEM_WATER #4ECDC4 (实际是 teal，非 jade green)
暗紫:       ELEM_CHAOS #B57EDC
```

### 3.2 🟡 风格前缀中的色值引用问题

风格前缀中写 `#0D2A22` 作为 "deep jade-green dark background"：
- 此色值不在任何 Token 中
- 应改为 `#06140F`（BG_DEEP）或 `#0F2A22`（BG_PANEL）
- 同时写 `#4FD6B8` 作为 "jade gemstone inlays" — 此色不在 Token 中，最接近的是 `#4ECDC4`（ELEM_WATER）

### 3.3 🟡 个别资产尺寸与代码中实际拉伸行为不符

| 资产 | 提示词尺寸 | 实际使用 |
|------|-----------|---------|
| `quality_*_220x280.png` | 220×280 | `affix_card.tscn` 中 FrameBg 是 TextureRect，stretch_mode 非 STRETCH_KEEP，会随卡片缩放 |
| `talent_scroll_210x200.png` | 210×200 | `talent_card.tscn` 中 FrameBg 为全幅 TextureRect，会被拉伸到卡片实际尺寸 |

### 3.4 🟢 `spell_slot_empty_40.png` / `spell_slot_locked_40.png` 的定位

提示词将这两个列为 "已有，需重绘"，且它们确实存在于 `assets/ui/` 并由 `generate_2d_sprites.py` 生成。但：
- `asset_paths.gd` 中 **没有** 对应常量
- `spell_slot.gd` 的视觉样式通过 `HudStyles.spell_dock_slot()` 代码绘制，**不加载这些 PNG**
- 这些文件目前是 "幽灵资产" — 存在但未被使用

**建议：** 要么在 `asset_paths.gd` 中添加 `SPELL_SLOT_EMPTY` / `SPELL_SLOT_LOCKED` 常量并在 `spell_slot.gd` 中应用，要么将其标记为 "待集成"。

---

## 四、代码侧发现的问题

### 4.1 `ICON_SPIRIT_STONE` 用 `elem_wood_32.png` 占位

```gdscript
# asset_paths.gd:32
const ICON_SPIRIT_STONE := UI_ROOT + "elem_wood_32.png"  # 树叶图标当作灵石！
```

提示词已正确识别需要 `icon_spirit_stone_32.png`（item 3.6），但当前代码用了完全不相关的木头元素图标。

### 4.2 `HUD_WEATHER_PANEL` 和 `HUD_SKILL_DOCK_FRAME` 复用同一张图

```gdscript
# asset_paths.gd:30-31
const HUD_WEATHER_PANEL := UI_ROOT + "panel_ninepatch_256.png"
const HUD_SKILL_DOCK_FRAME := UI_ROOT + "panel_ninepatch_256.png"
```

提示词已正确识别这两个需要专用资产（items 3.2, 3.3）。

### 4.3 Event Panel 选项图标全部硬编码为 `elem_wood_32.png`

```gdscript
# event_panel.gd:36
icon.texture = AssetPaths.load_texture(AssetPaths.ELEMENT_ICONS["wood"])
```

所有事件选项 — 无论其 karma 倾向 — 都使用同一个木头图标。需要传入实际图标路径或使用 karma 图标。

### 4.4 Shop Panel 治疗图标使用 HP 条纹理

```gdscript
# shop_panel.gd:73
var icon_path := AssetPaths.PROGRESS_HP if kind == "heal" else AssetPaths.ELEMENT_ICONS["fire"]
```

`PROGRESS_HP` 是 64×16 的九宫格进度条纹理，被缩放成 32×32 图标 — 完全不可用。

---

## 五、补充建议

### 5.1 新增全局风格前缀资产

当前所有资产共用同一条风格前缀。建议为不同资产类别微调前缀：

| 类别 | 前缀调整 |
|------|---------|
| **面板/框架类** | 强调 "jade tablet texture, gold filigree, nine-patch compatible" |
| **图标类** | 强调 "flat icon style, 1.5px stroke, rounded caps, painterly color, transparent background" |
| **战斗精灵类** | 强调 "top-down small sprite, clean silhouette, pixel-art inspired, limited palette" |
| **全屏背景类** | 强调 "cinematic digital painting, no UI elements, atmospheric depth" |

### 5.2 建议的完整 Karma 图标提示词

```
善 (Good) — karma_good_16.png:
> A tiny karma tendency dot "Good/善" for Chinese xianxia game UI, 16x16 pixels. A warm white jade ring with soft golden (#FFD700) inner glow. Pure and luminous. Transparent background, game UI indicator.

恶 (Evil) — karma_evil_16.png:
> A tiny karma tendency dot "Evil/恶" for Chinese xianxia game UI, 16x16 pixels. A dark crimson (#C45C5C) blood-red dot with subtle blackened edges. Sinister and weighty. Transparent background, game UI indicator.

贪 (Greed) — karma_greed_16.png:
> A tiny karma tendency dot "Greed/贪" for Chinese xianxia game UI, 16x16 pixels. A cracked golden (#F59E0B) coin or ingot shape with sharp highlights. Materialistic and fractured. Transparent background, game UI indicator.

逆 (Rebellion) — karma_rebellion_16.png:
> A tiny karma tendency dot "Rebellion/逆" for Chinese xianxia game UI, 16x16 pixels. An upward-pointing dark purple (#B57EDC) sword or arrow silhouette. Defiant and sharp. Transparent background, game UI indicator.

道心 (Dao Heart) — karma_dao_heart_16.png:
> A tiny karma tendency dot "Dao Heart/道心" for Chinese xianxia game UI, 16x16 pixels. A miniature radiant golden (#FFD700) star or diamond with cross-shaped light rays. Transcendent and pure. Transparent background, game UI indicator.
```

### 5.3 建议与 `generate_2d_sprites.py` 同步

当前 `generate_2d_sprites.py` 的 `main()` 函数生成约 40 个资产文件。建议新增生成函数：
- `gen_karma_icons()` — 5 个 karma 倾向图标
- `gen_heal_icon()` — 治疗图标
- `gen_dodge_icon()` — 闪避图标
- `gen_weather_panel_frame()` — 天气面板专用框
- `gen_spell_dock_frame()` — 技能栏装饰框
- `gen_spirit_stone_icon()` — 灵石图标
- `gen_large_element_icons()` — 80px 大元素图标（机缘卡用）
- `gen_realm_icons()` — 5 个境界图标
- `gen_enemy_hp_bar()` — 敌人血条

---

## 六、总结

| 指标 | 数值 |
|------|------|
| 提示词覆盖资产总数 | 61 |
| 已存在文件（需重绘） | 42 |
| 计划新增（正确识别） | 19 |
| **遗漏的关键资产 (P0)** | **5**（karma 图标 ×5 算 1 组、治疗、闪避、重随、已备角标） |
| **遗漏的体验资产 (P1)** | **4**（Boss 横幅、心魔指示器、跳过图标、灵宠 CD 环） |
| **遗漏的锦上添花 (P2)** | **5**（章节横幅、胜负装饰、道统图标、训练标识、自动状态灯） |
| 色彩体系问题 | 3 处色值与代码 Token 不一致 |
| 代码占位符问题 | 4 处硬编码占位需要替换 |

**总体而言，提示词文档覆盖面达到 85%，对核心 UI 路径的资产识别是准确的。主要缺口集中在战斗内交互反馈（karma 图标、闪避指示器、心魔试炼标识）和跨面板复用装饰（治疗图标、重随图标、Boss 横幅）上。色彩体系需与 `ui_tokens.gd` 的实际金碧仙宫色板对齐。**
