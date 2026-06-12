class_name TargetSelector

extends RefCounted



const TargetingConfig = preload("res://systems/combat/targeting_config.gd")



## 自动索敌 v2：威胁圈 + 残血 + 距离 + 攻击圈内 Boss 加权；带评分粘性。

static var _locked: WeakRef





static func acquire(player: Node2D, max_range: float) -> Node2D:

	if player == null or player.get_tree() == null:

		return null

	var stick_range := TargetingConfig.get_float("auto_target_stick_range", 650.0)

	var best := _find_best_scored(player, max_range)

	var locked := _get_locked_enemy()



	if locked != null and _is_candidate(player, locked, stick_range):

		if _is_candidate(player, locked, max_range):

			var threat_override := _find_threat_override(player, locked, max_range)

			if threat_override != null:

				_locked = weakref(threat_override)

				return threat_override

			var boss_override := _try_boss_switch(player, locked, max_range)

			if boss_override != null:

				_locked = weakref(boss_override)

				return boss_override

			if best != null:

				var locked_score := score_enemy(player, locked, max_range)

				var best_score := score_enemy(player, best, max_range)

				if best_score > locked_score * TargetingConfig.get_float("stick_switch_ratio", 1.15):

					_locked = weakref(best)

					return best

			return locked



	if best != null:

		_locked = weakref(best)

	else:

		_locked = null

	return best





static func has_attack_target(player: Node2D) -> bool:

	return acquire(player, TargetingConfig.get_float("auto_attack_range", 480.0)) != null





static func direction_to_target(player: Node2D, move_hint: Vector2 = Vector2.ZERO) -> Vector2:

	var target := acquire(player, TargetingConfig.get_float("auto_target_range", 520.0))

	if target != null:

		var to_target := target.global_position - player.global_position

		if to_target.length_squared() > 0.01:

			return to_target.normalized()

	return _normalize_or_default(move_hint, Vector2.RIGHT)





static func clear_lock() -> void:

	_locked = null





static func score_enemy(player: Node2D, enemy: Node2D, score_range: float = -1.0) -> float:

	if player == null or enemy == null:

		return -1.0

	var default_range := TargetingConfig.get_float("auto_target_range", 520.0)

	var range_basis := score_range if score_range > 0.0 else default_range

	var dist := player.global_position.distance_to(enemy.global_position)

	var score := 0.0

	var threat_range := TargetingConfig.get_float("threat_range", 140.0)

	var attack_range := TargetingConfig.get_float("auto_attack_range", 480.0)



	if dist <= threat_range:

		score += TargetingConfig.get_float("score_threat_base", 50000.0)

		score += (threat_range - dist) * TargetingConfig.get_float("score_threat_close_bonus", 80.0)



	if dist <= attack_range:

		score += TargetingConfig.get_float("score_attack_range_base", 5000.0)

		if enemy.has_method("is_boss_unit") and enemy.is_boss_unit():

			score += TargetingConfig.get_float("score_boss_in_attack", 3000.0)

		elif enemy.has_method("is_elite_unit") and enemy.is_elite_unit():

			score += TargetingConfig.get_float("score_elite_in_attack", 800.0)



	var hp_ratio := 1.0

	if enemy.has_node("HealthComponent"):

		var health: Node = enemy.get_node("HealthComponent")

		if float(health.max_hp) > 0.0:

			hp_ratio = float(health.current_hp) / float(health.max_hp)



	score += (1.0 - hp_ratio) * TargetingConfig.get_float("score_low_hp_max", 2500.0)



	if dist <= range_basis:

		score += (1.0 - dist / range_basis) * TargetingConfig.get_float("score_distance_max", 1500.0)



	return score





static func _find_best_scored(player: Node2D, max_range: float) -> Node2D:

	var best: Node2D = null

	var best_score := -1.0

	for enemy in player.get_tree().get_nodes_in_group("enemy"):

		if not (enemy is Node2D):

			continue

		if not _is_candidate(player, enemy as Node2D, max_range):

			continue

		var enemy_score := score_enemy(player, enemy as Node2D, max_range)

		if enemy_score > best_score:

			best_score = enemy_score

			best = enemy as Node2D

	return best





static func _find_threat_override(player: Node2D, locked: Node2D, max_range: float) -> Node2D:

	if locked != null and _in_threat_range(player, locked):

		return null

	var best: Node2D = null

	var best_score := -1.0

	for enemy in player.get_tree().get_nodes_in_group("enemy"):

		if not (enemy is Node2D):

			continue

		var node := enemy as Node2D

		if not _is_candidate(player, node, max_range):

			continue

		if not _in_threat_range(player, node):

			continue

		var enemy_score := score_enemy(player, node, max_range)

		if enemy_score > best_score:

			best_score = enemy_score

			best = node

	return best





static func _try_boss_switch(player: Node2D, locked: Node2D, max_range: float) -> Node2D:

	if locked == null or _in_threat_range(player, locked):

		return null

	if locked.has_method("is_boss_unit") and locked.is_boss_unit():

		return null

	var best_boss: Node2D = null

	var best_boss_score := -1.0

	for enemy in player.get_tree().get_nodes_in_group("enemy"):

		if not (enemy is Node2D):

			continue

		var node := enemy as Node2D

		if not enemy.has_method("is_boss_unit") or not enemy.is_boss_unit():

			continue

		if not _is_candidate(player, node, max_range):

			continue

		if not _in_attack_range(player, node):

			continue

		var enemy_score := score_enemy(player, node, max_range)

		if enemy_score > best_boss_score:

			best_boss_score = enemy_score

			best_boss = node

	if best_boss == null:

		return null

	var locked_score := score_enemy(player, locked, max_range)

	if best_boss_score > locked_score * TargetingConfig.get_float("stick_boss_switch_ratio", 1.05):

		return best_boss

	return null





static func _get_locked_enemy() -> Node2D:

	if _locked == null:

		return null

	var enemy: Variant = _locked.get_ref()

	if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():

		_locked = null

		return null

	return enemy as Node2D





static func _is_candidate(player: Node2D, enemy: Node2D, max_range: float) -> bool:

	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():

		return false

	if enemy.has_node("HealthComponent"):

		var health: Node = enemy.get_node("HealthComponent")

		if health.has_method("is_alive") and not health.is_alive():

			return false

	var max_dist_sq := max_range * max_range

	return player.global_position.distance_squared_to(enemy.global_position) <= max_dist_sq





static func _in_threat_range(player: Node2D, enemy: Node2D) -> bool:

	return player.global_position.distance_to(enemy.global_position) <= TargetingConfig.get_float("threat_range", 140.0)





static func _in_attack_range(player: Node2D, enemy: Node2D) -> bool:

	return player.global_position.distance_to(enemy.global_position) <= TargetingConfig.get_float("auto_attack_range", 480.0)





static func _normalize_or_default(dir: Vector2, fallback: Vector2) -> Vector2:

	if dir.length_squared() > 0.01:

		return dir.normalized()

	return fallback

