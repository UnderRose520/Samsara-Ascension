# 2D Asset Generation Tools

The current runtime map pipeline is `generate_runtime_maps.py`. Older scripts
such as `generate_2d_maps.py` are legacy placeholder generators and should not
be used for the new realm-art runtime path unless you intentionally want to
overwrite art with placeholders.

## Dependencies

```powershell
pip install pillow
```

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
