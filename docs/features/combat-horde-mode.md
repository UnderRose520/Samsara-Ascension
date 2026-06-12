# 魔劫涌潮（战斗房玩法）

## 概述

战斗房不再「清完当前怪 → 下一波 → 过关」，改为 **持续涌潮 + 击杀配额 + 倒计时** 的守劫模式。

## 过关条件（满足任一）

1. **斩魔达标**：本房击杀数 ≥ 配额（如第 1 重天 20 只）
2. **时限已至**：倒计时归零，仍可进入下一房（提示「脱身」）

Boss 房仍为单 Boss 战，不走涌潮。

## 涌潮规则

- 进房立即刷第一波；之后按 `wave_interval_sec` 间隔持续刷怪
- 同屏上限 `max_alive`，未达上限且未斩够配额则继续刷
- 精英房每 3 波可能混入带词缀精英
- 道心「证道」配额 +1，「问道」−1

## 配置表

`game/data/combat/combat_hordes.csv`

| 列 | 含义 |
|----|------|
| `kill_quota` | 本房需击杀总数 |
| `time_limit_sec` | 倒计时秒数 |
| `wave_interval_sec` | 波次间隔 |
| `spawn_per_wave` | 每波刷怪数 |
| `max_alive` | 同屏上限 |

默认配额（无 CSV 行时）：第 N 重天 ≈ `10 + N×10`（第 3 重天 50）。

## HUD

顶栏：`斩魔 12/20 · 1:45 · 第5波`

## 相关文件

- `combat_horde_config.gd` — 读表
- `horde_controller.gd` — 涌潮状态机（计时、配额、刷波信号）
- `arena_base.gd` — 战斗房共用：地板、涌潮、刷怪环、清理与计数
- `run_controller.gd` / `training_arena.gd` — 继承 `ArenaBase`，分别实现跑图流程与训练波次
- `wave_composer.gd` — `compose_horde_batch`
- `hud.gd` — `horde_updated` / `horde_ended` 显示
