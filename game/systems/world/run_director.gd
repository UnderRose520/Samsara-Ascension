extends Node

const AffixBuildMatcher = preload("res://systems/affix/affix_build_matcher.gd")

const NO_FEEDBACK_SEC := 30.0
const BUILD_MISS_LIMIT := 2

var seconds_since_highlight := 0.0
var build_miss_streak := 0
var reward_fix_ready := false
var tempo_help_ready := false
var survival_help_ready := false
var _low_hp_seen := false
var _stage_reward_fix_used := {}
var _stage_tempo_help_used := {}
var _stage_survival_help_used := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.run_started.connect(_on_run_started)
	EventBus.room_entered.connect(_on_room_entered)
	EventBus.combo_milestone.connect(func(count: int) -> void: record_highlight("combo_%d" % count))
	EventBus.combo_discovered.connect(func(_combo_id: String) -> void: record_highlight("combo_discovered"))
	EventBus.dao_tradition_awakened.connect(func(_tradition: Dictionary) -> void: record_highlight("dao_awaken"))
	EventBus.unity_burst_requested.connect(func(_payload: Dictionary) -> void: record_highlight("unity"))
	EventBus.crit_moment_requested.connect(func(_text: String, _duration: float) -> void: record_highlight("crit"))
	EventBus.pet_coord_hit.connect(func(_enemy: Node) -> void: record_highlight("pet_coord"))
	EventBus.hidden_chain_discovered.connect(func(_id: String, _name: String, _payload: Dictionary) -> void: record_highlight("hidden_chain", 1.0))
	EventBus.player_hp_changed.connect(_on_player_hp_changed)


func _process(delta: float) -> void:
	if not RunContext.run_active or RunContext.ui_blocking:
		return
	seconds_since_highlight += delta
	if seconds_since_highlight >= NO_FEEDBACK_SEC:
		var stage := RunContext.current_stage
		if not bool(_stage_tempo_help_used.get(stage, false)):
			tempo_help_ready = true


func record_highlight(reason: String = "", weight: float = -1.0) -> void:
	var resolved := weight if weight >= 0.0 else _highlight_weight(reason)
	seconds_since_highlight *= clampf(1.0 - resolved, 0.0, 1.0)


func get_offer_context_bonus() -> Dictionary:
	var result := {}
	if reward_fix_ready:
		result["director_build_boost"] = 2.0
		result["director_reason"] = "道势向当前修行靠拢"
		_stage_reward_fix_used[RunContext.current_stage] = true
		reward_fix_ready = false
	if tempo_help_ready:
		result["director_build_boost"] = maxf(float(result.get("director_build_boost", 1.0)), 1.2)
		result["director_hint"] = "天地灵机渐盛"
		_stage_tempo_help_used[RunContext.current_stage] = true
		tempo_help_ready = false
		record_highlight("tempo_help")
	if survival_help_ready:
		result["director_survival_help"] = 1.7
		result["director_build_boost"] = maxf(float(result.get("director_build_boost", 1.0)), 1.25)
		result["director_hint"] = "绝境处生机浮现"
		_stage_survival_help_used[RunContext.current_stage] = true
		survival_help_ready = false
	return result


func record_reward_offer(offers: Array, context: Dictionary = {}) -> void:
	if bool(context.get("from_event", false)):
		return
	var has_build_offer := false
	var desired_tags: Array = context.get("desired_combo_tags", [])
	var element_bias := str(context.get("element_bias", ""))
	for tag in offers:
		if _is_build_offer(tag, element_bias, desired_tags):
			has_build_offer = true
			break
	if has_build_offer:
		build_miss_streak = 0
		return
	build_miss_streak += 1
	var stage := RunContext.current_stage
	if build_miss_streak >= BUILD_MISS_LIMIT and not bool(_stage_reward_fix_used.get(stage, false)):
		reward_fix_ready = true


func describe_pending() -> String:
	if reward_fix_ready:
		return "道势向当前修行靠拢"
	if tempo_help_ready:
		return "天地灵机渐盛"
	if survival_help_ready:
		return "绝境处生机浮现"
	return ""


func _on_run_started(_seed: int) -> void:
	seconds_since_highlight = 0.0
	build_miss_streak = 0
	reward_fix_ready = false
	tempo_help_ready = false
	survival_help_ready = false
	_low_hp_seen = false
	_stage_reward_fix_used.clear()
	_stage_tempo_help_used.clear()
	_stage_survival_help_used.clear()


func _on_room_entered(_room: Dictionary, _stage: Dictionary) -> void:
	record_highlight("room_entered")
	_low_hp_seen = false


func _on_player_hp_changed(current: float, maximum: float) -> void:
	if maximum <= 0.0 or not RunContext.run_active:
		return
	if current / maximum > 0.35 or _low_hp_seen:
		return
	var stage := RunContext.current_stage
	if bool(_stage_survival_help_used.get(stage, false)):
		return
	_low_hp_seen = true
	survival_help_ready = true


func _highlight_weight(reason: String) -> float:
	match reason:
		"combo_10":
			return 0.25
		"combo_30":
			return 0.45
		"combo_60", "combo_100", "combo_200":
			return 0.75
		"combo_discovered", "hidden_chain", "dao_awaken", "unity":
			return 1.0
		"crit", "pet_coord":
			return 0.55
		"room_entered":
			return 0.2
	return 0.75


func _is_build_offer(tag, element_bias: String, desired_tags: Array) -> bool:
	if typeof(tag) == TYPE_DICTIONARY:
		if bool(tag.get("locked", false)):
			return false
		tag = tag.get("tag")
	if tag == null:
		return false
	if AffixBuildMatcher.matches(tag, element_bias, desired_tags):
		return true
	if desired_tags.is_empty() and element_bias.is_empty():
		return int(tag.dao_bucket) > 0
	return false
