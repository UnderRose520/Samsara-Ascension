extends CharacterBody2D

const GameConstants = preload("res://core/constants/game_constants.gd")
const DamagePipeline = preload("res://systems/combat/damage_pipeline.gd")
const CombatAim = preload("res://systems/combat/combat_aim.gd")
const TargetSelector = preload("res://systems/combat/target_selector.gd")
const PROJECTILE_SCENE = preload("res://scenes/combat/projectile.tscn")
const AssetPaths = preload("res://assets/asset_paths.gd")
const WeaponRegistry = preload("res://systems/equipment/weapon_registry.gd")

@onready var health: Node = $HealthComponent
@onready var combo: Node = $ComboCounter
@onready var status: Node = $StatusComponent
@onready var affix_holder: Node = $AffixHolder
@onready var spell_caster: Node = $PlayerSpellCaster
@onready var body_visual: Sprite2D = $BodyVisual

var move_speed := 300.0
var attack_power := 10.0
var crit_rate := 0.05
var crit_mult := 1.5
var defense := 5.0
var dodge_cooldown := 1.0

var _dodge_cd := 0.0
var _dodge_time := 0.0
var _dodge_dir := Vector2.RIGHT
var _iframe := 0.0
var _hit_invuln := 0.0
var _attack_cd := 0.0
var _combat_anim_time := 0.0
var _last_facing := Vector2.RIGHT
var _dodge_trail_cd := 0.0
var _wet_slow_strength := 0.0
var _anim_state := "idle"
var _visual_facing := Vector2.RIGHT
var _weapon: Dictionary = {}
var _weapon_id := ""
var debug_weapon_shape := ""
var _dao_visual_time := 0.0
var _perfect_counter_time := 0.0
var _perfect_counter_flash := 0.0
var _perfect_counter_bonus_ready := false
var _guardian_invuln := 0.0

const COMBAT_ANIMATION_HOLD_SEC := 0.5
const ANIMATION_FPS := {
	"idle": 6.0,
	"walk": 8.0,
	"combat": 12.0,
}


func _ready() -> void:
	var stats := RunContext.apply_realm_growth_to_stats(ConfigRegistry.get_default_player_stats())
	move_speed = stats.move_speed
	attack_power = stats.attack
	crit_rate = stats.crit_rate
	crit_mult = stats.crit_mult
	defense = stats.defense
	dodge_cooldown = stats.dodge_cooldown
	health.max_hp = stats.hp
	health.current_hp = stats.hp
	health.changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	affix_holder.changed.connect(func(): queue_redraw())
	_on_health_changed(health.current_hp, health.max_hp)
	add_to_group("player")
	EventBus.room_entered.connect(_on_room_entered)
	EventBus.run_started.connect(_on_run_started)
	EventBus.display_settings_changed.connect(_apply_sprite_style)
	EventBus.weapon_changed.connect(_on_weapon_changed)
	EventBus.unity_burst_requested.connect(_on_unity_burst_requested)
	_on_weapon_changed(RunContext.get_weapon())
	_apply_sprite_style()


func _physics_process(delta: float) -> void:
	if get_tree().paused or RunContext.ui_blocking:
		return
	_dodge_cd = maxf(_dodge_cd - delta, 0.0)
	_iframe = maxf(_iframe - delta, 0.0)
	_hit_invuln = maxf(_hit_invuln - delta, 0.0)
	_guardian_invuln = maxf(_guardian_invuln - delta, 0.0)
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_combat_anim_time = maxf(_combat_anim_time - delta, 0.0)
	_dodge_trail_cd = maxf(_dodge_trail_cd - delta, 0.0)
	_perfect_counter_time = maxf(_perfect_counter_time - delta, 0.0)
	_perfect_counter_flash = maxf(_perfect_counter_flash - delta, 0.0)
	if _perfect_counter_time <= 0.0:
		_perfect_counter_bonus_ready = false
	_dao_visual_time += delta
	status.tick(self, delta)
	TerrainSystem.apply_body_effects(self, delta)
	RunContext.tick_dao_momentum(delta)
	_update_wet_slow(delta)

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir.length_squared() > 0.01:
		_last_facing = input_dir.normalized()
		if absf(input_dir.x) > 0.05:
			_visual_facing = input_dir.normalized()
			_apply_visual_facing()

	_try_start_dodge(input_dir)

	if _dodge_time > 0.0:
		_dodge_time = maxf(_dodge_time - delta, 0.0)
		var dash_speed := _dodge_speed()
		var progress := 1.0 - (_dodge_time / GameConstants.DODGE_DURATION)
		if progress > 0.72:
			var ease := (progress - 0.72) / 0.28
			dash_speed *= lerpf(1.0, 0.35, ease)
		velocity = _dodge_dir * dash_speed
		if _dodge_trail_cd <= 0.0:
			_dodge_trail_cd = 0.045
			VfxManager.spawn_world(global_position, "cast", Color(0.55, 0.82, 1.0, 0.55))
		_visual_facing = _dodge_dir
	else:
		var speed: float = move_speed * float(status.get_move_speed_mult()) * _wet_move_mult()
		velocity = input_dir * speed

	move_and_slide()
	global_position = GameConstants.clamp_to_arena(global_position, 12.0)
	if body_visual:
		if _dodge_time > 0.0:
			body_visual.modulate = Color(1.25, 1.25, 1.35, 0.82)
		elif RunContext.dao_momentum_state == "dao_extreme":
			body_visual.modulate = Color(1.55, 1.46, 0.82, 1.0)
		elif RunContext.dao_momentum_state == "clarity":
			body_visual.modulate = Color(1.35, 1.22, 0.72, 1.0)
		elif RunContext.dao_momentum_state == "full":
			body_visual.modulate = Color(1.18, 1.12, 0.82, 1.0)
		elif _wet_slow_strength > 0.05:
			body_visual.modulate = Color(0.82, 0.92, 1.08).lerp(Color.WHITE, 1.0 - _wet_slow_strength * 0.55)
		else:
			body_visual.modulate = Color.WHITE
		_apply_visual_facing()
	_update_animation_state()
	if _needs_redraw():
		queue_redraw()

	var move_hint := get_aim_move_hint()
	if _attack_cd <= 0.0:
		if SaveManager.get_display_setting("auto_attack") and TargetSelector.has_attack_target(self):
			_fire_basic_attack(move_hint)
		elif Input.is_action_pressed("attack"):
			_fire_basic_attack(input_dir)

	if Input.is_action_just_pressed("dao_unity"):
		RunContext.trigger_unity_burst("manual")

	if Input.is_action_just_pressed("pet_skill"):
		var pet := get_tree().get_first_node_in_group("pet")
		if pet and pet.has_method("try_coordinated_skill"):
			var dir := CombatAim.resolve_direction(self, get_aim_move_hint())
			pet.try_coordinated_skill(dir)


func _try_start_dodge(input_dir: Vector2) -> bool:
	if not Input.is_action_just_pressed("dodge") or _dodge_cd > 0.0 or _dodge_time > 0.0:
		return false
	var dir := input_dir
	if dir.length_squared() < 0.01:
		dir = _last_facing
	if dir.length_squared() < 0.01:
		return false
	_dodge_dir = dir.normalized()
	_dodge_time = GameConstants.DODGE_DURATION
	_iframe = GameConstants.DODGE_IFRAME
	_dodge_cd = dodge_cooldown
	_dodge_trail_cd = 0.0
	VfxManager.spawn_world(global_position, "cast", Color(0.65, 0.88, 1.0))
	return true


func _dodge_speed() -> float:
	return GameConstants.DODGE_DISTANCE / maxf(GameConstants.DODGE_DURATION, 0.01)


func _update_wet_slow(delta: float) -> void:
	if TerrainSystem.query_at(global_position) != "wet":
		if _wet_slow_strength > 0.0:
			var decay := delta / maxf(GameConstants.TERRAIN_WET_RECOVERY_SEC, 0.01)
			_wet_slow_strength = maxf(_wet_slow_strength - decay, 0.0)
		return
	_wet_slow_strength = 1.0


func _wet_move_mult() -> float:
	return lerpf(1.0, GameConstants.TERRAIN_WET_SLOW_MULT, _wet_slow_strength)


func apply_terrain_water_slow() -> void:
	_wet_slow_strength = 1.0


func apply_status(status_name: String, duration: float) -> void:
	status.apply_status(status_name, duration)


func receive_terrain_damage(amount: float, _terrain_type: String = "") -> void:
	if get_tree().paused:
		return
	if _guardian_invuln > 0.0:
		return
	_apply_player_damage(amount)


func _on_room_entered(_room: Dictionary, _stage: Dictionary) -> void:
	_wet_slow_strength = 0.0
	TargetSelector.clear_lock()


func _on_run_started(_seed_value: int) -> void:
	TargetSelector.clear_lock()
	_on_weapon_changed(RunContext.get_weapon())


func _on_weapon_changed(weapon: Dictionary) -> void:
	_weapon = weapon.duplicate()
	_weapon_id = str(_weapon.get("weapon_id", ""))
	debug_weapon_shape = str(_weapon.get("attack_shape", "projectile"))
	if affix_holder and affix_holder.has_method("refresh_stats"):
		affix_holder.refresh_stats()


func _sync_weapon_from_run_context() -> void:
	if _weapon_id == RunContext.weapon_id and not _weapon.is_empty():
		return
	_on_weapon_changed(RunContext.get_weapon())


func _on_unity_burst_requested(payload: Dictionary) -> void:
	if str(payload.get("source", "")) == "":
		return
	var family := str(payload.get("weapon_family", _weapon.get("family", "")))
	var style := _resolve_unity_style()
	var radius := 190.0
	var damage_mult := 3.2
	if family == "sword":
		radius = 150.0
		damage_mult = 3.8
	elif family == "banner":
		radius = 210.0
		damage_mult = 2.8
	match style:
		"furnace":
			radius += 25.0
			damage_mult += 0.45
		"thunder":
			radius += 45.0
			damage_mult += 0.15
		"wood":
			radius += 35.0
		"five":
			radius += 60.0
			damage_mult += 0.3
		"combo":
			damage_mult += 0.25
	var element_hint := str(_weapon.get("element_hint", "fire"))
	var weapon_mods := RunContext.get_weapon_mod_effects()
	element_hint = _unity_element_for_style(style, element_hint)
	if style == "default" and not str(weapon_mods.get("element_override", "")).is_empty():
		element_hint = str(weapon_mods.get("element_override", element_hint))
	var unity_color := _unity_color_for_style(style)
	var hit_count := 0
	var unity_hit_index := 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == null or not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		if global_position.distance_to((enemy as Node2D).global_position) > radius:
			continue
		if enemy.has_method("receive_player_weapon_hit"):
			enemy.receive_player_weapon_hit(self, attack_power * damage_mult * float(weapon_mods.get("damage_mult", 1.0)), element_hint, "unity_%s_%s" % [style, str(_weapon.get("weapon_id", "weapon"))])
			_apply_unity_status(enemy, style)
			_apply_weapon_mod_status(enemy, weapon_mods)
			hit_count += 1
			unity_hit_index += 1
			_emit_unity_hit_floater(enemy, attack_power * damage_mult * float(weapon_mods.get("damage_mult", 1.0)), unity_color, unity_hit_index)
	VfxManager.spawn_world(global_position, "dao", unity_color)
	EventBus.unity_burst_visual_requested.emit({
		"world_position": global_position,
		"element_key": element_hint,
		"style": style,
		"color": unity_color,
		"hit_count": hit_count,
	})
	if hit_count > 0:
		EventBus.crit_moment_requested.emit("%s · %d击" % [_unity_label_for_style(style), hit_count], 0.45)
	else:
		EventBus.learn_feedback.emit("万法归一 · 未命中", "skill")
		EventBus.crit_moment_requested.emit("归一未命中", 0.32)


func _resolve_unity_style() -> String:
	match RunContext.dao_tradition_awakened_this_run:
		"furnace_dao":
			return "furnace"
		"thunder_dao":
			return "thunder"
		"wood_dao":
			return "wood"
		"five_dao":
			return "five"
		"combo_dao":
			return "combo"
	var weapon_family := str(_weapon.get("family", ""))
	if weapon_family == "banner":
		return "wood"
	if weapon_family == "sword":
		return "combo"
	return "default"


func _unity_element_for_style(style: String, fallback: String) -> String:
	match style:
		"furnace":
			return "fire"
		"thunder":
			return "thunder"
		"wood":
			return "wood"
		"five":
			return "chaos"
	return fallback


func _apply_unity_status(enemy: Node, style: String) -> void:
	if not enemy.has_method("apply_status"):
		return
	match style:
		"furnace":
			enemy.apply_status("burn", 4.0)
		"thunder":
			enemy.apply_status("paralyze", 1.2)
		"wood":
			enemy.apply_status("poison", 5.0)
		"five":
			enemy.apply_status("burn", 3.0)
			enemy.apply_status("poison", 3.0)
		"combo":
			enemy.apply_status("slow", 2.0)


func _unity_color_for_style(style: String) -> Color:
	match style:
		"furnace":
			return Color(1.0, 0.36, 0.08)
		"thunder":
			return Color(0.65, 0.82, 1.0)
		"wood":
			return Color(0.45, 0.9, 0.38)
		"five":
			return Color(0.92, 0.76, 1.0)
		"combo":
			return Color(1.0, 0.84, 0.18)
	return Color(1.0, 0.84, 0.18)


func _unity_label_for_style(style: String) -> String:
	match style:
		"furnace":
			return "焚天归一"
		"thunder":
			return "雷罚归一"
		"wood":
			return "万毒归一"
		"five":
			return "五行归元"
		"combo":
			return "连击归一"
	return "万法归一"


func _apply_sprite_style() -> void:
	if body_visual == null:
		return
	var path: String = AssetPaths.player_sprite(SaveManager.get_sprite_style(), 64)
	if body_visual.has_method("set_texture_path"):
		body_visual.set_texture_path(path)
	if "animation_fps" in body_visual:
		body_visual.animation_fps = float(ANIMATION_FPS.get(_anim_state, 6.0))
	if body_visual.has_method("set_animation_prefix_name"):
		body_visual.set_animation_prefix_name(_anim_state)
	_apply_visual_facing()


func _update_animation_state() -> void:
	if body_visual == null or not body_visual.has_method("set_animation_prefix_name"):
		return
	var next_state: String = "idle"
	if _combat_anim_time > 0.0:
		next_state = "combat"
	elif velocity.length() > 25.0 or _dodge_time > 0.0:
		next_state = "walk"
	if next_state == _anim_state:
		return
	_anim_state = next_state
	if "animation_fps" in body_visual:
		body_visual.animation_fps = float(ANIMATION_FPS.get(_anim_state, 6.0))
	body_visual.set_animation_prefix_name(_anim_state)


func get_aim_move_hint() -> Vector2:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir.length_squared() > 0.01:
		return input_dir.normalized()
	if velocity.length_squared() > 0.01:
		return velocity.normalized()
	return _last_facing


func _apply_visual_facing() -> void:
	if body_visual == null or absf(_visual_facing.x) < 0.05:
		return
	body_visual.flip_h = _visual_facing.x < 0.0


func _needs_redraw() -> bool:
	if body_visual == null or body_visual.texture == null:
		return true
	if RunContext.dao_momentum_state != "idle" or RunContext.dao_momentum > 0.0:
		return true
	if _iframe > 0.0:
		return true
	return spell_caster and spell_caster.has_method("is_casting") and spell_caster.is_casting()


func _fire_basic_attack(move_hint: Vector2) -> void:
	_sync_weapon_from_run_context()
	var dir := _resolve_basic_attack_direction(move_hint)
	if dir.length_squared() > 0.01:
		_visual_facing = dir.normalized()
		_last_facing = _visual_facing
		_apply_visual_facing()
	var shape := str(_weapon.get("attack_shape", "projectile"))
	match shape:
		"short_arc":
			_fire_short_arc_attack(dir)
		_:
			_fire_projectile_attack(dir)
	_finish_basic_attack()


func _fire_projectile_attack(dir: Vector2) -> void:
	var projectile: Area2D = PROJECTILE_SCENE.instantiate()
	projectile.global_position = global_position + dir * 16.0
	var weapon_mods := RunContext.get_weapon_mod_effects()
	var speed := float(_weapon.get("projectile_speed", GameConstants.PROJECTILE_SPEED))
	var damage_mult := float(_weapon.get("damage_mult", 1.0)) * float(weapon_mods.get("damage_mult", 1.0)) * RunContext.get_dao_clarity_attack_mult() * _consume_perfect_counter_mult()
	var element_hint := str(_weapon.get("element_hint", "fire"))
	if not str(weapon_mods.get("element_override", "")).is_empty():
		element_hint = str(weapon_mods.get("element_override", element_hint))
	var color := Color(str(_weapon.get("visual_color", "#ffd700")))
	var radius := float(_weapon.get("projectile_radius", 5.0))
	var attack_range := float(_weapon.get("attack_range", 520.0)) * float(weapon_mods.get("range_mult", 1.0))
	projectile.setup(
		dir,
		attack_power * damage_mult,
		self,
		speed,
		radius,
		color,
		-1,
		element_hint,
		attack_range,
		"weapon_projectile",
		str(weapon_mods.get("status_on_hit", "")),
		float(weapon_mods.get("status_duration", 0.0))
	)
	get_tree().current_scene.add_child(projectile)
	VfxManager.spawn_world(global_position + dir * 16.0, "cast", color)


func _fire_short_arc_attack(dir: Vector2) -> void:
	var weapon_mods := RunContext.get_weapon_mod_effects()
	var attack_range := float(_weapon.get("attack_range", 72.0)) * float(weapon_mods.get("range_mult", 1.0))
	var arc_deg := float(_weapon.get("attack_arc_deg", 92.0))
	var damage_mult := float(_weapon.get("damage_mult", 1.0)) * float(weapon_mods.get("damage_mult", 1.0)) * RunContext.get_dao_clarity_attack_mult() * _consume_perfect_counter_mult()
	var element_hint := str(_weapon.get("element_hint", "physical"))
	if not str(weapon_mods.get("element_override", "")).is_empty():
		element_hint = str(weapon_mods.get("element_override", element_hint))
	var hit_count := 0
	var half_arc := deg_to_rad(arc_deg) * 0.5
	_spawn_slash_arc(dir, attack_range, arc_deg)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == null or not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var offset: Vector2 = (enemy as Node2D).global_position - global_position
		var distance := offset.length()
		if distance > attack_range or distance <= 0.01:
			continue
		if absf(wrapf(offset.angle() - dir.angle(), -PI, PI)) > half_arc:
			continue
		if enemy.has_method("receive_player_weapon_hit"):
			enemy.receive_player_weapon_hit(self, attack_power * damage_mult, element_hint, "weapon_%s" % str(_weapon.get("weapon_id", "basic")))
			_apply_weapon_mod_status(enemy, weapon_mods)
			hit_count += 1
	if hit_count > 0:
		RunContext.add_dao_momentum(4.0 if hit_count >= 3 else 1.0, "weapon_cleave")
		VfxManager.spawn_world(global_position + dir * minf(attack_range * 0.45, 40.0), "combo", Color(0.88, 0.94, 1.0))
	else:
		VfxManager.spawn_world(global_position + dir * 24.0, "cast", Color(0.75, 0.82, 0.95))


func _spawn_slash_arc(dir: Vector2, attack_range: float, arc_deg: float) -> void:
	var visual := SlashArcVisual.new()
	visual.setup(dir, attack_range, deg_to_rad(arc_deg), Color(0.72, 0.9, 1.0, 0.72))
	add_child(visual)


func _finish_basic_attack() -> void:
	var speed_mult: float = affix_holder.attack_speed_mult
	var weapon_interval_mult := float(_weapon.get("attack_interval_mult", 1.0))
	weapon_interval_mult *= float(RunContext.get_weapon_mod_effects().get("attack_interval_mult", 1.0))
	var clarity_mult := RunContext.get_dao_clarity_attack_mult()
	_attack_cd = GameConstants.ATTACK_INTERVAL * weapon_interval_mult / maxf(speed_mult * clarity_mult, 0.1)
	_combat_anim_time = COMBAT_ANIMATION_HOLD_SEC


func _apply_weapon_mod_status(enemy: Node, effects: Dictionary) -> void:
	var status_name := str(effects.get("status_on_hit", ""))
	if status_name.is_empty() or not enemy.has_method("apply_status"):
		return
	enemy.apply_status(status_name, float(effects.get("status_duration", 1.0)))
	if enemy.has_method("show_weapon_mod_status_feedback"):
		enemy.show_weapon_mod_status_feedback(status_name)


class SlashArcVisual:
	extends Node2D

	var _dir := Vector2.RIGHT
	var _range := 72.0
	var _arc := PI * 0.5
	var _color := Color.WHITE
	var _life := 0.0
	const LIFE_MAX := 0.14

	func setup(dir: Vector2, attack_range: float, arc_rad: float, color: Color) -> void:
		_dir = dir.normalized() if dir.length_squared() > 0.01 else Vector2.RIGHT
		_range = attack_range
		_arc = arc_rad
		_color = color
		z_index = 8

	func _process(delta: float) -> void:
		_life += delta
		if _life >= LIFE_MAX:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var alpha := 1.0 - (_life / LIFE_MAX)
		var color := _color
		color.a *= alpha
		var start := _dir.angle() - _arc * 0.5
		var end := _dir.angle() + _arc * 0.5
		draw_arc(Vector2.ZERO, _range * 0.72, start, end, 18, color, 5.0, true)
		var inner := color
		inner.a *= 0.45
		draw_arc(Vector2.ZERO, _range * 0.42, start, end, 14, inner, 3.0, true)


func _resolve_basic_attack_direction(move_hint: Vector2) -> Vector2:
	if SaveManager.get_display_setting("auto_aim") or SaveManager.get_display_setting("auto_attack"):
		return TargetSelector.direction_to_target(self, move_hint)
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length_squared() > 0.01:
		return to_mouse.normalized()
	if move_hint.length_squared() > 0.01:
		return move_hint.normalized()
	return _last_facing


func _on_health_changed(current: float, maximum: float) -> void:
	EventBus.player_hp_changed.emit(current, maximum)


func _on_died() -> void:
	EventBus.player_died.emit()


func receive_contact_damage(amount: float) -> void:
	if get_tree().paused:
		return
	if _guardian_invuln > 0.0:
		return
	if _iframe > 0.0:
		_trigger_perfect_dodge()
		return
	if _hit_invuln > 0.0:
		return
	_apply_player_damage(amount)


func receive_enemy_projectile(amount: float) -> void:
	receive_contact_damage(amount)


func _trigger_perfect_dodge() -> void:
	if _perfect_counter_time > 0.68:
		return
	_perfect_counter_time = 0.8
	_perfect_counter_flash = 0.8
	_perfect_counter_bonus_ready = true
	RunContext.add_dao_momentum(8.0, "perfect_dodge")
	EventBus.perfect_dodge_triggered.emit(global_position)
	EventBus.crit_moment_requested.emit("完美闪避", 0.1)
	VfxManager.spawn_world(global_position, "gold", Color(1.0, 0.95, 0.72))


func _consume_perfect_counter_mult() -> float:
	if _perfect_counter_bonus_ready and _perfect_counter_time > 0.0:
		_perfect_counter_bonus_ready = false
		_perfect_counter_time = 0.0
		EventBus.pet_coord_feedback.emit("完美反击 · 伤害x1.5")
		return 1.5
	return 1.0


func _emit_unity_hit_floater(enemy: Node, estimated_damage: float, color: Color, hit_index: int) -> void:
	if not enemy is Node2D:
		return
	EventBus.damage_dealt.emit({
		"final_damage": estimated_damage,
		"world_position": (enemy as Node2D).global_position,
		"target_is_player": false,
		"is_crit": false,
		"is_combo": false,
		"is_unity": true,
		"unity_hit_index": hit_index,
		"color": color,
	})


func _apply_player_damage(amount: float) -> void:
	var defense_val := defense
	if affix_holder:
		defense_val += affix_holder.flat_defense
	var mitigated := amount * (1.0 - DamagePipeline.calc_mitigation(defense_val))
	health.take_damage(mitigated)
	_hit_invuln = GameConstants.HIT_INVULN
	if body_visual:
		VfxManager.flash_control(body_visual, Color(1.45, 0.45, 0.45), 0.16)
	VfxManager.spawn_world(global_position, "hit", Color(0.95, 0.35, 0.35))
	EventBus.damage_dealt.emit({
		"final_damage": mitigated,
		"world_position": global_position,
		"target_is_player": true,
		"is_crit": false,
		"is_combo": false,
	})


func grant_guardian_invuln(duration: float) -> void:
	_guardian_invuln = maxf(_guardian_invuln, duration)
	_hit_invuln = maxf(_hit_invuln, duration)
	_perfect_counter_flash = maxf(_perfect_counter_flash, duration)
	if body_visual:
		VfxManager.flash_control(body_visual, Color(1.4, 1.25, 0.5), 0.22)


func _draw() -> void:
	_draw_dao_momentum_aura()
	if body_visual and body_visual.texture != null:
		if _iframe > 0.0:
			draw_circle(Vector2.ZERO, 14.0, Color(1, 1, 1, 0.25))
		if _perfect_counter_flash > 0.0:
			var pulse := 0.5 + 0.5 * sin(_dao_visual_time * 18.0)
			draw_circle(Vector2.ZERO, 22.0 + pulse * 5.0, Color(1.0, 0.9, 0.35, 0.22))
			draw_arc(Vector2.ZERO, 28.0 + pulse * 6.0, 0.0, TAU, 42, Color(1.0, 0.86, 0.28, 0.65), 3.5)
		if spell_caster and spell_caster.has_method("is_casting") and spell_caster.is_casting():
			var cast_color := Color(1.0, 0.45, 0.15, 0.85)
			if spell_caster.has_method("get_casting_color"):
				cast_color = spell_caster.get_casting_color()
				cast_color.a = 0.85
			draw_arc(Vector2.ZERO, 18.0, -PI * 0.5, PI * 0.5, 16, cast_color, 2.5)
		return
	var color: Color = GameConstants.COLOR_PLAYER
	if _iframe > 0.0:
		color = color.lightened(0.35)
	draw_circle(Vector2.ZERO, 12.0, color)
	if _perfect_counter_flash > 0.0:
		var pulse := 0.5 + 0.5 * sin(_dao_visual_time * 18.0)
		draw_circle(Vector2.ZERO, 22.0 + pulse * 5.0, Color(1.0, 0.9, 0.35, 0.22))
		draw_arc(Vector2.ZERO, 28.0 + pulse * 6.0, 0.0, TAU, 42, Color(1.0, 0.86, 0.28, 0.65), 3.5)
	if spell_caster and spell_caster.has_method("is_casting") and spell_caster.is_casting():
		var cast_color := Color(1.0, 0.45, 0.15, 0.85)
		if spell_caster.has_method("get_casting_color"):
			cast_color = spell_caster.get_casting_color()
			cast_color.a = 0.85
		draw_arc(Vector2.ZERO, 18.0, -PI * 0.5, PI * 0.5, 16, cast_color, 2.5)


func _draw_dao_momentum_aura() -> void:
	if RunContext.dao_momentum_state == "idle" and RunContext.dao_momentum <= 0.0:
		return
	var charged_state := RunContext.dao_momentum_state == "clarity" or RunContext.dao_momentum_state == "dao_extreme"
	var pct := 1.0 if charged_state else clampf(RunContext.dao_momentum / maxf(RunContext.dao_momentum_max, 1.0), 0.0, 1.0)
	var pulse_speed := 10.0 if RunContext.dao_momentum_state == "dao_extreme" else (8.0 if RunContext.dao_momentum_state == "full" else 5.0)
	var pulse := 0.5 + 0.5 * sin(_dao_visual_time * pulse_speed)
	var color := Color(1.0, 0.82, 0.22, 0.22 + pulse * 0.2)
	var radius := lerpf(18.0, 28.0, pct)
	var width := 2.0
	if RunContext.dao_momentum_state == "full":
		color = Color(1.0, 0.9, 0.28, 0.42 + pulse * 0.28)
		radius = 30.0 + pulse * 4.0
		width = 3.0
	elif RunContext.dao_momentum_state == "clarity":
		color = Color(1.0, 0.76, 0.18, 0.5 + pulse * 0.18)
		radius = 34.0 + pulse * 5.0
		width = 3.5
	elif RunContext.dao_momentum_state == "dao_extreme":
		color = Color(1.0, 0.95, 0.36, 0.62 + pulse * 0.28)
		radius = 42.0 + pulse * 7.0
		width = 5.0
	draw_arc(Vector2.ZERO, radius, 0.0, TAU * pct, 40, color, width, true)
	if charged_state:
		var fill_alpha := 0.2 if RunContext.dao_momentum_state == "dao_extreme" else 0.12
		draw_circle(Vector2.ZERO, 18.0 + pulse * 3.0, Color(1.0, 0.72, 0.18, fill_alpha))
