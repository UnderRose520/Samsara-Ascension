# AGENTS.md

《轮回仙途》(Samsara Ascension) — a Godot 4.6 cultivation roguelite. See `CLAUDE.md` for design/architecture and `game/README.md` for gameplay/run details. The Godot project root is `game/`, not the repository root.

## Cursor Cloud specific instructions

### Engine / how to run
- Godot **4.6.3** is installed at `/usr/local/bin/godot` (on `PATH` as `godot`). The startup update script self-heals it if missing.
- Run the game (needs a display; `DISPLAY=:1` is available): `godot --path game`
- Logic-only / CI-style run without a window: `godot --headless --path game`
- First launch (or after pulling new assets) reimports assets; to pre-warm the import cache: `godot --headless --import` from `game/`. The cache lives in `game/.godot/` (git-ignored).

### Expected (non-error) startup warnings in this VM
- There is **no Vulkan GPU**, so the engine logs `Required extension VK_KHR_surface not found` and falls back to **OpenGL 3 (Mesa llvmpipe software rendering)**. This is normal here; the 2D game runs fine, just slower.
- There is no audio device, so audio falls back to the **dummy driver** (`All audio drivers failed`). Also normal.

### Testing / linting / building
- There is **no automated test suite, no lint config, and no CI** in this repo. "Testing" means launching the game and playing it manually. Don't expect `make test`, `npm`, etc.
- There is no committed `export_presets.cfg` (git-ignored); there is no checked-in export/build pipeline. Develop by running the project directly, not by exporting.

### Gameplay run caveats (for manual testing)
- The game boots `scenes/main/main.tscn` → a run-setup panel (pick Dao-heart → optional seed → `踏入轮回` to start) → combat (`魔劫涌潮` horde mode).
- Combat is punishing: enemies spawn next to the player, so an **idle player dies in ~1-2 seconds**. To test gameplay you must move continuously. For hands-off survivability, open the **Esc pause menu** and enable **自动瞄准 (auto-aim)** and **自动普攻 (auto-attack)** — these persist in the save and let the player auto-fight while you kite. Keys: WASD move, Space dodge, LMB attack, Q/E/R spells, V pet, K self-destruct, Esc pause.
- For scripted/manual UI input via `xdotool`, note the WM adds an ~84px title bar: window content origin is `(1,85)` after `xdotool windowmove <id> 0 0`. Keyboard input only reaches the player when the game window (not a focused `LineEdit` such as the seed field) has focus.

### Asset tooling gotcha
- `python game/tools/generate_2d_*.py` (needs Pillow) regenerate placeholder PNGs **in place over git-tracked files**, dirtying the working tree. Only run them if you intend to regenerate art, and do not commit the regenerated PNGs unless that is the goal.
