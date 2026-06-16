extends Node2D

const CsvLoader = preload("res://systems/affix/csv_loader.gd")
const GameConstants = preload("res://core/constants/game_constants.gd")

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


func _ready() -> void:
	for row in CsvLoader.load_rows("res://data/pets/pets.csv"):
		if str(row.get("pet_id", "")) == "huo_ying":
			_pet_def = row
			break
	add_to_group("pet")
	visible = false
	_use_sprite = body_visual != null and body_visual.texture != null
	_update_animation_state()
	EventBus.pet_acquired.connect(_on_pet_acquired)
	EventBus.pet_coord_hit.connect(_on_pet_coord_hit)


func _on_pet_acquired(_pet_id: String) -> void:
	if owner_player:
		bind_player(owner_player)


func bind_player(player: CharacterBody2D) -> void:
	owner_player = player
	visible = RunContext.pet_acquired


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
	global_position = owner_player.global_position + Vector2(-28, -8)
	_passive_cd = maxf(_passive_cd - delta, 0.0)
	_coord_cd = maxf(_coord_cd - delta, 0.0)
	_coord_hit_window = maxf(_coord_hit_window - delta, 0.0)
	_pulse = maxf(_pulse - delta, 0.0)
	_combat_anim = maxf(_combat_anim - delta, 0.0)
	if _passive_cd <= 0.0:
		_passive_attack()
	elif owner_player.velocity.length_squared() > 1.0:
		_update_visual_facing(owner_player.velocity)
	_update_animation_state()
	queue_redraw()


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
		"source_tag": source_tag,
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


func _apply_visual_facing() -> void:
	if body_visual == null or absf(_visual_facing.x) < 0.05:
		return
	body_visual.flip_h = _visual_facing.x < 0.0


func _draw() -> void:
	if not RunContext.pet_acquired:
		return
	if _use_sprite:
		return
	var radius := 6.0 + _pulse * 10.0
	var color := Color(1.0, 0.55, 0.2)
	if _pulse > 0.0:
		color = Color(1.0, 0.85, 0.3)
	draw_circle(Vector2.ZERO, radius, color)
