extends CanvasLayer

const WeaponModCatalog = preload("res://systems/equipment/weapon_mod_catalog.gd")
const UiAnimations = preload("res://ui/ui_animations.gd")
const UiHelpers = preload("res://ui/ui_helpers.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")

@onready var panel: PanelContainer = $Panel
@onready var dimmer: ColorRect = $Dimmer
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var summary_label: Label = $Panel/Margin/VBox/Summary
@onready var cards_box: HBoxContainer = $Panel/Margin/VBox/Cards

var _offers: Array = []
var _context: Dictionary = {}
var _closing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	dimmer.visible = false
	UiHelpers.apply_panel_polish(panel)
	UiHelpers.decorate_modal_header($Panel/Margin/VBox, title_label)
	EventBus.weapon_mod_choice_requested.connect(_on_choice_requested)


func _on_choice_requested(offers: Array, context: Dictionary = {}) -> void:
	_offers = offers
	_context = context
	_closing = false
	title_label.text = "\u672c\u547d\u5668\u796d\u70bc"
	summary_label.text = "\u5df2\u796d\u70bc %d/%d · %s" % [
		RunContext.weapon_mods.size(),
		WeaponModCatalog.MAX_MODS,
		str(context.get("source", "\u6e05\u573a\u673a\u7f18")),
	]
	_rebuild_cards()
	panel.visible = true
	dimmer.visible = true
	UiAnimations.modal_open(panel, dimmer)


func _rebuild_cards() -> void:
	for child in cards_box.get_children():
		child.queue_free()
	for i in _offers.size():
		cards_box.add_child(_make_card(_offers[i], i))


func _make_card(mod: Dictionary, index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(210, 210)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiHelpers.apply_panel_polish(card, false)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var name_label := Label.new()
	name_label.text = WeaponModCatalog.format_mod(mod)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", _rarity_color(str(mod.get("rarity", "common"))))
	name_label.add_theme_font_size_override("font_size", 18)
	box.add_child(name_label)

	var tags_label := Label.new()
	tags_label.text = WeaponModCatalog.format_tags(mod)
	tags_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tags_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tags_label.add_theme_color_override("font_color", UiTokens.ACCENT_GOLD_SOFT)
	tags_label.add_theme_font_size_override("font_size", 13)
	box.add_child(tags_label)

	var desc_label := Label.new()
	desc_label.text = str(mod.get("description", ""))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY)
	desc_label.custom_minimum_size = Vector2(0, 58)
	box.add_child(desc_label)

	var effect_label := Label.new()
	effect_label.text = _format_effects(mod)
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	box.add_child(effect_label)

	var synergy := _format_synergy(mod)
	if not synergy.is_empty():
		var synergy_label := Label.new()
		synergy_label.text = synergy
		synergy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		synergy_label.add_theme_color_override("font_color", UiTokens.ACCENT_GOLD)
		synergy_label.add_theme_font_size_override("font_size", 12)
		box.add_child(synergy_label)

	var conflicts := WeaponModCatalog.format_conflicts(mod)
	if not conflicts.is_empty():
		var conflict_label := Label.new()
		conflict_label.text = "\u4e92\u65a5\uff1a%s" % conflicts
		conflict_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		conflict_label.add_theme_color_override("font_color", Color(1.0, 0.58, 0.38))
		conflict_label.add_theme_font_size_override("font_size", 12)
		box.add_child(conflict_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	var button := Button.new()
	button.text = "\u9009\u62e9\u796d\u70bc"
	button.custom_minimum_size = Vector2(0, 40)
	button.pressed.connect(_on_mod_selected.bind(str(mod.get("id", ""))))
	box.add_child(button)

	if not VfxManager.should_reduce_motion():
		card.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(float(index) * UiAnimations.CARD_STAGGER)
		tw.tween_property(card, "modulate:a", 1.0, 0.18)
	return card


func _format_effects(mod: Dictionary) -> String:
	var parts: PackedStringArray = []
	if float(mod.get("damage_mult", 1.0)) != 1.0:
		parts.append("\u4f24\u5bb3 x%.2f" % float(mod.get("damage_mult", 1.0)))
	if float(mod.get("range_mult", 1.0)) != 1.0:
		parts.append("\u89e6\u53ca x%.2f" % float(mod.get("range_mult", 1.0)))
	if float(mod.get("attack_interval_mult", 1.0)) != 1.0:
		parts.append("\u95f4\u9694 x%.2f" % float(mod.get("attack_interval_mult", 1.0)))
	var element := str(mod.get("element_override", ""))
	if not element.is_empty():
		parts.append("\u5143\u7d20 %s" % element)
	var status := str(mod.get("status_on_hit", ""))
	if not status.is_empty():
		parts.append("\u547d\u4e2d %s %.1fs" % [status, float(mod.get("status_duration", 1.0))])
	return " / ".join(parts) if not parts.is_empty() else "\u7a33\u5b9a\u589e\u5e45"


func _format_synergy(mod: Dictionary) -> String:
	var tags: Array = mod.get("tags", [])
	var hints: PackedStringArray = []
	var path_hint := str(_context.get("path_hint", ""))
	var focus_tags: Array = _context.get("focus_tags", [])
	if _has_tag_overlap(tags, focus_tags) or _matches_path_hint(tags, path_hint):
		hints.append("\u9053\u9014\u5951\u5408")
	var element_hint := str(_context.get("element_hint", ""))
	if not element_hint.is_empty() and str(mod.get("element_override", "")) == element_hint:
		hints.append("\u5929\u8c61\u5171\u9e23")
	if _has_owned_tag_overlap(tags):
		hints.append("\u5df2\u6709\u796d\u70bc\u534f\u540c")
	return " / ".join(hints)


func _has_owned_tag_overlap(tags: Array) -> bool:
	for owned_id in RunContext.weapon_mods:
		var owned := WeaponModCatalog.get_mod(str(owned_id))
		for tag in owned.get("tags", []):
			if str(tag) in tags:
				return true
	return false


func _has_tag_overlap(tags: Array, other_tags: Array) -> bool:
	for tag in tags:
		if str(tag) in other_tags:
			return true
	return false


func _matches_path_hint(tags: Array, path_hint: String) -> bool:
	if path_hint.is_empty():
		return false
	if str(path_hint) in tags:
		return true
	match path_hint:
		"orb":
			return "spell" in tags or "range" in tags
		"sword":
			return "temper" in tags or "crit" in tags or "thunder" in tags
		"talisman":
			return "wood" in tags or "matrix" in tags
		"banner":
			return "soul" in tags or "core" in tags
	return false


func _rarity_color(rarity: String) -> Color:
	match rarity:
		"epic":
			return UiTokens.ACCENT_GOLD
		"rare":
			return UiTokens.ELEM_WATER
	return UiTokens.TEXT_PRIMARY


func _on_mod_selected(mod_id: String) -> void:
	if _closing or mod_id.is_empty():
		return
	_closing = true
	UiAnimations.modal_close(panel, dimmer, func() -> void:
		panel.visible = false
		dimmer.visible = false
		_offers.clear()
		_closing = false
		EventBus.weapon_mod_choice_closed.emit(mod_id)
	)
