extends Node

const GameConstants = preload("res://core/constants/game_constants.gd")

## 场景层弹幕工厂 — 系统层通过 EventBus 请求，此处持有场景资源。

const PLAYER_PROJECTILE_SCENE = preload("res://scenes/combat/projectile.tscn")
const ENEMY_PROJECTILE_SCENE = preload("res://scenes/combat/enemy_projectile.tscn")


func _ready() -> void:
	EventBus.spawn_player_projectile_requested.connect(_on_spawn_player_projectile)
	EventBus.spawn_enemy_projectile_requested.connect(_on_spawn_enemy_projectile)


func _on_spawn_player_projectile(payload: Dictionary) -> void:
	var scene_root: Node = payload.get("scene_root")
	if scene_root == null or not is_instance_valid(scene_root):
		scene_root = get_tree().current_scene
	if scene_root == null:
		return
	var projectile: Area2D = PLAYER_PROJECTILE_SCENE.instantiate()
	projectile.global_position = payload.get("position", Vector2.ZERO)
	projectile.setup(
		payload.get("direction", Vector2.RIGHT),
		float(payload.get("damage", 0.0)),
		payload.get("owner"),
		float(payload.get("speed", -1.0)),
		float(payload.get("radius", 5.0)),
		payload.get("color", GameConstants.COLOR_PROJECTILE),
		int(payload.get("pierce", -1)),
		str(payload.get("element", "fire")),
		float(payload.get("range", -1.0)),
		str(payload.get("source_tag", "projectile")),
		str(payload.get("status_on_hit", "")),
		float(payload.get("status_duration", 0.0)),
		int(payload.get("evolution_layer", 1)),
		str(payload.get("evolution_branch", "base")),
		int(payload.get("synergy_rank", 0)),
	)
	scene_root.add_child(projectile)


func _on_spawn_enemy_projectile(payload: Dictionary) -> void:
	var scene_root: Node = payload.get("scene_root")
	if scene_root == null or not is_instance_valid(scene_root):
		scene_root = get_tree().current_scene
	if scene_root == null:
		return
	var projectile: Area2D = ENEMY_PROJECTILE_SCENE.instantiate()
	projectile.global_position = payload.get("position", Vector2.ZERO)
	projectile.setup(
		payload.get("direction", Vector2.RIGHT),
		float(payload.get("damage", 0.0)),
		float(payload.get("speed", 240.0)),
		float(payload.get("radius", 5.0)),
		payload.get("color", Color(1.0, 0.35, 0.35)),
		str(payload.get("element", "")),
		str(payload.get("status_on_hit", "")),
		float(payload.get("status_duration", 0.0)),
		str(payload.get("source_tag", "enemy_projectile")),
	)
	scene_root.add_child(projectile)
