# 《轮回仙途》Godot 4.6 客户端

## 运行

```powershell
& "D:\AI\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe" --path "D:\AI\project\godot\Samsara Ascension\game"
```

## 当前进度

### Phase 2 ✅
词条、Combo、功法、清场三选一、爆燃、连击慢动作

### Phase 3 ✅（含 2026-06-10 深化）
道心开局、境界突破、Build 可视化、前世遗泽、完整流程、灵宠、天象、战斗反馈

- **结构化关卡**：`StageGenerator` + `RoomLayoutGenerator`（障碍/地形槽）+ `WaveComposer`（多波/精英词缀）
- **敌人池 CSV**：`enemies.csv` / `stage_enemy_pools.csv` / `elite_affixes.csv`，多 archetype 与关底 Boss
- **天气 × 地形**：`TerrainSystem` 可走入地形池 + 乱石碰撞；积水减速；伤害桶 B 联动
- **架构（2026-06-10）**
  - **涌潮 / 布局 / 索敌 / VFX**：`HordeController`、`TargetingConfig`（CSV）、`VfxManager` 粒子池
  - **RunContext 拆分**：`CombatRngService` · `EntityCache` · `SpellProgress` · `KarmaTracker`
  - **弹幕工厂**：系统层发 `EventBus` 信号，`CombatSpawner` 实例化场景（无 system→scene preload）
  - **战斗房基类**：`ArenaBase` ← `run_controller` / `training_arena` 共用刷怪与涌潮逻辑
- **确定性随机**：`RunRng` + `CombatRngService` + 按房间派生子种子；详见 [`docs/features/seed-reproducibility.md`](../docs/features/seed-reproducibility.md)
- **索敌 v2**：`auto_aim` / `auto_attack` 双开关 + 评分优先级；详见 [`docs/features/combat-targeting-priority.md`](../docs/features/combat-targeting-priority.md)
- **种子复现 UI**：开局输入种子 · HUD/Esc 显示与复制

> 完整变更记录：[`docs/implementation-log.md`](../docs/implementation-log.md)

### Phase 4 ✅
- **随机事件房**：8 常规/天象 + 心魔试炼台 + **因果事件**（善/恶/贪/道心，善名远播需善念）
- **心魔试炼**：悟道 20% / 证道必出 / 问道不出；碎片 + 心魔强化开局
- **道统觉醒**：5 条通用道统
- **五重天流程**：炼气→筑基→金丹→元婴→渡劫（5 关 Boss）
- **八种天象**：晴/雨/雷/烈阳/罡风/迷雾/霜雪/沙暴
- **坊市择路**：战斗清场后可踏入坊市（购词条/仙品/调息丹）
- **轮回成长**：结算获轮回点，开局可升级真元/灵石/重随折扣

### Phase 1 战斗补全 ✅
- **Q/E/R 主动法术**：CSV 驱动，独立冷却与蓄力
- **法术解锁/换绑**：突破解锁 E/R；词条 `unlock_spell` / `bind_spell` 可提前解锁或换绑
- **敌人技能框架**：近战 / 弹幕 / 狙击 / 冲刺，按 archetype 配置
- **4 敌编队**：狂战 → 符师 → 弩手 → 投弹（第 2 关起战斗房至少 4 敌）
- **Boss 三阶段**：血量阈值切换技能池（初境 → 劫火四起 → 天罚降世）
- **习得反馈**：屏幕中央 Toast + 法术栏高亮（`EventBus.learn_feedback`）

## 一局结构（每关）

战斗 ×2（**魔劫涌潮**：持续刷怪 · 斩够配额或倒计时结束）→ **机缘房** → 关底 Boss → 突破 → 词条 → 择路（可坊市/调息）

### 魔劫涌潮（战斗房）

| 重天 | 斩魔配额 | 时限 | 每波刷怪 |
|------|----------|------|----------|
| 1 | 20 | 2:00 | 4 只/波 |
| 2 | 30 | 2:30 | 5 只/波 |
| 3 | 50 | 3:00 | 6 只/波 |
| 4+ | 70–90 | 3:20+ | 6–7 只/波 |

详情见 [`docs/features/combat-horde-mode.md`](../docs/features/combat-horde-mode.md)

## 操作

- 开局选道心 → 可选 **局种子**（留空随机）→ **轮回成长** → **踏入轮回**
- **WASD** 移动 · **空格** 闪避 · **左键** 攻击 · **Q/E/R** 法术 · **V** 灵宠协同
- **Esc** 暂停（血条/飘字、自动瞄准/自动普攻、**复制本局种子**）
- HUD 顶栏显示 **种子** 编号；复现规则见 `docs/features/seed-reproducibility.md`
- 战斗后择路可进 **坊市** · 机缘房三选一 · Boss 后突破 · 凑词条觉醒道统

## 战斗技能（Phase 1 补全）

### 玩家主动法术
- **Q · 烈焰弹**：开局可用
- **E · 雷击印**：炼气关底突破解锁（词条 **九霄雷引** 可提前解锁）
- **R · 玄冰扇**：筑基关底突破解锁（词条 **玄冰残卷** 可提前解锁）
- **换绑**：**连环雷诀** → E 换为连环雷 · **玄冰枪谱** → R 换为玄冰枪
- 配置表：`data/spells/active_spells.csv` · DSL：`unlock_spell:e` / `bind_spell:r:spell_id`

### Boss 阶段技能
- 配置表：`data/enemies/boss_phases.csv`
- **初境**（100%～60%）：近身 + 劫火
- **劫火四起**（60%～30%）：近身 + 猛扑 + 劫火
- **天罚降世**（30% 以下）：天罚雨八连 + 近身 + 猛扑

### 敌人技能框架
- 配置表：`data/enemies/enemy_skills.csv` + `enemy_archetypes.csv`
- **训练木人**：近身击
- **投弹木人**（4 敌末位）：近身击 + 灵弹
- **弩手木人**（4 敌倒数第二）：近身击 + 穿云箭
- **狂战木人**（4 敌首位）：震地 + 狂扑
- **符师木人**（4 敌第二位）：灵弹 + 符扇五连
- **4 敌同场固定编队**：狂战 → 符师 → 弩手 → 投弹（5 敌中间加训练木人）
- **精英战房**（combat_hard）：同上编队，仅 HP 倍率更高
- **关底守将**：近身击 + 劫火三连（含三阶段切换，见上）

### 习得提示

| 触发 | 示例 |
|------|------|
| 炼气/筑基突破 | `突破习得 · E 雷击印 · 词条槽 5` |
| 词条解锁法术 | `词条解锁 · E 雷击印` |
| 词条换绑 | `法术换绑 · 连环雷` |
| 功法层解锁 | `功法精进 · 烈焰掌 第2层` |

- HUD 中央 **LearnToast** 大字显示约 3 秒淡出
- 习得 E/R 时左侧法术栏短暂高亮
- 信号：`EventBus.learn_feedback(text, accent)`，`accent` 为 `spell` / `rebind` / `skill`

## 配置表索引

| 路径 | 用途 |
|------|------|
| `data/spells/active_spells.csv` | 玩家 Q/E/R 法术 |
| `data/enemies/enemy_skills.csv` | 敌人技能 |
| `data/enemies/enemy_archetypes.csv` | 敌人 archetype → 技能组 |
| `data/enemies/boss_phases.csv` | Boss 阶段与技能池 |
| `data/combat/combat_hordes.csv` | 魔劫涌潮配额/时限 |
| `data/combat/targeting_config.csv` | 索敌评分参数 |
| `data/rooms/obstacle_templates.csv` | 战斗房障碍 |
| `data/rooms/room_layouts.csv` | 战斗房布局 |
| `data/affixes/affixes.csv` | 词条（含 `unlock_spell` / `bind_spell`） |

## Autoload 索引

| 名称 | 路径 | 职责 |
|------|------|------|
| `EventBus` | `autoload/event_bus.gd` | 全局信号（含弹幕 `spawn_*_projectile_requested`） |
| `RunContext` | `autoload/run_context.gd` | 局状态、种子派生、跑图进度 |
| `CombatRngService` | `autoload/combat_rng_service.gd` | 战斗暴击/状态 RNG |
| `EntityCache` | `autoload/entity_cache.gd` | 玩家/灵宠节点缓存 |
| `SpellProgress` | `autoload/spell_progress.gd` | 法术槽解锁与默认绑定 |
| `KarmaTracker` | `autoload/karma_tracker.gd` | 业力、事件出现次数 |
| `CombatSpawner` | `autoload/combat_spawner.gd` | 弹幕场景工厂 |
| `VfxManager` | `autoload/vfx_manager.gd` | 粒子对象池 |
| `WeatherSystem` / `TerrainSystem` | `systems/world/` | 天象与地形 |

## 设计文档

- **GDD 玩法：** 仓库根目录 `GDD_轮回仙途_v6.0.md`
- **UI/UX 美术：** [`docs/UIUX_轮回仙途_v1.0.md`](../docs/UIUX_轮回仙途_v1.0.md)（Token、组件、全界面规范）
- **实现日志：** [`docs/implementation-log.md`](../docs/implementation-log.md)（近期功能与架构变更）
- **索敌 / 自动攻击：** [`docs/features/combat-targeting-priority.md`](../docs/features/combat-targeting-priority.md)
- **种子复现：** [`docs/features/seed-reproducibility.md`](../docs/features/seed-reproducibility.md)
- **魔劫涌潮：** [`docs/features/combat-horde-mode.md`](../docs/features/combat-horde-mode.md)
