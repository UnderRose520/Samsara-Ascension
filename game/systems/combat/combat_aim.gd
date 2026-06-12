class_name CombatAim
extends RefCounted

const TargetSelector = preload("res://systems/combat/target_selector.gd")

## 解析玩家攻击/施法朝向：auto_aim 时指向 TargetSelector 目标，否则跟随鼠标。


static func resolve_direction(player: Node2D, move_hint: Vector2 = Vector2.ZERO) -> Vector2:
	if player == null:
		return _normalize_or_default(move_hint, Vector2.RIGHT)
	if SaveManager.get_display_setting("auto_aim"):
		return TargetSelector.direction_to_target(player, move_hint)
	var to_mouse := player.get_global_mouse_position() - player.global_position
	if to_mouse.length_squared() > 0.01:
		return to_mouse.normalized()
	return _normalize_or_default(move_hint, Vector2.RIGHT)


static func _normalize_or_default(dir: Vector2, fallback: Vector2) -> Vector2:
	if dir.length_squared() > 0.01:
		return dir.normalized()
	return fallback
