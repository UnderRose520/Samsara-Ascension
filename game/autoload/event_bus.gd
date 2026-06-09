extends Node

signal damage_dealt(result: Dictionary)
signal player_hp_changed(current: float, maximum: float)
signal combo_updated(count: int)
signal enemy_killed(enemy: Node)
signal player_died
signal run_started(seed_value: int)
signal affix_acquired(affix_id: String)
signal affix_choice_requested(offers: Array, context: Dictionary)
signal affix_choice_closed
signal all_enemies_cleared(wave: int)
signal combo_milestone(count: int)
signal combo_discovered(combo_id: String)
signal skill_layer_unlocked(skill_id: String, layer: int)
signal gold_changed(amount: int)
signal crit_moment_requested(text: String, duration: float)
signal affix_reroll_requested
signal affix_skip_requested
signal wave_changed(wave: int)
signal weather_changed(weather_id: String, weather_name: String)
signal path_choice_requested(branches: Array)
signal path_choice_closed(choice_id: String)
signal room_entered(room: Dictionary, stage: Dictionary)
signal run_completed(victory: bool)
signal pet_acquired(pet_id: String)
signal pet_coord_feedback(text: String)
signal run_setup_confirmed
signal breakthrough_requested(offers: Array, context: Dictionary)
signal breakthrough_closed(talent_id: String)
signal realm_changed(realm_level: int, affix_slots: int)
signal legacy_choice_requested(affixes: Array)
signal legacy_choice_closed(affix_id: String)
signal display_settings_changed
signal event_requested(event: Dictionary, choices: Array)
signal event_closed(choice_index: int)
signal dao_tradition_awakened(tradition: Dictionary)
signal dao_tradition_progress(progress: Dictionary)
signal karma_changed(karma: Dictionary)
signal shop_requested(offers: Array, context: Dictionary)
signal shop_closed(purchased: bool)
signal spell_unlock_changed(unlocked_slots: Array)
signal learn_feedback(text: String, accent: String)
