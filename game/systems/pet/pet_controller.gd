extends Node2D

const CsvLoader = preload("res://systems/affix/csv_loader.gd")
const GameConstants = preload("res://core/constants/game_constants.gd")

var _pet_def: Dictionary = {}
var _passive_cd := 0.0
var _coord_cd := 0.0
var _pulse := 0.0
var owner_player: CharacterBody2D
var _use_sprite := false


func _ready() -> void:
	for row in CsvLoader.load_rows("res://data/pets/pets.csv"):
		if str(row.get("pet_id", "")) == "huo_ying":
			_pet_def = row
			break
	add_to_group("pet")
	visible = false
	_use_sprite = has_node("BodyVisual") and get_node("BodyVisual").texture != null
	EventBus.pet_acquired.connect(_on_pet_acquired)


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
	_pulse = 0.35
	EventBus.pet_coord_feedback.emit("火萤协同爆发!")
	return true


func _physics_process(delta: float) -> void:
	if not RunContext.pet_acquired or owner_player == null:
		return
	global_position = owner_player.global_position + Vector2(-28, -8)
	_passive_cd = maxf(_passive_cd - delta, 0.0)
	_coord_cd = maxf(_coord_cd - delta, 0.0)
	_pulse = maxf(_pulse - delta, 0.0)
	if _passive_cd <= 0.0:
		_passive_attack()
	queue_redraw()


func _passive_attack() -> void:
	var target := _find_nearest_enemy()
	if target == null:
		_passive_cd = 0.5
		return
	var dir := (target.global_position - global_position).normalized()
	_spawn_projectile(dir, float(_pet_def.get("passive_attack", 6.0)), 4.0)
	_passive_cd = 2.5


func _fire_coord_burst(direction: Vector2) -> void:
	var damage := float(_pet_def.get("coord_damage", 18.0))
	for i in 5:
		var spread := deg_to_rad(-30.0 + i * 15.0)
		_spawn_projectile(direction.rotated(spread), damage, 7.0)


func _spawn_projectile(direction: Vector2, damage: float, radius: float) -> void:
	EventBus.spawn_player_projectile_requested.emit({
		"scene_root": get_tree().current_scene,
		"position": global_position + direction * 10.0,
		"direction": direction,
		"damage": damage,
		"owner": owner_player,
		"speed": -1.0,
		"radius": radius,
	})


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
