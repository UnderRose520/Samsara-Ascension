#!/usr/bin/env python3
"""Generate unified image2 assets and wire them into runtime paths.

The script intentionally reads API credentials only from environment variables.
Do not put API keys in this file, prompt files, logs, or command arguments.
"""

from __future__ import annotations

import argparse
import base64
import io
import json
import os
import shutil
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[2]
GAME_ROOT = ROOT / "game"
UI_ROOT = GAME_ROOT / "assets" / "ui"
HUD_ROOT = UI_ROOT / "hud"
CARD_ROOT = UI_ROOT / "cards"
SPRITE_ROOT = GAME_ROOT / "assets" / "sprites"
FRAME_ROOT = SPRITE_ROOT / "frames"
FX_ROOT = SPRITE_ROOT / "fx"
MAP_ROOT = GAME_ROOT / "assets" / "maps"
RAW_ROOT = ROOT / "output" / "imagegen" / "unified_ink_image2"

ENDPOINT = "https://api.ssstoken.net/v1/images/generations"
MODEL = "gpt-image-2"
MAGENTA = (255, 0, 255)
TERRAIN_PROP_CELL = 128
TERRAIN_PROP_GRID = 3
TERRAIN_PROP_SIZE = TERRAIN_PROP_CELL * TERRAIN_PROP_GRID
TERRAIN_PROP_MAX_COVERAGE = 0.42

PALETTE_ACCENTS = {
    "qi_refining_verdant": ((99, 226, 162), (210, 177, 92)),
    "foundation_cavern": ((88, 214, 224), (166, 214, 186)),
    "golden_core_demon": ((238, 93, 70), (169, 84, 210)),
    "nascent_soul_ruins": ((216, 181, 96), (124, 180, 224)),
    "tribulation_thunder": ((116, 184, 255), (218, 190, 98)),
}

STYLE_BASE = """
Unified art direction for Samsara Ascension, a 2D dark Chinese xianxia cultivation roguelite.
Visual language: dark ink wash, black jade base, cold jade rim light, restrained old-gold ritual linework.
Five-element color is high saturation only on gameplay signal parts: fire orange-red, water cyan-blue, thunder blue-white, wood jade-green, earth old-gold, soul violet.
No western fantasy, no Diablo-like item render, no gothic castle, no European armor, no photorealism, no beige parchment dominance, no UI text, no letters, no labels, no watermark.
""".strip()

COHESION_RULES = """
Cohesion hard rules: every asset must feel from the same dark Chinese ink xianxia roguelite.
Palette: black jade and deep ink-teal base, cold jade rim light, restrained old-gold ritual linework.
Five-element saturated color appears only on gameplay signal parts, never as a full-body wash or full-background glow.
Avoid stickers, emoji, circular avatar badges, inventory loot lighting, purple-only palettes, western fantasy, gothic castle shapes, European armor, Diablo-like item render, anime portrait crop, photorealism, beige parchment dominance, UI text, labels, and watermark.
""".strip()

ACTOR_COHESION_RULES = """
Actor runtime rules: transparent-source sprite on perfectly flat #FF00FF background only.
3/4 top-down full body, compact readable silhouette, visible head-torso-feet or exact creature body shape.
Subject fills the central 58-66 percent with generous padding; no portrait crop, no circular avatar, no badge frame, no HP ring, no status icon, no baked shadow circle.
Use dark ink body mass plus one restrained jade, old-gold, or elemental accent marking the threat part only.
64px test: recognizable as this exact role as a black silhouette plus one accent color.
For chibi: same combat identity in compact proportions, not cute mascot, not giant-head sticker.
""".strip()

ICON_COHESION_RULES = """
Icon runtime rules: transparent-source atlas on flat #FF00FF background.
One centered emblem per cell, circular jade-seal or talisman language, readable at 48px and 96px.
No square inventory panel, no item-card background, no thick metal frame, no 3D object lighting.
No readable Chinese characters, letters, labels, or decorative text strokes.
Each spell, status, weather, pet, and artifact icon must have a distinct silhouette before color is considered.
Element color stays inside the emblem core; old-gold rim and dark-jade base stay consistent across all icons.
""".strip()

MAP_COHESION_RULES = """
Map runtime rules: exact overhead top-down 2D game ground, no horizon, no walls pretending to be arena borders.
Playable center 70-75 percent must remain matte, low-noise, low-contrast dark ink-stone.
All cracks, sigils, fog, veins, ruins, lamps, water highlights, and story detail stay in the outer 20 percent.
No central magic circle, target ring, door, chest, pillar, tree canopy, tall prop, character, projectile, UI, text, or collidable-looking object baked into the background.
Tileset source: top row exactly four swatches only: floor, floor_alt, blocker, decoration; lower 75 percent must be plain filler with no extra tile concepts.
Terrain props: flat low ground details only, centered per cell, no tall rocks, walls, pillars, or trees.
""".strip()

UI_COHESION_RULES = """
UI backdrop rules: 16:9 Chinese xianxia ink backdrop with central 55-65 percent dark negative space for panels.
Architecture, lamps, wheels, pools, clouds, and glow must frame side and top edges, not sit behind text panels.
Use Chinese ritual roofs, jade shrines, bronze lamps, and ink mist; no sharp cathedral spires, castle towers, gothic arches, or giant black triangular silhouettes.
No characters, monsters, readable text, labels, UI buttons, or central emblem competing with the actual interface.
""".strip()

CHROMA_RULE = """
Transparent-source rule: render the subject on a perfectly flat solid #FF00FF chroma-key background.
The background must be one uniform color with no shadows, gradients, texture, reflection, floor plane, or lighting variation.
Do not use #FF00FF inside the subject. Keep the subject fully inside the canvas with generous padding.
""".strip()

MAP_RULE = """
Runtime map rule: foundation-only top-down battle background for a survivors-like roguelite.
Design for a 1920x1080 16:9 top-down game screen; keep the playable center readable after downscaling.
The central 70-75 percent is clean playable ground: flat, low-contrast, matte dark ink-stone, no bright veins, no circles, no sigils, no cracks, no fog patches, no visual hazards.
All story detail, glow, mist, cracks, ritual marks, ruins, water highlights, and atmosphere must stay in the outer 20 percent border.
No characters, enemies, pets, bosses, weapons, projectiles, UI, text, labels, doors, chests, pickups, tall props, buildings, castle walls, gothic ruins, European battlements, tree canopies, forest walls, or large collidable-looking objects.
Camera: exact overhead/top-down 2D game background, no horizon, no portrait composition, no huge central target marker.
""".strip()

TILESET_RULE = """
Runtime tileset rule: source for a Godot TileSet atlas that will be resized to 128x128 and sliced as four 32x32 cells across the top row.
The top row must contain exactly four separated tile concepts from left to right: 1 floor, 2 floor_alt, 3 obstacle/blocker, 4 decoration.
Place these as four large square swatches across the upper 25 percent of the 1024x1024 canvas, each swatch occupying one 256x256 top-row slot.
The remaining lower 75 percent must stay visually simple dark filler and must not introduce extra tile concepts.
No visible grid lines, labels, text, UI, characters, weapons, projectiles, full room composition, or extra rows of props.
""".strip()

TERRAIN_PROPS_RULE = """
Runtime terrain prop rule: transparent-source 3x3 prop sheet, resized to 384x384 and sliced into nine 128x128 cells.
Use solid #FF00FF as the entire background for chroma-key cleanup. Do not use #FF00FF inside props.
Each cell contains one compact low terrain-detail prop, centered with generous padding and no edge touching.
These are flat non-colliding terrain details: veins, moss, stains, low debris, scars, shallow puddle rims, dust, aura residue.
No tall props, large rocks, walls, pillars, trees, crates, chests, doors, UI, labels, characters, weapons, projectiles, or full backgrounds.
""".strip()


STAGE_PROMPTS = {
    "qi_refining_verdant": {
        "label": "炼气翠林",
        "theme": "ink-jade qi refining field, rain-dark stone, sparse edge-weighted low moss stains painted into the ground, very faint wood-element jade veins near border only, clean Chinese brush texture",
        "accent": "jade green and pale cyan only in thin embedded qi traces",
        "tiles": "rain-dark ink stone, sparse moss, low jade qi stains, no forest walls",
        "props": "moss tufts, thin jade qi veins, low wet stone chips, small spirit grass stains",
    },
    "foundation_cavern": {
        "label": "筑基灵窟",
        "theme": "wet black-jade foundation cavern floor, smooth worn stone, very subtle wet sheen only near outer edges, center dry-looking and matte, mineral veins like Chinese ink brush cracks only at border",
        "accent": "cold cyan water and muted jade mineral glow",
        "tiles": "wet black jade cave stone, muted mineral vein, shallow edge sheen, matte center",
        "props": "thin mineral veins, shallow wet stains, low stone chips, muted cyan water residue",
    },
    "golden_core_demon": {
        "label": "金丹魔域",
        "theme": "golden-core demon domain ground, black-violet ink scars, restrained ember fissures only as thin edge accents, ash-stained ritual stone, no ember cracks inside playable center",
        "accent": "small orange-red fire cracks and faint soul violet smoke at edges",
        "tiles": "ash-stained black violet stone, restrained ember scar, old-gold ritual dust",
        "props": "thin ember scars, ash swirls, low demon stone chips, faint violet residue",
    },
    "nascent_soul_ruins": {
        "label": "元婴遗墟",
        "theme": "nascent-soul Chinese ruin floor, moonlit blue-gray worn stone, fragmented broken formation traces as edge ornaments, never a central magic circle",
        "accent": "aged cold-gold linework and very pale blue mist near edges",
        "tiles": "moonlit blue-gray worn ruin stone, fragmented cold-gold formation marks",
        "props": "broken low slab fragments, gold trace shards, pale blue dust stains, flat ruin glyph chips",
    },
    "tribulation_thunder": {
        "label": "天劫雷台",
        "theme": "heavenly tribulation thunder ground, storm-dark black stone, wet slate, top-down Chinese ink battle floor, no raised arena, no central platform outline, no target-like circle",
        "accent": "thin blue-white thunder veins and restrained old-gold scars around the outer ground",
        "tiles": "storm-dark wet slate, thin thunder vein, old-gold scorch scar, no arena ring",
        "props": "thin lightning traces, low thunder slate chips, wet scorch marks, small old-gold cracks",
    },
}


@dataclass(frozen=True)
class ActorJob:
    key: str
    slug: str
    size: str
    prompt_subject: str
    accent: str
    outputs: tuple[tuple[str, int], ...]
    frame_slug: str
    frame_size: int


ACTOR_JOBS = [
    ActorJob(
        "player_normal",
        "player_style_normal",
        "1024x1024",
        "jade-robed sword cultivator, compact heroic full body, flowing robe kept close to silhouette, small jade sword, clear head-body-feet shape, elegant Chinese cultivation outfit",
        "cold jade and old-gold meridian glow",
        (("player_style_normal_64.png", 64), ("player_style_normal_128.png", 128), ("player_cultivator_64.png", 64)),
        "player_style_normal",
        64,
    ),
    ActorJob(
        "player_chibi",
        "player_style_chibi",
        "1024x1024",
        "compact chibi jade-robed cultivator version of the hero, cute but still battle-readable, oversized head, short body, tiny jade sword, same jade and old-gold palette",
        "cold jade and old-gold meridian glow",
        (("player_style_chibi_64.png", 64), ("player_style_chibi_128.png", 128)),
        "player_style_chibi",
        64,
    ),
    ActorJob(
        "pet_huo_ying",
        "pet_huo_ying",
        "1024x1024",
        "small firefly spirit pet named Huo Ying, round ember core, translucent jade wings, friendly companion silhouette, not a western fairy, no human face",
        "fire orange core with jade wing glow",
        (("pet_huo_ying_32.png", 32),),
        "pet_huo_ying",
        32,
    ),
    ActorJob(
        "boss_thunder_normal",
        "enemy_thunder_elite_ingame",
        "1024x1024",
        "thunder tribulation guardian boss, imposing Chinese ritual armor silhouette, blue-white thunder crown, old-gold talisman plates, no European plate armor, no demon horns as western devil",
        "blue-white thunder and cold gold",
        (("enemy_thunder_elite_ingame_64.png", 64), ("enemy_thunder_elite_ingame_128.png", 128)),
        "enemy_thunder_elite_ingame",
        64,
    ),
    ActorJob(
        "boss_thunder_chibi",
        "enemy_thunder_elite_chibi",
        "1024x1024",
        "chibi thunder tribulation guardian boss, large ritual crown, compact body, blue-white thunder eye glow, old-gold talisman plates, cute but threatening",
        "blue-white thunder and cold gold",
        (("enemy_thunder_elite_chibi_64.png", 64), ("enemy_thunder_elite_chibi_128.png", 128)),
        "enemy_thunder_elite_chibi",
        64,
    ),
    ActorJob(
        "enemy_wild_wolf",
        "enemy_wild_wolf",
        "1024x1024",
        "low crouching yao wolf, four-legged, pointed ears, arched back, short tail, tiny forehead talisman scar, ink-brush fur tufts, claw and fang threat parts, readable at 64px",
        "wood jade-green claw traces",
        (("enemy_wild_wolf_64.png", 64),),
        "enemy_wild_wolf",
        64,
    ),
    ActorJob(
        "enemy_crossbow_cultivator",
        "enemy_crossbow_cultivator",
        "1024x1024",
        "lean rogue cultivator with straw hat, masked lower face, tattered rogue talisman belt, horizontal cloud crossbow, crooked half-crouched ranged stance, dark robe, not player-like",
        "blue-white thunder on crossbow limbs",
        (("enemy_crossbow_cultivator_64.png", 64),),
        "enemy_crossbow_cultivator",
        64,
    ),
    ActorJob(
        "enemy_shield_guard",
        "enemy_shield_guard",
        "1024x1024",
        "heavy formation guard with huge basalt xuanwu tortoise-shell formation shield covering front, short sturdy legs, guardian stance, shield occupies most of silhouette",
        "earth old-gold shield core with jade ward line",
        (("enemy_shield_guard_64.png", 64),),
        "enemy_shield_guard",
        64,
    ),
    ActorJob(
        "enemy_sky_bat",
        "enemy_sky_bat",
        "1024x1024",
        "corrupted sky bat yao, small body with wide torn wings shaped like Chinese ink brush strokes, sharp ears, glowing mouth projectile core, flying ranged harassment silhouette",
        "soul violet with blue thunder wing edges",
        (("enemy_sky_bat_64.png", 64),),
        "enemy_sky_bat",
        64,
    ),
    ActorJob(
        "enemy_mud_serpent",
        "enemy_mud_serpent",
        "1024x1024",
        "low S-shaped mud serpent, broad flat head, wet clay ridges, poison-mud mouth, body thick enough to read at 64px, not dragon",
        "earth old-gold clay ridges with very small cyan wet mouth glint",
        (("enemy_mud_serpent_64.png", 64),),
        "enemy_mud_serpent",
        64,
    ),
    ActorJob(
        "enemy_wind_mantis",
        "enemy_wind_mantis",
        "1024x1024",
        "tall forward-leaning mantis yao, oversized sickle arms, triangular head, slim body, fast slasher silhouette, no mech parts",
        "wood jade body with cyan wind blade edges",
        (("enemy_wind_mantis_64.png", 64),),
        "enemy_wind_mantis",
        64,
    ),
    ActorJob(
        "enemy_furnace_golem",
        "enemy_furnace_golem",
        "1024x1024",
        "stocky walking Chinese alchemy furnace spirit, round tripod kiln body, short stone arms, ember core in belly, old furnace yao silhouette, not western lava giant",
        "fire orange ember core with old-gold furnace lines",
        (("enemy_furnace_golem_64.png", 64),),
        "enemy_furnace_golem",
        64,
    ),
    ActorJob(
        "enemy_wild_wolf_chibi",
        "enemy_wild_wolf_chibi",
        "1024x1024",
        "compact chibi yao wolf version of wild_wolf, four-legged pounce silhouette, oversized ears and forehead talisman scar, short body, claw and fang threat parts still readable at 64px",
        "wood jade-green claw traces",
        (("enemy_wild_wolf_chibi_64.png", 64),),
        "enemy_wild_wolf_chibi",
        64,
    ),
    ActorJob(
        "enemy_crossbow_cultivator_chibi",
        "enemy_crossbow_cultivator_chibi",
        "1024x1024",
        "compact chibi rogue crossbow cultivator, large straw hat, masked face, short dark robe, horizontal cloud crossbow kept close to body, clearly a ranged enemy not the player",
        "blue-white thunder on crossbow limbs",
        (("enemy_crossbow_cultivator_chibi_64.png", 64),),
        "enemy_crossbow_cultivator_chibi",
        64,
    ),
    ActorJob(
        "enemy_shield_guard_chibi",
        "enemy_shield_guard_chibi",
        "1024x1024",
        "compact chibi formation shield guard, short sturdy body mostly hidden behind huge basalt xuanwu formation shield, guardian stance, shield identity dominant at 64px",
        "earth old-gold shield core with jade ward line",
        (("enemy_shield_guard_chibi_64.png", 64),),
        "enemy_shield_guard_chibi",
        64,
    ),
    ActorJob(
        "enemy_sky_bat_chibi",
        "enemy_sky_bat_chibi",
        "1024x1024",
        "compact chibi corrupted sky bat yao, small round body, oversized torn ink-brush wings, sharp ears, tiny glowing mouth projectile core, flying harassment silhouette",
        "soul violet with blue thunder wing edges",
        (("enemy_sky_bat_chibi_64.png", 64),),
        "enemy_sky_bat_chibi",
        64,
    ),
    ActorJob(
        "enemy_mud_serpent_chibi",
        "enemy_mud_serpent_chibi",
        "1024x1024",
        "compact chibi mud serpent, low thick S-shaped body, broad flat head, wet clay ridges, poison-mud mouth cue, cute proportions but still hostile and not dragon-like",
        "earth old-gold clay ridges with very small cyan wet mouth glint",
        (("enemy_mud_serpent_chibi_64.png", 64),),
        "enemy_mud_serpent_chibi",
        64,
    ),
    ActorJob(
        "enemy_wind_mantis_chibi",
        "enemy_wind_mantis_chibi",
        "1024x1024",
        "compact chibi wind mantis yao, triangular head, short body, oversized twin sickle arms, forward-leaning fast slasher silhouette, no mech parts",
        "wood jade body with cyan wind blade edges",
        (("enemy_wind_mantis_chibi_64.png", 64),),
        "enemy_wind_mantis_chibi",
        64,
    ),
    ActorJob(
        "enemy_furnace_golem_chibi",
        "enemy_furnace_golem_chibi",
        "1024x1024",
        "compact chibi Chinese alchemy furnace golem, round tripod kiln body, tiny stone arms and feet, ember core in belly, old furnace spirit silhouette not western lava giant",
        "fire orange ember core with old-gold furnace lines",
        (("enemy_furnace_golem_chibi_64.png", 64),),
        "enemy_furnace_golem_chibi",
        64,
    ),
]

ACTOR_ALIAS_COPY = {
    "enemy_wild_wolf": ["enemy_style_normal_melee", "enemy_style_chibi_melee", "enemy_berserker"],
    "enemy_crossbow_cultivator": ["enemy_style_normal_ranged", "enemy_style_chibi_ranged", "enemy_archer", "enemy_bomber"],
    "enemy_shield_guard": ["enemy_style_normal_elite", "enemy_style_chibi_elite", "enemy_training_dummy"],
}

ACTOR_ALIAS_SOURCES = {
    "enemy_style_normal_melee": "enemy_wild_wolf",
    "enemy_style_chibi_melee": "enemy_wild_wolf",
    "enemy_berserker": "enemy_wild_wolf",
    "enemy_style_normal_ranged": "enemy_crossbow_cultivator",
    "enemy_style_chibi_ranged": "enemy_crossbow_cultivator",
    "enemy_archer": "enemy_crossbow_cultivator",
    "enemy_bomber": "enemy_crossbow_cultivator",
    "enemy_style_normal_elite": "enemy_shield_guard",
    "enemy_style_chibi_elite": "enemy_shield_guard",
    "enemy_training_dummy": "enemy_shield_guard",
}

ACTOR_PROMPT_DETAILS = {
    "player_normal": {
        "silhouette": "upright compact hero, robe sleeves kept close, clear head torso feet, small sword close to body",
        "signal": "jade meridian glow on sword guard and shoulder talisman, not on the whole body",
        "motion": "idle breath, short step, sword-ready combat pulse; no huge slash arc baked into the body",
        "avoid": "generic wuxia NPC, western wizard robe, oversized sword, long cape, portrait crop",
    },
    "player_chibi": {
        "silhouette": "same hero identity in compact chibi proportions, large head and tiny sword but battle-readable",
        "signal": "small jade-gold dots on sword, forehead charm, and robe hem",
        "motion": "cute breathing bounce and sword-ready pulse; keep feet anchor stable",
        "avoid": "mascot animal, school anime outfit, big decorative halo, western wizard hat",
    },
    "pet_huo_ying": {
        "silhouette": "tiny round ember core, two translucent jade wings, short flame tail, friendly companion sprite",
        "signal": "orange-red ember center with jade wing rim only",
        "motion": "hovering firefly bob, wing shimmer, tiny combat spark",
        "avoid": "human fairy, butterfly with body details, western familiar, smoky unreadable blob",
    },
    "boss_thunder_normal": {
        "silhouette": "imposing Chinese tribulation guardian, ritual crown, broad shoulders, talisman plates, compact boss stance",
        "signal": "blue-white thunder crown and weapon-hand danger cue, old-gold talisman seams",
        "motion": "slow authority idle, heavy step, thunder pressure combat pulse",
        "avoid": "European plate knight, Diablo demon, horned devil, skull armor, gothic paladin",
    },
    "boss_thunder_chibi": {
        "silhouette": "chibi thunder guardian boss, oversized ritual crown, square compact body, stern glowing eyes",
        "signal": "blue-white thunder eye and crown sparks, old-gold talisman seams",
        "motion": "weighty bounce, short stomp, thunder pulse",
        "avoid": "cute toy robot, western knight, horned devil, giant floating halo",
    },
    "enemy_wild_wolf": {
        "silhouette": "low quadruped yao wolf, pointed ears, arched back, claw-forward pounce shape, short readable tail, forehead talisman scar",
        "signal": "cyan-jade eyes, fang mark, and claw tips only; a few wood-wind particles near paws",
        "motion": "crouch breath, low run, bite and claw lunge",
        "avoid": "snow wolf, giant boss wolf, realistic fur photo, long flowing tail that shrinks the body",
    },
    "enemy_crossbow_cultivator": {
        "silhouette": "lean crooked rogue cultivator, straw hat, masked lower face, tattered talisman belt, horizontal cloud crossbow forming a clear ranged line",
        "signal": "blue-white thunder on crossbow string and bolt tip, robe stays dark ink",
        "motion": "side-step guard, draw string, compact recoil shot",
        "avoid": "heroic player look, bow instead of crossbow, rifle, European hunter, bright armor",
    },
    "enemy_shield_guard": {
        "silhouette": "heavy formation guard, short sturdy legs, huge basalt xuanwu tortoise-shell or rectangular-rounded Chinese formation shield covering at least 40 percent of front silhouette",
        "signal": "old-gold earth sigil at shield center and thin jade ward edge",
        "motion": "shield breath, heavy step, shield bash and ward pulse",
        "avoid": "kite shield, European knight shield, holy paladin, overexposed gold, cute round mascot",
    },
    "enemy_sky_bat": {
        "silhouette": "small corrupted sky bat yao, wide torn wings shaped like Chinese ink brush strokes, sharp ears, tiny glowing mouth core",
        "signal": "soul violet mouth core and blue-purple thunder flecks on wing edges",
        "motion": "hover flap, diagonal flight tilt, mouth projectile charge",
        "avoid": "skull face, leathery vampire monster, photoreal bat, huge cropped wings, black silhouette with no rim, vampire cape",
    },
    "enemy_mud_serpent": {
        "silhouette": "low S-shaped mud serpent, broad flat head, thick readable body, wet clay ridges, not dragon-like",
        "signal": "old-gold clay ridge marks with only a very small cyan wet mouth glint",
        "motion": "tongue flick idle, S-slide, mud spit windup",
        "avoid": "Chinese dragon, thin ordinary snake line, bright green poison, large mud puddle hiding body",
    },
    "enemy_wind_mantis": {
        "silhouette": "tall forward-leaning mantis yao, triangular head, huge twin sickle arms, slim fast slasher body",
        "signal": "cyan wind blade glow hugs the sickle arms and jade-green shell joints only",
        "motion": "sickle open-close idle, quick skitter, crossed slash",
        "avoid": "mecha insect, huge wings, western alien bug, detached crescent slash, long wind trails outside the body",
    },
    "enemy_furnace_golem": {
        "silhouette": "stocky walking Chinese alchemy furnace spirit, round tripod kiln body, short stone arms, ember core in belly",
        "signal": "saturated orange-red furnace cracks and old-gold Chinese furnace linework",
        "motion": "furnace fire breath, heavy wobble step, heat-up slam or flame spit",
        "avoid": "western lava giant, generic stone golem without furnace identity, full white-hot flames, boss scale",
    },
    "enemy_wild_wolf_chibi": {
        "silhouette": "same wild wolf identity in compact chibi quadruped proportions, oversized ears, arched pounce back, short readable tail, forehead talisman scar",
        "signal": "cyan-jade eyes and claw tips only; keep wood-wind particles tight to paws",
        "motion": "tiny crouch bounce, low scamper, bite and claw lunge",
        "avoid": "cute pet dog, round mascot, snow wolf, realistic fur photo, giant boss wolf",
    },
    "enemy_crossbow_cultivator_chibi": {
        "silhouette": "same rogue cultivator identity in compact chibi proportions, big straw hat, masked face, horizontal cloud crossbow as the main shape",
        "signal": "blue-white thunder on the crossbow string and bolt tip only",
        "motion": "short side-step guard, draw string, compact recoil shot",
        "avoid": "hero player chibi, bow instead of crossbow, rifle, European hunter, oversized detached bolt",
    },
    "enemy_shield_guard_chibi": {
        "silhouette": "same guard identity in compact chibi proportions, tiny legs and body behind a huge basalt xuanwu shield",
        "signal": "old-gold earth sigil at shield center and thin jade ward edge",
        "motion": "shield breath, heavy hop step, shield bash and ward pulse",
        "avoid": "European knight, kite shield, toy mascot, overexposed gold, round emoji shield",
    },
    "enemy_sky_bat_chibi": {
        "silhouette": "same sky bat identity in compact chibi proportions, tiny body with oversized torn ink-brush wings and sharp ears",
        "signal": "soul violet mouth core and blue-purple wing-edge flecks",
        "motion": "hover flap, small diagonal tilt, mouth projectile charge",
        "avoid": "vampire cape, skull face, photoreal bat, wings cropped by canvas edge",
    },
    "enemy_mud_serpent_chibi": {
        "silhouette": "same mud serpent identity in compact chibi proportions, thick S body, broad flat head, wet clay ridges",
        "signal": "old-gold clay ridges with a tiny cyan wet mouth glint",
        "motion": "small tongue flick, S-slide, mud spit windup",
        "avoid": "Chinese dragon, thin ordinary snake, bright green poison, mud puddle hiding the body",
    },
    "enemy_wind_mantis_chibi": {
        "silhouette": "same mantis identity in compact chibi proportions, big triangular head and oversized twin sickle arms",
        "signal": "cyan wind glow hugs sickle arms and jade shell joints only",
        "motion": "sickle open-close bounce, quick skitter, crossed slash",
        "avoid": "mecha insect, alien bug, giant wings, detached crescent slash outside the body",
    },
    "enemy_furnace_golem_chibi": {
        "silhouette": "same furnace golem identity in compact chibi proportions, round tripod kiln body, tiny stone arms, ember belly core",
        "signal": "orange-red furnace cracks and old-gold furnace linework",
        "motion": "furnace fire breath, heavy wobble hop, heat-up slam",
        "avoid": "western lava giant, generic rock golem, boss scale, full white-hot flames",
    },
}

SPELL_CELLS = [
    ("spell_q_fire_talisman_96.png", "fiery talisman bolt, orange-red flame drop wrapped by old-gold rune stroke"),
    ("spell_e_jade_sword_array_96.png", "jade sword array, three cyan sword lights crossing over a dark jade seal"),
    ("spell_r_thunder_fan_96.png", "thunder ice folding fan, blue-white fan arc with violet thunder core"),
    ("spell_locked_jade_seal_96.png", "locked jade seal, dim cracked round seal and small lock silhouette"),
    ("spell_lie_yan_bolt_96.png", "fire talisman bolt, compact flame talisman projectile icon"),
    ("spell_yu_jian_thrust_96.png", "jade sword thrust, single sharp jade sword ray icon"),
    ("spell_qi_fu_96.png", "protective qi talisman, circular guard seal icon"),
    ("spell_summon_soul_96.png", "soul summoning lantern, violet soul orb icon"),
    ("spell_lei_chi_strike_96.png", "thunder pool strike, compact blue-white thunder impact icon"),
    ("spell_lei_chi_chain_96.png", "thunder chain link, short linked lightning sigil icon"),
    ("spell_xuan_bing_fan_96.png", "black-ice folding fan, cold cyan fan icon"),
    ("spell_xuan_bing_lance_96.png", "black-ice lance, cold cyan ice spear icon"),
    ("spell_hui_chun_jue_96.png", "jade renewal art, green revival leaf talisman icon"),
]

COMPANION_CELLS = [
    ("pet_huo_ying_avatar_64.png", 64, "Huo Ying firefly spirit avatar, ember core and jade wings; same design as cell 2, only prepared for smaller output"),
    ("pet_huo_ying_avatar_96.png", 96, "Huo Ying firefly spirit avatar, identical design to cell 1, slightly larger and more readable"),
    ("artifact_xuanyu_gourd_pendant_64.png", 64, "Xuanyu gourd cultivation emblem, dark jade gourd and old-gold cord; same design as cell 4, only prepared for smaller output"),
    ("artifact_xuanyu_gourd_pendant_96.png", 96, "Xuanyu gourd cultivation emblem, identical design to cell 3, slightly larger and more readable"),
]

STATUS_ICON_CELLS = [
    (UI_ROOT / "status_burn_32.png", 32, "burn status, orange-red flame crack seal"),
    (UI_ROOT / "status_freeze_32.png", 32, "freeze status, cyan ice shard seal"),
    (UI_ROOT / "status_paralyze_32.png", 32, "paralyze status, blue-white broken thunder seal"),
    (UI_ROOT / "status_poison_32.png", 32, "poison status, jade thorn droplet seal"),
    (UI_ROOT / "status_slow_32.png", 32, "slow status, dim water ripple weight seal"),
    (UI_ROOT / "status_shield_32.png", 32, "shield status, basalt xuanwu ward seal"),
    (UI_ROOT / "status_haste_32.png", 32, "haste status, jade wind arrow seal"),
    (UI_ROOT / "status_root_32.png", 32, "root status, green vine binding seal"),
    (UI_ROOT / "status_bleed_32.png", 32, "bleed status, dark red ink cut seal"),
    (UI_ROOT / "status_curse_32.png", 32, "curse status, violet broken oath seal"),
    (UI_ROOT / "status_wet_32.png", 32, "wet status, cyan water drop ring seal"),
    (UI_ROOT / "status_elite_32.png", 32, "elite identity, old-gold dangerous triangle crest"),
    (UI_ROOT / "status_boss_32.png", 32, "boss identity, thunder crown boss crest"),
    (UI_ROOT / "status_promoted_32.png", 32, "promoted identity, ascending jade-gold step crest"),
    (UI_ROOT / "status_dao_32.png", 32, "Dao status, quiet white-gold orbit seal"),
    (UI_ROOT / "status_counter_32.png", 32, "counter status, reversed blade crescent seal"),
    (UI_ROOT / "status_mutation_32.png", 32, "mutation status, unstable purple-red crack seed"),
    (UI_ROOT / "status_windup_32.png", 32, "windup warning, orange threat eye seal"),
]

ELEMENT_ICON_CELLS = [
    ("fire", "fire element, orange-red flame talisman core", [(UI_ROOT / "elem_fire_32.png", 32), (UI_ROOT / "elem_fire_large_80.png", 80)]),
    ("water", "water element, cyan flowing droplet seal", [(UI_ROOT / "elem_water_32.png", 32), (UI_ROOT / "elem_water_large_80.png", 80)]),
    ("thunder", "thunder element, blue-white lightning split seal", [(UI_ROOT / "elem_thunder_32.png", 32), (UI_ROOT / "elem_thunder_large_80.png", 80)]),
    ("wood", "wood element, jade sprout and vine seal", [(UI_ROOT / "elem_wood_32.png", 32), (UI_ROOT / "elem_wood_large_80.png", 80)]),
    ("earth", "earth element, old-gold mountain square seal", [(UI_ROOT / "elem_earth_32.png", 32), (UI_ROOT / "elem_earth_large_80.png", 80)]),
    ("chaos", "chaos and soul element, violet-black void pearl seal", [(UI_ROOT / "elem_chaos_32.png", 32), (UI_ROOT / "elem_chaos_large_80.png", 80)]),
    ("ice", "ice element, cold cyan black-ice shard seal", [(UI_ROOT / "elem_ice_large_80.png", 80)]),
]

UTILITY_KARMA_ICON_CELLS = [
    (UI_ROOT / "icon_spirit_stone_32.png", 32, "spirit stone currency, small jade crystal coin"),
    (UI_ROOT / "icon_heal_32.png", 32, "heal command, jade medicine droplet and leaf"),
    (UI_ROOT / "icon_dodge_32.png", 32, "dodge command, wind step crescent"),
    (UI_ROOT / "icon_reroll_24.png", 24, "reroll command, tiny fate wheel swirl"),
    (UI_ROOT / "icon_skip_24.png", 24, "skip command, tiny fading path arrow"),
    (UI_ROOT / "icon_heart_demon_trial_24.png", 24, "heart demon trial, tiny purple-red inner demon eye seal"),
    (UI_ROOT / "badge_owned_32.png", 32, "owned badge, compact jade check crest without text"),
    (UI_ROOT / "badge_training_48x16.png", (48, 16), "training badge, slim old-gold jade training strip with no words"),
    (UI_ROOT / "pet_avatar_ring_40.png", 40, "pet avatar ring, small black-jade circular frame"),
    (UI_ROOT / "bt_slot_arrow_32.png", 32, "breakthrough slot arrow, jade chevron and old-gold spark"),
    (UI_ROOT / "spell_slot_empty_40.png", 40, "empty spell slot, dark jade circular slot"),
    (UI_ROOT / "spell_slot_locked_40.png", 40, "locked spell slot, cracked jade lock seal"),
    (UI_ROOT / "karma_good_16.png", 16, "good karma dot, tiny warm jade-gold blessing bead"),
    (UI_ROOT / "karma_evil_16.png", 16, "evil karma dot, tiny purple-red thorn bead"),
    (UI_ROOT / "karma_greed_16.png", 16, "greed karma dot, tiny old-gold hook bead"),
    (UI_ROOT / "karma_rebellion_16.png", 16, "rebellion karma dot, tiny blue-white broken chain bead"),
    (UI_ROOT / "karma_dao_heart_16.png", 16, "Dao-heart karma dot, tiny white-gold orbit bead"),
]

HUD_RUNE_SURFACE_CELLS = [
    (HUD_ROOT / "affix_rune_fire_64.png", 64, "affix rune fire, orange flame seal"),
    (HUD_ROOT / "affix_rune_thunder_64.png", 64, "affix rune thunder, blue-white lightning seal"),
    (HUD_ROOT / "affix_rune_water_64.png", 64, "affix rune water, cyan ripple seal"),
    (HUD_ROOT / "affix_rune_wood_64.png", 64, "affix rune wood, jade sprout seal"),
    (HUD_ROOT / "affix_rune_earth_64.png", 64, "affix rune earth, old-gold mountain seal"),
    (HUD_ROOT / "affix_rune_seal_64.png", 64, "affix rune sealed, dim cracked jade seal"),
    (HUD_ROOT / "auto_seal_attack_64.png", 64, "auto attack seal, sword talisman crest"),
    (HUD_ROOT / "auto_seal_guard_64.png", 64, "auto guard seal, shield talisman crest"),
    (HUD_ROOT / "auto_seal_pet_64.png", 64, "auto pet seal, tiny companion flame crest"),
    (HUD_ROOT / "auto_seal_artifact_64.png", 64, "auto artifact seal, gourd artifact crest"),
    (HUD_ROOT / "hud_left_section_divider_320x24.png", (320, 24), "left HUD thin section divider, broken old-gold jade line"),
    (UI_ROOT / "hud_spell_dock_frame.png", (320, 64), "bottom spell dock frame, dark jade long slot with three quiet wells"),
    (UI_ROOT / "hud_weather_panel_280x120.png", (280, 120), "weather charm panel, dark jade talisman plaque"),
    (UI_ROOT / "combo_track_256x8.png", (256, 8), "combo track, ultra-thin jade-gold progress rail"),
    (UI_ROOT / "progress_hp_9slice.png", (32, 12), "HP progress nine-slice, dark red ink jade capsule"),
    (UI_ROOT / "progress_mana_9slice.png", (32, 12), "mana progress nine-slice, cyan spirit jade capsule"),
    (UI_ROOT / "enemy_hp_bar_9slice.png", (32, 8), "enemy HP tiny nine-slice, muted red danger rail"),
]

TALENT_TAG_ICON_CELLS = [
    (UI_ROOT / "talent_badge_attack.png", 32, "talent attack badge, red-orange blade spark"),
    (UI_ROOT / "talent_badge_defense.png", 32, "talent defense badge, basalt ward crest"),
    (UI_ROOT / "talent_badge_spirit.png", 32, "talent spirit badge, cyan soul breath pearl"),
    (UI_ROOT / "talent_badge_utility.png", 32, "talent utility badge, jade compass bead"),
    (UI_ROOT / "tag_common.png", (72, 24), "common quality tag backing, quiet gray-jade pill"),
    (UI_ROOT / "tag_rare.png", (72, 24), "rare quality tag backing, cyan jade pill"),
    (UI_ROOT / "tag_epic.png", (72, 24), "epic quality tag backing, violet jade pill"),
    (UI_ROOT / "tag_fire.png", (72, 24), "fire element tag backing, orange-red ink pill"),
    (UI_ROOT / "tag_ice.png", (72, 24), "ice element tag backing, cold cyan ink pill"),
    (UI_ROOT / "tag_thunder.png", (72, 24), "thunder element tag backing, blue-white ink pill"),
    (UI_ROOT / "talent_icon_realm_1.png", 32, "realm 1 talent icon, small jade sprout realm seal"),
    (UI_ROOT / "talent_icon_realm_2.png", 32, "realm 2 talent icon, old-gold foundation stone seal"),
    (UI_ROOT / "talent_icon_realm_3.png", 32, "realm 3 talent icon, orange golden-core ember seal"),
    (UI_ROOT / "talent_icon_realm_4.png", 32, "realm 4 talent icon, pale soul moon seal"),
    (UI_ROOT / "talent_icon_realm_5.png", 32, "realm 5 talent icon, blue-white tribulation orbit seal"),
]

PROJECTILE_ELEMENTS_4X6 = [
    ("fire", "fire orange-red talisman bolt and flame impact"),
    ("thunder", "blue-white thunder needle projectile and electric impact"),
    ("ice", "cold cyan black-ice shard projectile and frost impact"),
    ("water", "cyan water bead projectile and splash impact"),
    ("generic", "neutral jade qi bead projectile and soft ink impact"),
    ("chaos", "violet soul void pearl projectile and broken oath impact"),
]

QUALITY_TALENT_SURFACE_CELLS = [
    (UI_ROOT / "quality_common_220x280.png", (220, 280), "legacy common quality frame, quiet gray-jade edge and dark open center"),
    (UI_ROOT / "quality_rare_220x280.png", (220, 280), "legacy rare quality frame, cyan jade edge and dark open center"),
    (UI_ROOT / "quality_epic_220x280.png", (220, 280), "legacy epic quality frame, violet jade edge and dark open center"),
    (UI_ROOT / "quality_legendary_220x280.png", (220, 280), "legacy legendary quality frame, restrained old-gold edge and dark open center"),
    (UI_ROOT / "quality_dao_220x280.png", (220, 280), "legacy Dao quality frame, white-gold orbit edge and black-jade open center"),
    (UI_ROOT / "talent_scroll_210x200.png", (210, 200), "talent scroll card surface, black-jade scroll plaque, no beige parchment, no text"),
    (UI_ROOT / "talent_scroll_210x200_highlight.png", (210, 200), "highlighted talent scroll card surface, cold jade edge pulse, no text"),
    (UI_ROOT / "hud_panel_bg_320x448.png", (320, 448), "legacy HUD panel background, translucent black-jade tall plaque, quiet center"),
    (HUD_ROOT / "weather_thunderstorm_icon_64.png", 64, "thunderstorm weather icon, blue-white storm cloud thunder seal"),
    (UI_ROOT / "weather_clear_32.png", 32, "small fallback clear weather icon, jade-gold sun dot"),
    (UI_ROOT / "weather_rain_32.png", 32, "small fallback rain weather icon, cyan rain drop dot"),
    (UI_ROOT / "weather_thunder_32.png", 32, "small fallback thunder weather icon, blue-white lightning dot"),
    (UI_ROOT / "weather_fire_32.png", 32, "small fallback fire weather icon, orange-red sun flame dot"),
    (UI_ROOT / "weather_wind_32.png", 32, "small fallback wind weather icon, jade wind curl dot"),
    (UI_ROOT / "weather_fog_32.png", 32, "small fallback fog weather icon, pale mist bead"),
    (UI_ROOT / "weather_snow_32.png", 32, "small fallback snow weather icon, cyan frost bead"),
    (UI_ROOT / "weather_sand_32.png", 32, "small fallback sand weather icon, old-gold dust bead"),
]

UI_JOBS = {
    "bg_main_menu_celestial_hall.png": "wide dark jade immortal mountain gate and celestial hall silhouettes pushed to upper third and side edges, Chinese xianxia ink painting, cloud sea, bronze ritual lamps, open center for UI",
    "bg_run_setup_inner_court.png": "inner cultivation court, faint flat low-contrast jade fate compass mostly hidden under outer floor edges, incense mist, Chinese ritual architecture, open center for selection panel, not a bright central emblem",
    "bg_run_result_reincarnation_pool.png": "reincarnation pool inside ancient jade shrine, pool rim and bronze fate wheel silhouettes frame lower and side edges, center remains calm dark water with minimal reflection, faint soul ribbons",
    "event_illustration_secret_encounter.png": "wide secret encounter banner, half-open jade ruin door on one side, talisman light, mist, center-left or center-right negative space for UI, no people, no text",
}

LEGACY_RAW_SOURCES = {
    "weather_icon_atlas_4x2": ROOT / "output" / "imagegen" / "hud_icons" / "weather_icon_atlas.image2_raw.png",
    "hud_core_icon_atlas_2x2": ROOT / "output" / "imagegen" / "hud_icons" / "hud_icon_atlas.image2_raw.png",
    "spell_qer_icon_atlas_2x2": ROOT / "output" / "imagegen" / "hud_icons" / "spell_icon_atlas_v2.image2_raw.png",
    "wood_earth_projectile_impact_atlas_4x4": ROOT / "output" / "imagegen" / "spell_semantic_assets" / "wood_earth_projectile_impact_atlas_4x4.image2_raw.png",
    "pet_huo_ying_avatar": ROOT / "output" / "imagegen" / "hud_ui_assets" / "raw" / "pet_huo_ying_avatar.image2_raw.png",
    "artifact_xuanyu_gourd_pendant": ROOT / "output" / "imagegen" / "hud_ui_assets" / "raw" / "artifact_xuanyu_gourd_pendant.image2_raw.png",
    "weather_thunderstorm_charm": ROOT / "output" / "imagegen" / "hud_ui_assets" / "raw" / "weather_thunderstorm_charm.image2_raw.png",
    "card_reward_common_240x373": ROOT / "output" / "imagegen" / "reward_cards" / "card_reward_common_240x373.image2_raw.png",
    "card_reward_rare_240x373": ROOT / "output" / "imagegen" / "reward_cards" / "card_reward_rare_240x373.image2_raw.png",
    "hud_left_panel_frame_448x512": ROOT / "output" / "imagegen" / "left_hud_panel" / "hud_left_panel_frame_448x512.image2_raw.png",
    "hud_left_objective_card_384x112": ROOT / "output" / "imagegen" / "left_hud_panel" / "hud_left_objective_card_384x112.image2_raw.png",
    "hud_left_resource_track_384x32": ROOT / "output" / "imagegen" / "left_hud_panel" / "hud_left_resource_track_384x32.image2_raw.png",
    "hud_left_build_badge_320x40": ROOT / "output" / "imagegen" / "left_hud_panel" / "hud_left_build_badge_320x40.image2_raw.png",
}

WEATHER_ICON_CELLS = [
    ("weather_clear_icon_64.png", 64, "clear sky jade sun disk"),
    ("weather_rain_icon_64.png", 64, "rain water talisman with three blue droplets"),
    ("weather_thunder_icon_64.png", 64, "thunderstorm blue-white lightning sigil"),
    ("weather_fire_icon_64.png", 64, "fierce solar fire flame seal"),
    ("weather_wind_icon_64.png", 64, "wind spiral jade gust"),
    ("weather_fog_icon_64.png", 64, "fog pale mist charm"),
    ("weather_snow_icon_64.png", 64, "snow crystalline frost talisman"),
    ("weather_sand_icon_64.png", 64, "sandstorm old-gold dust vortex"),
]

HUD_CORE_CELLS = [
    (UI_ROOT / "hud_pet_huo_ying_avatar_128.png", 128, "firefly spirit pet avatar, warm ember core and jade wing portrait"),
    (UI_ROOT / "hud_artifact_xuanyu_gourd_128.png", 128, "dark jade gourd artifact pendant, cold gold rim and subtle spirit glow"),
    (UI_ROOT / "hud_weather_thunder_sig_96.png", 96, "thunderstorm celestial compass seal, blue-white lightning sigil"),
    (UI_ROOT / "hud_auto_seal_base_64.png", 64, "empty auto-strategy seal base, dark jade circular seal with cold gold rim"),
]

DAO_HEART_CELLS = [
    (UI_ROOT / "dao_heart_ask_128.png", 128, "Ask Dao heart, calm open jade question seal, soft white-gold breath, low difficulty clarity"),
    (UI_ROOT / "dao_heart_enlighten_128.png", 128, "Enlighten Dao heart, balanced jade lotus and ink compass seal, steady cultivation focus"),
    (UI_ROOT / "dao_heart_prove_128.png", 128, "Prove Dao heart, sharp thunder-gold vow seal, intense trial pressure, still elegant"),
]

PATH_ICON_CELLS = [
    (UI_ROOT / "path_combat_48.png", 48, "combat path, crossed jade sword-light and talisman spark, not western weapons"),
    (UI_ROOT / "path_rest_48.png", 48, "rest path, quiet meditation cushion seal with incense curl and jade breath"),
    (UI_ROOT / "path_shop_48.png", 48, "shop path, small spirit-stone pouch and bronze scale seal, no coin text"),
    (UI_ROOT / "path_event_48.png", 48, "event path, half-open fate scroll seal and tiny mist doorway"),
    (UI_ROOT / "path_elite_48.png", 48, "elite path, dangerous boss-mask talisman seal, blue-white threat spark"),
]

SPELL_QER_CELLS = [
    ("spell_q_fire_talisman_96.png", 96, "Q fire talisman bolt, orange-red flame drop wrapped by old-gold rune stroke"),
    ("spell_e_jade_sword_array_96.png", 96, "E jade sword array, three cyan sword lights crossing over a dark jade seal"),
    ("spell_r_thunder_fan_96.png", 96, "R thunder-ice folding fan, blue-white fan arc with violet thunder core"),
    ("spell_locked_jade_seal_96.png", 96, "locked jade seal, dim cracked round seal and small lock talisman"),
]

VFX_4X4_CELLS = [
    (FRAME_ROOT / "projectile_wood" / "fly_00.png", 16, "wood projectile frame 00"),
    (FRAME_ROOT / "projectile_wood" / "fly_01.png", 16, "wood projectile frame 01"),
    (FRAME_ROOT / "projectile_wood" / "fly_02.png", 16, "wood projectile frame 02"),
    (FRAME_ROOT / "projectile_wood" / "fly_03.png", 16, "wood projectile frame 03"),
    (FRAME_ROOT / "projectile_earth" / "fly_00.png", 16, "earth projectile frame 00"),
    (FRAME_ROOT / "projectile_earth" / "fly_01.png", 16, "earth projectile frame 01"),
    (FRAME_ROOT / "projectile_earth" / "fly_02.png", 16, "earth projectile frame 02"),
    (FRAME_ROOT / "projectile_earth" / "fly_03.png", 16, "earth projectile frame 03"),
    (FRAME_ROOT / "impact_wood" / "impact_00.png", 32, "wood impact frame 00"),
    (FRAME_ROOT / "impact_wood" / "impact_01.png", 32, "wood impact frame 01"),
    (FRAME_ROOT / "impact_wood" / "impact_02.png", 32, "wood impact frame 02"),
    (FRAME_ROOT / "impact_wood" / "impact_03.png", 32, "wood impact frame 03"),
    (FRAME_ROOT / "impact_earth" / "impact_00.png", 32, "earth impact frame 00"),
    (FRAME_ROOT / "impact_earth" / "impact_01.png", 32, "earth impact frame 01"),
    (FRAME_ROOT / "impact_earth" / "impact_02.png", 32, "earth impact frame 02"),
    (FRAME_ROOT / "impact_earth" / "impact_03.png", 32, "earth impact frame 03"),
]

WEATHER_GROUND_DECAL_CELLS = [
    (FX_ROOT / "weather_decal_rain_128.png", 128, "rain: shallow cyan ink puddle ripple, wet brush stain, low contrast edge, no hazard circle"),
    (FX_ROOT / "weather_decal_thunder_128.png", 128, "thunder: storm-dark wet ground stain with tiny blue-white branch vein, not a warning target"),
    (FX_ROOT / "weather_decal_snow_128.png", 128, "snow: pale cyan frost dust patch, broken snow crystals on black jade stone, soft and sparse"),
    (FX_ROOT / "weather_decal_sand_128.png", 128, "sand: old-gold dry dust smear, wind-brushed grit crescent, subdued on dark ink floor"),
    (FX_ROOT / "weather_decal_fog_128.png", 128, "fog: gray-jade low mist stain, soft ink bloom, transparent open center"),
    (FX_ROOT / "weather_decal_fire_128.png", 128, "fire weather: ember ash scorch stain, orange-red hairline cracks only on edge, no lava puddle"),
    (FX_ROOT / "weather_decal_wind_128.png", 128, "wind: jade wind-swept grassless brush curl, very thin spiral smear, non-hazard"),
    (FX_ROOT / "weather_decal_clear_128.png", 128, "clear fallback: faint circular black-jade breathing brush mark, two old-gold dust flecks, distinct calm outline but very low contrast"),
]

WEATHER_OVERLAY_PARTICLE_CELLS = [
    (FX_ROOT / "weather_particle_rain_64x96.png", (64, 96), "rain overlay particle: long thin cyan-blue ink rain slash, tapered brush ends, slight black-jade ghost edge"),
    (FX_ROOT / "weather_particle_thunder_64x96.png", (64, 96), "thunderstorm overlay particle: rain slash with tiny blue-white lightning fork and two old-gold spark flecks"),
    (FX_ROOT / "weather_particle_snow_64.png", 64, "snow overlay particle: pale cyan frost blossom, broken six-point ink crystal, sparse transparent interior"),
    (FX_ROOT / "weather_particle_fog_128.png", 128, "fog overlay particle: soft gray-jade ink cloud wisp, feathered edge, open transparent center"),
    (FX_ROOT / "weather_particle_sand_96x64.png", (96, 64), "sand overlay particle: old-gold dry grit crescent, wind-brushed dust stroke, subdued on dark floor"),
    (FX_ROOT / "weather_particle_wind_128x64.png", (128, 64), "wind overlay particle: jade-green calligraphy wind curl, thin ribbon stroke with transparent center"),
    (FX_ROOT / "weather_particle_fire_64.png", 64, "fire weather ash particle: tiny ember ash spark, orange-red edge and black ink smoke tail, not a projectile"),
    (FX_ROOT / "weather_particle_clear_64.png", 64, "clear fallback mote: faint black-jade dust mote with one restrained old-gold glint, very low contrast"),
]

ENEMY_PROJECTILE_TRAIL_CELLS = [
    (FX_ROOT / "enemy_projectile_trail_generic_128x48.png", (128, 48), "generic enemy projectile trail: dark jade qi comet tail, soft black ink taper, tiny cold jade core streak"),
    (FX_ROOT / "enemy_projectile_trail_fire_128x48.png", (128, 48), "fire enemy projectile trail: orange-red talisman ember brush tail, black ink smoke edge, restrained hot core"),
    (FX_ROOT / "enemy_projectile_trail_thunder_128x48.png", (128, 48), "thunder enemy projectile trail: blue-white lightning needle tail, broken ink fork, tiny old-gold spark flecks"),
    (FX_ROOT / "enemy_projectile_trail_ice_128x48.png", (128, 48), "ice enemy projectile trail: cyan black-ice shard tail, frost brush splinters, cold jade rim"),
    (FX_ROOT / "enemy_projectile_trail_water_128x48.png", (128, 48), "water enemy projectile trail: cyan water-ink ribbon tail, soft splash beads, no western wave icon"),
    (FX_ROOT / "enemy_projectile_trail_wood_128x48.png", (128, 48), "wood poison enemy projectile trail: jade-green vine qi tail, venom ink droplets, sharp but not UI-like"),
    (FX_ROOT / "enemy_projectile_trail_earth_128x48.png", (128, 48), "earth enemy projectile trail: old-gold dust talisman tail, black stone grit, heavy grounded taper"),
    (FX_ROOT / "enemy_projectile_trail_chaos_128x48.png", (128, 48), "chaos soul enemy projectile trail: violet soul-smoke tail, broken oath ink wisps, small saturated core only"),
]

THUNDER_STRIKE_DECAL_CELLS = [
    (FX_ROOT / "thunder_strike_warning_192.png", 192, "warning ground seal: thin broken old-gold ring with tiny blue-white thunder knots, transparent center"),
    (FX_ROOT / "thunder_strike_impact_192.png", 192, "impact ground burst: blue-white thunder splash and old-gold scorch ring, edge-heavy, transparent center"),
    (FX_ROOT / "thunder_strike_bolt_128x512.png", (128, 512), "vertical lightning bolt: jagged Chinese ink thunder stroke, blue-white core, old-gold spark tips, tall transparent asset"),
    (FX_ROOT / "thunder_strike_scorch_192.png", 192, "after-scorch: fading storm scorch blossom, blue-gray ink smoke, a few gold crack sparks"),
]

ENEMY_TELEGRAPH_CELLS = [
    (FX_ROOT / "enemy_spawn_telegraph_128.png", 128, "normal enemy spawn warning: broken red-orange square talisman corners, black ink smoke, transparent center"),
    (FX_ROOT / "enemy_spawn_telegraph_elite_128.png", 128, "elite spawn warning: double-layer broken red-orange talisman frame, old-gold corner hooks, tiny threat sparks, transparent center"),
    (FX_ROOT / "enemy_attack_line_256x64.png", (256, 64), "standard enemy attack lane: long thin red-orange ink blade strip, broken talisman ticks along both edges"),
    (FX_ROOT / "enemy_attack_dash_256x96.png", (256, 96), "dash warning lane: wider red-orange rush smear with old-gold speed cuts, clear transparent middle"),
    (FX_ROOT / "enemy_attack_sniper_256x48.png", (256, 48), "sniper warning lane: extremely thin sharp red-orange thread with tiny blue-white aiming sparks, slimmer than the standard lane"),
    (FX_ROOT / "enemy_attack_melee_128.png", 128, "melee warning arc: compact crescent claw arc seal, red-orange outer edge, transparent interior"),
]

COMBAT_ACTION_FX_CELLS = [
    (FX_ROOT / "player_slash_arc_192x128.png", (192, 128), "player melee slash arc: cold jade crescent brush slash, blue-white core, old-gold sparks, transparent inner gap"),
    (FX_ROOT / "crit_screen_slash_640x180.png", (640, 180), "screen crit slash: long diagonal ink blade slash, cold jade white edge, sparse old-gold spark flecks, no straight debug line"),
    (FX_ROOT / "enemy_windup_seal_160.png", 160, "enemy windup seal: red-orange broken talisman ring, transparent center, threat readable but not a western magic circle"),
    (FX_ROOT / "actor_presence_shadow_128x64.png", (128, 64), "actor foot presence shadow: black-jade oval brush wash with cold jade lower rim, very low contrast"),
    (FX_ROOT / "player_dao_aura_160.png", 160, "player Dao momentum aura: old-gold jade orbit brush ring, open center, calm cultivation pressure"),
    (FX_ROOT / "player_counter_aura_160.png", 160, "perfect counter aura: sharper old-gold impact ring with two jade-white spark knots, open center"),
    (FX_ROOT / "enemy_identity_ring_elite_160.png", 160, "elite enemy identity ring: old-gold broken lower halo, dark jade smoke, subtle corner ticks"),
    (FX_ROOT / "enemy_identity_ring_boss_192.png", 192, "boss identity ring: larger red-orange and old-gold oath halo, black ink pressure, transparent actor center"),
    (FX_ROOT / "enemy_guard_aura_192.png", 192, "guardian aura: xuanwu shield field, old-gold jade defensive ring, low alpha center, no solid disk"),
    (FX_ROOT / "status_badge_backing_48.png", 48, "world status badge backing: tiny black jade circular seal plate, cold jade rim, readable at 12px"),
    (FX_ROOT / "enemy_weapon_claw_96x64.png", (96, 64), "enemy claw windup glyph: three red-orange ink claw slashes, pointed right, black smoke edge"),
    (FX_ROOT / "enemy_weapon_crossbow_112x64.png", (112, 64), "enemy crossbow windup glyph: horizontal talisman crossbow silhouette, old-gold stock, blue-white bolt tip"),
    (FX_ROOT / "enemy_weapon_furnace_core_96.png", 96, "enemy furnace core windup glyph: ember alchemy furnace eye, orange-red core inside black jade ring"),
    (FX_ROOT / "enemy_weapon_xuanwu_shield_96.png", 96, "enemy xuanwu shield windup glyph: dark turtle-shell shield sigil, old-gold rim, jade crack light"),
    (FX_ROOT / "enemy_weapon_soul_banner_96x128.png", (96, 128), "enemy soul banner windup glyph: vertical torn black-violet banner, old-gold pole, purple soul flame edge"),
    (FX_ROOT / "enemy_weapon_poison_spit_80x64.png", (80, 64), "enemy poison spit windup glyph: jade venom ink droplet burst, pointed right, dark smoke outline"),
]

OVERLAY_ORNAMENT_FX_CELLS = [
    (FX_ROOT / "dao_pattern_fire_256.png", 256, "fire Dao awakening corner ornament: diagonal Chinese talisman brush pattern, black jade ink mass, red-orange danger edge, sparse old-gold sparks, open transparent center"),
    (FX_ROOT / "dao_pattern_thunder_256.png", 256, "thunder Dao awakening corner ornament: diagonal lightning talisman brush pattern, black jade ink mass, blue-white thunder edge, tiny old-gold seal flecks, open transparent center"),
    (FX_ROOT / "dao_pattern_wood_256.png", 256, "wood Dao awakening corner ornament: diagonal vine-and-rune talisman brush pattern, black jade ink mass, jade-green life edge, small old-gold seed sparks, open transparent center"),
    (FX_ROOT / "dao_pattern_water_256.png", 256, "water Dao awakening corner ornament: diagonal wave-and-ice talisman brush pattern, black jade ink mass, cyan-blue water edge, thin old-gold seal flecks, open transparent center"),
    (FX_ROOT / "dao_pattern_five_256.png", 256, "five elements Dao awakening corner ornament: diagonal circular five-element talisman fragments, black jade ink mass, five tiny saturated accent sparks, restrained old-gold ring shards, open transparent center"),
    (FX_ROOT / "crit_edge_top_512x96.png", (512, 96), "critical moment top edge glow strip: horizontal torn ink wash border, cold jade white inner slash light, old-gold spark dust, feathered transparent lower edge"),
    (FX_ROOT / "crit_edge_side_96x512.png", (96, 512), "critical moment side edge glow strip: vertical torn ink wash border, cold jade white inner slash light, old-gold spark dust, feathered transparent inner edge"),
    (FX_ROOT / "crit_edge_corner_192.png", 192, "critical moment corner flare: L-shaped ink slash flare, cold jade white edge, tiny old-gold sparks, transparent center and feathered outer ink"),
]

SINGLE_ICON_REUSE_JOBS = [
    ("pet_huo_ying_avatar", [(HUD_ROOT / "pet_huo_ying_avatar_64.png", 64), (HUD_ROOT / "pet_huo_ying_avatar_96.png", 96)], "Huo Ying firefly spirit pet HUD avatar, round ember core with translucent jade wings"),
    ("artifact_xuanyu_gourd_pendant", [(HUD_ROOT / "artifact_xuanyu_gourd_pendant_64.png", 64), (HUD_ROOT / "artifact_xuanyu_gourd_pendant_96.png", 96)], "Xuanyu gourd pendant HUD avatar, black jade gourd silhouette with old-gold cord"),
    ("weather_thunderstorm_charm", [(HUD_ROOT / "weather_thunderstorm_charm_160x96.png", (160, 96))], "wide thunderstorm weather charm, blue-white lightning sigil on dark jade talisman"),
]

REWARD_CARD_REUSE_JOBS = [
    ("card_reward_common_240x373", CARD_ROOT / "card_reward_common_240x373.png", (240, 373), "common reward card frame, bone-white flying-ink edge, quiet dark jade center"),
    ("card_reward_rare_240x373", CARD_ROOT / "card_reward_rare_240x373.png", (240, 373), "rare reward card frame, jade-cyan cut-corner line, tiny edge dust, dark clean center"),
    ("card_reward_epic_240x373", CARD_ROOT / "card_reward_epic_240x373.png", (240, 373), "epic reward card frame, deep violet-jade edge sparks, old-gold joint marks, dark readable center"),
    ("card_reward_legendary_240x373", CARD_ROOT / "card_reward_legendary_240x373.png", (240, 373), "legendary reward card frame, restrained old-gold celestial rim, jade corner glow, dark readable center"),
    ("card_reward_dao_240x373", CARD_ROOT / "card_reward_dao_240x373.png", (240, 373), "dao reward card frame, black jade void center, thin white-gold Dao orbit only on edge, rare and quiet"),
]

REWARD_OVERLAY_REUSE_JOBS = [
    ("card_reward_forbidden_overlay_240x373", CARD_ROOT / "card_reward_forbidden_overlay_240x373.png", (240, 373), "transparent forbidden temptation overlay, purple-red reverse-flow cracks and oath sparks only around outer edge"),
    ("card_reward_locked_overlay_240x373", CARD_ROOT / "card_reward_locked_overlay_240x373.png", (240, 373), "transparent locked reward overlay, dim gray jade seal chains and frost dust only around outer edge"),
]

REWARD_QUALITY_FX_REUSE_JOBS = [
    ("reward_quality_aura_256", CARD_ROOT / "reward_quality_aura_256.png", (256, 256), 8, "transparent reward quality aura, circular-square broken brush halo, old-gold and cold jade edge wisps, open center for reward card text, no solid fill"),
    ("reward_quality_mote_64", CARD_ROOT / "reward_quality_mote_64.png", (64, 64), 6, "transparent reward quality mote, tiny old-gold jade spark knot with rice-paper ink tail, readable as a restrained edge particle at 6-11px"),
    ("reward_forbidden_reverse_mark_128x48", CARD_ROOT / "reward_forbidden_reverse_mark_128x48.png", (128, 48), 4, "transparent forbidden reverse-flow mark, short purple-red broken oath slash with black-jade smoke feathering, no circle, no enemy seal"),
]

CORE_UI_SURFACE_REUSE_JOBS = [
	("panel_ninepatch_256", UI_ROOT / "panel_ninepatch_256.png", (256, 256), 4, True, True, "square reusable nine-slice modal panel surface, translucent black-jade glass, cold jade inner rim, old-gold dry-brush corners, empty center"),
	("modal_ink_veil_1920x1080", UI_ROOT / "modal_ink_veil_1920x1080.png", (1920, 1080), 0, False, False, "full-screen unified modal veil dimmer texture, deep black-jade ink wash, extremely subtle cold jade edge mist and old-gold dust only near outer 12 percent, center 70 percent flat readable matte dark ink field, no emblem, no frame, no vignette ring, no bright particles"),
	("dao_heart_card_frame", UI_ROOT / "dao_heart_card_frame.png", (168, 200), 3, True, True, "Dao-heart selection card frame, vertical black-jade plaque, cold jade inner edge, sparse old-gold corner talisman marks, empty center"),
    ("setup_title_ornament", UI_ROOT / "setup_title_ornament.png", (640, 48), 2, True, True, "run setup title ornament, long thin jade cloud crown, old-gold dry-brush center knot, transparent background"),
    ("couplet_panel_left", UI_ROOT / "couplet_panel_left.png", (48, 240), 2, True, True, "left vertical couplet plaque, slim black jade hanging strip, old-gold knots and jade mist, empty readable center"),
    ("couplet_panel_right", UI_ROOT / "couplet_panel_right.png", (48, 240), 2, True, True, "right vertical couplet plaque, mirrored slim black jade hanging strip, old-gold knots and jade mist, empty readable center"),
    ("modal_title_bar_720x52", UI_ROOT / "modal_title_bar_720x52.png", (720, 52), 2, True, True, "long modal title bar ornament, black-jade lacquer strip, old-gold upper line, cold jade smoke edge, empty center"),
    ("btn_primary_gold_360x48", UI_ROOT / "btn_primary_gold_360x48.png", (360, 48), 2, True, True, "primary command button surface, dark jade interior, restrained old-gold rim, subtle center glow, no words"),
    ("btn_secondary_360x40", UI_ROOT / "btn_secondary_360x40.png", (360, 40), 2, True, True, "secondary command button surface, dark ink teal interior, cold jade rim, quiet old-gold corner ticks, no words"),
    ("scroll_toast_520x72", UI_ROOT / "scroll_toast_520x72.png", (520, 72), 2, True, True, "wide toast scroll surface, black jade scroll plaque, soft ink mist edges, tiny old-gold corner knots, no parchment beige"),
    ("divider_gold_256x2", UI_ROOT / "divider_gold_256x2.png", (256, 2), 0, True, True, "ultra-thin old-gold divider stroke, broken dry-brush line with tiny jade glints, transparent background"),
    ("event_banner_640x160", UI_ROOT / "event_banner_640x160.png", (640, 160), 0, False, False, "regular event banner, dark jade shrine threshold and drifting ink mist at side edges, central negative space"),
    ("event_illustration_560x96", UI_ROOT / "event_illustration_560x96.png", (560, 96), 0, False, False, "small event illustration strip, weather-karma omen clouds, jade wind and old-gold fate dust, low contrast center"),
    ("boss_banner_640x80", UI_ROOT / "boss_banner_640x80.png", (640, 80), 0, False, False, "thin boss announcement banner, dark thunder altar edge, old-gold threat line, central negative space"),
    ("enemy_nameplate_128x24", UI_ROOT / "enemy_nameplate_128x24.png", (128, 24), 2, True, True, "tiny world-space enemy nameplate backing, transparent black-jade pill, cold jade hairline rim, restrained old-gold corner ticks, no words, no emblem, readable behind 8-12px enemy names"),
    ("spell_slot_ready_frame_96", UI_ROOT / "spell_slot_ready_frame_96.png", (96, 96), 4, True, True, "round combat spell slot frame in ready state, transparent black-jade lacquer ring, cold jade inner rim, restrained old-gold talisman ticks at four compass points, open transparent center for a 54px spell icon, no words, no emblem disk, no western metal"),
    ("spell_slot_cooldown_frame_96", UI_ROOT / "spell_slot_cooldown_frame_96.png", (96, 96), 4, True, True, "round combat spell slot frame in cooldown state, transparent black-jade lacquer ring, dim cyan jade inner rim, subtle smoky ink notch marks, open transparent center for a 54px spell icon, darker and calmer than ready, no words, no solid disk"),
    ("spell_slot_locked_frame_96", UI_ROOT / "spell_slot_locked_frame_96.png", (96, 96), 4, True, True, "round combat spell slot frame in locked state, transparent black-jade ring, muted gray jade rim, thin old-gold broken seal marks, open transparent center for locked seal icon, no words, no opaque fill, no western metal"),
    ("spell_shortcut_badge_32", UI_ROOT / "spell_shortcut_badge_32.png", (32, 32), 2, True, True, "tiny circular keyboard key badge for spell slot, transparent old-gold jade coin rim, dark ink center readable behind one letter, crisp at 32px, no baked text, no icon"),
    ("spell_cooldown_sweep_96", UI_ROOT / "spell_cooldown_sweep_96.png", (96, 96), 4, True, True, "round cooldown sweep overlay for spell slot, semi-transparent black ink crescent and jade smoke around outer ring, open enough center to see icon and cooldown number, no text, no full opaque disk, no hard rectangular edge"),
    ("breakthrough_bg_overlay", UI_ROOT / "breakthrough_bg_overlay.png", (1920, 1080), 0, False, False, "full-screen breakthrough overlay, dark ink-jade mist and subtle ascending fate ribbons around edges, center subdued for modal text"),
    ("breakthrough_backdrop_no_emblem_v3_1920x1080", UI_ROOT / "breakthrough_backdrop_no_emblem_v3_1920x1080.png", (1920, 1080), 0, False, False, "full-screen breakthrough realm gate backdrop, black-jade heavenly threshold and distant Chinese immortal hall, clean dark central safe zone behind the modal, center 900x520 must be plain dark ink mist only, no large five-element emblems, no circular symbols, no oversized icons behind the UI, no glowing discs, no icon-like symbols, no element badges anywhere in the image"),
    ("realm_gate_panel_760x360", UI_ROOT / "realm_gate_panel_760x360.png", (760, 360), 6, True, True, "transparent wide realm gate panel ornament, open celestial doorway arc, five-element jade veins, old-gold talisman hinges, thunder sparks, empty dark center for talent cards, no text"),
    ("death_moment_vignette_1920x1080", UI_ROOT / "death_moment_vignette_1920x1080.png", (1920, 1080), 0, False, False, "full-screen death moment vignette, black-jade soul mist, blood-red regret sparks and cold cyan spirit particles on edges, center dark and readable, no flat black screen"),
    ("death_soul_totem_disc_512", UI_ROOT / "death_soul_totem_disc_512.png", (512, 512), 10, True, True, "transparent circular soul totem disc, broken Dao seal, reincarnation rings, cold jade center, old-gold cracks, ember-red regret motes, no text"),
]

LEFT_HUD_REUSE_JOBS = [
    ("hud_left_panel_frame_448x512", HUD_ROOT / "hud_left_panel_frame_448x512.png", (448, 512), 8, True, "tall translucent left combat status panel frame, black-jade glass and cold-gold rim"),
    ("hud_left_objective_card_384x112", HUD_ROOT / "hud_left_objective_card_384x112.png", (384, 112), 4, True, "wide compact objective-card background, dark jade rounded pill and thin cold-gold accent"),
    ("hud_left_resource_track_384x32", HUD_ROOT / "hud_left_resource_track_384x32.png", (384, 32), 2, True, "long thin resource bar track, black-jade slot with rounded ends"),
    ("hud_left_build_badge_320x40", HUD_ROOT / "hud_left_build_badge_320x40.png", (320, 40), 2, True, "wide realm and build badge background, dark jade rounded pill and subtle top highlight"),
]


def _api_key() -> str:
    for name in ("SSSTOKEN_API_KEY", "SAMSARA_IMAGE_API_KEY"):
        value = os.environ.get(name, "").strip()
        if value:
            return value
    raise RuntimeError(
        "SSSTOKEN_API_KEY is not set. Set it in your local environment; do not pass it as a command argument."
    )


def _decode_image(payload: dict) -> bytes:
    data = payload.get("data", [])
    if not data:
        raise RuntimeError("image response missing data[0]")
    first = data[0]
    b64_value = first.get("b64_json") or first.get("base64") or first.get("image")
    if isinstance(b64_value, str) and b64_value:
        if b64_value.startswith("data:"):
            b64_value = b64_value.split(",", 1)[1]
        return base64.b64decode(b64_value)
    url = first.get("url")
    if isinstance(url, str) and url:
        with urllib.request.urlopen(url, timeout=300) as response:
            return response.read()
    raise RuntimeError("image response missing b64_json/url")


def request_image(prompt: str, *, size: str, timeout: int, retries: int, sleep_seconds: float) -> Image.Image:
    key = _api_key()
    body = {
        "model": MODEL,
        "prompt": prompt,
        "n": 1,
        "size": size,
        "quality": "auto",
        "background": "auto",
        "output_format": "png",
        "moderation": "auto",
    }
    headers = {
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
    }
    for attempt in range(1, retries + 1):
        request = urllib.request.Request(
            ENDPOINT,
            data=json.dumps(body).encode("utf-8"),
            headers=headers,
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                payload = json.loads(response.read().decode("utf-8"))
            return Image.open(io.BytesIO(_decode_image(payload))).convert("RGBA")
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            msg = f"HTTP {exc.code}: {detail[:420]}"
        except Exception as exc:  # noqa: BLE001 - report retryable provider issue.
            msg = str(exc)
        print(f"image request attempt {attempt}/{retries} failed: {msg}", file=sys.stderr, flush=True)
        if attempt >= retries:
            raise RuntimeError(f"image request failed after {retries} attempts: {msg}")
        time.sleep(sleep_seconds)
    raise RuntimeError("unreachable image request retry state")


def remove_magenta(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    px = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = px[x, y]
            if a == 0:
                if r > 160 and g < 120 and b > 160:
                    px[x, y] = (0, 0, 0, 0)
                continue
            if (r > 205 and g < 82 and b > 205) or (abs(r - 255) <= 18 and g <= 28 and abs(b - 255) <= 18):
                px[x, y] = (0, 0, 0, 0)
            elif r > 160 and g < 120 and b > 160:
                px[x, y] = (r, max(g, 35), b, 0 if a < 64 else int(a * 0.18))
    return rgba


def alpha_coverage(image: Image.Image) -> float:
    alpha = image.convert("RGBA").getchannel("A")
    nonzero = sum(1 for value in alpha.getdata() if value > 8)
    return nonzero / float(max(1, image.width * image.height))


def trim_alpha(image: Image.Image, padding: int) -> Image.Image:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return image
    left, top, right, bottom = bbox
    return image.crop((
        max(0, left - padding),
        max(0, top - padding),
        min(image.width, right + padding),
        min(image.height, bottom + padding),
    ))


def fit_square(image: Image.Image, size: int, *, anchor: str = "bottom", fill_ratio: float = 0.84) -> Image.Image:
    clean = trim_alpha(remove_magenta(image), padding=max(8, image.width // 80))
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    clean.thumbnail((max(1, int(size * fill_ratio)), max(1, int(size * fill_ratio))), Image.Resampling.LANCZOS)
    x = (size - clean.width) // 2
    if anchor == "center":
        y = (size - clean.height) // 2
    else:
        y = size - clean.height - max(1, int(size * 0.06))
    canvas.alpha_composite(clean, (x, y))
    return canvas


def dark_ink_grade_rgb(image: Image.Image, *, target_mean: int = 78, max_channel: int = 164) -> Image.Image:
    rgb = image.convert("RGB")
    rgb = ImageEnhance.Color(rgb).enhance(0.56)
    rgb = ImageEnhance.Contrast(rgb).enhance(0.92)
    pixels = list(rgb.getdata())
    if pixels:
        mean = sum((r + g + b) / 3.0 for r, g, b in pixels) / len(pixels)
        if mean > 1:
            scale = min(1.0, target_mean / mean)
            rgb = ImageEnhance.Brightness(rgb).enhance(scale)
    teal = Image.new("RGB", rgb.size, (7, 30, 33))
    rgb = Image.blend(rgb, teal, 0.16)
    px = rgb.load()
    for y in range(rgb.height):
        for x in range(rgb.width):
            r, g, b = px[x, y]
            px[x, y] = (min(r, max_channel), min(g, max_channel), min(b, max_channel))
    return rgb


def dark_ink_grade_rgba(image: Image.Image, *, target_mean: int = 78, max_channel: int = 164) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    rgb = rgba.convert("RGB")
    rgb = dark_ink_grade_rgb(rgb, target_mean=target_mean, max_channel=max_channel)
    base = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    base.paste(rgb)
    base.putalpha(alpha)
    return base


def recolor_purple_to_jade(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    px = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if r > 70 and b > 70 and g < max(r, b) * 0.78:
                luma = int((r * 0.21 + g * 0.72 + b * 0.07) * 0.42)
                nr = max(5, min(30, luma // 4))
                ng = max(26, min(86, luma + 18))
                nb = max(24, min(80, luma + 14))
                px[x, y] = (nr, ng, nb, min(a, 158))
    return rgba


def _fx_palette_for_name(name: str) -> tuple[tuple[int, int, int], tuple[int, int, int]]:
    key = name.lower()
    if "enemy_" in key:
        return (246, 62, 24), (222, 164, 58)
    if "thunder" in key or "bolt" in key:
        return (116, 188, 255), (218, 186, 82)
    if "rain" in key:
        return (76, 198, 224), (78, 138, 196)
    if "snow" in key:
        return (170, 224, 236), (118, 178, 226)
    if "sand" in key:
        return (208, 158, 74), (144, 100, 44)
    if "fog" in key:
        return (128, 154, 146), (88, 120, 112)
    if "fire" in key:
        return (236, 92, 42), (220, 156, 58)
    if "wind" in key:
        return (86, 216, 164), (112, 182, 210)
    if "clear" in key:
        return (72, 126, 112), (176, 144, 78)
    return (116, 188, 255), (218, 186, 82)


def clean_fx_spill(image: Image.Image, target_name: str) -> Image.Image:
    primary, secondary = _fx_palette_for_name(target_name)
    rgba = image.convert("RGBA")
    px = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            pure_key = r > 205 and b > 205 and g < 96
            if pure_key and a < 245:
                px[x, y] = (0, 0, 0, 0)
                continue
            magenta_spill = (
                r > 96
                and b > 106
                and g < max(r, b) * 0.74
                and r - g > 34
                and b - g > 34
            )
            if not magenta_spill:
                continue
            luma = max(0.0, min(1.0, (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0))
            use_secondary = luma > 0.58 or ("sand" in target_name or "clear" in target_name)
            target = secondary if use_secondary else primary
            warm = 0.24 if "enemy_" in target_name or "fire" in target_name else 0.12
            nr = int(target[0] * (0.62 + luma * 0.42) + secondary[0] * warm)
            ng = int(target[1] * (0.62 + luma * 0.42) + secondary[1] * warm)
            nb = int(target[2] * (0.62 + luma * 0.42) + secondary[2] * warm)
            new_alpha = int(a * (0.58 if pure_key else 0.82))
            px[x, y] = (min(nr, 255), min(ng, 255), min(nb, 255), max(0, min(new_alpha, 255)))
    return rgba


def tune_weather_decal_readability(image: Image.Image, target_name: str) -> Image.Image:
    key = target_name.lower()
    if "weather_decal_" not in key:
        return image
    if not any(name in key for name in ("clear", "wind", "snow")):
        return image
    rgba = image.convert("RGBA")
    px = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            luma = max(0.0, min(1.0, (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0))
            if "clear" in key:
                jade = (18, 58, 52)
                gold = (136, 112, 58)
                target = gold if luma > 0.46 and r >= g else jade
                strength = 0.68
                alpha_scale = 0.46 if (r > 86 and b > 78 and g < max(r, b) * 0.88) else 0.58
                nr = int(r * (1.0 - strength) + target[0] * strength)
                ng = int(g * (1.0 - strength) + target[1] * strength)
                nb = int(b * (1.0 - strength) + target[2] * strength)
                px[x, y] = (nr, ng, nb, int(a * alpha_scale))
            elif "wind" in key:
                ink_jade = (28, 108, 88)
                cold_jade = (74, 154, 132)
                target = cold_jade if luma > 0.42 else ink_jade
                strength = 0.54
                nr = int(r * (1.0 - strength) + target[0] * strength)
                ng = int(g * (1.0 - strength) + target[1] * strength)
                nb = int(b * (1.0 - strength) + target[2] * strength)
                px[x, y] = (nr, ng, nb, int(a * 0.66))
            elif "snow" in key:
                frost = (126, 178, 190)
                blue_gray = (82, 116, 142)
                target = frost if luma > 0.44 else blue_gray
                strength = 0.48
                nr = int(r * (1.0 - strength) + target[0] * strength)
                ng = int(g * (1.0 - strength) + target[1] * strength)
                nb = int(b * (1.0 - strength) + target[2] * strength)
                px[x, y] = (nr, ng, nb, int(a * 0.74))
    return rgba


def fit_alpha_rect(
    image: Image.Image,
    size: tuple[int, int],
    *,
    padding: int = 4,
    stretch: bool = False,
    recolor_jade: bool = False,
) -> Image.Image:
    clean = remove_magenta(image)
    if recolor_jade:
        clean = recolor_purple_to_jade(clean)
    clean = trim_alpha(clean, padding=max(padding, image.width // 96))
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    fit_size = (max(1, size[0] - padding * 2), max(1, size[1] - padding * 2))
    if stretch:
        clean = clean.resize(fit_size, Image.Resampling.LANCZOS)
    else:
        clean = ImageOps.contain(clean, fit_size, Image.Resampling.LANCZOS)
    canvas.alpha_composite(clean, ((size[0] - clean.width) // 2, (size[1] - clean.height) // 2))
    return canvas


def fit_reward_card_frame(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    source = image.convert("RGBA")
    width, height = source.size
    target_ratio = size[0] / size[1]
    crop_w = min(width, int(height * target_ratio))
    crop_h = min(height, int(width / target_ratio))
    left = (width - crop_w) // 2
    top = (height - crop_h) // 2
    return source.crop((left, top, left + crop_w, top + crop_h)).resize(size, Image.Resampling.LANCZOS)


def selected(args: argparse.Namespace, *names: str) -> bool:
    return not args.only or any(name in args.only for name in names)


def save_outputs_from_grid(
    image: Image.Image,
    *,
    cols: int,
    rows: int,
    outputs: list[tuple[Path, int | tuple[int, int], str]] | list[tuple[str, int | tuple[int, int], str]],
    raw_path: Path,
    prompt: str,
    manifest: list[dict],
    category: str,
    key_prefix: str,
    fill_ratio: float = 0.88,
    recolor_rect_jade: bool = True,
) -> None:
    cells = slice_atlas(image, cols=cols, rows=rows)
    for index, (target, size, desc) in enumerate(outputs):
        out = target if isinstance(target, Path) else HUD_ROOT / target
        if isinstance(size, tuple):
            icon = fit_alpha_rect(cells[index], size, padding=2, stretch=False, recolor_jade=recolor_rect_jade)
        else:
            icon = fit_square(cells[index], size, anchor="center", fill_ratio=fill_ratio)
        save_runtime_image(icon, out)
        save_prompt(out.with_suffix(".prompt.txt"), prompt)
        manifest.append({"category": category, "key": f"{key_prefix}:{desc}", "raw": str(raw_path), "runtime": str(out)})


def fit_fx_asset(image: Image.Image, size: int | tuple[int, int], target_name: str, *, fill_ratio: float = 0.92) -> Image.Image:
    clean = clean_fx_spill(remove_magenta(image), target_name)
    clean = trim_alpha(clean, padding=max(6, image.width // 96))
    if isinstance(size, tuple):
        canvas = Image.new("RGBA", size, (0, 0, 0, 0))
        fit_size = (max(1, size[0] - 4), max(1, size[1] - 4))
        clean = ImageOps.contain(clean, fit_size, Image.Resampling.LANCZOS)
        canvas.alpha_composite(clean, ((size[0] - clean.width) // 2, (size[1] - clean.height) // 2))
    else:
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        clean.thumbnail((max(1, int(size * fill_ratio)), max(1, int(size * fill_ratio))), Image.Resampling.LANCZOS)
        canvas.alpha_composite(clean, ((size - clean.width) // 2, (size - clean.height) // 2))
    canvas = clean_fx_spill(canvas, target_name)
    return tune_weather_decal_readability(canvas, target_name)


def save_fx_outputs_from_grid(
    image: Image.Image,
    *,
    cols: int,
    rows: int,
    outputs: list[tuple[Path, int | tuple[int, int], str]],
    raw_path: Path,
    prompt: str,
    manifest: list[dict],
    category: str,
    key_prefix: str,
    fill_ratio: float = 0.92,
) -> None:
    cells = slice_atlas(image, cols=cols, rows=rows)
    for index, (out, size, desc) in enumerate(outputs):
        fx = fit_fx_asset(cells[index], size, out.name, fill_ratio=fill_ratio)
        save_runtime_image(fx, out)
        save_prompt(out.with_suffix(".prompt.txt"), prompt)
        manifest.append({"category": category, "key": f"{key_prefix}:{desc}", "raw": str(raw_path), "runtime": str(out)})


def safe_terrain_cell(cell: Image.Image) -> Image.Image:
    clean = remove_magenta(cell.convert("RGBA"))
    bbox = clean.getchannel("A").getbbox()
    canvas = Image.new("RGBA", (TERRAIN_PROP_CELL, TERRAIN_PROP_CELL), (0, 0, 0, 0))
    if bbox is None:
        return canvas
    content = clean.crop(bbox)
    content.thumbnail((TERRAIN_PROP_CELL - 28, TERRAIN_PROP_CELL - 28), Image.Resampling.LANCZOS)
    while alpha_coverage(content) > TERRAIN_PROP_MAX_COVERAGE and min(content.size) > 18:
        next_size = (max(1, int(content.width * 0.92)), max(1, int(content.height * 0.92)))
        content = content.resize(next_size, Image.Resampling.LANCZOS)
    canvas.alpha_composite(content, ((TERRAIN_PROP_CELL - content.width) // 2, (TERRAIN_PROP_CELL - content.height) // 2))
    return canvas


def accent_terrain_cell(cell: Image.Image, stage_id: str, col: int, row: int) -> Image.Image:
    first, second = PALETTE_ACCENTS.get(stage_id, ((100, 210, 180), (210, 180, 96)))
    out = cell.copy()
    draw = ImageDraw.Draw(out, "RGBA")
    if col == 0 and row == 0:
        draw.line((35, 72, 94, 48), fill=(*first, 118), width=2)
        draw.arc((31, 38, 98, 91), 178, 302, fill=(*second, 84), width=2)
    elif col == 1 and row == 0:
        draw.ellipse((44, 51, 83, 76), outline=(*first, 112), width=3)
        draw.line((53, 82, 77, 91), fill=(*second, 96), width=2)
    elif col == 2 and row == 0:
        draw.line((38, 88, 90, 42), fill=(*first, 150), width=3)
        draw.arc((30, 34, 100, 98), 205, 325, fill=(*second, 105), width=2)
    elif col == 0 and row == 1:
        draw.line((36, 76, 96, 50), fill=(*first, 126), width=2)
        draw.line((50, 88, 77, 66), fill=(*second, 82), width=2)
    elif col == 1 and row == 1:
        draw.arc((34, 44, 96, 88), 10, 170, fill=(*second, 110), width=3)
        draw.line((44, 66, 90, 66), fill=(*first, 92), width=2)
    elif col == 2 and row == 1:
        draw.rectangle((42, 43, 86, 85), outline=(*second, 135), width=3)
        draw.line((45, 72, 82, 48), fill=(*first, 120), width=2)
    elif col == 0 and row == 2:
        draw.arc((35, 43, 98, 91), 160, 285, fill=(*second, 112), width=3)
        draw.line((47, 53, 86, 74), fill=(*first, 86), width=2)
    elif col == 1 and row == 2:
        draw.polygon(((45, 63), (65, 42), (86, 64), (66, 87)), outline=(*first, 116), fill=None)
        draw.line((49, 80, 83, 48), fill=(*second, 90), width=2)
    else:
        draw.ellipse((36, 50, 93, 78), outline=(*first, 135), width=3)
        draw.line((46, 82, 84, 93), fill=(*second, 110), width=2)
    return out


def fit_terrain_props_atlas(image: Image.Image, stage_id: str) -> Image.Image:
    fitted = ImageOps.fit(
        image.convert("RGBA"),
        (TERRAIN_PROP_SIZE, TERRAIN_PROP_SIZE),
        method=Image.Resampling.LANCZOS,
        centering=(0.5, 0.5),
    )
    out = Image.new("RGBA", (TERRAIN_PROP_SIZE, TERRAIN_PROP_SIZE), (0, 0, 0, 0))
    for row in range(TERRAIN_PROP_GRID):
        for col in range(TERRAIN_PROP_GRID):
            box = (
                col * TERRAIN_PROP_CELL,
                row * TERRAIN_PROP_CELL,
                (col + 1) * TERRAIN_PROP_CELL,
                (row + 1) * TERRAIN_PROP_CELL,
            )
            cell = safe_terrain_cell(fitted.crop(box))
            cell = accent_terrain_cell(cell, stage_id, col, row)
            out.alpha_composite(cell, (col * TERRAIN_PROP_CELL, row * TERRAIN_PROP_CELL))
    return remove_magenta(out)


def save_prompt(path: Path, prompt: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(prompt.strip() + "\n", encoding="utf-8")


def save_runtime_image(image: Image.Image, out: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    image.save(out)


def copy_seed_raw_if_available(raw_path: Path, source: Path) -> bool:
    if raw_path.exists() or not source.exists():
        return False
    raw_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, raw_path)
    return True


def load_seed_or_request_image(
    args: argparse.Namespace,
    *,
    raw_path: Path,
    seed_key: str,
    prompt: str,
    size: str,
    label: str,
) -> tuple[Image.Image, bool]:
    seed_source = LEGACY_RAW_SOURCES.get(seed_key)
    if seed_source is not None and not args.force:
        copied = copy_seed_raw_if_available(raw_path, seed_source)
        if copied:
            print(f"{label} seeded {raw_path} from existing image2 raw", flush=True)
    return load_or_request_image(args, raw_path=raw_path, prompt=prompt, size=size, label=label)


def atomic_save_image(image: Image.Image, out: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    tmp = out.with_name(f"{out.name}.tmp")
    image.save(tmp, format="PNG")
    tmp.replace(out)


def make_actor_prompt(job: ActorJob) -> str:
    detail = ACTOR_PROMPT_DETAILS.get(
        job.key,
        {
            "silhouette": "compact readable full-body silhouette",
            "signal": job.accent,
            "motion": "idle, walk, and combat frame source stays readable after runtime frame generation",
            "avoid": "generic fantasy design, unclear silhouette, overdecorated details",
        },
    )
    return f"""
{STYLE_BASE}
{COHESION_RULES}
{ACTOR_COHESION_RULES}
{CHROMA_RULE}

Asset type: 2D game actor sprite source for runtime resizing to 64px.
Subject: {job.prompt_subject}.
View: 3/4 top-down, full body visible, ground contact anchor, hover center, or bottom anchor clear as appropriate, readable as a tiny 64px unit.
Style: clean hand-painted 2D sprite, dark ink outline, Chinese xianxia silhouette, old-gold/jade rim light, compact shape.
Accent: {job.accent}. The accent must mark the gameplay threat part only.
Silhouette contract: {detail['silhouette']}.
Gameplay signal contract: {detail['signal']}.
Animation-readiness contract: {detail['motion']}. Make the pose suitable for deterministic idle/walk/combat frame variants.
Composition: one isolated full-body character centered on the canvas, body fills the central 62 percent, generous magenta padding.
Contrast: use a readable dark silhouette with cold jade rim light so the sprite survives downscaling to 64px on dark maps.
64px silhouette test: the actor must still be recognizable as this exact role when viewed as a black shape plus one accent color.
Constraints: no background, no shadow, no UI, no text, no labels, no western armor, no gothic demon design, no photoreal portrait, no anime bust crop, no extra characters, no props detached far from body.
Avoid specifically: {detail['avoid']}.
""".strip()


def actor_frames(static: Image.Image, size: int, accent=(96, 205, 178)) -> dict[str, list[Image.Image]]:
    result: dict[str, list[Image.Image]] = {"idle": [], "walk": [], "combat": []}
    clean = static.convert("RGBA")
    for i in range(4):
        for prefix in result:
            frame = Image.new("RGBA", (size, size), (0, 0, 0, 0))
            src = clean.copy()
            if prefix == "walk":
                offset_x = [-2, 1, 2, -1][i] if size >= 64 else [-1, 0, 1, 0][i]
                offset_y = [0, -1, 0, 1][i] if size >= 64 else [0, 0, 0, 1][i]
                frame.alpha_composite(src, (offset_x, offset_y))
                draw = ImageDraw.Draw(frame)
                draw.ellipse((size * 0.26, size * 0.78, size * 0.74, size * 0.86), fill=(*accent, 34))
            elif prefix == "combat":
                scale = [1.0, 1.04, 1.08, 1.02][i]
                resized = src.resize((max(1, int(size * scale)), max(1, int(size * scale))), Image.Resampling.BICUBIC)
                frame.alpha_composite(resized, ((size - resized.width) // 2, size - resized.height - max(1, size // 18)))
                draw = ImageDraw.Draw(frame)
                arc_box = (size * 0.18, size * 0.17, size * 0.82, size * 0.82)
                draw.arc(arc_box, 205, 330, fill=(*accent, 165), width=max(1, size // 24))
            else:
                offset_y = [0, -1, 0, 1][i] if size >= 64 else [0, 0, 0, 1][i]
                frame.alpha_composite(src, (0, offset_y))
            result[prefix].append(frame)
    return result


def write_frame_bundle(slug: str, static: Image.Image, size: int, accent=(96, 205, 178)) -> None:
    directory = FRAME_ROOT / slug
    directory.mkdir(parents=True, exist_ok=True)
    for old in directory.glob("*.png"):
        old.unlink()
    for prefix, frames in actor_frames(static, size, accent).items():
        for index, frame in enumerate(frames):
            frame.save(directory / f"{prefix}_{index:02d}.png")


def should_stop_for_limit(args: argparse.Namespace, generated_count: int) -> bool:
    return args.max_requests is not None and generated_count >= args.max_requests


def load_or_request_image(
    args: argparse.Namespace,
    *,
    raw_path: Path,
    prompt: str,
    size: str,
    label: str,
) -> tuple[Image.Image, bool]:
    if args.force or not raw_path.exists():
        if args.reuse_only:
            raise RuntimeError(f"raw image is missing for {label}: {raw_path}")
        print(f"{label} -> {raw_path}", flush=True)
        image = request_image(prompt, size=size, timeout=args.timeout, retries=args.retries, sleep_seconds=args.retry_sleep)
        atomic_save_image(image, raw_path)
        return image, True
    print(f"{label} reuse {raw_path}", flush=True)
    return Image.open(raw_path).convert("RGBA"), False


def record_prompt_only(manifest: list[dict], *, category: str, key: str, prompt_path: Path, prompt: str) -> None:
    save_prompt(prompt_path, prompt)
    manifest.append({"category": category, "key": key, "prompt": str(prompt_path), "mode": "prompt_only"})


def image2_asset_plan(args: argparse.Namespace | None = None) -> list[dict[str, Path | str]]:
    rows: list[dict[str, Path | str]] = []
    for stage_id, info in STAGE_PROMPTS.items():
        if args is not None and args.only and stage_id not in args.only:
            continue
        stage_dir = MAP_ROOT / stage_id
        for asset_name, runtime_name in (
            ("room_background", "room_background.png"),
            ("tileset", "tileset.png"),
            ("terrain_props", "terrain_props.png"),
        ):
            if args is not None and args.only_asset and asset_name not in args.only_asset:
                continue
            rows.append(
                {
                    "category": "map",
                    "key": f"{stage_id}:{asset_name}",
                    "raw": RAW_ROOT / "maps" / f"{stage_id}_{asset_name}.image2_raw.png",
                    "runtime": stage_dir / runtime_name,
                    "prompt": RAW_ROOT / "maps" / f"{stage_id}_{asset_name}.prompt.txt",
                }
            )
    for job in ACTOR_JOBS:
        if args is not None and args.only and job.key not in args.only and job.slug not in args.only:
            continue
        for filename, _size in job.outputs:
            rows.append(
                {
                    "category": "actor",
                    "key": f"{job.key}:{filename}",
                    "raw": RAW_ROOT / "actors" / f"{job.slug}.image2_raw.png",
                    "runtime": SPRITE_ROOT / filename,
                    "prompt": RAW_ROOT / "actors" / f"{job.slug}.prompt.txt",
                }
            )
    actor_raw_by_key = {job.key: RAW_ROOT / "actors" / f"{job.slug}.image2_raw.png" for job in ACTOR_JOBS}
    actor_prompt_by_key = {job.key: RAW_ROOT / "actors" / f"{job.slug}.prompt.txt" for job in ACTOR_JOBS}
    for alias, source_key in ACTOR_ALIAS_SOURCES.items():
        if args is not None and args.only and alias not in args.only and source_key not in args.only:
            continue
        raw = actor_raw_by_key.get(source_key, RAW_ROOT / "actors" / f"{source_key}.image2_raw.png")
        prompt = actor_prompt_by_key.get(source_key, raw.with_suffix(".prompt.txt"))
        rows.append(
            {
                "category": "actor",
                "key": f"{source_key}:alias:{alias}_64.png",
                "raw": raw,
                "runtime": SPRITE_ROOT / f"{alias}_64.png",
                "prompt": prompt,
            }
        )
    icon_plan: list[tuple[str, Path, list[Path]]] = [
        ("weather_icon_atlas_4x2", RAW_ROOT / "icons" / "weather_icon_atlas_4x2.image2_raw.png", [HUD_ROOT / filename for filename, _size, _desc in WEATHER_ICON_CELLS]),
        ("hud_core_icon_atlas_2x2", RAW_ROOT / "icons" / "hud_core_icon_atlas_2x2.image2_raw.png", [path for path, _size, _desc in HUD_CORE_CELLS]),
        ("dao_heart_icon_atlas_3x1", RAW_ROOT / "icons" / "dao_heart_icon_atlas_3x1.image2_raw.png", [path for path, _size, _desc in DAO_HEART_CELLS]),
        ("path_choice_icon_atlas_3x2", RAW_ROOT / "icons" / "path_choice_icon_atlas_3x2.image2_raw.png", [path for path, _size, _desc in PATH_ICON_CELLS]),
        ("spell_qer_icon_atlas_2x2", RAW_ROOT / "icons" / "spell_qer_icon_atlas_2x2.image2_raw.png", [HUD_ROOT / filename for filename, _size, _desc in SPELL_QER_CELLS]),
        ("wood_earth_projectile_impact_atlas_4x4", RAW_ROOT / "icons" / "wood_earth_projectile_impact_atlas_4x4.image2_raw.png", [path for path, _size, _desc in VFX_4X4_CELLS] + [SPRITE_ROOT / "projectile_wood_16.png", SPRITE_ROOT / "projectile_earth_16.png"]),
        ("spell_icon_atlas_4x4", RAW_ROOT / "icons" / "spell_icon_atlas_4x4.image2_raw.png", [HUD_ROOT / filename for filename, _desc in SPELL_CELLS]),
        ("companion_artifact_icon_atlas_2x2", RAW_ROOT / "icons" / "companion_artifact_icon_atlas_2x2.image2_raw.png", [HUD_ROOT / filename for filename, _size, _desc in COMPANION_CELLS]),
        ("status_icon_atlas_5x4", RAW_ROOT / "icons" / "status_icon_atlas_5x4.image2_raw.png", [path for path, _size, _desc in STATUS_ICON_CELLS]),
        (
            "element_icon_atlas_4x2",
            RAW_ROOT / "icons" / "element_icon_atlas_4x2.image2_raw.png",
            [path for _key, _desc, outputs in ELEMENT_ICON_CELLS for path, _size in outputs],
        ),
        ("utility_karma_icon_atlas_5x4", RAW_ROOT / "icons" / "utility_karma_icon_atlas_5x4.image2_raw.png", [path for path, _size, _desc in UTILITY_KARMA_ICON_CELLS]),
        ("hud_rune_surface_atlas_5x4", RAW_ROOT / "icons" / "hud_rune_surface_atlas_5x4.image2_raw.png", [path for path, _size, _desc in HUD_RUNE_SURFACE_CELLS]),
        ("talent_tag_icon_atlas_5x3", RAW_ROOT / "icons" / "talent_tag_icon_atlas_5x3.image2_raw.png", [path for path, _size, _desc in TALENT_TAG_ICON_CELLS]),
        ("weather_ground_decal_atlas_4x2", RAW_ROOT / "icons" / "weather_ground_decal_atlas_4x2.image2_raw.png", [path for path, _size, _desc in WEATHER_GROUND_DECAL_CELLS]),
        ("weather_overlay_particle_atlas_4x2", RAW_ROOT / "icons" / "weather_overlay_particle_atlas_4x2.image2_raw.png", [path for path, _size, _desc in WEATHER_OVERLAY_PARTICLE_CELLS]),
        ("enemy_projectile_trail_atlas_4x2", RAW_ROOT / "icons" / "enemy_projectile_trail_atlas_4x2.image2_raw.png", [path for path, _size, _desc in ENEMY_PROJECTILE_TRAIL_CELLS]),
        ("thunder_strike_decal_atlas_2x2", RAW_ROOT / "icons" / "thunder_strike_decal_atlas_2x2.image2_raw.png", [path for path, _size, _desc in THUNDER_STRIKE_DECAL_CELLS]),
        ("enemy_telegraph_atlas_3x2", RAW_ROOT / "icons" / "enemy_telegraph_atlas_3x2.image2_raw.png", [path for path, _size, _desc in ENEMY_TELEGRAPH_CELLS]),
        ("combat_action_fx_atlas_4x4", RAW_ROOT / "icons" / "combat_action_fx_atlas_4x4.image2_raw.png", [path for path, _size, _desc in COMBAT_ACTION_FX_CELLS]),
        ("overlay_ornament_fx_atlas_4x2", RAW_ROOT / "icons" / "overlay_ornament_fx_atlas_4x2.image2_raw.png", [path for path, _size, _desc in OVERLAY_ORNAMENT_FX_CELLS]),
    ]
    for key, outputs, _description in SINGLE_ICON_REUSE_JOBS:
        icon_plan.append((key, RAW_ROOT / "icons" / f"{key}.image2_raw.png", [out for out, _size in outputs]))
    for key, raw, runtimes in icon_plan:
        if args is not None and args.only and key not in args.only and raw.stem not in args.only:
            continue
        for runtime in runtimes:
            rows.append(
                {
                    "category": "icon",
                    "key": f"{key}:{runtime.name}",
                    "raw": raw,
                    "runtime": runtime,
                    "prompt": raw.with_suffix(".prompt.txt"),
                }
            )
    projectile_raw = RAW_ROOT / "icons" / "projectile_impact_core_atlas_4x6.image2_raw.png"
    if args is None or not args.only or "projectile_impact_core_atlas_4x6" in args.only or "projectile_impacts" in args.only:
        for element, _desc in PROJECTILE_ELEMENTS_4X6:
            for index in range(4):
                rows.append(
                    {
                        "category": "icon",
                        "key": f"projectile_impact_core_atlas_4x6:{element}:fly_{index:02d}.png",
                        "raw": projectile_raw,
                        "runtime": FRAME_ROOT / f"projectile_{element}" / f"fly_{index:02d}.png",
                        "prompt": projectile_raw.with_suffix(".prompt.txt"),
                    }
                )
            for index in range(4):
                rows.append(
                    {
                        "category": "icon",
                        "key": f"projectile_impact_core_atlas_4x6:{element}:impact_{index:02d}.png",
                        "raw": projectile_raw,
                        "runtime": FRAME_ROOT / f"impact_{element}" / f"impact_{index:02d}.png",
                        "prompt": projectile_raw.with_suffix(".prompt.txt"),
                    }
                )
            rows.append(
                {
                    "category": "icon",
                    "key": f"projectile_impact_core_atlas_4x6:projectile_{element}_16.png",
                    "raw": projectile_raw,
                    "runtime": SPRITE_ROOT / f"projectile_{element}_16.png",
                    "prompt": projectile_raw.with_suffix(".prompt.txt"),
                }
            )
    for filename in UI_JOBS:
        key = filename.removesuffix(".png")
        if args is not None and args.only and filename not in args.only and key not in args.only:
            continue
        raw = RAW_ROOT / "ui" / f"{key}.image2_raw.png"
        rows.append(
            {
                "category": "ui",
                "key": key,
                "raw": raw,
                "runtime": UI_ROOT / filename,
                "prompt": raw.with_suffix(".prompt.txt"),
            }
        )
    quality_talent_key = "quality_talent_surface_atlas_5x4"
    quality_talent_raw = RAW_ROOT / "ui" / "quality_talent_surface_atlas_5x4.image2_raw.png"
    if args is None or not args.only or quality_talent_key in args.only or "quality_talent_surfaces" in args.only:
        for runtime, _size, _desc in QUALITY_TALENT_SURFACE_CELLS:
            rows.append(
                {
                    "category": "ui",
                    "key": f"{quality_talent_key}:{runtime.name}",
                    "raw": quality_talent_raw,
                    "runtime": runtime,
                    "prompt": quality_talent_raw.with_suffix(".prompt.txt"),
                }
            )
    for key, runtime, _size, _description in REWARD_CARD_REUSE_JOBS:
        if args is not None and args.only and key not in args.only:
            continue
        raw = RAW_ROOT / "ui" / f"{key}.image2_raw.png"
        rows.append(
            {
                "category": "ui",
                "key": key,
                "raw": raw,
                "runtime": runtime,
                "prompt": raw.with_suffix(".prompt.txt"),
            }
        )
    for key, runtime, _size, _description in REWARD_OVERLAY_REUSE_JOBS:
        if args is not None and args.only and key not in args.only:
            continue
        raw = RAW_ROOT / "ui" / f"{key}.image2_raw.png"
        rows.append(
            {
                "category": "ui",
                "key": key,
                "raw": raw,
                "runtime": runtime,
                "prompt": raw.with_suffix(".prompt.txt"),
            }
        )
    for key, runtime, _size, _padding, _description in REWARD_QUALITY_FX_REUSE_JOBS:
        if args is not None and args.only and key not in args.only and "reward_quality_fx" not in args.only:
            continue
        raw = RAW_ROOT / "ui" / f"{key}.image2_raw.png"
        rows.append(
            {
                "category": "ui",
                "key": key,
                "raw": raw,
                "runtime": runtime,
                "prompt": raw.with_suffix(".prompt.txt"),
            }
        )
    for key, runtime, _size, _padding, _stretch, _transparent, _description in CORE_UI_SURFACE_REUSE_JOBS:
        if args is not None and args.only and key not in args.only:
            continue
        raw = RAW_ROOT / "ui" / f"{key}.image2_raw.png"
        rows.append(
            {
                "category": "ui",
                "key": key,
                "raw": raw,
                "runtime": runtime,
                "prompt": raw.with_suffix(".prompt.txt"),
            }
        )
    for key, runtime, _size, _padding, _stretch, _description in LEFT_HUD_REUSE_JOBS:
        if args is not None and args.only and key not in args.only:
            continue
        raw = RAW_ROOT / "ui" / f"{key}.image2_raw.png"
        rows.append(
            {
                "category": "ui",
                "key": key,
                "raw": raw,
                "runtime": runtime,
                "prompt": raw.with_suffix(".prompt.txt"),
            }
        )
    return rows


def write_status_report(args: argparse.Namespace) -> None:
    rows = image2_asset_plan(args)
    payload = []
    for row in rows:
        raw = row["raw"]
        runtime = row["runtime"]
        prompt = row["prompt"]
        assert isinstance(raw, Path)
        assert isinstance(runtime, Path)
        assert isinstance(prompt, Path)
        payload.append(
            {
                "category": row["category"],
                "key": row["key"],
                "raw": str(raw),
                "raw_exists": raw.exists(),
                "runtime": str(runtime),
                "runtime_exists": runtime.exists(),
                "prompt": str(prompt),
                "prompt_exists": prompt.exists(),
                "image2_ready": raw.exists() and runtime.exists() and prompt.exists(),
            }
        )
    status_path = RAW_ROOT / "image2_unified_assets_status.json"
    summary_path = RAW_ROOT / "image2_unified_assets_summary.json"
    status_path.parent.mkdir(parents=True, exist_ok=True)
    status_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    missing_raw = sum(1 for row in payload if not row["raw_exists"])
    missing_runtime = sum(1 for row in payload if not row["runtime_exists"])
    missing_prompt = sum(1 for row in payload if not row["prompt_exists"])
    ready = sum(1 for row in payload if row["image2_ready"])
    category_summary: dict[str, dict[str, int]] = {}
    for row in payload:
        category = str(row["category"])
        bucket = category_summary.setdefault(
            category,
            {"tracked": 0, "image2_ready": 0, "missing_raw": 0, "missing_runtime": 0, "missing_prompt": 0},
        )
        bucket["tracked"] += 1
        bucket["image2_ready"] += int(bool(row["image2_ready"]))
        bucket["missing_raw"] += int(not bool(row["raw_exists"]))
        bucket["missing_runtime"] += int(not bool(row["runtime_exists"]))
        bucket["missing_prompt"] += int(not bool(row["prompt_exists"]))
    summary = {
        "tracked": len(payload),
        "image2_ready": ready,
        "missing_raw": missing_raw,
        "missing_runtime": missing_runtime,
        "missing_prompt": missing_prompt,
        "categories": category_summary,
        "note": "image2_ready means raw PNG, runtime PNG, and prompt file all exist. runtime_exists alone may still be a fallback asset.",
    }
    summary_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote status: {status_path}")
    print(f"Wrote summary: {summary_path}")
    print(
        f"Tracked assets: {len(payload)}; image2 ready: {ready}; "
        f"missing raw: {missing_raw}; missing runtime: {missing_runtime}; missing prompt: {missing_prompt}"
    )


def run_actors(args: argparse.Namespace, manifest: list[dict]) -> int:
    generated_count = 0
    jobs = [job for job in ACTOR_JOBS if not args.only or job.key in args.only or job.slug in args.only]
    for job in jobs:
        if should_stop_for_limit(args, generated_count):
            break
        raw_path = RAW_ROOT / "actors" / f"{job.slug}.image2_raw.png"
        prompt_path = RAW_ROOT / "actors" / f"{job.slug}.prompt.txt"
        prompt = make_actor_prompt(job)
        if args.write_prompts_only:
            record_prompt_only(manifest, category="actor", key=job.key, prompt_path=prompt_path, prompt=prompt)
            continue
        image, requested = load_or_request_image(
            args,
            raw_path=raw_path,
            prompt=prompt,
            size=job.size,
            label=f"[actors] requesting {job.key}",
        )
        generated_count += int(requested)
        save_prompt(prompt_path, prompt)
        frame_source: Image.Image | None = None
        for filename, size in job.outputs:
            out = SPRITE_ROOT / filename
            fitted = fit_square(image, size, anchor="bottom", fill_ratio=0.86)
            save_runtime_image(fitted, out)
            save_prompt(out.with_suffix(".prompt.txt"), prompt)
            if size == job.frame_size and frame_source is None:
                frame_source = fitted
            manifest.append({"category": "actor", "key": job.key, "raw": str(raw_path), "runtime": str(out)})
        if frame_source is None:
            frame_source = fit_square(image, job.frame_size, anchor="bottom", fill_ratio=0.86)
        write_frame_bundle(job.frame_slug, frame_source, job.frame_size)

    # Keep archetype fallback sprites visually aligned with the identity pass.
    for source_slug, aliases in ACTOR_ALIAS_COPY.items():
        source_static = SPRITE_ROOT / f"{source_slug}_64.png"
        source_frames = FRAME_ROOT / source_slug
        if not source_static.exists():
            continue
        for alias in aliases:
            shutil.copyfile(source_static, SPRITE_ROOT / f"{alias}_64.png")
            alias_dir = FRAME_ROOT / alias
            if alias_dir.exists():
                shutil.rmtree(alias_dir)
            if source_frames.exists():
                shutil.copytree(source_frames, alias_dir)
    return generated_count


def make_map_prompt(stage_id: str, info: dict[str, str]) -> str:
    return f"""
{STYLE_BASE}
{COHESION_RULES}
{MAP_COHESION_RULES}
{MAP_RULE}

Asset type: runtime combat map background, 16:9.
Stage: {info['label']} / {stage_id}.
Theme: {info['theme']}.
Accent: {info['accent']}.
Style details: Chinese ink-wash top-down game ground, black jade material, brush texture, elegant xianxia cultivation atmosphere.
Gameplay readability: low-noise center, high-quality edges, no baked actors or collidable props.
""".strip()


def make_tileset_prompt(stage_id: str, info: dict[str, str]) -> str:
    return f"""
{STYLE_BASE}
{COHESION_RULES}
{MAP_COHESION_RULES}
{TILESET_RULE}

Asset type: runtime top-row tileset source.
Stage: {info['label']} / {stage_id}.
Theme material: {info['tiles']}.
Accent: {info['accent']}.
Style: clean hand-painted HD xianxia map tile asset, top-down with slight material read, crisp silhouettes at 32px, black-jade base, cold jade rim, old-gold linework only where meaningful.
Tile order contract: cell 1 base floor, cell 2 alternate floor, cell 3 compact blocker mark, cell 4 compact non-colliding decoration.
Constraints: no western fantasy dungeon tiles, no castle floors, no gothic stonework, no text, no labels, no UI, no characters, no extra tile concepts below the top row.
""".strip()


def make_terrain_props_prompt(stage_id: str, info: dict[str, str]) -> str:
    return f"""
{STYLE_BASE}
{COHESION_RULES}
{MAP_COHESION_RULES}
{TERRAIN_PROPS_RULE}

Asset type: runtime transparent terrain prop atlas.
Stage: {info['label']} / {stage_id}.
Theme prop language: {info['props']}.
Accent: {info['accent']}. High saturation appears only as tiny gameplay-readable traces, never as full-cell glow.
Grid: exactly 3 columns by 3 rows, one centered prop per cell, no visible grid lines.
Cell order:
1. [0,0] thin embedded elemental vein or wet qi crack
2. [1,0] small moss, spirit grass, ash, dust, or mineral cluster
3. [2,0] compact low stone/slab/debris accent
4. [0,1] alternate thin glowing vein or elemental trace
5. [1,1] shallow stain, puddle rim, scorch, dust swirl, or wind streak
6. [2,1] compact low debris or flat glyph fragment
7. [0,2] compact realm-specific elemental scar or aura residue
8. [1,2] alternate low ground ornament with a different silhouette
9. [2,2] alternate stone/slab/debris accent for obstacle-adjacent dressing
Style: clean hand-painted HD xianxia map-prop style, subtle enough for dense combat, varied silhouettes, flat non-colliding ground details.
Constraints: no tall object, no large boulder, no wall, no pillar, no tree, no chest, no weapon, no character, no text, no label, no UI, no background scene.
""".strip()


def run_maps(args: argparse.Namespace, manifest: list[dict]) -> int:
    generated_count = 0
    for stage_id, info in STAGE_PROMPTS.items():
        if args.only and stage_id not in args.only:
            continue
        stage_dir = MAP_ROOT / stage_id
        map_jobs = [
            {
                "asset": "room_background",
                "size": "2048x1152",
                "raw": RAW_ROOT / "maps" / f"{stage_id}_room_background.image2_raw.png",
                "prompt_path": RAW_ROOT / "maps" / f"{stage_id}_room_background.prompt.txt",
                "runtime": stage_dir / "room_background.png",
                "stage_prompt": stage_dir / "room_background.prompt.txt",
                "prompt": make_map_prompt(stage_id, info),
            },
            {
                "asset": "tileset",
                "size": "1024x1024",
                "raw": RAW_ROOT / "maps" / f"{stage_id}_tileset.image2_raw.png",
                "prompt_path": RAW_ROOT / "maps" / f"{stage_id}_tileset.prompt.txt",
                "runtime": stage_dir / "tileset.png",
                "stage_prompt": stage_dir / "tileset.prompt.txt",
                "prompt": make_tileset_prompt(stage_id, info),
            },
            {
                "asset": "terrain_props",
                "size": "1024x1024",
                "raw": RAW_ROOT / "maps" / f"{stage_id}_terrain_props.image2_raw.png",
                "prompt_path": RAW_ROOT / "maps" / f"{stage_id}_terrain_props.prompt.txt",
                "runtime": stage_dir / "terrain_props.png",
                "stage_prompt": stage_dir / "terrain_props.prompt.txt",
                "prompt": make_terrain_props_prompt(stage_id, info),
            },
        ]
        for job in map_jobs:
            asset_name = str(job["asset"])
            raw_path = job["raw"]
            prompt = str(job["prompt"])
            prompt_path = job["prompt_path"]
            if args.only_asset and asset_name not in args.only_asset:
                continue
            if should_stop_for_limit(args, generated_count):
                return generated_count
            if args.write_prompts_only:
                save_prompt(job["stage_prompt"], prompt)
                record_prompt_only(
                    manifest,
                    category="map",
                    key=f"{stage_id}:{asset_name}",
                    prompt_path=prompt_path,
                    prompt=prompt,
                )
                continue
            image, requested = load_or_request_image(
                args,
                raw_path=raw_path,
                prompt=prompt,
                size=str(job["size"]),
                label=f"[maps] requesting {stage_id} {asset_name}",
            )
            generated_count += int(requested)
            runtime_path = job["runtime"]
            if asset_name == "room_background":
                fitted = ImageOps.fit(image.convert("RGB"), (1280, 720), method=Image.Resampling.LANCZOS, centering=(0.5, 0.5))
                fitted = dark_ink_grade_rgb(fitted, target_mean=70, max_channel=148)
                save_runtime_image(fitted, runtime_path)
                save_runtime_image(fitted, stage_dir / "qa_runtime_preview.png")
            elif asset_name == "tileset":
                fitted = ImageOps.fit(image.convert("RGBA"), (128, 128), method=Image.Resampling.LANCZOS, centering=(0.5, 0.0))
                fitted = dark_ink_grade_rgba(fitted, target_mean=74, max_channel=150)
                save_runtime_image(fitted, runtime_path)
            else:
                save_runtime_image(fit_terrain_props_atlas(image, stage_id), runtime_path)
            save_prompt(job["stage_prompt"], prompt)
            save_prompt(prompt_path, prompt)
            manifest.append({"category": "map", "key": f"{stage_id}:{asset_name}", "raw": str(raw_path), "runtime": str(runtime_path)})
    return generated_count


def atlas_prompt(cells: list[tuple[str, str]], *, cols: int, rows: int, title: str, cell_note: str) -> str:
    lines = [f"{index + 1}. {desc}" for index, (_filename, desc) in enumerate(cells)]
    return f"""
{STYLE_BASE}
{COHESION_RULES}
{ICON_COHESION_RULES}
{CHROMA_RULE}

Asset type: {title}, icon atlas.
Grid: exactly {cols} columns by {rows} rows, one centered icon per cell, no visible grid lines or borders.
Cell order: left to right, top to bottom.
{chr(10).join(lines)}
Style: clean HD Chinese xianxia HUD icon, circular jade-seal language, restrained old-gold rim, strong tiny-icon silhouette, readable at 48px and 96px.
Icon language: flat emblem-like xianxia talisman and seal silhouettes, not rendered physical inventory objects.
Rune strokes must be abstract marks only; icons must not include readable glyph text or written characters.
{cell_note}
Constraints: no text, no letters, no Chinese characters, no labels, no UI card background, no square item panel, no western dark-fantasy item render, no thick metal frame, no photoreal 3D object.
""".strip()


def make_weather_icon_prompt() -> str:
    return atlas_prompt(
        [(filename, desc) for filename, _size, desc in WEATHER_ICON_CELLS],
        cols=4,
        rows=2,
        title="combat weather HUD icons",
        cell_note="Weather icons must read as a family of compact celestial talisman emblems. Keep color roles distinct: clear jade-gold, rain water-cyan, thunder blue-white, fire orange-red, wind jade-cyan, fog pale blue-gray, snow icy cyan, sand old-gold.",
    )


def make_hud_core_prompt() -> str:
    return atlas_prompt(
        [(path.name, desc) for path, _size, desc in HUD_CORE_CELLS],
        cols=2,
        rows=2,
        title="core combat HUD pet artifact and status emblems",
        cell_note="These are transparent HUD emblems, not inventory loot renders. Keep all icons dark-jade based with cold jade rim and old-gold ritual linework; do not create square item cards.",
    )


def make_dao_heart_prompt() -> str:
    return atlas_prompt(
        [(path.name, desc) for path, _size, desc in DAO_HEART_CELLS],
        cols=3,
        rows=1,
        title="run setup Dao-heart selection icons",
        cell_note="The three icons must feel like one family but have distinct silhouettes: calm open seal, balanced lotus compass, sharp vow seal. They will sit on large setup cards at 128px, so keep the emblem bold and centered.",
    )


def make_path_icon_prompt() -> str:
    return atlas_prompt(
        [(path.name, desc) for path, _size, desc in PATH_ICON_CELLS],
        cols=3,
        rows=2,
        title="run path choice icons",
        cell_note="Use five distinct route-sign emblems and leave the sixth cell completely flat #FF00FF. These icons are only 48px at runtime, so shape identity must be stronger than texture detail.",
    )


def make_spell_qer_prompt() -> str:
    return atlas_prompt(
        [(filename, desc) for filename, _size, desc in SPELL_QER_CELLS],
        cols=2,
        rows=2,
        title="legacy Q/E/R spell HUD icons",
        cell_note="These four icons are the fixed slot icons and must match the same icon language as the semantic spell atlas. Do not draw the letters Q, E, or R.",
    )


def make_status_icon_prompt() -> str:
    return atlas_prompt(
        [(path.name, desc) for path, _size, desc in STATUS_ICON_CELLS],
        cols=5,
        rows=4,
        title="combat status and enemy identity icons",
        cell_note=(
            "Use one compact xianxia seal per cell. Debuffs use sharper cracked silhouettes; buffs use rounder upward silhouettes; "
            "identity icons use crest-like threat marks. Keep all icons readable at 32px, with dark-jade body and one tiny saturated semantic core."
        ),
    )


def make_element_icon_prompt() -> str:
    return atlas_prompt(
        [(key, desc) for key, desc, _outputs in ELEMENT_ICON_CELLS],
        cols=4,
        rows=2,
        title="five-element and soul element icons",
        cell_note=(
            "Each cell is one elemental jade-seal emblem. Fire/water/thunder/wood/earth/chaos/ice must be distinct by silhouette before color. "
            "Cell 8 should remain completely flat #FF00FF."
        ),
    )


def make_utility_karma_icon_prompt() -> str:
    return atlas_prompt(
        [(path.name, desc) for path, _size, desc in UTILITY_KARMA_ICON_CELLS],
        cols=5,
        rows=4,
        title="utility command, badge, spell slot, and karma dot icons",
        cell_note=(
            "These are tiny runtime UI marks. Keep them simple, dark-jade based, and silhouette-first. "
            "Cells that output 16px or 24px must be extra bold with no fine detail. Do not draw words."
        ),
    )


def make_hud_rune_surface_prompt() -> str:
    return atlas_prompt(
        [(path.name, desc) for path, _size, desc in HUD_RUNE_SURFACE_CELLS],
        cols=5,
        rows=4,
        title="HUD rune seals and compact combat surfaces",
        cell_note=(
            "Mix circular rune seals and thin HUD surfaces in one family: black jade base, cold jade rim, restrained old-gold linework. "
            "For rectangular cells, draw one centered horizontal UI strip with transparent #FF00FF around it, no words."
        ),
    )


def make_talent_tag_icon_prompt() -> str:
    return atlas_prompt(
        [(path.name, desc) for path, _size, desc in TALENT_TAG_ICON_CELLS],
        cols=5,
        rows=3,
        title="talent badges, quality tags, element tags, and realm icons",
        cell_note=(
            "Top-row badges and realm icons are compact jade-seal emblems. Tag backing cells are blank pill-shaped UI surfaces with no text. "
            "Keep them quiet enough for Chinese UI labels to sit on top at runtime."
        ),
    )


def make_projectile_impact_core_prompt() -> str:
    rows = "\n".join(
        f"Row {index + 1}: {element} - {desc}; first four cells are fly_00..03, then reuse the same visual language for the matching impact sequence in the later half."
        for index, (element, desc) in enumerate(PROJECTILE_ELEMENTS_4X6)
    )
    return f"""
{STYLE_BASE}
{COHESION_RULES}
{ICON_COHESION_RULES}
{CHROMA_RULE}

Asset type: runtime projectile and impact VFX atlas for combat sprites.
Grid: exactly 4 columns by 6 rows, one centered VFX frame per cell, no visible grid lines.
Rows 1-6 are projectile fly loops for: fire, thunder, ice, water, generic jade qi, chaos soul.
Each row has frames 00-03, compact forward-motion variation, readable at 16px.
After generation the same source will also define matching impact frames by row, so each projectile must contain enough elemental identity for a small burst version.
{rows}
Style: 2D dark Chinese ink-wash xianxia VFX, black ink silhouette first, tiny saturated elemental core second, crisp alpha-ready edge.
Gameplay rule: high saturation only in the projectile core or spark tips; no full-cell glow.
Avoid: full-screen explosion, smoke cloud filling the cell, western magic rune, sci-fi laser, photoreal render, text, numbers, watermark.
""".strip()


def make_weather_ground_decal_prompt() -> str:
    lines = "\n".join(
        f"{index + 1}. {desc}" for index, (_path, _size, desc) in enumerate(WEATHER_GROUND_DECAL_CELLS)
    )
    return f"""
{STYLE_BASE}
{COHESION_RULES}
{CHROMA_RULE}

Asset type: runtime weather ground decal atlas for a top-down 2D combat arena.
Grid: exactly 4 columns by 2 rows, one centered low ground decal per cell, no visible grid lines or borders.
Cell order: left to right, top to bottom.
{lines}
Visual language: flat ground-contact ink stains and shallow elemental residue, not icons and not UI.
Runtime use: decals are randomly placed on top-down battle floors at 40-90px display size, so the center must remain soft and non-blocking.
Style: dark Chinese ink-wash xianxia ground marks, black jade floor residue, cold jade rim light only where needed, restrained old-gold dust lines.
Gameplay rule: weather decals must never look like enemy danger zones; no target circles, no thick rings, no bright filled disks.
Composition: each decal occupies the central 58-72 percent of its cell with feathered transparent edges and strong alpha-ready silhouette.
Constraints: no text, no letters, no characters, no props, no stones taller than ground, no UI emblem, no western magic circle, no photoreal puddle, no full-cell glow, no watermark.
""".strip()


def make_weather_overlay_particle_prompt() -> str:
    lines = "\n".join(
        f"{index + 1}. {desc}" for index, (_path, _size, desc) in enumerate(WEATHER_OVERLAY_PARTICLE_CELLS)
    )
    return f"""
{STYLE_BASE}
{COHESION_RULES}
{CHROMA_RULE}

Asset type: runtime weather overlay particle atlas for a top-down 2D combat arena.
Grid: exactly 4 columns by 2 rows, one centered particle or wisp per cell, no visible grid lines or borders.
Cell order: left to right, top to bottom.
{lines}
Visual language: small airborne ink-wash weather marks, not UI icons and not ground decals.
Runtime use: particles are repeatedly spawned across a 1920x1080 combat camera, scaled from about 10px to 90px depending on weather; each cell must remain readable when small and soft when large.
Style: dark Chinese ink-wash xianxia weather, black jade shadow strokes, cold jade rim light, restrained old-gold dust only for sand, thunder, and clear motes.
Gameplay rule: overlay particles must never look like enemy bullets, loot, target markers, or UI badges; rain and wind must be directional brush marks, fog must be soft and non-blocking.
Composition: each particle occupies the central 46-70 percent of its cell with generous transparent padding and clean alpha-ready silhouette.
Constraints: no text, no letters, no characters, no creature, no weapon, no item icon, no circular badge, no western magic rune, no photoreal storm photo, no full-cell glow, no watermark.
""".strip()


def make_enemy_projectile_trail_prompt() -> str:
    lines = "\n".join(
        f"{index + 1}. {desc}" for index, (_path, _size, desc) in enumerate(ENEMY_PROJECTILE_TRAIL_CELLS)
    )
    return f"""
{STYLE_BASE}
{COHESION_RULES}
{CHROMA_RULE}

Asset type: runtime enemy projectile trail atlas for a top-down 2D combat arena.
Grid: exactly 4 columns by 2 rows, one horizontal projectile trail per cell, no visible grid lines or borders.
Cell order: left to right, top to bottom.
{lines}
Visual language: fast hostile spell tails in dark Chinese ink-wash xianxia style, made for tiny enemy bullets and boss barrages.
Runtime use: each trail is drawn behind an enemy projectile sprite at 24-72px length, rotated along projectile direction; left side should be the fading tail and right side the hot leading edge.
Style: black ink silhouette first, small saturated elemental core second, cold jade rim and old-gold talisman dust only where semantically useful.
Gameplay rule: high saturation must remain in the narrow core or spark tips; trails must support readability without becoming red danger telegraphs or player skill effects.
Composition: each trail occupies the central 70-84 percent of its cell width, thin vertical profile, feathered transparent edges, no cell-edge touching.
Constraints: no text, no letters, no character, no weapon, no item icon, no UI panel, no circular badge, no western magic rune, no sci-fi laser beam, no full-cell glow, no watermark.
""".strip()


def make_thunder_strike_decal_prompt() -> str:
    lines = "\n".join(
        f"{index + 1}. {desc}" for index, (_path, _size, desc) in enumerate(THUNDER_STRIKE_DECAL_CELLS)
    )
    return f"""
{STYLE_BASE}
{COHESION_RULES}
{CHROMA_RULE}

Asset type: runtime thunder strike VFX decal atlas for a top-down 2D combat arena.
Grid: exactly 2 columns by 2 rows, one centered VFX decal per cell, no visible grid lines or borders.
Cell order: left to right, top to bottom.
{lines}
Visual language: Chinese tribulation thunder, black ink strokes, old-gold warning seal fragments, blue-white lightning core.
Runtime use: warning and impact decals are scaled around 120-200px; the vertical bolt cell is stretched tall above the strike point.
Gameplay rule: warning must be readable but elegant, with transparent center so actors remain visible. Impact can be brighter but must fade at edges.
Composition: each asset fully separated from the #FF00FF background, generous padding, no cell-edge touching.
Constraints: no text, no letters, no Chinese characters, no UI panel, no western magic rune, no sci-fi laser, no white full-screen flash, no photoreal storm photo, no watermark.
""".strip()


def make_enemy_telegraph_prompt() -> str:
    lines = "\n".join(
        f"{index + 1}. {desc}" for index, (_path, _size, desc) in enumerate(ENEMY_TELEGRAPH_CELLS)
    )
    return f"""
{STYLE_BASE}
{COHESION_RULES}
{CHROMA_RULE}

Asset type: runtime enemy danger telegraph atlas for a top-down 2D roguelite combat arena.
Grid: exactly 3 columns by 2 rows, one centered warning decal per cell, no visible grid lines or borders.
Cell order: left to right, top to bottom.
{lines}
Visual language: red-orange danger talisman marks painted with Chinese ink, black jade smoke, sparse old-gold ritual ticks.
Gameplay rule: enemy warnings are allowed to be brighter than ambient art. They must stay readable over dark ink maps while preserving transparent centers for actors.
Shape rule: spawn cells are compact square/ring-like talisman marks; line cells are horizontal lanes pointing right; melee cell is a compact crescent/arc.
Style: high-saturation red-orange only on danger edges and tick marks, no solid filled red slabs, no rectangular debug bars.
Composition: each warning fully separated from the #FF00FF background, generous padding, no cell-edge touching.
Constraints: no text, no letters, no readable Chinese characters, no UI labels, no western magic circle, no sci-fi targeting reticle, no full opaque rectangle, no watermark.
""".strip()


def make_combat_action_fx_prompt() -> str:
    lines = "\n".join(
        f"{index + 1}. {desc}" for index, (_path, _size, desc) in enumerate(COMBAT_ACTION_FX_CELLS)
    )
    return f"""
{STYLE_BASE}
{COHESION_RULES}
{CHROMA_RULE}

Asset type: runtime combat action FX atlas for a 1920x1080 top-down 2D cultivation roguelite.
Grid: exactly 4 columns by 4 rows, one centered alpha-ready FX glyph per cell, no visible grid lines or borders.
Cell order: left to right, top to bottom.
{lines}
Visual language: dark Chinese ink-wash xianxia combat overlays, black jade mass first, cold jade rim second, old-gold ritual sparks third. Red-orange appears only on hostile windup threat cells, not on player slash or neutral backing.
Runtime use: assets are drawn over sprites and UI overlays at 12px to 640px; each cell must have a clean silhouette, transparent center where actors stand, generous padding, and no cell-edge touching.
Shape rules: slash assets are brush strokes, ring assets are broken talisman halos with open centers, weapon glyphs point right so the runtime can rotate them toward the player.
Style: high-saturation particles are crisp gameplay signals only; keep ambient ink dark and elegant, not western dark fantasy, not Diablo loot art, not photoreal.
Constraints: no text, no letters, no readable Chinese characters, no character bodies, no UI panels, no inventory icons, no western magic circles, no sci-fi reticles, no full opaque disks, no watermark.
""".strip()


def make_overlay_ornament_fx_prompt() -> str:
    lines = "\n".join(
        f"{index + 1}. {desc}" for index, (_path, _size, desc) in enumerate(OVERLAY_ORNAMENT_FX_CELLS)
    )
    return f"""
{STYLE_BASE}
{COHESION_RULES}
{CHROMA_RULE}

Asset type: runtime full-screen overlay ornament FX atlas for a 1920x1080 top-down 2D cultivation roguelite.
Grid: exactly 4 columns by 2 rows, one alpha-ready overlay ornament per cell, no visible grid lines or borders.
Cell order: left to right, top to bottom.
{lines}
Visual language: dark Chinese ink-wash xianxia, black jade ink mass, cold jade rim light, restrained old-gold ritual sparks. Saturated elemental color appears only on edge strokes and small particle accents.
Runtime use: Dao awakening corner ornaments are mirrored and rotated into the four screen corners; they must read as diagonal talisman brush patterns with open transparent centers. Crit edge strips tile/stretch along screen edges; they need feathered transparent inner edges and no hard rectangular slab.
Shape rules: no full opaque rectangles, no centered icon badges, no circular avatar frames, no text, no readable Chinese characters. Keep each ornament fully inside its cell with generous padding and no cell-edge touching except the intended soft edge strip direction.
Style: elegant high-saturation particles over deep ink, not western fantasy, not Diablo loot art, not sci-fi HUD, not photoreal.
Constraints: no characters, no monsters, no weapons as objects, no UI labels, no watermark.
""".strip()


def _load_existing_rgba(path: Path) -> Image.Image:
    if not path.exists():
        raise RuntimeError(f"overlay composite fallback source missing: {path}")
    return Image.open(path).convert("RGBA")


def _tint_alpha(image: Image.Image, color: tuple[int, int, int], alpha_scale: float = 1.0) -> Image.Image:
    source = image.convert("RGBA")
    alpha = source.getchannel("A")
    luma = source.convert("L")
    out = Image.new("RGBA", source.size, (0, 0, 0, 0))
    px_out = out.load()
    px_alpha = alpha.load()
    px_luma = luma.load()
    for y in range(source.height):
        for x in range(source.width):
            a = px_alpha[x, y]
            if a <= 2:
                continue
            light = 0.42 + float(px_luma[x, y]) / 255.0 * 0.76
            px_out[x, y] = (
                min(255, int(color[0] * light)),
                min(255, int(color[1] * light)),
                min(255, int(color[2] * light)),
                max(0, min(255, int(a * alpha_scale))),
            )
    return out


def _place_contained(canvas: Image.Image, image: Image.Image, box: tuple[int, int, int, int], *, rotate: float = 0.0, alpha: float = 1.0) -> None:
    work = image.convert("RGBA")
    if rotate:
        work = work.rotate(rotate, resample=Image.Resampling.BICUBIC, expand=True)
    width = max(1, box[2] - box[0])
    height = max(1, box[3] - box[1])
    work = ImageOps.contain(work, (width, height), Image.Resampling.LANCZOS)
    if alpha < 0.999:
        a = work.getchannel("A").point(lambda value: max(0, min(255, int(value * alpha))))
        work.putalpha(a)
    x = box[0] + (width - work.width) // 2
    y = box[1] + (height - work.height) // 2
    canvas.alpha_composite(work, (x, y))


def _soften_overlay_asset(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    glow = rgba.filter(ImageFilter.GaussianBlur(4.0))
    glow_alpha = glow.getchannel("A").point(lambda value: int(value * 0.34))
    glow.putalpha(glow_alpha)
    out = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    out.alpha_composite(glow)
    out.alpha_composite(rgba)
    out.putalpha(ImageChops.lighter(out.getchannel("A"), alpha))
    return out


def make_overlay_ornament_composite_fallback_raw() -> Image.Image:
    slash = _load_existing_rgba(FX_ROOT / "crit_screen_slash_640x180.png")
    player_arc = _load_existing_rgba(FX_ROOT / "player_slash_arc_192x128.png")
    seal = _load_existing_rgba(FX_ROOT / "enemy_windup_seal_160.png")
    dao_aura = _load_existing_rgba(FX_ROOT / "player_dao_aura_160.png")
    counter_aura = _load_existing_rgba(FX_ROOT / "player_counter_aura_160.png")
    boss_ring = _load_existing_rgba(FX_ROOT / "enemy_identity_ring_boss_192.png")
    guard_aura = _load_existing_rgba(FX_ROOT / "enemy_guard_aura_192.png")

    element_sources = {
        "fire": _load_existing_rgba(UI_ROOT / "elem_fire_large_80.png"),
        "thunder": _load_existing_rgba(UI_ROOT / "elem_thunder_large_80.png"),
        "wood": _load_existing_rgba(UI_ROOT / "elem_wood_large_80.png"),
        "water": _load_existing_rgba(UI_ROOT / "elem_water_large_80.png"),
        "five": _load_existing_rgba(UI_ROOT / "elem_chaos_large_80.png"),
    }
    palettes = {
        "fire": ((238, 86, 42), (220, 176, 86), seal),
        "thunder": ((116, 190, 255), (228, 206, 108), counter_aura),
        "wood": ((88, 226, 148), (210, 188, 96), dao_aura),
        "water": ((88, 208, 236), (176, 198, 224), guard_aura),
        "five": ((224, 190, 86), (148, 222, 210), boss_ring),
    }
    raw = Image.new("RGBA", (1152, 576), (0, 0, 0, 0))
    cell = 288
    for index, style in enumerate(["fire", "thunder", "wood", "water", "five"]):
        col = index % 4
        row = index // 4
        x = col * cell
        y = row * cell
        asset = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        primary, secondary, ring_source = palettes[style]
        _place_contained(asset, _tint_alpha(ring_source, secondary, 0.38), (38, 38, 250, 250), alpha=0.72)
        _place_contained(asset, _tint_alpha(slash, primary, 0.74), (10, 52, 278, 180), rotate=-34.0, alpha=0.92)
        _place_contained(asset, _tint_alpha(player_arc, secondary, 0.68), (36, 116, 252, 258), rotate=-18.0, alpha=0.76)
        _place_contained(asset, element_sources[style], (100, 88, 188, 176), alpha=0.48)
        asset = _soften_overlay_asset(asset)
        raw.alpha_composite(asset, (x, y))

    top_asset = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
    _place_contained(top_asset, _tint_alpha(slash, (118, 216, 255), 0.72), (8, 72, 280, 162), alpha=0.90)
    _place_contained(top_asset, _tint_alpha(player_arc, (226, 188, 78), 0.42), (24, 124, 264, 222), alpha=0.58)
    raw.alpha_composite(_soften_overlay_asset(top_asset), (cell, cell))

    side_asset = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
    _place_contained(side_asset, _tint_alpha(slash, (118, 216, 255), 0.70), (76, 8, 166, 280), rotate=90.0, alpha=0.88)
    _place_contained(side_asset, _tint_alpha(counter_aura, (226, 188, 78), 0.34), (104, 42, 218, 246), alpha=0.50)
    raw.alpha_composite(_soften_overlay_asset(side_asset), (cell * 2, cell))

    corner_asset = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
    _place_contained(corner_asset, _tint_alpha(slash, (118, 216, 255), 0.74), (22, 30, 196, 128), rotate=-28.0, alpha=0.84)
    _place_contained(corner_asset, _tint_alpha(slash, (118, 216, 255), 0.62), (28, 24, 126, 198), rotate=62.0, alpha=0.78)
    _place_contained(corner_asset, _tint_alpha(counter_aura, (226, 188, 78), 0.46), (58, 58, 228, 228), alpha=0.58)
    raw.alpha_composite(_soften_overlay_asset(corner_asset), (cell * 3, cell))
    return raw


def make_quality_talent_surface_prompt() -> str:
    return atlas_prompt(
        [(path.name, desc) for path, _size, desc in QUALITY_TALENT_SURFACE_CELLS],
        cols=5,
        rows=4,
        title="legacy quality frames, talent scroll surfaces, fallback weather icons, and HUD panel",
        cell_note=(
            "Frames and scroll surfaces must keep a transparent center or dark readable center, with ornament only around edges. "
            "Small fallback weather icons must be simple jade-seal dots. No words, no beige parchment, no western card frame."
        ),
    )


def make_vfx_prompt() -> str:
    return f"""
{STYLE_BASE}
{COHESION_RULES}
{ICON_COHESION_RULES}
{CHROMA_RULE}

Asset type: wood and earth projectile and impact VFX atlas for runtime sprites.
Grid: exactly 4 columns by 4 rows, one centered VFX frame per cell, no visible grid lines or borders.
Row 1: projectile_wood fly frames 00-03, compact green jade talisman seed projectile, black ink leaf silhouette, high saturation green core, subtle forward motion variation.
Row 2: projectile_earth fly frames 00-03, compact amber earth seal stone projectile, black ink square-rock silhouette, old-gold mineral core, subtle forward motion variation.
Row 3: impact_wood frames 00-03, green wood-root talisman impact expanding then fading, leaf sparks and ink splashes, readable at 32px.
Row 4: impact_earth frames 00-03, amber square stone-seal impact expanding then cracking, dust sparks and ink splashes, readable at 32px.
Style: clean hand-painted HD game VFX, dark ink silhouette first, high-saturation elemental core second, crisp alpha-ready edges.
Constraints: no text, no numbers, no UI frame, no full-screen explosion, no huge trail, no photoreal render, no western magic rune.
""".strip()


def make_single_icon_prompt(description: str) -> str:
    return f"""
{STYLE_BASE}
{COHESION_RULES}
{ICON_COHESION_RULES}
{CHROMA_RULE}

Asset type: single transparent combat HUD emblem.
Subject: {description}.
Style: clean hand-painted HD xianxia HUD icon, black-jade silhouette, cold jade rim, restrained old-gold ritual linework, high saturation only on the gameplay signal core.
Composition: one centered icon with generous padding, readable at 64px and 96px.
Constraints: no text, no letters, no Chinese characters, no square item card, no thick metal frame, no western dark-fantasy loot render, no photorealism.
""".strip()


def make_reward_card_prompt(description: str) -> str:
    return f"""
{STYLE_BASE}
{COHESION_RULES}
{UI_COHESION_RULES}

Asset type: vertical reward card frame source art, normalized to 240x373 runtime UI.
Subject: {description}.
Style: black rice-paper ink, dark jade center panels, dry brush flying-white border, thin jade-cyan structure lines, sparse edge particles.
Layout contract: decoration stays in the outer 12-16 percent; top rarity line, upper icon area, lower title/description area, and bottom tag strip remain dark, clean, and readable.
Constraints: no text, no numbers, no icon content, no character, no UI labels, no western card frame, no bright palace frame, no central magic circle, no particles crossing text zones.
""".strip()


def make_reward_overlay_prompt(description: str) -> str:
    return f"""
{STYLE_BASE}
{COHESION_RULES}
{CHROMA_RULE}

Asset type: transparent reward card state overlay, normalized to 240x373 runtime UI.
Subject: {description}.
Style: dark ink xianxia UI overlay, edge-only visual state, no frame replacement, no opaque center.
Layout contract: all cracks, chains, dust, seals, and particles stay within the outer 12-18 percent of the card; center text and icon zones remain transparent and readable.
Composition: one centered vertical card-sized overlay on solid #FF00FF background, edge ornament only.
Constraints: no text, no numbers, no character, no full card background fill, no western chains, no skull, no bright center glow, no watermark.
""".strip()


def make_reward_quality_fx_prompt(description: str) -> str:
    return f"""
{STYLE_BASE}
{COHESION_RULES}
{UI_COHESION_RULES}
{CHROMA_RULE}

Asset type: transparent reward-card quality effect sprite for runtime TextureRect layers.
Subject: {description}.
Style: high-polish dark ink xianxia UI effect, black-jade smoke, cold jade rim light, restrained old-gold sparks, saturated only on the tiny gameplay signal.
Runtime use: layered on top of 278x432 reward cards at very low alpha; it must feel like the same hand-painted water-ink UI family as the reward frames.
Composition: one centered transparent effect on flat #FF00FF, generous padding, feathered edges, open readable center where applicable.
Constraints: no text, no letters, no numbers, no card frame, no full card background, no western magic circle, no loot gem, no skull, no character, no opaque center, no watermark.
""".strip()


def make_left_hud_prompt(description: str) -> str:
    return f"""
{STYLE_BASE}
{COHESION_RULES}
{UI_COHESION_RULES}
{CHROMA_RULE}

Asset type: transparent combat HUD surface for the left battle panel.
Subject: {description}.
Style: clean hand-painted HD UI, translucent black-jade glass, cold jade rim light, restrained old-gold linework, thin ink texture, quiet enough to sit over combat.
Composition: one centered surface only, open readable center, edge ornament only, no inner text.
Constraints: no text, no letters, no numbers, no labels, no watermark, no beige parchment, no sci-fi metal, no thick boxy frame, no purple-dominant palette.
""".strip()


def make_core_ui_surface_prompt(description: str, transparent: bool) -> str:
    chroma = CHROMA_RULE if transparent else ""
    return f"""
{STYLE_BASE}
{COHESION_RULES}
{UI_COHESION_RULES}
{chroma}

Asset type: reusable runtime UI surface for a 1920x1080 dark xianxia roguelite interface.
Subject: {description}.
Style: clean hand-painted HD UI, black-jade glass or ink lacquer, cold jade rim light, restrained old-gold dry-brush ornament, very low texture noise.
Composition: one centered surface only, open readable center, ornaments stay on edges and corners.
Constraints: no text, no letters, no numbers, no labels, no character, no monster, no beige parchment dominance, no western fantasy frame, no gothic metal, no photorealism, no watermark.
""".strip()


def slice_atlas(image: Image.Image, *, cols: int, rows: int) -> list[Image.Image]:
    result: list[Image.Image] = []
    cell_w = image.width // cols
    cell_h = image.height // rows
    for row in range(rows):
        for col in range(cols):
            result.append(image.crop((col * cell_w, row * cell_h, (col + 1) * cell_w, (row + 1) * cell_h)))
    return result


def run_icons(args: argparse.Namespace, manifest: list[dict]) -> int:
    generated_count = 0
    if selected(args, "weather", "weather_icon_atlas_4x2"):
        if should_stop_for_limit(args, generated_count):
            return generated_count
        raw_path = RAW_ROOT / "icons" / "weather_icon_atlas_4x2.image2_raw.png"
        prompt = make_weather_icon_prompt()
        if args.write_prompts_only:
            record_prompt_only(manifest, category="icon", key="weather_icon_atlas_4x2", prompt_path=raw_path.with_suffix(".prompt.txt"), prompt=prompt)
        else:
            image, requested = load_seed_or_request_image(
                args,
                raw_path=raw_path,
                seed_key="weather_icon_atlas_4x2",
                prompt=prompt,
                size="1024x1024",
                label="[icons] requesting weather atlas",
            )
            generated_count += int(requested)
            save_prompt(raw_path.with_suffix(".prompt.txt"), prompt)
            outputs = [(filename, size, filename.removesuffix(".png")) for filename, size, _desc in WEATHER_ICON_CELLS]
            save_outputs_from_grid(
                image,
                cols=4,
                rows=2,
                outputs=outputs,
                raw_path=raw_path,
                prompt=prompt,
                manifest=manifest,
                category="icon",
                key_prefix="weather_icon_atlas_4x2",
                fill_ratio=0.90,
            )

    if selected(args, "hud_core", "hud_core_icon_atlas_2x2"):
        if should_stop_for_limit(args, generated_count):
            return generated_count
        raw_path = RAW_ROOT / "icons" / "hud_core_icon_atlas_2x2.image2_raw.png"
        prompt = make_hud_core_prompt()
        if args.write_prompts_only:
            record_prompt_only(manifest, category="icon", key="hud_core_icon_atlas_2x2", prompt_path=raw_path.with_suffix(".prompt.txt"), prompt=prompt)
        else:
            image, requested = load_seed_or_request_image(
                args,
                raw_path=raw_path,
                seed_key="hud_core_icon_atlas_2x2",
                prompt=prompt,
                size="1024x1024",
                label="[icons] requesting HUD core atlas",
            )
            generated_count += int(requested)
            save_prompt(raw_path.with_suffix(".prompt.txt"), prompt)
            outputs = [(path, size, path.name.removesuffix(".png")) for path, size, _desc in HUD_CORE_CELLS]
            save_outputs_from_grid(
                image,
                cols=2,
                rows=2,
                outputs=outputs,
                raw_path=raw_path,
                prompt=prompt,
                manifest=manifest,
                category="icon",
                key_prefix="hud_core_icon_atlas_2x2",
                fill_ratio=0.90,
            )

    if selected(args, "dao_heart", "dao_heart_icon_atlas_3x1"):
        if should_stop_for_limit(args, generated_count):
            return generated_count
        raw_path = RAW_ROOT / "icons" / "dao_heart_icon_atlas_3x1.image2_raw.png"
        prompt = make_dao_heart_prompt()
        if args.write_prompts_only:
            record_prompt_only(manifest, category="icon", key="dao_heart_icon_atlas_3x1", prompt_path=raw_path.with_suffix(".prompt.txt"), prompt=prompt)
        else:
            image, requested = load_seed_or_request_image(
                args,
                raw_path=raw_path,
                seed_key="dao_heart_icon_atlas_3x1",
                prompt=prompt,
                size="1536x512",
                label="[icons] requesting Dao-heart atlas",
            )
            generated_count += int(requested)
            save_prompt(raw_path.with_suffix(".prompt.txt"), prompt)
            outputs = [(path, size, path.name.removesuffix(".png")) for path, size, _desc in DAO_HEART_CELLS]
            save_outputs_from_grid(
                image,
                cols=3,
                rows=1,
                outputs=outputs,
                raw_path=raw_path,
                prompt=prompt,
                manifest=manifest,
                category="icon",
                key_prefix="dao_heart_icon_atlas_3x1",
                fill_ratio=0.90,
            )

    if selected(args, "path_choice", "path_choice_icon_atlas_3x2"):
        if should_stop_for_limit(args, generated_count):
            return generated_count
        raw_path = RAW_ROOT / "icons" / "path_choice_icon_atlas_3x2.image2_raw.png"
        prompt = make_path_icon_prompt()
        if args.write_prompts_only:
            record_prompt_only(manifest, category="icon", key="path_choice_icon_atlas_3x2", prompt_path=raw_path.with_suffix(".prompt.txt"), prompt=prompt)
        else:
            image, requested = load_seed_or_request_image(
                args,
                raw_path=raw_path,
                seed_key="path_choice_icon_atlas_3x2",
                prompt=prompt,
                size="1536x1024",
                label="[icons] requesting path-choice atlas",
            )
            generated_count += int(requested)
            save_prompt(raw_path.with_suffix(".prompt.txt"), prompt)
            outputs = [(path, size, path.name.removesuffix(".png")) for path, size, _desc in PATH_ICON_CELLS]
            save_outputs_from_grid(
                image,
                cols=3,
                rows=2,
                outputs=outputs,
                raw_path=raw_path,
                prompt=prompt,
                manifest=manifest,
                category="icon",
                key_prefix="path_choice_icon_atlas_3x2",
                fill_ratio=0.90,
            )

    if selected(args, "spell_qer", "spell_qer_icon_atlas_2x2"):
        if should_stop_for_limit(args, generated_count):
            return generated_count
        raw_path = RAW_ROOT / "icons" / "spell_qer_icon_atlas_2x2.image2_raw.png"
        prompt = make_spell_qer_prompt()
        if args.write_prompts_only:
            record_prompt_only(manifest, category="icon", key="spell_qer_icon_atlas_2x2", prompt_path=raw_path.with_suffix(".prompt.txt"), prompt=prompt)
        else:
            image, requested = load_seed_or_request_image(
                args,
                raw_path=raw_path,
                seed_key="spell_qer_icon_atlas_2x2",
                prompt=prompt,
                size="1024x1024",
                label="[icons] requesting QER spell atlas",
            )
            generated_count += int(requested)
            save_prompt(raw_path.with_suffix(".prompt.txt"), prompt)
            outputs = [(filename, size, filename.removesuffix(".png")) for filename, size, _desc in SPELL_QER_CELLS]
            save_outputs_from_grid(
                image,
                cols=2,
                rows=2,
                outputs=outputs,
                raw_path=raw_path,
                prompt=prompt,
                manifest=manifest,
                category="icon",
                key_prefix="spell_qer_icon_atlas_2x2",
                fill_ratio=0.88,
            )

    if selected(args, "wood_earth_vfx", "wood_earth_projectile_impact_atlas_4x4"):
        if should_stop_for_limit(args, generated_count):
            return generated_count
        raw_path = RAW_ROOT / "icons" / "wood_earth_projectile_impact_atlas_4x4.image2_raw.png"
        prompt = make_vfx_prompt()
        if args.write_prompts_only:
            record_prompt_only(manifest, category="icon", key="wood_earth_projectile_impact_atlas_4x4", prompt_path=raw_path.with_suffix(".prompt.txt"), prompt=prompt)
        else:
            image, requested = load_seed_or_request_image(
                args,
                raw_path=raw_path,
                seed_key="wood_earth_projectile_impact_atlas_4x4",
                prompt=prompt,
                size="1024x1024",
                label="[icons] requesting wood/earth VFX atlas",
            )
            generated_count += int(requested)
            save_prompt(raw_path.with_suffix(".prompt.txt"), prompt)
            cells = slice_atlas(image, cols=4, rows=4)
            for index, (out, size, desc) in enumerate(VFX_4X4_CELLS):
                icon = fit_square(cells[index], size, anchor="center", fill_ratio=0.78)
                save_runtime_image(icon, out)
                save_prompt(out.with_suffix(".prompt.txt"), prompt)
                manifest.append({"category": "icon", "key": f"wood_earth_projectile_impact_atlas_4x4:{desc}", "raw": str(raw_path), "runtime": str(out)})
            for element in ("wood", "earth"):
                first_frame = FRAME_ROOT / f"projectile_{element}" / "fly_00.png"
                target = SPRITE_ROOT / f"projectile_{element}_16.png"
                save_runtime_image(Image.open(first_frame).convert("RGBA"), target)
                save_prompt(target.with_suffix(".prompt.txt"), prompt)
                manifest.append({"category": "icon", "key": f"wood_earth_projectile_impact_atlas_4x4:projectile_{element}_16", "raw": str(raw_path), "runtime": str(target)})

    if selected(args, "status_icons", "status_icon_atlas_5x4"):
        if should_stop_for_limit(args, generated_count):
            return generated_count
        raw_path = RAW_ROOT / "icons" / "status_icon_atlas_5x4.image2_raw.png"
        prompt = make_status_icon_prompt()
        if args.write_prompts_only:
            record_prompt_only(manifest, category="icon", key="status_icon_atlas_5x4", prompt_path=raw_path.with_suffix(".prompt.txt"), prompt=prompt)
        else:
            image, requested = load_or_request_image(
                args,
                raw_path=raw_path,
                prompt=prompt,
                size="1536x1024",
                label="[icons] requesting status icon atlas",
            )
            generated_count += int(requested)
            save_prompt(raw_path.with_suffix(".prompt.txt"), prompt)
            outputs = [(path, size, path.name) for path, size, _desc in STATUS_ICON_CELLS]
            save_outputs_from_grid(
                image,
                cols=5,
                rows=4,
                outputs=outputs,
                raw_path=raw_path,
                prompt=prompt,
                manifest=manifest,
                category="icon",
                key_prefix="status_icon_atlas_5x4",
                fill_ratio=0.92,
            )

    if selected(args, "element_icons", "element_icon_atlas_4x2"):
        if should_stop_for_limit(args, generated_count):
            return generated_count
        raw_path = RAW_ROOT / "icons" / "element_icon_atlas_4x2.image2_raw.png"
        prompt = make_element_icon_prompt()
        if args.write_prompts_only:
            record_prompt_only(manifest, category="icon", key="element_icon_atlas_4x2", prompt_path=raw_path.with_suffix(".prompt.txt"), prompt=prompt)
        else:
            image, requested = load_or_request_image(
                args,
                raw_path=raw_path,
                prompt=prompt,
                size="1024x1024",
                label="[icons] requesting element icon atlas",
            )
            generated_count += int(requested)
            save_prompt(raw_path.with_suffix(".prompt.txt"), prompt)
            cells = slice_atlas(image, cols=4, rows=2)
            for index, (key, _desc, outputs) in enumerate(ELEMENT_ICON_CELLS):
                for out, size in outputs:
                    icon = fit_square(cells[index], size, anchor="center", fill_ratio=0.92)
                    save_runtime_image(icon, out)
                    save_prompt(out.with_suffix(".prompt.txt"), prompt)
                    manifest.append({"category": "icon", "key": f"element_icon_atlas_4x2:{out.name}", "raw": str(raw_path), "runtime": str(out)})

    if selected(args, "utility_karma", "utility_karma_icon_atlas_5x4"):
        if should_stop_for_limit(args, generated_count):
            return generated_count
        raw_path = RAW_ROOT / "icons" / "utility_karma_icon_atlas_5x4.image2_raw.png"
        prompt = make_utility_karma_icon_prompt()
        if args.write_prompts_only:
            record_prompt_only(manifest, category="icon", key="utility_karma_icon_atlas_5x4", prompt_path=raw_path.with_suffix(".prompt.txt"), prompt=prompt)
        else:
            image, requested = load_or_request_image(
                args,
                raw_path=raw_path,
                prompt=prompt,
                size="1536x1024",
                label="[icons] requesting utility/karma atlas",
            )
            generated_count += int(requested)
            save_prompt(raw_path.with_suffix(".prompt.txt"), prompt)
            outputs = [(path, size, path.name) for path, size, _desc in UTILITY_KARMA_ICON_CELLS]
            save_outputs_from_grid(
                image,
                cols=5,
                rows=4,
                outputs=outputs,
                raw_path=raw_path,
                prompt=prompt,
                manifest=manifest,
                category="icon",
                key_prefix="utility_karma_icon_atlas_5x4",
                fill_ratio=0.92,
            )

    if selected(args, "hud_runes", "hud_rune_surface_atlas_5x4"):
        if should_stop_for_limit(args, generated_count):
            return generated_count
        raw_path = RAW_ROOT / "icons" / "hud_rune_surface_atlas_5x4.image2_raw.png"
        prompt = make_hud_rune_surface_prompt()
        if args.write_prompts_only:
            record_prompt_only(manifest, category="icon", key="hud_rune_surface_atlas_5x4", prompt_path=raw_path.with_suffix(".prompt.txt"), prompt=prompt)
        else:
            image, requested = load_or_request_image(
                args,
                raw_path=raw_path,
                prompt=prompt,
                size="1536x1024",
                label="[icons] requesting HUD rune/surface atlas",
            )
            generated_count += int(requested)
            save_prompt(raw_path.with_suffix(".prompt.txt"), prompt)
            outputs = [(path, size, path.name) for path, size, _desc in HUD_RUNE_SURFACE_CELLS]
            save_outputs_from_grid(
                image,
                cols=5,
                rows=4,
                outputs=outputs,
                raw_path=raw_path,
                prompt=prompt,
                manifest=manifest,
                category="icon",
                key_prefix="hud_rune_surface_atlas_5x4",
                fill_ratio=0.92,
            )

    if selected(args, "talent_tags", "talent_tag_icon_atlas_5x3"):
        if should_stop_for_limit(args, generated_count):
            return generated_count
        raw_path = RAW_ROOT / "icons" / "talent_tag_icon_atlas_5x3.image2_raw.png"
        prompt = make_talent_tag_icon_prompt()
        if args.write_prompts_only:
            record_prompt_only(manifest, category="icon", key="talent_tag_icon_atlas_5x3", prompt_path=raw_path.with_suffix(".prompt.txt"), prompt=prompt)
        else:
            image, requested = load_or_request_image(
                args,
                raw_path=raw_path,
                prompt=prompt,
                size="1536x1024",
                label="[icons] requesting talent/tag atlas",
            )
            generated_count += int(requested)
            save_prompt(raw_path.with_suffix(".prompt.txt"), prompt)
            outputs = [(path, size, path.name) for path, size, _desc in TALENT_TAG_ICON_CELLS]
            save_outputs_from_grid(
                image,
                cols=5,
                rows=3,
                outputs=outputs,
                raw_path=raw_path,
                prompt=prompt,
                manifest=manifest,
                category="icon",
                key_prefix="talent_tag_icon_atlas_5x3",
                fill_ratio=0.92,
            )

    if selected(args, "weather_ground_decals", "weather_ground_decal_atlas_4x2"):
        if should_stop_for_limit(args, generated_count):
            return generated_count
        raw_path = RAW_ROOT / "icons" / "weather_ground_decal_atlas_4x2.image2_raw.png"
        prompt = make_weather_ground_decal_prompt()
        if args.write_prompts_only:
            record_prompt_only(manifest, category="icon", key="weather_ground_decal_atlas_4x2", prompt_path=raw_path.with_suffix(".prompt.txt"), prompt=prompt)
        else:
            image, requested = load_or_request_image(
                args,
                raw_path=raw_path,
                prompt=prompt,
                size="1024x512",
                label="[icons] requesting weather ground decal atlas",
            )
            generated_count += int(requested)
            save_prompt(raw_path.with_suffix(".prompt.txt"), prompt)
            save_fx_outputs_from_grid(
                image,
                cols=4,
                rows=2,
                outputs=[(path, size, path.name) for path, size, _desc in WEATHER_GROUND_DECAL_CELLS],
                raw_path=raw_path,
                prompt=prompt,
                manifest=manifest,
                category="icon",
                key_prefix="weather_ground_decal_atlas_4x2",
                fill_ratio=0.90,
            )

    if selected(args, "weather_overlay_particles", "weather_overlay_particle_atlas_4x2"):
        if should_stop_for_limit(args, generated_count):
            return generated_count
        raw_path = RAW_ROOT / "icons" / "weather_overlay_particle_atlas_4x2.image2_raw.png"
        prompt = make_weather_overlay_particle_prompt()
        if args.write_prompts_only:
            record_prompt_only(manifest, category="icon", key="weather_overlay_particle_atlas_4x2", prompt_path=raw_path.with_suffix(".prompt.txt"), prompt=prompt)
        else:
            image, requested = load_or_request_image(
                args,
                raw_path=raw_path,
                prompt=prompt,
                size="1152x576",
                label="[icons] requesting weather overlay particle atlas",
            )
            generated_count += int(requested)
            save_prompt(raw_path.with_suffix(".prompt.txt"), prompt)
            save_fx_outputs_from_grid(
                image,
                cols=4,
                rows=2,
                outputs=[(path, size, path.name) for path, size, _desc in WEATHER_OVERLAY_PARTICLE_CELLS],
                raw_path=raw_path,
                prompt=prompt,
                manifest=manifest,
                category="icon",
                key_prefix="weather_overlay_particle_atlas_4x2",
                fill_ratio=0.86,
            )

    if selected(args, "enemy_projectile_trails", "enemy_projectile_trail_atlas_4x2"):
        if should_stop_for_limit(args, generated_count):
            return generated_count
        raw_path = RAW_ROOT / "icons" / "enemy_projectile_trail_atlas_4x2.image2_raw.png"
        prompt = make_enemy_projectile_trail_prompt()
        if args.write_prompts_only:
            record_prompt_only(manifest, category="icon", key="enemy_projectile_trail_atlas_4x2", prompt_path=raw_path.with_suffix(".prompt.txt"), prompt=prompt)
        else:
            image, requested = load_or_request_image(
                args,
                raw_path=raw_path,
                prompt=prompt,
                size="1536x768",
                label="[icons] requesting enemy projectile trail atlas",
            )
            generated_count += int(requested)
            save_prompt(raw_path.with_suffix(".prompt.txt"), prompt)
            save_fx_outputs_from_grid(
                image,
                cols=4,
                rows=2,
                outputs=[(path, size, path.name) for path, size, _desc in ENEMY_PROJECTILE_TRAIL_CELLS],
                raw_path=raw_path,
                prompt=prompt,
                manifest=manifest,
                category="icon",
                key_prefix="enemy_projectile_trail_atlas_4x2",
                fill_ratio=0.92,
            )

    if selected(args, "thunder_strike_decals", "thunder_strike_decal_atlas_2x2"):
        if should_stop_for_limit(args, generated_count):
            return generated_count
        raw_path = RAW_ROOT / "icons" / "thunder_strike_decal_atlas_2x2.image2_raw.png"
        prompt = make_thunder_strike_decal_prompt()
        if args.write_prompts_only:
            record_prompt_only(manifest, category="icon", key="thunder_strike_decal_atlas_2x2", prompt_path=raw_path.with_suffix(".prompt.txt"), prompt=prompt)
        else:
            image, requested = load_or_request_image(
                args,
                raw_path=raw_path,
                prompt=prompt,
                size="1024x1024",
                label="[icons] requesting thunder strike decal atlas",
            )
            generated_count += int(requested)
            save_prompt(raw_path.with_suffix(".prompt.txt"), prompt)
            save_fx_outputs_from_grid(
                image,
                cols=2,
                rows=2,
                outputs=[(path, size, path.name) for path, size, _desc in THUNDER_STRIKE_DECAL_CELLS],
                raw_path=raw_path,
                prompt=prompt,
                manifest=manifest,
                category="icon",
                key_prefix="thunder_strike_decal_atlas_2x2",
                fill_ratio=0.92,
            )

    if selected(args, "enemy_telegraphs", "enemy_telegraph_atlas_3x2"):
        if should_stop_for_limit(args, generated_count):
            return generated_count
        raw_path = RAW_ROOT / "icons" / "enemy_telegraph_atlas_3x2.image2_raw.png"
        prompt = make_enemy_telegraph_prompt()
        if args.write_prompts_only:
            record_prompt_only(manifest, category="icon", key="enemy_telegraph_atlas_3x2", prompt_path=raw_path.with_suffix(".prompt.txt"), prompt=prompt)
        else:
            image, requested = load_or_request_image(
                args,
                raw_path=raw_path,
                prompt=prompt,
                size="1536x1024",
                label="[icons] requesting enemy telegraph atlas",
            )
            generated_count += int(requested)
            save_prompt(raw_path.with_suffix(".prompt.txt"), prompt)
            save_fx_outputs_from_grid(
                image,
                cols=3,
                rows=2,
                outputs=[(path, size, path.name) for path, size, _desc in ENEMY_TELEGRAPH_CELLS],
                raw_path=raw_path,
                prompt=prompt,
                manifest=manifest,
                category="icon",
                key_prefix="enemy_telegraph_atlas_3x2",
                fill_ratio=0.92,
            )

    if selected(args, "combat_action_fx", "combat_action_fx_atlas_4x4"):
        if should_stop_for_limit(args, generated_count):
            return generated_count
        raw_path = RAW_ROOT / "icons" / "combat_action_fx_atlas_4x4.image2_raw.png"
        prompt = make_combat_action_fx_prompt()
        if args.write_prompts_only:
            record_prompt_only(manifest, category="icon", key="combat_action_fx_atlas_4x4", prompt_path=raw_path.with_suffix(".prompt.txt"), prompt=prompt)
        else:
            image, requested = load_or_request_image(
                args,
                raw_path=raw_path,
                prompt=prompt,
                size="1536x1536",
                label="[icons] requesting combat action FX atlas",
            )
            generated_count += int(requested)
            save_prompt(raw_path.with_suffix(".prompt.txt"), prompt)
            save_fx_outputs_from_grid(
                image,
                cols=4,
                rows=4,
                outputs=[(path, size, path.name) for path, size, _desc in COMBAT_ACTION_FX_CELLS],
                raw_path=raw_path,
                prompt=prompt,
                manifest=manifest,
                category="icon",
                key_prefix="combat_action_fx_atlas_4x4",
                fill_ratio=0.90,
            )

    if selected(args, "overlay_ornament_fx", "overlay_ornament_fx_atlas_4x2"):
        if should_stop_for_limit(args, generated_count):
            return generated_count
        raw_path = RAW_ROOT / "icons" / "overlay_ornament_fx_atlas_4x2.image2_raw.png"
        prompt = make_overlay_ornament_fx_prompt()
        if args.write_prompts_only:
            record_prompt_only(manifest, category="icon", key="overlay_ornament_fx_atlas_4x2", prompt_path=raw_path.with_suffix(".prompt.txt"), prompt=prompt)
        elif args.composite_fallback and (args.force or not raw_path.exists()):
            image = make_overlay_ornament_composite_fallback_raw()
            raw_path.parent.mkdir(parents=True, exist_ok=True)
            atomic_save_image(image, raw_path)
            fallback_note = (
                prompt
                + "\n\nFallback note: provider request timed out during this session, so this raw atlas was composited from existing project image2 assets "
                + "(crit slash, slash arc, Dao aura, guard aura, enemy seal/ring, and element icons). Re-run with --force without --composite-fallback when the image provider is healthy to replace it with a native gpt-image-2 atlas."
            )
            save_prompt(raw_path.with_suffix(".prompt.txt"), fallback_note)
            save_fx_outputs_from_grid(
                image,
                cols=4,
                rows=2,
                outputs=[(path, size, path.name) for path, size, _desc in OVERLAY_ORNAMENT_FX_CELLS],
                raw_path=raw_path,
                prompt=fallback_note,
                manifest=manifest,
                category="icon",
                key_prefix="overlay_ornament_fx_atlas_4x2",
                fill_ratio=0.94,
            )
        else:
            image, requested = load_or_request_image(
                args,
                raw_path=raw_path,
                prompt=prompt,
                size="1536x768",
                label="[icons] requesting overlay ornament FX atlas",
            )
            generated_count += int(requested)
            save_prompt(raw_path.with_suffix(".prompt.txt"), prompt)
            save_fx_outputs_from_grid(
                image,
                cols=4,
                rows=2,
                outputs=[(path, size, path.name) for path, size, _desc in OVERLAY_ORNAMENT_FX_CELLS],
                raw_path=raw_path,
                prompt=prompt,
                manifest=manifest,
                category="icon",
                key_prefix="overlay_ornament_fx_atlas_4x2",
                fill_ratio=0.94,
            )

    if selected(args, "projectile_impacts", "projectile_impact_core_atlas_4x6"):
        if should_stop_for_limit(args, generated_count):
            return generated_count
        raw_path = RAW_ROOT / "icons" / "projectile_impact_core_atlas_4x6.image2_raw.png"
        prompt = make_projectile_impact_core_prompt()
        if args.write_prompts_only:
            record_prompt_only(manifest, category="icon", key="projectile_impact_core_atlas_4x6", prompt_path=raw_path.with_suffix(".prompt.txt"), prompt=prompt)
        else:
            image, requested = load_or_request_image(
                args,
                raw_path=raw_path,
                prompt=prompt,
                size="1024x1536",
                label="[icons] requesting projectile/impact atlas",
            )
            generated_count += int(requested)
            save_prompt(raw_path.with_suffix(".prompt.txt"), prompt)
            cells = slice_atlas(image, cols=4, rows=6)
            for row, (element, _desc) in enumerate(PROJECTILE_ELEMENTS_4X6):
                for index in range(4):
                    cell = cells[row * 4 + index]
                    projectile_frame = fit_square(cell, 16, anchor="center", fill_ratio=0.78)
                    projectile_out = FRAME_ROOT / f"projectile_{element}" / f"fly_{index:02d}.png"
                    save_runtime_image(projectile_frame, projectile_out)
                    save_prompt(projectile_out.with_suffix(".prompt.txt"), prompt)
                    manifest.append({"category": "icon", "key": f"projectile_impact_core_atlas_4x6:{element}:fly_{index:02d}", "raw": str(raw_path), "runtime": str(projectile_out)})

                    impact_frame = fit_square(cell, 32, anchor="center", fill_ratio=0.92)
                    draw = ImageDraw.Draw(impact_frame)
                    alpha = [86, 118, 96, 42][index]
                    draw.ellipse((6, 6, 26, 26), outline=(220, 210, 150, alpha), width=1)
                    impact_out = FRAME_ROOT / f"impact_{element}" / f"impact_{index:02d}.png"
                    save_runtime_image(impact_frame, impact_out)
                    save_prompt(impact_out.with_suffix(".prompt.txt"), prompt)
                    manifest.append({"category": "icon", "key": f"projectile_impact_core_atlas_4x6:{element}:impact_{index:02d}", "raw": str(raw_path), "runtime": str(impact_out)})
                first_frame = FRAME_ROOT / f"projectile_{element}" / "fly_00.png"
                static_out = SPRITE_ROOT / f"projectile_{element}_16.png"
                save_runtime_image(Image.open(first_frame).convert("RGBA"), static_out)
                save_prompt(static_out.with_suffix(".prompt.txt"), prompt)
                manifest.append({"category": "icon", "key": f"projectile_impact_core_atlas_4x6:projectile_{element}_16.png", "raw": str(raw_path), "runtime": str(static_out)})

    for key, outputs, description in SINGLE_ICON_REUSE_JOBS:
        if not selected(args, key):
            continue
        if should_stop_for_limit(args, generated_count):
            return generated_count
        raw_path = RAW_ROOT / "icons" / f"{key}.image2_raw.png"
        prompt = make_single_icon_prompt(description)
        if args.write_prompts_only:
            record_prompt_only(manifest, category="icon", key=key, prompt_path=raw_path.with_suffix(".prompt.txt"), prompt=prompt)
            continue
        image, requested = load_seed_or_request_image(
            args,
            raw_path=raw_path,
            seed_key=key,
            prompt=prompt,
            size="1024x1024",
            label=f"[icons] requesting {key}",
        )
        generated_count += int(requested)
        save_prompt(raw_path.with_suffix(".prompt.txt"), prompt)
        for out, size in outputs:
            if isinstance(size, tuple):
                fitted = fit_alpha_rect(image, size, padding=4, stretch=False)
            else:
                fitted = fit_square(image, size, anchor="center", fill_ratio=0.90)
            save_runtime_image(fitted, out)
            save_prompt(out.with_suffix(".prompt.txt"), prompt)
            manifest.append({"category": "icon", "key": f"{key}:{out.name}", "raw": str(raw_path), "runtime": str(out)})

    if not args.only or "spells" in args.only:
        if should_stop_for_limit(args, generated_count):
            return generated_count
        raw_path = RAW_ROOT / "icons" / "spell_icon_atlas_4x4.image2_raw.png"
        prompt = atlas_prompt(
            SPELL_CELLS,
            cols=4,
            rows=4,
            title="combat spell HUD icons",
            cell_note="Cells 14, 15, and 16 must be completely empty flat #FF00FF background only, no mist, no ornament, no icon-like shape.",
        )
        if args.write_prompts_only:
            record_prompt_only(manifest, category="icon", key="spell_icon_atlas_4x4", prompt_path=raw_path.with_suffix(".prompt.txt"), prompt=prompt)
        else:
            image, requested = load_or_request_image(
                args,
                raw_path=raw_path,
                prompt=prompt,
                size="1024x1024",
                label="[icons] requesting spell atlas",
            )
            generated_count += int(requested)
            save_prompt(raw_path.with_suffix(".prompt.txt"), prompt)
            cells = slice_atlas(image, cols=4, rows=4)
            for index, (filename, _desc) in enumerate(SPELL_CELLS):
                out = HUD_ROOT / filename
                icon = fit_square(cells[index], 96, anchor="center", fill_ratio=0.92)
                save_runtime_image(icon, out)
                save_prompt(out.with_suffix(".prompt.txt"), prompt)
                manifest.append({"category": "icon", "key": filename, "raw": str(raw_path), "runtime": str(out)})

    if not args.only or "companions" in args.only:
        if should_stop_for_limit(args, generated_count):
            return generated_count
        raw_path = RAW_ROOT / "icons" / "companion_artifact_icon_atlas_2x2.image2_raw.png"
        companion_prompt = atlas_prompt(
            [(name, desc) for name, _size, desc in COMPANION_CELLS],
            cols=2,
            rows=2,
            title="pet and artifact HUD avatars",
            cell_note="Each cell should feel like the same icon family as the spell HUD icons. Pet and artifact cells are Chinese cultivation HUD emblems, not loot items. No gem socket, no inventory-item lighting, no black leather, no iron or steel frame, no Western amulet, no skull, no demonic glow.",
        )
        if args.write_prompts_only:
            record_prompt_only(
                manifest,
                category="icon",
                key="companion_artifact_icon_atlas_2x2",
                prompt_path=raw_path.with_suffix(".prompt.txt"),
                prompt=companion_prompt,
            )
            return generated_count
        image, requested = load_or_request_image(
            args,
            raw_path=raw_path,
            prompt=companion_prompt,
            size="1024x1024",
            label="[icons] requesting companion/artifact atlas",
        )
        generated_count += int(requested)
        save_prompt(raw_path.with_suffix(".prompt.txt"), companion_prompt)
        cells = slice_atlas(image, cols=2, rows=2)
        for index, (filename, size, _desc) in enumerate(COMPANION_CELLS):
            out = HUD_ROOT / filename
            icon = fit_square(cells[index], size, anchor="center", fill_ratio=0.92)
            save_runtime_image(icon, out)
            save_prompt(out.with_suffix(".prompt.txt"), companion_prompt)
            manifest.append({"category": "icon", "key": filename, "raw": str(raw_path), "runtime": str(out)})
    return generated_count


def run_ui(args: argparse.Namespace, manifest: list[dict]) -> int:
    generated_count = 0
    if selected(args, "quality_talent_surfaces", "quality_talent_surface_atlas_5x4"):
        if should_stop_for_limit(args, generated_count):
            return generated_count
        raw_path = RAW_ROOT / "ui" / "quality_talent_surface_atlas_5x4.image2_raw.png"
        prompt = make_quality_talent_surface_prompt()
        if args.write_prompts_only:
            record_prompt_only(manifest, category="ui", key="quality_talent_surface_atlas_5x4", prompt_path=raw_path.with_suffix(".prompt.txt"), prompt=prompt)
        else:
            image, requested = load_or_request_image(
                args,
                raw_path=raw_path,
                prompt=prompt,
                size="1536x1024",
                label="[ui] requesting quality/talent surface atlas",
            )
            generated_count += int(requested)
            save_prompt(raw_path.with_suffix(".prompt.txt"), prompt)
            outputs = [(path, size, path.name) for path, size, _desc in QUALITY_TALENT_SURFACE_CELLS]
            save_outputs_from_grid(
                image,
                cols=5,
                rows=4,
                outputs=outputs,
                raw_path=raw_path,
                prompt=prompt,
                manifest=manifest,
                category="ui",
                key_prefix="quality_talent_surface_atlas_5x4",
                fill_ratio=0.92,
            )

    for key, out, size, description in REWARD_CARD_REUSE_JOBS:
        if not selected(args, key):
            continue
        if should_stop_for_limit(args, generated_count):
            return generated_count
        raw_path = RAW_ROOT / "ui" / f"{key}.image2_raw.png"
        prompt = make_reward_card_prompt(description)
        if args.write_prompts_only:
            record_prompt_only(manifest, category="ui", key=key, prompt_path=raw_path.with_suffix(".prompt.txt"), prompt=prompt)
            continue
        image, requested = load_seed_or_request_image(
            args,
            raw_path=raw_path,
            seed_key=key,
            prompt=prompt,
            size="1024x1024",
            label=f"[ui] requesting {key}",
        )
        generated_count += int(requested)
        save_prompt(raw_path.with_suffix(".prompt.txt"), prompt)
        fitted = fit_reward_card_frame(image, size)
        save_runtime_image(fitted, out)
        save_prompt(out.with_suffix(".prompt.txt"), prompt)
        manifest.append({"category": "ui", "key": key, "raw": str(raw_path), "runtime": str(out)})

    for key, out, size, description in REWARD_OVERLAY_REUSE_JOBS:
        if not selected(args, key):
            continue
        if should_stop_for_limit(args, generated_count):
            return generated_count
        raw_path = RAW_ROOT / "ui" / f"{key}.image2_raw.png"
        prompt = make_reward_overlay_prompt(description)
        if args.write_prompts_only:
            record_prompt_only(manifest, category="ui", key=key, prompt_path=raw_path.with_suffix(".prompt.txt"), prompt=prompt)
            continue
        image, requested = load_seed_or_request_image(
            args,
            raw_path=raw_path,
            seed_key=key,
            prompt=prompt,
            size="1024x1536",
            label=f"[ui] requesting {key}",
        )
        generated_count += int(requested)
        save_prompt(raw_path.with_suffix(".prompt.txt"), prompt)
        fitted = fit_alpha_rect(image, size, padding=4, stretch=False, recolor_jade=False)
        save_runtime_image(fitted, out)
        save_prompt(out.with_suffix(".prompt.txt"), prompt)
        manifest.append({"category": "ui", "key": key, "raw": str(raw_path), "runtime": str(out)})

    for key, out, size, padding, description in REWARD_QUALITY_FX_REUSE_JOBS:
        if not selected(args, key, "reward_quality_fx"):
            continue
        if should_stop_for_limit(args, generated_count):
            return generated_count
        raw_path = RAW_ROOT / "ui" / f"{key}.image2_raw.png"
        prompt = make_reward_quality_fx_prompt(description)
        if args.write_prompts_only:
            record_prompt_only(manifest, category="ui", key=key, prompt_path=raw_path.with_suffix(".prompt.txt"), prompt=prompt)
            continue
        request_size = "1536x1024" if size[0] > size[1] else "1024x1024"
        image, requested = load_seed_or_request_image(
            args,
            raw_path=raw_path,
            seed_key=key,
            prompt=prompt,
            size=request_size,
            label=f"[ui] requesting {key}",
        )
        generated_count += int(requested)
        save_prompt(raw_path.with_suffix(".prompt.txt"), prompt)
        fitted = fit_alpha_rect(image, size, padding=padding, stretch=False, recolor_jade=False)
        save_runtime_image(fitted, out)
        save_prompt(out.with_suffix(".prompt.txt"), prompt)
        manifest.append({"category": "ui", "key": key, "raw": str(raw_path), "runtime": str(out)})

    for key, out, size, padding, stretch, transparent, description in CORE_UI_SURFACE_REUSE_JOBS:
        if not selected(args, key):
            continue
        if should_stop_for_limit(args, generated_count):
            return generated_count
        raw_path = RAW_ROOT / "ui" / f"{key}.image2_raw.png"
        prompt = make_core_ui_surface_prompt(description, transparent)
        if args.write_prompts_only:
            record_prompt_only(manifest, category="ui", key=key, prompt_path=raw_path.with_suffix(".prompt.txt"), prompt=prompt)
            continue
        request_size = "1536x1024" if size[0] >= size[1] else "1024x1536"
        if size == (1920, 1080):
            request_size = "2048x1152"
        if size[0] == size[1]:
            request_size = "1024x1024"
        image, requested = load_seed_or_request_image(
            args,
            raw_path=raw_path,
            seed_key=key,
            prompt=prompt,
            size=request_size,
            label=f"[ui] requesting {key}",
        )
        generated_count += int(requested)
        save_prompt(raw_path.with_suffix(".prompt.txt"), prompt)
        if transparent:
            fitted = fit_alpha_rect(image, size, padding=padding, stretch=stretch, recolor_jade=True)
        else:
            fitted = ImageOps.fit(image.convert("RGBA"), size, method=Image.Resampling.LANCZOS, centering=(0.5, 0.5))
            fitted = dark_ink_grade_rgba(fitted, target_mean=76, max_channel=156)
        save_runtime_image(fitted, out)
        save_prompt(out.with_suffix(".prompt.txt"), prompt)
        manifest.append({"category": "ui", "key": key, "raw": str(raw_path), "runtime": str(out)})

    for key, out, size, padding, stretch, description in LEFT_HUD_REUSE_JOBS:
        if not selected(args, key):
            continue
        if should_stop_for_limit(args, generated_count):
            return generated_count
        raw_path = RAW_ROOT / "ui" / f"{key}.image2_raw.png"
        prompt = make_left_hud_prompt(description)
        if args.write_prompts_only:
            record_prompt_only(manifest, category="ui", key=key, prompt_path=raw_path.with_suffix(".prompt.txt"), prompt=prompt)
            continue
        image, requested = load_seed_or_request_image(
            args,
            raw_path=raw_path,
            seed_key=key,
            prompt=prompt,
            size="1024x1024",
            label=f"[ui] requesting {key}",
        )
        generated_count += int(requested)
        save_prompt(raw_path.with_suffix(".prompt.txt"), prompt)
        fitted = fit_alpha_rect(image, size, padding=padding, stretch=stretch, recolor_jade=True)
        save_runtime_image(fitted, out)
        save_prompt(out.with_suffix(".prompt.txt"), prompt)
        manifest.append({"category": "ui", "key": key, "raw": str(raw_path), "runtime": str(out)})

    for filename, subject in UI_JOBS.items():
        if args.only and filename not in args.only and filename.removesuffix(".png") not in args.only:
            continue
        if should_stop_for_limit(args, generated_count):
            break
        size = "1536x512" if filename.startswith("event_") else "2048x1152"
        raw_path = RAW_ROOT / "ui" / f"{filename.removesuffix('.png')}.image2_raw.png"
        asset_type = "wide 4:1 event banner" if filename.startswith("event_") else "16:9 UI backdrop"
        composition = (
            "Composition: wide 4:1 banner, dramatic object on one side, center-left or center-right dark negative space for event text and buttons, edge-framed light, no text."
            if filename.startswith("event_")
            else "Composition: UI safe area leaves the central 55-65 percent as dark, soft, low-detail negative space for panels and text. Main architecture, lamps, doors, wheels, pools, clouds, mist, and bright accents frame the left, right, and top edges, not behind the center panel."
        )
        prompt = f"""
{STYLE_BASE}
{COHESION_RULES}
{UI_COHESION_RULES}

Asset type: {asset_type} for a Chinese xianxia roguelite.
Subject: {subject}.
{composition}
Mood: dark atmospheric edges, elegant black-jade and old-gold xianxia mood.
Constraints: no characters, no monsters, no UI text, no labels, no western castle, no gothic dungeon.
""".strip()
        if args.write_prompts_only:
            record_prompt_only(manifest, category="ui", key=filename, prompt_path=raw_path.with_suffix(".prompt.txt"), prompt=prompt)
            continue
        image, requested = load_or_request_image(
            args,
            raw_path=raw_path,
            prompt=prompt,
            size=size,
            label=f"[ui] requesting {filename}",
        )
        generated_count += int(requested)
        target_size = (1536, 384) if filename.startswith("event_") else (2048, 1152)
        fitted = ImageOps.fit(image.convert("RGB"), target_size, method=Image.Resampling.LANCZOS)
        out = UI_ROOT / filename
        save_runtime_image(fitted, out)
        save_prompt(out.with_suffix(".prompt.txt"), prompt)
        save_prompt(raw_path.with_suffix(".prompt.txt"), prompt)
        manifest.append({"category": "ui", "key": filename, "raw": str(raw_path), "runtime": str(out)})
    return generated_count


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate unified image2 assets for Samsara Ascension.")
    parser.add_argument(
        "--category",
        action="append",
        choices=["maps", "actors", "icons", "ui", "all"],
        help="Category to generate. Repeatable. Default: actors + icons + maps.",
    )
    parser.add_argument("--only", action="append", help="Optional key/slug/stage/name filter. Repeatable.")
    parser.add_argument(
        "--only-asset",
        action="append",
        choices=["room_background", "tileset", "terrain_props"],
        help="Map sub-asset filter for --category maps. Repeatable.",
    )
    parser.add_argument("--force", action="store_true", help="Request fresh images even when raw image2 files exist.")
    parser.add_argument("--reuse-only", action="store_true", help="Rebuild runtime assets only from existing raw files; never call the API.")
    parser.add_argument("--composite-fallback", action="store_true", help="For selected overlay ornaments only, compose runtime art from existing image2 assets when the provider is unavailable.")
    parser.add_argument("--write-prompts-only", action="store_true", help="Write prompt files and manifest without reading raw files or calling the API.")
    parser.add_argument("--status-only", action="store_true", help="Write a JSON status report for tracked raw/runtime/prompt assets and exit.")
    parser.add_argument("--max-requests", type=int, help="Maximum new image requests per selected category.")
    parser.add_argument("--timeout", type=int, default=300)
    parser.add_argument("--retries", type=int, default=2)
    parser.add_argument("--retry-sleep", type=float, default=8.0)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    categories = set(args.category or ["actors", "icons", "maps"])
    if "all" in categories:
        categories = {"maps", "actors", "icons", "ui"}
    RAW_ROOT.mkdir(parents=True, exist_ok=True)
    if args.status_only:
        write_status_report(args)
        return 0
    manifest: list[dict] = []
    generated_count = 0
    try:
        if "maps" in categories:
            generated_count += run_maps(args, manifest)
        if "actors" in categories:
            generated_count += run_actors(args, manifest)
        if "icons" in categories:
            generated_count += run_icons(args, manifest)
        if "ui" in categories:
            generated_count += run_ui(args, manifest)
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    manifest_path = RAW_ROOT / "image2_unified_assets_manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote manifest: {manifest_path}")
    print(f"New image requests: {generated_count}")
    status_args = argparse.Namespace(**vars(args))
    status_args.only = None
    status_args.only_asset = None
    write_status_report(status_args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
