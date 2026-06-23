# 《轮回仙途》全新 UI/UX 设计文档

版本：v1.2  
日期：2026-06-21  
定位：2D 修仙 Roguelite 暗色水墨高饱和粒子 UI 全新方案，1920x1080 美术母版标准  
适用范围：Godot 4.6.3 客户端 UI、HUD、奖励、事件、结算、主题资产与实现验收  

---

## 0. 设计声明

本稿是一次完全重新设计，不继承现有代码和旧文档中的 UI 视觉方案。现有项目资料只作为玩法、系统、技术约束来源，例如：魔劫涌潮、三选一、天气地形、隐藏连锁、死亡遗憾、轮回成长、Godot 4.6.3、60 FPS 目标、UTF-8 文件规范。

最终方向定为：

```text
墨渊五行
在漆黑宣纸上，用克制墨痕构建界面骨架，
用高饱和五行粒子表达技能、危险、稀有、突破、死亡与轮回。
```

一句话原则：

```text
水墨是气质，粒子是信号，战斗可读性永远高于装饰。
```

美术锚点：

```text
玄墨道场，五行照夜。
```

解释：`玄墨` 负责暗色水墨、轮回、压迫和宣纸材质；`五行照夜` 负责高饱和粒子、元素辨识、奖励诱惑和关键瞬间。任何界面、地图、角色、怪物、技能或图标，只要偏离这 8 个字，都要回到本稿的尺寸、颜色、噪声和提示词规则重新校准。

---

## 1. 核心体验目标

### 1.1 玩家第一感受

玩家打开游戏时，应立刻感觉到：

- 这不是明亮仙宫 UI，而是黑暗轮回、秘境、魔劫、道痕交织的修仙战场。
- 界面像一张在暗处展开的战斗符箓，平时收敛，关键时刻炸开。
- 每一种高饱和颜色都有意义：火、雷、水、木、土、危险、稀有、禁忌、确认。
- 肉鸽选择不是菜单管理，而是一次次“要不要赌命修歪”的道途选择。
- 死亡不是失败弹窗，而是一段能让玩家产生“差一点，再来”的轮回仪式。

### 1.2 UI 必须服务的五个爽点

| 爽点 | UI 责任 | 验收标准 |
|---|---|---|
| 生存压迫 | 让玩家 0.2 秒看懂血量、危险方向、保命技能 | 濒死、Boss 大招、地面危险不能被水墨和粒子遮挡 |
| 构筑成形 | 让玩家看见这局正在走向哪条道 | 词条选择后必须飞入构筑符印或流派轨迹 |
| 随机诱惑 | 让每次三选一有“这个好强但有代价”的张力 | 每次奖励至少 1 张改变玩法的卡 |
| 隐藏发现 | 让玩家触发后知道“刚才悟到了什么” | 首次触发给原因链，触发前不剧透完整答案 |
| 死亡执念 | 让结算 5 秒内给出再开理由 | 首屏显示死因、遗憾、名场面、遗泽、再来入口 |

---

## 2. 讨论后舍弃的路线

| 路线 | 为什么不作为主路线 |
|---|---|
| 血月魔箓 | 冲击强，但容易把游戏推向黑红魔幻，五行与轮回层次不足 |
| 星河道藏 | 更仙、更空灵，但肉鸽杀戮感和魔劫压迫感弱 |
| 金碧仙宫 | 修仙识别强，但容易厚重、明亮、宫殿化，不符合暗色水墨和肉鸽战斗 |

保留原则：

- 可以借用血月魔箓的禁忌、心魔、道消气质。
- 可以借用星河道藏的轮回命盘、天命种子、结算星轨。
- 禁止把主 UI 做成大金边、大宫殿、大卡片堆叠。

---

## 3. 不可违背的硬规范

### 3.0 标准画幅

所有 UI、地图、事件插画、结算背景、Boss 登场背景、轮回转场背景、AI 生成提示词和美术审核，统一以 `1920x1080` 作为母版标准。

当前项目中已有的 `1280x720` 资产只作为运行时兼容导出版或低配导出版。后续不得直接以 `1280x720` 作为美术生成标准，因为水墨笔触、细线、图标、地面纹理和粒子缩放后会显得粗糙。

```text
master_canvas: 1920x1080
aspect_ratio: 16:9
runtime_export_current: 1280x720
downsample_ratio: 0.667
upscale_reference_ratio: 1.5
```

1920 母版安全区：

| 区域 | 尺寸 / 坐标 | 用途 |
|---|---:|---|
| 全画布 | `1920x1080` | 设计母版 |
| 战斗安全区 | 中心 `1344x756`，约 `x=288..1632, y=162..918` | 禁止常驻大 UI、浓墨、强粒子 |
| 核心操作区 | 中心 `960x540` | 玩家、敌弹、危险圈最高可读 |
| HUD 外框区 | 四边 `72-160px` | 常驻 HUD |
| 模态安全边距 | 左右 >= `120px`，上下 >= `72px` | 奖励、结算、事件 |
| 背景叙事区 | 四边外圈约 `240px` | 地图故事、墨雾、远景纹理 |

从 1920 母版导出到 1280x720 时，不可小于：

| 元素 | 1920 母版 | 720 导出最小 |
|---|---:|---:|
| 正文 | `20-22px` | `14px` |
| HUD 数字 | `28-32px` | `18px` |
| 卡牌标题 | `34-40px` | `22px` |
| 血条高度 | `30px` | `18px` |
| 技能图标 | `88-96px` | `56-64px` |
| 状态图标 | `44-48px` | `28-32px` |
| 点击热区 | `66px` | `44px` |
| 危险边界亮线 | `12px` | `8px` |
| UI 细线 | `3px` | `2px` |

### 3.1 战斗可读性

1. 屏幕中心宽高各 70% 为战斗安全区，禁止常驻面板、装饰阵法、非战斗粒子、浓墨遮罩。
2. 玩家必须在 0.2 秒内读出：真元状态、技能可用性、危险方向、目标/波次进度。
3. 血量、技能冷却、Boss 预警、地面危险不得使用低对比水墨风处理。
4. 天气、墨雾、沙尘、雪粒只能做氛围，不得遮挡敌弹、危险圈、拾取物、角色轮廓。
5. UI 颜色不得与敌方弹幕危险色混淆。危险默认使用高亮红紫和明确形状，友方五行使用更纯的元素色。

### 3.2 粒子与动效

1. HUD 常驻粒子总数不超过 80。
2. 奖励、突破、死亡、道统觉醒等全屏峰值粒子不超过 300，峰值持续不超过 1.2 秒。
3. 同屏 shader material 种类不超过 8 个；战斗常驻 shader 不超过 4 个。
4. 高饱和粒子只用于技能、危险、品质、确认、隐藏链、突破、死亡轮回等反馈信号。
5. 没有 gameplay feedback 的粒子一律不做。
6. 普通击杀、普通资源变化、普通升级不得触发全屏水墨或大字播报。

### 3.3 奖励与文本

1. 奖励卡必须 1 秒读懂：品质、流派、收益、代价、适配构筑。
2. 奖励标题不超过 6 字，主描述不超过 18 字，代价不超过 14 字。
3. 每次三选一至少 1 张改变玩法的卡，不能全是纯数值。
4. 禁忌奖励必须显示代价标签，并需要二次确认。
5. 书法字体只用于情绪大字，不用于数值、冷却、词条正文。

### 3.4 结算与重开

1. 死亡慢动作总长不超过 1.2 秒，除首次关键死亡教学外不得拖长。
2. 结算首屏 5 秒内必须让玩家知道：怎么死的、爽点是什么、差一点在哪里、下局为什么值得开。
3. 再来一局入口必须在结算首屏可见，不被动画和统计遮挡。

---

## 4. 设计 Token

采用三层结构：Primitive 原始值 -> Semantic 语义值 -> Component 组件值。实现时可映射到 Godot `Theme.tres`、palette JSON、组件脚本常量或资源 manifest。

### 4.1 Primitive Color

| Token | 值 | 用途 |
|---|---:|---|
| `ink.black.950` | `#050608` | 主背景、最深墨 |
| `ink.green.900` | `#071112` | 深青黑底 |
| `ink.gray.850` | `#15191A` | 湿墨灰、面板底 |
| `ink.gray.700` | `#2A3030` | 分隔线、禁用边 |
| `paper.bone.100` | `#E8E0C8` | 主文字、标题 |
| `paper.mist.300` | `#AEB8B1` | 次级文字 |
| `jade.cyan.400` | `#4FE7D2` | 冷玉结构、高亮信息 |
| `gold.old.500` | `#C79A42` | 稀有、Boss、传承 |
| `blood.red.500` | `#E83A3A` | 危险、濒死、禁忌警告 |
| `void.purple.500` | `#8E3BFF` | 心魔、禁忌、诅咒 |
| `element.fire` | `#FF3B1F` | 火 |
| `element.thunder` | `#A855FF` | 雷 |
| `element.water` | `#1EA7FF` | 水 |
| `element.wood` | `#35F06A` | 木 |
| `element.earth` | `#E2A238` | 土 |
| `element.neutral` | `#D8D0B8` | 无、玄、通用 |

### 4.2 Semantic Color

| Token | 映射 | 说明 |
|---|---|---|
| `surface.root` | `ink.black.950` | 最底层背景 |
| `surface.panel` | `rgba(5,6,8,0.78)` | 标准暗面板 |
| `surface.panel_strong` | `rgba(7,17,18,0.92)` | 模态/事件面板 |
| `surface.ink_wash` | `rgba(21,25,26,0.65)` | 水墨晕染 |
| `text.primary` | `paper.bone.100` | 正文主要文字 |
| `text.secondary` | `paper.mist.300` | 次要说明 |
| `text.disabled` | `rgba(174,184,177,0.42)` | 禁用 |
| `line.quiet` | `rgba(79,231,210,0.18)` | 普通线 |
| `line.active` | `jade.cyan.400` | 选中/焦点 |
| `line.rare` | `gold.old.500` | 稀有/传承 |
| `state.danger` | `blood.red.500` | 危险 |
| `state.forbidden` | `void.purple.500` | 禁忌/心魔 |

### 4.3 Rarity Token

稀有度不能只靠颜色，必须同时通过轮廓、边缘光、粒子、入场节奏表达。

| 稀有度 | 色彩 | 形状 | 粒子 | 入场 |
|---|---|---|---|---|
| 凡品 | 骨白墨边 | 矩形玉简 | 几乎无 | 0.25 秒 |
| 灵品 | 冷玉青 | 切角玉简 | 轻微浮尘 | 0.35 秒 |
| 仙品 | 旧金 | 双层符框 | 金色短粒 | 0.55 秒 |
| 天品 | 金紫混光 | 墨裂符框 | 卡面流光 | 0.8 秒 |
| 道品 | 五行轮廓 | 非对称道痕框 | 五行聚散 | 1.2 秒 |
| 禁忌 | 紫红污染 | 破裂边框 | 逆流粒子 | 1.2 秒 + 二次确认 |
| 隐藏 | 暗金剪影 | 未明符印 | 初次爆点 | 首触发 1.0 秒 |

### 4.4 Typography

| 层级 | 建议字号 1080p | 用途 | 规则 |
|---|---:|---|---|
| `display.calligraphy` | 64-96 | 突破、道消、轮回、天命 | 只用于短字，不承载信息 |
| `title.large` | 32-40 | 主界面标题、结算章名 | 高对比 |
| `title.medium` | 24-28 | 面板标题、卡牌名 | 不超过 6 字优先 |
| `body.primary` | 18-20 | 词条正文、事件说明 | 高可读字体 |
| `body.small` | 14-16 | 标签、来源、代价 | 不低于 14 |
| `number.hud` | 18-24 | 血量、冷却、波次 | 数字清晰，禁止书法 |
| `caption` | 12-14 | 辅助信息 | 不用于关键战斗信息 |

字体建议：

- 正文：清晰黑体或宋黑混合字体。
- 标题：锋利宋体、碑刻感标题字体。
- 书法：仅用于“大字情绪”，如“轮回”“道消”“突破”。

### 4.5 Spacing and Shape

| Token | 值 | 用途 |
|---|---:|---|
| `space.1` | 4 | 微间距 |
| `space.2` | 8 | 小组件内边距 |
| `space.3` | 12 | 标签/图标间距 |
| `space.4` | 16 | 面板内边距 |
| `space.6` | 24 | 卡牌区块间距 |
| `space.8` | 32 | 模态区块间距 |
| `radius.none` | 0 | 符纸、碑刻 |
| `radius.small` | 4 | 标签、技能槽 |
| `radius.medium` | 8 | 卡牌、模态，最大常规圆角 |

---

## 5. 视觉语言

### 5.1 材质

| 材质 | 用途 | 做法 |
|---|---|---|
| 漆黑宣纸 | 主背景、模态底 | 低频纸纹，低对比，不进入文字背后 |
| 湿墨晕染 | 面板边缘、转场 | 边缘不规则，中心保持干净 |
| 冷玉薄片 | HUD 结构、按钮、技能槽 | 半透、薄边、弱内发光 |
| 残碑裂纹 | Boss、死亡、结算 | 只在高压场景使用 |
| 符纸玉简 | 奖励、事件选项 | 卡面固定信息结构 |
| 道痕粒子 | 突破、隐藏链、道统 | 根据五行 palette 变色 |

禁止：

- 厚重金边宫殿框。
- 大面积亮色渐变背景。
- 文字背后的高噪水墨纹。
- 与地面危险相似的流动装饰。

### 5.2 色彩使用比例

```text
暗底与低饱和结构：80% 以上
冷玉/骨白信息：15% 左右
高饱和五行与危险：5% 以下，且必须绑定反馈
```

同一屏幕主强调色最多 2 个。例如雷火流派可同时亮雷紫与火红，水木土只显示低亮标签。

### 5.3 图标语言

| 类型 | 形状规则 | 颜色规则 |
|---|---|---|
| 技能 | 圆形或八边符印底，中心大剪影 | 元素色只点亮核心 |
| 五行 | 火尖、水弧、雷折、木芽、土方 | 颜色 + 形状双编码 |
| Buff | 圆、上升、环绕 | 低亮青绿/金 |
| Debuff | 尖、裂、下坠 | 红紫/灰黑 |
| 禁忌 | 破边、倒纹、污染裂痕 | 紫红主色，必须有代价标 |
| 资源 | 独立轮廓，24px 可识别 | 灵石金、道势青、命火红 |

---

## 6. 信息架构

### 6.1 信息优先级

P0：常驻且最高可读性

- 真元、护盾、濒死。
- 技能冷却、闪避/保命资源。
- Boss/精英/地面危险/敌方弹幕/天气致命变化。
- 当前目标：波次、击杀、倒计时、Boss 血量。

P1：常驻但可压缩

- 当前构筑身份：剑修、法修、符修、体修等。
- 道势、灵力、连击、杀意、灵石。
- 天气与地形的 1-2 个战斗关键词。
- 稀有触发：隐藏链、道统觉醒、法宝共鸣。

P2：只在暂停、Tab、奖励、结算中展开

- 完整词条列表。
- 种子、详细统计、伤害占比。
- 隐藏链札记、天气地形发现、历史记录。
- 长文本事件、世界观、完整来源说明。

### 6.2 常驻、临时、模态

| 层级 | 出现方式 | 内容 | 输入 |
|---|---|---|---|
| 常驻 HUD | 贴边、薄、半透明 | 血量、技能、目标、天象 | 不抢输入 |
| 临时反馈 | 右侧轨、边缘、角色周边 | 连击、隐藏链、濒死、技能可用 | 不抢输入 |
| 轻模态 | 暂停或极慢速 | 奖励三选、事件选项、突破 | 接管输入 |
| 重模态 | 暂停 | 死亡、结算、设置、图鉴 | 接管输入 |

---

## 7. 战斗 HUD

### 7.1 总布局

```text
┌─────────────────────────────────────────────────────────────┐
│ 左上：命格生存区                顶中：目标/波次细线        右上：天象签 │
│ 左中：构筑符印区                                             右侧：上头反馈轨 │
│                                                             │
│                                                             │
│                      中心 70% 战斗安全区                    │
│                                                             │
│                                                             │
│ 底左：状态合并              底中：技能 Dock              底右：威胁罗盘 │
└─────────────────────────────────────────────────────────────┘
```

1920x1080 母版推荐控件框：

| 区块 | 位置 / 尺寸 | 说明 |
|---|---:|---|
| 左上命格生存区 | `x=40, y=36, w=420, h=190` | 真元、护盾、境界、资源 |
| 左中构筑符印区 | `x=44, y=250, w=360, h=280` | 4-6 个符印槽 |
| 顶中目标条 | `x=600, y=32, w=720, h=36` | 魔劫进度 / Boss 血条 |
| 右上天象签 | `x=1560, y=36, w=280, h=96` | 天气 + 2 个关键词 |
| 右侧反馈轨 | `x=1580, y=220, w=300, h=520` | 连击、隐藏链、稀有提示 |
| 底部技能 Dock | `x=580, y=900, w=760, h=128` | LMB / Space / QER / V |
| 底左状态合并 | `x=48, y=900, w=380, h=104` | 机缘/劫数最多 6 个 |
| 底右威胁罗盘 | `x=1612, y=884, w=220, h=160` | 精英/Boss/掉落方向 |

下采样到 1280x720 时按 `0.667` 缩放；HUD 数字、冷却数字和血条高度如低于最小值，优先锁定最小字号和高度，而不是等比继续缩小。

### 7.2 左上：命格生存区

内容：

- 头像或道途小印。
- 真元条，必须是左上最强对比元素。
- 护盾/护体灵气条。
- 境界短名，例如“炼气”“筑基”“金丹”。
- 灵石与当前核心资源小字。

规格：

- 1080p 血条高度不低于 18px；720p 视觉高度不低于 16px，触控版不低于 22px。
- 低于 30% 真元：边缘暗红弱警告。
- 低于 15% 真元：血条、屏幕边缘、角色脚下警示三选二同步，不允许全屏乱闪。
- 真元变化可即时，但补间和 redraw 限频到 10 次/秒以内。

### 7.3 左中：构筑脉络区

内容：

- 4-6 个构筑符印槽，例如剑、雷、火、符、血、禁。
- 每个符印只显示图形或单字，不放长说明。
- 构筑发生质变时展开 1.5 秒短句，例如“雷剑成势”“符阵自转”。

交互：

- 鼠标悬停显示 tooltip。
- Tab 进入完整构筑页。
- 奖励选择后，卡牌化为符光飞入对应符印槽。

### 7.4 顶中：战斗目标区

内容：

- 平时为极细进度线：魔劫涌潮进度、剩余时间、击杀目标。
- Boss 出现时转为 Boss 血条与阶段刻度。
- 阶段破势可 0.4 秒墨裂动画。

禁止：

- 顶部频繁大黑条播报普通击杀。
- 长目标文案。
- 压住角色上方视野的大面板。

### 7.5 右上：天象地形签

内容：

- 天气图标。
- 最多 2 个战斗关键词。
- 示例：`雷雨：积水 + 雷术强`、`烈阳：干地 + 火势盛`。

规则：

- 只写会改变操作的信息。
- 不写氛围文案。
- 天气图标可有低频呼吸，不常驻喷粒子。

### 7.6 右侧：上头反馈轨

显示：

- 隐藏链首次发现。
- 连击里程碑：30、60、100、200。
- 稀有掉落。
- 道统觉醒。
- Boss 破势。

不显示：

- 普通击杀。
- 普通资源 +1。
- 高频小伤害。

时长：

- 普通重要反馈 1.2 秒。
- 稀有反馈 1.8 秒。
- 传说/隐藏反馈 2.4 秒，首次可 1.0 秒高饱和爆点。

### 7.7 底中：技能 Dock

内容：

- LMB 普攻、Space 御风步、Q/E/R 主动法术、V 灵宠协同。
- 冷却用环形或扇形墨痕遮罩。
- 剩余 3 秒内显示数字；3 秒以上只显示进度。
- 技能可用时用内焰/内雷点亮，不全槽闪烁。

规则：

- 技能升级后图标轮廓变化，不能只改数字。
- 禁用态要同时降低亮度、加锁形、加灰纹，不能只变灰。
- Dock 使用容器居中，不能固定绝对坐标。

### 7.8 底左：临时状态

- Buff/Debuff 最多常驻 6 个。
- 超过后合并为“机缘 x4 / 劫数 x3”。
- 悬停或 Tab 查看详情。

### 7.9 底右：威胁罗盘

如果没有地图探索，就不做复杂小地图，而做威胁罗盘：

- 红点：精英/Boss 方向。
- 紫点：心魔/禁忌事件方向。
- 金点：稀有掉落/传承。
- 只提示方向，不显示完整路径。

---

## 8. 核心界面设计

### 8.1 主菜单：轮回碑

画面：

- 黑色宣纸底，一块残碑立在微光命火中。
- 菜单不是横排按钮，而是碑上浮现的道痕选项。
- 背景粒子极少，只保留命火和墨尘。
- 1920 母版中，轮回残碑占画面左中约 `520x760`，建议位置 `x=260..780, y=160..920`。
- 菜单区放在右侧约 `x=1160..1640, y=280..800`，背景必须低噪，便于按钮和文字读取。
- 命火从底部中心偏左 `x=920..1040, y=820..980` 向上燃，粒子不进入右侧菜单主体区。

信息：

- 继续轮回。
- 新开一世。
- 轮回札记。
- 设置。
- 退出。

规则：

- 第一屏就能进入游戏，不做营销式落地页。
- 选中项用冷玉线和短符光，不用大金框。

### 8.2 开局设置：道心与天命

包含：

- 道心选择：问道、悟道、证道。
- 角色/道途/灵根。
- 种子输入。
- 前世遗泽。
- 轮回成长简表。

布局：

- 左侧为道心/角色选择。
- 右侧为本局天命卷轴，显示会影响开局的关键条件。
- 底部主操作“踏入轮回”始终可见。

视觉：

- 道心三档不能像难度羞辱。每个都用正向修仙文案。
- 证道可以更尖锐、更明亮，但不能让问道显得低级。

### 8.3 奖励三选：浮墨玉简

入场：

1. 战斗瞬停 0.15 秒。
2. 敌弹淡化，角色仍可见。
3. 背景暗化 65%-75%。
4. 三张玉简从下方升起，普通入场不超过 0.45 秒。

卡牌固定结构：

```text
┌─────────────────────────────┐
│ 品质线 + 五行/流派符号       │
│                             │
│          大图标              │
│                             │
│ 名称：不超过 6 字             │
│ 核心效果：不超过 18 字         │
│ 代价/限制：不超过 14 字        │
│                             │
│ 标签：雷 / 剑 / 禁 / 法宝       │
└─────────────────────────────┘
```

1920 母版布局：

```text
background_dim: 70%
card_size: 360x560
card_gap: 48
three_card_group: 1176x620
group_position: centered, slightly below center, y=320..940
rarity_line_height: 64
main_icon_area: 180
text_and_tag_area: 220
```

禁忌卡可以破边和污染，但品质、名称、主描述、代价、标签的位置不能变化。

卡牌类型：

| 类型 | UI 呈现 | 设计目的 |
|---|---|---|
| 稳定增强 | 静态、清晰、低风险 | 给安全选择 |
| 构筑推进 | 显示道统/流派进度 | 让玩家看见成形 |
| 破格诱惑 | 高收益 + 明确代价 | 制造手心出汗 |
| 灰色选项 | 完整展示但不可选 | 制造下局执念 |
| 禁忌选项 | 紫红污染 + 二次确认 | 允许修歪 |

选择后：

- 卡牌化为符光，飞入构筑符印区或技能 Dock。
- 0.35 秒内完成，不拖慢下一房。

### 8.4 灰色选项

灰色选项必须完整展示效果，不隐藏诱惑。

| 条件 | 文案 |
|---|---|
| 真元不足 | 气血不足，无法承受 |
| 道势枯竭 | 道势枯竭，无法引动 |
| 无灵宠 | 身边无灵兽，共鸣无从谈起 |
| 连击不足 | 道韵未聚，顿悟无门 |
| 道途不合 | 此法与你道途不合 |

目的不是惩罚，而是让玩家产生：“下次我要带着条件来拿它。”

### 8.5 突破界面

触发：

- Boss 后、境界提升、关键天赋选择。

视觉：

- 背景墨浪向中心收束，境界字以书法出现。
- 三到四个天赋像悬浮残碑，不是普通卡片。
- 首次突破演出不超过 1.5 秒，复见不超过 0.7 秒。

信息：

- 新境界。
- 词条槽变化。
- 新解锁技能或系统。
- 三选一或四选一突破收益。

### 8.6 事件界面

定位：

```text
短、险、可赌。
```

布局：

- 左侧或上方是事件插画。
- 右侧或下方是 2-4 个选项。
- 每个选项必须显示收益、代价、触发条件。
- 风险选项用紫红禁忌标识，不隐藏真实代价。

规则：

- 事件正文不超过 80 字。
- 单个选项主文案不超过 16 字。
- 选项详情可 tooltip 展开。

### 8.7 坊市

视觉：

- 黑市感、幽暗灯火、玉符标价。
- 不做明亮商业街。

规则：

- 商品显示价格、流派、稀有度、是否影响构筑。
- 买不起也要展示效果，制造目标。
- 代价型交易必须二次确认。

### 8.8 Tab / 暂停玉简

Tab 不是暂停菜单的垃圾桶，而是“本局构筑解释器”。

必须显示：

- 当前流派轨迹。
- 已装备词条与来源。
- 隐藏链札记。
- 天气地形发现。
- 伤害/承伤关键统计。
- 种子信息。

不常驻到 HUD 的长解释，全部放这里。

### 8.9 死亡轮回

死亡分三段：

1. 0.3 秒：角色命火熄灭或道痕断裂。
2. 0.5 秒：致命来源高亮，例如 Boss 技、火堆、围杀、禁忌代价。
3. 0.4 秒：画面坠入轮回池，进入结算。

1920 母版结算首屏：

| 区块 | 位置 / 尺寸 | 内容 |
|---|---:|---|
| 左侧死亡名场面 | `x=120, y=160, w=700, h=760` | 最后一幕、死因、击杀者 |
| 右侧轮回账本 | `x=940, y=160, w=820, h=620` | 爽点、遗憾、收益、遗泽 |
| 底部行动区 | `x=940, y=820, w=820, h=120` | 再入轮回、查看札记、返回 |

首屏必须显示：

- 死因：被谁 / 什么机制杀死。
- 本局名场面：最高连击、最强构筑、隐藏发现。
- 差一点：距离突破、道统、Boss、隐藏链还差什么。
- 遗泽：下一局可带走什么。
- 再来一局入口。

文案风格：

- 不羞辱玩家。
- 不写“失败”。
- 用“道消”“轮回”“命火未尽”等修仙语义。

### 8.10 结算与再开

结算顺序：

1. 首屏给再开理由。
2. 第二层给详细统计。
3. 第三层给解锁和札记。

再开入口：

- 默认选中“再入轮回”。
- 手柄/键盘一键确认。
- 不要求玩家看完所有统计才能再开。

---

## 9. 隐藏链与随机性的 UI 规则

### 9.1 核心原则

隐藏链不能提前剧透，但触发后必须让玩家知道“刚才为什么发生”。

### 9.2 触发前

- 不显示完整公式。
- 可以显示模糊征兆，例如“雷意躁动”“地脉微鸣”。
- 条件未满足的灰色选项要完整展示诱惑，但不写全部隐藏路径。

### 9.3 首次触发

显示结构：

```text
悟得：雷泽引劫
因：雷术击中积水中的敌人
果：下一次雷术连锁 +1
已记入：轮回札记
```

时长：

- 首触发 1.0 秒强反馈。
- 可暂停后在札记查看完整说明。

### 9.4 触发后

- 同一隐藏链复触发只显示 0.35 秒短反馈。
- 札记中记录触发条件、效果、种子、首次时间。
- 不让同一提示在 30 秒内重复刷屏。

---

## 10. 地图美术标准

### 10.1 地图总纲

《轮回仙途》的战斗地图采用 2D 俯视 / 轻 3D 感手绘 HD 水墨场景。地图必须好看，但第一职责仍是服务高速肉鸽战斗。

统一风格：

- 暗色水墨底。
- 高饱和五行能量只作为局部环境痕迹和战斗反馈。
- 中心战斗区低噪、低对比、无复杂装饰。
- 边缘区域承载主题辨识度、环境故事和高细节。
- 地图底图不得烘入角色、敌人、UI、宝箱、门、传送阵、明显碰撞物、高柱、高树、机关等运行时对象。

推荐资产模式：

```text
map_mode: scene_mode
visual_model: layered_raster + optional tilemap support
runtime_object_model: separate_props + scene_hooks
collision_model: runtime shapes / terrain metadata
engine_target: Godot project-native
```

### 10.2 1920 地图画布

美术母版：

```text
master_background: 1920x1080
aspect_ratio: 16:9
runtime_export_current: 1280x720
world_design_reference: 1920x1056
tile_size_reference: 48 px
tile_cells_reference: 40 x 22
```

当前项目运行时兼容契约：

```text
room_background.png: 1280x720
world_bounds: 1280x704
tile_size: 32
tilemap_cells: 40x22
terrain_props.png: 3x3 atlas, 128x128 per cell
```

1920 母版换算：

```text
1280x720 -> 1920x1080 scale: 1.5x
1280x704 world_bounds -> 1920x1056 world_design_reference
32 tile -> 48 px design tile
40x22 cells unchanged
128 prop cell -> 192 px design prop cell
```

推荐流程：

1. image generation 和美术审核全部按 `1920x1080`。
2. 保存母版为非运行时资产，例如 `room_background_master_1920.png`。
3. 当前运行时导出 `room_background.png` 为 `1280x720`。
4. 下采样算法使用 Lanczos 或 Bicubic，导出后做锐度检查。
5. `world_bounds` 仍可使用 `1280x704`，底部 16px 作为运行时安全余量。
6. 所有 prompt 文件按 1920x1080 写，并注明运行时会导出到 1280x720。

### 10.3 地图安全区

1920 母版划分：

```text
full_canvas: 1920x1080
runtime_world_area: x=0..1920, y=0..1056
bottom_reserved_runtime_margin: y=1056..1080
center_low_noise_zone: x=384..1536, y=216..864
combat_primary_zone: x=288..1632, y=162..918
edge_theme_zone: left/right 240 px, top/bottom 120 px
```

1280 导出版换算：

```text
runtime_world_area: 1280x704
center_low_noise_zone: x=256..1024, y=144..576
combat_primary_zone: x=192..1088, y=108..612
edge_theme_zone: left/right 160 px, top/bottom 80 px
```

规则：

1. 中心低噪区只允许地表纹理、浅色裂纹、低对比阵纹、浅水痕、薄雾影。
2. 中心低噪区禁止大面积高亮、强图案、复杂花纹、厚边界、发光圆阵。
3. 主题识别细节主要放在边缘：残碑、洞壁、远景符纹、魔痕、雷云投影、藤痕等。
4. 地图不能画出会被玩家误认为可碰撞的高墙、高柱、树冠、巨石、栏杆，除非这些对象会作为 terrain props 或 runtime collision 单独生成。
5. 战斗中心 60% 必须能清楚看见角色、敌人、弹幕、地面危险预警和掉落物。
6. 地图底图的高饱和色覆盖率建议低于 8%，只作为元素倾向和局部能量裂隙。

### 10.4 五重天地图差异

统一项：

- 同一 `1920x1080` 俯视手绘 HD 母版。
- 同一暗色水墨、低噪中心、边缘叙事规则。
- 同一“无角色、无 UI、无文字、无运行时 props”的底图契约。
- 同一中心 60% 低噪战斗区。

差异项：

| 重天 | 主题名 | 主情绪 | 主色 | 粒子 | 材质差异 | 独占视觉词 |
|---|---|---|---|---|---|---|
| 炼气 | 青岚炼气泽 | 湿润、初入仙途 | 墨玉绿 | 青萤 | 湿石、浅苔、薄水膜 | wet jade moss veins |
| 筑基 | 玄窟筑基脉 | 凝练、地脉压迫 | 深玄青 | 玉脉蓝绿 | 洞窟黑石、玉髓矿脉 | cold jade mineral veins |
| 金丹 | 赤魔金丹狱 | 欲望、暴烈、腐化 | 紫黑 | 魔焰橙红 | 烧裂黑玉、熔痕、魔纹 | crimson corruption cracks |
| 元婴 | 月魄元婴墟 | 空旷、古老、魂雾 | 冷月蓝灰 | 幽蓝魂光 | 风化青石、残金阵纹 | old gold broken formation lines |
| 渡劫 | 九霄渡劫台 | 天威、终局压迫 | 雷云黑灰 | 蓝白雷光 | 雷击灰石、玻璃裂痕 | electric thunder scorch veins |

禁止五张地图都出现：

- 同样的中心圆阵。
- 同样的裂纹方向。
- 同样的边缘石头。
- 同样的亮色地脉。
- 同样的水墨云雾。
- 同样的视觉重心。

### 10.5 Base Background 约束

`room_background_master_1920.png` 只能包含：

- 地面材质。
- 浅层水墨纹理。
- 地形色带。
- 低矮裂纹。
- 地表符痕。
- 非交互性环境痕迹。
- 边缘氛围。
- 不影响碰撞判断的浅阴影。

不能包含：

- 角色、敌人、Boss、NPC。
- UI、文字、数字、箭头、图标。
- 宝箱、门、传送门、祭坛、机关。
- 高树、高石柱、可碰撞巨石。
- 明显奖励点、出生点、刷怪点。
- 中心大圆阵或强发光目标圈。
- 会被理解为可通行 / 不可通行边界的强结构线。

### 10.6 Tileset 约束

当前可继续保留运行时 `tile_size=32`，但美术母版按 `48px` 思考。

建议 tileset 内容：

```text
ground_dark_ink
ground_wet_ink
ground_cracked
ground_element_trace
shallow_water
mud_or_swamp
burnt_ground
frosted_ground
thunder_scorch
demon_corruption
```

规则：

1. tile 不能做成过强棋盘格。
2. 任意 4x4 tile 拼接后不能出现明显重复噪声。
3. 地形效果 tile 必须比普通地面更可读，但不要比技能特效更亮。
4. 元素地形必须形状 + 颜色双重区分。
5. 水、火、雷、毒、冰、魔染不能只靠颜色区分。

### 10.7 Terrain Props 约束

当前运行时：

```text
terrain_props.png: 384x384
grid: 3x3
cell: 128x128
```

1920 母版建议：

```text
terrain_props_master_1920.png: 576x576
grid: 3x3
cell: 192x192
runtime_downsample: 384x384
```

九格建议：

```text
0 stone_blocker
1 water_pool
2 swamp_snare
3 fire_pit
4 ice_patch
5 thunder_mark
6 demon_growth
7 spirit_herb_cluster
8 broken_relic
```

规则：

1. 每个 prop 必须有透明背景。
2. 每格内容不得贴边，至少保留 12% 内边距。
3. 碰撞型 prop 的实际碰撞范围必须小于视觉范围，避免角色碰空气。
4. 低矮地形可以进入中心区，高大 blocker 只能稀疏出现。
5. prop 风格统一为暗色水墨手绘，但每个主题可以通过局部材质变体换色。

### 10.8 五主题地图提示词

以下 prompt 全部按 `1920x1080` 母版写。

#### qi_refining_verdant / 青岚炼气泽

```text
1920x1080 top-down 2D hand-painted HD game battle arena background, dark xianxia ink wash style, foundation-only ground layer, deep black ink paper texture, wet jade-green soil, shallow low-contrast moss veins, thin cyan spiritual traces, scattered flat stone stains near the edges, subtle water seepage marks, low spiritual grass marks only at the border, center 60 percent clean and low-noise for fast roguelite combat readability, high quality 2D game map background, no characters, no UI, no text, no props, no tall objects, no collision objects, no treasure, no portals, no buildings, no labels
```

负向：

```text
bright forest, tall trees, tree canopy, dense bushes, shrub wall, vertical rocks, cliffs, buildings, bridge, chest, altar, portal, character, enemy, boss, NPC, UI, text, symbols as labels, arrows, marker circles, high saturation everywhere, noisy center, large glowing magic circle in the middle, isometric view, side view, pixel art, low resolution, blurry, photorealistic
```

#### foundation_cavern / 玄窟筑基脉

```text
1920x1080 top-down 2D hand-painted HD game battle arena background, dark xianxia ink wash cavern floor, foundation-only ground layer, black teal stone ground, cold jade mineral veins, damp ink shadows, flat cave-floor cracks, subtle blue-green spiritual ore traces along the edges, center 60 percent open clean low-noise combat area, readable ground shapes for survivors-like roguelite combat, elegant dark ink texture, no characters, no UI, no text, no runtime props, no tall pillars, no walls, no doors, no treasure, no portal
```

负向：

```text
side-view cave, high walls, narrow corridor, maze, stalagmites in center, big pillars, glowing crystals as objects, treasure chest, gate, doorway, bridge, lava river, character, monster, UI, text, labels, arrows, dense noise, high contrast center, realistic 3D render, pixel art, blurry
```

#### golden_core_demon / 赤魔金丹狱

```text
1920x1080 top-down 2D hand-painted HD game battle arena background, dark xianxia ink wash demonic domain floor, foundation-only ground layer, black-purple ink ground, restrained crimson corruption cracks, burnt golden core talisman scars near the edges, subtle ember stains, demonic ink veins fading toward a clean readable center, center 60 percent low-noise and not overly bright, high saturation only in small cracks and edge accents, suitable for fast 2D roguelite combat, no characters, no UI, no text, no props, no corpses, no gates, no treasure, no portal, no tall objects
```

负向：

```text
full red screen, gore, blood pool, horror scene, skull piles, bones, huge magic circle in center, demons, characters, enemies, boss, UI, text, labels, portals, treasure, altar, buildings, high pillars, noisy center, excessive particles, photorealistic, 3D render, pixel art
```

#### nascent_soul_ruins / 月魄元婴墟

```text
1920x1080 top-down 2D hand-painted HD game battle arena background, dark xianxia ink wash ancient cultivation ruins floor, foundation-only ground layer, moonlit gray stone, old gold broken formation lines, pale blue ink shadows, fragmented dao patterns near the edges, worn floor slabs and subtle cracks, center 60 percent spacious clean low-noise combat area, elegant ruined sacred ground atmosphere, no readable text, no characters, no UI, no props, no pillars, no walls, no altar, no treasure, no portal, no buildings
```

负向：

```text
large palace, intact temple, tall columns, stairs blocking movement, altar object, statue object, readable Chinese characters, giant center magic circle, UI, text labels, character, enemy, NPC, chest, portal, dense debris in center, high noise floor, photorealistic, side view, isometric, pixel art
```

#### tribulation_thunder / 九霄渡劫台

```text
1920x1080 top-down 2D hand-painted HD game battle arena background, dark xianxia ink wash heavenly tribulation arena floor, foundation-only ground layer, charcoal stone ground, electric blue and white-violet thunder veins mostly near the edges, subtle lightning scorch marks, stormy ink-wash atmosphere, center 60 percent clean low-noise readable combat floor, high saturation thunder accents controlled and sparse, no characters, no UI, no text, no props, no giant lightning bolts crossing the center, no altar, no portal, no treasure, no tall objects
```

负向：

```text
full screen lightning, bright blue everywhere, giant thunder beam in center, storm clouds covering floor, character, enemy, boss, UI, text, labels, altar, portal, treasure chest, pillars, walls, mountains, side view, 3D render, pixel art, noisy center, blurry
```

### 10.9 地图 QA

母版验收：

1. 图片尺寸必须为 `1920x1080`。
2. 中心低噪区截图灰度对比不能明显高于边缘主题区。
3. 中心区不得出现大圆阵、强发光、复杂符号、可误判障碍物。
4. 不得出现角色、敌人、UI、文字、箭头、图标、宝箱、门、传送门。
5. 主题在缩小到 `1280x720` 后仍能一眼区分。
6. 角色放在中心时，轮廓必须清楚。
7. 红、紫、蓝高饱和区域不能与敌方弹幕和地面危险预警混淆。
8. 下采样到 `1280x720` 后不能糊成一片，也不能出现锐化噪点。
9. 每张图必须保留对应 `.prompt.txt`。
10. 五主题并排检查时必须统一风格，但不能像同一张图换色。

运行时兼容验收：

1. `room_background.png` 导出为 `1280x720`。
2. `world_bounds` 仍对应 `1280x704`。
3. `tilemap_cells` 仍为 `40x22`。
4. `tile_size` 仍为 `32`。
5. `terrain_props.png` 仍为 `384x384`，`3x3`，每格 `128`。
6. 若保留母版，母版 prop atlas 应为 `576x576`，每格 `192`。
7. Godot 中地面危险预警、掉落物、角色脚底光圈在五张地图上都可读。
8. 连续 10 分钟战斗中，地图纹理不得导致视觉疲劳或目标丢失。

---

## 11. 角色、怪物与技能资产标准

### 11.1 1080p 战斗尺寸

以下以 `1920x1080` 为显示标准。导出到 `1280x720` 时统一乘 `0.667`，但最小可读角色高度不得低于 `40px`。

| 类型 | 1080p 屏幕显示尺寸 | 720p 换算 | 备注 |
|---|---:|---:|---|
| 玩家 | 高 `96px`，宽 `64-80px` | 高 `64px` | 光环/剑气外圈可到 `128px` |
| 宠物 | 高 `48-64px` | `32-43px` | 不得比普通怪更抢眼 |
| 普通怪 | 高 `56-84px` | `37-56px` | 小怪靠数量，轮廓必须简单 |
| 精英怪 | 高 `112-150px` | `75-100px` | 加肩甲、角、背光、符纹 |
| 小 Boss | 高 `220-280px` | `147-187px` | 半屏威压但不遮地面危险 |
| 主 Boss | 高 `320-420px` | `213-280px` | 技能前摇必须明显 |
| 弹幕核心 | `14-36px` | `9-24px` | 外发光可到 `40-90px` |
| 大招弹幕 | `48-72px` | `32-48px` | 必须慢速 / 高预警 |
| Impact 小 | `64x64px` | `43x43px` | 普通命中 |
| Impact 中 | `128x128px` | `85x85px` | 技能命中 |
| Impact 大 | `192-320px` | `128-213px` | 精英 / Boss / 突破 |
| 技能图标 | 源图 `256x256` 或 `512x512`，HUD 显示 `72x72` | `48x48` | 冷却数字不小于 `18px` |

### 11.2 Sprite Sheet 规格

- 玩家：`hero_action_bundle`，每个动作单独生成，不做混合大图。
- 玩家 idle：`2x2`，4 帧，单元格建议 `192x192` 或高清源 `512x512`。
- 玩家 run / walk：四方向 `4x4`，单元格 `192x192` 或高清源 `512x512`，脚底锚点固定。
- 玩家 attack / cast：身体表 `2x3`，单元格 `192x192` 或高清源 `512x512`，不带大剑气、弹幕、impact。
- 玩家死亡 / 突破：`4x4`，单元格 `256x256` 或高清源 `512x512`。
- 普通怪 idle / combat：`2x2` 或 `2x3`，单元格 `160x160` 或高清源 `512x512`。
- 精英怪：`2x3`，单元格 `256x256` 或高清源 `512x512`。
- Boss idle / aura：`3x3`，单元格 `512x512`。
- Boss cast / death：`4x4`，单元格 `512x512` 或 `768x768`。
- Projectile：`1x4` 或 `2x2`，单元格 `96-160px`；高清源可用 `512px` 单格。
- Impact：`2x2`，小 `128x128`，中 `256x256`，大 `384-512px`。
- 所有原始图：纯 `#FF00FF` 背景，无文字、无边框、无 UI、每格同尺寸、主体不碰边。

### 11.3 统一但差异化

统一项：

- 视角：top-down / 斜 45 度，略俯视。
- 风格：暗色水墨轮廓 + 高饱和五行粒子。
- 轮廓：深墨描边，低噪声材质，发光只给元素、稀有、危险。
- 颜色：主体暗，五行色只作为能量层。

差异化：

- 玩家：冷玉青 / 骨白轮廓，动作干净，像道心稳定的修士。
- 普通怪：剪影简单，1 个识别点，例如爪、角、虫壳、鬼火。
- 精英怪：2-3 个识别点，例如背旗、符链、异色核心、破碎法器。
- Boss：大剪影 + 阶段化形态，必须有唯一视觉主题，例如血月、雷劫、骨莲、黑水龙影。
- 宠物：圆润、小体量、低攻击性，用尾焰或灵环表达能力。
- 同屏主色最多 2 个，例如雷紫 + 水蓝，不要五色全开。

### 11.4 角色与 VFX Prompt 要点

玩家：

```text
2D top-down 3/4 view cultivation roguelite hero sprite sheet, dark ink-wash xianxia style, clean HD game sprite, black ink silhouette, jade cyan and bone white accents, high saturation elemental particles kept close to body, readable full body, stable feet anchor, same scale in every frame, solid #FF00FF background, no text, no UI, no frame borders
```

普通怪：

```text
2D top-down 3/4 view dark ink-wash monster sprite sheet for cultivation roguelite, simple readable silhouette, corrupted spirit beast, black ink body, one clear elemental accent, high contrast eyes/core, clean HD sprite, same size every frame, solid #FF00FF background, no text, no UI
```

精英怪：

```text
elite cultivation demon creature, larger threatening silhouette, dark ink armor, glowing talisman chains, saturated thunder/fire/water particles, readable attack pose, not too noisy, clear weak-point core, top-down 3/4 clean HD sprite sheet, solid #FF00FF background
```

Boss：

```text
huge xianxia roguelite boss sprite, dark ink-wash mythic silhouette, ancient demon cultivator / calamity beast, massive body, ritual halo, saturated elemental storm particles, readable head arms core, cinematic but gameplay-readable, top-down 3/4 view, clean HD, solid #FF00FF background, no text
```

技能 VFX：

```text
2D game VFX sprite sheet, xianxia elemental spell, dark ink smoke base with high saturation particles, clear gameplay shape, loopable projectile / impact burst, transparent-feeling energy, no caster body, no UI, no text, solid #FF00FF background, same size each frame
```

固定负向：

```text
no realistic photo, no 3D render, no western cartoon, no low contrast, no busy background, no text, no UI, no watermark, no frame border, no cropped body, no edge touching, no inconsistent scale, no huge detached FX in body animation
```

---

## 12. 组件库

### 12.1 UIFoundation

| 组件 | 用途 | 状态 |
|---|---|---|
| `InkPanel` | 水墨暗底面板 | normal、strong、danger、transparent |
| `InkButton` | 文本按钮 | normal、hover、pressed、disabled、focused、selected |
| `InkIconButton` | 图标按钮 | normal、hover、pressed、disabled、focused、selected |
| `InkLabel` | 标题/正文/数值 | title、body、caption、number、danger |
| `InkProgressBar` | 真元、护盾、Boss、修为 | normal、low、critical、shielded |
| `InkTag` | 五行、品质、状态 | element、rarity、status、weather |
| `InkTooltip` | 悬浮说明 | title、description、delta、source |
| `InkCard` | 奖励/事件/遗泽 | common、rare、epic、legendary、dao、forbidden、locked |

### 12.2 GameHUD

| 组件 | 内容 |
|---|---|
| `PlayerVitalsHUD` | 真元、护盾、境界、灵石、资源 |
| `BuildSigilHUD` | 4-6 个构筑符印 |
| `SkillDockHUD` | LMB/Space/Q/E/R/V |
| `WeatherSigilHUD` | 天气、地形、元素倾向 |
| `ObjectiveRailHUD` | 魔劫进度、波次、Boss 血量 |
| `CombatToastHUD` | 短反馈轨 |
| `DamageNumberLayer` | 飘字，合并与降频 |
| `ThreatCompassHUD` | 威胁方向 |

### 12.3 RunFlowUI

| 组件 | 内容 |
|---|---|
| `MainMenuView` | 继续、新局、札记、设置 |
| `RunSetupView` | 道心、角色、灵根、种子、遗泽 |
| `RewardChoiceView` | 三选一、重随、禁忌确认 |
| `BreakthroughView` | 境界、天赋、词条槽 |
| `EventChoiceView` | 插画、短叙事、选项 |
| `ShopView` | 商品、价格、代价、购买 |
| `PauseCodexView` | 构筑、札记、设置、种子 |
| `DeathReincarnationView` | 道消、遗憾、遗泽 |
| `RunResultView` | 结算、解锁、再开 |

---

## 13. 动效规格

### 13.1 基础时长

| 场景 | 时长 |
|---|---:|
| 按钮 hover | 0.2-0.35 秒 |
| 按钮确认 | 0.18 秒 |
| 普通奖励入场 | <= 0.45 秒 |
| 稀有奖励入场 | <= 0.8 秒 |
| 传说/禁忌奖励入场 | <= 1.2 秒 |
| 事件入场 | <= 0.5 秒 |
| Boss 破势 | <= 0.6 秒 |
| 隐藏链首次发现 | <= 1.0 秒 |
| 隐藏链复触发 | <= 0.35 秒 |
| 突破/道统首见 | <= 1.5 秒 |
| 突破/道统复见 | <= 0.7 秒 |
| 死亡镜头 | <= 1.2 秒 |

### 13.2 必须可跳过

- 奖励卡翻面。
- 事件插画展开。
- 结算统计滚动。
- 死亡遗言长文本。
- 隐藏链札记解锁说明。
- 突破成功大演出复看版本。

### 13.3 不可跳过但必须极短

- 濒死警告。
- Boss 大招预警。
- 地面危险预警。
- 技能可用反馈。
- 禁忌代价确认。

### 13.4 五行粒子语言

| 元素 | 形态 | 速度 | 用途 |
|---|---|---|---|
| 火 | 短尾火星、爆裂 | 快 | 爆燃、灼烧、禁忌代价 |
| 雷 | 折线、瞬闪、残影 | 极快 | 麻痹、连锁、雷罚 |
| 水 | 液滴、弧线、扩散 | 中慢 | 治疗、积水、冰水联动 |
| 木 | 孢光、上升、生命脉冲 | 中 | 回复、毒、召唤 |
| 土 | 碎片、沉降、厚重冲击 | 慢 | 护盾、地脉、震地 |
| 玄/无 | 灰白墨尘、逆流 | 慢 | 轮回、时间、禁术 |

---

## 14. Godot 技术落地

### 14.1 CanvasLayer 层级

```text
Root
├─ WorldLayer                 # 2D 战斗世界，Node2D
├─ WorldVFXLayer              # 天气、地面、战斗粒子，Node2D/CanvasLayer
├─ UILayer_GameHUD            # CanvasLayer layer=10
│  └─ HUDRoot Control
├─ UILayer_CombatFeedback     # CanvasLayer layer=20
│  ├─ DamageNumbers
│  ├─ CombatToasts
│  └─ EdgeWarnings
├─ UILayer_Modal              # CanvasLayer layer=40
│  └─ ModalStackRoot
├─ UILayer_Tooltip            # CanvasLayer layer=60
├─ UILayer_FadeTransition     # CanvasLayer layer=80
└─ UILayer_Debug              # CanvasLayer layer=100，仅开发期开启
```

规则：

- HUD 不直接挂在角色、敌人、房间节点下。
- 模态全部走 `ModalStackRoot`，同一时间只允许一个主模态抢输入。
- Tooltip 不参与暂停逻辑，只跟随鼠标/焦点刷新。
- 战斗飘字和世界粒子分开。
- UI 根节点使用 `Control`，不使用 `Node2D` 手写排版。

### 14.2 资源目录

```text
game/assets/ui/themes/
game/assets/ui/components/
game/assets/ui/icons/
game/assets/ui/frames/
game/assets/ui/hud/
game/assets/ui/backgrounds/
game/assets/ui/particles/
game/assets/ui/shaders/
game/assets/ui/fonts/
```

### 14.3 命名规范

```text
ui_[screen]_[role]_[variant]_[size].png
ui_icon_[domain]_[name]_[size].png
ui_frame_[component]_[state]_[scale].png
ui_particle_[element]_[purpose]_[size].png
ui_shader_[purpose].gdshader
theme_[style]_[variant].tres
```

示例：

```text
ui_icon_element_fire_64.png
ui_frame_reward_legendary_9slice.png
ui_particle_thunder_click_128.png
ui_shader_ink_flow.gdshader
theme_dark_ink_default.tres
```

### 14.4 最小资源清单

主题：

```text
game/assets/ui/themes/theme_dark_ink_default.tres
game/assets/ui/themes/ui_asset_manifest_dark_ink.json
game/assets/ui/themes/ui_particle_palette_dark_ink.json
```

字体：

```text
game/assets/ui/fonts/ui_font_body_sc.ttf
game/assets/ui/fonts/ui_font_title_sc.ttf
```

框体：

```text
game/assets/ui/frames/ui_frame_panel_ink_9slice.png
game/assets/ui/frames/ui_frame_button_normal_9slice.png
game/assets/ui/frames/ui_frame_button_pressed_9slice.png
game/assets/ui/frames/ui_frame_button_disabled_9slice.png
game/assets/ui/frames/ui_frame_card_common_9slice.png
game/assets/ui/frames/ui_frame_card_rare_9slice.png
game/assets/ui/frames/ui_frame_card_epic_9slice.png
game/assets/ui/frames/ui_frame_card_legendary_9slice.png
game/assets/ui/frames/ui_frame_card_dao_9slice.png
```

图标：

```text
game/assets/ui/icons/ui_icon_element_fire_64.png
game/assets/ui/icons/ui_icon_element_water_64.png
game/assets/ui/icons/ui_icon_element_thunder_64.png
game/assets/ui/icons/ui_icon_element_wood_64.png
game/assets/ui/icons/ui_icon_element_earth_64.png
game/assets/ui/icons/ui_icon_element_neutral_64.png
game/assets/ui/icons/ui_icon_danger_64.png
game/assets/ui/icons/ui_icon_lock_64.png
game/assets/ui/icons/ui_icon_reroll_64.png
```

HUD：

```text
game/assets/ui/hud/ui_hud_hp_bar_9slice.png
game/assets/ui/hud/ui_hud_skill_slot_9slice.png
game/assets/ui/hud/ui_hud_skill_cooldown_mask.png
game/assets/ui/hud/ui_hud_weather_badge_9slice.png
```

粒子：

```text
game/assets/ui/particles/ui_particle_fire_burst_128.png
game/assets/ui/particles/ui_particle_water_burst_128.png
game/assets/ui/particles/ui_particle_thunder_burst_128.png
game/assets/ui/particles/ui_particle_wood_burst_128.png
game/assets/ui/particles/ui_particle_earth_burst_128.png
game/assets/ui/particles/ui_particle_ink_drift_128.png
```

Shader：

```text
game/assets/ui/shaders/ui_shader_ink_flow.gdshader
game/assets/ui/shaders/ui_shader_element_glow.gdshader
```

### 14.5 性能预算

| 项目 | 预算 |
|---|---:|
| UI 主动刷新 | <= 1.0 ms/frame |
| 常驻 HUD redraw | <= 10 次/秒 |
| DamageNumber 同屏 | <= 80，超出聚合 |
| CombatToast 同屏 | <= 4 |
| HUD 常驻粒子 | <= 80 |
| 全屏峰值粒子 | <= 300，<= 1.2 秒 |
| 同屏 shader material | <= 8 |
| 战斗常驻 shader | <= 4 |

低配模式：

- 关闭墨流背景。
- 粒子数量降低 50%。
- 关闭非关键 glow。
- 卡面流光改静态贴图。
- 大型背景不做每帧变形。

### 14.6 输入规则

- 鼠标、键盘、手柄焦点状态必须一致。
- `Esc` 优先关闭 Tooltip/子面板，再关闭主模态，再打开暂停。
- 奖励、突破、死亡结算期间暂停战斗输入。
- HUD 不抢游戏输入。
- 所有按钮状态包含 normal、hover、pressed、disabled、focused、selected。
- 高饱和反馈必须可在设置中降级。

---

## 15. 分辨率适配

设计基准：1920x1080。  
必测分辨率：1280x720、1600x900、1920x1080、2560x1440。  
预留：16:9、20:9、平板 4:3。

规则：

- Control 使用 anchors 和 containers。
- HUD 四边布局，不依赖绝对像素。
- 底部技能槽使用 `HBoxContainer + CenterContainer`。
- 模态桌面最大宽度 1120px，最小边距 48px；720p 下自动缩到 92% 宽。
- 中文文本允许换行，按钮文字必要时缩短或转图标。
- Tooltip 不得出屏，自动翻转方向。
- 关键按钮触控热区不小于 44x44px。

---

## 16. MVP 实施批次

### MVP 0：技术底线

- 建立 token、主题、CanvasLayer 层级、字体层级。
- 暂不做复杂 shader。
- 用静态 9-slice 和 StyleBox 验证排版。

验收：

- 1920x1080 与 1280x720 无重叠。
- 中文显示正常。
- Headless 启动无 parser/type 错误。

### MVP 1：战斗 HUD 可读版

- 真元、技能 Dock、冷却、危险提示、目标进度、天气签。
- 中心 70% 安全区。
- 技能可用反馈清晰。

验收：

- 玩家 0.2 秒能读出生存、技能、危险、目标。
- 10 分钟战斗 UI 节点不持续增长。

### MVP 2：奖励卡 1 秒可读版

- 三选一卡牌固定结构。
- 稳定增强、构筑推进、破格诱惑、灰色选项、禁忌选项。
- 选择后飞入构筑符印。

验收：

- 1 秒看懂每张卡的流派、收益、代价。
- 每次至少 1 张改变玩法。

### MVP 3：死亡结算再开版

- 死亡遗憾镜头。
- 结算首屏：死因、名场面、遗憾、收益、遗泽、再开。

验收：

- 5 秒内知道为什么想重开。
- 再开入口首屏可见。

### MVP 4：水墨与粒子增强

- 局部墨晕、按钮粒子、奖励翻卡、突破/道统粒子。
- 粒子低配开关。

验收：

- 常驻粒子 <=80。
- 峰值粒子 <=300 且 <=1.2 秒。
- 低配降级风格仍成立。

### MVP 5：主题化与扩展

- `Theme.tres`、资源 manifest、五行 palette。
- 支持换皮、移动端安全区、低配视觉档位。

验收：

- 缺失资源 fallback 到默认主题，不出现黑块或中断。

---

## 17. 验收清单

### 17.1 视觉验收

- 暗底占画面 80% 以上，高饱和色不成为背景。
- 同屏主强调色不超过 2 个。
- 文字背后无高噪水墨纹。
- 稀有度同时使用形状、边缘、粒子、颜色表达。
- 书法不用于数值、冷却、词条正文。
- 奖励卡布局固定，不因稀有度改变信息位置。

### 17.2 战斗验收

- 中心 70% 战斗区无遮挡。
- 血量、技能、危险、目标 0.2 秒可识别。
- 地面危险生效前至少 0.45 秒预警；Boss 大招至少 0.9 秒预警。
- 低血 30% 弱警告，15% 强警告。
- 状态图标最多 6 个，超出合并。
- 连击大反馈只在 30、60、100、200 出现。

### 17.3 性能验收

- UI 主动刷新 <=1.0 ms/frame。
- 常驻 HUD redraw <=10 次/秒。
- DamageNumber 同屏 <=80，超出合并。
- 常驻 HUD 粒子 <=80。
- 峰值粒子 <=300 且 <=1.2 秒。
- 同屏 shader material <=8。
- 模态反复打开关闭 50 次无残留输入焦点、重复节点或明显内存增长。

### 17.4 工程验收

- Godot headless 启动无 parser/type 错误。
- 1920x1080、1280x720、2560x1440 无重叠、截断、Tooltip 出屏。
- 中文文本 UTF-8，无替换字符、UTF-8 误读痕迹或其他常见乱码。
- 所有玩家可见术语使用中文修仙术语：真元、灵石、道消、轮回、机缘、劫数、御风步。
- 代码变量使用英文：`hp_bar`、`reward_card`、`weather_badge`。

---

## 18. 禁止事项

1. 禁止中心区域常驻大面板。
2. 禁止高饱和装饰粒子常驻满屏。
3. 禁止把血量、技能冷却、地面危险做成低对比水墨风。
4. 禁止奖励卡只写“伤害 +10%”这类无玩法变化内容。
5. 禁止事件选项隐藏真实代价。
6. 禁止所有稀有度只靠颜色区分。
7. 禁止顶部频繁大字播报普通击杀、普通升级、普通资源变化。
8. 禁止战斗中长文本解释构筑。
9. 禁止 UI 与敌方弹幕使用相同危险色语言。
10. 禁止天气特效遮挡地面危险区。
11. 禁止把修仙感等同于厚金边、宫殿框、亮色云纹。
12. 禁止让低配降级后只剩黑色方块和白字。

---

## 19. AI 资产生成提示词库 v2

本节用于 image2 / 其他图像生成工具 / 美术外包 brief。目标不是“黑底加发光”，而是把《轮回仙途》的资产稳定生成成同一套高质量 2D 游戏美术：暗色水墨、玄玉冷光、旧金命痕、五行高饱和粒子，但中心可读、层级清楚、能直接服务高速战斗。

### 19.1 Prompt 拼装顺序

所有资产按同一顺序拼装，避免每次临时发挥导致风格漂移。

```text
[全局正向] + [资产类型契约] + [主题变量] + [玩法可读性约束] + [构图词] + [质量词] + [导出约束]
[全局负向] + [资产类型负向] + [拒收风险负向]
```

每次生成必须保存同名 `.prompt.txt` 或 manifest 字段：

```yaml
asset_id:
asset_class:
target_file:
canvas_size:
runtime_export_size:
alpha_strategy: transparent | magenta_ff00ff
sheet_grid:
stage_or_theme:
style_variant:
positive_prompt:
negative_prompt:
seed:
model:
generation_date:
source_image_or_ref:
postprocess_steps:
accept_status: accepted | rejected | needs_edit
accepted_by:
reject_reason:
qa_checks:
  - size_ok:
  - alpha_ok:
  - readability_at_runtime_size:
  - no_text_watermark:
  - center_safe_zone_ok:
  - runtime_object_not_baked:
notes:
```

### 19.2 全局正向

中文全局正向：

```text
《轮回仙途》暗色修仙 Roguelite 2D 手绘游戏美术，玄墨道场，五行照夜；以漆黑宣纸、湿墨晕染、干笔擦痕和低频纸纹建立暗色层次，冷玉青细结构线与骨白信息层保持清晰，旧金只作为磨损命痕、残碑断线和稀有点缀；高饱和五行粒子仅用于技能、天气、危险预警、品质反馈、突破、死亡与轮回信号，覆盖率受控。东方仙侠符箓、道痕、残碑、玉片、墨雾、灵脉裂纹作为图形语言。手绘高清 2D 游戏资产，非写实，非 3D，轮廓清楚，缩小后可识别，适合高速战斗和深色 UI。
```

English global positive:

```text
Samsara Ascension dark xianxia cultivation roguelite 2D hand-painted game asset, mysterious black ink dojo, five elements illuminating the night; layered black rice paper texture, wet ink wash, dry-brush abrasion and low-frequency paper grain create dark value depth; thin jade-cyan structure lines and bone-white readable surfaces stay crisp; restrained old-gold only appears as worn fate marks, broken stele lines and rare accents; high-saturation five-element particles are used only for skills, weather, danger warnings, rarity feedback, breakthrough, death and reincarnation signals, with controlled coverage. Eastern talisman marks, dao traces, broken steles, jade shards, ink mist and spiritual vein cracks as visual language. Clean HD hand-painted 2D game asset, non-photorealistic, non-3D, readable silhouettes, recognizable at runtime size, suitable for fast combat and dark UI.
```

### 19.3 全局负向

通用负向：

```text
不要照片写实，不要 3D 渲染，不要厚涂奇幻插画，不要欧美卡通，不要赛博霓虹城市，不要明亮仙宫，不要厚金宫殿框，不要页游充值框，不要透明玻璃拟物按钮，不要大面积彩虹渐变，不要满屏廉价魔法粒子，不要高 Bloom，不要中心强光晕，不要中心复杂大圆阵，不要文字、数字、水印、logo、箭头、UI 标注，不要主体贴边，不要裁切，不要模糊低清，不要高噪声覆盖战斗中心或文字区，不要把角色、怪物、宝箱、门、柱、祭坛、墙体烘进地图底图。
```

防廉价粒子与防页游感：

```text
禁止五彩烟花，禁止霓虹灯管线，禁止过亮电光铺满画面，禁止金碧辉煌宫殿框，禁止中心大法阵抢视线，禁止粒子无玩法意义地常驻，禁止背景亮度超过角色、敌弹、危险圈和关键 UI 信息。
```

### 19.4 美术导演约束

构图：

```text
构图必须遵守“中心静、边缘活、角落藏故事”。中心 60% 不是纯空白，而是低对比、低频纹理、可读地表或可安装 UI 的暗面；边缘 240px 承载主题叙事，但不能四边平均堆满细节。每张 1920x1080 母版只能有 1 个主视觉重心和 1 个次级重心。
```

水墨：

```text
水墨风格应偏“博物馆级暗色纸本 + 手绘游戏概括”，不是国风插画堆满细节。笔触以大块湿墨、干笔擦痕、低频纸纹为主，细符线只作为结构提示。禁止把画面做成仙宫壁纸、赛博符文背景、厚涂奇幻场景或亮色二次元特效图。
```

材质：

```text
主材质比例建议：漆黑宣纸和湿墨 70%，冷玉薄线和骨白信息层 15%，旧金/矿物/裂纹 10%，高饱和五行粒子 5% 以下。暗处必须有 3-5 个低对比层级，不允许大面积纯黑死区，也不允许噪点铺满。
```

灯光：

```text
灯光采用低照度、单主光、局部反光。默认同一批资产使用左上冷光、右下弱墨影。允许边缘微弱逆光、符痕自发光、粒子短暂辉光；禁止全屏均匀发亮、中心大光晕、强 Bloom、舞台聚光灯、明亮天堂感。
```

五行形状语言：

| 元素 | 形状 | 粒子 | 禁止 |
|---|---|---|---|
| 火 | 尖裂、短尾、爆点 | 橙红火星，边缘迅速衰减 | 烟雾铺满、脏灰火云 |
| 雷 | 折线、断闪、三角阵 | 紫白瞬闪，硬边短残影 | 蓝雾填满图标 |
| 水 | 弧线、涟漪、镜面 | 蓝色水弧，透明软边 | 大面积水花噪点 |
| 木 | 芽状、脉络、节点 | 绿色生命脉冲，三点发光 | 密集树叶团 |
| 土 | 方印、沉降、碎片 | 土金重心，低速石屑 | 泥黄色大底 |
| 禁忌 | 逆纹、破边、裂环 | 紫红逆流粒子 | 温暖正向金光 |

### 19.5 工程质量词库

```text
清晰剪影；主体外轮廓与背景明度差至少 25%；缩放到目标显示尺寸后仍能分辨主形状；透明资产每格保留 12% 内边距；sprite sheet 每格主体高度误差小于 5%；同一批资产统一光源方向为左上冷光、右下弱墨影；高饱和色面积不超过全屏画面 8%，技能/VFX 可到 18%；地图中心 60% 低噪、无高对比装饰；UI 文本区低纹理、低亮点、可叠骨白字和冷玉青字。
```

### 19.6 构图词库

```text
地图底图：俯视 2D，foundation-only 地面层，中心 60% 留空低噪，边缘 240px 承载叙事细节。
全屏 UI：1920x1080，主视觉偏左或偏上，右侧/下侧预留低噪面板区，禁止中心强光抢菜单。
角色怪物：俯视 3/4，脚底锚点稳定，头部、武器、核心器官分层明确。
图标：中心主形占 62%-72%，外圈符印占 12%-18%，四角不放关键细节。
卡框：标题区、图标区、描述区、标签区固定，装饰不穿过文字区。
VFX：核心形状先读，粒子尾迹后读；预警圈中心透明，边界高对比。
```

### 19.7 资产变量槽位

| 资产类 | 必填槽位 | 可选槽位 | 关键工程约束 |
|---|---|---|---|
| 全屏 UI 背景 | `screen_id`、`主视觉位置`、`低噪留白区`、`情绪材质` | `旧金比例`、`五行点缀` | 不含文字/UI 控件；中右或中下可放面板 |
| 地图底图 | `stage_id`、`地表材质`、`边缘叙事物`、`元素色`、`composition_flow` | `天气痕迹`、`灵脉方向` | 只画地面；中心 60% 低噪；不可烘入碰撞物 |
| Tileset | `tile_family`、`grid`、`cell_size`、`terrain_effect` | `stage_skin`、`transition_edge` | seamless；无 props；无棋盘重复噪声 |
| 地形 props | `prop_role`、`碰撞/伤害/减速语义`、`单格尺寸` | `stage_skin`、`aura_color` | 3x3 atlas；每格 12% padding；纯洋红或 alpha |
| 玩家角色 | `职业身份`、`服装主形`、`动作状态`、`sheet_grid` | `元素流派`、`法器小件` | 身体动画不能带大范围弹幕；脚底锚点一致 |
| 普通怪/精英怪 | `enemy_role`、`剪影标记`、`攻击属性`、`显示高度` | `弱点核心`、`腐化材质` | 同屏缩小后靠剪影区分；每只怪只用 1 个主元素 |
| Boss | `boss_theme`、`巨大剪影`、`弱点核心`、`前摇方向` | `登场_aura`、`阶段变化` | 华丽但头/手/核心/危险方向必须可读 |
| 技能图标 | `skill_id`、`元素`、`主形状`、`外圈符印` | `品质点缀`、`流派标记` | 72x72 可读；无文字数字；不要做成完整卡框 |
| 技能 VFX | `vfx_type`、`元素`、`运动方向`、`命中反馈` | `循环帧`、`衰减方式` | projectile / impact / 预警分开生成 |
| 奖励卡框 | `rarity`、`布局区块`、`边框语言`、`文字区材质` | `禁忌裂纹`、`隐藏封印` | 稀有度变化不改变信息区坐标 |
| 天气图标 | `weather_id`、`天气主形`、`强调色`、`外轮廓` | `地表影响暗示` | 与技能图标、危险图标不可混淆 |

### 19.8 风格变量枚举

| 变量 | 主色 | 形状语言 | 粒子语言 | 用途 |
|---|---|---|---|---|
| `ink_jade` | 墨黑、冷玉青 | 薄玉片、细符线 | 青色微尘 | 默认 UI/HUD、问道 |
| `thunder_fire` | 雷紫、火红 | 折线雷纹、短尾火星 | 快闪、爆点 | 雷火构筑、爆发奖励 |
| `forbidden_void` | 紫红、黑墨 | 破边、逆纹、裂痕 | 逆流粒子 | 禁忌、心魔、代价 |
| `old_gold_legacy` | 旧金、骨白 | 残碑断线、命盘 | 短金尘 | 稀有、传承、结算遗泽 |
| `moon_soul` | 月蓝、灰白 | 残月弧、漂浮墨雾 | 慢速魂光 | 元婴、魂、轮回 |
| `earth_sigil` | 土金、深褐灰 | 方印、沉降碎片 | 慢速碎光 | 护盾、地脉 |

### 19.9 全屏 UI 背景 Prompt

全屏 UI 通用模板：

```text
1920x1080 full-screen dark ink-wash cultivation roguelite UI background for [screen_id], Samsara Ascension visual style, black rice paper base with layered wet ink wash and dry-brush abrasion, one clear main focal point at [main_focus_position], one secondary focal point at [secondary_focus_position], [low_noise_ui_area] kept dark, quiet and readable for UI panels/buttons/cards, edge storytelling with [edge_story_materials], thin jade-cyan dao traces, restrained old-gold worn fate marks, high saturation five-element particles under 5 percent, low-key single main light from upper-left, weak ink shadow to lower-right, elegant oppressive museum-grade dark paper painting, no text, no logo, no UI widgets, no characters unless explicitly requested, no bright palace, no heavy gold frame, no center bloom.
```

主菜单 / 轮回碑：

```text
1920x1080 full-screen main menu background, broken reincarnation stele in left-middle x=260..780 y=160..920, faint life flame near bottom center-left x=920..1040 y=820..980, right menu area x=1160..1640 y=280..800 kept low-noise and dark, black rice paper, layered wet ink, dry brush cracks, jade-cyan fate lines carved into the stele, old-gold worn cracks only on broken edges, sparse cyan dust and red life sparks, one quiet oppressive focal point, no text, no logo, no UI buttons, no character, no palace, no thick gold frame.
```

开局设置 / 道心天命：

```text
1920x1080 full-screen run setup background, dark inner cultivation court made of black jade stone and rice paper shadow, left x=120..840 low-noise area for dao-heart choices, right x=980..1740 scroll-like low-noise area for destiny summary, subtle jade-cyan talisman meridians, small old-gold destiny dust, calm upper-left cold light, no readable characters, no UI widgets, no bright palace, no large glowing circle, no thick gold border.
```

死亡轮回 / 结算：

```text
1920x1080 full-screen death and reincarnation result background, black ink abyss, broken soul mirror, old-gold fate threads, pale moon-blue soul mist, cracked reincarnation pool behind lower middle but dimmer than UI text, right and lower areas kept low-noise for result panels and replay button, emotional but restrained, low-key single light, no text, no UI, no character body, no bright heaven palace, no photorealism.
```

### 19.10 地图底图 Prompt

地图通用模板：

```text
1920x1080 top-down 2D hand-painted HD battle arena background, dark xianxia ink-wash style, foundation-only ground layer, [stage_theme], [composition_flow], [center_floor_treatment], [exclusive_material_language], [edge_story_layout], center 60 percent uses broad matte value blocks, low-frequency ground texture, no high-frequency speckles, no repeated tile noise, no circular focal point, combat primary zone x=288..1632 y=162..918 unobstructed, edge details richer than center but remain flat ground marks only, high saturation [element_color] accents under 8 percent and mostly near edges, no characters, no enemies, no boss, no UI, no text, no props, no tall objects, no collision objects, no treasure, no portal, no buildings, no altar, no giant glowing circle in the center, do not reuse the same crack pattern, same circular rune layout, same edge rocks, same glowing vein distribution, or same visual center as other stages.
```

五主题地图变量：

| `stage_id` | 构图 | 边缘叙事 | 中心低噪 | 独占材质 |
|---|---|---|---|---|
| `qi_refining_verdant` | 柔和 S 形水痕，湿地从两角渗入 | 边缘苔痕、浅水膜、低矮灵草影 | 平滑湿泥，少量浅苔线 | 墨玉湿泥、青萤露点、湿苔 lace |
| `foundation_cavern` | 左右挤压的洞窟岩层，斜向矿脉 | 边缘断玉脉、洞壁投影、矿粉 | 磨平黑青石，裂纹稀疏 | 黑青洞石、玉髓矿脉、云母尘 |
| `golden_core_demon` | 四角侵蚀，裂纹向中心衰减 | 魔纹灼痕、灰烬、烧焦符疤 | 哑光紫黑地面，避免满屏红 | 烧裂黑玉、朱砂魔痕、ember ash |
| `nascent_soul_ruins` | 破碎石板在边缘形成残阵节奏 | 残金阵线、月尘、魂雾污痕 | 冷灰大石面，低对比板缝 | 风化青石、残金嵌线、月魄灰尘 |
| `tribulation_thunder` | 雷击弧线压在外圈，中心留空 | 雷烧纹、玻璃裂、紫白电痕 | 炭灰石面，微弱裂纹 | 雷击灰石、玻璃化裂痕、fulgurite 雷熔脉 |

五主题 prompt 片段：

```text
qi_refining_verdant: asymmetric marsh-basin composition, soft S-shaped seepage flowing from upper-left edge to lower-right edge but fading before center, smooth damp jade mud center, exclusive wet moss lace, cyan dew dots, thin water-film reflections, flat low reed shadows only at border.
```

```text
foundation_cavern: compressed cavern-strata composition, diagonal black-teal stone pressure bands from left and right edges, clean worn stone center, exclusive cold jade marrow veins, mica dust, damp cave ink shadows, broken mineral seams clustered along border.
```

```text
golden_core_demon: aggressive corner-inward corruption composition, claw-like crimson cracks starting from four edges and dying out before combat center, matte black-purple obsidian center, exclusive burnt black jade glaze, cinnabar demon scars, ember ash, scorched golden-core talisman burns near edges.
```

```text
nascent_soul_ruins: ancient ruin-floor composition with broken orthogonal slab rhythm around edges and a quiet open moonlit center, exclusive weathered blue-gray stone, old-gold inlay fragments, pale soul-mist stains, eroded dao-pattern dust, no palace silhouette.
```

```text
tribulation_thunder: storm-pressure composition with radial thunder scorch arcs kept outside the combat zone, charcoal stone center with faint glass cracks, exclusive blue-white lightning vitrification, fulgurite veins, violet storm stains, edge thunder burns, no giant bolt crossing center.
```

### 19.11 Tileset Prompt

基础地表 tileset：

```text
1024x1024 dark xianxia top-down HD hand-painted tileset, 8x8 grid, 128x128 per tile, seamless edges, foundation ground tiles only, no prop objects, no characters, no UI, no text. Include base ground variants: dark ink soil, damp jade mud, black teal cave stone, burnt black jade, weathered moon stone, charcoal thunder stone. Include transition tiles with soft irregular edges, low-frequency texture, no checkerboard repetition, no high-frequency speckles, readable after export to 1280x720.
```

元素效果 tileset：

```text
1024x1024 dark xianxia top-down HD hand-painted element terrain effect tileset, 8x8 grid, 128x128 per tile, flat ground overlays only: shallow water, swamp mud, ember fissure, frost sheet, thunder scorch, demon corruption. Each effect distinguished by both shape and color, saturation controlled, brighter than base ground but dimmer than combat VFX, no tall objects, no walls, no glowing center circle, no UI, no text.
```

### 19.12 地形 Props Prompt

九宫格地形母版：

```text
576x576 transparent prop atlas for a dark xianxia cultivation roguelite 2D top-down game, 3x3 grid, each cell 192x192, solid #FF00FF background if alpha is unavailable, consistent clean HD hand-painted dark ink-wash style, readable top-down props, each prop fits inside central 50-60 percent of its cell, at least 12 percent padding, no prop touching cell edges, no grid lines, no labels, no UI, no text.
Cell 1 stone blocker: low dark ink boulder cluster, squat oval silhouette, collision core smaller than visual edge, no tall pillar.
Cell 2 shallow water pool: flat irregular puddle, dark jade water film, cyan rim highlight, transparent soft edge.
Cell 3 swamp snare: sticky black-green mud patch, root-like flat tendrils, readable trap shape, no tall grass wall.
Cell 4 fire pit: low ember fissure on burnt ground, orange-red core under 8 percent, no campfire object.
Cell 5 ice patch: thin frosted ground sheet, pale blue cracked surface, slippery readable edge, no ice wall.
Cell 6 thunder mark: flat branching scorch sigil, blue-white tiny arcs, charcoal burn halo, no large lightning bolt.
Cell 7 demon growth: low corruption stain, purple-black organic veins, crimson pustule accents, no creature body.
Cell 8 spirit herb cluster: small low herb tufts with cyan dew, compact readable silhouette, no bush wall.
Cell 9 broken relic: flat shattered stone talisman fragments, old-gold inlay, low height, no readable text.
```

主题变体：

```text
qi_refining_verdant: wet jade moss, cyan dew, thin water film, no tall grass wall.
foundation_cavern: cold mineral veins, black cave stone, mica dust, no high stalagmite.
golden_core_demon: crimson corruption, burnt black jade, ember ash, no gore.
nascent_soul_ruins: pale moon dust, broken old-gold rune fragments, no readable text.
tribulation_thunder: blue-white lightning scorch, cracked charcoal stone, no giant lightning bolt.
```

### 19.13 角色资产 DNA

角色审核总句：

```text
角色靠暗色轮廓读身份，技能靠高饱和核心读功能；亮色必须有形状，粒子必须有边界，水墨不能把战斗信息糊掉。
```

层级差异：

| 层级 | 轮廓 | 材质 | 粒子 | 动作 |
|---|---|---|---|---|
| 玩家 | 中等身高、修长、脚底锚点稳定，轮廓干净 | 黑墨布袍 + 骨白脸手 + 冷玉细边 | 贴身、少量、偏青玉，只表达道心和当前流派 | 姿态克制，动作准，施法手势清楚 |
| 普通怪 | 小而简单，最多 1 个识别点 | 粗墨、腐化皮壳、低细节 | 只用 1 种元素色，小核心或眼光 | 动作短促，攻击方向明显，不做复杂前摇 |
| 精英 | 比小怪大 1.7-2 倍，2-3 个识别点 | 墨甲、符链、破法器、异色核心 | 允许 1-2 种元素色，但集中在弱点/武器/背旗 | 必须有可读前摇：抬手、蓄力、旋身、锁链展开 |
| Boss | 大剪影唯一主题，远看就能认出 | 残碑、骨莲、劫雷、黑水、禁忌裂纹等专属材质 | 高饱和但分层：核心最亮，边缘次亮，身体保持暗 | 阶段化动作，大招前摇必须夸张、慢、可躲 |
| 宠物 | 小、圆、低攻击性 | 软墨、玉铃、灵环 | 低亮尾焰或小环，不抢玩家 | 跟随、轻跳、辅助施法，不做 Boss 级特效 |

角色统一风格锁：

```text
2D top-down 3/4 view, dark xianxia cultivation roguelite game sprite, 墨渊五行 visual style, black ink silhouette, low-noise hand-painted body material, high saturation five-element energy used only as readable gameplay accents, strong readable shape at runtime size, centered full body, stable feet anchor, same scale every frame, solid #FF00FF background, no text, no UI, no frame border, no cropped body, no edge touching, no photorealism, no 3D render, no western cartoon, no noisy texture, no huge detached FX in body animation.
```

### 19.14 玩家角色 Prompt

玩家模板：

```text
2D top-down 3/4 view cultivation roguelite player hero [idle / run / cast body / attack body] sprite sheet, [grid], same character identity across all actions, slim readable cultivator silhouette, black ink robe with bone-white face and hand accents, jade-cyan thin robe trim, calm dao-heart posture, clean sword/talisman/caster gesture, close-to-body jade cyan spiritual particles only, no large projectile, no impact burst, no wide slash FX, stable feet anchor, readable at 96px height on 1920x1080, 墨渊五行 visual style, solid #FF00FF background.
```

雷火法修施法身体例：

```text
2D top-down 3/4 view cultivation roguelite player hero cast body sprite sheet, 2x3 grid, same character identity across all frames, slim readable cultivator silhouette, black ink robe, jade-cyan talisman hand gesture, bone-white face highlight, two short violet lightning sparks around fingers, three tiny orange-red fire embers near sleeves, particles kept within body silhouette radius, focused forward-lean casting pose, stable feet anchor, body height consistent, no detached spell ball, no explosion, solid #FF00FF background, no text, no UI, no edge touching.
```

### 19.15 怪物与 Boss Prompt

普通怪模板：

```text
2D top-down 3/4 view cultivation roguelite common enemy sprite sheet, [2x2 / 2x3 grid], simple black ink corrupted silhouette, one clear identity marker only: [single horn / claw arm / hollow mask / ghost flame core / cracked shell], one element accent only: [fire / thunder / water / wood / earth / void], high-contrast eye or core, low-noise body, aggressive but small profile, readable at 56-84px height, same scale every frame, solid #FF00FF background.
```

精英模板：

```text
2D top-down 3/4 view elite cultivation demon enemy sprite sheet, 2x3 grid, larger threatening silhouette, black ink armor plates, two or three identity markers: [back banner / talisman chains / broken magic weapon / glowing weak-point core], saturated [element pair] accents controlled around silhouette, clear attack wind-up pose, visible weak-point core, readable at 112-150px height, no noisy all-over glow, solid #FF00FF background.
```

Boss 模板：

```text
2D top-down 3/4 view huge xianxia roguelite boss sprite sheet, [3x3 idle aura / 4x4 cast / 4x4 death], massive mythic black ink silhouette, unique theme: [blood moon / thunder calamity / bone lotus / black water dragon shadow / forbidden golden core], readable head arms weapon and core, large ritual halo kept close behind body, phase-change visual marks, saturated elemental storm particles concentrated on core, weapon, halo edge and attack hand, readable at 320-420px height, cinematic but gameplay-readable, no noisy full-screen FX, solid #FF00FF background.
```

Boss 例子：

```text
雷劫劫主 Boss，3x3 idle aura sheet, massive ink-robed calamity cultivator, horn-like thunder crown silhouette, one giant jade-black ritual halo behind shoulders, bright blue-white lightning core in chest, old-gold cracked talisman plates on arms, violet thunder particles only on halo edge and raised hand, clear pre-cast posture, center body remains dark and readable, no text, no UI, no edge touching.
```

### 19.16 技能图标 Prompt

高饱和不脏的比例：

```text
60% dark ink silhouette / clean negative space
25% pure saturated elemental core
10% thin bright rim light or sparks
5% bone-white or jade-cyan highlight
no gray muddy glow, no full-canvas smoke, no rainbow particles, no noisy texture
```

技能图标模板：

```text
512x512 transparent skill icon for dark xianxia cultivation roguelite UI, circular or octagonal talisman seal composition, one large black ink silhouette as the main readable shape: [blade / seal / fist / fan / mirror / lotus / chain], pure high saturation [element color] energy core, thin jade-cyan structure lines, small bone-white highlight on the focal edge, clean negative space around the shape, strong readability at 72x72 HUD size, no text, no numbers, no UI frame, no muddy smoke, no rainbow glow, no photorealistic render, solid #FF00FF background if transparency unavailable.
```

图标例子：

```text
火符斩：black ink talisman blade silhouette, pure orange-red flame core, three sharp ember tails, tiny bone-white hot edge, no smoky gray cloud.
雷剑阵：jade sword seal in center, angular violet lightning folded into triangular array, black ink negative space between lightning lines, no blue fog filling the icon.
水镜步：black ink crescent mirror, pure cyan-blue water arc, pale afterimage slash, smooth curved silhouette, no splash noise covering center.
木灵缠：black ink vine ring, saturated green life pulse at three nodes, small sprout glyph, clean circular motion, no dense leaves.
土御印：heavy square black ink seal, ochre-gold stone core, four falling stone shards, thick stable silhouette, no brown muddy background.
禁血契：cracked black seal, purple-red reversed veins, bright danger core, broken rim, no warm gold, no decorative clutter.
```

### 19.17 技能 VFX Prompt

Projectile：

```text
512x512 2D game VFX projectile sprite sheet, 2x2 grid, dark xianxia elemental spell projectile, compact readable core shape: [needle / orb / blade wave / talisman dart / crescent / chain spark], black ink smoke only as thin trailing base, pure high saturation [element] core, bright rim on leading edge, transparent-feeling fading tail, loopable motion, readable at 14-36px core size, no caster body, no impact explosion, no full-cell smoke cloud, no muddy mixed colors, solid #FF00FF background.
```

Impact：

```text
768x768 2D game VFX impact burst sprite sheet, 2x2 grid, clear hit shape: [radial burst / directional slash / ring shockwave / ground crack / talisman pop], dark ink fragments at outer edge, pure saturated [element] burst at center, bone-white hot center for 1 frame, edges fade quickly, center readable, no projectile trail, no caster body, no gray dust covering the whole cell, solid #FF00FF background.
```

Boss 预警：

```text
1024x1024 transparent top-down boss warning decal, gameplay-first danger marker, thin high-contrast red-purple boundary, broken black ink talisman fragments around edge, center 75% transparent, one clear attack shape: [circle / cone / line / cross / expanding ring], readable on dark maps, no filled opaque circle, no decorative mandala, no text, no arrows, solid #FF00FF background if alpha unavailable.
```

VFX 例子：

```text
雷火飞符 projectile：compact talisman dart, black ink paper core, violet lightning leading edge, orange-red ember tail, 2x2 loop, no explosion.
水月斩 impact：directional crescent slash burst, cyan-blue water blade center, black ink droplets on outer arc, one bone-white sharp edge, no full-screen splash.
土脉震 impact：square shockwave, ochre-gold cracked ground lines, black ink stone fragments at four corners, center bright then quickly fading, no dusty brown fog.
禁忌血爆 impact：purple-red cracked ring, black reversed ink veins, bright red core only in center, outer edge transparent, dirty gray smoke forbidden.
```

### 19.18 奖励卡框 Prompt

卡框通用模板：

```text
720x1120 transparent reward card frame for a dark xianxia cultivation roguelite UI, vertical jade slip card frame, fixed layout zones for rarity line at top, large icon area in upper middle, title and description area in lower middle, tag strip at bottom, dark ink paper body, thin jade-cyan structure line, low-noise center panels, readable at 360x560 on a 1920x1080 screen, frame decoration stays within outer 12-16 percent, title/description/tag zones remain clean for Chinese text, 8px or less corner radius feel, no text, no numbers, no icon content, no filled background outside card, solid #FF00FF background if transparency is unavailable.
```

稀有度变量：

```text
common: bone-white ink edge, almost no particles.
rare: jade-cyan cut-corner line, tiny floating dust.
epic: old-gold double talisman line, short gold particles.
legendary: gold and violet edge light, subtle ink cracks.
dao: five-element asymmetric dao trace outline, controlled five-color particles under 8 percent.
forbidden: purple-red broken polluted edge, reversed particles, dangerous cracked border, no warm gold.
hidden: dark gold silhouette edge, unrevealed talisman seal, restrained mystery.
```

### 19.19 天气图标 Prompt

天气图标模板：

```text
256x256 transparent weather badge icon for dark xianxia cultivation roguelite HUD, ink-wash talisman badge silhouette, black ink base, jade-cyan thin outline, [weather_shape], one high saturation accent only, subject centered and occupying 70 percent, readable at 64x64 and still distinguishable at 32x32, no text, no numbers, no UI label, no watermark, solid #FF00FF background if transparency is unavailable.
```

天气变量：

| 天气 | `[weather_shape]` | 强调色 | 关键辨识 |
|---|---|---|---|
| 晴 | thin sun seal behind ink cloud | 旧金 | 轻、低饱和 |
| 雨 | slanted rain threads and water drop arc | 水蓝 | 斜雨 + 水滴 |
| 雷雨 | rain threads crossed by angular lightning | 雷紫 | 折线雷 |
| 烈阳 | cracked fire sun talisman | 火红 | 干裂 + 火星 |
| 风 | spiral ink gust talisman | 青白 | 旋风弧 |
| 雾 | layered pale ink mist | 灰白 | 软边雾 |
| 雪 | snowflake seal with ink wash edge | 冰蓝 | 雪晶 |
| 沙暴 | square earth dust swirl | 土金 | 土尘碎片 |

### 19.20 生成后拒收总表

任意资产命中以下问题，直接拒收或重抽：

1. 尺寸、比例、sheet grid、透明 / 洋红背景不符合目标规格。
2. 出现文字、数字、水印、logo、箭头、伪 UI。
3. 暗色水墨风丢失，变成写实、3D、欧美卡通、霓虹赛博、亮色仙宫或厚金页游。
4. 地图中心 60% 有高亮圆阵、高噪纹理、可误判为目标点的装饰。
5. 地图烘入角色、怪物、宝箱、墙、门、柱、祭坛、高树、大石等运行时对象。
6. 透明资产主体贴边、裁切、每格比例漂移超过 5%。
7. 玩家 attack/cast 身体表含大范围弹幕、剑气或 impact，导致身体缩小。
8. 图标缩到 `64x64` / `72x72` 后只剩色团，无法读出元素和技能主形。
9. 卡框文字区有强纹理、亮点、裂纹穿过，放中文后不可读。
10. Boss 华丽但弱点核心、前摇方向、身体朝向不可读。
11. 五主题并排只像换色，地表材质、构图骨架和边缘叙事没有差异。
12. 高饱和色铺满画面，抢过敌弹、技能、危险预警。
13. 友方火/雷与敌方危险红紫使用同一种发光语言，导致误判。
14. 下采样到 `1280x720` 后出现糊、脏、过锐噪点或线条断裂。

---

## 20. 最终设计判断

这套 UI 不追求“每一秒都华丽”，而追求“每一个关键瞬间都值得记住”。

常态：

```text
暗、薄、清楚、贴边。
```

关键瞬间：

```text
亮、短、准、能复述。
```

玩家应该记住的不是“这个 UI 很花”，而是：

- “我刚才雷术打进积水，整片战场导雷了。”
- “我差一格就觉醒道统，所以我必须再开。”
- “那张禁忌卡很危险，但我想试。”
- “死亡以后我的前世遗泽真的改变了下一局。”

这就是《轮回仙途》的 UI 目标：让修仙肉鸽的每一次选择、悟道、爆发、道消和轮回，都有清晰、克制、强烈的界面记忆点。
