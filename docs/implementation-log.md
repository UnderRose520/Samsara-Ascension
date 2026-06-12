# 实现日志

记录 Godot 原型 `game/` 的重要功能落地与架构变更。设计细节以 GDD / 各功能文档为准。

---

## 2026-06-10 — 架构重构（RunContext 拆分 · 弹幕工厂 · ArenaBase）

### RunContext 瘦身

`RunContext` 仅保留局核心状态（种子、金币、跑图、境界、道心、灵宠等）。以下职责拆为独立 autoload，降低耦合：

| Autoload | 职责 | 关键 API |
|----------|------|----------|
| `CombatRngService` | 战斗内确定性随机（暴击、状态施加） | `roll_chance()` · `reset()` |
| `EntityCache` | 玩家/灵宠节点缓存 | `get_player()` · `get_pet()` · `invalidate_*()` |
| `SpellProgress` | 法术槽解锁与默认绑定 | `get_unlocks()` · `grant_for_realm()` |
| `KarmaTracker` | 业力 + 事件出现次数 | `add_karma()` · `record_event()` · `events_seen` |

- 局种子与子种子派生仍由 `RunContext.derive_rng_seed()` 统一（`RunRng` 依赖此入口）
- 开局 / 进房：`CombatRngService.reset()`；突破习得：`SpellProgress.grant_for_realm()`

### 系统层 → 场景层：弹幕工厂

系统脚本**禁止** `preload` 战斗场景；改为 EventBus 信号 + `CombatSpawner` 实例化：

| 信号 | 发射方 | 场景资源 |
|------|--------|----------|
| `spawn_player_projectile_requested` | `player_spell_caster` · `pet_controller` | `projectile.tscn` |
| `spawn_enemy_projectile_requested` | `enemy_skill_controller` | `enemy_projectile.tscn` |

`CombatSpawner` 在 `_ready` 中监听信号，payload 含 `position` / `direction` / `damage` / `owner` 等。

### ArenaBase 战斗房基类

`arena_base.gd` 抽取 `run_controller` 与 `training_arena` 约 50% 共用逻辑：

- `combat_floor` + `HordeController` 初始化
- 刷怪环 `_spawn_pos_on_ring`、`_spawn_enemy_dummy`、涌潮 batch
- `_clear_enemies` · `_count_living_enemies` · `_tick_horde` · 击杀回调

子类通过虚方法扩展差异（`_get_horde_room_def` · `_on_horde_cleared` · `_arena_flow_rng` 等）。**注意：** Godot 4 不允许子类重复声明父类已有 `const` / `var`（如 `GameConstants`、`_player`）。

**关键文件：** `arena_base.gd` · `run_controller.gd` · `training_arena.gd` · `combat_spawner.gd` · 各新 autoload

---

## 2026-06-10 — 架构清理 + 战斗地形/积水 + Code Review 修复

### 架构

| 项 | 说明 |
|----|------|
| `HordeController` | 魔劫涌潮状态/计时/刷怪从 `run_controller.gd` 拆出；`RunController` 只负责刷怪与过关 |
| `targeting_config.csv` | 索敌 12 项评分常量迁入 CSV，`TargetingConfig` 加载 |
| `VfxManager` 对象池 | 复用 `Node2D + CPUParticles2D`（上限 40），减少战斗热路径分配 |
| 训练场对齐 | `training_arena` 接入 `combat_floor` 布局/天气 + `HordeController` 涌潮循环 |

### 地形与移动

- 乱石/石柱：`StaticBody2D` 碰撞（layer 1）；天气地形池可走入
- 积水（`wet`）：移速 ×0.62，出水后 1.4s 恢复；天象×地形加成仍可用
- 怪物攻击相位错开：`apply_spawn_stagger` + 轨道/移速抖动，避免齐射

### Bug 修复（Code Review）

- 弹道贴图：`_ready()` 末尾 `_apply_sprite()`
- 自动攻击无目标时仍可手动左键
- 词条面板关闭动画与重随竞态（`_close_token`）
- 法术蓄力方向锁定 `_pending_dir`
- 敌人 fallback 双重绘圆
- `begin_training_run()` 复用 `begin_run(..., is_training=true)`
- 玩家死亡时 `EntityCache.invalidate_player()`

**关键文件：** `horde_controller.gd`、`targeting_config.gd`、`vfx_manager.gd`、`terrain_system.gd`、`player.gd`、`projectile.gd`、`training_arena.gd`

---

## 2026-06-10 — 魔劫涌潮（战斗房玩法重设计）

- 战斗房改为 **持续刷怪 + 击杀配额 + 倒计时**；达标或到时均可过关
- 配额按重天：20 / 30 / 50 / 70 / 90（精英房 +25%），配置于 `combat_hordes.csv`
- HUD 显示 `斩魔 N/M · 分:秒 · 第K波`
- 文档：[`combat-horde-mode.md`](features/combat-horde-mode.md)

---

## 2026-06-10 — 索敌 v2 + 确定性 RNG 架构 + 种子复现

### 自动瞄准 / 自动普攻（索敌 v2）

| 项 | 说明 |
|----|------|
| 双开关 | `auto_aim`（朝向索敌）、`auto_attack`（480px 内自动连射）；Esc 暂停可切换，存档于 `SaveManager` |
| 旧档迁移 | `auto_target` → 同时写入 `auto_aim` + `auto_attack` |
| 评分索敌 | `TargetSelector` v2：威胁圈 > Boss/精英 > 残血 > 距离；粘性 1.15；威胁/Boss 即时切换 |
| 朝向 | `CombatAim` 统一法术/灵宠/普攻朝向；`auto_attack` 时无目标仍用最后有效朝向 |
| UI 拦截 | `RunContext.ui_blocking` 时停止自动普攻与蓄力 |
| 设计文档 | [`combat-targeting-priority.md`](features/combat-targeting-priority.md) |

**关键文件：** `target_selector.gd`、`combat_aim.gd`、`player.gd`、`player_spell_caster.gd`、`pause_overlay.gd`、`save_manager.gd`

---

### 确定性随机（Seeded RNG）架构

| 项 | 说明 |
|----|------|
| 局种子 | `RunContext.seed_value`；随机开局用 `_bootstrap_rng` |
| 子种子 | FNV-1a：`RunContext.derive_rng_seed(context)` |
| 工具类 | `RunRng` — `stage_room` / `run_controller` / `training` / `enemy_jitter` |
| 关卡生成 | `StageGenerator` 按 **关索引 + 房索引 + 房间类型** 派生 RNG，与运行时布局/波次回退一致 |
| 战斗随机 | `CombatRngService` 按房间重置序号；暴击/状态触发不再使用全局 `randf()` |
| 伤害上下文 | `CombatContextBuilder` 统一天气/地形/灵宠桶；`AffixHolder` 委托构建 |
| 训练场 | `RunContext.begin_training_run(seed)`；**涌潮 + 战斗布局** 与正式房一致（共用 `ArenaBase`） |

**关键文件：** `run_rng.gd`、`run_context.gd`、`combat_rng_service.gd`、`stage_generator.gd`、`combat_context_builder.gd`、`arena_base.gd`、`run_controller.gd`、`training_arena.gd`

---

### 种子 UI 与复现

| 位置 | 功能 |
|------|------|
| 道心选择 | 局种子输入框 +「随机」按钮；留空 = 随机开局 |
| HUD 顶栏 | 显示 `种子 N`（训练场带「· 训练」） |
| Esc 暂停 | 显示种子 +「复制种子」（`process_always` 定时器恢复按钮） |
| 存档 | `SaveManager.last_run_seed` 记录上局种子，placeholder 提示 |
| 文档 | [`seed-reproducibility.md`](features/seed-reproducibility.md) |

---

### Bug 修复（同批次）

- `training_dummy.gd` 重复 `const` 声明（编译错误）
- 暴击标签使用 `get_instance_id()` 破坏跨局复现 → 改为固定标签 + `combat_roll_seq`
- 暂停时复制种子按钮 Timer 不触发 → `create_timer(..., true)`
- `CombatContextBuilder` 暴击倍率重复叠加 `bonus_crit_mult` → 已移除重复加算
- 词条选择面板 `offer_selected` 信号参数类型错位 → 无参信号 + `get_offer()`
- `VariantUtils.as_bool()` 替代非法 `bool()` 调用

---

## 2026-06-10 — Phase 3 关卡与战斗深化（同会话早段）

### 天气 × 地形 × 伤害

- `TerrainSystem` + `weather.csv` 扩展
- 战斗地板渲染地形槽；环境乘算接入伤害上下文

### 关卡生成

- `RoomLayoutGenerator` — 障碍/地形槽
- `WaveComposer` — 多波次（含精英词缀房）
- `StageGenerator` 骨架 + `room_layouts.csv` / `room_templates.csv`

### 敌人多样化

- `enemies.csv`、`stage_enemy_pools.csv`、`elite_affixes.csv`
- `EnemySpawnRegistry` / `WaveComposer` 驱动多 archetype
- 训练木人场景支持多敌人贴图与技能 archetype

---

## 文档索引

| 文档 | 内容 |
|------|------|
| [`combat-horde-mode.md`](features/combat-horde-mode.md) | 魔劫涌潮（`HordeController` · `ArenaBase`） |
| [`combat-targeting-priority.md`](features/combat-targeting-priority.md) | 索敌 v2（`targeting_config.csv`） |
| [`seed-reproducibility.md`](features/seed-reproducibility.md) | 随机流划分、复现方法（含 `CombatRngService`） |
| [`code_review_report.md`](code_review_report.md) | 审查报告（部分已过时，以本日志为准） |
| [`game/README.md`](../game/README.md) | 可玩原型运行说明 |

---

## 待办（已知，未在本批次完成）

- 索敌 v2 手动测试清单逐项勾选
- 锁定目标 UI（脚下标记）
- 角色/灵根选择、法器精灵、无尽模式（GDD Phase 4+）
- 伤害流水线阶段 10 后处理迁入 `DamagePipeline`
- 每日挑战：固定每日种子（需服务端或日期派生逻辑）
- 地形真实贴图（石头/湖水替换 ColorRect 占位）
- `SaveManager` 迁移版本号（减少每次 load 的 legacy 检查）
- 词条 `unlock_spell` 同步写入 `SpellProgress`（当前仍由 `AffixHolder` + `PlayerSpellCaster` 合并生效）
