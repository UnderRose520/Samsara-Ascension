# 《轮回仙途》UI 资产提示词 — 金碧仙宫风格

**用途：** AI 图片生成提示词，覆盖三张核心 UI 页面的所有视觉资产  
**统一风格：** 中国修仙·金碧仙宫 — 翡翠碧玉底色、鎏金雕花边框、祥云仙鹤、山水仙境  
**设计基准：** 1920×1080（UIUX §5 布局与尺寸均以该画布标注）  
**运行视口：** 1280×720（`game/project.godot` → `display/window/size`；`stretch/mode=canvas_items`）  
**色彩体系（对齐 `ui_tokens.gd`）：** 深翡翠绿底 `#06140F` (BG_DEEP) / 面板底 `#0F2A22` (BG_PANEL)，鎏金 `#FFD700` (ACCENT_GOLD)，玉石青 `#4ECDC4` (ELEM_WATER)，暗紫 `#B57EDC` (ELEM_CHAOS)  
**适用范围：** 金碧仙宫风格仅用于地图背景、技能装饰框、面板框架等装饰性元素；功能性小图标（karma、治疗、闪避等）见第七部分，使用通用扁平风格。

> **尺寸含义：** 下文各条「尺寸」= **设计稿逻辑像素**（按 1920×1080 标注），不是物理屏幕像素。Godot 会把整个 UI 画布等比缩放至窗口；**不需要**为 1280×720、2560×1440 各做一套同名 PNG。多分辨率策略见 **§0**。

---

## 0. 分辨率、纵横比与像素密度

### 0.1 三层坐标（美术 / 策划 / 程序共用）

| 层级 | 含义 | 本项目取值 |
|------|------|------------|
| **设计基准** | 线框、间距、资产标注尺寸的参照画布 | **1920×1080**（16:9） |
| **逻辑视口** | Godot Control 布局实际使用的坐标系 | **1280×720**（16:9，= 设计基准 × **2/3**） |
| **物理窗口** | 玩家显示器分辨率（Steam 常见 1080p / 1440p / 4K / 超宽） | 任意；由引擎 **整体缩放** 逻辑视口 |

**换算：** 设计稿上 `W×H` → 场景中约 `round(W×2/3) × round(H×2/3)`。例：Setup 面板设计 640×590 → 场景 `640×590` 偏移（当前 `run_setup_panel` 已按 1280 宽系布局）；HUD 左上区设计宽 320px → 实现 `320px` 逻辑宽。

**代码入口：** `game/project.godot` `[display]`；布局见各 `.tscn` 锚点/偏移；路径常量 `game/assets/asset_paths.gd`。

### 0.2 是否需要 @2x / 多精度版本？

| 资产类型 | 交付策略 | 说明 |
|----------|----------|------|
| **九宫格框 / 进度条 / 分隔线** | **仅 1x**，按文档标注像素导出 | 由 `StyleBoxTexture` / `TextureRect` **拉伸**；不必做 @2x |
| **小图标（16–48px）** | **1x PNG**；高细节可选 **SVG 源文件** | UIUX §11：图标可 SVG；运行时 Godot 用 PNG。PC 1080p–4K **一套即可**，靠 `canvas_items` 缩放 |
| **大图标 / 卡片顶图（64–128px）** | **1x 按标注尺寸**；机缘卡 **80px 专图**（§6.2） | 避免把 32px 图标硬拉大到 80px |
| **全屏背景 / 氛围图（1920×1080）** | **1 张 16:9 主图**；可选 **2560×1440 源图** 仅当 4K 下 COVERED 裁切仍糊 | **不做** `@2x` 文件名约定；高分辨率用 `_4k` 或覆盖同名文件 |
| **战斗精灵（16–64px）** | **1x 像素风**；Filter **Nearest** | 放大时保持像素清晰；与 UI 图标策略不同 |
| **装饰性 UI（卷轴框、品质框）** | **1x + 九宫格边距固定** | 选中态 glow 可用 **第二张 PNG** 或代码 `modulate`（当前突破卡） |

**结论（Steam PC 首发）：**

- **默认只维护一套 PNG**，尺寸按 **1920×1080 设计基准** 标注（与 UIUX「@2x 为 1080p 基准」一致：即 **1080p 高度下的 1x 资产**，不是 iOS 的 `@2x` 双份资源）。
- **不需要**为 1280×720、1920×1080、2560×1440 各导出同名资源。
- **需要**在 **4K 全屏背景** 或 **极大放大** 的场景单独评估是否提供更高分辨率 **源图**（仍替换同一路径，不增加代码分支）。

### 0.3 纵横比适配（16:10、21:9 超宽等）

引擎：`stretch/mode=canvas_items`，默认 **`aspect=keep`**（视口等比缩放，不足处 **留黑边/留空**，不拉伸变形）。

| 区域 | 代码策略 | 美术要求 |
|------|----------|----------|
| **全屏背景** | `TextureRect` + `STRETCH_KEEP_ASPECT_COVERED`（Setup `Backdrop`、突破弱化 hall） | 构图 **中心安全区** 放主体；上下或左右可被 **裁切**；避免关键元素贴边 |
| **全屏遮罩 Dimmer** | `ColorRect` 锚点铺满 | 无资产要求 |
| **居中 Modal**（Setup / 突破 / 词条） | 锚点 **屏幕中心** + 固定 `offset` 宽高 | 面板本身 **不随超宽变宽**；超宽屏两侧露出更多背景 |
| **战斗 HUD 四区** | 左上/右上/底中 **角锚 + 边距**（`hud.tscn`） | 超宽时 **中央战斗区变宽**，HUD 贴边不动；不在 HUD 资产里做超宽专用横条 |
| **Toast / 顶栏横幅** | 水平居中或 `expand` 宽度 | 九宫格横条可水平 repeat；插画类 **16:9 安全区** |

**验收纵横比（除 16:9 外必测）：**

| 比例 | 示例分辨率 | 关注点 |
|------|------------|--------|
| 16:9 | 1920×1080、1280×720 | 基准 |
| 16:10 | 1920×1200、2560×1600 | 上下黑边或略裁背景；HUD 不重叠 |
| 21:9 | 2560×1080、3440×1440 | 背景左右裁切；Modal 仍居中；中央留白加大 |
| 4:3 | 1440×1080（少见） | 左右黑边；角锚 HUD 仍可用 |

**不做：** 为 21:9 单独画「加宽版 HUD 底图」—— 布局交给锚点，美术保证 **背景 COVERED 可裁** 即可。

### 0.4 像素密度（HiDPI / 125%–200% 系统缩放）

- Godot 4 **PC 版**以 **窗口像素** 为准；系统显示缩放由 OS 报告给引擎，UI 随 `canvas_items` 一并缩放。
- **小图标**在 4K + 150% 缩放下若发糊：优先检查导入设置 **`Filter=Linear`**（UI） vs **`Nearest`**（像素精灵）；其次考虑 **略增大源图分辨率**（如 32→48 图标），仍只保留 **一个文件名**。
- **细线 / 1px 分隔线**（如 `divider_gold_256x2`）：导出 **2px 高源图** 或中间 1px 实线 + 透明上下，避免缩放后消失。

### 0.5 资产类型 → 代码拉伸模式速查

| 资产示例 | 推荐 `stretch_mode` / 用法 | 分辨率敏感? |
|----------|---------------------------|-------------|
| `bg_jade_palace_hall.png` | `KEEP_ASPECT_COVERED` | **高** — 需安全区 |
| `panel_ninepatch_256.png` | `StyleBoxTexture` 九宫格 | 低 — 边距 32px 固定 |
| `talent_scroll_210x200.png` | `STRETCH_SCALE`（随卡固定尺寸） | 低 — 尺寸写死在场景 |
| `modal_title_bar_720x52.png` | `EXPAND_FIT_WIDTH` 比例居中 | 中 — 随 Modal 宽度 |
| `divider_gold_256x2.png` | 水平 fit 宽度 | 低 |
| `progress_hp_9slice.png` | 九宫格 **仅横向** 拉长 | 低 |
| `elem_*_32.png` | `KEEP_ASPECT_CENTERED`，控件 min 32×32 | 中 — 勿小于标注尺寸 |
| `elem_*_large_80.png` | 机缘卡专用，禁止从 32 拉伸 | **高** |

### 0.6 给 AI 出图时的统一后缀（可选写入提示词末尾）

> "Designed for 1920x1080 game UI logical space; center-weighted composition for 16:9 safe area; edges may be cropped on ultrawide displays; no text; transparent background where specified."

全屏背景额外加：

> "Important visual elements in central 70% frame; dark soft edges for letterbox/crop tolerance."

---

## 全局风格统一描述（金碧仙宫装饰框架 / 背景类资产共用前缀）

> **风格前缀（第一～六部分装饰类资产使用，第七部分功能性图标不用）：**
> "Chinese xianxia immortal palace aesthetic, deep jade-green dark background (#06140F), ornate gilded gold filigree borders (#FFD700), jade-teal gemstone inlays (#4ECDC4), intricate cloud-scroll patterns, ancient Chinese calligraphy influence, high-fantasy cultivation RPG game UI, painterly rendering with subtle metallic sheen, no text"

---

## 第一部分：道心选择页（Run Setup Panel）— UI-01

### 1.1 全屏背景

**文件名：** `bg_jade_palace_hall.png`  
**尺寸：** 1920×1080（全屏，16:9 主图；见 §0.3 COVERED 裁切）  
**代码位置：** `run_setup_panel.tscn` → `Backdrop` TextureRect（`STRETCH_KEEP_ASPECT_COVERED`）  
**AssetPaths 常量：** `MENU_BACKDROP`

**提示词：**
> A grand celestial jade palace hall interior, Chinese xianxia immortal palace aesthetic. Massive jade-green marble columns with gilded gold capitals and intricate dragon-phoenix carvings rise to a vaulted ceiling. The floor is polished dark jade reflecting golden light. Through open archways, distant immortal mountain peaks float among ethereal clouds and mist. Golden ornamental railings and hanging lanterns line the hall. A pair of elegant white cranes stand on a golden platform. The atmosphere is serene and majestic, bathed in warm golden light filtering through jade lattices. Deep jade-green and gold color palette. Cinematic wide-angle perspective, no text, no UI elements, painterly digital art style, game background asset.

### 1.2 中央面板框（九宫格）

**文件名：** `panel_ninepatch_256.png`  
**尺寸：** 256×256（九宫格，边距 32px）  
**代码位置：** `run_setup_panel.tscn` → `Panel` PanelContainer  
**AssetPaths 常量：** `PANEL_NINEPATCH`

**提示词：**
> An ornate Chinese immortal palace decorative panel frame, 256x256 pixels, nine-patch compatible. Dark jade-green background (#1A1A2E) with an elaborate beveled gold frame border. The gold frame features traditional Chinese cloud-scroll motifs, with multiple layered gold lines creating depth. Four corners have jade gemstone inlays (teal-green #4FD6B8) set in golden bezels. Subtle aged jade texture on the panel surface. The design is symmetrical with ornate filigree patterns along all four edges. No text, transparent background outside the frame, game UI panel asset.

### 1.3 道心卡片外框

**文件名：** `dao_heart_card_frame.png`  
**尺寸：** 168×200（九宫格）  
**代码位置：** `dao_heart_card.tscn` → `DaoHeartCard` PanelContainer  
**说明：** 当前无独立 PNG（纯 StyleBoxFlat 占位），需新增

**提示词：**
> An ornate vertical card frame for a Chinese xianxia game, 168x200 pixels. Deep dark jade-green (#1B4438) background with a thin golden (#FFD700) border featuring delicate cloud-scroll filigree patterns. The top and bottom edges have slightly thicker gold lines with subtle scrollwork. Small jade gemstone dots at each corner. Inner area has a slightly lighter jade tint with faint rice-paper texture. The frame should feel like an elegant jade tablet with gold trimming. No text, no icons, game UI card frame asset.

### 1.4 问道图标（太极）

**文件名：** `dao_heart_ask_128.png`  
**尺寸：** 128×128  
**代码位置：** `dao_heart_card.tscn` → `Icon` TextureRect  
**AssetPaths 常量：** `DAO_HEART_ICONS["ask"]`

**提示词：**
> A mystical yin-yang taiji symbol rendered in Chinese xianxia immortal palace style, 128x128 pixels. The taiji is composed of swirling jade-blue (#4ECDC4) and deep midnight-blue energy, with each half containing a luminous pearl (one light, one dark). The symbol is encircled by a thin golden (#FFD700) ring with ornate cloud-scroll engravings. Ethereal jade-green energy wisps emanate from the symbol. Set against a dark jade background with subtle golden filigree patterns. The symbol represents "Asking the Dao" — a calm, contemplative path. No text, game UI icon, painterly rendering with metallic gold accents.

### 1.5 悟道图标（太阳/烈阳）

**文件名：** `dao_heart_enlighten_128.png`  
**尺寸：** 128×128  
**代码位置：** `dao_heart_card.tscn` → `Icon` TextureRect  
**AssetPaths 常量：** `DAO_HEART_ICONS["enlighten"]`

**提示词：**
> A radiant golden sun medallion in Chinese xianxia immortal palace style, 128x128 pixels. A blazing golden (#FFD700) sun with an inner spiral vortex of molten gold, surrounded by twelve radiating golden flame tendrils. The sun is framed by an ornate golden circular border with traditional Chinese cloud-scroll engravings and jade-green (#4FD6B8) gemstone accents. Wisps of golden energy spiral outward. The symbol represents "Enlightenment" — the balanced standard path. Set against a dark jade background. No text, game UI icon, painterly rendering with luminous metallic sheen.

### 1.6 证道图标（双剑）

**文件名：** `dao_heart_prove_128.png`  
**尺寸：** 128×128  
**代码位置：** `dao_heart_card.tscn` → `Icon` TextureRect  
**AssetPaths 常量：** `DAO_HEART_ICONS["prove"]`

**提示词：**
> Two crossed celestial swords in Chinese xianxia immortal palace style, 128x128 pixels. A pair of ornate jian (Chinese straight swords) with crimson-red (#EF4444) energy-wreathed blades crossing at the center. Each blade has a golden (#FFD700) cross-guard with jade-green gemstone pommels. Fiery red energy trails emanate from the blades, with subtle ember particles. The swords are framed by an ornate golden circular border with cloud-scroll engravings. The symbol represents "Proving the Dao" — the extreme trial path. Set against a dark jade background. No text, game UI icon, painterly rendering with dramatic crimson and gold accents.

### 1.7 标题装饰条

**文件名：** `setup_title_ornament.png`  
**尺寸：** 640×48  
**代码位置：** `run_setup_panel.tscn` → `Title` Label 上方装饰  
**说明：** 当前仅有文字 Label，可增加装饰条

**提示词：**
> A horizontal decorative title banner ornament for Chinese xianxia game UI, 640x48 pixels. A thin golden (#FFD700) line with ornate cloud-scroll filigree extending from both ends toward the center. At the center, a small jade-green (#4FD6B8) gemstone set in a golden bezel. The golden lines have subtle beveled highlights creating a metallic 3D effect. Faint golden energy wisps extend upward. Transparent background outside the ornament. No text, game UI decorative element.

### 1.8 按钮 — 主按钮（踏入轮回）

**文件名：** `btn_primary_gold_360x48.png`  
**尺寸：** 360×48  
**代码位置：** `run_setup_panel.tscn` → `StartButton` Button  
**说明：** 当前使用 Theme `Primary`，无专用 PNG

**提示词：**
> A primary action button for Chinese xianxia game UI, 360x48 pixels. Rich golden (#FFD700) gradient background with a subtle metallic sheen, transitioning from deeper gold at edges to brighter gold at center. The button has a thin dark border with ornate golden filigree corner decorations (small cloud-scroll motifs). A faint inner glow gives a sense of depth. The overall feel is luxurious and commanding — a "enter the cycle" CTA button. No text, transparent background outside button, game UI asset.

### 1.9 按钮 — 次要按钮（轮回成长）

**文件名：** `btn_secondary_360x40.png`  
**尺寸：** 360×40  
**代码位置：** `run_setup_panel.tscn` → `MetaButton` Button  
**说明：** 当前使用 Theme `Secondary`，无专用 PNG

**提示词：**
> A secondary action button for Chinese xianxia game UI, 360x40 pixels. Semi-transparent dark jade-green (#1A1A2E) background with a thin (#C4B69C) border line. Subtle golden (#FFD700) edge highlights at the top and bottom. Minimal decoration — a clean, understated button that complements but does not compete with the primary golden button. No text, transparent background outside button, game UI asset.

---

## 第二部分：机缘三选一 / 词条三选一 — UI-04 / UI-05

### 2.1 突破/词条面板标题条

**文件名：** `modal_title_bar_720x52.png`（已有，建议重绘）  
**尺寸：** 720×52  
**代码位置：** `breakthrough_panel.gd` → `decorate_modal_header()`  
**AssetPaths 常量：** `MODAL_TITLE_BAR`

**提示词：**
> A modal title bar ornament for Chinese xianxia game UI, 720x52 pixels. An ornate horizontal banner with a central jade-green (#4FD6B8) gemstone set in an elaborate golden (#FFD700) bezel with filigree cloud-scroll decorations radiating outward. The bar has a dark jade-green (#0F2A22) background with thin golden lines above and below. Golden filigree scrollwork extends symmetrically from the center gem toward both edges, fading out toward the ends. Subtle metallic sheen on all gold elements. No text, game UI decorative element.

### 2.2 金色分隔线

**文件名：** `divider_gold_256x2.png`（已有，建议重绘）  
**尺寸：** 256×2  
**代码位置：** `breakthrough_panel.gd` → `add_gold_divider()`  
**AssetPaths 常量：** `DIVIDER_GOLD`

**提示词：**
> A thin golden horizontal divider line for Chinese xianxia game UI, 256x2 pixels. The line has a gradient effect — brighter gold (#FFD700) at the center, fading to a muted gold (#C4B69C) at the edges. Subtle metallic shimmer. The line is perfectly horizontal with clean edges. No text, transparent background, game UI decorative element.

### 2.3 卷轴天赋卡片框

**文件名：** `talent_scroll_210x200.png`（已有，建议重绘）  
**尺寸：** 210×200  
**代码位置：** `talent_card.tscn` → `FrameBg` TextureRect  
**AssetPaths 常量：** `TALENT_SCROLL`

**提示词：**
> A vertical scroll-style card frame for Chinese xianxia game UI, 210x200 pixels. Resembles an ancient jade-green (#1B4438) scroll or tablet with ornate golden (#FFD700) frame edges on the left and right sides (like golden scroll rollers). The top and bottom edges have horizontal golden lines with subtle cloud-scroll engravings. The interior has a slightly lighter jade tint with faint aged rice-paper texture. Four corners have small jade-green (#4FD6B8) gemstone accents. The overall feel is like an ancient cultivation scroll mounted in a golden frame. No text, no icons, transparent background, game UI card asset.

### 2.4 卷轴卡片选中态（高亮版）

**文件名：** `talent_scroll_210x200_highlight.png`  
**尺寸：** 210×200  
**代码位置：** `talent_card.gd` → hover 时 `modulate` 暖色  
**说明：** 可选，当前用代码 modulate 实现

**提示词：**
> A vertical scroll-style card frame for Chinese xianxia game UI, 210x200 pixels, in "selected/hovered" state. Same design as the base scroll card but with enhanced golden (#FFD700) frame edges that have a warm luminous glow. A subtle golden outer glow surrounds the entire card. The jade-green (#1B4438) interior is slightly warmer-toned. Small golden particle-like sparkles are scattered along the frame edges. The card feels "active" and "selected" — like a sacred scroll being chosen. No text, no icons, transparent background, game UI card asset.

### 2.5 品质框 — 凡品

**文件名：** `quality_common_220x280.png`（已有，建议重绘）  
**尺寸：** 220×280  
**代码位置：** `asset_paths.gd` → `QUALITY_FRAMES[0]`

**提示词：**
> A quality tier card frame "Common/凡品" for Chinese xianxia game UI, 220x280 pixels. Simple thin silver-gray (#B0B0B0) border on a dark jade-green (#1A1A2E) background. Minimal ornamentation — just a clean 1px border with very subtle aged texture. The frame is understated and plain, representing the lowest tier. No text, no icons, game UI quality frame asset.

### 2.6 品质框 — 灵品

**文件名：** `quality_rare_220x280.png`（已有，建议重绘）  
**尺寸：** 220×280  
**代码位置：** `asset_paths.gd` → `QUALITY_FRAMES[1]`

**提示词：**
> A quality tier card frame "Rare/灵品" for Chinese xianxia game UI, 220x280 pixels. A thin blue (#4E9AF1) border on a dark jade-green (#1A1A2E) background with a subtle blue outer glow. Simple cloud-scroll filigree at the four corners in blue-tinted gold. The frame has a faint ethereal blue shimmer. Slightly more ornate than Common. No text, no icons, game UI quality frame asset.

### 2.7 品质框 — 仙品

**文件名：** `quality_epic_220x280.png`（已有，建议重绘）  
**尺寸：** 220×280  
**代码位置：** `asset_paths.gd` → `QUALITY_FRAMES[2]`

**提示词：**
> A quality tier card frame "Epic/仙品" for Chinese xianxia game UI, 220x280 pixels. A 2px purple (#A855F7) border on a dark jade-green (#1A1A2E) background with a noticeable purple outer glow and scattered tiny purple particle sparkles. Ornate golden (#FFD700) cloud-scroll filigree at all four corners. The frame has an otherworldly mystical purple shimmer. Moderately ornate with celestial feel. No text, no icons, game UI quality frame asset.

### 2.8 品质框 — 天品

**文件名：** `quality_legendary_220x280.png`（已有，建议重绘）  
**尺寸：** 220×280  
**代码位置：** `asset_paths.gd` → `QUALITY_FRAMES[3]`

**提示词：**
> A quality tier card frame "Legendary/天品" for Chinese xianxia game UI, 220x280 pixels. A 2px golden (#F59E0B) border on a dark jade-green (#1A1A2E) background with a strong golden outer glow and animated-looking golden sweep-light effect. Ornate golden (#FFD700) cloud-scroll filigree at all four corners with additional gold lines along the edges. A golden light sweep travels across the frame. Very ornate and prestigious. No text, no icons, game UI quality frame asset.

### 2.9 品质框 — 道品

**文件名：** `quality_dao_220x280.png`（已有，建议重绘）  
**尺寸：** 220×280  
**代码位置：** `asset_paths.gd` → `QUALITY_FRAMES[4]`

**提示词：**
> A quality tier card frame "Dao/道品" for Chinese xianxia game UI, 220x280 pixels. A 2px gradient border transitioning between crimson-red (#EF4444) and golden (#FFD700) on a dark jade-green (#1A1A2E) background. A prominent golden-red gradient outer glow. The most ornate frame — elaborate golden (#FFD700) cloud-scroll filigree at all four corners, gold filigree lines running along all edges, and a crimson-gold gradient light sweep. Represents the ultimate cultivation tier. No text, no icons, game UI quality frame asset.

### 2.10 属性图标 — 火

**文件名：** `elem_fire_32.png`（已有，建议重绘）  
**尺寸：** 32×32  
**AssetPaths 常量：** `ELEMENT_ICONS["fire"]`

**提示词：**
> A fire element icon for Chinese xianxia game UI, 32x32 pixels. A stylized flame rendered in warm orange-red (#FF6B35) with golden (#FFD700) highlights at the tips. The flame has a classic Chinese cloud-fire shape with elegant curved tendrils. Subtle inner glow. No background, transparent, game UI element icon.

### 2.11 属性图标 — 水

**文件名：** `elem_water_32.png`（已有，建议重绘）  
**尺寸：** 32×32  
**AssetPaths 常量：** `ELEMENT_ICONS["water"]`

**提示词：**
> A water element icon for Chinese xianxia game UI, 32x32 pixels. A stylized water droplet or wave crest rendered in teal-cyan (#4ECDC4) with lighter blue highlights. The shape has elegant Chinese water-scroll curves. Subtle inner glow with aquatic shimmer. No background, transparent, game UI element icon.

### 2.12 属性图标 — 雷

**文件名：** `elem_thunder_32.png`（已有，建议重绘）  
**尺寸：** 32×32  
**AssetPaths 常量：** `ELEMENT_ICONS["thunder"]`

**提示词：**
> A thunder/lightning element icon for Chinese xianxia game UI, 32x32 pixels. A stylized lightning bolt rendered in bright golden (#FFD700) with white-hot core. The bolt has a classic Chinese thunder-symbol shape with angular but elegant lines. Electric sparkle particles around the bolt. No background, transparent, game UI element icon.

### 2.13 属性图标 — 木

**文件名：** `elem_wood_32.png`（已有，建议重绘）  
**尺寸：** 32×32  
**AssetPaths 常量：** `ELEMENT_ICONS["wood"]`

**提示词：**
> A wood element icon for Chinese xianxia game UI, 32x32 pixels. A stylized leaf or small tree rendered in verdant green (#7BC67E) with lighter green veins. Organic flowing shape with subtle Chinese wood-pattern curves. Gentle inner glow. No background, transparent, game UI element icon.

### 2.14 属性图标 — 土

**文件名：** `elem_earth_32.png`（已有，建议重绘）  
**尺寸：** 32×32  
**AssetPaths 常量：** `ELEMENT_ICONS["earth"]`

**提示词：**
> An earth element icon for Chinese xianxia game UI, 32x32 pixels. A stylized mountain or earth rune rendered in warm amber-brown (#C4A35A) with darker stone texture. Solid and grounded shape with subtle Chinese mountain-pattern lines. Warm inner glow. No background, transparent, game UI element icon.

### 2.15 属性图标 — 混沌

**文件名：** `elem_chaos_32.png`（已有，建议重绘）  
**尺寸：** 32×32  
**AssetPaths 常量：** `ELEMENT_ICONS["chaos"]`

**提示词：**
> A chaos element icon for Chinese xianxia game UI, 32x32 pixels. A stylized chaos star or void swirl rendered in purple (#B57EDC) with pink-white highlights. A five-pointed star shape with swirling energy tendrils at each point. Otherworldly and mystical. No background, transparent, game UI element icon.

### 2.16 品质标签 — 凡品/灵品/仙品

**文件名：** `tag_common.png` / `tag_rare.png` / `tag_epic.png`  
**尺寸：** 64×24  
**代码位置：** `talent_card.gd` / `affix_card.gd` → 品质标签区域  
**说明：** 当前用代码 Label 实现，可增加专用标签底图

**提示词（凡品）：**
> A small quality tag badge "Common/凡品" background for Chinese xianxia game UI, 64x24 pixels. A subtle rounded rectangle with a thin silver-gray (#B0B0B0) border and semi-transparent dark jade (#1A1A2E) fill. Minimal decoration. No text, game UI tag asset.

**提示词（灵品）：**
> A small quality tag badge "Rare/灵品" background for Chinese xianxia game UI, 64x24 pixels. A rounded rectangle with a thin blue (#4E9AF1) border, semi-transparent dark jade (#1A1A2E) fill, and subtle blue outer glow. No text, game UI tag asset.

**提示词（仙品）：**
> A small quality tag badge "Epic/仙品" background for Chinese xianxia game UI, 64x24 pixels. A rounded rectangle with a 2px purple (#A855F7) border, semi-transparent dark jade (#1A1A2E) fill, purple outer glow, and tiny sparkle accents. No text, game UI tag asset.

### 2.17 元素系标签 — 冰系/雷系/火系

**文件名：** `tag_ice.png` / `tag_thunder.png` / `tag_fire.png`  
**尺寸：** 80×20  
**说明：** 卡片底部的 "冰系·控制" 等标签

**提示词（冰系）：**
> A small element tag badge for Chinese xianxia game UI, 80x20 pixels. Rounded rectangle with a thin ice-blue (#4ECDC4) left accent bar (3px wide) and semi-transparent ice-tinted dark fill. Subtle frost-like shimmer. No text, game UI tag asset.

**提示词（雷系）：**
> A small element tag badge for Chinese xianxia game UI, 80x20 pixels. Rounded rectangle with a thin golden (#FFD700) left accent bar (3px wide) and semi-transparent dark fill with golden tint. Subtle electric shimmer. No text, game UI tag asset.

**提示词（火系）：**
> A small element tag badge for Chinese xianxia game UI, 80x20 pixels. Rounded rectangle with a thin crimson (#FF6B35) left accent bar (3px wide) and semi-transparent dark fill with warm tint. Subtle ember shimmer. No text, game UI tag asset.

---

## 第三部分：战斗 HUD — UI-03

### 3.1 左上修士面板底图

**文件名：** `hud_panel_bg_320x448.png`（已有，建议重绘）  
**尺寸：** 320×448  
**代码位置：** `hud_character_panel.tscn` → `PanelFrame` TextureRect  
**AssetPaths 常量：** `HUD_PANEL_BG`

**提示词：**
> A left-side HUD panel background for Chinese xianxia game UI, 320x448 pixels. A semi-transparent dark jade-green (#0F2A22) panel with subtle aged rice-paper texture overlay. A thin golden (#FFD700) line runs along the left edge as an accent stripe. The panel has a faint inner border of slightly lighter jade. The texture resembles an ancient cultivation scroll or jade tablet — weathered but elegant. The panel should work as a semi-transparent overlay (opacity ~42%). No text, no data, game UI panel background asset.

### 3.2 右上天气面板专用框

**文件名：** `hud_weather_panel_280x120.png`  
**尺寸：** 280×120（九宫格）  
**代码位置：** `hud_weather_panel.tscn` → `PanelFrame` TextureRect  
**AssetPaths 常量：** `HUD_WEATHER_PANEL`（当前复用 `panel_ninepatch_256.png`，建议专用）

**提示词：**
> A right-top HUD weather panel frame for Chinese xianxia game UI, 280x120 pixels. A compact ornate panel with dark jade-green (#0F2A22) background. A thin golden (#FFD700) border with delicate cloud-scroll filigree at the four corners. A jade-green (#4FD6B8) gemstone accent at the top center. Subtle aged jade texture. The panel is compact and elegant, designed to hold weather/celestial information. No text, no icons, game UI panel frame asset.

### 3.3 底中技能栏装饰框

**文件名：** `hud_spell_dock_frame.png`  
**尺寸：** 360×80  
**代码位置：** `hud_skill_dock.tscn` → `DockFrame` TextureRect  
**AssetPaths 常量：** `HUD_SKILL_DOCK_FRAME`（当前复用 `panel_ninepatch_256.png`，建议专用）

**提示词：**
> A bottom-center skill dock decorative frame for Chinese xianxia game UI, 360x80 pixels. A horizontal ornamental bar with dark jade-green (#0F2A22) background. Elaborate golden (#FFD700) filigree cloud-scroll decorations at both ends, extending inward. The center has a subtle jade-green (#4FD6B8) gemstone accent. Thin golden lines along top and bottom edges. The frame should feel like a sacred weapon rack or spell altar base. No text, no icons, transparent background outside the frame, game UI decorative element.

### 3.4 真元条（HP）填充

**文件名：** `progress_hp_9slice.png`（已有，建议重绘）  
**尺寸：** 64×16（九宫格）  
**代码位置：** `hud_character_panel.tscn` → `HpBar` → `hud_resource_bar.tscn`  
**AssetPaths 常量：** `PROGRESS_HP`

**提示词：**
> A health/HP bar fill texture for Chinese xianxia game UI, 64x16 pixels, nine-patch compatible. A horizontal bar with a warm red (#E85D5D) to soft pink (#FF8A7A) gradient fill. Rounded ends. Subtle inner glow and a thin darker red outline. The bar has a slight metallic sheen. Designed to be stretched horizontally. No text, game UI progress bar asset.

### 3.5 灵力条（Mana）填充

**文件名：** `progress_mana_9slice.png`（已有，建议重绘）  
**尺寸：** 64×16（九宫格）  
**代码位置：** `hud_character_panel.tscn` → `ManaBar` → `hud_resource_bar.tscn`  
**AssetPaths 常量：** `PROGRESS_MANA`

**提示词：**
> A mana/spirit-power bar fill texture for Chinese xianxia game UI, 64x16 pixels, nine-patch compatible. A horizontal bar with a cool blue (#5B9BD5) to light sky-blue (#7EC8FF) gradient fill. Rounded ends. Subtle inner glow and a thin darker blue outline. The bar has a slight aquatic shimmer. Designed to be stretched horizontally. No text, game UI progress bar asset.

### 3.6 灵石图标

**文件名：** `icon_spirit_stone_32.png`  
**尺寸：** 32×32  
**代码位置：** `hud_character_panel.tscn` → `GoldIcon` TextureRect  
**AssetPaths 常量：** `ICON_SPIRIT_STONE`（当前使用 `elem_wood_32.png` 占位）

**提示词：**
> A spirit stone (灵石) currency icon for Chinese xianxia game UI, 32x32 pixels. A luminous jade-green (#4FD6B8) gemstone with a faceted, slightly oval shape. The stone has an inner golden (#FFD700) glow emanating from its core, with subtle light rays. A thin golden bezel frame around the stone. The gem looks precious and cultivation-world currency. No background, transparent, game UI currency icon.

### 3.7 Combo 进度条

**文件名：** `combo_track_256x8.png`（已有，建议重绘）  
**尺寸：** 256×8  
**代码位置：** `hud_character_panel.tscn` → `ComboTrackBar`  
**AssetPaths 常量：** `COMBO_TRACK`

**提示词：**
> A combo/awakening progress track bar for Chinese xianxia game UI, 256x8 pixels. A thin horizontal bar with a gradient fill transitioning from fiery orange-red (#FF6B35) on the left to bright golden (#FFD700) on the right. Dark jade (#1B4438) background behind the gradient. The bar has a subtle metallic sheen. Designed to show combo awakening progress. No text, game UI progress bar asset.

### 3.8 天象图标 — 8种

**文件名：** `weather_clear_32.png` 等  
**尺寸：** 32×32  
**代码位置：** `hud_weather_panel.tscn` → `WeatherIcon`  
**AssetPaths 常量：** `WEATHER_ICONS`

**晴/烈阳 — `weather_clear_32.png`：**
> A clear/sunny weather icon for Chinese xianxia game UI, 32x32 pixels. A radiant golden (#FFD700) sun with elegant ray patterns. The sun has a warm glow with subtle cloud-scroll motifs in the rays. Bright and warm. No background, transparent, game UI weather icon.

**雨 — `weather_rain_32.png`：**
> A rain weather icon for Chinese xianxia game UI, 32x32 pixels. A soft blue-gray cloud with delicate rain droplets falling. The droplets are rendered in teal-cyan (#4ECDC4) with subtle motion trails. Misty and atmospheric. No background, transparent, game UI weather icon.

**雷 — `weather_thunder_32.png`：**
> A thunder weather icon for Chinese xianxia game UI, 32x32 pixels. A dark storm cloud with a bright golden (#FFD700) lightning bolt striking downward. Electric spark particles around the bolt. Dramatic and powerful. No background, transparent, game UI weather icon.

**火劫 — `weather_fire_32.png`：**
> A fire tribulation weather icon for Chinese xianxia game UI, 32x32 pixels. A blazing fireball or flame vortex in orange-red (#FF6B35) with golden (#FFD700) core. Flame tendrils extending outward in a circular pattern. Intense and dangerous. No background, transparent, game UI weather icon.

**罡风 — `weather_wind_32.png`：**
> A wind/gale weather icon for Chinese xianxia game UI, 32x32 pixels. Stylized wind currents rendered as flowing green (#7BC67E) curves with subtle spiral patterns. The wind has an ethereal, cultivation-world quality with cloud-like wisps. No background, transparent, game UI weather icon.

**雾 — `weather_fog_32.png`：**
> A fog weather icon for Chinese xianxia game UI, 32x32 pixels. Layered misty fog bands rendered in soft gray (#8A8278) with slight transparency variations. The fog has a dreamy, ethereal quality. Subtle jade tint. No background, transparent, game UI weather icon.

**雪 — `weather_snow_32.png`：**
> A snow weather icon for Chinese xianxia game UI, 32x32 pixels. A stylized snowflake or cluster of snowflakes in ice-blue (#4ECDC4) and white. Delicate crystalline patterns with subtle sparkle. Cold and pristine. No background, transparent, game UI weather icon.

**沙 — `weather_sand_32.png`：**
> A sandstorm weather icon for Chinese xianxia game UI, 32x32 pixels. Swirling sand particles in warm amber-brown (#C4A35A) forming a small vortex. Sandy wind currents with fine particle trails. Arid and fierce. No background, transparent, game UI weather icon.

### 3.9 灵宠头像外环

**文件名：** `pet_avatar_ring_40.png`（已有，建议重绘）  
**尺寸：** 40×40  
**代码位置：** `hud_weather_panel.tscn` → `PetIcon` 区域  
**AssetPaths 常量：** `PET_AVATAR_RING`

**提示词：**
> A pet/companion avatar ring frame for Chinese xianxia game UI, 40x40 pixels. A circular golden (#FFD700) ring with delicate cloud-scroll engravings along the ring. The ring has a beveled metallic finish with a thin inner shadow. Designed to frame a small pet portrait inside. No background, transparent center, game UI avatar frame asset.

### 3.10 法术图标 — Q 火焰弹

**文件名：** `spell_q_fire_40.png`（已有，建议重绘）  
**尺寸：** 40×40  
**AssetPaths 常量：** `SPELL_ICONS["q"]`

**提示词：**
> A fire spell icon "Q slot" for Chinese xianxia game UI, 40x40 pixels. A stylized fireball or flame vortex in orange-red (#FF6B35) with a bright golden (#FFD700) core. The flame has elegant Chinese cloud-fire curves. Set on a dark jade-green (#1B4438) circular background with a thin golden border. The icon is compact and bold. No text, game UI spell icon.

### 3.11 法术图标 — E 雷击

**文件名：** `spell_e_thunder_40.png`（已有，建议重绘）  
**尺寸：** 40×40  
**AssetPaths 常量：** `SPELL_ICONS["e"]`

**提示词：**
> A thunder spell icon "E slot" for Chinese xianxia game UI, 40x40 pixels. A bright golden (#FFD700) lightning bolt striking downward with electric spark particles. Set on a dark jade-green (#1B4438) circular background with a thin golden border. Energetic and powerful. No text, game UI spell icon.

### 3.12 法术图标 — R 玄冰

**文件名：** `spell_r_water_40.png`（已有，建议重绘）  
**尺寸：** 40×40  
**AssetPaths 常量：** `SPELL_ICONS["r"]`

**提示词：**
> A water/ice spell icon "R slot" for Chinese xianxia game UI, 40x40 pixels. A stylized ice crystal or water vortex in teal-cyan (#4ECDC4) with lighter blue-white highlights. Crystalline and frost-like. Set on a dark jade-green (#1B4438) circular background with a thin golden border. Cold and elegant. No text, game UI spell icon.

### 3.13 法术图标 — 锁定态

**文件名：** `spell_q_locked_40.png` / `spell_e_locked_40.png` / `spell_r_locked_40.png`（已有，建议重绘）  
**尺寸：** 40×40  
**AssetPaths 常量：** `SPELL_ICONS["*_locked"]`

**提示词（通用锁定态）：**
> A locked spell slot icon for Chinese xianxia game UI, 40x40 pixels. A dark jade-green (#1B4438) circular background with a thin dimmed golden border. A prominent padlock silhouette in muted gray (#8A8278) at the center. The overall feel is "disabled" and "not yet available". Semi-transparent overlay dims the background. No text, game UI spell icon.

### 3.14 空槽位

**文件名：** `spell_slot_empty_40.png`（已有，建议重绘）  
**尺寸：** 40×40

**提示词：**
> An empty spell slot for Chinese xianxia game UI, 40x40 pixels. A dark jade-green (#1B4438) circular background with a thin dimmed golden border. A subtle inner shadow creating depth. The slot appears empty and waiting to be filled. Minimal decoration. No text, game UI spell slot asset.

### 3.15 锁定槽位

**文件名：** `spell_slot_locked_40.png`（已有，建议重绘）  
**尺寸：** 40×40

**提示词：**
> A locked spell slot for Chinese xianxia game UI, 40x40 pixels. A dark jade-green (#1B4438) circular background with a thin dimmed golden border. A padlock icon in muted gray at center with a semi-transparent dark overlay. The slot is clearly "locked" and inaccessible. No text, game UI spell slot asset.

### 3.16 习得 Toast 横幅底图

**文件名：** `scroll_toast_520x72.png`（已有，建议重绘）  
**尺寸：** 520×72  
**代码位置：** `hud.tscn` → `LearnToastPanel` → `ScrollBg`  
**AssetPaths 常量：** `SCROLL_TOAST`

**提示词：**
> A horizontal scroll-style toast notification banner for Chinese xianxia game UI, 520x72 pixels. A jade-green (#1A1A2E) panel with golden (#FFD700) horizontal lines at top and bottom edges. Ornate golden cloud-scroll corner decorations at all four corners (L-shaped metalwork, not full frame). The center has a slightly lighter jade tint with subtle aged rice-paper texture. The overall feel is like an unrolled ancient scroll notification. No text, game UI toast asset.

### 3.17 路径图标 — 5种

**尺寸：** 48×48  
**代码位置：** `path_choice_panel` → 路径卡片图标  
**AssetPaths 常量：** `PATH_ICONS`

**战斗 — `path_combat_48.png`：**
> A combat path icon for Chinese xianxia game UI, 48x48 pixels. A stylized sword (jian) in fiery orange-red (#FF6B35) on a dark jade circular background. Elegant and martial. No text, game UI path icon.

**调息 — `path_rest_48.png`：**
> A rest/recovery path icon for Chinese xianxia game UI, 48x48 pixels. A lotus flower in verdant green (#7BC67E) on a dark jade circular background. Peaceful and healing. No text, game UI path icon.

**坊市 — `path_shop_48.png`：**
> A shop/market path icon for Chinese xianxia game UI, 48x48 pixels. A golden (#FFD700) coin or treasure symbol on a dark jade circular background. Prosperous and inviting. No text, game UI path icon.

**机缘 — `path_event_48.png`：**
> A random event path icon for Chinese xianxia game UI, 48x48 pixels. A mystical scroll or fortune symbol in purple (#B57EDC) on a dark jade circular background. Mysterious and intriguing. No text, game UI path icon.

**精英 — `path_elite_48.png`：**
> An elite/special encounter path icon for Chinese xianxia game UI, 48x48 pixels. A skull or demon face symbol in golden (#F59E0B) on a dark jade circular background. Dangerous and prestigious. No text, game UI path icon.

### 3.18 事件横幅

**文件名：** `event_banner_640x160.png`（已有，建议重绘）  
**尺寸：** 640×160  
**AssetPaths 常量：** `EVENT_BANNER`

**提示词：**
> A wide event banner illustration for Chinese xianxia game UI, 640x160 pixels. A misty immortal mountain landscape with layered peaks fading into clouds. Deep jade-green (#0D2A22) tones at the bottom transitioning to lighter misty grays at the top. A pale golden moon (#FFD700) in the upper right. Horizontal mist bands float between mountain layers. The scene is serene and mystical, like a traditional Chinese landscape painting rendered in digital art style. No text, no UI elements, game event banner asset.

---

## 第四部分：境界突破面板 — UI-05 专用资产

### 4.1 境界天赋分类图标 — 5境

**文件名：** `talent_icon_realm_1.png` ~ `talent_icon_realm_5.png`  
**尺寸：** 48×48  
**代码位置：** `talent_card.tscn` → `Icon` TextureRect  
**AssetPaths 函数：** `AssetPaths.talent_realm_icon(realm_level)`

**炼气（1）— `talent_icon_realm_1.png`：**
> A realm/ cultivation-stage icon "Qi Refining/炼气" for Chinese xianxia game UI, 48x48 pixels. A delicate green (#7BC67E) jade leaf or qi-wisp symbol with flowing organic curves. Represents the foundational stage of cultivation. Soft inner glow. Set against a transparent background. No text, game UI realm icon.

**筑基（2）— `talent_icon_realm_2.png`：**
> A realm/cultivation-stage icon "Foundation/筑基" for Chinese xianxia game UI, 48x48 pixels. A solid golden-brown (#C4A35A) foundation stone or pillar base with angular geometric shapes. Represents building a strong foundation. Warm inner glow. Transparent background. No text, game UI realm icon.

**金丹（3）— `talent_icon_realm_3.png`：**
> A realm/cultivation-stage icon "Golden Core/金丹" for Chinese xianxia game UI, 48x48 pixels. A luminous golden (#FFD700) sphere or pill (dan) with radiating energy patterns. Represents the golden core formation. Brilliant inner glow with golden rays. Transparent background. No text, game UI realm icon.

**元婴（4）— `talent_icon_realm_4.png`：**
> A realm/cultivation-stage icon "Nascent Soul/元婴" for Chinese xianxia game UI, 48x48 pixels. A small ethereal golden (#FFD700) figure or soul-form emerging from a lotus base. Translucent and luminous with a golden aura. Represents the birth of the nascent soul. Transparent background. No text, game UI realm icon.

**渡劫（5）— `talent_icon_realm_5.png`：**
> A realm/cultivation-stage icon "Tribulation/渡劫" for Chinese xianxia game UI, 48x48 pixels. A dramatic golden (#FFD700) lightning bolt or tribulation cloud symbol with crimson (#EF4444) accents. Represents facing heavenly tribulation. Electric and powerful with a sense of danger. Transparent background. No text, game UI realm icon.

### 4.2 破境专用氛围背景

**文件名：** `breakthrough_bg_overlay.png`  
**尺寸：** 1920×1080（16:9；可选 2560×1440 源图覆盖，见 §0.2）  
**代码位置：** `breakthrough_panel.gd` → `_apply_weak_backdrop()`  
**说明：** 可选，当前复用 `bg_jade_palace_hall.png` @ 22% 弱化

**提示词：**
> An ethereal breakthrough/ascension atmosphere background for Chinese xianxia game UI, 1920x1080 pixels. A cosmic jade-green (#0D2A22) void with subtle swirling nebula patterns in darker tones. Faint golden (#FFD700) constellation lines connect across the background like a celestial map. Scattered jade-green (#4FD6B8) and golden energy particles drift through the space. The overall feel is transcendental and otherworldly — the space between mortal and immortal realms. Very dark and atmospheric (designed to be used at low opacity ~20%). No text, no UI elements, game UI overlay asset.

### 4.3 槽位箭头装饰

**文件名：** `bt_slot_arrow_32.png`  
**尺寸：** 32×32  
**代码位置：** `breakthrough_panel.tscn` → `ArrowLabel` Label  
**说明：** 当前用 Label `→`，可增加装饰箭头

**提示词：**
> A decorative arrow icon for Chinese xianxia game UI, 32x32 pixels. A golden (#FFD700) arrow pointing right, with ornate cloud-scroll decorations along the shaft. The arrowhead is a jade-green (#4FD6B8) diamond shape. The design is elegant and represents progression or advancement. Transparent background. No text, game UI decorative element.

### 4.4 效果类型角标

**文件名：** `talent_badge_attack.png` / `talent_badge_defense.png` / `talent_badge_spirit.png` / `talent_badge_utility.png`  
**尺寸：** 24×24  
**说明：** 可选，天赋卡片上的攻/防/真元/天机小标

**提示词（攻击）：**
> A small "Attack" type badge for Chinese xianxia game UI, 24x24 pixels. A tiny sword silhouette in fiery red (#FF6B35) on a semi-transparent dark circle. Minimal and clean. No text, transparent background, game UI badge.

**提示词（防御）：**
> A small "Defense" type badge for Chinese xianxia game UI, 24x24 pixels. A tiny shield silhouette in golden-brown (#C4A35A) on a semi-transparent dark circle. Minimal and clean. No text, transparent background, game UI badge.

**提示词（真元）：**
> A small "Spirit/真元" type badge for Chinese xianxia game UI, 24x24 pixels. A tiny pearl or orb silhouette in teal-cyan (#4ECDC4) on a semi-transparent dark circle. Minimal and clean. No text, transparent background, game UI badge.

**提示词（天机）：**
> A small "Celestial/天机" type badge for Chinese xianxia game UI, 24x24 pixels. A tiny star or constellation silhouette in bright golden (#FFD700) on a semi-transparent dark circle. Minimal and clean. No text, transparent background, game UI badge.

---

## 第五部分：角色与战斗精灵

### 5.1 玩家角色

**文件名：** `player_cultivator_64.png`（已有，建议重绘）  
**尺寸：** 64×64  
**代码位置：** `asset_paths.gd` → `PLAYER`

**提示词：**
> A top-down view cultivator character sprite for Chinese xianxia roguelite game, 64x64 pixels. A young immortal cultivator in flowing white and golden robes with jade-green accents. Hair tied in a topknot with a golden hairpin. The character stands in a ready combat stance. Elegant but simple silhouette suitable for small sprite. Clean outlines, limited palette, pixel-art inspired but with painterly details. Transparent background, game character sprite.

### 5.2 火萤灵宠

**文件名：** `pet_huo_ying_32.png`（已有，建议重绘）  
**尺寸：** 32×32  
**代码位置：** `asset_paths.gd` → `PET_HUO_YING`

**提示词：**
> A firefly companion pet sprite for Chinese xianxia roguelite game, 32x32 pixels. A tiny luminous firefly with orange-red (#FF6B35) wings and a bright golden (#FFD700) glowing body. Delicate and cute with a warm glow aura. Transparent background, game pet sprite.

### 5.3 敌人精灵 — 4种

**尺寸：** 64×64  
**代码位置：** `asset_paths.gd` → `ENEMY_*`

**训练木人 — `enemy_training_dummy_64.png`：**
> A training dummy enemy sprite for Chinese xianxia roguelite game, 64x64 pixels. A simple wooden training post or scarecrow-like figure in earth-brown (#C4A35A) tones. Basic and non-threatening. Clean silhouette. Transparent background, game enemy sprite.

**狂战士 — `enemy_berserker_64.png`：**
> A berserker demon enemy sprite for Chinese xianxia roguelite game, 64x64 pixels. A hulking demonic beast in crimson (#EF4444) with white markings. Muscular and aggressive pose. Dark and menacing. Transparent background, game enemy sprite.

**弓手 — `enemy_archer_64.png`：**
> An archer/ranged enemy sprite for Chinese xianxia roguelite game, 64x64 pixels. A lean demonic creature in green (#7BC67E) tones with a bow or ranged weapon. Agile and threatening. Transparent background, game enemy sprite.

**投弹手 — `enemy_bomber_64.png`：**
> A bomber/ranged enemy sprite for Chinese xianxia roguelite game, 64x64 pixels. A demonic creature in fiery orange (#FF6B35) with golden (#FFD700) accents. Holding explosive projectiles. Volatile and dangerous. Transparent background, game enemy sprite.

### 5.4 弹幕精灵 — 6种

**尺寸：** 16×16  
**代码位置：** `asset_paths.gd` → `PROJECTILE_*`

**火焰弹 — `projectile_fire_16.png`：**
> A fire projectile sprite for Chinese xianxia game, 16x16 pixels. A small blazing fireball in orange-red (#FF6B35) with golden core and flame trail. Transparent background, game projectile sprite.

**雷击弹 — `projectile_thunder_16.png`：**
> A thunder projectile sprite for Chinese xianxia game, 16x16 pixels. A small lightning bolt in bright golden (#FFD700) with electric sparks. Transparent background, game projectile sprite.

**冰弹 — `projectile_ice_16.png`：**
> An ice projectile sprite for Chinese xianxia game, 16x16 pixels. A small ice crystal in teal-cyan (#4ECDC4) with frost shimmer. Transparent background, game projectile sprite.

**水弹 — `projectile_water_16.png`：**
> A water projectile sprite for Chinese xianxia game, 16x16 pixels. A small water droplet in blue-cyan (#4ECDC4) with aquatic glow. Transparent background, game projectile sprite.

**混沌弹 — `projectile_chaos_16.png`：**
> A chaos projectile sprite for Chinese xianxia game, 16x16 pixels. A small void orb in purple (#B57EDC) with swirling energy. Transparent background, game projectile sprite.

**通用弹 — `projectile_generic_16.png`：**
> A generic energy projectile sprite for Chinese xianxia game, 16x16 pixels. A small golden (#FFD700) energy orb with soft glow. Neutral and versatile. Transparent background, game projectile sprite.

---

## 第六部分：遗漏资产补充（交叉比对后发现）

### 6.1 敌人头顶血条（世界空间）

**文件名：** `enemy_hp_bar_9slice.png`  
**尺寸：** 56×12（九宫格）  
**代码位置：** `world_enemy_health_bar.tscn`  
**说明：** 当前用纯 StyleBoxFlat 占位，文档 §8 建议后续增加 PNG

**提示词：**
> A thin enemy health bar for Chinese xianxia game UI, 56x12 pixels, nine-patch compatible. A slim horizontal bar with a dark semi-transparent background and a crimson-red (#E85D5D) fill. Subtle inner glow on the fill. Minimal decoration — designed to float above enemy heads in combat. No text, game UI health bar asset.

### 6.2 机缘选择卡大型元素图标（64-80px）

**说明：** 图2（机缘三选一）中每张卡顶部显示大型元素图标（雪花~80px、闪电~80px、火焰~80px），远大于 HUD 中的 32px 图标。当前代码 `affix_card.tscn` 使用 32px 图标但 TextureRect 会拉伸，为保证清晰度建议生成专用大图标。

**冰系大图标 — `elem_ice_large_80.png`：**
> A large ice/snow element icon for Chinese xianxia game choice card, 80x80 pixels. An intricate crystalline snowflake rendered in teal-cyan (#4ECDC4) and ice-blue with white highlights. The snowflake has six elaborate arms with fractal-like crystal branches. Subtle frost particles and cold mist surround the icon. Luminous inner glow. Transparent background, game UI element icon.

**雷系大图标 — `elem_thunder_large_80.png`：**
> A large thunder/lightning element icon for Chinese xianxia game choice card, 80x80 pixels. A dramatic golden (#FFD700) lightning bolt with branching electric arcs. White-hot core with golden energy trails. Electric spark particles scattered around. The bolt has an angular but elegant Chinese thunder-symbol design. Transparent background, game UI element icon.

**火系大图标 — `elem_fire_large_80.png`：**
> A large fire element icon for Chinese xianxia game choice card, 80x80 pixels. A blazing fire vortex rendered in orange-red (#FF6B35) with a bright golden (#FFD700) core. Elegant Chinese cloud-fire tendrils spiral outward. Ember particles float around the flame. Intense and powerful. Transparent background, game UI element icon.

### 6.3 道心选择页两侧对联装饰板

**文件名：** `couplet_panel_left.png` / `couplet_panel_right.png`  
**尺寸：** 48×240（竖长条）  
**代码位置：** `run_setup_panel.gd` → 动态生成的对联 Label 背景  
**说明：** 图1左右两侧显示"大道无形""仙途无尽"竖排文字，位于翡翠立柱上的金色装饰板内。当前可能仅用 Label 文字实现，但图中文字有独立的装饰底板。

**提示词（左侧）：**
> A vertical decorative couplet panel for Chinese xianxia game UI, 48x240 pixels. A narrow vertical jade-green (#1B4438) panel with golden (#FFD700) top and bottom caps featuring cloud-scroll filigree. The panel has a thin golden border and subtle jade texture. Designed to hold vertical Chinese calligraphy text. No text, transparent background, game UI decorative element.

**提示词（右侧）：**
> A vertical decorative couplet panel for Chinese xianxia game UI, 48x240 pixels. Mirror of the left panel — narrow vertical jade-green (#1B4438) panel with golden (#FFD700) top and bottom caps featuring cloud-scroll filigree. Thin golden border, subtle jade texture. No text, transparent background, game UI decorative element.

### 6.4 事件面板专用插画

**文件名：** `event_illustration_560x96.png`  
**尺寸：** 560×96  
**代码位置：** `event_panel.tscn` → `ArtBanner` TextureRect  
**说明：** 当前 `ArtBanner` 复用 `panel_ninepatch_256.png` 作为占位，文档 §5.6 要求 16:9 事件插画区。每种事件类型可有不同插画，初版可先做 1 张通用仙侠山水。

**提示词：**
> A wide panoramic illustration banner for Chinese xianxia random events, 560x96 pixels. A misty immortal landscape with layered mountain peaks, flowing clouds, and ancient pavilions. Deep jade-green and gold color palette. The scene shows a crossroads or mystical gateway among the mountains, suggesting choice and destiny. Ethereal and atmospheric. No text, no UI elements, game event illustration asset.

### 6.5 Boss 阶段顶栏横幅（金碧仙宫风格）

**文件名：** `boss_banner_640x80.png`  
**尺寸：** 640×80（九宫格）  
**代码位置：** `hud.gd` → `_on_room_entered()` Boss 房间标签；`top_announcement_overlay.tscn`  
**说明：** 当前 Boss 阶段用普通 Label，`top_announcement_overlay` 复用 `scroll_toast_520x72.png`。需专用横幅。

**提示词：**
> A boss encounter announcement banner for Chinese xianxia game UI, 640x80 pixels, nine-patch compatible. Deep jade-green (#0F2A22) background with an elaborate golden (#FFD700) double-line border. Ornate cloud-scroll filigree decorations at both ends, with a prominent jade-green (#4FD6B8) gemstone accent at the center. The top and bottom edges have subtle gold inner glow lines. The overall feel is ominous yet majestic — like a sacred arena announcement scroll unfurling. No text, game UI banner asset.

---

## 第七部分：功能性小图标（通用游戏 UI 风格，非金碧仙宫）

> **说明：** 以下为战斗/交互中的功能性小图标（因果指示、治疗、闪避、重随等），不属于地图背景或技能装饰框，**不使用金碧仙宫风格前缀**。采用通用扁平线性图标风格：1.5px 描边、圆角端点、透明背景、语义色填充。

### 7.1 因果（Karma）倾向色点 × 5

**尺寸：** 16×16  
**代码位置：** `event_panel.gd:36` — **所有事件选项硬编码使用 `elem_wood_32.png`** 作为图标  
**规范依据：** UIUX §5.6：「选项按钮最多 3 个，带 karma 倾向色点（善/恶/贪/逆）」  
**说明：** 游戏追踪 5 种因果值，当前完全缺失。

**善 — `karma_good_16.png`：**
> A tiny karma indicator dot "Good/善" for game UI, 16x16 pixels. A warm white jade ring with soft golden (#FFD700) inner glow. Pure, luminous, benevolent. Flat icon style, 1.5px stroke, rounded caps, transparent background. No text.

**恶 — `karma_evil_16.png`：**
> A tiny karma indicator dot "Evil/恶" for game UI, 16x16 pixels. A dark crimson (#C45C5C) blood-drop shape with subtle blackened edges. Sinister and weighty. Flat icon style, 1.5px stroke, transparent background. No text.

**贪 — `karma_greed_16.png`：**
> A tiny karma indicator dot "Greed/贪" for game UI, 16x16 pixels. A small cracked golden (#F59E0B) coin silhouette with sharp highlight lines. Materialistic and fractured. Flat icon style, 1.5px stroke, transparent background. No text.

**逆 — `karma_rebellion_16.png`：**
> A tiny karma indicator dot "Rebellion/逆" for game UI, 16x16 pixels. An upward-pointing dark purple (#B57EDC) sword-arrow silhouette. Defiant, sharp, rebellious energy. Flat icon style, 1.5px stroke, transparent background. No text.

**道心 — `karma_dao_heart_16.png`：**
> A tiny karma indicator dot "Dao Heart/道心" for game UI, 16x16 pixels. A miniature radiant golden (#FFD700) four-pointed star with fine cross-shaped light rays. Transcendent and pure. Flat icon style, transparent background. No text.

### 7.2 治疗/恢复图标

**文件名：** `icon_heal_32.png`  
**尺寸：** 32×32  
**代码位置：** `shop_panel.gd:73` — 当前用 `PROGRESS_HP`（HP 条的 64×16 九宫格纹理，完全不适合作为图标）作为治疗商品图标  
**说明：** 明显占位 hack，急需专用图标。

**提示词：**
> A healing/recovery icon for game UI, 32x32 pixels. A luminous teal-green (#4ECDC4) lotus flower or spirit herb silhouette with a gentle cross-shaped glow. Elegant and medicinal — suggesting vitality restoration. Flat icon style with subtle inner glow, 1.5px stroke, rounded caps, transparent background. No text.

### 7.3 闪避（御风步）图标

**文件名：** `icon_dodge_32.png`  
**尺寸：** 32×32  
**代码位置：** `hud.gd:61` — 仅在 HintLabel 文字中提及 "空格闪避"，无任何可视化指示  
**规范依据：** GDD §4：「WASD 移动，spacebar 闪避（invincibility frames）」

**提示词：**
> A dodge/dash ability icon for game UI, 32x32 pixels. A stylized afterimage or wind-trail figure in translucent teal (#4ECDC4) with horizontal motion blur lines and a slight upward arc. Suggests swift evasive movement. Clean silhouette, flat icon style, 1.5px stroke, transparent background. No text.

### 7.4 重随图标

**文件名：** `icon_reroll_24.png`  
**尺寸：** 24×24  
**代码位置：** `affix_choice_panel.gd` → `RerollButton` 纯文字 "重随 (N 灵石)"

**提示词：**
> A reroll icon for game UI, 24x24 pixels. A pair of stylized dice or circular refresh arrows in golden (#FFD700). Clean and simple — suggesting random chance and renewal. Flat icon style, 1.5px stroke, transparent background. No text.

### 7.5 跳过图标

**文件名：** `icon_skip_24.png`  
**尺寸：** 24×24  
**代码位置：** `affix_choice_panel.gd` → `SkipButton` 纯文字 "跳过 (+N 灵石)"

**提示词：**
> A skip/pass icon for game UI, 24x24 pixels. A rightward double-arrow or fast-forward symbol in muted gold (#C4B69C). Simple and unobtrusive — suggesting "move past without choosing". Flat icon style, 1.5px stroke, transparent background. No text.

### 7.6 已拥有角标（已备）

**文件名：** `badge_owned_32.png`  
**尺寸：** 32×32（角标，叠在卡片右上角）  
**代码位置：** `affix_card.gd` — 尚未实现  
**规范依据：** UIUX §5.2：「已拥有词条：卡片角标 '已备'」

**提示词：**
> A small "already owned" corner badge for game UI cards, 32x32 pixels. A triangular ribbon-shaped badge in muted gold (#F0D68A) with a subtle checkmark silhouette. Semi-transparent dark background behind the badge area. Designed to overlay the top-right corner of affix/talent cards. Flat style, transparent background except badge. No text.

### 7.7 心魔试炼激活指示器

**文件名：** `icon_heart_demon_trial_24.png`  
**尺寸：** 24×24  
**代码位置：** `hud.gd:302-319` — 试炼状态仅以纯文本在天气面板 `meta_label` 显示

**提示词：**
> A small heart demon trial active indicator for game UI, 24x24 pixels. A tiny crimson (#EF4444) demon eye or horned silhouette with a subtle dark purple (#B57EDC) outer glow. Compact danger marker — noticeable but not intrusive. Flat icon style, 1.5px stroke, transparent background. No text.

### 7.8 训练模式标识

**文件名：** `badge_training_48x16.png`  
**尺寸：** 48×16  
**代码位置：** `RunContext.training_mode` — 当前仅追加 "· 训练" 文字到种子 Label

**提示词：**
> A small "Training Mode" label badge for game UI, 48x16 pixels. A subtle rounded rectangle with a thin teal-green (#4ECDC4) border and semi-transparent dark fill. Clean and understated. Designed to sit inline in the HUD. Flat style, transparent background. No text.

---

## 资产总览表

| 序号 | 资产名 | 尺寸 | 页面 | 优先级 | 状态 |
|------|--------|------|------|--------|------|
| 1 | `bg_jade_palace_hall.png` | 1920×1080 | Setup/突破 | P0 | 已有，需重绘 |
| 2 | `panel_ninepatch_256.png` | 256×256 | 全局 | P0 | 已有，需重绘 |
| 3 | `dao_heart_card_frame.png` | 168×200 | Setup | P0 | **新增** |
| 4 | `dao_heart_ask_128.png` | 128×128 | Setup | P0 | 已有，需重绘 |
| 5 | `dao_heart_enlighten_128.png` | 128×128 | Setup | P0 | 已有，需重绘 |
| 6 | `dao_heart_prove_128.png` | 128×128 | Setup | P0 | 已有，需重绘 |
| 7 | `setup_title_ornament.png` | 640×48 | Setup | P2 | **新增** |
| 8 | `btn_primary_gold_360x48.png` | 360×48 | Setup | P1 | **新增** |
| 9 | `btn_secondary_360x40.png` | 360×40 | Setup | P1 | **新增** |
| 10 | `modal_title_bar_720x52.png` | 720×52 | 突破 | P0 | 已有，需重绘 |
| 11 | `divider_gold_256x2.png` | 256×2 | 突破 | P0 | 已有，需重绘 |
| 12 | `talent_scroll_210x200.png` | 210×200 | 突破 | P0 | 已有，需重绘 |
| 13 | `talent_scroll_210x200_highlight.png` | 210×200 | 突破 | P1 | **新增**（可选） |
| 14 | `quality_common_220x280.png` | 220×280 | 全局 | P0 | 已有，需重绘 |
| 15 | `quality_rare_220x280.png` | 220×280 | 全局 | P0 | 已有，需重绘 |
| 16 | `quality_epic_220x280.png` | 220×280 | 全局 | P0 | 已有，需重绘 |
| 17 | `quality_legendary_220x280.png` | 220×280 | 全局 | P0 | 已有，需重绘 |
| 18 | `quality_dao_220x280.png` | 220×280 | 全局 | P0 | 已有，需重绘 |
| 19 | `elem_fire_32.png` | 32×32 | 全局 | P0 | 已有，需重绘 |
| 20 | `elem_water_32.png` | 32×32 | 全局 | P0 | 已有，需重绘 |
| 21 | `elem_thunder_32.png` | 32×32 | 全局 | P0 | 已有，需重绘 |
| 22 | `elem_wood_32.png` | 32×32 | 全局 | P0 | 已有，需重绘 |
| 23 | `elem_earth_32.png` | 32×32 | 全局 | P0 | 已有，需重绘 |
| 24 | `elem_chaos_32.png` | 32×32 | 全局 | P0 | 已有，需重绘 |
| 25 | `tag_common.png` | 64×24 | 全局 | P2 | **新增**（可选） |
| 26 | `tag_rare.png` | 64×24 | 全局 | P2 | **新增**（可选） |
| 27 | `tag_epic.png` | 64×24 | 全局 | P2 | **新增**（可选） |
| 28 | `tag_ice.png` / `tag_thunder.png` / `tag_fire.png` | 80×20 | 突破 | P2 | **新增**（可选） |
| 29 | `hud_panel_bg_320x448.png` | 320×448 | HUD | P0 | 已有，需重绘 |
| 30 | `hud_weather_panel_280x120.png` | 280×120 | HUD | P0 | **新增** |
| 31 | `hud_spell_dock_frame.png` | 360×80 | HUD | P0 | **新增** |
| 32 | `progress_hp_9slice.png` | 64×16 | HUD | P0 | 已有，需重绘 |
| 33 | `progress_mana_9slice.png` | 64×16 | HUD | P0 | 已有，需重绘 |
| 34 | `icon_spirit_stone_32.png` | 32×32 | HUD | P0 | **新增** |
| 35 | `combo_track_256x8.png` | 256×8 | HUD | P1 | 已有，需重绘 |
| 36 | `weather_*_32.png` × 8 | 32×32 | HUD | P0 | 已有，需重绘 |
| 37 | `pet_avatar_ring_40.png` | 40×40 | HUD | P1 | 已有，需重绘 |
| 38 | `spell_q_fire_40.png` | 40×40 | HUD | P0 | 已有，需重绘 |
| 39 | `spell_e_thunder_40.png` | 40×40 | HUD | P0 | 已有，需重绘 |
| 40 | `spell_r_water_40.png` | 40×40 | HUD | P0 | 已有，需重绘 |
| 41 | `spell_*_locked_40.png` × 3 | 40×40 | HUD | P1 | 已有，需重绘 |
| 42 | `spell_slot_empty_40.png` | 40×40 | HUD | P1 | 已有，需重绘 |
| 43 | `spell_slot_locked_40.png` | 40×40 | HUD | P1 | 已有，需重绘 |
| 44 | `scroll_toast_520x72.png` | 520×72 | HUD | P0 | 已有，需重绘 |
| 45 | `path_*_48.png` × 5 | 48×48 | 全局 | P1 | 已有，需重绘 |
| 46 | `event_banner_640x160.png` | 640×160 | 事件 | P1 | 已有，需重绘 |
| 47 | `talent_icon_realm_1~5.png` | 48×48 | 突破 | P0 | **新增** |
| 48 | `breakthrough_bg_overlay.png` | 1920×1080 | 突破 | P2 | **新增**（可选） |
| 49 | `bt_slot_arrow_32.png` | 32×32 | 突破 | P2 | **新增**（可选） |
| 50 | `talent_badge_*.png` × 4 | 24×24 | 突破 | P2 | **新增**（可选） |
| 51 | `player_cultivator_64.png` | 64×64 | 战斗 | P0 | 已有，需重绘 |
| 52 | `pet_huo_ying_32.png` | 32×32 | 战斗 | P1 | 已有，需重绘 |
| 53 | `enemy_*_64.png` × 4 | 64×64 | 战斗 | P0 | 已有，需重绘 |
| 54 | `projectile_*_16.png` × 6 | 16×16 | 战斗 | P1 | 已有，需重绘 |
| 55 | `enemy_hp_bar_9slice.png` | 56×12 | 战斗 | P1 | **新增** |
| 56 | `elem_ice_large_80.png` | 80×80 | 机缘选择 | P0 | **新增** |
| 57 | `elem_thunder_large_80.png` | 80×80 | 机缘选择 | P0 | **新增** |
| 58 | `elem_fire_large_80.png` | 80×80 | 机缘选择 | P0 | **新增** |
| 59 | `couplet_panel_left.png` | 48×240 | Setup | P1 | **新增**（可选） |
| 60 | `couplet_panel_right.png` | 48×240 | Setup | P1 | **新增**（可选） |
| 61 | `event_illustration_560x96.png` | 560×96 | 事件 | P1 | **新增** |
| 62 | `boss_banner_640x80.png` | 640×80 | HUD/Boss | P1 | **新增** |
| 63 | `karma_good_16.png` | 16×16 | 事件 | P0 | **新增** |
| 64 | `karma_evil_16.png` | 16×16 | 事件 | P0 | **新增** |
| 65 | `karma_greed_16.png` | 16×16 | 事件 | P0 | **新增** |
| 66 | `karma_rebellion_16.png` | 16×16 | 事件 | P0 | **新增** |
| 67 | `karma_dao_heart_16.png` | 16×16 | 事件 | P0 | **新增** |
| 68 | `icon_heal_32.png` | 32×32 | 坊市 | P0 | **新增** |
| 69 | `icon_dodge_32.png` | 32×32 | HUD | P1 | **新增** |
| 70 | `icon_reroll_24.png` | 24×24 | 全局 | P1 | **新增** |
| 71 | `icon_skip_24.png` | 24×24 | 全局 | P1 | **新增** |
| 72 | `badge_owned_32.png` | 32×32 | 全局 | P1 | **新增** |
| 73 | `icon_heart_demon_trial_24.png` | 24×24 | HUD | P1 | **新增** |
| 74 | `badge_training_48x16.png` | 48×16 | HUD | P2 | **新增** |

**总计：** 74 个资产文件（含 32 个新增，42 个需重绘）

---

## 附录 A：与 `UI资产清单_道心与战斗HUD.md` 的交叉引用

| 主题 | 本文档（提示词） | 清单文档 |
|------|------------------|----------|
| 尺寸标注 | 1920×1080 **设计基准** | 1080p 锚点位置 + 逻辑尺寸 |
| 多分辨率 | **§0**（权威） | §9 验收提到 1280×720 抽查 |
| 代码路径 | 各资产「代码位置」 | §13 代码索引 |
| @2x / 4K | §0.2 仅高分辨率背景可选 | — |

**文档版本：** 2026-06-10 · 增补 §0 分辨率/纵横比/像素密度策略。
