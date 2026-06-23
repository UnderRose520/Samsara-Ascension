# 2D Asset Generation Tools

The current runtime map pipeline is `generate_runtime_maps.py`. Older scripts
such as `generate_2d_maps.py` are legacy placeholder generators and should not
be used for the new realm-art runtime path unless you intentionally want to
overwrite art with placeholders.

## Dependencies

```powershell
pip install pillow
```

## Visual Asset Coverage QA

Check runtime-critical UI, HUD, icon, sprite-frame, VFX-frame, `AssetPaths`,
and runtime map manifest coverage without touching gameplay code:

```powershell
python game/tools/qa_visual_asset_coverage.py
```

The script exits non-zero for missing or incorrectly sized required assets.
Pending optional coverage, such as fallback-backed talent icons or large
reward-card element icons, is reported as warnings.

## Runtime Map QA

Run the static manifest/atlas checks after changing map assets, terrain props,
or the runtime scene manifest:

```powershell
python game/tools/qa_runtime_map_assets.py
```

Run the Godot end-to-end generation sampler after changing `StageGenerator`,
`RoomLayoutGenerator`, weather/terrain weighting, safe zones, or arena scaling:

```powershell
.\Godot_v4.6.3-stable_win64.exe --headless --path game --scene res://tools/qa_runtime_map_generation.tscn
```

The sampler generates the real five-stage run plan across fixed seeds, rebuilds
combat-room layouts through `RoomLayoutGenerator`, checks weather-adjusted
terrain weights, obstacle/terrain bounds, safe-zone avoidance, boosted weather
terrain coverage, and writes `game/tools/runtime_map_generation_qa_report.txt`.

Run the 1920x1080 rendered combat integration screenshot QA after changing
runtime UI, HUD, map rendering, actor sprites, pets, weather, terrain, or VFX:

```powershell
python game/tools/qa_visual_integration_1920.py
```

This wrapper launches Godot in windowed rendering mode because `--headless`
uses the dummy renderer and cannot read a real viewport texture. It instances
the real `CombatFloor`, player, enemies, pet controller, projectiles, weather,
VFX, and HUD, then writes:

- `output/visual_qa/combat_visual_integration_1920.png`
- `output/visual_qa/combat_visual_integration_1920_report.txt`
- `tmp/qa_visual_integration_1920.log`

The wrapper exits non-zero if the report does not pass or the screenshot is not
exactly `1920x1080`.

Run the 1920x1080 rendered reward-card visual QA after changing affix offers,
reward card art, rarity particles, temptation/locked states, or large element
icons:

```powershell
python game/tools/qa_reward_cards_1920.py
```

This opens the real `AffixChoicePanel` over a rendered combat map and checks a
legendary card, a temptation card in second-confirm state, and a locked/gray
card. It writes:

- `output/visual_qa/reward_cards_1920.png`
- `output/visual_qa/reward_cards_1920_report.txt`
- `tmp/qa_reward_cards_1920.log`

Run the 1920x1080 rendered flow UI QA after changing run setup, event panels,
run result, menu backdrops, or modal styling:

```powershell
python game/tools/qa_flow_ui_1920.py
```

This captures the real run setup, event, and run result scenes separately and
checks their backdrops, panels, titles, body text, buttons, illustrations, and
PNG dimensions. It writes:

- `output/visual_qa/flow_run_setup_1920.png`
- `output/visual_qa/flow_event_panel_1920.png`
- `output/visual_qa/flow_run_result_1920.png`
- `output/visual_qa/flow_ui_1920_report.txt`
- `tmp/qa_flow_ui_1920.log`

## Gameplay Systems QA

Run the headless gameplay systems QA after changing event selection, hidden
chains, battle event director behavior, Boss phases, death summaries, or run
highlights:

```powershell
python game/tools/qa_gameplay_systems.py
```

This wrapper launches Godot headless and checks:

- `EventSelector.pick_event_id()` / `build_choices()` against `events.csv`
- `BattleEventDirector` weather opportunities and elite-room mutation triggers
- `HiddenChainDetector` first discovery, SaveManager persistence, chain effects,
  and RunContext highlight recording
- Boss HP phase gates, lockout damage clipping, phase feedback, and inheritance
  feedback on death
- cultivation path to weapon identity, player runtime weapon shape, enemy
  `weapon_id` readability labels, and Boss inheritance labels
- enemy projectile semantic routing from enemy weapon identity to projectile
  element/status, player hit status application, dodge suppression, semantic
  hit feedback, and `damage_dealt` source metadata
- `RunContext.build_death_summary()`, hidden-chain highlight priority, and
  weather-kill highlight behavior

It writes:

- `game/tools/gameplay_systems_qa_report.txt`
- `tmp/qa_gameplay_systems.log`

Run the real run-flow contract QA after changing `main.tscn`, `RunSetupPanel`,
`RunController`, reward/event/path panels, room advancement, or run settlement:

```powershell
python game/tools/qa_run_flow_contract.py
```

This wrapper launches Godot headless and instances the real `main.tscn`. It
starts a seeded run through `RunSetupPanel`, verifies `RunContext.begin_run()`
and `main.gd` create `World/RunController`, resolves the opening affix through
the real `AffixChoicePanel`, clears two combat rooms through `RunController`,
handles the weapon-mod branch when it appears, advances through reward/path
choice, resolves the first event room, and verifies `run_completed` reaches the
real result panel. It writes:

- `game/tools/run_flow_contract_qa_report.txt`
- `tmp/qa_run_flow_contract.log`

## Runtime Maps

Remote image generation through the SSSToken OpenAI-compatible endpoint:

```powershell
python game/tools/generate_runtime_maps.py --provider ssstoken --no-fallback
```

The tool reads the key from `SSSTOKEN_API_KEY` or `OPENAI_API_KEY`, uses
`gpt-image-2` by default, and writes:

- `game/assets/maps/runtime_scene_manifest.json`
- `game/assets/maps/<theme_id>/room_background.png`
- `game/assets/maps/<theme_id>/tileset.png`
- `game/assets/maps/<theme_id>/terrain_props.png`
- `game/assets/maps/<theme_id>/qa_runtime_preview.png`
- prompt files beside every visible generated asset

Offline/procedural fallback for smoke tests:

```powershell
python game/tools/generate_runtime_maps.py --provider procedural
```

## Runtime Integration

Godot loads map art through `runtime_scene_manifest.json`:

- `StageGenerator` copies manifest stage fields into stage/room definitions.
- Combat rooms receive seeded, larger randomized `arena` bounds and tile counts.
- `CombatFloor` swaps the background, tileset, and terrain prop atlas from the
  manifest.
- `RunController` and `TrainingArena` resize arena walls to match room bounds.

Seeded randomness flows through `RunContext.derive_rng_seed()` and
`RunRng.stage_room(...)`, so copying a run seed reproduces the room sizes,
layouts, terrain slots, and spawn-zone scaling.

After regenerating PNGs, open/import the Godot project so `.import` files are
refreshed before manual runtime testing.
