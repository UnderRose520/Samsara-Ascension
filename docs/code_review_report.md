# 《轮回仙途》代码审查报告

**审查日期：** 2026-06-10（架构条目见文末补充说明）  
**审查基线：** GDD v6.0 / TDD v7.0.1 / UIUX v1.0  
**审查范围：** `game/` 目录下全部 Godot 4.6 GDScript 代码（约 100 个 .gd 文件）  
**审查方法：** 对照设计文档逐系统比对，按严重程度（🔴Critical / 🟡Major / 🟢Minor / 💡Suggestion）分级

---

## 执行摘要

当前代码实现了 **Phase 1–2 核心原型（约 60% 完成度）**：战斗循环可玩，词条系统基本工作，带有 HUD、5关结构、天气系统、灵宠雏形和突破系统。代码整体结构清晰，命名规范一致，使用了 EventBus 模式解耦，数据层采用 CSV 驱动。

**关键差距（相对于 TDD v7.0）：**
- 缺失系统：角色/灵根选择、法器精灵系统、丹药/法宝、无尽模式、上古秘境
- 部分实现：天象×地形交互仍偏浅、关卡生成/敌人池已 CSV 化但内容量不足
- UI 覆盖度高；种子复现、索敌 v2、Seeded RNG 已于 2026-06-10 落地（见 [`implementation-log.md`](implementation-log.md)）

---

## 1. 架构与基础设施（TDD §3–5, GDD §28）

### 1.1 分层架构 ✅

| 设计要求 | 实现状态 | 评分 |
|----------|----------|------|
| Presentation Layer | HUD + 各面板均实现 | ✅ 良好 |
| Game Flow Layer | `RunContext` + `run_controller.gd` 状态机；战斗房共用 `ArenaBase` | ✅ 良好 |
| Simulation Layer | `DamagePipeline` / `WeatherSystem` / `AffixHolder` 等 | ✅ 基本完整 |
| Generation Layer | `StageGenerator` 生成5关骨架 | 🟡 简化 |
| Data Layer | `ConfigRegistry` + `CsvLoader` 编译 CSV | ✅ 良好 |
| Infrastructure | `EventBus` / `SaveManager` / `VfxManager` | ✅ 良好 |

### 1.2 Autoload 初始化顺序

**TDD §5.2 要求：**
```
ConfigRegistry._ready() → SaveManager._ready() → AudioManager._ready() → EventBus → NetManager
```

**实际（project.godot）：**
```
EventBus → ConfigRegistry → SaveManager → RunContext → WeatherSystem → VfxManager
```

🟢 **偏差：** `AudioManager` 在 autoload 列表中但初始化顺序正确——`ConfigRegistry` 先于 `SaveManager`。`WeatherSystem` 放在 autoload 与 TDD 一致。无 `NetManager` 是正确的（Phase 6+）。

### 1.3 通信模式

**EventBus 信号覆盖率（相对于 TDD §3.2）：**

| 信号类别 | 设计要求 | 已实现 | 覆盖率 |
|----------|----------|--------|--------|
| 战斗相关 | damage_dealt, player_died, enemy_killed | 3/3 | 100% |
| 词条/Affix | affix_acquired, affix_choice_requested | 6/6 | 100% |
| 突破/Breakthrough | breakthrough_requested/closed, realm_changed | 3/3 | 100% |
| 路线/Path | path_choice_requested/closed | 2/2 | 100% |
| 天气/Weather | weather_changed | 1/1 | 100% |
| 事件/Event | event_requested/closed | 2/2 | 100% |
| 商店/Shop | shop_requested/closed | 2/2 | 100% |
| 道统/Dao | dao_tradition_awakened/progress | 2/2 | 100% |
| 因果/Karma | karma_changed | 1/1 | 100% |
| 灵宠/Pet | pet_acquired, pet_coord_feedback | 2/2 | 100% |
| Meta | run_started/completed, gold_changed, legacy_* | 5/5 | 100% |

**总计：29 个信号全部实现。** ✅

### 1.4 确定性随机（Seeded RNG）

✅ **TDD §3.3 局内随机已统一走 Seeded RNG（2026-06-10 修复）。**

| 组件 | 实现 | 状态 |
|------|------|------|
| 局种子 | `RunContext.seed_value` + `_bootstrap_rng` | ✅ |
| 子种子派生 | `RunContext.derive_rng_seed(context)` FNV-1a | ✅ |
| 流程随机 | `RunRng.make()` + `run_controller._flow_rng()` 按上下文隔离 | ✅ |
| 战斗随机 | `CombatRngService`（原 `RunContext.combat_roll_*`） | ✅ |
| 关卡生成 | `StageGenerator.generate(dao_heart, KarmaTracker.events_seen)` + `RunRng.stage_room()` | ✅ |
| 词条 roll | `AffixOfferSelector.roll_offers(..., rng)` | ✅ |
| 开局/UI | 道心界面输入种子 · HUD/Esc 显示与复制 · `SaveManager.last_run_seed` | ✅ |

**已修复（原 Critical）：** 移除 `run_controller` 共享 `_rng.randomize()`；暴击/状态触发/敌人生成抖动等不再使用全局 `randf()`。`CombatContextBuilder` 统一伤害上下文；`StageGenerator` 与运行时共用 `stage_room_*` 子种子。详见 [`docs/implementation-log.md`](implementation-log.md)。

**相关文件：** `run_rng.gd`、`run_context.gd`、`combat_rng_service.gd`、`combat_context_builder.gd`、`arena_base.gd`、`run_controller.gd`

> **2026-06-10 架构补充（审查后落地）：** `RunContext` 拆分为 `CombatRngService` / `EntityCache` / `SpellProgress` / `KarmaTracker`；弹幕经 `CombatSpawner` + EventBus；详见 [`implementation-log.md`](implementation-log.md) 最新章节。

---

## 2. 战斗系统（TDD §7, GDD §7）

### 2.1 伤害流水线

**TDD §7.3 要求 10 阶段流水线：**

| 阶段 | 设计 | 实现 | 状态 |
|------|------|------|------|
| 1. 基础伤害 | skill/attack base | `base_damage` | ✅ |
| 2. 属性加成 | element, spirit_root | **未实现** | 🔴 |
| 3. 词条加算 | flat effects | `additive_bonus` (始终 0) | 🟡 |
| 4. 词条乘算 | 桶A，道韵衰减 | `mult_a` + `apply_bucket_multipliers` | ✅ |
| 5. 环境乘算 | 桶B：天象+地形 | `mult_b` via `WeatherSystem.apply_to_context` | 🟡 |
| 6. 伙伴乘算 | 桶C：灵宠+器灵 | `mult_c` via pet `get_mult_c()` | 🟡 |
| 7. 境界乘算 | 桶D：天赋+局外 | `mult_d` | ✅ |
| 8. 暴击 | crit_rate, crit_mult | ✅ | ✅ |
| 9. 防御减免 | target.defense | `calc_mitigation()` | ✅ |
| 10. 后处理 | 触发效果、飘字 | 仅返回 Dictionary | 🟡 |

**具体发现：**

#### 🔴 阶段10后处理严重不足
`damage_pipeline.gd:37` 的 `compute_pve()` 仅返回 `{"final_damage": ..., "is_crit": ...}`。TDD 要求返回 `DamageResult` 结构体，包含触发效果标记、状态施加列表、天机一击队列条目。当前实现中，`on_hit` 效果处理在 `AffixHolder.proc_on_hit()` 中独立执行——不在流水线内。

#### 🟡 阶段5和阶段6耦合松散（部分缓解）
`CombatContextBuilder` 已统一协调天气/地形/灵宠桶；`DamagePipeline` 仍未作为唯一入口编排后处理。

#### 🟡 道韵衰减实现正确但不完整
`apply_bucket_multipliers()` 实现了 `[1.0, 0.8, 0.6]` 衰减，与 TDD §7.4 一致。但仅有桶 A 使用了此函数，桶 B/C/D 未正确汇集多源乘算。

### 2.2 基础战斗参数

| 参数 | GDD/TDD 要求 | 实际值 | 状态 |
|------|-------------|--------|------|
| 移速 | 300 px/s | 300 | ✅ |
| 闪避距离 | 150 px | 150 (DODGE_DISTANCE) | ✅ |
| 无敌帧 | 0.25 s | 0.25 (DODGE_IFRAME) | ✅ |
| 闪避 CD | 1.0s (问道 0.8) | 1.0 (dodge_cooldown) | ✅ |
| 碰撞半径 | 12 px | 12 (draw circle) | ✅ |
| 默认生命 | 100 | 100 | ✅ |
| 默认攻击 | 10 (TDD §7.2) | 10 (PLAYER_ATTACK) | ✅ |
| 默认防御 | 5 | 5 | ✅ |

✅ **基础战斗参数全部正确。**

### 2.3 角色灵根系统

🔴 **GDD §5 要求 6 个角色 × 8 种灵根，当前完全未实现。**

GDD 要求的角色：
- 剑修（Sword Intent 机制）
- 体修（Rage 机制）
- 丹修（Pill Heart 机制）
- 符修（Array 机制）
- 魔修（Demonization 机制）
- 散修（Wanderer 机制）

灵根（Fire/Water/Thunder/Wood/Earth/Chaos/Heavenly/Dual）

当前仅有单一的 "player" 角色，无角色选择、无灵根系统、无独特机制。

### 2.4 操控实现

| 操作 | GDD 要求 | 实现 | 状态 |
|------|----------|------|------|
| WASD 移动 | ✅ | Input.get_vector | ✅ |
| 空格闪避 | ✅ | dodge action → iframe + teleport | ✅ |
| 鼠标瞄准 | ✅ | get_global_mouse_position | ✅ |
| 左键普攻 | ✅ | attack action → _fire_at_mouse | ✅ |
| Q 法术 | ✅ | spell_q → PlayerSpellCaster | ✅ |
| E 法术 | ✅ | spell_e (突破后解锁) | ✅ |
| R 法术 | ✅ | spell_r (突破后解锁) | ✅ |
| V 灵宠协同 | ✅ | pet_skill → try_coordinated_skill | ✅ |
| F 器灵技能 | ❌ | **未实现** | 🔴 |
| 蓄力攻击 | ❌ | **未实现** | 🔴 |
| **总计** | 10 操作 | 8 实现 | 80% |

### 2.5 状态效果

`StatusComponent` 支持 burn / slow / paralyze 三种状态 ✅  
GDD §7 要求的 freeze / poison 未实现 🟡

---

## 3. 词条与构筑系统（TDD §8, GDD §9）

### 3.1 AffixCompiler ✅

- CSV DSL 解析：`flat_attack` / `mult_crit_rate` / `on_hit_status` / `unlock_spell` / `bind_spell` ✅
- 品质映射（common→凡, rare→灵, epic→仙, legendary→天, dao→道）✅
- 分类映射（skill, spell, constitution, divine, synergy, companion）✅
- 元素映射（none/fire/water/thunder/wood/earth/chaos）✅
- 道韵桶（dao_bucket）✅

### 3.2 AffixHolder ✅

- 装备/上限管理 ✅
- 属性重算（flat_attack/defense/max_hp, crit, attack_speed）✅
- 暴燃检测（combust tag + 5 burn stacks → detonate_burn）✅
- Element bias 检测（连续3次同元素）✅
- 道统觉醒检测 ✅
- Combo 发现 ✅
- Spell unlock/bind 通知 ✅

### 3.3 缺失的词条类型

| GDD §9.4 类别 | 设计数量 | 已实现 | 状态 |
|---------------|----------|--------|------|
| 法术词条 | 16+ | ~8（passives） | 🟡 |
| 联动词条 | 11+ | ~4（combo） | 🟡 |
| 伙伴词条 | 15+ | 0 | 🔴 |
| 神通词条 | 4 | 0 | 🔴 |
| 无尽专属 | 6 | 0 | 🔴 |

### 3.4 功法升级系统

`skill_progression.gd` 实现了基于命中计数/kill 的升级 ✅  
但 GDD §9.3 要求每系3本功法各5层（15本功法 × 5层 = 75 层），当前仅有 `lie_yan_zhang` 的骨架。

---

## 4. 关卡与房间生成（TDD §10, GDD §14）

### 4.1 StageGenerator

🔴 **极其简化——与 GDD §14 差距巨大**

| GDD 要求 | 实现状态 |
|----------|----------|
| 5关骨架，每关含 combat×N + event×1 + boss×1 | ✅ 基本实现 |
| 房间类型：combat/elite/shop/event/rest/boss/hidden (7种) | 🟡 仅 combat/event/boss (3种)；elite/shop/rest/hidden 通过硬编码模拟 |
| 障碍物生成与约束校验 | 🔴 未实现——combat_floor 仅绘制地板 |
| 地形元素生成（积水/干燥/冰面等） | 🔴 未实现——天气仅影响数值，不生成可视地形 |
| 敌人组合配表（5关×5-6种敌人） | 🔴 全部使用 training_dummy 木人变体 |
| 波次系统（2-4波/房间，波次间隔） | 🔴 单波全出 |
| 精英词缀（疾速/厚甲/再生等） | 🔴 未实现 |
| 敌人属性按关卡缩放（×1.0→×8.0） | 🟡 仅有 boss 的 HP 缩放 |

### 4.2 run_controller.gd 分析

`run_controller.gd`（539行）是单局核心，处理几乎所有游戏流程。TDD §6.2 状态机建议将 `RunManager` 独立为系统，但当前所有逻辑耦合在一个场景脚本中。

🟡 **关注点：**
- `_spawn_room_enemies()` 硬编码了"木人"名称查找表（行 192-215）——这应该在 CSV 配置中定义
- `_build_shop_offers()` 直接构造商店数据而非通过 ShopSystem
- `_offer_path_choice()` 硬编码了路径选项

---

## 5. 天象与天气系统（TDD §9, GDD §8）

### 5.1 WeatherSystem

✅ CSV 加载 `data/weather/weather.csv`  
✅ `set_weather()` / `apply_to_context()` 用于桶 B 乘算  

🔴 **重大缺失：**

| GDD §8 要求 | 实现状态 |
|-------------|----------|
| 8种天象（烈日/灵雨/雷暴/灵雾/妖风/寒潮/蚀月/七彩祥云） | 🔴 仅加载了 CSV，但天气实际效果仅在 `mult_b` 数值上 |
| 地形元素（干燥区域/积水/冰面/浓雾/电弧区域） | 🔴 **完全未实现** |
| 天象 × 属性交互（爆燃/导电/冻结/蒸汽） | 🔴 **完全未实现** |
| 首次交互慢动作演示 | 🔴 **完全未实现** |
| 灵宠对天象的反应 | 🔴 **完全未实现** |
| 天象预告（按道心难度） | 🔴 **完全未实现** |

`weather_system.gd:37-41` 的 `apply_to_context()` 仅做元素亲和数值修正——这是设计文档中"天象是你的武器"核心卖点的 **最大实现差距**。

---

## 6. UI 系统（UIUX v1.0, GDD §24–25）

### 6.1 Design Token 覆盖

UIUX §3 定义了完整的 Design Token 体系：

| Token 类别 | 定义 | 代码映射 | 状态 |
|------------|------|----------|------|
| 基础面色 | `bg.deep` / `bg.panel` / `bg.panel_alt` | `ui/theme/ui_tokens.gd` | ✅ |
| 文字色 | `text.primary` / `text.secondary` / `text.muted` | ✅ | ✅ |
| 强调色 | `accent.gold` / `accent.gold_soft` | ✅ | ✅ |
| 元素色 | fire/water/thunder/wood/earth/chaos | ✅ (6/6) | ✅ |
| 品质色 | common/rare/epic/legendary/dao | `quality_glow.gd` | ✅ |
| 语义色 | hp/mana/buff/debuff/learn/rebind/skill | ✅ (7/7) | ✅ |

✅ **Design Token 映射完整。**

### 6.2 UI 界面清单

UIUX §4 定义了全部界面：

| 界面 | 实现文件 | 状态 |
|------|----------|------|
| HUD（战斗） | `hud.gd` + 组件 | ✅ 非常完整 |
| 道心选择 | `run_setup_panel.gd` + `dao_heart_card.gd` | ✅ |
| 词条三选一 | `affix_choice_panel.gd` + `affix_card.gd` | ✅ |
| 突破面板 | `breakthrough_panel.gd` + `talent_card.gd` | ✅ |
| 路径选择 | `path_choice_panel.gd` | ✅ |
| 事件面板 | `event_panel.gd` | ✅ |
| 商店面板 | `shop_panel.gd` | ✅ |
| 暂停面板 | `pause_overlay.gd` | ✅ |
| 前世遗泽 | `legacy_select_panel.gd` | ✅ |
| 结算面板 | `run_result_panel.gd` | ✅ |
| 轮回殿/Meta | `meta_upgrade_panel.gd` | ✅ |
| 道统觉醒 | `dao_tradition_overlay.gd` | ✅ |
| 天机一击 | `crit_moment_overlay.gd` | ✅ |
| 伤害飘字 | `combat_feedback_layer.gd` | ✅ |
| 顶部公告 | `top_announcement_overlay.gd` | ✅ |

✅ **15/15 界面均已实现**，远超 Phase 1–2 预期。

### 6.3 HUD 分析

HUD (`hud.gd`, 480 行) 是整个项目最完善的系统：
- 符合 UIUX §3 布局（左信息/右天象/底技能栏）✅
- Combo 追踪条 + 道统进度 ✅
- Learn Toast 动效 ✅
- 低血量脉冲警告 ✅
- 法术槽冷却显示 ✅
- 天气药丸 + 灵石药丸 ✅
- 灵宠状态 CD 显示 ✅

🟡 **HUD 的 accent 颜色随关卡变化（stage_accent），但未使用 UIUX 定义的完整色板。**

---

## 7. 数据架构（TDD §13, GDD §28）

### 7.1 三层数据架构

| 层级 | 设计 | 实现 |
|------|------|------|
| 配表层（CSV） | Excel → CSV | ✅ 现有 CSV 文件 |
| 枚举层 | enum 类型 | 🟡 `game_enums.gd` 基本为空 |
| 运行时层 | `CompiledTag` | ✅ `compiled_tag.gd` |

### 7.2 CSV 配表覆盖率

| 配表 | GDD §28 要求 | 文件 | 状态 |
|------|-------------|------|------|
| 词条 | affixes.csv | ✅ `data/affixes/affixes.csv` | ✅ |
| 功法 | skills.csv | 🟡 未找到独立 skills.csv | 🟡 |
| 法术 | active_spells.csv | ✅ `data/spells/active_spells.csv` | ✅ |
| 灵宠 | pets.csv | ✅ `data/pets/pets.csv` (1只) | 🟡 |
| 天象 | weather.csv | ✅ `data/weather/weather.csv` | ✅ |
| 事件 | events.csv | ✅ `data/events/events.csv` | ✅ |
| 道统 | dao_traditions.csv | ✅ `data/dao/dao_traditions.csv` | ✅ |
| 关卡骨架 | stages.csv | ✅ `data/stages/stages.csv` | ✅ |
| 房间模板 | room_templates.csv | ✅ `data/rooms/room_templates.csv` | ✅ |
| 突破天赋 | talents.csv | ✅ `data/talents/breakthrough_talents.csv` | ✅ |
| Meta升级 | meta_upgrades.csv | ✅ `data/meta/meta_upgrades.csv` | ✅ |
| 敌人配置 | enemies.csv | 🔴 **未找到独立敌人配表** | 🔴 |
| 精英词缀 | elite_affixes.csv | 🔴 **未找到** | 🔴 |
| 关卡布局 | room_layouts.csv | 🔴 **未找到** | 🔴 |

### 7.3 枚举层缺失

`game/core/enums/game_enums.gd` 几乎是空壳：

```gdscript
# 实际内容
enum GameMode { MAIN_RUN, ENDLESS, ANCIENT_REALM }
```

🟡 TDD §36 要求定义完整的枚举体系：
- `TriggerType`（OnAttack, OnHit, OnKill, OnDodge, Passive...）→ 当前使用字符串匹配
- `EffectType`（AddDamage, ApplyStatus, ModifyStat...）→ 当前使用字符串 DSL
- `RoomType`（COMBAT, ELITE, SHOP, EVENT, REST, BOSS, HIDDEN）→ 仅字符串
- `StatusType` → 仅 StatusComponent 中 match 字符串

**影响：** 没有编译期类型检查，字符串拼写错误只在运行时暴露。

---

## 8. 灵宠系统（TDD §23, GDD §12）

### 8.1 当前实现

- `pet_controller.gd`（115行）：仅实现火萤（huo_ying）一只灵宠
- 协同技能（V键 5方向扇形火弹）✅
- 被动普攻（每2.5秒自动射击）✅
- 桶C乘算（1.08）✅

🔴 **GDD §12 要求 6 只灵宠：**
- 火灵雀（火系，冲锋留火带）— 部分实现
- 水灵蛟（水系，回复冰愈）— 未实现
- 雷灵貂（雷系，瞬移雷击）— 未实现  
- 木灵鹿（木系，毒藤缠绕）— 未实现
- 土灵龟（土系，挡刀护盾）— 未实现
- 天机灵狐（光/暗，CD刷新）— 未实现

---

## 9. 道统系统（TDD §8.4, GDD §10.5）

`dao_tradition_registry.gd` 实现了：CSV 加载、条件匹配、`try_awaken()` ✅

🟡 GDD §10.5 要求 7 个通用道统 + 6 个角色专属道统，当前仅有 CSV 中定义的道统。

---

## 10. 商店系统（GDD §11.5）

`shop_panel.gd` + `run_controller._build_shop_offers()` 实现了：
- 调息丹（35% 回血）✅
- 机缘词条 ✅
- 仙品机缘 ✅

🔴 缺失：
- GDD §11 的丹药系统（携带上限、多种丹药效果）
- 法宝系统（完全未实现）

---

## 11. 事件系统（GDD §15）

✅ `event_selector.gd` + `event_resolver.gd` + `event_panel.gd` 实现了基本事件框架。

🟡 GDD §15 / §31 定义了大量事件，当前 CSV 中事件数量未知。

---

## 12. Meta/局外成长（TDD §32, GDD §21）

✅ `meta_upgrade_registry.gd` + `meta_upgrade_panel.gd` 实现了：
- 轮回点数系统
- CSV 驱动的升级列表
- 效果累计（hp, start_gold, reroll_discount）

🔴 缺失：
- 天命种子系统（权重修正）— 完全未实现
- 角色解锁系统
- 图鉴系统

---

## 13. 代码质量

### 13.1 优点

1. **一致性命名**：snake_case 变量/函数，PascalCase 类名，符合 GDScript 惯例
2. **文档字符串**：关键函数有注释，CSV loader 和 compiler 的 DSL 语法清晰
3. **类型提示**：使用了 `class_name`、`const`、`static func` 和基本的类型标注
4. **信号解耦**：`EventBus` 作为中央事件总线，模块间通信规范
5. **数据驱动**：所有游戏内容来自 CSV，运行时编译一次
6. **防御性编程**：`clampi`/`maxf`/`minf` 保护数值边界
7. **paused 检查**：`_physics_process` 正确处理暂停状态

### 13.2 问题

#### ✅ 运行时可复现性（Seeded RNG）— 已修复
原 `run_controller` 使用 `randomize()` / 全局 `randf()` 的问题已修复，见 §1.4。

#### 🟡 字符串魔法值
枚举类型应使用 enum 而非字符串比较（如 `str(room.get("type", "")) == "boss"` 出现 6+ 次）。

#### 🟡 单例查找模式
多处使用 `get_tree().get_first_node_in_group("player")` 查找玩家——在每帧 `_physics_process` 中也做此查找（`training_dummy.gd:146`）。

#### 🟡 紧耦合（部分缓解）
- 伤害上下文已迁至 `CombatContextBuilder`（天气/地形/灵宠）
- `DamagePipeline` 仍未统一协调后处理与 `proc_on_hit`

#### 💡 缺少测试
`damage_pipeline.gd` 的纯函数非常适合单元测试，但当前无测试文件。

#### 💡 魔法数字
`GameConstants` 中部分值未集中管理（如 `ENEMY_BOSS_SPAWN`、`AFFIX_SKIP_REWARD`）。

---

## 14. TDD v7.0 GDD 覆盖度分析表

基于 TDD §18 的框架，逐项评估：

| GDD 章节 | 系统 | TDD 状态 | 代码实现 | 差距评级 |
|----------|------|----------|----------|----------|
| §3 难度系统 | 道心选择 | ✅ 已设计 | ✅ 已实现 | — |
| §4 基础操作 | WASD/闪避/瞄准 | ✅ | ✅ | — |
| §5 角色与灵根 | 6角色×8灵根 | ✅ | 🔴 0% | Critical |
| §6 修炼境界 | 5境界+天赋 | ✅ | ✅ 70% | Major |
| §7 战斗系统 | 10步伤害流水线 | ✅ | 🟡 70% | Major |
| §8 天象地形 | 8天象+地形交互 | ✅ | 🟡 15% | Critical |
| §9 功法词条 | 3层体系 | ✅ | 🟡 55% | Major |
| §10 Build可视化 | 5层体系 | ✅ | 🟡 60% | Major |
| §11 丹药法宝 | 丹药+法宝 | ✅ | 🔴 0% | Critical |
| §12 灵宠系统 | 6灵宠 | ✅ | 🟡 17% | Major |
| §13 器灵系统 | 6器灵 | ✅ | 🔴 0% | Critical |
| §14 关卡生成 | 结构化随机 | ✅ | 🟡 30% | Critical |
| §15 随机事件 | 选择驱动 | ✅ | ✅ 70% | Minor |
| §16 因果系统 | 6标记+事件 | ✅ | 🟡 40% | Major |
| §17 奖励关卡 | 3秘境界面 | ✅ | 🔴 0% | Critical |
| §18 Boss设计 | 5Boss+阶段 | ✅ | 🟡 20% | Critical |
| §19 无尽模式 | 防溢出6层 | ✅ | 🔴 0% | Critical |
| §20 失败重生 | 前世遗泽 | ✅ | ✅ | — |
| §21 局外成长 | 轮回殿 | ✅ | 🟡 50% | Major |
| §22 天命种子 | 权重修正 | ✅ | 🔴 0% | Critical |
| §23 动态难度 | 6层防溢出 | ✅ | 🟡 10% | Major |
| §24-25 UI/UX | Design Token | UIUX v1.0 | ✅ 85% | Minor |

---

## 15. 风险与行动建议

### 🔴 Critical（应立即修复）

| # | 问题 | 文件 | 影响 |
|---|------|------|------|
| ~~1~~ | ~~Seeded RNG 未正确播种~~ | — | ✅ 已修复，见 [`implementation-log.md`](implementation-log.md) |
| 2 | 天象 × 地形交互深度不足 | `weather_system.gd` / `terrain_system.gd` | 核心卖点仍待深化 |
| 3 | 角色/灵根系统未实现 | 缺失文件 | 核心构筑层缺失 |
| ~~4~~ | ~~关卡生成缺少障碍物和地形~~ | `combat_floor.gd` | 🟡 部分实现（布局/地形槽/CSV） |
| ~~5~~ | ~~敌人系统仅木人变体~~ | `training_dummy.gd` | 🟡 部分实现（多 CSV 敌人池 + archetype） |

### 🟡 Major（Phase 3 前应完成）

| # | 问题 |
|---|------|
| 6 | 伤害流水线阶段 10（后处理）不足 |
| 7 | 桶 B/C/D 的多源道韵衰减未实现 |
| 8 | 枚举层基本为空，缺少类型安全 |
| 9 | 灵宠系统仅 1/6 |
| 10 | 功法技能升级仅有骨架 |
| 11 | 器灵系统未开始 |
| 12 | 丹药/法宝系统未开始 |
| 13 | Boss 阶段系统未充分实现 |
| 14 | 波次系统简化为单波全出 |

### 🟢 Minor / 💡 Suggestion

| # | 建议 |
|---|------|
| 15 | 将 `run_controller.gd` 拆分为 RunManager + CombatManager |
| 16 | 为 `DamagePipeline` 添加单元测试 |
| 17 | 字符串 room type 改用 enum |
| 18 | 缓存 `get_first_node_in_group("player")` 结果 |
| 19 | 补充完整 TDD §36 枚举定义 |
| 20 | 添加敌人配置 CSV（替换木人硬编码） |

---

## 16. 总结

**当前代码状态：Phase 1–3 可玩闭环已完成；Phase 4 内容量与系统深度仍在推进。**

2026-06-10 已完成：Seeded RNG 架构、种子 UI、索敌 v2、关卡布局/波次/敌人池 CSV 化（详见 [`implementation-log.md`](implementation-log.md)）。

仍待推进的主要差距：
1. **天象 × 地形交互**——差异化卖点，当前仅有基础渲染与伤害桶
2. **角色与灵根系统**——核心构筑起点，完全缺失
3. **内容量**——敌人/词条/事件池需继续扩充
4. **法器精灵、无尽模式**——GDD Phase 4+ 系统

建议后续按以下优先级推进：
1. ~~修复 RNG seeded~~ ✅
2. 深化地形交互与首次演示慢动作（GDD §8）
3. 角色选择界面 + 至少 2 个可玩角色
4. 锁定目标 UI、每日挑战种子
5. 伤害流水线阶段 10 与桶 B/C/D 道韵衰减补全
