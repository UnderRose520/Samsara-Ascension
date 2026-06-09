class_name EventResolver

const EventSelector = preload("res://systems/world/event_selector.gd")


static func apply(event: Dictionary, choice_index: int, player: Node) -> Dictionary:
	var choices := EventSelector.build_choices(event)
	if choice_index < 0 or choice_index >= choices.size():
		return {"message": "你未作选择。"}
	var effect := str(choices[choice_index].get("effect", "none"))
	var parts := effect.split(";")
	var result := {"message": "", "offer_affix": false, "_parts": []}
	for part in parts:
		part = part.strip_edges()
		if part.is_empty() or part == "none":
			continue
		_apply_token(part, player, result)
	var event_id := str(event.get("id", ""))
	RunContext.record_event(event_id)
	var chunks: Array = result.get("_parts", [])
	if not chunks.is_empty():
		result.message = " · ".join(chunks)
	elif result.message.is_empty():
		result.message = "机缘已了。"
	result.erase("_parts")
	return result


static func _apply_token(token: String, player: Node, result: Dictionary) -> void:
	if token.begins_with("gold:"):
		var amount := int(token.get_slice(":", 1))
		RunContext.gold += amount
		EventBus.gold_changed.emit(RunContext.gold)
		_append_message(result, "获得 %d 灵石" % amount)
		return
	if token.begins_with("heal_pct:"):
		var pct := float(token.get_slice(":", 1))
		_heal_player(player, pct)
		_append_message(result, "恢复 %.0f%% 真元" % (pct * 100.0))
		return
	if token == "affix:1":
		result.offer_affix = true
		_append_message(result, "残卷化作一道机缘")
		return
	if token.begins_with("bias:"):
		RunContext.next_affix_bias = token.get_slice(":", 1)
		_append_message(result, "心念偏向 %s 系" % RunContext.next_affix_bias)
		return
	if token.begins_with("karma:"):
		var kind := token.get_slice(":", 1)
		if kind == "dao":
			kind = "dao_heart"
		RunContext.add_karma(kind, 1)
		_append_message(result, _karma_message(kind))
		return
	if token.begins_with("speed:"):
		var mult := float(token.get_slice(":", 1))
		if player.has_node("AffixHolder"):
			player.get_node("AffixHolder").attack_speed_mult *= mult
		_append_message(result, "身法一轻，攻速提升")
		return
	if token == "trial_accept":
		RunContext.heart_demon_trial_active = true
		RunContext.add_karma("rebellion", 1)
		_append_message(result, "心魔试炼已启 · 敌人更强，奖励更丰")
		return
	if token == "trial_contemplate":
		_heal_player(player, 0.12)
		_append_message(result, "沉思片刻，心魔稍退")
		return
	if token == "trial_leave":
		RunContext.gold += 10
		EventBus.gold_changed.emit(RunContext.gold)
		_append_message(result, "转身离去，拾得 10 灵石")


static func _append_message(result: Dictionary, text: String) -> void:
	result.message = text
	var parts: Array = result.get("_parts", [])
	parts.append(text)
	result["_parts"] = parts


static func _heal_player(player: Node, pct: float) -> void:
	if not player.has_node("HealthComponent"):
		return
	var health: Node = player.get_node("HealthComponent")
	health.current_hp = minf(health.max_hp, health.current_hp + health.max_hp * pct)
	health.changed.emit(health.current_hp, health.max_hp)


static func _karma_message(kind: String) -> String:
	match kind:
		"good": return "善念渐生"
		"evil": return "恶念暗长"
		"greed": return "贪念缠身"
		"dao", "dao_heart": return "道心更坚"
	return "因果有变"
