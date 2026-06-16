# Runtime Map Assets

These assets feed the Godot runtime map pipeline through
`res://assets/maps/runtime_scene_manifest.json`.

## Generation

Use the runtime generator, not the legacy placeholder script:

```powershell
python game/tools/generate_runtime_maps.py --provider ssstoken --no-fallback
```

The generator reads the image API key from `SSSTOKEN_API_KEY` or
`OPENAI_API_KEY`. Do not put API keys in this file, in command arguments, or in
committed scripts.

For offline validation only:

```powershell
python game/tools/generate_runtime_maps.py --provider procedural
```

## Runtime Contract

The game loads stage surfaces from `runtime_scene_manifest.json` first and only
falls back to `tileset_metadata.json` when the manifest is missing.

Runtime-rendered fields:

- `room_background`: full arena foundation background.
- `tileset`: 4-cell Godot atlas for floor, floor_alt, obstacle, decoration.
- `terrain_props`: 3x3 transparent terrain-detail atlas, sliced into 128px cells.
- `scenery_props`: manifest placements that reference `terrain_props`.
- Weather terrain pools: gameplay circles from `TerrainSystem`, visually dressed
  through the active stage `terrain_props` atlas when imported.
- `spawn_zones`, `safe_zones`, `no_spawn_zones`: room spawn policy.
- `arena`: world bounds, camera bounds, tile count, and tile size.

Metadata or QA-only fields, intentionally ignored by gameplay:

- `qa_preview`: flattened preview for humans; the runtime does not render it.
- `prompt_files`: source prompts for reproducible image generation.
- `tileset_metadata.json`: legacy/fallback theme index; runtime prefers the manifest.

## Theme Folders

Each theme folder should contain:

| File | Purpose |
| --- | --- |
| `room_background.png` | Foundation-only arena background. |
| `tileset.png` | Four 32px tile concepts after resizing to 128x128. |
| `terrain_props.png` | Transparent 3x3 low terrain detail atlas. |
| `qa_runtime_preview.png` | QA-only preview, not rendered at runtime. |
| `*.prompt.txt` | Image prompt metadata, not rendered at runtime. |

## Import Notes

- Godot must import new PNGs before `ResourceLoader.exists()` sees them.
- If `terrain_props.png` is absent from a stale manifest, scenery props fall back to
  the tileset atlas and lose the richer terrain-detail layer.
