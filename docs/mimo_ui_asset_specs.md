# 《轮回仙途》美术资产规格文档

> 版本：1.0  
> 引擎：Godot 4.6 · 2D 顶视角  
> 基准分辨率：1920×1080  
> 视觉基调：水墨暗色 × 高饱和粒子光效  
> 依赖文档：`mimo_ui_design_system.md` · `mimo_ui_character_scene.md`

---

## 一、场景资产规格

### 1.1 主菜单背景

```
场景名: main_menu_bg
尺寸: 1920×1080px
图层1（背景）: 深墨渐变底色，从 ink.000 #0A0A0F 到 ink.300 #222230，自下而上
图层2（中景）: 水墨山水远景剪影，深灰色调，云雾缭绕于山间
图层3（前景）: 左侧竹林剪影 + 右侧松树剪影，底部墨迹飞白边缘
图层4（特效）: 金色光粒缓慢上浮（境界突破意象），左上角月亮光晕

Midjourney提示词:
Chinese ink wash painting style, dark moody xianxia main menu background, 1920x1080, layered mountain silhouettes in deep ink tones, bamboo forest left side, pine tree right side, moonlight glow upper left, golden particles floating upward, misty clouds between mountains, dark background #0A0A0F to #222230 gradient, atmospheric depth, no characters, cinematic composition, --ar 16:9 --v 6.1 --style raw

SD提示词:
(chinese ink wash painting:1.4), dark xianxia landscape background, layered mountain silhouettes, bamboo forest, pine tree, moonlight, golden floating particles, misty atmosphere, dark color palette #0A0A0F, cinematic composition, masterpiece, best quality, ultra-detailed, 8k

SD负面提示词:
low quality, blurry, text, watermark, logo, bright colors, modern elements, western style, 3d render, photorealistic, oversaturated, white background

ChatGPT版本:
生成一张 1920×1080 的中国水墨修仙游戏主菜单背景，简洁极简的插画风格，画面清晰干净。深墨色渐变底，远处是层叠山峦剪影，云雾柔和地穿行在山间；左侧保留竹林剪影，右侧保留松树剪影，左上角有克制的月光光晕，少量金色光粒从下方向上漂浮。使用柔和细腻的阴影、温和的散射光、自然无缝的渐变效果，边缘锐利精致但避免过度锐化。精准控制细微细节，主体层次清楚，超高清晰度。不要人物、文字、UI、Logo；无噪点、无颗粒、无伪影、无脏污纹理、无斑驳污迹、无杂乱琐碎细节。
```

### 1.2 道心Setup背景

```
场景名: daoheart_setup_bg
尺寸: 1920×1080px
图层1（背景）: 纯墨 ink.000 #0A0A0F，中央有微弱水墨旋涡纹理
图层2（中景）: 五道元素光柱从底部向上延伸（火/水/雷/木/土），半透明
图层3（前景）: 中央圆形道心法阵，暗金色线条，缓慢旋转
图层4（特效）: 法阵周围五行粒子环绕，中央光点脉动

Midjourney提示词:
Chinese ink wash painting style, dark xianxia Dao heart selection screen background, 1920x1080, five elemental pillars rising from bottom (fire orange #FF4400, water cyan #00CCFF, thunder purple #BB44FF, wood green #44FF44, earth gold #FFAA22), circular magic formation in center with golden lines, dark ink background #0A0A0F, mystical particles floating, no characters, atmospheric depth, --ar 16:9 --v 6.1 --style raw

SD提示词:
(chinese ink wash painting:1.4), dark xianxia selection screen, five elemental pillars, circular magic formation, golden lines, dark background #0A0A0F, mystical floating particles, atmospheric, masterpiece, best quality, 8k

SD负面提示词:
low quality, blurry, text, watermark, bright background, modern UI, 3d render, photorealistic

ChatGPT版本:
生成一张 1920×1080 的中国水墨修仙道心选择界面背景，简洁极简的插画风格，画面清晰干净。深墨色背景中央有很淡的水墨旋涡纹理，底部向上延伸五道半透明元素光柱：火橙、水青、雷紫、木绿、土金。中央绘制暗金色圆形道心法阵，线条锐利精致、结构清楚，周围有少量五行粒子环绕和中央光点脉动感。使用柔和细腻的阴影、温和的散射光、自然无缝渐变，整体神秘庄重，有修仙仪式感。不要人物、文字、UI、Logo；无噪点、无颗粒、无伪影、无脏污纹理，避免过度锐化，无斑驳污迹，无杂乱琐碎细节。
```

### 1.3 Stage 1 战斗地图：炼气·竹林

```
场景名: stage1_bamboo_forest
尺寸: 1920×1920px（战斗房）/ 2560×2560px（Boss房）
图层1（背景）: 深绿苔藓石板地面，缝隙有灵气微光，可平铺
图层2（中景）: 竹林剪影（左/右两侧），灵气石堆、断木、苔藓岩石散布
图层3（前景）: 灵草发光植物（蓝绿光点），符文石碑（1-2个）
图层4（特效）: 蓝绿色灵气粒子弥漫，水面反光（若有水潭）

Midjourney提示词:
Chinese ink wash painting style, mystical bamboo forest battle arena, top-down 45-degree isometric view, dark green mossy stone floor tileable texture, ancient broken trees, glowing spirit grass with blue-green light #00CCFF, bamboo silhouettes on sides, rune stones scattered, misty dark atmosphere #0A0A0F background, 1920x1920 pixels, ethereal spirit qi particles, xianxia cultivation forest, tileable, seamless --ar 1:1 --v 6.1 --style raw

SD提示词:
(chinese ink wash painting:1.4), mystical bamboo forest floor, top-down isometric view, dark green mossy stone tiles, glowing blue-green spirit grass, bamboo silhouettes, rune stones, misty atmosphere, tileable texture, masterpiece, best quality, 8k

SD负面提示词:
low quality, blurry, text, watermark, bright colors, modern elements, 3d render, perspective distortion

ChatGPT版本:
生成一张 1920×1920 的中国水墨修仙竹林战场地图，俯视 45 度角，可无缝平铺，简洁极简的插画风格，画面清晰干净。地面为深绿色苔藓石板，石板边缘清楚，缝隙中有微弱蓝绿色灵光；两侧有低调竹林剪影，地面散布少量断木、苔藓岩石、发光灵草和 1-2 个符文石碑。中心战斗区域保持开阔、低噪、可读，不要堆满装饰。使用柔和细腻阴影、温和散射光、自然无缝渐变和锐利精致硬边，细微细节精准但克制，超高清晰度。不要人物、怪物、文字、UI、Logo；无噪点、无颗粒、无伪影、无脏污纹理，避免过度锐化，无斑驳污迹，无杂乱琐碎细节。
```

### 1.4 Stage 2 战斗地图：筑基·仙山

```
场景名: stage2_spirit_mountain
尺寸: 1920×1920px（战斗房）/ 2560×2560px（Boss房）
图层1（背景）: 湿润暗色岩石地面，局部积水反射蓝光，可平铺
图层2（中景）: 钟乳石柱悬挂、地面石笋、地下暗河区域
图层3（前景）: 发光蘑菇（蓝紫光）、古代石刻壁画
图层4（特效）: 水滴粒子、水面波纹、微弱蓝光反射

Midjourney提示词:
Chinese ink wash painting style, underground water cave battle arena, top-down 45-degree isometric view, dark wet stone floor with puddles reflecting blue light #00CCFF, stalactites hanging, glowing mushrooms, underground stream, ancient stone carvings, misty dark cave #0A0A0F background, 1920x1920 pixels, water reflections, tileable, xianxia secret realm --ar 1:1 --v 6.1 --style raw

SD提示词:
(chinese ink wash painting:1.4), underground water cave floor, top-down isometric view, dark wet stone tiles, glowing blue mushrooms, stalactites, water puddles reflections, ancient carvings, tileable texture, masterpiece, best quality, 8k

SD负面提示词:
low quality, blurry, text, watermark, bright colors, modern elements, 3d render, dry surface

ChatGPT版本:
生成一张 1920×1920 的中国水墨修仙地下水洞战场地图，俯视 45 度角，可无缝平铺，简洁极简的插画风格，画面清晰干净。深色潮湿岩石地面带有清楚的石纹和少量积水，积水反射柔和蓝光；边缘区域点缀钟乳石、地面石笋、发光蓝紫蘑菇和古代石刻痕迹，可有一条地下暗河从边缘经过。中心战斗区域保持开阔、低噪、可读，水滴粒子少量漂浮。使用柔和细腻阴影、温和散射光、自然无缝渐变、锐利精致硬边，超高清晰度。不要人物、怪物、文字、UI、Logo；无噪点、无颗粒、无伪影、无脏污纹理，避免过度锐化，无斑驳污迹，无杂乱琐碎细节。
```

### 1.5 Stage 3 战斗地图：金丹·雷域

```
场景名: stage3_thunder_wasteland
尺寸: 1920×1920px（战斗房）/ 2560×2560px（Boss房）
图层1（背景）: 龟裂焦黑大地，裂缝中有紫色雷光，可平铺
图层2（中景）: 雷击焦木、碎裂岩石、雷纹石板
图层3（前景）: 电磁粒子持续闪烁，地面雷纹光脉
图层4（特效）: 间歇性雷击闪光、紫色电弧跳跃

Midjourney提示词:
Chinese ink wash painting style, thunder-scarred wasteland battle arena, top-down 45-degree isometric view, cracked blackened earth with purple lightning #BB44FF glowing in fissures, burnt trees struck by lightning, shattered rocks, thunder rune stone slabs, electric particles, dark stormy sky #0A0A0F background, 1920x1920 pixels, apocalyptic landscape, xianxia tribulation ground, tileable --ar 1:1 --v 6.1 --style raw

SD提示词:
(chinese ink wash painting:1.4), thunder wasteland floor, cracked blackened earth, purple lightning in fissures, burnt trees, shattered rocks, electric particles, tileable texture, masterpiece, best quality, 8k

SD负面提示词:
low quality, blurry, text, watermark, bright background, green forest, water, 3d render

ChatGPT版本:
生成一张 1920×1920 的中国水墨修仙雷域战场地图，俯视 45 度角，可无缝平铺，简洁极简的插画风格，画面清晰干净。龟裂焦黑大地作为主地面，裂缝中透出克制的紫色雷光；边缘散布少量雷击焦木、碎裂岩石和雷纹石板，电磁粒子与紫色电弧只作为点缀。中心战斗区域保持开阔、低噪、可读，末日渡劫氛围强但不杂乱。使用柔和细腻阴影、温和散射光、自然无缝渐变、锐利精致硬边和清楚的裂纹轮廓，超高清晰度。不要人物、怪物、文字、UI、Logo；无噪点、无颗粒、无伪影、无脏污纹理，避免过度锐化，无斑驳污迹，无杂乱琐碎细节。
```

### 1.6 Stage 4 战斗地图：元婴·星空

```
场景名: stage4_inferno_forge
尺寸: 1920×1920px（战斗房）/ 2560×2560px（Boss房）
图层1（背景）: 焦黑岩石地面，熔岩裂缝中流出橙红色岩浆，可平铺
图层2（中景）: 熔岩池、燃烧残骸、火焰石柱
图层3（前景）: 焦黑骨骼/残骸散落
图层4（特效）: 灰烬粒子持续上浮、热浪扭曲效果、岩浆脉动光

Midjourney提示词:
Chinese ink wash painting style, infernal lava forge battle arena, top-down 45-degree isometric view, cracked obsidian floor with orange-red lava #FF4400 flowing in fissures, burning wreckage, fire stone pillars, ash particles floating upward, dark red ambient glow, dark background #0A0A0F, 1920x1920 pixels, hellish landscape, xianxia demon realm, tileable --ar 1:1 --v 6.1 --style raw

SD提示词:
(chinese ink wash painting:1.4), lava forge floor, cracked obsidian tiles, orange lava in fissures, burning wreckage, fire pillars, ash particles, tileable texture, masterpiece, best quality, 8k

SD负面提示词:
low quality, blurry, text, watermark, cool colors, blue, green, water, ice, 3d render

ChatGPT版本:
生成一张 1920×1920 的中国水墨修仙熔岩魔域战场地图，俯视 45 度角，可无缝平铺，简洁极简的插画风格，画面清晰干净。焦黑黑曜石地面为主，裂缝中流淌橙红色岩浆，岩浆边缘有柔和热光；边缘区域点缀少量燃烧残骸、火焰石柱和灰烬粒子。中心战斗区域保持开阔、低噪、可读，炽热压迫但不拥挤。使用柔和细腻阴影、温和散射光、自然无缝渐变、锐利精致硬边，岩石和裂缝轮廓清楚，超高清晰度。不要人物、怪物、文字、UI、Logo；无噪点、无颗粒、无伪影、无脏污纹理，避免过度锐化，无斑驳污迹，无杂乱琐碎细节。
```

### 1.7 Stage 5 战斗地图：渡劫·天劫

```
场景名: stage5_celestial_chaos
尺寸: 2560×2560px（战斗房）/ 2880×2880px（Boss房）
图层1（背景）: 混沌云海（深紫+暗蓝），无尽深渊感
图层2（中景）: 悬浮古老石板（边缘碎裂）、五行元素柱各一
图层3（前景）: 轮回纹阵（地面）、破碎天穹碎片悬浮
图层4（特效）: 星辰粒子漫天、五行元素光交替闪烁、混沌紫光笼罩

Midjourney提示词:
Chinese ink wash painting style, chaotic celestial battlefield arena, top-down 45-degree isometric view, floating ancient stone platform with cracked edges, five-element rune pillars (fire #FF4400, water #00CCFF, thunder #BB44FF, wood #44FF44, earth #FFAA22), chaos clouds below, broken sky fragments floating, samsara rune circles on ground, star particles in sky, dark void #0A0A0F background, 2560x2560 pixels, cosmic xianxia final battleground, tileable --ar 1:1 --v 6.1 --style raw

SD提示词:
(chinese ink wash painting:1.4), celestial chaos battlefield floor, floating stone platform, five-element pillars, chaos clouds, samsara rune circles, star particles, cosmic atmosphere, tileable texture, masterpiece, best quality, 8k

SD负面提示词:
low quality, blurry, text, watermark, simple ground, flat terrain, modern elements, 3d render

ChatGPT版本:
生成一张 2560×2560 的中国水墨修仙混沌天界战场地图，俯视 45 度角，可无缝平铺，简洁极简的插画风格，画面清晰干净。主体是悬浮古老石板平台，边缘碎裂但轮廓清楚；平台周围可见深紫与暗蓝混沌云海，边缘布置五根代表五行的半透明元素光柱。地面有清晰但克制的轮回纹阵，天空碎片和星辰粒子少量点缀，中心战斗区域保持开阔、低噪、可读。使用柔和细腻阴影、温和散射光、自然无缝渐变、锐利精致硬边，营造宏大终局感，超高清晰度。不要人物、怪物、文字、UI、Logo；无噪点、无颗粒、无伪影、无脏污纹理，避免过度锐化，无斑驳污迹，无杂乱琐碎细节。
```

### 1.8 坊市背景

```
场景名: market_bg
尺寸: 1920×1080px
图层1（背景）: 深墨渐变底色，两侧有建筑剪影
图层2（中景）: 古代坊市建筑轮廓（店铺、招牌、灯笼），水墨风格
图层3（前景）: 地面石板路纹理，摊位轮廓
图层4（特效）: 灯笼暖光（微弱橙色光晕），烟雾粒子（炊烟）

Midjourney提示词:
Chinese ink wash painting style, ancient xianxia market street background, 1920x1080, dark ink silhouettes of traditional Chinese shop buildings, hanging lanterns with warm glow, stone paved road, steam rising from food stalls, misty dark atmosphere #0A0A0F, no characters, cinematic composition, atmospheric depth --ar 16:9 --v 6.1 --style raw

SD提示词:
(chinese ink wash painting:1.4), ancient xianxia market street, dark ink silhouettes, traditional Chinese buildings, hanging lanterns, stone road, steam particles, dark background, masterpiece, best quality, 8k

SD负面提示词:
low quality, blurry, text, watermark, modern buildings, bright colors, people, 3d render, photorealistic

ChatGPT版本:
生成一张 1920×1080 的中国水墨修仙古代坊市街道背景，简洁极简的插画风格，画面清晰干净。深墨色渐变底，两侧是传统店铺建筑剪影和少量招牌轮廓，灯笼发出克制暖光；前景有清楚的石板路纹理和少量摊位轮廓，炊烟柔和上升。整体温暖、有市井气，但保持低噪和留白，适合作为 UI 背景。使用柔和细腻阴影、温和散射光、自然无缝渐变、锐利精致硬边，超高清晰度。不要人物、文字、现代物件、UI、Logo；无噪点、无颗粒、无伪影、无脏污纹理，避免过度锐化，无斑驳污迹，无杂乱琐碎细节。
```

### 1.9 事件背景

```
场景名: event_bg
尺寸: 1920×1080px
图层1（背景）: 纯墨 ink.000 #0A0A0F
图层2（中景）: 水墨山水远景（极淡，15%透明度），营造氛围
图层3（前景）: 无（留白给事件UI内容）
图层4（特效）: 微弱金色粒子上浮（若有重要事件），或无特效

Midjourney提示词:
Chinese ink wash painting style, dark atmospheric event screen background, 1920x1080, deep ink gradient #0A0A0F to #121218, faint mountain silhouette at 15% opacity, minimal composition, subtle golden particles floating, vast empty space, xianxia meditation atmosphere, no characters, no text --ar 16:9 --v 6.1 --style raw

SD提示词:
(chinese ink wash painting:1.4), dark atmospheric background, faint mountain silhouette, deep ink gradient, minimal, subtle golden particles, meditation atmosphere, masterpiece, best quality

SD负面提示词:
low quality, blurry, text, watermark, bright colors, busy composition, modern elements

ChatGPT版本:
生成一张 1920×1080 的中国水墨修仙叙事事件背景，简洁极简的插画风格，画面清晰干净。深墨色渐变底，远处只有 15% 透明度左右的极淡山峦剪影，整体大面积留白；少量微弱金色粒子缓慢上浮，氛围宁静、深邃、适合承载事件 UI 内容。使用柔和细腻阴影、温和散射光、自然无缝渐变和克制细节，超高清晰度。不要人物、文字、UI、Logo；无噪点、无颗粒、无伪影、无脏污纹理，避免过度锐化，无斑驳污迹，无杂乱琐碎细节。
```

### 1.10 结算背景

```
场景名: result_bg
尺寸: 1920×1080px
图层1（背景）: 深墨渐变底色，中央有水墨漩涡纹理
图层2（中景）: 成功：金色光芒从中央放射 / 失败：暗红裂纹从中央扩散
图层3（前景）: 成功：金色粒子爆发 / 失败：灰烬粒子飘落
图层4（特效）: 成功：境界突破金光（道品金 #FFD700） / 失败：暗红 HP 红 #FF3344 粒子消散

Midjourney提示词:
Chinese ink wash painting style, dark xianxia result screen background, 1920x1080, success version: golden light rays radiating from center #FFD700, golden particles exploding outward, ink vortex texture, dark background #0A0A0F; failure version: dark red cracks spreading from center #FF3344, ash particles falling, dark background. Split into two versions, cinematic composition --ar 16:9 --v 6.1 --style raw

SD提示词:
(chinese ink wash painting:1.4), xianxia result screen, success: golden light rays, golden particles, ink vortex; failure: dark red cracks, ash particles. Dark background, cinematic, masterpiece, best quality, 8k

SD负面提示词:
low quality, blurry, text, watermark, bright background, modern elements, 3d render

ChatGPT版本:
生成两张 1920×1080 的中国水墨修仙游戏结算背景，简洁极简的插画风格，画面清晰干净。成功版：深墨色背景，中央有水墨漩涡纹理和克制的金色光芒向四周放射，少量金色粒子向外扩散，仪式感强但不刺眼。失败版：深墨色背景，中央有暗红裂纹向四周扩散，少量灰烬粒子缓慢飘落，氛围沉静压抑。两版都使用柔和细腻阴影、温和散射光、自然无缝渐变、锐利精致硬边和清楚主体层次，超高清晰度。不要人物、文字、UI、Logo；无噪点、无颗粒、无伪影、无脏污纹理，避免过度锐化，无斑驳污迹，无杂乱琐碎细节。
```

---

## 二、UI组件资产规格

### 2.1 按钮尺寸表

所有按钮使用水墨笔触边框（非圆角矩形），通过 Shader 模拟飞白边缘。

| 按钮类型 | 尺寸 (W×H) | 字号 | 内边距 | 边框 | 状态 |
|----------|-----------|------|--------|------|------|
| 按钮·大 | 320×64px | 20px Bold | 16px | 笔触 2-3px | normal/hover/pressed/disabled |
| 按钮·中 | 240×52px | 18px Bold | 12px | 笔触 2px | normal/hover/pressed/disabled |
| 按钮·小 | 160×40px | 16px Bold | 8px | 笔触 2px | normal/hover/pressed/disabled |
| 按钮·图标 | 48×48px | — | 0px | 笔触 2px | normal/hover/pressed/disabled |
| 按钮·标签 | 120×36px | 14px Regular | 8px | 笔触 1px | normal/hover/pressed/disabled |

**按钮状态规范**

| 状态 | 背景色 | 文字色 | 边框色 | 特效 |
|------|--------|--------|--------|------|
| normal | ink.200 #1A1A22 | ink.800 #B8B0A8 | ink.500 #3E3E52 | 无 |
| hover | ink.300 #222230 | ink.900 #E8DFD2 | 元素基础色 | 微弱外发光 4px |
| pressed | ink.400 #2E2E3E | ink.950 #F5EEE2 | 元素高亮色 | 墨点飞溅粒子 |
| disabled | ink.100 #121218 | ink.600 #5A5A72 | ink.400 #2E2E3E | 50% 透明度 |

### 2.2 面板NinePatch规格

面板使用 `StyleBoxTexture` + NinePatch 实现，边缘为水墨笔触纹理。

| 面板类型 | 最小尺寸 | 九宫格边距 (L/T/R/B) | 背景 | 边框 |
|----------|---------|---------------------|------|------|
| 面板·标准 | 400×300px | 24/24/24/24 | bg.solid | border.brush |
| 面板·宽屏 | 800×500px | 32/32/32/32 | bg.solid | border.brush |
| 面板·弹窗 | 600×400px | 24/24/24/24 | bg.solid | border.glow |
| 面板·卷轴 | 500×600px | 16/48/16/48 | bg.paper | border.brush |
| 面板·书籍 | 900×650px | 32/32/32/32 | bg.paper | border.brush |
| 面板·HUD条 | 400×24px | 0/0/0/0 | bg.solid | 无 |

**NinePatch纹理规格**

| 纹理 | 尺寸 | 说明 |
|------|------|------|
| 面板背景纹理 | 128×128px | 墨色底 + 微弱宣纸纹理叠加 |
| 笔触边框纹理 | 128×128px | 左右粗中间细的笔触线条，9宫格拉伸 |
| 印章边框纹理 | 64×64px | 方形篆刻边缘，暗红色调 |
| 发光边框纹理 | 128×128px | 元素色发光边框，用于品质/选中态 |

### 2.3 卡牌规格

| 卡牌部分 | 尺寸 | 说明 |
|----------|------|------|
| 卡牌正面 | 160×224px | 含边框 |
| 卡牌背面 | 160×224px | 统一设计 |
| 卡牌边框 | 4px | 品质色边框（凡/灵/仙/天/道） |
| 卡牌插图区 | 152×140px | 减去边框 |
| 卡牌名称区 | 152×32px | 底部名称文字 |
| 卡牌图标 | 24×24px | 元素图标（左上角） |
| 卡牌费用 | 20×20px | 圆形费用指示（右上角） |

**卡牌品质边框规范**

| 品质 | 边框颜色 | 边框宽度 | 发光效果 |
|------|---------|---------|---------|
| 凡品 | ink.500 #3E3E52 | 2px | 无 |
| 灵品 | #44CCAA | 2px | glow.subtle 4px |
| 仙品 | #4488FF | 3px | glow.medium 8px |
| 天品 | #AA44FF | 3px | glow.strong 16px |
| 道品 | #FFD700 | 4px | glow.epic 32px |

**卡牌动画规格**

| 动画 | 时长 | 缓动 | 说明 |
|------|------|------|------|
| 翻转 | 300ms | ease.inkInOut | Y轴180°翻转 |
| 悬浮 | 持续 | ease.float | Y轴±4px微浮 |
| 被选中 | 150ms | ease.bounce | 放大1.1x + 上移16px |
| 打出 | 200ms | ease.brushStroke | 从手牌飞向目标 |
| 消亡 | 400ms | ease.inkOut | 淡出 + 粒子消散 |

### 2.4 图标尺寸表

| 图标类型 | 尺寸 | 用途 | 说明 |
|----------|------|------|------|
| 状态指示小圆点 | 16×16px | 在线/离线、状态标记 | 圆形，单色 |
| 列表内联图标 | 24×24px | 属性列表项前缀 | 水墨线条风格 |
| 技能栏图标 | 32×32px | Q/W/E/R技能图标 | 水墨线条 + 元素色高亮 |
| 装备图标 | 32×32px | 武器/防具/饰品 | 水墨线条风格 |
| 面板标题装饰 | 48×48px | 面板标题旁装饰 | 水墨笔触 |
| Boss标记 | 48×48px | Boss头顶标记 | 红色敌意标记 |
| 境界突破图标 | 64×64px | 境界名称旁 | 元素色发光 |
| 成就图标 | 64×64px | 成就展示 | 印章风格 |
| 物品图标·小 | 24×24px | 背包物品 | 水墨线条 |
| 物品图标·中 | 32×32px | 商店展示 | 水墨线条 |
| 物品图标·大 | 48×48px | 物品详情 | 水墨线条 + 品质边框 |
| 元素图标 | 32×32px | 五行元素标识 | 水墨线条 + 对应色 |
| 旗帜图标 | 48×48px | 势力/门派标识 | 印章风格 |

### 2.5 进度条规格

| 进度条类型 | 尺寸 (W×H) | 背景色 | 填充色 | 特效 |
|-----------|-----------|--------|--------|------|
| HP条 | 400×24px | ink.300 #222230 | #FF3344 | 低血量闪烁 |
| MP条 | 400×24px | ink.300 #222230 | #3366FF | 无 |
| SP条 | 400×24px | ink.300 #222230 | #AA44FF | 心魔相关脉动 |
| 境界经验条 | 320×16px | ink.300 #222230 | #FFD700 | 突破时金光爆发 |
| Boss HP条 | 600×32px | ink.200 #1A1A22 | #FF3344 | 阶段切换变色 |
| 加载进度条 | 240×8px | ink.300 #222230 | ink.800 #B8B0A8 | 墨水流动动画 |
| 法力消耗条 | 80×8px | ink.400 #2E2E3E | #3366FF | 技能消耗预览 |

**进度条通用规格**

| 参数 | 值 |
|------|-----|
| 圆角 | 0px（锐角） |
| 边框 | 1px ink.500 #3E3E52 |
| 填充动画 | 200ms ease.inkOut |
| 闪光效果 | 300ms 白色高光从左到右扫描 |
| 遮罩边缘 | 水墨飞白 Shader 处理 |

### 2.6 装饰元素尺寸

| 装饰元素 | 尺寸 | 用途 | 说明 |
|----------|------|------|------|
| 分隔线·横 | 100%宽 × 2px | 区域分隔 | ink.500 #3E3E52，笔触粗细变化 |
| 分隔线·竖 | 2px × 100%高 | 区域分隔 | ink.500 #3E3E52 |
| 角落装饰 | 32×32px | 面板角落 | 水墨笔触角花 |
| 标题装饰线 | 200×4px | 标题下方 | 元素色渐变线 |
| 背景光晕 | 256×256px | 重要元素后方 | 柔和发光，元素色 20% 透明度 |
| 印章图标 | 48×48px | 确认/认证标记 | 暗红篆刻风格 |
| 卷轴端头 | 24×48px | 卷轴界面装饰 | 木质卷轴端头 |
| 星星装饰 | 16×16px | 评分/评级 | 金色，可点亮/熄灭 |

---

## 三、粒子纹理资产规格

### 3.1 墨点粒子变体

基础墨点粒子，用于 UI 点击反馈、过渡效果、墨迹扩散。

| 变体 | 尺寸 | 形状 | 颜色 | 用途 |
|------|------|------|------|------|
| 墨点·小 | 4×4px | 近圆形，边缘不规则 | ink.600 #5A5A72 → 透明 | 微点击反馈 |
| 墨点·中 | 8×8px | 椭圆，边缘飞白 | ink.500 #3E3E52 → 透明 | 按钮点击反馈 |
| 墨点·大 | 12×12px | 不规则圆形，有飞白 | ink.400 #2E2E3E → 透明 | 面板展开特效 |
| 墨点·泼洒 | 16×16px | 泼墨形状，边缘飞溅 | ink.300 #222230 → 透明 | 重要操作反馈 |

**AI生成提示词**

```
变体1（墨点·小）:
Chinese ink wash style, single small ink dot particle, irregular circular shape, dark gray #5A5A72, slightly splattered edges, transparent background, game asset, no text, 4x4 pixels, pixel art precision

变体2（墨点·中）:
Chinese ink wash style, medium ink drop particle, oval shape with white feather edges, dark gray #3E3E52, brush stroke texture, transparent background, game asset, no text, 8x8 pixels

变体3（墨点·大）:
Chinese ink wash style, large ink splatter particle, irregular circle with flying white edges, dark gray #2E2E3E, brush splatter texture, transparent background, game asset, no text, 12x12 pixels

变体4（墨点·泼洒）:
Chinese ink wash style, ink splash particle, scattered splatter shape, dark gray #222230, dramatic brush splatter, transparent background, game asset, no text, 16x16 pixels
```

### 3.2 元素粒子

五行元素粒子，用于技能释放、元素爆发、环境特效。

| 元素 | 变体 | 尺寸 | 形状 | 颜色 | 用途 |
|------|------|------|------|------|------|
| 🔥 火 | 火星 | 4×4px | 不规则点状 | #FF4400 朱砂明 | 炎爆粒子 |
| 🔥 火 | 火焰 | 6×8px | 火焰形状 | #FF4400 → #8B2500 | 火焰附着 |
| 🔥 火 | 灰烬 | 3×3px | 飘散碎片 | #FFAA22 → 透明 | 灰烬上浮 |
| 💧 水 | 水滴 | 4×6px | 水滴形状 | #00CCFF 玄青明 | 水系技能 |
| 💧 水 | 波纹 | 8×2px | 扁平弧形 | #00CCFF 50% | 水面涟漪 |
| 💧 水 | 冰晶 | 6×6px | 六角形 | #F5EEE2 净纸白 | 冰冻效果 |
| ⚡ 雷 | 电弧 | 2×8px | 锯齿线条 | #BB44FF 紫金明 | 雷击效果 |
| ⚡ 雷 | 电球 | 6×6px | 球形 | #BB44FF → #FF44FF | 雷球蓄力 |
| ⚡ 雷 | 电花 | 4×4px | 星形 | #F5EEE2 净纸白 | 电花闪烁 |
| 🌿 木 | 叶片 | 4×6px | 叶形 | #44FF44 木·明 | 木系技能 |
| 🌿 木 | 藤蔓 | 2×12px | 弯曲线条 | #1A3A1A 木·暗 | 藤蔓生长 |
| 🌿 木 | 花粉 | 2×2px | 圆点 | #FFEE44 领悟色 | 花粉飘散 |
| 🪨 土 | 碎石 | 4×4px | 不规则块 | #FFAA22 赤金明 | 土系技能 |
| 🪨 土 | 沙尘 | 3×3px | 弥散点 | #4A3A1A 赭石暗 | 沙尘弥漫 |
| 🪨 土 | 金光 | 2×2px | 星形 | #FFD700 道品 | 金光闪烁 |

**AI生成提示词**

```
火·火星:
Chinese ink wash style, tiny fire spark particle, irregular dot shape, bright orange #FF4400, glowing, transparent background, game particle asset, no text, 4x4 pixels

火·火焰:
Chinese ink wash style, small flame particle, teardrop flame shape, orange #FF4400 fading to dark red #8B2500, transparent background, game particle asset, no text, 6x8 pixels

火·灰烬:
Chinese ink wash style, tiny ash particle, scattered fragment, golden #FFAA22 fading to transparent, floating upward, transparent background, game particle asset, no text, 3x3 pixels

水·水滴:
Chinese ink wash style, water drop particle, teardrop shape, cyan blue #00CCFF, glossy, transparent background, game particle asset, no text, 4x6 pixels

雷·电弧:
Chinese ink wash style, lightning arc particle, zigzag line shape, bright purple #BB44FF, electric, transparent background, game particle asset, no text, 2x8 pixels

木·叶片:
Chinese ink wash style, leaf particle, leaf shape, bright green #44FF44, organic, transparent background, game particle asset, no text, 4x6 pixels

土·碎石:
Chinese ink wash style, rock fragment particle, irregular chunk, golden #FFAA22, solid, transparent background, game particle asset, no text, 4x4 pixels
```

### 3.3 品质粒子

品质对应粒子，用于物品掉落、装备展示、突破特效。

| 品质 | 变体 | 尺寸 | 形状 | 颜色 | 用途 |
|------|------|------|------|------|------|
| 凡品 | 灰尘 | 2×2px | 圆点 | #888888 | 凡品掉落微光 |
| 凡品 | 碎片 | 3×3px | 不规则 | #888888 → 透明 | 凡品破碎 |
| 灵品 | 灵光 | 4×4px | 星形 | #44CCAA | 灵品内发光 |
| 灵品 | 呼吸 | 6×6px | 柔和球 | #44CCAA 40% | 灵品呼吸闪烁 |
| 仙品 | 流光 | 4×6px | 拖尾线条 | #4488FF | 仙品边缘流光 |
| 仙品 | 环绕 | 3×3px | 圆点 | #4488FF → 透明 | 仙品环绕粒子 |
| 天品 | 光环 | 8×8px | 发光球 | #AA44FF 60% | 天品强光环 |
| 天品 | 织绕 | 4×4px | 星形 | #AA44FF | 天品粒子环绕 |
| 道品 | 帝金光 | 6×6px | 星形 | #FFD700 | 道品帝王金光 |
| 道品 | 光晕 | 12×12px | 柔和球 | #FFD700 30% | 道品全屏光晕 |

**AI生成提示词**

```
凡品·灰尘:
Minimalist style, tiny dust particle, simple dot, gray #888888, subtle, transparent background, game particle asset, no text, 2x2 pixels

灵品·灵光:
Chinese ink wash style, spirit light particle, soft star shape, teal #44CCAA, gentle glow, transparent background, game particle asset, no text, 4x4 pixels

仙品·流光:
Chinese ink wash style, immortal flow light particle, trailing line shape, blue #4488FF, flowing, transparent background, game particle asset, no text, 4x6 pixels

天品·光环:
Chinese ink wash style, celestial halo particle, glowing orb shape, purple #AA44FF, intense aura, transparent background, game particle asset, no text, 8x8 pixels

道品·帝金光:
Chinese ink wash style, dao lord golden light particle, radiant star shape, gold #FFD700, imperial radiance, transparent background, game particle asset, no text, 6x6 pixels
```

### 3.4 背景粒子

环境氛围粒子，用于场景背景装饰。

| 粒子类型 | 尺寸 | 形状 | 颜色 | 运动 | 用途 |
|----------|------|------|------|------|------|
| 灵气光点 | 2×2px | 圆点 | #00CCFF / #44FF44 | 缓慢上浮 | 山林/仙境场景 |
| 灰尘浮游 | 2×2px | 圆点 | #787890 30% | 随机漂浮 | 所有场景 |
| 雨滴 | 1×4px | 线条 | #00CCFF 40% | 斜向下 | 水洞/雷域场景 |
| 雪花 | 3×3px | 星形 | #F5EEE2 50% | 缓慢飘落 | 特殊场景 |
| 雷电火花 | 2×2px | 圆点 | #BB44FF | 随机闪烁 | 雷域场景 |
| 灰烬上浮 | 2×2px | 不规则 | #FFAA22 40% | 缓慢上浮 | 火域场景 |
| 星辰 | 1×1px | 圆点 | #F5EEE2 | 静止/微闪 | 天劫/星空场景 |
| 混沌虹彩 | 3×3px | 不规则 | #FF44FF 彩虹色 | 随机漂浮 | 混沌场景 |

**AI生成提示词**

```
灵气光点:
Chinese ink wash style, tiny spirit qi light particle, soft glowing dot, cyan #00CCFF, ethereal, transparent background, game ambient particle, no text, 2x2 pixels

灰尘浮游:
Chinese ink wash style, dust mote particle, subtle gray dot #787890, low opacity, floating, transparent background, game ambient particle, no text, 2x2 pixels

雷电火花:
Chinese ink wash style, electric spark particle, tiny purple dot #BB44FF, flickering, transparent background, game ambient particle, no text, 2x2 pixels

星辰:
Chinese ink wash style, star particle, tiny white dot #F5EEE2, twinkling, transparent background, game ambient particle, no text, 1x1 pixels
```

---

## 四、音效资产清单

### 4.1 UI音效

| 音效ID | 名称 | 描述 | 时长 | 触发场景 |
|--------|------|------|------|----------|
| `ui_click` | 按钮点击 | 墨笔轻触纸面，短促清脆 | 0.1-0.2s | 按钮点击 |
| `ui_hover` | 按钮悬浮 | 微弱气流声，轻柔 | 0.1s | 鼠标悬浮 |
| `ui_open_panel` | 面板展开 | 墨水浸润宣纸，缓慢展开 | 0.3-0.5s | 面板打开 |
| `ui_close_panel` | 面板收起 | 墨水快速收拢 | 0.2-0.3s | 面板关闭 |
| `ui_card_flip` | 卡牌翻转 | 纸张翻动 + 墨迹声 | 0.2-0.3s | 卡牌翻转 |
| `ui_card_select` | 卡牌选中 | 轻微弹跳声 + 墨点声 | 0.15s | 卡牌选中 |
| `ui_card_play` | 卡牌打出 | 墨笔挥洒 + 纸张声 | 0.3s | 卡牌使用 |
| `ui_equip` | 装备穿戴 | 金属轻响 + 灵气嗡鸣 | 0.3s | 装备更换 |
| `ui_unequip` | 装备卸下 | 金属分离声 | 0.2s | 装备卸下 |
| `ui_level_up` | 等级提升 | 墨水升腾 + 灵气聚集 | 0.8s | 境界提升 |
| `ui_breakthrough` | 突破成功 | 金光爆发 + 雷鸣远响 | 1.5s | 境界突破 |
| `ui_breakthrough_fail` | 突破失败 | 玻璃碎裂 + 墨水泼洒 | 1.0s | 突破失败 |
| `ui_item_get` | 获得物品 | 清脆铃声 + 墨点 | 0.3s | 拾取物品 |
| `ui_item_rare` | 获得稀有物品 | 升调铃声 + 光效声 | 0.5s | 拾取稀有 |
| `ui_gold` | 获得灵石 | 金属碰撞声 | 0.2s | 获得灵石 |
| `ui_scroll` | 卷轴滚动 | 纸张滚动声 | 持续 | 卷轴界面 |
| `ui_typewriter` | 打字机效果 | 墨笔书写声，每字一下 | 0.05s/字 | 文字显示 |
| `ui_select_confirm` | 确认选择 | 墨笔落印声 | 0.3s | 道心选择确认 |
| `ui_seed_input` | 种子输入 | 毛笔落纸声 | 0.05s/字 | 输入种子 |

### 4.2 战斗音效

| 音效ID | 名称 | 描述 | 时长 | 触发场景 |
|--------|------|------|------|----------|
| `combat_sword_slash` | 剑斩 | 金属划破空气 + 水声 | 0.3s | 剑修普攻 |
| `combat_fire_burst` | 火焰爆发 | 火焰喷射 + 燃烧 | 0.4s | 火系技能 |
| `combat_water_splash` | 水流冲击 | 水流涌动 + 飞溅 | 0.3s | 水系技能 |
| `combat_thunder_strike` | 雷击 | 闪电劈裂 + 雷鸣 | 0.5s | 雷系技能 |
| `combat_wood_vine` | 藤蔓缠绕 | 植物生长 + 缠绕声 | 0.4s | 木系技能 |
| `combat_earth_crush` | 土石崩裂 | 岩石碎裂 + 震动 | 0.5s | 土系技能 |
| `combat_chaos_rift` | 混沌裂隙 | 扭曲能量 + 空间撕裂 | 0.6s | 混沌技能 |
| `combat_hit_light` | 轻击命中 | 墨点飞溅 + 微弱冲击 | 0.15s | 普攻命中 |
| `combat_hit_heavy` | 重击命中 | 墨点飞溅 + 强烈冲击 | 0.2s | 暴击命中 |
| `combat_dodge` | 闪避 | 墨水流动 + 风声 | 0.2s | 闪避动作 |
| `combat_shield_block` | 护盾格挡 | 墨盾碰撞 + 能量声 | 0.3s | 护盾挡伤 |
| `combat_player_hurt` | 玩家受伤 | 短促冲击 + 墨点飞溅 | 0.2s | 受到伤害 |
| `combat_player_death` | 玩家死亡 | 墨水泼洒 + 消散声 | 1.0s | 角色死亡 |
| `combat_enemy_spawn` | 敌人生成 | 墨水凝聚 + 出现声 | 0.5s | 敌人刷新 |
| `combat_enemy_death` | 敌人死亡 | 墨水消散 + 碎裂声 | 0.4s | 敌人死亡 |
| `combat_boss_appear` | Boss出场 | 雷鸣 + 地震 + 墨水漩涡 | 2.0s | Boss出现 |
| `combat_boss_phase` | Boss阶段切换 | 玻璃碎裂 + 能量爆发 | 1.0s | Boss转阶段 |
| `combat_wave_start` | 波次开始 | 号角声 + 墨水扩散 | 0.8s | 新波次开始 |
| `combat_wave_clear` | 波次清空 | 墨点消散 + 安宁声 | 0.5s | 波次结束 |
| `combat_combo` | 连击 | 升调金属声 | 0.2s | 连击计数 |

### 4.3 氛围音效

| 音效ID | 名称 | 描述 | 时长 | 触发场景 |
|--------|------|------|------|----------|
| `amb_forest` | 山林氛围 | 风声 + 竹叶声 + 远处鸟鸣 | 循环 | Stage 1 |
| `amb_cave` | 水洞氛围 | 水滴回声 + 暗流涌动 | 循环 | Stage 2 |
| `amb_thunder` | 雷域氛围 | 远处雷鸣 + 风声 + 电磁嗡鸣 | 循环 | Stage 3 |
| `amb_inferno` | 熔炉氛围 | 岩浆涌动 + 火焰燃烧 + 热风 | 循环 | Stage 4 |
| `amb_celestial` | 天劫氛围 | 风暴呼啸 + 雷电远响 + 空间扭曲 | 循环 | Stage 5 |
| `amb_menu` | 主菜单氛围 | 悠远笛声 + 墨水流淌 + 微弱风铃 | 循环 | 主菜单 |
| `amb_market` | 坊市氛围 | 远处人声 + 叫卖声 + 炊烟声 | 循环 | 坊市界面 |
| `amb_event` | 事件氛围 | 低沉嗡鸣 + 灵气聚集 | 5-10s | 事件触发 |
| `amb_victory` | 胜利氛围 | 升调铃声 + 金光声 + 宁静 | 3-5s | 战斗胜利 |
| `amb_defeat` | 失败氛围 | 低沉消散 + 墨水泼洒 + 寂静 | 3-5s | 战斗失败 |
| `amb_heart_dao` | 道心氛围 | 深沉冥想声 + 灵气脉动 | 循环 | 道心选择 |
| `amb_samsara` | 轮回氛围 | 时空扭曲 + 远处钟声 + 墨水旋涡 | 循环 | 轮回转场 |

---

## 五、资产文件命名规范

### 5.1 文件命名格式

```
{类别}_{子类别}_{名称}_{尺寸}_{变体}.{格式}
```

**类别前缀**

| 类别 | 前缀 | 示例 |
|------|------|------|
| 场景背景 | `bg_` | `bg_stage1_forest_1920x1920.png` |
| UI面板 | `panel_` | `panel_standard_9patch.png` |
| UI按钮 | `btn_` | `btn_large_normal.png` |
| UI图标 | `icon_` | `icon_skill_sword_32.png` |
| 卡牌 | `card_` | `card_front_160x224.png` |
| 角色Sprite | `char_` | `char_swordsman_idle_72.png` |
| 敌人Sprite | `enemy_` | `enemy_berserker_idle_64.png` |
| Boss Sprite | `boss_` | `boss_fire_golem_idle_160.png` |
| 灵宠Sprite | `pet_` | `pet_firefly_idle_24.png` |
| 粒子纹理 | `part_` | `part_ink_dot_4.png` |
| 音效 | `sfx_` | `sfx_ui_click.wav` |
| 氛围音效 | `amb_` | `amb_forest_loop.ogg` |

### 5.2 目录结构

```
game/assets/
├── art/
│   ├── backgrounds/
│   │   ├── main_menu/
│   │   ├── daoheart_setup/
│   │   ├── stage1_bamboo/
│   │   ├── stage2_mountain/
│   │   ├── stage3_thunder/
│   │   ├── stage4_inferno/
│   │   ├── stage5_celestial/
│   │   ├── market/
│   │   ├── event/
│   │   └── result/
│   ├── ui/
│   │   ├── panels/
│   │   ├── buttons/
│   │   ├── icons/
│   │   ├── cards/
│   │   ├── progress_bars/
│   │   └── decorations/
│   ├── characters/
│   │   ├── swordsman/
│   │   ├── alchemist/
│   │   ├── talisman/
│   │   ├── monk/
│   │   ├── dark/
│   │   └── wanderer/
│   ├── enemies/
│   │   ├── berserker/
│   │   ├── archer/
│   │   ├── flyer/
│   │   └── elites/
│   ├── bosses/
│   │   ├── boss1_fire_golem/
│   │   ├── boss2_water_dragon/
│   │   ├── boss3_thunder_shadow/
│   │   ├── boss4_fire_demon/
│   │   └── boss5_tribulation/
│   ├── pets/
│   │   ├── firefly/
│   │   ├── turtle/
│   │   ├── thunderbird/
│   │   ├── woodspirit/
│   │   ├── earthbeast/
│   │   └── chaosworm/
│   ├── particles/
│   │   ├── ink/
│   │   ├── elements/
│   │   ├── quality/
│   │   └── ambient/
│   └── fonts/
├── audio/
│   ├── sfx/
│   │   ├── ui/
│   │   ├── combat/
│   │   └── misc/
│   └── ambience/
└── shaders/
    ├── ink_edge.gdshader
    ├── outline.gdshader
    └── nine_patch_brush.gdshader
```

---

## 六、Godot导入设置速查

### 6.1 纹理导入

```ini
[common]
compress/mode=0  ; Lossless
compress/high_quality=false
compress/hdr_compression=1

[2d]
detect_3d/compress_to=0
mipmaps/generate=false
roughness/mode=0
process/size_limit=0
svg/scale=1.0
editor/scale=1.0
```

### 6.2 音频导入

```ini
[common]
compress/mode=2  ; MP3 (UI音效) / 0 (WAV, 战斗音效)
compress/quality=0.8
loop/mode=0  ; Off (单次) / 1 (Forward, 循环)
loop/begin=0
loop/end=-1
```

### 6.3 粒子纹理要求

- 格式：PNG（带 Alpha 通道）
- 颜色空间：sRGB
- 混合模式：Additive（所有发光粒子）
- 最大尺寸：16×16px（大部分 2×2 ~ 8×8）
- 无 Mipmap

---

*文档结束 — 《轮回仙途》美术资产规格 v1.0*
