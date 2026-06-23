# 《轮回仙途》角色与场景美术设计文档

> 版本：1.0  
> 引擎：Godot 4.6 · 2D 顶视角 45°  
> 基准分辨率：1920×1080  
> 美术风格：暗色水墨 × 高饱和五行粒子  
> 角色碰撞体基准：64×64px · 视觉体：72×72px

---

## 一、设计总则

### 1.1 角色 Sprite 设计规范

| 参数 | 值 | 说明 |
|------|-----|------|
| 角色碰撞体 | 64×64px | 逻辑碰撞区域 |
| 视觉体 | 72×72px | 含轮廓光与飞白毛边 |
| 身体剪影 | ~48×56px | 头部14×14 · 躯干20×24 · 双腿16×18 |
| 轮廓光 | 1-2px | 沿剪影内侧，元素对应色 |
| 飞白毛边 | 轮廓外1px | 随机散点，模拟毛笔笔触 |
| 动画帧数 | idle 4帧 · walk 4帧 · combat 4帧 | 2×2 网格排列 |

### 1.2 色彩体系引用

所有角色配色严格遵循设计系统色彩层级：

- **墨色系**（`ink.000`~`ink.500`）：60% 面积，服装主体、阴影
- **中性色**（`ink.600`~`ink.950`）：25% 面积，轮廓、高光、皮肤
- **元素色/品质色**：10% 面积，武器光效、粒子特效、技能标识
- **语义色**：5% 面积，战斗状态指示

---

## 二、六大角色 Sprite 设计

### 2.1 剑修（剑客）

> **视觉定位**：飘逸白衣如雪，剑气如虹贯穿暗夜，身形修长凌厉，衣袂在风中翻飞，尽显剑仙超然之姿。

**配色方案**

| 位置 | 颜色 | HEX | 说明 |
|------|------|-----|------|
| 长袍主色 | 素纸白 | `#E8DFD2` | 主体道袍，占角色面积 40% |
| 袍底渐变 | 宣白 | `#B8B0A8` | 袍摆渐变过渡 |
| 轮廓光 | 水·明 | `#00CCFF` | 剑气属性光，水系呼应 |
| 腰带/剑鞘 | 重墨 | `#1A1A22` | 深色束腰，反衬白衣 |
| 剑刃高光 | 净纸 | `#F5EEE2` | 剑锋最亮处 |
| 剑气粒子 | 水·明 | `#00CCFF` | 战斗时剑气流光 |
| 皮肤 | 暖白 | `#E0C8A8` | 微暖肤色 |

**精灵表规格**

| 动画 | 帧数 | 网格 | 帧尺寸 | 描述 |
|------|------|------|--------|------|
| idle | 4帧 | 2×2 | 72×72px | 身体微浮，白衣下摆轻微摆动，剑在身后悬浮，偶尔剑尖闪烁水蓝光点 |
| walk | 4帧 | 2×2 | 72×72px | 衣袂向后飘扬，步伐轻盈如踏风，脚下无尘 |
| combat | 4帧 | 2×2 | 72×72px | 拔剑斩击，剑身拖曳蓝色弧光，身体前倾发力 |

**视觉元素**
- 武器：长剑「清风」，剑身修长有弧度，剑格处有水纹装饰
- 服装：交领右衽白色道袍，广袖收口，腰束墨色丝绦，袍底有淡蓝水纹暗花
- 发型：黑色长发高束马尾，发带为水蓝色
- 特效：idle时剑尖有微弱水蓝光点漂浮；combat时剑气弧光为水蓝色扇形

**AI 生成提示词**

```
Chinese ink wash painting style, dark moody xianxia cultivator sprite, top-down 45-degree isometric view, sword master in flowing white robes, longsword with blue aura, dark background #0A0A0F, character centered, clean silhouette, white hanfu-style robe with blue water patterns, black belt, hair in high ponytail with blue ribbon, sword glowing light blue #00CCFF, 2x2 sprite grid, 4 frames, each frame 72x72 pixels, solid magenta #FF00FF background, no text, high contrast, particle effects in cyan-blue

ChatGPT版本:
水墨画风格，一位飘逸的白衣剑客，身穿素白汉服道袍，腰束黑色丝绦，长发高束马尾系蓝色发带。手持一柄寒光长剑，剑身泛着幽蓝水光，衣袂随风翻飞。背景深沉暗色，整体凌厉超然，如剑仙降世。
```

---

### 2.2 丹修（炼丹师）

> **视觉定位**：道袍厚重沉稳，火焰环绕周身，手持丹炉，浑身散发朱砂与炉火的灼热气息，老练而神秘。

**配色方案**

| 位置 | 颜色 | HEX | 说明 |
|------|------|-----|------|
| 道袍主色 | 中墨 | `#2E2E3E` | 深色道袍，丹炉师气质 |
| 袍面装饰 | 赭石暗 | `#4A3A1A` | 土系暖色点缀纹 |
| 火焰主色 | 朱砂暗 | `#8B2500` | 炉火、丹火 |
| 火焰高光 | 朱砂明 | `#FF4400` | 丹火爆发粒子 |
| 轮廓光 | 朱砂明 | `#FF4400` | 火属性光效 |
| 丹炉 | 灰墨 | `#787890` | 青铜质感丹炉 |
| 皮肤 | 暖白 | `#D8B888` | 偏古铜肤色 |

**精灵表规格**

| 动画 | 帧数 | 网格 | 帧尺寸 | 描述 |
|------|------|------|--------|------|
| idle | 4帧 | 2×2 | 72×72px | 身体微沉，丹炉悬浮身侧，炉口有火光明灭，周身有火星飘散 |
| walk | 4帧 | 2×2 | 72×72px | 沉稳步伐，丹炉跟随身侧，火星沿途散落 |
| combat | 4帧 | 2×2 | 72×72px | 双手前推丹炉，炉口喷出火焰扇形，火光映照面部 |

**视觉元素**
- 武器：青铜小丹炉，炉身有火纹浮雕，炉口有明火
- 服装：深色交领道袍，宽袖束口，胸前有火焰纹刺绣，腰间悬挂葫芦
- 发型：灰黑色头发盘成道髻，插有火色玉簪
- 特效：idle时炉口火光明灭（0.5s周期），火星粒子上浮；combat时火焰扇形喷射

**AI 生成提示词**

```
Chinese ink wash painting style, dark moody xianxia alchemist sprite, top-down 45-degree isometric view, Taoist priest in dark robes with fire element, small bronze alchemy furnace floating beside him, dark background #0A0A0F, character centered, deep purple-gray robe #2E2E3E with fire embroidery, flames #FF4400 around furnace, sparks rising upward, 2x2 sprite grid, 4 frames, each frame 72x72 pixels, solid magenta #FF00FF background, no text, warm orange-red glow on character face from fire

ChatGPT版本:
水墨画风格，一位沉稳的老练道人，身穿深灰紫道袍，胸前绣有火焰纹样。身侧悬浮一座青铜小丹炉，炉口燃着橘红炉火，火星缓缓上浮。面色古铜，道髻高盘，插着火色玉簪，浑身散发朱砂与炉火的灼热气息。
```

---

### 2.3 符修（符箓师）

> **视觉定位**：手持符笔，符文在空中飘飞环绕，周身环绕淡紫色灵光，气质空灵飘逸，有几分不食人间烟火的仙气。

**配色方案**

| 位置 | 颜色 | HEX | 说明 |
|------|------|-----|------|
| 道袍主色 | 深墨 | `#222230` | 深紫灰道袍 |
| 袍面符文 | 紫金暗 | `#3A1A5A` | 符文暗纹 |
| 符纸/符光 | 紫金明 | `#BB44FF` | 符箓发光 |
| 轮廓光 | 紫金明 | `#BB44FF` | 雷属性光效 |
| 笔杆 | 淡墨 | `#3E3E52` | 竹制笔杆 |
| 皮肤 | 暖白 | `#E0D0C0` | 文人肤色 |

**精灵表规格**

| 动画 | 帧数 | 网格 | 帧尺寸 | 描述 |
|------|------|------|--------|------|
| idle | 4帧 | 2×2 | 72×72px | 右手持笔悬于身前，3-4张符纸在身周环绕漂浮，符文微光闪烁 |
| walk | 4帧 | 2×2 | 72×72px | 步伐轻盈，符纸跟随环绕，符笔在手中轻晃 |
| combat | 4帧 | 2×2 | 72×72px | 笔尖挥出，符纸飞射而出，紫色符文炸裂成光点 |

**视觉元素**
- 武器：符笔（竹杆毛笔，笔尖有灵光），可发射符纸
- 服装：深紫灰道袍，交领广袖，袖口和衣襟有符文暗纹
- 符纸：淡黄色宣纸，上书紫色符文，空中飘飞时微微发光
- 特效：idle时符纸环绕（螺旋轨迹，0.8s周期）；combat时符纸飞射+符文炸裂

**AI 生成提示词**

```
Chinese ink wash painting style, dark moody xianxia talisman master sprite, top-down 45-degree isometric view, cultivator holding calligraphy brush, purple glowing talisman papers floating around, dark background #0A0A0F, character centered, deep purple-gray Taoist robe #222230 with rune patterns, brush in right hand, 3-4 floating talisman papers glowing #BB44FF, 2x2 sprite grid, 4 frames, each frame 72x72 pixels, solid magenta #FF00FF background, no text, mystical purple aura, rune particles

ChatGPT版本:
水墨画风格，一位空灵飘逸的符箓师，身穿深紫灰道袍，袖口衣襟暗藏符文纹路。右手持竹杆符笔悬于身前，三四张淡黄符纸环绕身周飘飞，紫色符文微微闪烁灵光。气质出尘脱俗，如不食人间烟火的仙人。
```

---

### 2.4 体修（武僧）

> **视觉定位**：肌肉虬结，金色佛光环绕，赤足踏地，浑身散发力量感与威严感，如金刚降世，不怒自威。

**配色方案**

| 位置 | 颜色 | HEX | 说明 |
|------|------|-----|------|
| 袍服主色 | 赭石暗 | `#4A3A1A` | 土系暖色僧袍 |
| 袍面高光 | 赤金明 | `#FFAA22` | 佛光/土系光效 |
| 轮廓光 | 赤金明 | `#FFAA22` | 土属性金色 |
| 皮肤 | 古铜 | `#B89060` | 健康古铜肤色 |
| 护腕/绑腿 | 重墨 | `#1A1A22` | 深色护具 |
| 佛珠 | 净纸 | `#F5EEE2` | 白色念珠 |
| 肌肉高光 | 宣白 | `#B8B0A8` | 肌肉线条高光 |

**精灵表规格**

| 动画 | 帧数 | 网格 | 帧尺寸 | 描述 |
|------|------|------|--------|------|
| idle | 4帧 | 2×2 | 72×72px | 扎马步站立，双拳握紧，金色佛光在身周微微脉动，念珠在腰间 |
| walk | 4帧 | 2×2 | 72×72px | 沉稳有力的步伐，每步踏地震动地面，佛光随步伐闪烁 |
| combat | 4帧 | 2×2 | 72×72px | 蓄力拳击，金色拳劲迸发，地面碎裂特效 |

**视觉元素**
- 武器：无（拳掌攻击），拳头包裹金色拳劲
- 服装：无袖僧袍（露出肌肉），赤足，腰系宽布带，背负念珠
- 发型：光头或短寸，头顶有戒疤（3点）
- 特效：idle时佛光脉动（1.2s周期）；combat时拳劲金色爆裂+地面碎裂

**AI 生成提示词**

```
Chinese ink wash painting style, dark moody xianxia martial monk sprite, top-down 45-degree isometric view, muscular monk in sleeveless golden-brown robe, golden Buddhist aura #FFAA22, dark background #0A0A0F, character centered, barefoot, muscular arms exposed, prayer beads at waist, golden fist aura, 2x2 sprite grid, 4 frames, each frame 72x72 pixels, solid magenta #FF00FF background, no text, powerful stance, golden light particles, earth element glow

ChatGPT版本:
水墨画风格，一位肌肉虬结的武僧，身穿赭褐色无袖僧袍，露出健硕古铜色臂膀。赤足踏地，腰系宽布带挂着白色念珠，头顶有三点戒疤。周身环绕金色佛光，如金刚降世，不怒自威，浑身散发力量与威严。
```

---

### 2.5 魔修（魔道修士）

> **视觉定位**：暗红长袍笼罩全身，魔气缭绕如暗影缠身，面容半隐半现，邪魅而危险，有一种不可名状的压迫感。

**配色方案**

| 位置 | 颜色 | HEX | 说明 |
|------|------|-----|------|
| 长袍主色 | 浓墨 | `#121218` | 几乎纯黑的暗袍 |
| 袍面暗纹 | 朱砂暗 | `#8B2500` | 暗红魔纹 |
| 魔气/轮廓光 | 虹彩明 | `#FF44FF` | 混沌系粉紫光 |
| 血红点缀 | HP红 | `#FF3344` | 眼睛、血纹 |
| 皮肤 | 苍白 | `#C0B8A8` | 病态苍白肤色 |
| 武器光 | 虹彩明 | `#FF44FF` | 魔器发光 |

**精灵表规格**

| 动画 | 帧数 | 网格 | 帧尺寸 | 描述 |
|------|------|------|--------|------|
| idle | 4帧 | 2×2 | 72×72px | 暗袍笼罩，魔气如烟雾在身周缭绕，眼睛发出红光，有暗红粒子上浮 |
| walk | 4帧 | 2×2 | 72×72px | 暗袍随步伐飘动，魔气拖尾，阴影延伸 |
| combat | 4帧 | 2×2 | 72×72px | 暗红能量爆发，魔气凝聚成爪或刃，虹彩光炸裂 |

**视觉元素**
- 武器：暗红色魔器（镰/爪），带有虹彩光芒
- 服装：宽大暗红-黑色长袍，兜帽半遮面，露出苍白下颌
- 发型：散乱黑发从兜帽中溢出
- 特效：idle时魔气烟雾环绕（1.5s慢周期）；combat时暗红+虹彩双重爆发

**AI 生成提示词**

```
Chinese ink wash painting style, dark moody xianxia dark cultivator sprite, top-down 45-degree isometric view, sinister figure in dark red-black hooded robe, chaotic pink-purple aura #FF44FF, dark background #0A0A0F, character centered, glowing red eyes #FF3344 under hood, dark mist swirling around body, pale skin, dark red magical weapon, 2x2 sprite grid, 4 frames, each frame 72x72 pixels, solid magenta #FF00FF background, no text, ominous atmosphere, dark energy particles, chaos element

ChatGPT版本:
水墨画风格，一位阴森危险的魔道修士，暗红黑兜帽长袍笼罩全身，只露出苍白下颌。双眼发出猩红光芒，魔气如暗影烟雾缭绕周身，散乱黑发从兜帽溢出。手持暗红魔器，虹彩紫光流转其上，邪魅而压迫。
```

---

### 2.6 散修（游侠）

> **视觉定位**：破旧斗篷风尘仆仆，行囊简陋却身手不凡，有一种浪迹天涯的洒脱与沧桑，是轮回中最自由的灵魂。

**配色方案**

| 位置 | 颜色 | HEX | 说明 |
|------|------|-----|------|
| 斗篷主色 | 灰墨 | `#787890` | 破旧灰褐色 |
| 斗篷内衬 | 深墨 | `#222230` | 暗色内里 |
| 皮革/绑带 | 赭石暗 | `#4A3A1A` | 旧皮革色 |
| 轮廓光 | 中性明 | `#D8D0B8` | 无元素，通用光 |
| 刀/武器 | 宣白 | `#B8B0A8` | 旧刀寒光 |
| 补丁/装饰 | 品质灰 | `#888888` | 破旧但有故事 |
| 皮肤 | 健康色 | `#C8A878` | 风吹日晒的肤色 |

**精灵表规格**

| 动画 | 帧数 | 网格 | 帧尺寸 | 描述 |
|------|------|------|--------|------|
| idle | 4帧 | 2×2 | 72×72px | 斗篷包裹全身，兜帽下露出半张沧桑脸，斗篷边缘有破损飘动 |
| walk | 4帧 | 2×2 | 72×72px | 随意的步伐，斗篷飘动，偶尔抬手拂去风沙 |
| combat | 4帧 | 2×2 | 72×72px | 拔刀斩击，刀光朴素凌厉，没有华丽特效，纯物理力量 |

**视觉元素**
- 武器：旧弯刀，刀身有磨损痕迹，刀柄缠布
- 服装：灰褐色破旧斗篷，多处补丁，皮革绑带束紧，斜挎旧布包
- 发型：灰黑色乱发从兜帽下散出
- 特效：idle时斗篷边缘轻微飘动；combat时朴素白色刀光，无粒子特效（与五行角色形成反差）

**AI 生成提示词**

```
Chinese ink wash painting style, dark moody xianxia wandering swordsman sprite, top-down 45-degree isometric view, rugged traveler in tattered gray-brown cloak, worn curved blade, dark background #0A0A0F, character centered, hood half-covering weathered face, patched cloak #787890, leather straps, simple and unadorned, no magical effects, plain white sword slash, 2x2 sprite grid, 4 frames, each frame 72x72 pixels, solid magenta #FF00FF background, no text, dusty windblown look, nomadic feel

ChatGPT版本:
水墨画风格，一位风尘仆仆的游侠散修，灰褐色破旧斗篷多处补丁，兜帽下露出半张沧桑面孔。皮革绑带束紧斗篷，斜挎旧布包，手持一柄磨损的旧弯刀。没有华丽特效，只有朴素凌厉的刀光，是轮回中最自由洒脱的灵魂。
```

---

## 三、敌人 Sprite 设计

### 3.1 普通怪模板

#### 近战型（berserker）

> **视觉定位**：粗犷兽形或半兽人，獠牙利爪，冲向玩家近身撕咬，充满原始杀意。

**配色方案**

| 位置 | 颜色 | HEX | 说明 |
|------|------|-----|------|
| 身体主色 | 深墨 | `#222230` | 暗色兽体 |
| 肌肉/皮肤 | 赭石暗 | `#4A3A1A` | 暗褐色 |
| 眼睛/攻击光 | HP红 | `#FF3344` | 红色敌意 |
| 爪牙高光 | 宣白 | `#B8B0A8` | 獠牙寒光 |

**规格**：碰撞体 56×44px · 视觉体 64×52px · idle 4帧(2×2) · combat 4帧(2×2)

**AI 生成提示词**

```
Chinese ink wash painting style, dark beast monster sprite, top-down 45-degree isometric view, snarling wolf-like creature with red eyes #FF3344, dark fur #222230, sharp claws and fangs, aggressive charging pose, dark background #0A0A0F, 2x2 sprite grid, 4 frames, each frame 64x52 pixels, solid magenta #FF00FF background, no text, feral energy, red particle eyes

ChatGPT版本:
水墨画风格，一头粗犷凶猛的兽形怪物，暗色皮毛，红色双眼发着凶光。獠牙利爪，呈凶猛冲锋姿态，充满原始杀意和野性能量。
```

#### 远程型（ranged/sniper）

> **视觉定位**：瘦高人形，手持弓弩或法器，保持距离发射弹幕，冷静而精准。

**配色方案**

| 位置 | 颜色 | HEX | 说明 |
|------|------|-----|------|
| 身体主色 | 中墨 | `#2E2E3E` | 灰紫人形 |
| 弹幕/法器光 | 水·明 | `#00CCFF` | 蓝色弹幕 |
| 长袍 | 深墨 | `#222230` | 暗色长袍 |
| 眼睛 | 紫金明 | `#BB44FF` | 法术紫光 |

**规格**：碰撞体 44×56px · 视觉体 52×64px · idle 4帧(2×2) · combat 4帧(2×2)

**AI 生成提示词**

```
Chinese ink wash painting style, tall thin ranged enemy sprite, top-down 45-degree isometric view, skeletal mage figure in dark robes #2E2E3E, holding crossbow or orb, glowing purple eyes #BB44FF, blue projectile energy #00CCFF, dark background #0A0A0F, 2x2 sprite grid, 4 frames, each frame 52x64 pixels, solid magenta #FF00FF background, no text, eerie calm, ranged attack stance

ChatGPT版本:
水墨画风格，一个瘦高人形的远程敌人，灰紫暗袍裹身，手持弓弩或法器。紫色法眼冷冷发光，身周有蓝色弹幕能量凝聚。冷静而精准，保持距离，散发着诡异的沉静气息。
```

#### 飞行型

> **视觉定位**：翅膀展开的妖蝠或飞虫，悬浮于地面之上，有翅膀扇动动画。

**配色方案**

| 位置 | 颜色 | 浓墨 | HEX |
|------|------|------|-----|
| 翅膀 | 深墨 | `#222230` | 半透明翼膜 |
| 身体 | 赭石暗 | `#4A3A1A` | 暗褐色躯干 |
| 眼睛 | HP红 | `#FF3344` | 红眼 |
| 翼边光 | 木·明 | `#44FF44` | 绿色毒翼 |

**规格**：碰撞体 48×48px · 视觉体 56×56px（含翼展）· idle 4帧(2×2) · combat 4帧(2×2)

**AI 生成提示词**

```
Chinese ink wash painting style, flying bat-like monster sprite, top-down 45-degree isometric view, dark winged creature hovering, translucent dark wings #222230, red glowing eyes #FF3344, green wing edge glow #44FF44, dark background #0A0A0F, 2x2 sprite grid, 4 frames, each frame 56x56 pixels, solid magenta #FF00FF background, no text, hovering wings flapping, toxic wing membrane

ChatGPT版本:
水墨画风格，一只悬浮的妖蝠飞虫，暗色半透明翼膜，红色双眼凶光闪烁。翼边泛着幽绿毒光，翅膀扇动悬浮于地面之上，身体呈暗褐色，散发着危险与诡异的气息。
```

---

### 3.2 精英怪设计

精英怪在普通怪基础上放大 1.25 倍，增加专属视觉标记。

#### 物理精英（疾行/厚甲/狂怒）

> **视觉定位**：体型更大的兽形精英，周身环绕红色气焰，头顶有精英光环，行动更快力量更强。

**配色方案**

| 位置 | 颜色 | HEX | 说明 |
|------|------|-----|------|
| 身体 | 深墨 | `#1A1A22` | 比普通更深 |
| 精英光环 | 品质·灵 | `#44CCAA` | 灵品级光环 |
| 气焰 | HP红 | `#FF3344` | 红色战意 |
| 甲壳/护甲 | 灰墨 | `#787890` | 金属质感护甲 |

**规格**：碰撞体 70×55px · 视觉体 80×65px · idle 4帧(2×2) · combat 4帧(2×2)

**特殊标记**：
- 头顶有灵品色（`#44CCAA`）光环标记
- 周身有红色气焰粒子（比普通怪多 50%）
- 体型比普通怪大 25%
- 受击时有更强烈的闪烁反馈

**AI 生成提示词**

```
Chinese ink wash painting style, elite beast monster sprite, top-down 45-degree isometric view, large armored wolf-beast with green aura ring #44CCAA above head, dark fur #1A1A22, red battle energy #FF3344, metal armor plates #787890, dark background #0A0A0F, 2x2 sprite grid, 4 frames, each frame 80x65 pixels, solid magenta #FF00FF background, no text, elite monster glow, larger and more menacing than normal

ChatGPT版本:
水墨画风格，一头体型更大的兽形精英怪，周身环绕青绿色灵品光环。暗色毛皮比普通怪更深，身上覆盖金属质感护甲，红色战意气焰比普通怪更浓烈，行动更快力量更强，是强化版的凶猛野兽。
```

#### 法术精英（符师/召唤者）

> **视觉定位**：瘦高人形法术精英，周身环绕紫色法阵，符文在身周旋转，有召唤能力。

**配色方案**

| 位置 | 颜色 | HEX | 说明 |
|------|------|-----|------|
| 长袍 | 浓墨 | `#121218` | 最深暗袍 |
| 法阵/符文 | 紫金明 | `#BB44FF` | 紫色法阵 |
| 轮廓光 | 虹彩明 | `#FF44FF` | 混沌紫光 |
| 法器 | 灰墨 | `#787890` | 法杖/法器 |

**规格**：碰撞体 52×72px · 视觉体 60×80px · idle 4帧(2×2) · combat 4帧(2×2)

**特殊标记**：
- 脚下有紫色法阵光环
- 周身有紫色符文旋转粒子
- 受击时有法阵碎裂特效

**AI 生成提示词**

```
Chinese ink wash painting style, elite mage enemy sprite, top-down 45-degree isometric view, tall dark-robed sorcerer #121218 with purple magic circle #BB44FF beneath feet, floating runes around body, dark background #0A0A0F, 2x2 sprite grid, 4 frames, each frame 60x80 pixels, solid magenta #FF00FF background, no text, elite mage glow, purple arcane aura, summoning stance

ChatGPT版本:
水墨画风格，一位瘦高人形的法术精英，最深暗袍裹身。脚下有紫色法阵光环，周身环绕紫色符文缓缓旋转。手持法杖，呈召唤姿态，散发着紫色奥术气息，是拥有召唤能力的危险法师。
```

---

### 3.3 Boss 设计

Boss 体型 2.5-3.0 倍角色（碰撞体 160×160px），每个阶段有独立视觉变化。

#### Boss 1：赤焰守关傀儡（Stage 1 · 初入仙途）

> **视觉定位**：巨大的火纹傀儡，由熔岩和黑石构成，胸口有火红核心，双臂为岩石重锤。

**阶段视觉变化**

| 阶段 | HP区间 | 视觉变化 |
|------|--------|---------|
| 初境 | 100%-60% | 傀儡完整，胸口核心稳定发光，火焰温和 |
| 劫火四起 | 60%-30% | 身体出现裂纹，核心膨胀发亮，火焰从裂纹中喷出 |
| 天罚降世 | <30% | 半身崩碎，核心暴露，全身被火焰包裹，疯狂攻击 |

**配色**：身体`#2E2E3E`深灰 · 核心`#FF4400`朱砂明 · 裂纹`#8B2500`朱砂暗 · 碎片飞散

**AI 生成提示词**

```
Chinese ink wash painting style, giant fire golem boss sprite, top-down 45-degree isometric view, massive stone construct with molten core glowing #FF4400, dark gray body #2E2E3E, red cracks #8B2500, lava flowing from joints, 3x3 sprite grid, 9 frames, each frame 160x160 pixels, solid magenta #FF00FF background, no text, intimidating boss, fire element, dark background #0A0A0F

ChatGPT版本:
水墨画风格，一尊巨大的火纹傀儡Boss，由熔岩与黑石构成。深灰石质身躯布满暗红裂纹，胸口火红核心熊熊燃烧，熔岩从关节处流淌而出。双臂如岩石重锤，整体威压感十足，是火焰与钢铁的化身。
```

#### Boss 2：幽泉秘境镇守（Stage 2 · 秘境深处）

> **视觉定位**：水系Boss，巨大的蛟龙形态，盘踞于暗色水潭之上，周身水流环绕。

**阶段视觉变化**

| 阶段 | HP区间 | 视觉变化 |
|------|--------|---------|
| 初境 | 100%-60% | 蛟龙盘踞水面，水流温和环绕，蓝光柔和 |
| 劫火四起 | 60%-30% | 水面翻涌，蛟龙升起半身，水流化为冰刺 |
| 天罚降世 | <30% | 全身被冰水包裹，水幕化为利刃，暴风雪粒子 |

**配色**：身体`#1A3A4A`玄青暗 · 鳞片`#00CCFF`玄青明 · 水纹`#1EA7FF` · 冰刺`#F5EEE2`净纸白

**AI 生成提示词**

```
Chinese ink wash painting style, giant water dragon boss sprite, top-down 45-degree isometric view, massive serpentine water dragon coiling over dark pool, teal scales #00CCFF on dark body #1A3A4A, water currents swirling around, ice crystals forming, dark background #0A0A0F, 3x3 sprite grid, 9 frames, each frame 160x160 pixels, solid magenta #FF00FF background, no text, aquatic boss, water element, majestic and cold

ChatGPT版本:
水墨画风格，一条巨大的水系蛟龙Boss，盘踞于暗色水潭之上。深青暗色身躯覆满碧蓝鳞片，水流环绕周身缓缓旋转，冰晶在水幕中凝结。蛟龙身躯蜿蜒蜿蜒，威严冷峻，是水之深渊的镇守者。
```

#### Boss 3：天雷劫影（Stage 3 · 渡劫前夕）

> **视觉定位**：雷系Boss，半透明的雷电巨影，由紫金闪电构成人形轮廓，无固定形态。

**阶段视觉变化**

| 阶段 | HP区间 | 视觉变化 |
|------|--------|---------|
| 初境 | 100%-60% | 雷影轮廓清晰，紫色闪电稳定脉动 |
| 劫火四起 | 60%-30% | 轮廓不稳定，闪电四射，地面出现雷击圈 |
| 天罚降世 | <30% | 形态狂暴化，全身白光，雷暴覆盖全场 |

**配色**：雷体`#3A1A5A`紫金暗 · 闪电`#BB44FF`紫金明 · 白光`#F5EEE2` · 雷击`#FF44FF`虹彩

**AI 生成提示词**

```
Chinese ink wash painting style, thunder shadow boss sprite, top-down 45-degree isometric view, semi-transparent humanoid figure made of lightning, dark purple body #3A1A5A, bright purple lightning #BB44FF crackling across form, unstable energy, dark background #0A0A0F, 3x3 sprite grid, 9 frames, each frame 160x160 pixels, solid magenta #FF00FF background, no text, thunder element boss, electric aura, ethereal and dangerous

ChatGPT版本:
水墨画风格，一道半透明的雷电巨影Boss，由紫金闪电构成人形轮廓。暗紫身躯上闪电噼啪炸裂，形态不断闪烁变化，能量极不稳定。飘渺而危险，如同天劫降世的怒影，是雷霆的化身。
```

#### Boss 4：焚心魔将（Stage 4 · 焚心秘域）

> **视觉定位**：火系魔物Boss，半人半魔形态，暗红铠甲，手持巨刃，周身火焰与魔气交织。

**阶段视觉变化**

| 阶段 | HP区间 | 视觉变化 |
|------|--------|---------|
| 初境 | 100%-60% | 铠甲完整，火焰稳定，持巨刃站立 |
| 劫火四起 | 60%-30% | 铠甲裂开露出魔体，火焰变为黑红 |
| 天罚降世 | <30% | 完全魔化，铠甲崩碎，身体膨胀，黑红火焰吞没一切 |

**配色**：铠甲`#121218`浓墨 · 魔火`#FF4400`朱砂明 · 黑火`#8B2500`朱砂暗 · 魔体`#FF3344`HP红

**AI 生成提示词**

```
Chinese ink wash painting style, fire demon general boss sprite, top-down 45-degree isometric view, half-demon warrior in dark armor #121218, massive flaming blade, fire #FF4400 and dark mist #8B2500 swirling, demonic red energy #FF3344, dark background #0A0A0F, 3x3 sprite grid, 9 frames, each frame 160x160 pixels, solid magenta #FF00FF background, no text, fire and chaos element, demon warrior, imposing presence

ChatGPT版本:
水墨画风格，一位半人半魔的火系魔将Boss。暗黑铠甲裹身，手持燃烧的巨刃，火焰与暗红魔气交织翻涌。猩红魔力在体表流转，铠甲下隐约露出魔物本体，威严霸气，是火焰与混沌的融合体。
```

#### Boss 5：九天雷劫化身（Stage 5 · 天劫试场）

> **视觉定位**：终极Boss，天劫的化身，由雷电和风暴构成的巨大人形，全身散发毁灭性的紫金光芒。

**阶段视觉变化**

| 阶段 | HP区间 | 视觉变化 |
|------|--------|---------|
| 初境 | 100%-60% | 巨大雷电人形，紫金光芒稳定，天地变色 |
| 劫火四起 | 60%-30% | 形态不稳定，雷暴四起，地面龟裂 |
| 天罚降世 | <30> | 全身白金光芒，天劫雷暴覆盖全屏，终极毁灭形态 |

**配色**：雷体`#3A1A5A`紫金暗 · 天雷`#BB44FF`紫金明 · 金光`#FFD700`道品 · 白光`#F5EEE2`净纸

**AI 生成提示词**

```
Chinese ink wash painting style, ultimate thunder tribulation boss sprite, top-down 45-degree isometric view, colossal humanoid figure formed from divine lightning, dark purple base #3A1A5A, blazing golden-white lightning #FFD700 and #BB44FF, sky-splitting energy, dark background #0A0A0F, 4x4 sprite grid, 16 frames, each frame 160x160 pixels, solid magenta #FF00FF background, no text, final boss, tribulation embodiment, apocalyptic scale, golden and purple lightning storm

ChatGPT版本:
水墨画风格，终极天劫化身Boss，一尊由雷电和风暴构成的巨大人形。暗紫底色上金白雷光与紫金闪电交织炸裂，天裂地崩的能量倾泻而下。紫金光芒照耀天际，是天劫的终极形态，拥有毁灭一切的恐怖威压。
```

---

## 四、灵宠设计

### 4.1 火萤（火系 · 小精灵形态）

> **视觉定位**：拳头大小的火焰精灵，通体发光，如一团有生命的火焰在空中飘浮。

**基本参数**

| 参数 | 值 |
|------|-----|
| 视觉体 | 16×12px（含光晕 24×20px）|
| 碰撞体 | 12×12px |
| 动画帧数 | idle 4帧(2×2) · walk 4帧(2×2) |
| 帧尺寸 | 24×24px |

**配色**

| 位置 | 颜色 | HEX |
|------|------|-----|
| 火焰主体 | 朱砂明 | `#FF4400` |
| 火焰内核 | 赤金明 | `#FFAA22` |
| 火焰外缘 | 朱砂暗 | `#8B2500` |
| 眼睛 | 净纸 | `#F5EEE2` |

**动画描述**
- idle：火焰跳动，大小缩放 0.95↔1.05，1.0s周期，火星上浮
- walk：火焰向移动方向倾斜，拖尾火星

**AI 生成提示词**

```
Chinese ink wash painting style, tiny fire spirit sprite, top-down 45-degree isometric view, small flame fairy with wings of fire, bright orange #FF4400 body with yellow core #FFAA22, dark background #0A0A0F, 2x2 sprite grid, 4 frames, each frame 24x24 pixels, solid magenta #FF00FF background, no text, cute fire elemental, glowing sparks

ChatGPT版本:
水墨画风格，拳头大小的火焰精灵，通体发光如一团有生命的火焰在空中飘浮。橘红火焰为主体，金黄内核明亮，火焰边缘跳跃着火星。可爱的小火灵，灵动而温暖。
```

---

### 4.2 玄龟（水系 · 龟形态）

> **视觉定位**：小巧的灵龟，龟壳上有水纹，周身有水流环绕，行动缓慢但防御力极强。

**基本参数**

| 参数 | 值 |
|------|-----|
| 视觉体 | 20×16px（含水纹 28×22px）|
| 碰撞体 | 18×14px |
| 动画帧数 | idle 4帧(2×2) · walk 4帧(2×2) |
| 帧尺寸 | 28×28px |

**配色**

| 位置 | 颜色 | HEX |
|------|------|-----|
| 龟壳 | 深墨 | `#222230` |
| 水纹 | 水·明 | `#00CCFF` |
| 龟体 | 水·暗 | `#1A3A4A` |
| 眼睛 | 水·明 | `#00CCFF` |

**动画描述**
- idle：龟壳微缩，水流在壳面流动，水面波纹荡漾
- walk：缓慢爬行，水纹在身后拖曳

**AI 生成提示词**

```
Chinese ink wash painting style, small water turtle spirit sprite, top-down 45-degree isometric view, cute divine turtle with water patterns on shell, dark shell #222230, glowing blue water纹 #00CCFF, dark background #0A0A0F, 2x2 sprite grid, 4 frames, each frame 28x28 pixels, solid magenta #FF00FF background, no text, water elemental pet, flowing water around shell

ChatGPT版本:
水墨画风格，一只小巧的灵龟，深色龟壳上有流动的水纹图案，泛着幽蓝光芒。水流在壳面缓缓流淌，行动缓慢却透着沉稳坚毅。可爱的小水灵宠物，灵性十足。
```

---

### 4.3 雷鸢（雷系 · 飞鸟形态）

> **视觉定位**：闪电形态的飞鸟，羽毛如雷电般闪烁，翅膀展开时有雷弧跳跃。

**基本参数**

| 参数 | 值 |
|------|-----|
| 视觉体 | 22×14px（含电弧 30×20px）|
| 碰撞体 | 20×12px |
| 动画帧数 | idle 4帧(2×2) · walk 4帧(2×2) |
| 帧尺寸 | 32×32px |

**配色**

| 位置 | 颜色 | HEX |
|------|------|-----|
| 羽毛 | 雷·暗 | `#3A1A5A` |
| 闪电 | 雷·明 | `#BB44FF` |
| 眼睛 | 虹彩明 | `#FF44FF` |
| 翼尖 | 净纸 | `#F5EEE2` |

**动画描述**
- idle：翅膀微扇，雷弧在翼尖跳跃，羽毛闪烁
- walk（飞）：翅膀展开滑翔，身后拖曳电弧

**AI 生成提示词**

```
Chinese ink wash painting style, lightning bird spirit sprite, top-down 45-degree isometric view, small electric bird with lightning feathers, dark purple body #3A1A5A, bright lightning #BB44FF on wings, dark background #0A0A0F, 2x2 sprite grid, 4 frames, each frame 32x32 pixels, solid magenta #FF00FF background, no text, thunder elemental pet, electric arcs on wingtips

ChatGPT版本:
水墨画风格，一只闪电形态的飞鸟灵宠，暗紫身躯上羽毛如雷电般闪烁。翅膀展开时紫金电弧在翼尖跳跃，虹彩紫眼灵动有神。羽毛闪烁间电光流转，是雷电凝聚而成的小精灵。
```

---

### 4.4 木灵（木系 · 树精形态）

> **视觉定位**：微型树精，身体由树干和绿叶构成，头顶有嫩芽，周身有藤蔓环绕。

**基本参数**

| 参数 | 值 |
|------|-----|
| 视觉体 | 18×20px（含藤蔓 26×26px）|
| 碰撞体 | 16×18px |
| 动画帧数 | idle 4帧(2×2) · walk 4帧(2×2) |
| 帧尺寸 | 28×28px |

**配色**

| 位置 | 颜色 | HEX |
|------|------|-----|
| 树干 | 赭石暗 | `#4A3A1A` |
| 叶子 | 木·明 | `#44FF44` |
| 嫩芽 | 木·暗 | `#1A3A1A` |
| 藤蔓 | 木·明 | `#44FF44` |

**动画描述**
- idle：叶子轻微摇摆，嫩芽呼吸闪烁，藤蔓缓缓绕身旋转
- walk：根部伸出小脚移动，叶子随步伐摇晃

**AI 生成提示词**

```
Chinese ink wash painting style, tiny tree spirit sprite, top-down 45-degree isometric view, cute wood elemental made of bark and leaves, brown trunk body #4A3A1A, bright green leaves #44FF44, tiny sprout on head, vines wrapping body, dark background #0A0A0F, 2x2 sprite grid, 4 frames, each frame 28x28 pixels, solid magenta #FF00FF background, no text, wood elemental pet, nature spirit

ChatGPT版本:
水墨画风格，一株微型树精灵宠，身体由树干和绿叶构成。褐色树干身躯，头顶嫩芽微微呼吸闪烁，翠绿藤蔓缓缓绕身旋转。叶子随风轻摇，是森林与自然凝聚的可爱小精灵。
```

---

### 4.5 金睛兽（土系 · 兽形态）

> **视觉定位**：小巧的土系灵兽，全身覆盖金色岩石甲壳，眼睛发出金色光芒，行动沉稳有力。

**基本参数**

| 参数 | 值 |
|------|-----|
| 视觉体 | 22×16px（含金光 30×22px）|
| 碰撞体 | 20×14px |
| 动画帧数 | idle 4帧(2×2) · walk 4帧(2×2) |
| 帧尺寸 | 32×32px |

**配色**

| 位置 | 颜色 | HEX |
|------|------|-----|
| 甲壳 | 赭石暗 | `#4A3A1A` |
| 金光 | 赤金明 | `#FFAA22` |
| 眼睛 | 赤金明 | `#FFAA22` |
| 身体 | 中墨 | `#2E2E3E` |

**动画描述**
- idle：甲壳微缩，金色光芒脉动，脚下有沙尘粒子
- walk：沉稳四足行走，每步踏出金色冲击波纹

**AI 生成提示词**

```
Chinese ink wash painting style, small earth beast sprite, top-down 45-degree isometric view, compact quadruped with golden rock armor #4A3A1A, glowing golden eyes #FFAA22, dark body #2E2E3E, dust particles beneath feet, dark background #0A0A0F, 2x2 sprite grid, 4 frames, each frame 32x32 pixels, solid magenta #FF00FF background, no text, earth elemental pet, armored creature

ChatGPT版本:
水墨画风格，一只小巧的土系灵兽，四足行走，全身覆盖金色岩石甲壳。金色双眼发出温暖光芒，脚下有沙尘粒子浮动。甲壳微缩间金色光芒脉动，每步踏出沉稳有力，是大地之力凝聚的灵兽。
```

---

### 4.6 混沌虫（混沌系 · 虫形态）

> **视觉定位**：不可名状的虫形生物，身体不断变形，虹彩光芒在体表流转，令人不安却又充满力量。

**基本参数**

| 参数 | 值 |
|------|-----|
| 视觉体 | 16×12px（含虹彩 24×18px）|
| 碰撞体 | 14×10px |
| 动画帧数 | idle 4帧(2×2) · walk 4帧(2×2) |
| 帧尺寸 | 24×24px |

**配色**

| 位置 | 颜色 | HEX |
|------|------|-----|
| 身体 | 混沌·暗 | `#1A1A2A` |
| 虹彩纹 | 混沌·明 | `#FF44FF` |
| 虹彩变色 | 多色渐变 | 红→紫→蓝→绿 |
| 眼睛 | 虹彩明 | `#FF44FF` |

**动画描述**
- idle：身体不断微微变形，虹彩在体表流动，颜色缓慢变化
- walk：蠕动前进，身后留下虹彩残影

**AI 生成提示词**

```
Chinese ink wash painting style, chaotic worm sprite, top-down 45-degree isometric view, amorphous insect creature with shifting form, dark body #1A1A2A with iridescent rainbow patterns #FF44FF, color-shifting surface, unsettling and powerful, dark background #0A0A0F, 2x2 sprite grid, 4 frames, each frame 24x24 pixels, solid magenta #FF00FF background, no text, chaos elemental pet, morphing creature, psychedelic glow

ChatGPT版本:
水墨画风格，一只不可名状的混沌虫灵宠，身体不断微微变形。暗色躯体上虹彩纹路流转，颜色在红紫蓝绿间缓慢变化，令人不安却又充满力量。蠕动前行时身后留下彩虹残影，如混沌之力的化身。
```

---

## 五、战斗场景地图设计

### 5.1 Stage 1：初入仙途 · 灵气山林

> **视觉定位**：仙气初现的幽静山林，灵气充沛，林间有淡淡的蓝绿色光点漂浮，地面覆盖苔藓与落叶。

**地图参数**

| 参数 | 值 |
|------|-----|
| 战斗房尺寸 | 1920×1920px |
| Boss房尺寸 | 2560×2560px |
| 地面纹理 | 深绿色苔藓石板，缝隙有灵气微光 |
| 装饰物 | 灵气石堆、断木、苔藓岩石、灵草、符文石碑 |
| 光照氛围 | 幽暗林间光，蓝绿色灵气粒子弥漫，无直射光 |
| 天气 | clear（晴朗）|

**装饰物清单**
- 灵气石堆（小/中）× 8-12
- 断木 × 4-6
- 苔藓岩石 × 6-8
- 灵草（发光植物）× 10-15
- 符文石碑 × 1-2
- 灵气泉眼 × 1

**AI 生成提示词**

```
Chinese ink wash painting style, mystical forest battle arena, top-down 45-degree isometric view, dark green mossy stone floor, ancient broken trees, glowing spirit grass with blue-green light #00CCFF and #44FF44 particles floating, rune stones scattered, misty dark atmosphere #0A0A0F background, 1920x1920 pixels, tileable ground texture, forest props scattered around edges, ethereal spirit qi particles, dark xianxia cultivation forest

ChatGPT版本:
水墨画风格，俯视45度角的灵气山林战场地面。深绿苔藓石板清晰铺满整个地面，石板边缘锐利、纹理可辨，缝隙中有微弱蓝绿色灵光。断木和苔藓岩石只散落在画面边缘区域，中心区域保持开阔干净。少量灵草和符文石碑点缀边缘。雾气极淡，不遮挡地面纹理。画面干净清晰，地面可读性高。
```

---

### 5.2 Stage 2：秘境深处 · 幽暗水洞

> **视觉定位**：深邃的地下溶洞，水面反射微光，钟乳石倒挂，有水滴声回荡，充满未知与危险。

**地图参数**

| 参数 | 值 |
|------|-----|
| 战斗房尺寸 | 1920×1920px |
| Boss房尺寸 | 2560×2560px |
| 地面纹理 | 湿润暗色岩石，局部有积水反射 |
| 装饰物 | 钟乳石柱、地下暗河、发光蘑菇、古代石刻、水帘 |
| 光照氛围 | 极暗，水面反射蓝光，发光蘑菇提供微弱光源 |
| 天气 | rain（雨）|

**装饰物清单**
- 钟乳石柱（悬挂）× 10-15
- 地面石笋 × 6-8
- 积水/暗河区域 × 3-4
- 发光蘑菇 × 8-12
- 古代石刻壁画 × 2-3
- 水帘（背景装饰）× 2

**AI 生成提示词**

```
Chinese ink wash painting style, underground water cave battle arena, top-down 45-degree isometric view, dark wet stone floor with puddles reflecting blue light #00CCFF, stalactites hanging from ceiling, glowing mushrooms providing dim light, underground stream, ancient stone carvings on walls, water drips, misty dark cave #0A0A0F background, 1920x1920 pixels, water reflections, cave formations, xianxia secret realm

ChatGPT版本:
水墨画风格，俯视45度角的地下水洞战场地面。湿润暗色岩石地面纹理清晰，石纹和积水边缘锐利可辨，积水反射柔和蓝光。钟乳石和发光蘑菇只在画面边缘，中心区域地面开阔干净。水滴粒子少量漂浮但不遮挡地面。画面干净清晰，地面可读性高。
```

---

### 5.3 Stage 3：渡劫前夕 · 雷云荒原

> **视觉定位**：被雷电肆虐的荒芜大地，地面龟裂，偶尔有雷击落下，天空乌云密布，充满压迫感。

**地图参数**

| 参数 | 值 |
|------|-----|
| 战斗房尺寸 | 1920×1920px |
| Boss房尺寸 | 2560×2560px |
| 地面纹理 | 龟裂焦黑大地，裂缝中有紫色雷光 |
| 装饰物 | 雷击焦木、碎裂岩石、雷纹石板、闪电残影、电磁粒子 |
| 光照氛围 | 紫色雷光间歇照射，地面有雷纹光脉 |
| 天气 | thunder（雷）|

**装饰物清单**
- 雷击焦木 × 6-8
- 碎裂岩石 × 8-10
- 雷纹石板 × 4-6
- 电磁粒子效果 × 持续
- 龟裂地面纹理 × 全场

**AI 生成提示词**

```
Chinese ink wash painting style, thunder-scarred wasteland battle arena, top-down 45-degree isometric view, cracked blackened earth with purple lightning #BB44FF glowing in fissures, burnt trees struck by lightning, shattered rocks, thunder rune stone slabs, electric particles crackling, dark stormy sky #0A0A0F background, 1920x1920 pixels, apocalyptic landscape, xianxia tribulation ground, ominous purple atmosphere

ChatGPT版本:
水墨画风格，俯视45度角的雷域战场地面。焦黑龟裂大地纹理清晰，裂缝轮廓锐利，缝隙中透出克制的紫色雷光。雷击焦木和碎裂岩石只在画面边缘，中心区域地面开阔干净。电磁粒子和电弧只作为边缘点缀，不遮挡地面。画面干净清晰，地面可读性高。
```

---

### 5.4 Stage 4：焚心秘域 · 地狱熔炉

> **视觉定位**：岩浆流淌的炼狱之地，地面有熔岩裂缝，热浪扭曲空气，暗红色光芒笼罩一切。

**地图参数**

| 参数 | 值 |
|------|-----|
| 战斗房尺寸 | 1920×1920px |
| Boss房尺寸 | 2560×2560px |
| 地面纹理 | 焦黑岩石，熔岩裂缝中流出橙红色岩浆 |
| 装饰物 | 熔岩池、燃烧的残骸、火焰石柱、灰烬粒子、焦黑骨骼 |
| 光照氛围 | 暗红光照，熔岩发光，热浪扭曲效果 |
| 天气 | fire（火）|

**装饰物清单**
- 熔岩池 × 3-5
- 燃烧残骸 × 6-8
- 火焰石柱 × 4-6
- 灰烬粒子 × 持续上浮
- 焦黑骨骼/残骸 × 4-6

**AI 生成提示词**

```
Chinese ink wash painting style, infernal lava forge battle arena, top-down 45-degree isometric view, cracked obsidian floor with orange-red lava #FF4400 flowing in fissures, burning wreckage, fire stone pillars, ash particles floating upward, dark red ambient glow, dark background #0A0A0F, 1920x1920 pixels, hellish landscape, xianxia demon realm, intense heat atmosphere, ember particles

ChatGPT版本:
水墨画风格，俯视45度角的熔岩战场地面。焦黑黑曜石地面纹理清晰，裂缝轮廓锐利，裂缝中流淌橙红色岩浆，岩浆边缘有柔和热光。燃烧残骸和火焰石柱只在画面边缘，中心区域地面开阔干净。灰烬粒子少量上浮但不遮挡地面。画面干净清晰，地面可读性高。
```

---

### 5.5 Stage 5：天劫试场 · 混沌天穹

> **视觉定位**：悬浮于天际的终极战场，脚下是无尽深渊，四周是混沌云海，五行元素交织碰撞，是天劫降临之地。

**地图参数**

| 参数 | 值 |
|------|-----|
| 战斗房尺寸 | 2560×2560px（最终战场加大）|
| Boss房尺寸 | 2880×2880px |
| 地面纹理 | 悬浮的古老石板，边缘碎裂，五行符文镶嵌 |
| 装饰物 | 混沌云海、五行元素柱、破碎天穹碎片、轮回纹阵、星辰粒子 |
| 光照氛围 | 五彩元素光交替闪烁，混沌紫光笼罩，星辰粒子漫天 |
| 天气 | wind（风）|

**装饰物清单**
- 混沌云海（背景层）× 全场
- 五行元素柱 × 5（金木水火土各一）
- 破碎天穹碎片 × 悬浮 8-12
- 轮回纹阵（地面）× 2-3
- 星辰粒子 × 持续

**AI 生成提示词**

```
Chinese ink wash painting style, chaotic celestial battlefield arena, top-down 45-degree isometric view, floating ancient stone platform with cracked edges, five-element rune pillars (fire #FF4400, water #00CCFF, thunder #BB44FF, wood #44FF44, earth #FFAA22), chaos clouds below, broken sky fragments floating, samsara rune circles on ground, star particles in sky, dark void #0A0A0F background, 2560x2560 pixels, cosmic xianxia final battleground, apocalyptic scale, five-element chaos

ChatGPT版本:
水墨画风格，俯视45度角的天界终极战场地面。悬浮的古老石板平台纹理清晰，边缘碎裂但轮廓锐利，地面轮回纹阵线条清楚。五行元素柱只在平台边缘，中心区域地面开阔干净。混沌云海在平台下方，破碎碎片和星辰粒子少量悬浮但不遮挡地面。画面干净清晰，地面可读性高。
```

---

## 六、资产优先级与实施路径

### 6.1 优先级矩阵

| 优先级 | 资产 | 理由 |
|--------|------|------|
| P0 | 剑修idle/walk/combat | 主角，玩家最常看到 |
| P0 | 近战普通怪idle/combat | 最常见敌人 |
| P0 | Stage 1 地图 | 第一关，首次体验 |
| P1 | 丹修/符修/体修/魔修/散修 | 其余角色 |
| P1 | 远程普通怪 + 精英怪 | 战斗多样性 |
| P1 | 火萤灵宠 | 唯一已实现的灵宠 |
| P2 | Stage 2-5 地图 | 后续关卡 |
| P2 | 飞行怪 | 特殊敌人类型 |
| P2 | Boss 1-5 | 关底Boss |
| P3 | 玄龟/雷鸢/木灵/金睛兽/混沌虫 | 其余灵宠 |

### 6.2 已有资产对标

项目已有以下占位资产，新设计需与其保持兼容或明确替换关系：

| 已有资产 | 新设计对标 | 动作 |
|----------|-----------|------|
| `player_cultivator_64.png` | 剑修 | 替换 |
| `player_style_normal_64/128.png` | 通用角色基底 | 保留为 fallback |
| `enemy_berserker_64.png` | 近战普通怪 | 替换 |
| `enemy_archer_64.png` | 远程普通怪 | 替换 |
| `enemy_bomber_64.png` | 飞行怪 | 替换 |
| `enemy_style_normal_elite_64/128.png` | 精英怪 | 替换 |
| `pet_huo_ying_32.png` | 火萤灵宠 | 升级 |
| 5阶段 tileset | 5阶段地图 | 替换 |

---

## 七、Godot 实现注意事项

### 7.1 Sprite 导入设置

```gdscript
# 角色 Sprite 推荐导入设置
# Import > Texture > Filter: Nearest (保持像素清晰)
# Import > Texture > Process > 启用 Mipmaps: Off

# AnimationPlayer 设置
# FPS: 8（idle/walk）· 12（combat）
# Animation mode: Linear
```

### 7.2 粒子层叠

| 层 | 内容 | 混合模式 |
|----|------|---------|
| 0 | 背景地图 | 正常 |
| 1 | 地面装饰/障碍物 | 正常 |
| 2 | 角色/敌人 | 正常 |
| 3 | 角色光效/轮廓光 | Additive |
| 4 | 弹幕/投射物 | Additive |
| 5 | 受击/爆炸特效 | Additive |
| 6 | 环境粒子（灰尘/雨/雷） | Additive |
| 7 | HUD | 正常 |

### 7.3 角色轮廓光 Shader 参考

```gdscript
shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.0, 0.8, 1.0, 0.6);
uniform float outline_width : hint_range(0.0, 4.0) = 1.5;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.3;

void fragment() {
    vec4 col = texture(TEXTURE, UV);
    if (col.a < 0.1) {
        // 采样周围像素检测边缘
        float max_alpha = 0.0;
        for (int x = -1; x <= 1; x++) {
            for (int y = -1; y <= 1; y++) {
                float neighbor = texture(TEXTURE, UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE * outline_width).a;
                max_alpha = max(max_alpha, neighbor);
            }
        }
        if (max_alpha > 0.1) {
            float noise = fract(sin(dot(UV * 100.0, vec2(12.9898, 78.233))) * 43758.5453);
            float alpha = max_alpha * outline_color.a * (1.0 - noise * noise_strength);
            COLOR = vec4(outline_color.rgb, alpha);
        }
    } else {
        COLOR = col;
    }
}
```

---

*文档结束 — 《轮回仙途》角色与场景美术设计 v1.0*
