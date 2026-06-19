# HUD UI 资产接入清单

更新时间：2026-06-19

## 生成范围

本批资产服务于“无框道痕 HUD”战斗界面，不承担布局框，不包含文字。文字、键位、冷却、数量等仍由 Godot UI 代码渲染。

生成方式：使用用户指定的 SSSToken `gpt-image-2` image2 接口。密钥只从环境变量读取，未写入仓库文件。

## 最终资产

目录：`game/assets/ui/hud/`

| 文件 | 尺寸 | 用途 |
| --- | ---: | --- |
| `pet_huo_ying_avatar_96.png` | 96x96 | 左侧灵宠入口 / Tooltip 高清源 |
| `pet_huo_ying_avatar_64.png` | 64x64 | 战斗 HUD 灵宠头像 |
| `artifact_xuanyu_gourd_pendant_96.png` | 96x96 | 左侧本命器悬坠高清源 |
| `artifact_xuanyu_gourd_pendant_64.png` | 64x64 | 战斗 HUD 本命器悬坠 |
| `weather_thunderstorm_charm_160x96.png` | 160x96 | 右上天象签装饰图标源 |
| `weather_thunderstorm_icon_64.png` | 64x64 | 右上雷暴天气小签图标 |
| `auto_seal_attack_64.png` | 64x64 | 底部 `攻` 自动普攻符灯 |
| `auto_seal_guard_64.png` | 64x64 | 底部 `护` 自动护体符灯 |
| `auto_seal_pet_64.png` | 64x64 | 底部 `宠` 灵宠协同符灯 |
| `auto_seal_artifact_64.png` | 64x64 | 底部 `器` 法宝/器灵符灯 |
| `affix_rune_fire_64.png` | 64x64 | 左侧词条符印：火 |
| `affix_rune_thunder_64.png` | 64x64 | 左侧词条符印：雷 |
| `affix_rune_water_64.png` | 64x64 | 左侧词条符印：水 |
| `affix_rune_wood_64.png` | 64x64 | 左侧词条符印：木/体 |
| `affix_rune_earth_64.png` | 64x64 | 左侧词条符印：土/契 |
| `affix_rune_seal_64.png` | 64x64 | 左侧词条符印：封印 |
| `hud_left_panel_frame_448x512.png` | 448x512 | 左上角战斗状态总览底板 |
| `hud_left_objective_card_384x112.png` | 384x112 | 左上角本关目标卡底图 |
| `hud_left_resource_track_384x32.png` | 384x32 | 气血 / 道势资源条底槽 |
| `hud_left_build_badge_320x40.png` | 320x40 | 道路 / 境界槽位徽章底图 |
| `hud_left_section_divider_320x24.png` | 320x24 | 修士分区细分隔线 |

预览图：`output/imagegen/hud_ui_assets/hud_ui_assets_contact_sheet.png`

左上角 HUD 预览图：`output/imagegen/left_hud_panel/left_hud_panel_contact_sheet.png`

Raw 备份：`output/imagegen/hud_ui_assets/raw/`

Prompt 备份：`output/imagegen/hud_ui_assets/prompts/`

## 接入建议

- 新增 `AssetPaths` 常量时建议挂在 `UI_ROOT + "hud/..."` 下，避免污染旧 `game/assets/ui/` 根目录。
- 灵宠头像只做状态入口，不显示 `V`；`V` 由底部 `宠` 符灯旁的临时键帽控制。
- 本命器悬坠放左侧成长区与底部主动区之间，展示 `玄玉葫 / 充能 / 器灵醒`，不与宠物头像合并。
- 天象签用 `weather_thunderstorm_icon_64.png` 加代码文字 `雷暴 / 积水 x3 / 借势`，不要使用大卡片。
- `auto_seal_*` 只作为符灯图标底，不直接替代中文短字；中文 `攻/护/宠/器` 用 Label 覆盖或旁置。
- `affix_rune_*` 建议显示 32-42px；64px 作为高清源，避免 1080p 缩放模糊。
- Godot 导入后检查 `.import` 是否生成；本批 PNG 均为透明背景，可用 `TextureRect` / `TextureButton`。
- 左上角 HUD 资产由 `tmp/generate_left_hud_panel_assets_image2.py` 管理。脚本会复用已有 image2 raw 做透明裁切和尺寸铺满；缺 raw 且无 `SSSTOKEN_API_KEY` 时保留现有同名成品。
- `hud_left_panel_frame_448x512.png`、`hud_left_objective_card_384x112.png`、`hud_left_resource_track_384x32.png`、`hud_left_build_badge_320x40.png` 已用 image2 单项生成并接入；`hud_left_section_divider_320x24.png` 当前保留本地 fallback 细线，因最后一次 image2 下载返回 502。
- 左上角 HUD 代码接入位置：`game/ui/components/hud_character_panel.tscn`、`game/ui/components/hud_character_panel.gd`、`game/ui/components/hud_resource_bar.tscn`、`game/ui/components/hud_resource_bar.gd`、`game/scenes/ui/hud.tscn`、`game/assets/asset_paths.gd`。

## 核心 Prompt 摘要

共同约束：

```text
transparent 2D game HUD UI asset for a Chinese xianxia cultivation roguelite;
hand-painted clean HD game icon, dark ink-jade, restrained cold gold,玄玉鎏金;
single centered asset, no text, no labels, no watermark;
perfectly flat solid #ff00ff chroma-key background for removal;
avoid rectangular card frame, thick UI box, sci-fi metal, beige paper scroll, purple-dominant palette.
```

单项主题：

- 火萤头像：橙金火萤灵宠，圆形玉珠感，能在 40-64px 读清。
- 玄玉葫悬坠：深色玉葫、冷金边、紫蓝器灵光、半环充能碎纹。
- 雷暴天象签：小型玉质罗盘/签牌，蓝白雷符与水滴，不含文字。
- 自动符灯：2x2 图集，攻击、护体、宠物协同、器灵触发四种中心符号。
- 词条符印：2x3 图集，火、雷、水、木、土、封印六种符印。
