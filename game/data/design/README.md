# Design Data Guide

This folder contains design guidance tables. They are not all runtime-loaded yet.

Use them as the bridge between `docs/玩家上头手册.md` and the actual runtime CSV/GDScript systems.

## Recommended Entry Points

1. `implementation_gap_audit.csv` - what is missing between design and runtime.
2. `content_pack_plan.csv` - what to build in batch 0/1/2.
3. `feedback_moments.csv` - how each satisfying combat moment should feel.
4. `starting_paths.csv` - Dao path identity and first-minutes promise.
5. `weapon_roles.csv` - weapon role, source, growth, and no-go rules.
6. `hidden_chain_rollout.csv` - hidden-chain rollout and natural discovery targets.
7. `reward_card_quota.csv` - minimum reward-card content quotas.
8. `death_variation_rules.csv` - anti-repetition rules for death/regret narrative.
9. `death_line_pool.csv` - concrete death-regret line variants.
10. `remnant_dream_variants.csv` - reincarnation dream variants by Dao/progress.
11. `run_director_rules.csv` - opportunity delivery, pity, mutex, and anti-repeat rules.
12. `event_playbook.csv` - battlefield event triggers, priority, fallback, and risk.
13. `build_archetypes.csv` - replayable build lanes and support requirements.

## Runtime Mapping

| Design table | Runtime destination |
|---|---|
| `starting_paths.csv` | `data/paths/cultivation_paths.csv`, run setup UI, player start state |
| `weapon_roles.csv` | `data/weapons/weapons.csv`, `WeaponRegistry`, player/enemy attacks |
| `enemy_weapon_roles.csv` | `data/enemies/enemies.csv`, enemy archetypes, enemy skills |
| `weather_playbook.csv` | `data/weather/weather.csv`, room/stage generation |
| `reward_sources.csv` | affixes, events, legacy rewards, artifact fragments |
| `event_playbook.csv` | battlefield event system, room state, VFX fallbacks |
| `content_pack_plan.csv` | milestone planning and acceptance checks, not runtime-loaded |
| `build_archetypes.csv` | reward weights, Dao-path synergies, weapon inscriptions |
| `feedback_moments.csv` | `VfxManager`, SFX, hit stop, screen shake, UI callouts |
| `boss_playbook.csv` | `data/enemies/boss_phases.csv`, boss skill pools, boss drops |
| `enemy_realm_scaling` | `data/enemies/enemy_realms.csv`, `data/enemies/enemies.csv`, enemy spawn stat rolls |
| `run_director_rules.csv` | stage generation, reward selection, event injection |
| `longterm_goals.csv` | save data, codex, records, unlocks |
| `hidden_chain_rollout.csv` | hidden chain triggers, codex reveal, run director |
| `reward_card_quota.csv` | reward pools, card templates, locked-option UI |
| `death_variation_rules.csv` | death montage, reincarnation dreams, past-life records |
| `death_line_pool.csv` | death montage line selector |
| `remnant_dream_variants.csv` | reincarnation dream selector, past-life records |

## Rule

Do not copy every design field into runtime CSVs at once. First implement batch 0 and prove the player can feel:

- a clear identity,
- one satisfying attack loop,
- one weather/weapon interaction,
- one meaningful reward choice,
- one memorable death or boss moment.
