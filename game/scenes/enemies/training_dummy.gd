extends CharacterBody2D

const GameConstants = preload("res://core/constants/game_constants.gd")
const DamagePipeline = preload("res://systems/combat/damage_pipeline.gd")
const CombatContextBuilder = preload("res://systems/combat/combat_context_builder.gd")
const RunRng = preload("res://core/utils/run_rng.gd")
const HealthComponentScript = preload("res://systems/combat/health_component.gd")
const EnemySkillRegistry = preload("res://systems/combat/enemy_skill_registry.gd")
const EnemySpawnRegistry = preload("res://systems/combat/enemy_spawn_registry.gd")
const EnemySkillController = preload("res://systems/combat/enemy_skill_controller.gd")
const BossPhaseRegistry = preload("res://systems/combat/boss_phase_registry.gd")
const AssetPaths = preload("res://assets/asset_paths.gd")

@onready var health: Node = $HealthComponent
@onready var status: Node = $StatusComponent
@onready var nameplate_bg: TextureRect = $NameplateBg
@onready var name_label: Label = $NameLabel
@onready var world_hp: WorldEnemyHealthBar = $WorldEnemyHealthBar
@onready var action_label_bg: TextureRect = $ActionLabelBg
@onready var action_label: Label = $ActionLabel
@onready var body_visual: Sprite2D = $BodyVisual

var _flash := 0.0
var _is_boss := false
var _is_elite := false
var _has_persistent_nameplate := false
var _contact_damage := 12.0
var _display_name := "训练木人"
var _enemy_id := ""
var _death_handled := false
var _move_speed := GameConstants.ENEMY_MOVE_SPEED
var _steer_velocity := Vector2.ZERO
var _slot_dir := Vector2(0, -1)
var _orbit_radius := GameConstants.ENEMY_ORBIT_RADIUS
var _speed_jitter := 1.0
var _archetype := "normal"
var _room_type := "combat"
var _skills: EnemySkillController
var _anim_state := "idle"
var _visual_facing := Vector2.RIGHT
var _last_damage_source := ""
var _last_damage_element := ""
var _last_damage_had_weather_synergy := false
var _status_feedback_cd := 0.0
var _boss_phase_gates: Array[float] = []
var _boss_phase_gate_index := 0
var _boss_gate_lock := 0.0
var _realm_name := ""
var _realm_level := 1
var _is_promoted_realm := false
var _stat_traits: Array[String] = []
var _spawn_index := 0
var _weapon_id := "claw"
var _sprite_faces_left_by_default := false
var _mutation_timer := 0.0
var _mutation_damage := 0.0
var _mutation_element := "fire"
var _separation_push := Vector2.ZERO
var _separation_timer := 0.0
var _action_label_text := ""
var _action_label_color := Color.WHITE
var _action_label_timer := 0.0
var _redraw_timer := 0.0
var _status_icon_texture_cache: Dictionary = {}
var _combat_fx_texture_cache: Dictionary = {}
var _movement_trail_texture_cache: Dictionary = {}
var _windup_weapon_texture_hits := 0
var _movement_trail_texture_hits := 0
var _nameplate_texture_hits := 0
var _guard_link_visual_time := 0.0
var _plate_reveal_timer := 0.0

const SEPARATION_REFRESH_BASE := 0.10
const ACTION_LABEL_REFRESH_SEC := 0.12
const ENEMY_REDRAW_INTERVAL := 1.0 / 24.0
const STATUS_ICON_SIZE := 7.0
const STATUS_ICON_MAX := 6
const ORDINARY_PLATE_REVEAL_SEC := 0.65
const GUARD_AURA_RADIUS := 160.0
const GUARD_DAMAGE_REDUCTION := 0.35

func _ready() -> void:
	health.max_hp = GameConstants.ENEMY_HP
	health.current_hp = GameConstants.ENEMY_HP
	health.changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	add_to_group("enemy")
	_apply_nameplate_assets()
	EventBus.display_settings_changed.connect(_apply_display_settings)
	_apply_display_settings()
	_refresh_name_label()
	_on_health_changed(health.current_hp, health.max_hp)
	_skills = EnemySkillController.new()
	_skills.setup(self, "normal")
	_separation_timer = float(_spawn_index % 5) * 0.018


func configure_enemy(display_name: String, is_boss: bool = false, room_type: String = "combat") -> void:
	var resolved_id := "boss" if is_boss else str(EnemySpawnRegistry.get_enemy_row_by_name(display_name).get("enemy_id", ""))
	_configure_enemy_resolved(display_name, resolved_id, is_boss, room_type)


func configure_enemy_by_id(enemy_id: String, is_boss: bool = false, room_type: String = "combat", display_name_override: String = "") -> void:
	var resolved_id := "boss" if is_boss else enemy_id.strip_edges().to_lower()
	var display_name := display_name_override.strip_edges()
	if display_name.is_empty():
		display_name = EnemySpawnRegistry.get_display_name(resolved_id)
	_configure_enemy_resolved(display_name, resolved_id, is_boss, room_type)


func _configure_enemy_resolved(display_name: String, enemy_id: String, is_boss: bool = false, room_type: String = "combat") -> void:
	_display_name = display_name
	_enemy_id = "boss" if is_boss else enemy_id.strip_edges().to_lower()
	_is_boss = is_boss
	var enemy_row := EnemySpawnRegistry.get_enemy_row(_enemy_id)
	var identity_elite := bool(enemy_row.get("is_elite", false)) or EnemySpawnRegistry.is_elite_display_name(display_name)
	_is_elite = identity_elite or room_type == "combat_hard"
	_has_persistent_nameplate = is_boss or identity_elite
	_room_type = room_type
	_contact_damage = 22.0 if is_boss else 12.0
	_move_speed = GameConstants.ENEMY_BOSS_MOVE_SPEED if is_boss else GameConstants.ENEMY_MOVE_SPEED
	_archetype = EnemySpawnRegistry.resolve_archetype_for_id(_enemy_id, is_boss, room_type) if not _enemy_id.is_empty() else EnemySkillRegistry.resolve_archetype(display_name, is_boss, room_type)
	var arch_row := EnemySkillRegistry.get_archetype(_archetype)
	_move_speed *= float(arch_row.get("move_speed_mult", 1.0))
	scale = Vector2(1.6, 1.6) if is_boss else Vector2.ONE
	_skills = EnemySkillController.new()
	_skills.setup(self, _archetype)
	if is_boss:
		var boss_phases := BossPhaseRegistry.get_phases("boss")
		_skills.setup_boss_phases(boss_phases)
		_boss_phase_gates = _build_boss_phase_gates(boss_phases)
		_boss_phase_gate_index = 0
		_boss_gate_lock = 0.0
	_refresh_name_label()
	_apply_body_sprite()
	_refresh_world_overlay_visibility()
	queue_redraw()


func _apply_body_sprite() -> void:
	if body_visual == null:
		return
	var path: String = AssetPaths.enemy_sprite_for_identity(_enemy_id, _archetype, _is_boss, SaveManager.get_sprite_style())
	_sprite_faces_left_by_default = _enemy_sprite_faces_left(path)
	if body_visual.has_method("set_texture_path"):
		body_visual.set_texture_path(path)
	elif ResourceLoader.exists(path):
		body_visual.texture = load(path)
	else:
		body_visual.texture = null
		push_error("TrainingDummy missing image2 enemy texture `%s`" % path)
	var visual_scale := 1.36 if _is_boss else (1.18 if _has_persistent_nameplate or _is_promoted_realm else 1.10)
	body_visual.scale = Vector2(visual_scale, visual_scale)
	if body_visual.has_method("set_animation_prefix_name"):
		body_visual.set_animation_prefix_name(_anim_state)
	_apply_visual_facing()


func configure_as_boss() -> void:
	configure_enemy("关底守将", true, "boss")


func set_enemy_weapon_id(weapon_id: String) -> void:
	_weapon_id = weapon_id if not weapon_id.is_empty() else "claw"
	_refresh_action_label()
	queue_redraw()


func debug_force_windup(skill_type: String = "melee", progress: float = 0.58) -> void:
	if _skills == null:
		return
	if _skills.has_method("debug_force_windup"):
		_skills.debug_force_windup(skill_type, progress)
	queue_redraw()


func get_enemy_projectile_semantics(skill: Dictionary = {}) -> Dictionary:
	var skill_id := str(skill.get("id", ""))
	var result := _weapon_projectile_semantics(_weapon_id)
	match skill_id:
		"blade_arc":
			result["element"] = "thunder"
			result["status"] = ""
			result["status_duration"] = 0.0
			result["color"] = Color(0.55, 0.9, 1.0)
		"burst", "boss_rain":
			result["element"] = "fire"
			result["status"] = "burn"
			result["status_duration"] = maxf(float(result.get("status_duration", 0.0)), 2.2)
			result["color"] = Color(1.0, 0.36, 0.18)
		"fan_volley":
			if not str(result.get("status", "")).is_empty():
				result["status_duration"] = clampf(float(result.get("status_duration", 0.0)), 0.6, 1.0)
	result["weapon_id"] = _weapon_id
	return result


func _build_boss_phase_gates(phases: Array) -> Array[float]:
	var gates: Array[float] = []
	for phase in phases:
		if typeof(phase) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = phase
		var ratio := float(row.get("hp_ratio", 1.0))
		if ratio > 0.0 and ratio < 1.0:
			gates.append(ratio)
	gates.sort()
	gates.reverse()
	return gates


func scale_contact_damage(mult: float) -> void:
	if mult <= 0.0:
		return
	_contact_damage *= mult


func scale_move_speed(mult: float) -> void:
	if mult <= 0.0:
		return
	_move_speed *= mult


func trigger_spirit_mutation(duration: float = 5.0, element_key: String = "fire") -> void:
	if _death_handled or _is_boss or _mutation_timer > 0.0:
		return
	_mutation_timer = maxf(duration, 1.0)
	_mutation_element = element_key if not element_key.is_empty() else "fire"
	_mutation_damage = maxf(18.0, _contact_damage * 1.75)
	_move_speed *= 0.7
	scale *= 1.5
	_flash = 0.45
	_show_status_hit_feedback("burn")
	EventBus.pet_coord_feedback.emit("敌人异变：灵气暴走，5秒后自爆")
	VfxManager.spawn_world(global_position, "gold", Color(1.0, 0.42, 0.16))
	queue_redraw()


func apply_instance_stats(stats: Dictionary) -> void:
	var speed_mult := float(stats.get("speed", 1.0))
	var defense_mult := float(stats.get("def", 1.0))
	var attack_mult := float(stats.get("atk", 1.0))
	_move_speed *= speed_mult
	health.defense *= defense_mult
	_realm_name = str(stats.get("realm_name", ""))
	_realm_level = int(stats.get("realm_level", 1))
	_is_promoted_realm = bool(stats.get("promoted", false))
	if _is_promoted_realm:
		_has_persistent_nameplate = true
	_stat_traits.clear()
	if _is_promoted_realm:
		_stat_traits.append("越阶")
	if defense_mult >= 1.35:
		_stat_traits.append("厚甲")
	if speed_mult >= 1.18:
		_stat_traits.append("迅捷")
	if attack_mult >= 1.35:
		_stat_traits.append("强攻")
	_refresh_name_label()
	queue_redraw()


func apply_elite_affixes(affix_ids: Array) -> void:
	const EliteAffixRegistry = preload("res://systems/combat/elite_affix_registry.gd")
	if affix_ids.is_empty():
		return
	_is_elite = true
	_has_persistent_nameplate = true
	_contact_damage *= 1.18
	health.defense *= 1.12
	var suffix: PackedStringArray = []
	for affix_id in affix_ids:
		var row: Dictionary = EliteAffixRegistry.get_affix(str(affix_id))
		if row.is_empty():
			continue
		_move_speed *= float(row.get("move_speed_mult", 1.0))
		_contact_damage *= float(row.get("contact_damage_mult", 1.0))
		var hp_scale: float = float(row.get("hp_mult", 1.0))
		if hp_scale != 1.0:
			health.max_hp *= hp_scale
			health.current_hp = health.max_hp
			health.changed.emit(health.current_hp, health.max_hp)
		suffix.append(EliteAffixRegistry.get_label(str(affix_id)))
	if not suffix.is_empty():
		_display_name = "%s·%s" % [_display_name, "·".join(suffix)]
		_refresh_name_label()
	queue_redraw()


func get_display_name() -> String:
	return _display_name


func get_codex_id() -> String:
	return _enemy_id


func set_display_name_override(display_name: String) -> void:
	if display_name.is_empty():
		return
	_display_name = display_name
	_refresh_name_label()


func is_boss_unit() -> bool:
	return _is_boss


func is_elite_unit() -> bool:
	return _is_elite


func init_combat_slot(spawn_pos: Vector2, player_pos: Vector2, index: int, total: int, is_boss: bool) -> void:
	_spawn_index = index
	var count := maxi(total, 1)
	var from_player: Vector2 = spawn_pos - player_pos
	if from_player.length_squared() > 640.0:
		_slot_dir = from_player.normalized()
	else:
		var angle := TAU * float(index) / float(count) - PI * 0.5
		_slot_dir = Vector2.from_angle(angle)
	if is_boss:
		_orbit_radius = maxf(GameConstants.ENEMY_ORBIT_RADIUS_BOSS, 92.0)
	else:
		_orbit_radius = GameConstants.ENEMY_ORBIT_RADIUS + float(index % 7) * GameConstants.ENEMY_ORBIT_SPREAD
	_speed_jitter = RunRng.enemy_jitter(index).randf_range(0.88, 1.08)
	_separation_timer = float(index % 7) * 0.017
	_redraw_timer = float(index % 5) * 0.011
	if _skills:
		_skills.apply_spawn_stagger(index)


func _apply_display_settings() -> void:
	_refresh_world_overlay_visibility()
	_apply_body_sprite()


func _refresh_world_overlay_visibility() -> void:
	var show_hp: bool = SaveManager.get_display_setting("show_enemy_hp")
	var show_plate := show_hp and _should_show_world_plate()
	if world_hp:
		world_hp.visible = show_plate and not _is_boss
	if nameplate_bg:
		nameplate_bg.visible = show_plate and not _is_boss and nameplate_bg.texture != null
	name_label.visible = show_plate and not _is_boss
	action_label.visible = show_hp and not _action_label_text.is_empty()
	if action_label_bg:
		action_label_bg.visible = action_label.visible and action_label_bg.texture != null


func _refresh_name_label() -> void:
	name_label.text = _display_name
	if not _is_boss and not _is_promoted_realm and not _realm_name.is_empty() and not _display_name.begins_with(_realm_name):
		name_label.text = "%s·%s" % [_realm_name, _display_name]
	_apply_nameplate_lod()
	if _is_boss:
		name_label.add_theme_color_override("font_color", Color(0.96, 0.78, 0.42))
		name_label.add_theme_font_size_override("font_size", 13)
		_tint_nameplate(Color(1.0, 0.76, 0.42, 0.82))
	elif _is_promoted_realm:
		name_label.add_theme_color_override("font_color", Color(0.95, 0.68, 0.38))
		name_label.add_theme_font_size_override("font_size", 12)
		_tint_nameplate(Color(1.0, 0.58, 0.32, 0.70))
	elif _has_persistent_nameplate:
		name_label.add_theme_color_override("font_color", Color(0.96, 0.70, 0.44))
		name_label.add_theme_font_size_override("font_size", 12)
		_tint_nameplate(Color(0.95, 0.68, 0.36, 0.66))
	else:
		name_label.add_theme_color_override("font_color", Color(0.78, 0.90, 0.84, 0.66))
		name_label.add_theme_font_size_override("font_size", 10)
		_tint_nameplate(Color(0.55, 0.92, 0.80, 0.26))
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.add_theme_color_override("font_outline_color", Color(0.005, 0.012, 0.010, 0.84))


func _has_strong_nameplate() -> bool:
	return _is_boss or _has_persistent_nameplate or _is_promoted_realm


func _should_show_world_plate() -> bool:
	if _is_boss:
		return false
	if _has_strong_nameplate():
		return true
	if _plate_reveal_timer > 0.0:
		return true
	if _skills and (_skills.is_busy() or _skills.get_windup_progress() > 0.0):
		return true
	return _is_guarded_by_ally() or _mutation_timer > 0.0


func _reveal_world_plate(duration: float = ORDINARY_PLATE_REVEAL_SEC) -> void:
	if _has_strong_nameplate():
		return
	_plate_reveal_timer = maxf(_plate_reveal_timer, duration)
	_refresh_world_overlay_visibility()


func _apply_nameplate_lod() -> void:
	if nameplate_bg == null or name_label == null:
		return
	if _has_strong_nameplate():
		nameplate_bg.offset_left = -64.0
		nameplate_bg.offset_right = 64.0
		name_label.offset_left = -56.0
		name_label.offset_right = 56.0
	else:
		nameplate_bg.offset_left = -54.0
		nameplate_bg.offset_right = 54.0
		name_label.offset_left = -48.0
		name_label.offset_right = 48.0


func _apply_nameplate_assets() -> void:
	_nameplate_texture_hits = 0
	var tex := AssetPaths.load_texture(AssetPaths.ENEMY_NAMEPLATE)
	if nameplate_bg:
		nameplate_bg.texture = tex
		nameplate_bg.visible = tex != null
	if action_label_bg:
		action_label_bg.texture = tex
		action_label_bg.visible = false
	if tex != null:
		_nameplate_texture_hits = 2


func _tint_nameplate(tint: Color) -> void:
	if nameplate_bg:
		nameplate_bg.modulate = tint


func _on_health_changed(current: float, maximum: float) -> void:
	if world_hp:
		world_hp.set_values(current, maximum, false)
		world_hp.visible = SaveManager.get_display_setting("show_enemy_hp") and not _is_boss
	if _is_boss and maximum > 0.0:
		var ratio := current / maximum
		if current <= HealthComponentScript.HP_EPSILON:
			ratio = maxf(RunContext.last_boss_hp_ratio, 0.01)
		RunContext.record_boss_hp_ratio(_display_name, ratio)
		_emit_boss_health_update()
	if current <= HealthComponentScript.HP_EPSILON:
		if not _death_handled:
			_on_died()
		return


func _boss_phase_count() -> int:
	return maxi(_boss_phase_gates.size() + 1, 1)


func _boss_phase_name() -> String:
	if _skills == null:
		return ""
	return _skills.get_phase_name()


func _emit_boss_health_update() -> void:
	if not _is_boss:
		return
	EventBus.boss_health_changed.emit(
		_display_name,
		float(health.current_hp),
		float(health.max_hp),
		clampi(_boss_phase_gate_index, 0, _boss_phase_count() - 1),
		_boss_phase_count(),
		_boss_phase_name()
	)


func _emit_damage(result: Dictionary) -> void:
	result["world_position"] = global_position
	result["target_is_player"] = false
	result["target"] = self
	result["target_weapon_id"] = _weapon_id
	result["target_killed"] = health.current_hp <= HealthComponentScript.HP_EPSILON
	result["source_tag"] = _last_damage_source
	_last_damage_had_weather_synergy = bool(result.get("weather_synergy", false)) or bool(result.get("terrain_synergy", false))
	result["target_status"] = {
		"burning": status.is_burning(),
		"paralyzed": status.is_paralyzed(),
		"slowed": status.is_slowed(),
		"frozen": status.is_frozen(),
		"poisoned": status.is_poisoned(),
	}
	EventBus.damage_dealt.emit(result)


func _get_player() -> Node2D:
	return EntityCache.get_player() as Node2D


func _apply_movement() -> void:
	move_and_slide()
	var radius := 20.0 if _is_boss else 16.0
	global_position = GameConstants.clamp_to_arena(global_position, radius)
	_refresh_action_label(false)
	_update_animation_state()
	# Throttled: let _process()'s ENEMY_REDRAW_INTERVAL gate control actual redraws.
	if _needs_redraw() and _redraw_timer <= 0.0:
		_redraw_timer = ENEMY_REDRAW_INTERVAL
		queue_redraw()


func _physics_process(delta: float) -> void:
	if get_tree().paused or _death_handled:
		return
	_status_feedback_cd = maxf(_status_feedback_cd - delta, 0.0)
	_boss_gate_lock = maxf(_boss_gate_lock - delta, 0.0)
	_separation_timer = maxf(_separation_timer - delta, 0.0)
	_action_label_timer = maxf(_action_label_timer - delta, 0.0)
	var had_plate_reveal := _plate_reveal_timer > 0.0
	_plate_reveal_timer = maxf(_plate_reveal_timer - delta, 0.0)
	if had_plate_reveal and _plate_reveal_timer <= 0.0:
		_refresh_world_overlay_visibility()
	TerrainSystem.apply_body_effects(self, delta)
	if not health.is_alive():
		velocity = Vector2.ZERO
		return

	var player: Node2D = _get_player()
	if player == null:
		velocity = Vector2.ZERO
		_apply_movement()
		return

	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()

	if _skills:
		if _is_boss and health.max_hp > 0.0:
			var hp_ratio: float = float(health.current_hp) / float(health.max_hp)
			_skills.update_phase(hp_ratio)
			RunContext.record_boss_hp_ratio(_display_name, hp_ratio)
		_skills.tick(delta, player)
		if _skills.is_busy():
			_update_chase_visual_facing(to_player)
			_refresh_world_overlay_visibility()
			_apply_movement()
			return

	var speed: float = _move_speed * _speed_jitter * status.get_move_speed_mult()
	var target: Vector2 = _compute_chase_velocity(player, dist, speed)
	var blend: float = minf(1.0, delta * 8.0)
	_steer_velocity = _steer_velocity.lerp(target, blend)
	if target.length_squared() < 1.0:
		_steer_velocity = _steer_velocity.lerp(Vector2.ZERO, minf(1.0, delta * 12.0))
	if _steer_velocity.length_squared() < 16.0 and target.length_squared() < 1.0:
		_steer_velocity = Vector2.ZERO
	velocity = _steer_velocity
	_update_chase_visual_facing(to_player)

	_apply_movement()


func _refresh_action_label(force: bool = true) -> void:
	if not force and _action_label_timer > 0.0:
		return
	_action_label_timer = ACTION_LABEL_REFRESH_SEC
	var next_text := ""
	var next_color := Color(0.65, 0.62, 0.58)
	if _skills and _skills.get_action_label().length() > 0 and (_skills.is_busy() or _skills.get_windup_progress() > 0.0):
		next_text = "%s · %s" % [_weapon_label(), _skills.get_action_label()]
		next_color = Color(1.0, 0.45, 0.25)
	elif _steer_velocity.length_squared() > 3025.0:
		if _archetype == "sniper":
			next_text = "瞄准"
			next_color = Color(0.85, 0.75, 1.0)
		elif _archetype == "berserker":
			next_text = "冲锋"
			next_color = Color(1.0, 0.35, 0.25)
		elif _archetype == "shaman":
			next_text = "结印"
			next_color = Color(0.55, 0.95, 0.85)
	elif _steer_velocity.length_squared() > 64.0:
		next_text = ""
		next_color = Color(0.85, 0.8, 0.7)
	else:
		next_text = ""
		next_color = Color(0.65, 0.62, 0.58)
	_apply_action_label(next_text, next_color)


func _apply_action_label(next_text: String, next_color: Color) -> void:
	if next_text != _action_label_text:
		_action_label_text = next_text
		action_label.text = next_text
		action_label.visible = SaveManager.get_display_setting("show_enemy_hp") and not next_text.is_empty()
		if action_label_bg:
			action_label_bg.visible = action_label.visible and action_label_bg.texture != null
	if next_color != _action_label_color:
		_action_label_color = next_color
		var ink_color := next_color.lerp(Color(0.82, 0.95, 0.88, 1.0), 0.34)
		action_label.add_theme_color_override("font_color", Color(ink_color.r, ink_color.g, ink_color.b, 0.68))
		if action_label_bg:
			action_label_bg.modulate = Color(ink_color.r, ink_color.g, ink_color.b, 0.24)
	action_label.add_theme_constant_override("outline_size", 1)
	action_label.add_theme_color_override("font_outline_color", Color(0.005, 0.012, 0.010, 0.88))


func _stat_trait_label(fallback: String) -> String:
	if _stat_traits.is_empty():
		return fallback
	return "%s · %s" % [fallback, "·".join(_stat_traits.slice(0, 2))]

func _update_animation_state() -> void:
	if body_visual == null or not body_visual.has_method("set_animation_prefix_name"):
		return
	var next_state: String = "idle"
	if _skills and _skills.is_busy():
		next_state = "combat"
	elif velocity.length() > 25.0 or _steer_velocity.length() > 25.0:
		next_state = "walk"
	if next_state == _anim_state:
		return
	_anim_state = next_state
	body_visual.set_animation_prefix_name(_anim_state)


func _update_visual_facing(direction: Vector2) -> void:
	if absf(direction.x) < 0.05:
		return
	_visual_facing = direction.normalized()
	_apply_visual_facing()


func _update_chase_visual_facing(to_player: Vector2) -> void:
	var horizontal := 0.0
	if absf(to_player.x) > 1.0:
		horizontal = to_player.x
	if horizontal != 0.0:
		_visual_facing = Vector2(signf(horizontal), 0.0)
		_apply_visual_facing()


func _apply_visual_facing() -> void:
	if body_visual == null or absf(_visual_facing.x) < 0.05:
		return
	body_visual.flip_h = _visual_facing.x > 0.0 if _sprite_faces_left_by_default else _visual_facing.x < 0.0


func _enemy_sprite_faces_left(path: String) -> bool:
	var file_name := path.get_file()
	if file_name.begins_with("enemy_style_"):
		return true
	return false


func _needs_redraw() -> bool:
	if body_visual == null or body_visual.texture == null:
		return true
	if _flash > 0.0:
		return true
	if _has_dynamic_visual_state():
		return true
	return false


func _compute_chase_velocity(player: Node2D, dist_to_player: float, speed: float) -> Vector2:
	if dist_to_player > GameConstants.ENEMY_AGGRO_RANGE:
		return Vector2.ZERO

	var desired_radius := _orbit_radius
	if _is_boss:
		desired_radius = maxf(desired_radius, GameConstants.ENEMY_CONTACT_RANGE + 38.0)
	var slot_pos: Vector2 = player.global_position + _slot_dir * desired_radius
	var to_slot: Vector2 = slot_pos - global_position
	var slot_dist: float = to_slot.length()

	if _is_boss and dist_to_player < desired_radius * 0.8:
		return (global_position - player.global_position).normalized() * speed

	var desired := Vector2.ZERO
	if slot_dist > GameConstants.ENEMY_ARRIVAL_THRESHOLD:
		desired = to_slot.normalized() * speed

	var push := _get_separation_push(dist_to_player < 72.0)
	if desired.length_squared() < 0.001:
		if push.length_squared() < 0.001:
			return Vector2.ZERO
		return push.normalized() * minf(speed * 0.28, push.length() * 2.0)

	if _is_boss and dist_to_player < desired_radius * 1.2:
		desired += (global_position - player.global_position).normalized() * speed * 0.35

	if push.length_squared() > 0.001:
		return (desired + push * 0.55).limit_length(speed)
	return desired


func _compute_separation_push(near_player: bool) -> Vector2:
	var push := Vector2.ZERO
	var sep_radius: float = GameConstants.ENEMY_SEPARATION_RADIUS
	if near_player:
		sep_radius *= 1.4
	var sep_radius_sq := sep_radius * sep_radius
	for other in get_tree().get_nodes_in_group("enemy"):
		if other == self or not is_instance_valid(other):
			continue
		var offset: Vector2 = global_position - other.global_position
		var dist_sq := offset.length_squared()
		if dist_sq < sep_radius_sq and dist_sq > 0.0001:
			var dist := sqrt(dist_sq)
			push += offset / dist * (sep_radius - dist)
	return push


func _get_separation_push(near_player: bool) -> Vector2:
	if _separation_timer > 0.0:
		return _separation_push
	var jitter := float((_spawn_index % 5) + 1) * 0.008
	_separation_timer = SEPARATION_REFRESH_BASE + jitter
	_separation_push = _compute_separation_push(near_player)
	return _separation_push


func _process(delta: float) -> void:
	var dot: float = status.tick(self, delta)
	if dot > 0.0:
		_apply_incoming_damage(dot)
	if _mutation_timer > 0.0:
		_mutation_timer = maxf(_mutation_timer - delta, 0.0)
		if _mutation_timer <= 0.0:
			_explode_mutation()
	_flash = maxf(_flash - delta, 0.0)
	_guard_link_visual_time = maxf(_guard_link_visual_time - delta, 0.0)
	_redraw_timer = maxf(_redraw_timer - delta, 0.0)
	var needs_redraw := _flash > 0.0 or _steer_velocity.length_squared() > 100.0
	if _has_dynamic_visual_state():
		needs_redraw = true
	if needs_redraw and _redraw_timer <= 0.0:
		_redraw_timer = ENEMY_REDRAW_INTERVAL
		queue_redraw()


func get_burn_stacks() -> int:
	return status.get_burn_stacks()


func apply_status(status_name: String, duration: float) -> void:
	status.apply_status(status_name, duration)
	queue_redraw()


func receive_terrain_damage(amount: float, terrain_type: String = "") -> void:
	if amount <= 0.0 or _death_handled:
		return
	_remember_damage_source("terrain_%s" % terrain_type, terrain_type)
	var result := {
		"final_damage": amount,
		"world_position": global_position,
		"target_is_player": false,
		"is_crit": false,
		"is_combo": false,
		"element": terrain_type,
	}
	result["final_damage"] = _apply_incoming_damage(amount)
	_flash = 0.12
	_reveal_world_plate()
	_emit_damage(result)


func detonate_burn(base_damage: float) -> float:
	var raw: float = status.consume_combust(base_damage)
	if raw <= 0.0:
		return 0.0
	var ctx: Dictionary
	var holder: Node = null
	var player := _get_player()
	if player and player.has_node("AffixHolder"):
		holder = player.get_node("AffixHolder")
		ctx = holder.build_damage_context(
			raw,
			maxf(health.defense - holder.flat_defense * 0.5, 0.0),
			player.crit_rate,
			player.crit_mult,
			"combust",
		)
	else:
		ctx = CombatContextBuilder.build_fallback(
			raw,
			health.defense,
			player.crit_rate if player else 0.0,
			1.5,
			"fire",
			player,
			"combust",
			false,
		)

	var result: Dictionary = DamagePipeline.compute_pve(ctx)
	_remember_damage_source("combo_combust", "fire")
	result["final_damage"] = _apply_incoming_damage(result.final_damage)
	_flash = 0.2
	result["is_combo"] = true
	_reveal_world_plate()
	_emit_damage(result)
	return result.final_damage


func receive_projectile_hit(projectile: Area2D) -> void:
	var ctx: Dictionary
	var holder: Node = null
	var projectile_element := str(projectile.get("element_key") if "element_key" in projectile else "fire")
	var projectile_source := str(projectile.get("source_tag") if "source_tag" in projectile else "projectile")
	if projectile.owner_player and projectile.owner_player.has_node("AffixHolder"):
		holder = projectile.owner_player.get_node("AffixHolder")
		if projectile_element.is_empty():
			ctx = holder.build_damage_context(
				projectile.damage,
				maxf(health.defense - holder.flat_defense * 0.5, 0.0),
				projectile.owner_player.crit_rate,
				projectile.owner_player.crit_mult,
				"proj",
			)
		else:
			ctx = CombatContextBuilder.build_fallback(
				projectile.damage + holder.flat_attack,
				maxf(health.defense - holder.flat_defense * 0.5, 0.0),
				projectile.owner_player.crit_rate,
				projectile.owner_player.crit_mult,
				projectile_element,
				projectile.owner_player,
				"proj_%s" % projectile_element,
				true,
			)
			for value in holder.bucket_a:
				ctx["bucket_a"].append(value)
			for value in holder.bucket_b:
				ctx["bucket_b"].append(value)
			for value in holder.bucket_c:
				ctx["bucket_c"].append(value)
			for value in holder.bucket_d:
				ctx["bucket_d"].append(value)
	else:
		var owner := projectile.owner_player as Node2D
		ctx = CombatContextBuilder.build_fallback(
			projectile.damage,
			health.defense,
			owner.crit_rate if owner else 0.0,
			1.5,
			projectile_element,
			owner,
			"proj_%s" % projectile_element,
			false,
		)

	var result: Dictionary = DamagePipeline.compute_pve(ctx)
	_remember_damage_source(projectile_source, projectile_element)
	result["final_damage"] = _apply_incoming_damage(result.final_damage)
	_flash = 0.12
	_reveal_world_plate()
	_emit_damage(result)
	var projectile_status := str(projectile.get("status_on_hit") if "status_on_hit" in projectile else "")
	if not projectile_status.is_empty():
		apply_status(projectile_status, float(projectile.get("status_duration") if "status_duration" in projectile else 1.0))
		_show_status_hit_feedback(projectile_status)
	if projectile_source == "pet_coord":
		EventBus.pet_coord_hit.emit(self)

	if holder:
		var bonus: float = holder.proc_on_hit(self)
		if bonus > 0.0:
			pass
		if projectile.owner_player.has_node("ComboCounter"):
			projectile.owner_player.get_node("ComboCounter").register_hit()
		if projectile.owner_player.has_node("SkillProgression"):
			projectile.owner_player.get_node("SkillProgression").register_hit()


func receive_player_weapon_hit(player: CharacterBody2D, damage: float, element_key: String = "", hit_label: String = "weapon") -> void:
	if player == null or _death_handled:
		return
	var holder: Node = player.get_node("AffixHolder") if player.has_node("AffixHolder") else null
	var resolved_element := element_key
	if resolved_element.is_empty() or resolved_element == "physical":
		resolved_element = holder.get_element_bias() if holder and holder.has_method("get_element_bias") else ""
	if resolved_element.is_empty() or resolved_element == "physical":
		resolved_element = "earth"

	var ctx: Dictionary
	if holder:
		ctx = CombatContextBuilder.build_fallback(
			damage + holder.flat_attack,
			maxf(health.defense - holder.flat_defense * 0.5, 0.0),
			player.crit_rate,
			player.crit_mult,
			resolved_element,
			player,
			hit_label,
			true,
		)
		for value in holder.bucket_a:
			ctx["bucket_a"].append(value)
		for value in holder.bucket_b:
			ctx["bucket_b"].append(value)
		for value in holder.bucket_c:
			ctx["bucket_c"].append(value)
		for value in holder.bucket_d:
			ctx["bucket_d"].append(value)
	else:
		ctx = CombatContextBuilder.build_fallback(
			damage,
			health.defense,
			player.crit_rate,
			player.crit_mult,
			resolved_element,
			player,
			hit_label,
			false,
		)

	var result: Dictionary = DamagePipeline.compute_pve(ctx)
	_remember_damage_source(hit_label, resolved_element)
	result["final_damage"] = _apply_incoming_damage(result.final_damage)
	_flash = 0.14
	_reveal_world_plate()
	_emit_damage(result)

	if holder:
		holder.proc_on_hit(self)
	if player.has_node("ComboCounter"):
		player.get_node("ComboCounter").register_hit()
	if player.has_node("SkillProgression"):
		player.get_node("SkillProgression").register_hit()
	RunContext.add_dao_momentum(1.5, "weapon_hit")


func _apply_incoming_damage(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	amount = _apply_guard_protection(amount)
	if not _is_boss or health.max_hp <= 0.0 or _boss_phase_gate_index >= _boss_phase_gates.size():
		return health.take_damage(amount)
	if _boss_gate_lock > 0.0:
		return 0.0
	var gate_ratio: float = float(_boss_phase_gates[_boss_phase_gate_index])
	var gate_hp: float = float(health.max_hp) * gate_ratio
	var current_hp: float = float(health.current_hp)
	if current_hp > gate_hp and current_hp - amount <= gate_hp:
		var applied: float = health.take_damage(maxf(current_hp - gate_hp, 0.0))
		_boss_phase_gate_index += 1
		_boss_gate_lock = 0.35
		_flash = 0.24
		if _skills:
			_skills.update_phase(float(health.current_hp) / maxf(float(health.max_hp), 1.0))
		var phase_label := _skills.get_phase_name() if _skills else "守势崩裂"
		_emit_boss_health_update()
		EventBus.feedback_anchor_requested.emit("boss_phase_break", {
			"world_position": global_position,
			"label": "%s · %s" % [_display_name, phase_label],
			"color": Color(1.0, 0.45, 0.22),
		})
		EventBus.pet_coord_feedback.emit("%s 守势崩裂，余劲被化去" % _display_name)
		return applied
	return health.take_damage(amount)


func show_weapon_mod_status_feedback(status_name: String) -> void:
	_show_status_hit_feedback(status_name)


func _remember_damage_source(source: String, element: String = "") -> void:
	_last_damage_source = source
	_last_damage_element = element


func _show_status_hit_feedback(status_name: String) -> void:
	if _status_feedback_cd > 0.0:
		return
	_status_feedback_cd = 0.08
	var color := StatusComponent.status_color(status_name)
	_flash = maxf(_flash, 0.18)
	VfxManager.spawn_world_semantic(global_position, "hit", color, "", status_name, 1)
	if body_visual:
		VfxManager.flash_control(body_visual, color.lightened(0.25), 0.12)


func _on_died() -> void:
	if _death_handled:
		return
	_death_handled = true
	visible = false
	collision_layer = 0
	collision_mask = 0
	if status.is_burning():
		var player := _get_player()
		if player and player.has_node("SkillProgression"):
			player.get_node("SkillProgression").register_status_kill()
	remove_from_group("enemy")
	EventBus.enemy_killed.emit(self)
	if _is_guardian_unit():
		EventBus.pet_coord_feedback.emit("%s 护阵崩解，周围妖物失去庇护" % _display_name)
	var momentum := 2.0 + (13.0 if _is_elite else 0.0) + (18.0 if _is_boss else 0.0)
	var bonus_label := ""
	if _last_damage_source.begins_with("terrain_") or _last_damage_source == "combo_combust" or _last_damage_had_weather_synergy:
		momentum += 12.0
		bonus_label = "天象地形"
		RunContext.record_weather_kill(self, WeatherSystem.current_weather_id, {
			"source": _last_damage_source,
			"element": _last_damage_element,
			"elite": _is_elite,
		})
	RunContext.add_dao_momentum(momentum, "kill_%s" % _last_damage_source)
	if not bonus_label.is_empty():
		EventBus.pet_coord_feedback.emit("%s击杀 · 道势 +%d" % [bonus_label, int(round(momentum))])
	_maybe_grant_promoted_reward()
	if _is_boss:
		var inheritance := _boss_inheritance_label()
		EventBus.feedback_anchor_requested.emit("boss_inheritance", {
			"world_position": global_position,
			"label": "%s · %s" % [_display_name, inheritance],
			"color": Color(1.0, 0.84, 0.2),
		})
		EventBus.pet_coord_feedback.emit("%s败退，%s开启" % [_display_name, inheritance])
	var burst_preset := "gold" if _is_boss else ("combo" if _is_elite else "hit")
	var burst_color := Color(1.0, 0.84, 0.2) if _is_boss else GameConstants.COLOR_ENEMY
	VfxManager.spawn_world(global_position, burst_preset, burst_color)
	queue_free()


func _boss_inheritance_label() -> String:
	match _weapon_id:
		"soul_banner":
			return "魂幡传承 · 本命器祭炼"
		"xuanwu_shield":
			return "玄甲传承 · 法宝碎片"
		_:
			return "Boss传承 · 本命器祭炼"


func _explode_mutation() -> void:
	if _death_handled:
		return
	var radius := 130.0
	_death_handled = true
	visible = false
	collision_layer = 0
	collision_mask = 0
	remove_from_group("enemy")
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == self or not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		if global_position.distance_to((enemy as Node2D).global_position) > radius:
			continue
		if enemy.has_method("receive_terrain_damage"):
			enemy.receive_terrain_damage(_mutation_damage, _mutation_element)
	var player := _get_player()
	if player and global_position.distance_to(player.global_position) <= radius and player.has_method("receive_terrain_damage"):
		player.receive_terrain_damage(_mutation_damage * 0.55, _mutation_element)
	EventBus.pet_coord_feedback.emit("灵气暴走炸裂，可伤敌我")
	EventBus.crit_moment_requested.emit("灵气暴走", 0.28)
	VfxManager.spawn_world(global_position, "combo", Color(1.0, 0.38, 0.12))
	EventBus.enemy_killed.emit(self)
	queue_free()


func _maybe_grant_promoted_reward() -> void:
	if not _is_promoted_realm or _is_boss:
		return
	var rng := RunRng.make("promoted_reward_%d_%d_%d_%s" % [RunContext.current_stage, RunContext.current_room, _spawn_index, _display_name])
	if rng.randf() >= 0.35:
		return
	var gold_bonus := 4 + maxi(_realm_level, 1) * 2
	RunContext.gold += gold_bonus
	EventBus.gold_changed.emit(RunContext.gold)
	RunContext.add_dao_momentum(3.0 + float(_realm_level), "promoted_enemy")
	EventBus.pet_coord_feedback.emit("越阶斩敌 · 灵石 +%d · 道势微涨" % gold_bonus)
	VfxManager.spawn_world(global_position, "gold", Color(1.0, 0.72, 0.24))


func _draw() -> void:
	var radius := 16.0 if not _is_boss else 20.0
	var color: Color = _enemy_base_accent_color()
	_draw_presence_shadow(radius, color)
	if _is_guardian_unit():
		_draw_guard_aura(radius)
	var status_color: Color = status.get_visual_tint()
	var has_status := _has_active_status()
	if has_status:
		var foot_color := status_color
		foot_color.a = 0.11
		var shadow := _combat_fx_texture("actor_presence_shadow")
		if shadow:
			_draw_centered_texture(shadow, Vector2(0.0, radius * 0.62), Vector2(radius * 2.6, radius * 1.05), Color(foot_color.r, foot_color.g, foot_color.b, 0.32))
		var ring_color := status_color
		ring_color.a = 0.42
		var status_ring := _combat_fx_texture("player_dao_aura")
		if status_ring:
			_draw_centered_texture(status_ring, Vector2.ZERO, Vector2.ONE * (radius + 7.0) * 2.0, Color(ring_color.r, ring_color.g, ring_color.b, 0.44))
	if _has_strong_nameplate():
		var elite_color := Color(1.0, 0.65, 0.22, 0.40)
		if _is_boss:
			elite_color = Color(1.0, 0.45, 0.24, 0.52)
		elif _is_promoted_realm:
			elite_color = Color(1.0, 0.82, 0.36, 0.45)
		var ring_key := "enemy_identity_ring_boss" if _is_boss else "enemy_identity_ring_elite"
		var identity_ring := _combat_fx_texture(ring_key)
		if identity_ring:
			_draw_centered_texture(identity_ring, Vector2.ZERO, Vector2.ONE * (radius + 11.0) * 2.0, elite_color)
	if _flash > 0.0:
		color = color.lightened(0.5)

	var move_speed := _steer_velocity.length()
	if move_speed > 10.0:
		var dir := _steer_velocity.normalized()
		var streak := radius * clampf(move_speed / maxf(_move_speed, 1.0), 0.35, 1.2)
		var streak_color := color.darkened(0.25)
		streak_color.a = 0.46
		_draw_movement_trail(dir, radius, streak, streak_color)

	if _skills and _skills.get_windup_progress() > 0.0:
		var progress := _skills.get_windup_progress()
		var phase_color := Color(1.0, 0.35, 0.2, 0.9)
		if _is_boss:
			phase_color = Color(1.0, 0.45, 0.85, 0.9)
		var windup_seal := _combat_fx_texture("enemy_windup_seal")
		if windup_seal:
			var seal_alpha := lerpf(0.42, 0.95, progress)
			_draw_centered_texture(windup_seal, Vector2.ZERO, Vector2.ONE * (radius + 16.0) * 2.0, Color(phase_color.r, phase_color.g, phase_color.b, seal_alpha))
		_draw_weapon_outline(radius, phase_color, progress)
	elif _skills and _skills.is_dashing():
		var dash_seal := _combat_fx_texture("enemy_windup_seal")
		if dash_seal:
			_draw_centered_texture(dash_seal, Vector2.ZERO, Vector2.ONE * (radius + 12.0) * 2.0, Color(1.0, 0.42, 0.18, 0.62))
		_draw_weapon_outline(radius, Color(1.0, 0.58, 0.22, 0.82), 1.0)

	_draw_status_icons(radius)

	if body_visual:
		body_visual.modulate = _enemy_sprite_modulate()
		return

func _draw_presence_shadow(radius: float, color: Color) -> void:
	var shadow := _combat_fx_texture("actor_presence_shadow")
	if shadow:
		_draw_centered_texture(shadow, Vector2(0.0, radius * 0.81), Vector2(radius * 3.0, radius * 1.35), Color(1.0, 1.0, 1.0, 0.70))
	var accent := color
	accent.a = 0.16 if not _is_boss else 0.26
	if shadow:
		_draw_centered_texture(shadow, Vector2(0.0, radius * 0.78), Vector2(radius * 3.22, radius * 1.45), Color(accent.r, accent.g, accent.b, maxf(accent.a, 0.22)))
	if _has_strong_nameplate():
		var ring := color.lightened(0.12)
		ring.a = 0.48 if _is_boss else 0.34
		var ring_key := "enemy_identity_ring_boss" if _is_boss else "enemy_identity_ring_elite"
		var texture := _combat_fx_texture(ring_key)
		if texture:
			_draw_centered_texture(texture, Vector2(0.0, radius * 0.38), Vector2.ONE * radius * (2.85 if _is_boss else 2.55), ring)


func _enemy_base_accent_color() -> Color:
	var color: Color = GameConstants.COLOR_ENEMY
	if _has_persistent_nameplate:
		color = color.lerp(Color(1.0, 0.45, 0.2), 0.2)
	elif _archetype == "sniper":
		color = color.lerp(Color(0.65, 0.55, 0.95), 0.25)
	elif _archetype == "berserker":
		color = color.lerp(Color(0.95, 0.25, 0.2), 0.3)
	elif _archetype == "shaman":
		color = color.lerp(Color(0.35, 0.85, 0.65), 0.25)
	elif _archetype == "ranged":
		color = color.lerp(Color(0.55, 0.7, 1.0), 0.15)
	if _is_boss:
		color = color.lerp(Color(0.85, 0.35, 0.2), 0.25)
	return color


func _enemy_sprite_modulate() -> Color:
	var tint := Color(0.96, 0.94, 0.9, 1.0)
	if _is_boss:
		tint = Color(1.04, 0.98, 0.9, 1.0)
	elif _has_persistent_nameplate or _is_promoted_realm:
		tint = Color(1.0, 0.96, 0.88, 1.0)
	if _flash > 0.0:
		tint = tint.lightened(0.45)
	return tint


func _has_active_status() -> bool:
	return status.is_burning() or status.is_poisoned() or status.is_frozen() or status.is_paralyzed() or status.is_slowed() or _mutation_timer > 0.0 or _is_guarded_by_ally()


func _has_dynamic_visual_state() -> bool:
	if _skills and (_skills.get_windup_progress() > 0.0 or _skills.is_dashing()):
		return true
	if _guard_link_visual_time > 0.0:
		return true
	return _has_active_status()


func _active_status_keys() -> Array[String]:
	var keys: Array[String] = []
	if _is_guarded_by_ally():
		keys.append("guard")
	if status.is_burning():
		keys.append("burn")
	if status.is_poisoned():
		keys.append("poison")
	if status.is_frozen():
		keys.append("freeze")
	elif status.is_slowed():
		keys.append("slow")
	if status.is_paralyzed():
		keys.append("paralyze")
	if _mutation_timer > 0.0:
		keys.append("mutation")
	if _skills and _skills.get_windup_progress() > 0.0:
		keys.append("windup")
	if _is_boss:
		keys.append("boss")
	elif _has_persistent_nameplate:
		keys.append("elite")
	elif _is_promoted_realm:
		keys.append("promoted")
	return keys.slice(0, STATUS_ICON_MAX)


func get_status_icon_texture_hit_count() -> int:
	var hits := 0
	for key in _active_status_keys():
		if _status_icon_texture(key) != null:
			hits += 1
	return hits


func get_combat_fx_texture_hit_count() -> int:
	var hits := _windup_weapon_texture_hits + _movement_trail_texture_hits
	for key in [
		"actor_presence_shadow",
		"enemy_windup_seal",
		"enemy_identity_ring_elite",
		"enemy_identity_ring_boss",
		"enemy_guard_aura",
		"status_badge_backing",
	]:
		if _combat_fx_texture(key) != null:
			hits += 1
	if AssetPaths.load_texture(AssetPaths.enemy_windup_weapon(_weapon_id)) != null:
		hits += 1
	return hits


func get_windup_weapon_texture_hit_count() -> int:
	return _windup_weapon_texture_hits


func get_movement_trail_texture_hit_count() -> int:
	return _movement_trail_texture_hits


func get_nameplate_texture_hit_count() -> int:
	return _nameplate_texture_hits


func get_world_hp_texture_hit_count() -> int:
	if world_hp == null or not world_hp.has_method("get_texture_style_hit_count"):
		return 0
	return int(world_hp.call("get_texture_style_hit_count"))


func get_visible_status_icon_count() -> int:
	return _active_status_keys().size()


func _is_guardian_unit() -> bool:
	return _weapon_id == "xuanwu_shield"


func _is_active_guardian_unit() -> bool:
	return _is_guardian_unit() and not _death_handled


func _is_guarded_by_ally() -> bool:
	if _death_handled or _is_guardian_unit():
		return false
	return _nearest_guardian() != null


func _nearest_guardian() -> Node2D:
	var nearest: Node2D = null
	var best_dist := GUARD_AURA_RADIUS
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == self or not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		if not enemy.has_method("_is_active_guardian_unit") or not bool(enemy.call("_is_active_guardian_unit")):
			continue
		var dist := global_position.distance_to((enemy as Node2D).global_position)
		if dist < best_dist:
			best_dist = dist
			nearest = enemy as Node2D
	return nearest


func _apply_guard_protection(amount: float) -> float:
	var guardian := _nearest_guardian()
	if guardian == null:
		return amount
	guardian.call("_pulse_guard_link", global_position)
	_show_status_hit_feedback("guard")
	return amount * (1.0 - GUARD_DAMAGE_REDUCTION)


func _pulse_guard_link(_target_pos: Vector2 = Vector2.ZERO) -> void:
	_guard_link_visual_time = 0.45
	queue_redraw()


func _draw_guard_aura(radius: float) -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
	var aura := _combat_fx_texture("enemy_guard_aura")
	if aura:
		var aura_size := Vector2.ONE * minf(GUARD_AURA_RADIUS * 0.62, (radius + 32.0 + pulse * 4.0) * 2.0)
		_draw_centered_texture(aura, Vector2.ZERO, aura_size, Color(1.0, 0.78, 0.38, 0.30 + pulse * 0.14))
	if _guard_link_visual_time > 0.0:
		if aura:
			_draw_centered_texture(aura, Vector2.ZERO, Vector2.ONE * (radius + 24.0) * 2.0, Color(1.0, 0.84, 0.36, 0.62))


func _draw_status_icons(radius: float) -> void:
	var keys := _active_status_keys()
	if keys.is_empty():
		return
	var count := mini(keys.size(), STATUS_ICON_MAX)
	var orbit_radius := radius + 18.0
	var start_angle := PI * 0.22
	var end_angle := PI * 0.78
	if count == 1:
		_draw_status_icon(str(keys[0]), Vector2(0.0, orbit_radius * 0.88), STATUS_ICON_SIZE)
		return
	for i in range(count):
		var t := float(i) / float(maxi(count - 1, 1))
		var angle := lerpf(start_angle, end_angle, t)
		_draw_status_icon(str(keys[i]), Vector2(cos(angle), sin(angle)) * orbit_radius, STATUS_ICON_SIZE)


func _draw_status_icon(status_key: String, center: Vector2, size: float) -> void:
	var texture := _status_icon_texture(status_key)
	var color := StatusComponent.status_color(status_key)
	var backing := _combat_fx_texture("status_badge_backing")
	if backing:
		_draw_centered_texture(backing, center, Vector2.ONE * size * 1.52, Color(color.r, color.g, color.b, 0.54))
	if texture:
		var rect := Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size))
		draw_texture_rect(texture, rect, false, Color(1.0, 1.0, 1.0, 0.66))


func _status_icon_texture(status_key: String) -> Texture2D:
	if _status_icon_texture_cache.has(status_key):
		return _status_icon_texture_cache[status_key] as Texture2D
	var icon_path := AssetPaths.status_icon(status_key)
	var texture := AssetPaths.load_texture(icon_path)
	_status_icon_texture_cache[status_key] = texture
	return texture


func _combat_fx_texture(key: String) -> Texture2D:
	if _combat_fx_texture_cache.has(key):
		return _combat_fx_texture_cache[key] as Texture2D
	var texture := AssetPaths.load_texture(AssetPaths.combat_action_fx(key))
	_combat_fx_texture_cache[key] = texture
	return texture


func _movement_trail_texture(element: String) -> Texture2D:
	if _movement_trail_texture_cache.has(element):
		return _movement_trail_texture_cache[element] as Texture2D
	var texture := AssetPaths.load_texture(AssetPaths.enemy_projectile_trail(element, ""))
	_movement_trail_texture_cache[element] = texture
	return texture


func _movement_trail_element() -> String:
	if status.is_burning():
		return "fire"
	if status.is_paralyzed():
		return "thunder"
	if status.is_frozen() or status.is_slowed():
		return "ice"
	if status.is_poisoned():
		return "wood"
	if _mutation_timer > 0.0:
		return _mutation_element
	if _is_boss:
		return "thunder"
	var semantics := _weapon_projectile_semantics(_weapon_id)
	var element := str(semantics.get("element", ""))
	return element if not element.is_empty() and element != "fire" else "generic"


func _draw_movement_trail(dir: Vector2, radius: float, streak: float, color: Color) -> void:
	var texture := _movement_trail_texture(_movement_trail_element())
	if texture == null:
		return
	_movement_trail_texture_hits = maxi(_movement_trail_texture_hits, 1)
	var draw_size := Vector2(maxf(radius * 2.15, streak * 2.0), maxf(12.0, radius * 0.72))
	draw_set_transform(-dir * radius * 0.22, dir.angle(), Vector2.ONE)
	draw_texture_rect(texture, Rect2(Vector2(-draw_size.x, -draw_size.y * 0.5), draw_size), false, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_centered_texture(texture: Texture2D, center: Vector2, draw_size: Vector2, modulate: Color = Color.WHITE) -> void:
	if texture == null:
		return
	draw_texture_rect(texture, Rect2(center - draw_size * 0.5, draw_size), false, modulate)


func _weapon_label() -> String:
	match _weapon_id:
		"claw": return "爪"
		"poison_spit": return "毒囊"
		"mud_bow", "cloud_crossbow": return "弩"
		"wind_blade": return "风刃"
		"furnace_core": return "炉心"
		"xuanwu_shield": return "盾"
		"soul_banner": return "魂幡"
	return "兵器"


func _weapon_projectile_semantics(weapon_id: String) -> Dictionary:
	match weapon_id:
		"poison_spit":
			return {"element": "wood", "status": "poison", "status_duration": 3.0, "color": Color(0.45, 1.0, 0.36)}
		"mud_bow":
			return {"element": "earth", "status": "slow", "status_duration": 1.5, "color": Color(0.72, 0.62, 0.38)}
		"cloud_crossbow":
			return {"element": "thunder", "status": "", "status_duration": 0.0, "color": Color(0.55, 0.82, 1.0)}
		"wind_blade":
			return {"element": "thunder", "status": "", "status_duration": 0.0, "color": Color(0.55, 0.9, 1.0)}
		"furnace_core":
			return {"element": "fire", "status": "burn", "status_duration": 2.4, "color": Color(1.0, 0.36, 0.18)}
		"soul_banner":
			return {"element": "soul", "status": "", "status_duration": 0.0, "color": Color(0.86, 0.38, 1.0)}
		"xuanwu_shield":
			return {"element": "earth", "status": "slow", "status_duration": 0.9, "color": Color(0.82, 0.72, 0.42)}
		_:
			return {"element": "fire", "status": "", "status_duration": 0.0, "color": Color(1.0, 0.35, 0.35)}


func _draw_weapon_outline(radius: float, color: Color, charge: float) -> void:
	var dir := _visual_facing.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var texture := AssetPaths.load_texture(AssetPaths.enemy_windup_weapon(_weapon_id))
	if texture == null:
		texture = _combat_fx_texture("enemy_windup_seal")
	if texture == null:
		return
	_windup_weapon_texture_hits = maxi(_windup_weapon_texture_hits, 1)


func _weapon_glyph_size(charge: float) -> Vector2:
	var scale := lerpf(0.92, 1.18, clampf(charge, 0.0, 1.0))
	match _weapon_id:
		"mud_bow", "cloud_crossbow":
			return Vector2(50.0, 29.0) * scale
		"wind_blade", "claw":
			return Vector2(44.0, 30.0) * scale
		"furnace_core":
			return Vector2.ONE * 38.0 * scale
		"xuanwu_shield":
			return Vector2.ONE * 42.0 * scale
		"soul_banner":
			return Vector2(38.0, 58.0) * scale
		"poison_spit":
			return Vector2(36.0, 29.0) * scale
	return Vector2(42.0, 28.0) * scale
