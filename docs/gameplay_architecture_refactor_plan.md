# 玩法深改架构落地计划

本文承接 `gameplay_deep_redesign.md` 与 `weapon_artifact_system_design.md`，用于约束首轮工程改造范围。

## 核心体验链

首轮不继续横向堆系统，而是把已有系统收束到一条可扩展链路：

```text
道途身份 -> 本命器攻击形态 -> 天象/地形借势 -> 道势积累 -> 通明/归一爆发 -> 道统成型
```

这条链路的工程目标是：每个新增玩法都能回答“它如何改变玩家动作、如何制造高潮、如何推进构筑”。

## 架构拆分

### 1. 本命器是身份层

本命器由 `data/weapons/weapons.csv` 驱动，运行时通过 `WeaponRegistry` 查询。

首批字段只保留玩法必要信息：

- `family`：剑、法珠、符旗、魂幡等大类，用于 UI、道统槽位、敌人读招。
- `attack_shape`：普攻形态，例如 `projectile`、`short_arc`。
- `attack_range` / `attack_arc_deg` / `projectile_speed`：形态参数。
- `damage_mult` / `attack_interval_mult`：轻量调手感，不做刷装数值膨胀。
- `element_hint`：给铭纹、天象、道统联动预留。

扩展规则：新增道途优先加一行 weapon 配置，再只在玩家攻击分发里补新的 `attack_shape`，不要为每把武器写独立玩家脚本。

### 2. 道势是高潮资源层

道势由 `RunContext` 管理，并通过 `EventBus.dao_momentum_changed` 通知 UI。

来源首批只接稳定事件：

- 普通/精英/Boss 击杀。
- 连击里程碑。
- 本命器近战命中多目标。

后续再接：

- 天象/地形击杀。
- 完美闪避反击。
- 灵宠协同命中 3 个以上敌人。
- 道统觉醒补满。

消耗首批：

- 满道势后 8 秒内可按 `F` 触发 `万法归一`。
- 未主动释放则自动进入 5 秒 `道法通明`。

扩展规则：其他系统只调用 `RunContext.add_dao_momentum()`，不要直接改 UI 或玩家属性。

### 3. 归一爆发是谱系出口

当前 `万法归一` 先做成本命器范围爆发，后续按谱系替换：

| 谱系 | 爆发方向 |
|---|---|
| 焚天 | 灼烧敌人连环爆燃，留下火场 |
| 雷罚 | 高威胁敌人落雷，积水区域导电 |
| 沧海 | 水波减速、冻结、冰裂 |
| 万毒 | 毒云铺场，毒杀回血 |
| 不动 | 护盾吸伤后反震 |
| 五行 | 按敌人状态触发处决 |

扩展规则：先做 `payload` 分发，不把每个道统效果硬塞进 `RunContext`。

### 4. 道统判定逐步迁移到槽位式

当前项目仍使用 raw `combo_tags` 判断道统。短期保持兼容，避免一次性推翻奖励池。

下一步应新增槽位表：

```csv
dao_id,slot_id,accepted_tags,required_count
furnace_dao,fire_source,fire_basic|fire_manual,1
furnace_dao,burn,burn|ignite,1
furnace_dao,detonate,combust|explode,1
```

再把 UI 进度从“已有标签数”升级为：

```text
焚天道统 2/5
已成：火源、燃烧
缺少：引爆、传播、纯化
```

## 首轮工程边界

本轮只做低风险骨架：

- 加入 `WeaponRegistry` 与 `weapons.csv`。
- `RunContext` 保存本命器与道势。
- 玩家普攻读取本命器配置，支持远程弹道和短扇形斩击。
- 敌人提供通用 `receive_player_weapon_hit()`。
- HUD 显示本命器与道势。
- 连击里程碑改为 10/30/60/100，并产出道势。

暂不做：

- 多道途开局选择 UI。
- 完整武器祭炼/铭纹/器灵。
- 槽位式道统觉醒替换。
- 敌人武器读招与掉落来源重写。

## 后续建议顺序

1. 开局道途卡：剑修/法修/符修先选其一，并调用 `RunContext.set_weapon()`。
2. 槽位式道统进度：先只改 UI 进度和推荐权重，再改觉醒条件。
3. 天象击杀归因：让地形/天气击杀调用道势，并显示死法标签。
4. 武器铭纹奖励：把普通奖励三选一拆成稳定增强、构筑推进、破格诱惑。
5. 器灵觉醒：从 `unity_burst_requested` 的 payload 分发出具体 F 技能。
