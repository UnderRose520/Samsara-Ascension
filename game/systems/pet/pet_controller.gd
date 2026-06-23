extends Node2D

const CsvLoader = preload("res://systems/affix/csv_loader.gd")
const GameConstants = preload("res://core/constants/game_constants.gd")
const AssetPaths = preload("res://assets/asset_paths.gd")

@onready var body_visual: Sprite2D = get_node_or_null("BodyVisual") as Sprite2D

var _pet_def: Dictionary = {}
var _passive_cd := 0.0
var _coord_cd := 0.0
var _pulse := 0.0
var _combat_anim := 0.0
var owner_player: CharacterBody2D
var _use_sprite := false
var _anim_state := "idle"
var _visual_facing := Vector2.RIGHT
var _coord_hit_window := 0.0
var _coord_hit_enemies: Dictionary = {}
var _coord_momentum_awarded := false
var _shadow_visual: Sprite2D
var _aura_visual: Sprite2D
var _fallback_visual: Sprite2D
var _pet_aura_texture_hits := 0
var _pet_shadow_texture_hits := 0
var _pet_fallback_texture_hits := 0


func _ready() -> void:
	for row in CsvLoader.load_rows("res://data/pets/pets.csv"):
		if str(row.get("pet_id", "")) == "huo_ying":
			_pet_def = row
			break
	add_to_group("pet")
	visible = false
	_ensure_support_visuals()
	_apply_body_sprite()
	_use_sprite = body_visual != null and body_visual.texture != null
	_apply_support_visuals()
	_update_animation_state()
	EventBus.pet_acquired.connect(_on_pet_acquired)
	EventBus.pet_coord_hit.connect(_on_pet_coord_hit)


func _on_pet_acquired(_pet_id: String) -> void:
	if owner_player:
		bind_player(owner_player)


func bind_player(player: CharacterBody2D) -> void:
	owner_player = player
	visible = RunContext.pet_acquired
	_apply_support_visuals()


func _apply_body_sprite() -> void:
	if body_visual == null:
		return
	if body_visual.has_method("set_texture_path"):
		body_visual.set_texture_path(AssetPaths.PET_HUO_YING)
	elif ResourceLoader.exists(AssetPaths.PET_HUO_YING):
		body_visual.texture = load(AssetPaths.PET_HUO_YING)
	body_visual.scale = Vector2(1.25, 1.25)


func _ensure_support_visuals() -> void:
	_shadow_visual = get_node_or_null("PetInkShadow") as Sprite2D
	if _shadow_visual == null:
		_shadow_visual = Sprite2D.new()
		_shadow_visual.name = "PetInkShadow"
		_shadow_visual.z_index = -3
		_shadow_visual.position = Vector2(0.0, 8.0)
		add_child(_shadow_visual)
		move_child(_shadow_visual, 0)
	_aura_visual = get_node_or_null("PetDaoAura") as Sprite2D
	if _aura_visual == null:
		_aura_visual = Sprite2D.new()
		_aura_visual.name = "PetDaoAura"
		_aura_visual.z_index = -2
		add_child(_aura_visual)
		move_child(_aura_visual, min(1, get_child_count() - 1))
	_fallback_visual = get_node_or_null("PetFallbackVisual") as Sprite2D
	if _fallback_visual == null:
		_fallback_visual = Sprite2D.new()
		_fallback_visual.name = "PetFallbackVisual"
		_fallback_visual.z_index = 1
		add_child(_fallback_visual)


func _apply_support_visuals() -> void:
	if _shadow_visual:
		_shadow_visual.texture = AssetPaths.load_texture(AssetPaths.combat_action_fx("actor_presence_shadow"))
		_shadow_visual.scale = Vector2(0.23, 0.14)
		_shadow_visual.modulate = Color(0.05, 0.025, 0.015, 0.34)
		_shadow_visual.visible = _shadow_visual.texture != null
		_pet_shadow_texture_hits = int(_shadow_visual.texture != null)
	if _aura_visual:
		_aura_visual.texture = AssetPaths.load_texture(AssetPaths.combat_action_fx("player_dao_aura"))
		_aura_visual.scale = Vector2(0.18, 0.18)
		_aura_visual.modulate = Color(1.0, 0.55, 0.16, 0.0)
		_aura_visual.visible = _aura_visual.texture != null
		_pet_aura_texture_hits = int(_aura_visual.texture != null)
	if _fallback_visual:
		_fallback_visual.texture = AssetPaths.load_texture(AssetPaths.HUD_PET_HUO_YING_AVATAR_64)
		_fallback_visual.scale = Vector2(0.38, 0.38)
		_fallback_visual.modulate = Color(1, 1, 1, 0.92)
		_fallback_visual.visible = _fallback_visual.texture != null and not _use_sprite
		_pet_fallback_texture_hits = int(_fallback_visual.texture != null)


func get_coord_cd_remaining() -> float:
	return _coord_cd


func try_coordinated_skill(direction: Vector2) -> bool:
	if not RunContext.pet_acquired or owner_player == null:
		return false
	if _coord_cd > 0.0:
		EventBus.pet_coord_feedback.emit("协同冷却 %.0fs" % ceilf(_coord_cd))
		return false
	_coord_cd = float(_pet_def.get("coord_cooldown", 8.0))
	var dir := direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	_fire_coord_burst(dir)
	_coord_hit_window = 1.2
	_coord_hit_enemies.clear()
	_coord_momentum_awarded = false
	_pulse = 0.35
	_combat_anim = 0.45
	_update_animation_state()
	EventBus.pet_coord_feedback.emit("火萤协同爆发!")
	return true


func _physics_process(delta: float) -> void:
	if not RunContext.pet_acquired or owner_player == null:
		return
	global_position = owner_player.global_position + _pet_follow_offset()
	_passive_cd = maxf(_passive_cd - delta, 0.0)
	_coord_cd = maxf(_coord_cd - delta, 0.0)
	_coord_hit_window = maxf(_coord_hit_window - delta, 0.0)
	_pulse = maxf(_pulse - delta, 0.0)
	_combat_anim = maxf(_combat_anim - delta, 0.0)
	if _passive_cd <= 0.0:
		_passive_attack()
	elif owner_player.velocity.length_squared() > 1.0:
		_update_visual_facing(owner_player.velocity)
	_update_support_visual_state(delta)
	_update_animation_state()


func _passive_attack() -> void:
	var target := _find_nearest_enemy()
	if target == null:
		_passive_cd = 0.5
		return
	var dir := (target.global_position - global_position).normalized()
	_update_visual_facing(dir)
	_spawn_projectile(dir, float(_pet_def.get("passive_attack", 6.0)), 4.0, "pet_passive")
	_passive_cd = 2.5
	_combat_anim = 0.35


func _fire_coord_burst(direction: Vector2) -> void:
	var damage: float = float(_pet_def.get("coord_damage", 18.0))
	_update_visual_facing(direction)
	for i in 5:
		var spread := deg_to_rad(-30.0 + i * 15.0)
		_spawn_projectile(direction.rotated(spread), damage, 7.0, "pet_coord")


func _spawn_projectile(direction: Vector2, damage: float, radius: float, source_tag: String = "pet") -> void:
	EventBus.spawn_player_projectile_requested.emit({
		"scene_root": get_tree().current_scene,
		"position": global_position + direction * 10.0,
		"direction": direction,
		"damage": damage,
		"owner": owner_player,
		"speed": -1.0,
		"radius": radius,
		"color": Color(1.0, 0.45, 0.15),
		"element": "fire",
		"source_tag": source_tag,
		"status_on_hit": "burn",
		"status_duration": 1.5,
	})


func _on_pet_coord_hit(enemy: Node) -> void:
	if _coord_hit_window <= 0.0 or _coord_momentum_awarded:
		return
	if enemy == null or not is_instance_valid(enemy):
		return
	_coord_hit_enemies[enemy.get_instance_id()] = true
	if _coord_hit_enemies.size() >= 3:
		_coord_momentum_awarded = true
		RunContext.add_dao_momentum(10.0, "pet_coord_multi_hit")
		EventBus.pet_coord_feedback.emit("灵宠协同贯穿三敌 · 道势 +10")


func _find_nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		var dist := global_position.distance_squared_to(enemy.global_position)
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best


func get_mult_c() -> float:
	return 1.08 if RunContext.pet_acquired else 1.0


func _update_animation_state() -> void:
	if body_visual == null or not body_visual.has_method("set_animation_prefix_name"):
		return
	var next_state: String = "idle"
	if _combat_anim > 0.0:
		next_state = "combat"
	elif owner_player != null and owner_player.velocity.length() > 25.0:
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


func _pet_follow_offset() -> Vector2:
	var velocity := owner_player.velocity if owner_player != null else Vector2.ZERO
	if velocity.length_squared() <= 16.0:
		return Vector2(-58.0, -18.0)
	var dir := velocity.normalized()
	return -dir * 62.0 + Vector2(0.0, -14.0)


func _apply_visual_facing() -> void:
	if body_visual == null or absf(_visual_facing.x) < 0.05:
		return
	body_visual.flip_h = _visual_facing.x < 0.0
	if _fallback_visual:
		_fallback_visual.flip_h = _visual_facing.x < 0.0


func _update_support_visual_state(delta: float) -> void:
	var active := RunContext.pet_acquired
	if _shadow_visual:
		_shadow_visual.visible = active and _shadow_visual.texture != null
		_shadow_visual.scale = Vector2(0.23 + _pulse * 0.05, 0.14 + _pulse * 0.03)
	if _aura_visual:
		_aura_visual.visible = active and _aura_visual.texture != null
		_aura_visual.rotation += delta * (1.0 + _pulse * 2.5)
		_aura_visual.scale = Vector2.ONE * (0.17 + _pulse * 0.09)
		var aura_alpha := 0.18 if _coord_cd <= 0.0 else 0.08
		if _pulse > 0.0:
			aura_alpha = 0.38 + _pulse * 0.20
		_aura_visual.modulate = Color(1.0, 0.62, 0.18, aura_alpha)
	if _fallback_visual:
		_fallback_visual.visible = active and _fallback_visual.texture != null and not _use_sprite


func get_pet_aura_texture_hit_count() -> int:
	return _pet_aura_texture_hits


func get_pet_shadow_texture_hit_count() -> int:
	return _pet_shadow_texture_hits


func get_pet_fallback_texture_hit_count() -> int:
	return _pet_fallback_texture_hits
