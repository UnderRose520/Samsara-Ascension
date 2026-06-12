# UI 资产与布局清单：道心选择 · 天赋突破 · 战斗 HUD

**用途：** 美术/策划换皮对照表 — 每个槽位对应文件路径、屏幕位置、显示内容、**是否应为 PNG 资产**，以及重设计建议。  
**基准分辨率：** 1920×1080（**设计基准**；Godot 逻辑视口当前为 **1280×720**，见 `game/project.godot`）  
**多分辨率策略：** 详见 [`UI资产提示词_金碧仙宫风格.md`](UI资产提示词_金碧仙宫风格.md) **§0**（纵横比、@2x、像素密度）  
**代码入口：** 统一路径常量见 [`game/assets/asset_paths.gd`](../game/assets/asset_paths.gd)。  
**设计规范：** 详见 [`docs/UIUX_轮回仙途_v1.0.md`](UIUX_轮回仙途_v1.0.md) §5.1、§5.3、§4.1。

---

## 0. 资产 vs 代码：什么该做 PNG？

| 类型 | 应做成 **资产（PNG / 9-slice）** | 应用 **代码 / Theme** 即可 |
|------|----------------------------------|----------------------------|
| 面板外框 | 卷轴边、金角、玉简底、Modal 九宫格 | 纯色半透明底（`StyleBoxFlat`）作占位 |
| 图标 | 道心/天象/法术/灵石/境界/天赋分类 | — |
| 进度条 | HP/灵力/Combo 的 9-slice fill | 纯渐变条（`HudHpBar._draw`） |
| 装饰条 | 技能栏底饰、标题横条、分隔线 | 1px 代码描边（临时） |
| 文字 | — | 所有 Label（标题、描述、数值） |
| 遮罩 | 全屏氛围图（如玉阙殿） | `ColorRect` 半透明 dimmer |
| 按钮 | 可选按钮皮肤图集 | 当前 `PrimaryButton` / `SecondaryButton` Theme |
| 动效 | 粒子贴图（VFX 库内） | 入场 tween、hover 上浮、槽位数字变化 |
| 布局 | — | 锚点、Margin、HBox/VBox |

**原则：** 需要仙侠气质、可换肤、九宫格拉伸的 → **资产**；会随数据频繁变、或可用 Token 配色的 → **代码**。

---

## 1. 总览

| 界面 | 场景/脚本 | CanvasLayer | 说明 |
|------|-----------|-------------|------|
| 道心选择（Setup） | `game/scenes/ui/run_setup_panel.tscn` / `.gd` | 70 | 开局选难度、种子、踏入轮回 |
| 道心卡片组件 | `game/ui/components/dao_heart_card.tscn` / `.gd` | — | 三张卡片：问道 / 悟道 / 证道 |
| **境界突破 / 天赋三选一** | `game/scenes/ui/breakthrough_panel.tscn` / `.gd` | **45** | 破境后选 1 天赋；760×360 Modal + 槽位动画 + 卷轴三卡 |
| **天赋卡片组件** | `game/ui/components/talent_card.tscn` / `.gd` | — | 卷轴卡 + 境界图标 + hover；数据来自 CSV |
| 战斗 HUD | `game/scenes/ui/hud.tscn` / `.gd` | 10 | 战斗内四区布局 |
| 左上修士面板 | `game/ui/components/hud_character_panel.tscn` | — | 真元/灵力/构筑/灵石 |
| 右上天气面板 | `game/ui/components/hud_weather_panel.tscn` | — | 天象/因果/灵宠 |
| 底中技能栏 | `game/ui/components/hud_skill_dock.tscn` | — | Q/E/R 圆槽 |
| 敌人头顶血条 | `game/ui/components/world_enemy_health_bar.tscn` | 世界空间 | 细条，无装饰框 |

---

## 2. 道心选择页（Run Setup）

### 2.1 屏幕布局示意

```
┌─────────────────────────────────────────────────────────────┐
│  [全屏背景 bg_jade_palace_hall]                              │
│  [半透明遮罩 Dimmer]                                         │
│                                                              │
│  大道无形          ┌─────────────────────┐          仙途无尽  │
│  (竖排对联)        │  选择道心 · 入轮回   │          (竖排对联)│
│  x≈-480           │  [问道][悟道][证道]  │          x≈+480   │
│                    │  详情 / 碎片 / 种子  │                     │
│                    │  [轮回成长][踏入轮回]│                     │
│                    └─────────────────────┘                     │
│                    居中 640×590                                │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 层级与位置

| 节点 | 类型 | 锚点/位置（1080p） | 尺寸 | 说明 |
|------|------|-------------------|------|------|
| `Backdrop` | TextureRect | 全屏 | — | 玉阙殿大厅背景 |
| `Dimmer` | ColorRect | 全屏 | — | 墨绿半透明 `#062E0B` @ 58% |
| `Panel` | PanelContainer | 屏幕中心 | **640×590** | `offset ±320, ±290~300` |
| 对联 Label（代码生成） | Label | 中心 ±480px 水平 | 约 48×240 | 「大道无形」「仙途无尽」竖排 |
| `Hearts` | HBoxContainer | Panel 内居中 | 3×168 宽卡片 | 间距 12px |

**Panel 内边距：** Margin 24/20/24/20；VBox 行间距 14px。

### 2.3 资产槽位

| 槽位 ID | 当前文件 | AssetPaths 常量 | 推荐规格 | 视觉描述 |
|---------|----------|-----------------|----------|----------|
| SETUP_BG | `game/assets/ui/bg_jade_palace_hall.png` | `MENU_BACKDROP` | **1920×1080+** 或可平铺 | 玉阙殿内景，暗部占主导，中央留 UI 空间 |
| SETUP_PANEL | 代码 StyleBoxFlat + `panel_ninepatch_256.png`（`UiHelpers.apply_panel_polish`） | `PANEL_NINEPATCH` | 九宫格 **256×256**，边距 32 | 深色玉简面板 + 金边；可换专用 Setup 框 |
| DAO_ASK | `game/assets/ui/dao_heart_ask_128.png` | `DAO_HEART_ICONS["ask"]` | **128×128** | 问道模式图标（平易入道） |
| DAO_ENLIGHTEN | `game/assets/ui/dao_heart_enlighten_128.png` | `DAO_HEART_ICONS["enlighten"]` | **128×128** | 悟道模式图标（标准） |
| DAO_PROVE | `game/assets/ui/dao_heart_prove_128.png` | `DAO_HEART_ICONS["prove"]` | **128×128** | 证道模式图标（极限） |

**道心卡片（DaoHeartCard）**

| 属性 | 值 |
|------|-----|
| 最小尺寸 | **168×200** |
| 图标区 | 72×72，居中 |
| 标题字号 | 20px，金色 `#FFD700` |
| 副标题字号 | 11px，secondary |
| 选中态 | 玉绿底 + 2px 暖金边 + 阴影；未选中 1px 软金边 |
| 卡片框贴图 | **暂无独立 PNG**，纯 StyleBoxFlat；后续可加 `dao_heart_card_frame.png` |

### 2.4 文案与逻辑（非资产，供对照）

| 控件 | 默认/动态文案 | 数据源 |
|------|---------------|--------|
| Title | 选择道心 · 入轮回 | 固定 |
| Detail | 悟道：标准体验… | 选中卡片 `HEART_DEFS.detail` |
| ShardLabel | 心魔碎片 n/3 · 已觉醒道统 n | `SaveManager` |
| PointsLabel | 轮回点 n · 可永久强化… | `SaveManager` |
| HeartDemonCheck | 心魔强化开局… | 碎片≥3 时显示 |
| SeedInput | 局种子 / 留空随机 | 用户输入 |
| StartButton | 踏入轮回 | — |

**三种道心（`run_setup_panel.gd` → `HEART_DEFS`）**

| key | 标题 | 副标题 | 效果摘要 |
|-----|------|--------|----------|
| ask | 问道 | 平易入道 | 敌人 -20% 真元，数量 -1，无心魔试炼台 |
| enlighten | 悟道 | 标准体验 | 标准体验，机缘房 20% 心魔试炼台 |
| prove | 证道 | 极限试炼 | 敌人 +20% 真元，数量 +1，必遇心魔试炼台 |

---

## 3. 战斗 HUD

### 3.1 屏幕布局示意

```
┌─────────────────────────────────────────────────────────────┐
│ ┌─修士面板 320px─┐                    ┌─天气面板 280px─┐   │
│ │ 关卡/波次/种子  │                    │ ☀ 烈阳·地形      │   │
│ │ 真元条 ████     │                    │ 下一天象 · —     │   │
│ │ 灵力条 ████(占位)│                    │ 因果/试炼摘要    │   │
│ │ 连击 x3         │                    │ 🐾 灵宠/CD       │   │
│ │ 道路/build…     │                    └──────────────────┘   │
│ │ 灵石 💎 240     │                                          │
│ └─────────────────┘                                          │
│                    [ 习得 · xxx Toast ]                       │
│                    ┌── Q ── E ── R ──┐                        │
│                    └  底中技能栏   ┘                          │
│              WASD 移动 · 空格闪避 …（底栏提示）                 │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 根节点位置（`hud.tscn` → `Root`）

| 区域 | 锚点容器 | 偏移（left, top, right, bottom） | 宽度 |
|------|----------|----------------------------------|------|
| 左上修士 | `CharacterAnchor` | (14, 14, 334, 390) | **320px** |
| 右上天气 | `WeatherAnchor` | 右对齐 (-294, 14, -14, 150) | **280px** |
| 底中技能 | `SkillDock` | 底中 (-168,-96, 168,-22) | **336px** |
| 操作提示 | `HintLabel` | 底中 y=-16，宽 720 | 9px muted |
| 习得 Toast | `LearnToastPanel` | 中心 (-260,-80, 260,-8) | **520×72** 级 |

---

## 4. 左上：HudCharacterPanel

**场景：** `game/ui/components/hud_character_panel.tscn`  
**脚本：** `hud_character_panel.gd`  
**最小宽度：** 320px；内容区 Margin 12/10。

### 4.1 资产槽位

| 槽位 ID | 当前文件 | AssetPaths 常量 | 推荐规格 | 说明 |
|---------|----------|-----------------|----------|------|
| CHAR_PANEL_FRAME | `hud_panel_bg_320x448.png` | `HUD_PANEL_BG` | **320×448** 或可拉伸 | 卷轴/玉简底图，opacity≈42% |
| CHAR_ACCENT | ColorRect（代码着色） | — | 3px 宽竖条 | 关卡强调色，非 PNG |
| HP_BAR | `progress_hp_9slice.png` | `PROGRESS_HP` | 9-slice，高约 16–22 | 真元条填充；数值叠在条上 |
| MANA_BAR | `progress_mana_9slice.png` | `PROGRESS_MANA` | 9-slice | 灵力条（**占位 68/100**，系统未接入） |
| COMBO_TRACK | `combo_track_256x8.png` | `COMBO_TRACK` | **256×8** | Combo 觉醒进度条 fill |
| GOLD_ICON | `elem_wood_32.png`（临时） | `ICON_SPIRIT_STONE` | **16–32px** | 灵石图标，**待换** `icon_spirit_stone_32.png` |

### 4.2 内容与字号

| 节点 | 字号 | 颜色/样式 | 动态内容示例 |
|------|------|-----------|--------------|
| TitleLabel | 18 | 关卡强调色 + 金描边 | 炼气期 / 关卡名 |
| WaveLabel | 11 | secondary | 房间 · 第 n 波 / 魔劫进度 |
| SeedLabel | 10 | muted | 种子 12345 · 训练 |
| HpBar 数值 | 10 | 白字居中 | 92 / 100 |
| ManaBar 数值 | 10 | 略灰（占位） | 68 / 100 |
| ComboLabel | 11 | 连击时 fire 色 | 连击\n3 |
| RealmLabel | 11 | 淡紫 | 炼气 · 槽位 3 |
| BuildLabel | 11 | secondary | 层 · 术1 体0 契0 |
| DaoLabel | 11 | 金/soft | 道统 · xxx 2/5 |
| ComboTrackLabel | 10 | secondary / fire | Combo 名 1/3 |
| AffixLabel | 10 | secondary，自动换行 | 词条 2/5 · 雷法… |
| SkillLabel | 10 | secondary | 功法 · 烈焰掌 Lv.1 |
| GoldLabel | 12 | 金色 | 灵石 240 |

**BuildScroll：** 最小高度 120px，超出可滚动。

---

## 5. 右上：HudWeatherPanel

**场景：** `game/ui/components/hud_weather_panel.tscn`  
**最小宽度：** 280px。

### 5.1 资产槽位

| 槽位 ID | 当前文件 | AssetPaths 常量 | 推荐规格 | 说明 |
|---------|----------|-----------------|----------|------|
| WEATHER_PANEL_FRAME | `panel_ninepatch_256.png` | `HUD_WEATHER_PANEL` | 九宫格 **256×256** | **占位**；建议专用 `hud_weather_panel_280x120.png` |
| WEATHER_ICON | `weather_*.png` | `WEATHER_ICONS[id]` | **32×32** | 见下表 8 种天象 |
| PET_RING | `pet_avatar_ring_40.png` | `PET_AVATAR_RING` | **24–40px** | 灵宠头像外环 |
| PET_SPRITE | `sprites/pet_huo_ying_32.png` | `PET_HUO_YING` | **32×32** | 当前仅火萤；多宠物需扩展 |

**天象图标清单（`WEATHER_ICONS`）**

| weather_id | 文件 | 玩家名示例 |
|------------|------|------------|
| clear | `weather_clear_32.png` | 晴 / 烈阳 |
| rain | `weather_rain_32.png` | 雨 |
| thunder | `weather_thunder_32.png` | 雷 |
| fire | `weather_fire_32.png` | 火劫 |
| wind | `weather_wind_32.png` | 罡风 |
| fog | `weather_fog_32.png` | 雾 |
| snow | `weather_snow_32.png` | 雪 |
| sand | `weather_sand_32.png` | 沙 |

### 5.2 文案

| 节点 | 说明 |
|------|------|
| WeatherLabel | `{天象名} · {地形}`，16px |
| NextLabel | **占位** 固定「下一天象 · —」（预报 API 未实现） |
| MetaLabel | 心魔试炼 / 碎片 / 善恶意等，10px |
| PetLabel | 灵宠名 · V 或 CD 秒数 |

---

## 6. 底中：HudSkillDock & SpellSlot

**场景：** `game/ui/components/hud_skill_dock.tscn` + `spell_slot.tscn`

### 6.1 资产槽位

| 槽位 ID | 当前文件 | AssetPaths 常量 | 推荐规格 | 说明 |
|---------|----------|-----------------|----------|------|
| SKILL_DOCK_FRAME | `panel_ninepatch_256.png` | `HUD_SKILL_DOCK_FRAME` | 宽 **~360×80** 装饰条 | **占位**；建议 `hud_spell_dock_frame.png` 含底栏金饰 |
| SPELL_Q | `spell_q_fire_40.png` | `SPELL_ICONS["q"]` | **40×40** | Q 槽法术图标 |
| SPELL_E | `spell_e_thunder_40.png` | `SPELL_ICONS["e"]` | **40×40** | E 槽 |
| SPELL_R | `spell_r_water_40.png` | `SPELL_ICONS["r"]` | **40×40** | R 槽 |
| SPELL_*_LOCKED | `spell_*_locked_40.png` | `SPELL_ICONS["*_locked"]` | **40×40** | 未解锁灰态 |
| SLOT_EMPTY | `spell_slot_empty_40.png` | （未接常量） | **40×40** | 空槽占位 |
| SLOT_LOCKED | `spell_slot_locked_40.png` | （未接常量） | **40×40** | 锁定槽边框 |

### 6.2 布局与交互

| 属性 | 值 |
|------|-----|
| Dock 位置 | 底中，距底边 22–96px |
| 单槽 dock 尺寸 | **56×56** 圆形容器 |
| 图标区 | 44×44 |
| 键位徽章 | Q/E/R，10px，顶中金色圆角底 |
| 冷却 | `SpellIconFrame` 扇形遮罩（代码绘制，非 PNG） |
| 槽间距 | 10px |

---

## 7. 中央 Toast & 其他战斗 UI

| 槽位 | 文件 | AssetPaths | 尺寸 | 触发 |
|------|------|------------|------|------|
| 习得卷轴底 | `scroll_toast_520x72.png` | `SCROLL_TOAST` | **520×72** | `EventBus.learn_feedback` |
| 面板底（Toast 外框） | `panel_ninepatch_256.png` | `PANEL_NINEPATCH` | 九宫格 | `UiHelpers.apply_panel_polish` |

**Toast 位置：**

- spell / rebind：屏幕中心偏上（y≈-80）
- skill：左上 (16, 400) 附近

**Toast 文字色（`hud.gd` → `LEARN_TOAST_COLORS`）**

| accent | 颜色用途 |
|--------|----------|
| spell | 金色 `#FFD700` |
| rebind | 冰蓝 |
| skill | 浅绿 |

---

## 8. 世界空间：敌人血条

**场景：** `game/ui/components/world_enemy_health_bar.tscn`  
**挂载：** `TrainingDummy` 等敌人，offset 约 (-28,-36)~(28,-24)。

| 属性 | 说明 |
|------|------|
| 尺寸 | 约 **56×12** |
| 样式 | 纯 StyleBoxFlat，**无 PNG 框** |
| 数值 | 可选显示 n/max |
| 开关 | `SaveManager.show_enemy_hp` |

**后续可选资产：** `enemy_hp_bar_9slice.png`（细条 9-slice，无背景板）。

---

## 9. 换皮工作流

1. **替换 PNG：** 保持文件名不变，覆盖 `game/assets/ui/` 下对应文件（Godot 自动重载）。
2. **新增专用图：** 在 `asset_paths.gd` 增加常量，并在组件 `_ready` / `apply_polish` 中改引用（如 `HUD_WEATHER_PANEL` → 新路径）。
3. **程序化生成：** 部分占位图由 `game/tools/generate_2d_sprites.py` 生成，改脚本后重新跑工具。
4. **验收：** 1080p 下检查四区不重叠；**1280×720**（逻辑视口）、**16:10**、**21:9** 抽查锚点与背景裁切；战斗内真元受击闪白、法术 CD 环正常。分辨率策略见 [`UI资产提示词_金碧仙宫风格.md` §0](UI资产提示词_金碧仙宫风格.md)。

---

## 10. 境界突破 / 天赋三选一（Breakthrough）

**UI 编号：** UI-05（见 UIUX §5.3）  
**触发：** 破境房间 → `EventBus.breakthrough_requested` → `run_controller.gd`  
**数据：** `game/data/talents/breakthrough_talents.csv`（按 `realm_level` 抽 3 选 1）

### 10.1 实现状态（2026-06-10 重设计已落地）

| 项目 | 实现 | 说明 |
|------|------|------|
| 面板 | ✅ | 居中 **760×360**，ninepatch + Modal 标题条 + 金色分隔线 |
| 标题 | ✅ | `{境界名} 破境 · 择一天赋`（`Title` Label） |
| 词条槽 | ✅ | 独立 `SlotRow`：`词条槽  {before}  →  {after}`，目标数字 **0.32s 延迟 + 缩放动画** |
| 背景 | ✅ 弱化 | 复用 `bg_jade_palace_hall.png` @ **22%** + dimmer `#0D051E` @ 65% |
| 天赋卡 | ✅ | 210×200 卷轴 + **48×48 境界图标** + hover 卷轴高亮 + `bind_hover_lift` |
| 境界图标 | ⚠️ 占位 | `AssetPaths.talent_realm_icon()`：优先 `talent_icon_realm_1~5.png`，缺失时回退 `elem_*_32` |
| VFX | ✅ | 打开/确认均为 `"dao"` 粒子 + `UiTokens.ELEM_WOOD`（非金色 burst） |
| 习得 Toast | ⏳ 待接 | 破境解锁 E/R 槽时 HUD Toast 由 `spell_progress.gd` 负责，与本 Modal 独立 |

### 10.2 屏幕布局示意（当前实现）

```
┌─────────────────────────────────────────────────────────────┐
│  [Backdrop bg_jade_palace_hall @ 22%]                        │
│  [Dimmer #0D051E @ 65%]                                      │
│                                                              │
│              ┌──────────────────────────────┐                │
│              │ [ModalTitleBar 720×52]       │  ← PNG 资产    │
│              │  筑基 破境 · 择一天赋         │  ← Title Label │
│              │  词条槽  3  →  5            │  ← SlotRow 动画 │
│              │ ─── divider_gold ───         │  ← PNG 分隔线   │
│              │ [卷轴卡1] [卷轴卡2] [卷轴卡3] │                │
│              │  图标      图标      图标     │  ← 见 10.4     │
│              │  天赋名    天赋名    天赋名   │  ← CSV 文案    │
│              │  描述…     描述…     描述…    │  ← TEXT_SECONDARY │
│              │ [择此天赋] [择此天赋] [择此天赋]│ ← Theme 按钮  │
│              └──────────────────────────────┘                │
│                    居中 760×360                              │
└─────────────────────────────────────────────────────────────┘
```

### 10.3 层级与位置（当前实现）

| 节点 | 类型 | 锚点/位置 | 尺寸 | 资产? |
|------|------|-----------|------|-------|
| `Backdrop` | TextureRect（代码 `_apply_weak_backdrop`） | 全屏 | — | **是** `MENU_BACKDROP` @ 22% |
| `Dimmer` | ColorRect | 全屏 | — | **否** `#0D051E` @ 65% |
| `Panel` | PanelContainer | 屏幕中心 | **760×360** | 框体 **是**（ninepatch） |
| `ModalTitleBar` | TextureRect（`decorate_modal_header`） | Title 上方 | 高 44 | **是** `MODAL_TITLE_BAR` |
| `Title` | Label | Panel 顶 | 24px 金 + 描边 | **否** |
| `SlotRow` | HBoxContainer | Title 下 | 间距 8 | **否** |
| `SlotPrefix` / `BeforeLabel` / `ArrowLabel` / `AfterLabel` | Label | SlotRow 内 | 15–18px | **否**；After 玉绿 `ELEM_WOOD` 色 |
| `UiGoldDivider_*` | TextureRect（`add_gold_divider`） | Cards 上方 | 高 6 | **是** `DIVIDER_GOLD` |
| `Cards` | HBoxContainer | Panel 内 | 3×210 + 间距 12 | **否**（布局） |
| `TalentCard` ×3 | 实例 | Cards 内 | **210×200** / 卡 | 见 10.4 |

**Panel 内边距：** Margin 20/16；VBox 间距 **12px**。

### 10.4 天赋卡片（TalentCard）资产槽位

| 槽位 ID | 当前文件 | AssetPaths 常量 | 推荐规格 | 资产? | 说明 |
|---------|----------|-----------------|----------|-------|------|
| TALENT_CARD_FRAME | `talent_scroll_210x200.png` | `TALENT_SCROLL` | **210×200** | **是** | 卷轴竖版外框；hover 时 `modulate` 暖色高亮 |
| TALENT_REALM_ICON | 占位 `elem_*_32.png` | `talent_realm_icon(realm)` | **48×48** | **是（待专图）** | 优先 `talent_icon_realm_{1~5}.png`；回退见 `TALENT_REALM_ICON_FALLBACK` |
| TALENT_EFFECT_BADGE | **缺失** | — | **24×24** | 可选 | 攻/防/真元/天机 等分类小标 |
| CARD_PANEL_BG | — | — | — | **否** | `StyleBoxEmpty`，依赖 FrameBg |
| NAME / DESC | — | — | — | **否** | CSV `name` / `description`；描述色 `TEXT_SECONDARY` |
| SELECT_BTN | — | Theme | 高 40 | **否** | `PrimaryButton`「择此天赋」 |

**卡片内边距：** Margin 14/10/14/12；VBox 间距 **6px**；图标区 `IconRow` 居中 48×48。  
**交互（代码）：** 入场 stagger、`UiAnimations.bind_hover_lift(3px)`、hover 卷轴高亮、选中后 `modal_close` + dao 粒子。

**境界图标占位映射（`TALENT_REALM_ICON_FALLBACK`，专图缺失时使用）：**

| `realm_level` | 占位文件 | 境界（示例） |
|---------------|----------|--------------|
| 1 | `elem_wood_32.png` | 炼气 |
| 2 | `elem_earth_32.png` | 筑基 |
| 3 | `elem_fire_32.png` | 金丹 |
| 4 | `elem_thunder_32.png` | 元婴 |
| 5 | `elem_chaos_32.png` | 渡劫 |

专图命名：`talent_icon_realm_{1~5}.png`，放入 `game/assets/ui/` 后由 `AssetPaths.talent_realm_icon()` 自动优先加载。

### 10.5 突破 Modal 级资产槽位

| 槽位 ID | 当前文件 | AssetPaths 常量 | 推荐规格 | 资产? |
|---------|----------|-----------------|----------|-------|
| BT_MODAL_PANEL | `panel_ninepatch_256.png` | `PANEL_NINEPATCH` | 256 九宫格 | **是** |
| BT_TITLE_BAR | `modal_title_bar_720x52.png` | `MODAL_TITLE_BAR` | **720×52** | **是（已接入）** |
| BT_BG_BACKDROP | `bg_jade_palace_hall.png` | `MENU_BACKDROP` | 1920×1080+ | **是** @ 22% 弱化 |
| BT_DIVIDER | `divider_gold_256x2.png` | `DIVIDER_GOLD` | 256×2 | **是（已接入）** |
| BT_BG_OVERLAY | **缺失** | — | 1920×1080 @ 20% | 可选专用氛围（替代弱化 hall） |
| BT_SLOT_ARROW | **缺失** | — | 32×32 `→` 装饰 | 可选；当前用 Label `→` |
| BT_VFX_BURST | VfxManager 粒子 | — | — | **半资产**；类型 `"dao"`，色 `ELEM_WOOD` |

### 10.6 文案与数据（非资产）

| 控件 | 动态内容 | 数据源 |
|------|----------|--------|
| Title | `{境界名} 破境 · 择一天赋` | `breakthrough_panel.gd` + `RunContext.realm_name()` |
| BeforeLabel | 破境前词条槽 `{before}` | `context.slots_before` / `RunContext.affix_slot_max()` |
| AfterLabel | 破境后词条槽 `{after}`（动画） | `context.slots_after` / `RunContext.preview_slots_after_breakthrough()` |
| NameLabel | 天赋名 | CSV `name` |
| DescLabel | 效果描述 | CSV `description` |
| Icon | 境界分类图 | CSV `realm_level` → `AssetPaths.talent_realm_icon()` |
| 选中后 | 应用 `effect1` DSL | `AffixHolder.apply_talent` |

**CSV 字段：** `id`, `name`, `realm_level`, `effect1`, `description`  
**示例天赋（每境 3 个，抽 3 选 1）：** 气海扩元、灵台清明、剑意初萌（炼气）… 详见 `breakthrough_talents.csv`。

### 10.7 资产 / 代码分工汇总（本页）

```
[资产 PNG — 已有 / 占位]
  talent_scroll_210x200.png       ← 卡框
  panel_ninepatch_256.png         ← Modal 底
  modal_title_bar_720x52.png      ← 标题条（已接入）
  divider_gold_256x2.png            ← 标题与卡片区分隔
  bg_jade_palace_hall.png         ← 弱化全屏背景 @ 22%
  elem_*_32.png                   ← 境界图标占位（realm 1–5 映射见 asset_paths）

[资产 PNG — 待新增]
  talent_icon_realm_1~5.png       ← 五境专用图标（覆盖占位即可，无需改代码）
  breakthrough_bg_overlay.png     ← 可选专用破境氛围
  talent_badge_*.png              ← 可选效果类型角标

[代码 / Theme]
  Dimmer ColorRect
  Title + SlotRow 四 Label + 槽位计数动画
  CSV 驱动的 name / description / realm_level
  PrimaryButton ×3
  UiAnimations 入场 / modal_open / bind_hover_lift
  VfxManager.spawn_world("dao", ELEM_WOOD)
```

---

## 11. 三页视觉统一建议

| 共用资产 | 道心 Setup | 天赋突破 | 战斗 HUD |
|----------|------------|----------|----------|
| `panel_ninepatch_256.png` | Modal 面板 | Modal 面板 | Toast 底 |
| `modal_title_bar_720x52.png` | — | **已接入** | — |
| `divider_gold_256x2.png` | — | **已接入** | — |
| 金边卷轴/竖卡 | 道心卡（代码框） | **talent_scroll** + hover 高亮 | — |
| `bg_jade_palace_hall.png` | 全屏背景 | **弱化背景 @ 22%** | — |
| 主按钮样式 | 踏入轮回 | 择此天赋 | — |
| 32px 元素图标 | — | 境界图标（**占位 elem_*，待专图**） | 天象/灵石/法术 |

---

## 12. 待补资产清单（建议优先级）

| 优先级 | 资产名（建议） | 页面 | 用途 | 参考尺寸 |
|--------|----------------|------|------|----------|
| P0 | `talent_icon_realm_1~5.png` | 突破 | 五境天赋分类图标（覆盖 `elem_*` 占位） | 48×48 |
| P0 | `talent_scroll_210x200.png` 重绘 | 突破 | 卷轴卡框（选中/未选中变体） | 210×200 |
| P0 | `icon_spirit_stone_32.png` | HUD | 灵石专用图标（当前 `elem_wood` 占位） | 32×32 |
| P0 | `hud_weather_panel_280x120.png` | HUD | 右上天气专用框 | 280×120 九宫格 |
| P0 | `hud_spell_dock_frame.png` | HUD | 底中技能栏装饰 | ~360×72 |
| P1 | `dao_heart_card_frame.png` | Setup | 道心卡片外框 | 168×200 九宫格 |
| P1 | `breakthrough_bg_overlay.png` | 突破 | 破境专用氛围（替代弱化 hall） | 1920×1080 |
| P1 | `hud_mana_bar_label.png` | HUD | 灵力条小标 | 可选 |
| P2 | `talent_badge_*.png` | 突破 | 效果类型角标 | 24×24 |
| P2 | `bt_slot_arrow_32.png` | 突破 | 槽位箭头装饰（替代 Label `→`） | 32×32 |
| P2 | `enemy_hp_bar_9slice.png` | 战斗 | 敌人头顶血条 | 高 8–12 |
| P2 | `weather_forecast_icon_16.png` | HUD | 下一天象小图标 | 16×16 |

**已从待办移除（代码已接入）：** `modal_title_bar_720x52.png` 接入突破页。

---

## 13. 相关代码索引

| 功能 | 文件 |
|------|------|
| 路径常量 / 天赋图标 | `game/assets/asset_paths.gd` → `TALENT_REALM_ICON_FALLBACK`, `talent_realm_icon()` |
| HUD 样式工厂 | `game/ui/hud_styles.gd` |
| HUD 事件接线 | `game/scenes/ui/hud.gd` |
| Setup 逻辑 | `game/scenes/ui/run_setup_panel.gd` |
| 道心卡片 | `game/ui/components/dao_heart_card.gd` |
| **突破 Modal** | `game/scenes/ui/breakthrough_panel.gd` |
| **天赋卡片** | `game/ui/components/talent_card.gd` |
| **天赋池 / 抽取** | `game/systems/realm/talent_selector.gd` |
| **天赋配置表** | `game/data/talents/breakthrough_talents.csv` |
| 资源条 HP/灵力 | `game/ui/components/hud_resource_bar.gd` |
| UI 规范 Token | `game/ui/theme/ui_tokens.gd` |
| Modal 面板抛光 | `game/ui/ui_helpers.gd` → `apply_panel_polish`, `decorate_modal_header`, `add_gold_divider` |

**文档版本：** 2026-06-10 · 含道心 Setup、**天赋突破三选一（重设计已落地）**、战斗 HUD 四区布局。
