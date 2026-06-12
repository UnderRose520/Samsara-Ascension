# 2D 资产生成工具（generate2dmap / generate2dsprite）

对应 UIUX 规范 `docs/UIUX_轮回仙途_v1.0.md`，输出 Godot 4 可直接引用的 PNG。

## 依赖

```powershell
pip install pillow
```

## generate_2d_sprites.py（UI + 角色 + 技能图标）

```powershell
python game/tools/generate_2d_sprites.py
```

输出：

- `game/assets/ui/` — 面板、元素/天象/法术/品质/道心图标、进度条 9-slice
- `game/assets/sprites/` — 玩家、敌人、弹道、灵宠

## generate_2d_maps.py（关卡地板 + 背景）

```powershell
python game/tools/generate_2d_maps.py
```

输出：

- `game/assets/maps/<theme_id>/tileset.png` — 4×32px 图块
- `game/assets/maps/<theme_id>/room_background.png` — 1280×720 战斗背景
- `game/assets/maps/tileset_metadata.json` — 主题与 stage_index 映射

## Godot 集成

| 模块 | 路径 |
|------|------|
| 资源路径常量 | `game/assets/asset_paths.gd` |
| Design Token | `game/ui/theme/ui_tokens.gd` |
| 全局 Theme | `game/ui/theme/samsara_theme.tres` |
| 战斗地板 | `game/scenes/rooms/combat_floor.tscn` |
| 词条卡组件 | `game/ui/components/affix_card.tscn` |
| 精灵占位脚本 | `game/scenes/visual/sprite_visual.gd` |

## Godot MCP

1. 用 Godot 4.6 打开 `game/` 项目
2. 启用插件 **Godot MCP**（已写入 `project.godot`）
3. 编辑器底部 MCP 面板启动服务（默认 `127.0.0.1:3000`）
4. 在 Cursor 或外部 MCP 客户端连接后，可用 `resource/manage` 导入、`scene/*` 编辑场景

重新生成 PNG 后，在 Godot 中 **Project → Reload Current Project** 或 MCP `resource/reload` 刷新资源。
