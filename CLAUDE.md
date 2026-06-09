# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**《轮回仙途》(Samsara Ascension)** — a cultivation-themed hybrid Roguelite game (action + deck-building + bullet hell). Top-down / isometric 45° view, targeting PC (Steam) first, mobile later.

**Tagline:** 天地为棋，万法归一 (Heaven and Earth as the Board, All Paths Converge as One)

**Current state:** Godot 4.6 prototype in `game/` — playable roguelite loop with combat, affixes, five stages, meta progression. GDD v6.0/v7.0 documents remain the design reference; see `game/README.md` for implementation status.

## Engine & Tech Stack

- **Engine:** Godot 4.6.3 (2D), project root `game/`
- **Data architecture (from GDD §28):** Three-layer pattern:
  1. **CSV/Excel** — designer-facing config tables (skills, affixes, pets, weather, events, enemies, dao traditions, level generation)
  2. **Enum layer** — compile-time type safety (`TriggerType`, `EffectType`, `Element`, `Quality`, `StatusType`)
  3. **Runtime structs** — `CompiledTag` and similar, compiled once at load time from CSVs
- **Target platforms:** PC (Steam) primary, mobile secondary
- **Session length:** 15–30 min main run, unlimited endless mode
- **Target playtime:** 200+ hours

## Design Documents

The GDD is the single source of truth. Always consult the **latest version (v6.0)** first:

| File | Version | Key Additions |
|------|---------|---------------|
| `GDD_轮回仙途_v6.0.md` | v6.0 (latest) | Structured random level generation, room layout rules, enemy wave design, level generation config tables |
| `GDD_轮回仙途_v5.0.md` | v5.0 | Damage pipeline with Dao-rhyme decay, Dao-tradition system, boss phase anti-overflow, crit special effects |
| `GDD_轮回仙途_v3.1.md` | v3.1 | Difficulty system, past-life legacies, build visualization |
| `GDD_轮回仙途_v3.0.md` | v3.0 | Deep optimization: pet/artifact/spirit systems merged |
| `GDD_轮回仙途_v2.0.md` | v2.0 | Pets + artifact spirits + endless mode |
| `GDD_轮回仙途_v1.0.md` | v1.0 | Initial complete framework |
| `docs/UIUX_轮回仙途_v1.0.md` | UI v1.0 | UI/UX 美术规范：Design Token、界面清单、组件库、HUD/Modal 线框、动效与资产清单（对齐 GDD §24–25） |

Older versions exist for revision history only; v6.0 supersedes them for all design decisions. **UI 实现以 `docs/UIUX_轮回仙途_v1.0.md` 为准。**

## Core Systems Architecture

The game has **20+ interconnected systems**. When implementing, understand these dependencies:

### Critical Path (Phase 1–3)
1. **Basic Operations (§4):** WASD movement, spacebar dodge (invincibility frames), mouse-aim combat, ability hotkeys (RMB/Q/E/R)
2. **Combat System (§7):** 10-stage damage pipeline with Dao-rhyme decay (diminishing returns across 4 damage buckets: Affix×Environment×Companion×Realm). Status effects (burn/freeze/paralyze/poison/slow). Critical-hit "Heaven's Chance" special effects system.
3. **Affix/Word System (§9):** The core build system — skills have 5 upgrade layers, affixes combo across elements. ~50+ affix combinations. Quality tiers: Common→Rare→Epic→Legendary→Dao.
4. **Level Generation (§14):** Structured random generation — skeleton (room sequence + types) generated first, then room layouts filled. 5 stages per run, each with a boss. Room types: combat, elite, shop, event, rest, hidden.
5. **Realm/Cultivation System (§6):** 5 stages (Qi Refining → Foundation → Golden Core → Nascent Soul → Tribulation → Ascension). Each breakthrough grants a talent choice (3 options) and expands affix slots (3→5→7→9→12).

### Depth Systems (Phase 4)
6. **Weather × Terrain Interaction (§8):** 8 weather types modify terrain and element damage. Weather + terrain create emergent combos (e.g., rain pools conduct lightning, dry ground amplifies fire). First-time interactions trigger tutorial-style slow-motion demonstrations.
7. **Spirit Pet System (§12):** 6 pets, each with element affinity, passive bonuses, and a coordinated skill (V+direction key). Pets have pity-timer acquisition guarantees.
8. **Artifact Spirit System (§13):** Weapon-bound spirits with personalities, independent active skill (F key), awakening mechanics.
9. **Character & Spirit Root System (§5):** 6 characters (Swordsman, Body Cultivator, Pill Cultivator, Talisman Cultivator, Demon Cultivator, Rogue Cultivator) × 8 spirit roots (Fire/Water/Thunder/Wood/Earth/Chaos/Heavenly/Dual). Each character has a unique combat mechanic (Sword Intent, Rage, Pill Heart, Talisman Array, Demonization, Wanderer). Fragment narrative system (6 memory fragments per character).
10. **Dao Tradition System (§10.5):** Build milestone achievements — collect specific affix combos to awaken a Dao Tradition (title + visual effect + stat boost). 7 general + 6 character-specific traditions.
11. **Karma System (§16):** Choices accumulate karma markers (Good/Evil/Dao Heart/Greed/Rebellion). Karma influences future event availability and endings.

### Meta Systems (Phase 5)
12. **Difficulty System (§3):** Three "Dao Heart" modes (Ask Dao/Enlighten/Prove Dao) replacing Easy/Normal/Hard. Internal "Heart Demon Trial" optional challenges. Endless mode uses natural scaling instead.
13. **Past-Life Legacy (§20):** On death, choose one affix to carry into next run at reduced quality. Guides build direction without full persistence.
14. **Endless Mode (§19):** Post-ascension infinite descent. Natural enemy scaling (15%/layer), mechanical defenses at layer 31+, adversarial affixes at layer 41+.
15. **Out-of-Run Growth (§21):** Reincarnation points for permanent upgrades. Destiny Seeds influence run RNG weights (partially revealed, partially hidden).
16. **Dynamic Difficulty (§23):** 6-layer soft anti-overflow system — Dao-rhyme decay, boss phase gates, defense formula, mechanical defense, adversarial affixes, minor HP scaling. No hard damage caps.

## Key Design Principles

When making implementation decisions, follow these rules from the GDD:

1. **Choice over luck** — all randomness gives the player meaningful options (3-choice affix picks, 2–3 path branches)
2. **Discovery over tutorial** — affix combos and weather interactions are discovered through play, not explained upfront. First-time interactions use in-world demonstrations, not pop-up tutorials.
3. **Rhythm over intensity** — weak→strong→overwhelming arc within each run. Breathing points before bosses.
4. **Death is progress** — past-life legacies, reincarnation points, fragment narratives. Death always gives something.
5. **Cultivation IS the roguelike** — every xianxia concept maps directly to a roguelike mechanic (tribulation = boss, breakthrough = level-up, reincarnation = new run).

## Naming Conventions (from GDD §32)

Game terms use cultivation/xianxia terminology:
- HP → 真元, Mana → 灵力, ATK → 攻伐之力, DEF → 护体灵气
- Crit → 天机一击, Dodge → 御风步, XP → 修为
- Gold → 灵石, Shop → 坊市, Death → 道消, Resurrection → 轮回
- Buff → 机缘, Debuff → 劫数, Build → 道路

Use these in player-facing UI. Use standard English terms in code (`hp`, `mana`, `attack`, `defense`, `crit`, `dodge`, `xp`, `gold`).

## Data-Driven Design

All game content lives in CSV/Excel config tables, NOT hardcoded. When adding content:
- Add rows to the appropriate config table (skills, affixes, enemies, events, etc.)
- Define enum values in the enum layer
- The runtime layer compiles configs at load time — never write per-item logic in code

The config table schemas are defined in GDD §28.2–28.7.

## Development Roadmap

From GDD §29 — total estimated ~22 weeks (5.5 months) to release:
- **Phase 1 (2 weeks):** Core combat prototype — movement, dodge, basic attack, 1 spell, 1 enemy, 1 boss, basic HUD
- **Phase 2 (3 weeks):** Affix system — 30 affixes, 5 combos, 3-layer skill upgrades, damage pipeline with Dao-rhyme decay
- **Phase 3 (5 weeks):** Full run loop — level generation, weather system (3 types), 1 pet prototype, difficulty selection, build visualization
- **Phase 4 (6 weeks):** All content — all 8 weather types, 6 characters, 8 spirit roots, 6 pets, 6 artifact spirits, all events, Dao traditions
- **Phase 5 (6 weeks):** Endless mode + polish — rankings, seasons, daily challenges, UI art, VFX, audio, tutorial, balance, Steam page

## Competitive References

When unsure about design details, reference these games:
- **Hades** — combat feel, narrative integration, execution animations
- **Slay the Spire** — affix combo depth, structured random maps
- **The Binding of Isaac** — item pool combinatorial explosion, room randomness
- **Warm Snow (暖雪)** — cultivation art style
- **Vampire Survivors** — bullet density, number inflation
