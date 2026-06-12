# 种子复现（Seeded RNG）

## 概述

局内所有随机结果由 `RunContext.seed_value` 派生，通过 `RunContext.derive_rng_seed(context)` 生成子种子。相同种子 + 相同操作序列 → 相同关卡、词条与战斗随机结果。

## 随机流划分

| 上下文前缀 | 用途 | 入口 |
|-----------|------|------|
| `stage_room_{关}_{房}_{类型}` | 关卡骨架、布局、波次、机缘 ID | `RunRng.stage_room()` |
| `run_controller_{...}` | 运行时生成（出生点、词条 roll、突破天赋、坊市） | `RunRng.run_controller()` |
| `combat_{序号}_{标签}` | 暴击、状态触发（每房重置序号） | `CombatRngService.roll_chance()` |
| `training_{...}` | 训练场波次/词条 | `RunRng.training()` |
| `training_jitter_w{波}_{索引}` | 训练场敌人速度抖动 | `RunRng.enemy_jitter()` |

## 玩家如何复现

1. 开局在「选择道心」界面输入种子，或留空随机
2. 局中 HUD 顶栏 / Esc 暂停面板查看并复制种子
3. 下一局输入相同种子，并尽量复现相同路线与操作（择路、重随、出手顺序）

## 复现边界

- **会一致：** 关卡结构、敌人波次、词条池 roll、同房间内的暴击/状态序列（操作一致时）
- **可能不同：** 玩家移动/出手顺序不同 → `CombatRngService` 序号消耗顺序变化；词条重随次数不同 → 后续 `run_controller_affix_*` 流变化
- **训练场：** 调用 `RunContext.begin_training_run(seed)`，默认种子 `4242`，HUD 显示「种子 N · 训练」

## 相关文件

- `game/autoload/run_context.gd` — 局种子、`derive_rng_seed`
- `game/autoload/combat_rng_service.gd` — 战斗随机序号与 `roll_chance`
- `game/core/utils/run_rng.gd` — 上下文工厂
- `game/systems/world/stage_generator.gd` — 按房间派生 RNG
- `game/scenes/ui/run_setup_panel.gd` — 开局种子输入
- `game/scenes/ui/hud.gd` / `pause_overlay.gd` — 局中显示与复制种子

## 变更历史

| 日期 | 变更 |
|------|------|
| 2026-06-10 | 初版：RunRng 架构、种子 UI、复现边界说明 |
| 2026-06-10 | 汇总至 [`implementation-log.md`](../implementation-log.md) |
| 2026-06-10 | 战斗 RNG 迁至 `CombatRngService` |
