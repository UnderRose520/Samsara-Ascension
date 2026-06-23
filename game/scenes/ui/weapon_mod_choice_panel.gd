extends CanvasLayer

const AssetPaths = preload("res://assets/asset_paths.gd")
const WeaponModCatalog = preload("res://systems/equipment/weapon_mod_catalog.gd")
const UiAnimations = preload("res://ui/ui_animations.gd")
const UiHelpers = preload("res://ui/ui_helpers.gd")
const UiTokens = preload("res://ui/theme/ui_tokens.gd")

@onready var panel: PanelContainer = $Panel
@onready var dimmer: TextureRect = $Dimmer
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
	UiHelpers.apply_modal_veil(dimmer, 0.72)
	UiHelpers.apply_panel_polish(panel)
	UiHelpers.decorate_modal_header($Panel/Margin/VBox, title_label)
	UiHelpers.add_gold_divider($Panel/Margin/VBox, cards_box)
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
	card.name = "WeaponModCard_%d" % index
	card.custom_minimum_size = Vector2(286, 338)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style := UiHelpers.make_ninepatch_panel_style()
	card_style.modulate_color = _rarity_panel_tint(str(mod.get("rarity", "common")))
	card.add_theme_stylebox_override("panel", card_style)

	var margin := MarginContainer.new()
	margin.name = "WeaponModCardMargin"
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.name = "WeaponModCardVBox"
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var icon_row := HBoxContainer.new()
	icon_row.name = "WeaponModIconRow"
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	icon_row.add_theme_constant_override("separation", 12)
	box.add_child(icon_row)

	var artifact_icon := TextureRect.new()
	artifact_icon.name = "WeaponModArtifactIcon"
	artifact_icon.custom_minimum_size = Vector2(58, 58)
	artifact_icon.texture = AssetPaths.load_texture(AssetPaths.HUD_ARTIFACT_XUANYU_GOURD_96)
	artifact_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artifact_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	artifact_icon.modulate = Color(0.92, 1.0, 0.90, 0.98)
	icon_row.add_child(artifact_icon)

	var semantic_icon := TextureRect.new()
	semantic_icon.name = "WeaponModSemanticIcon"
	semantic_icon.custom_minimum_size = Vector2(48, 48)
	semantic_icon.texture = AssetPaths.load_texture(_mod_icon_path(mod))
	semantic_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	semantic_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	semantic_icon.modulate = _mod_accent_color(mod)
	icon_row.add_child(semantic_icon)

	var name_label := Label.new()
	name_label.name = "WeaponModName"
	name_label.text = WeaponModCatalog.format_mod(mod)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", _rarity_color(str(mod.get("rarity", "common"))))
	name_label.add_theme_color_override("font_outline_color", Color(0.02, 0.012, 0.004, 0.88))
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name_label)

	var tags_box := HBoxContainer.new()
	tags_box.name = "WeaponModTags"
	tags_box.alignment = BoxContainer.ALIGNMENT_CENTER
	tags_box.add_theme_constant_override("separation", 6)
	box.add_child(tags_box)
	_add_tag_chip(tags_box, _kind_label(str(mod.get("kind", ""))), _mod_accent_color(mod))
	var visible_tags := 0
	for tag in mod.get("tags", []):
		if visible_tags >= 3:
			break
		_add_tag_chip(tags_box, _tag_label(str(tag)), UiTokens.ACCENT_GOLD_SOFT)
		visible_tags += 1

	var desc_label := Label.new()
	desc_label.name = "WeaponModDesc"
	desc_label.text = str(mod.get("description", ""))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY)
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.custom_minimum_size = Vector2(0, 50)
	box.add_child(desc_label)

	var effect_label := Label.new()
	effect_label.name = "WeaponModEffect"
	effect_label.text = _format_effects(mod)
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	effect_label.add_theme_font_size_override("font_size", 12)
	effect_label.custom_minimum_size = Vector2(0, 42)
	box.add_child(effect_label)

	var synergy := _format_synergy(mod)
	if not synergy.is_empty():
		var synergy_label := Label.new()
		synergy_label.name = "WeaponModSynergy"
		synergy_label.text = synergy
		synergy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		synergy_label.add_theme_color_override("font_color", UiTokens.ACCENT_GOLD)
		synergy_label.add_theme_font_size_override("font_size", 12)
		box.add_child(synergy_label)

	var conflicts := WeaponModCatalog.format_conflicts(mod)
	if not conflicts.is_empty():
		var conflict_label := Label.new()
		conflict_label.name = "WeaponModConflict"
		conflict_label.text = "\u4e92\u65a5\uff1a%s" % conflicts
		conflict_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		conflict_label.add_theme_color_override("font_color", Color(1.0, 0.58, 0.38))
		conflict_label.add_theme_font_size_override("font_size", 12)
		box.add_child(conflict_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	var button := Button.new()
	button.name = "WeaponModSelectButton"
	button.text = "\u796d\u70bc\u5165\u547d"
	button.custom_minimum_size = Vector2(0, 40)
	button.theme_type_variation = &"Primary"
	button.icon = AssetPaths.load_texture(_mod_button_icon_path(mod))
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	UiHelpers.apply_button_asset(button, true)
	button.pressed.connect(_on_mod_selected.bind(str(mod.get("id", ""))))
	box.add_child(button)

	if not VfxManager.should_reduce_motion():
		card.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(float(index) * UiAnimations.CARD_STAGGER)
		tw.tween_property(card, "modulate:a", 1.0, 0.18)
	return card


func _add_tag_chip(parent: HBoxContainer, text: String, color: Color) -> void:
	if text.is_empty():
		return
	var chip := Label.new()
	chip.text = text
	chip.add_theme_font_size_override("font_size", 11)
	chip.add_theme_color_override("font_color", color)
	chip.add_theme_color_override("font_outline_color", Color(0.02, 0.012, 0.004, 0.88))
	chip.add_theme_constant_override("outline_size", 1)
	parent.add_child(chip)


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
		parts.append("\u5143\u7d20 %s" % _element_label(element))
	var status := str(mod.get("status_on_hit", ""))
	if not status.is_empty():
		parts.append("\u547d\u4e2d %s %.1fs" % [_status_label(status), float(mod.get("status_duration", 1.0))])
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


func _rarity_panel_tint(rarity: String) -> Color:
	match rarity:
		"epic":
			return Color(1.0, 0.82, 0.52, 0.72)
		"rare":
			return Color(0.62, 0.95, 1.0, 0.64)
	return Color(0.76, 0.94, 0.88, 0.52)


func _mod_icon_path(mod: Dictionary) -> String:
	var status := str(mod.get("status_on_hit", ""))
	if not status.is_empty():
		return AssetPaths.status_icon(status)
	var element := str(mod.get("element_override", "")).strip_edges().to_lower()
	if not element.is_empty():
		return str(AssetPaths.ELEMENT_ICONS.get(element, AssetPaths.ELEMENT_ICONS["none"]))
	var kind := str(mod.get("kind", "")).strip_edges().to_lower()
	match kind:
		"inscription":
			return AssetPaths.status_icon("dao")
		"matrix":
			return AssetPaths.status_icon("counter")
		"temper":
			return AssetPaths.status_icon("promoted")
		"core":
			return AssetPaths.status_icon("mutation")
	for tag in mod.get("tags", []):
		var tag_key := str(tag).strip_edges().to_lower()
		if AssetPaths.ELEMENT_ICONS.has(tag_key):
			return str(AssetPaths.ELEMENT_ICONS.get(tag_key, AssetPaths.ELEMENT_ICONS["none"]))
	return AssetPaths.status_icon("dao")


func _mod_button_icon_path(mod: Dictionary) -> String:
	var status := str(mod.get("status_on_hit", ""))
	if not status.is_empty():
		return AssetPaths.status_icon(status)
	var kind := str(mod.get("kind", ""))
	if kind == "core":
		return AssetPaths.status_icon("dao")
	return AssetPaths.HUD_ARTIFACT_XUANYU_GOURD_64


func _mod_accent_color(mod: Dictionary) -> Color:
	var element := str(mod.get("element_override", ""))
	if not element.is_empty():
		return UiTokens.elem_color(element)
	match str(mod.get("rarity", "common")):
		"epic":
			return UiTokens.ACCENT_GOLD
		"rare":
			return UiTokens.ELEM_WATER
	return UiTokens.ACCENT_JADE


func _kind_label(kind: String) -> String:
	match kind:
		"temper":
			return "\u6dec\u70bc"
		"inscription":
			return "\u94ed\u7eb9"
		"matrix":
			return "\u9635\u7eb9"
		"core":
			return "\u5668\u82af"
	return "\u796d\u70bc"


func _tag_label(tag: String) -> String:
	match tag:
		"fire":
			return "\u706b"
		"water":
			return "\u6c34"
		"thunder":
			return "\u96f7"
		"wood":
			return "\u6728"
		"soul":
			return "\u9b42"
		"status":
			return "\u72b6\u6001"
		"range":
			return "\u89e6\u53ca"
		"damage":
			return "\u4f24\u5bb3"
		"temper":
			return "\u6dec\u5203"
		"weapon":
			return "\u672c\u547d"
		"inscription":
			return "\u94ed\u7eb9"
		"matrix":
			return "\u9635\u7eb9"
		"core":
			return "\u5668\u82af"
		"spell":
			return "\u6cd5\u672f"
		"crit":
			return "\u7834\u52bf"
		"sword":
			return "\u5251"
		"orb":
			return "\u73e0"
		"talisman":
			return "\u7b26"
		"banner":
			return "\u9b42\u5e61"
	return tag


func _element_label(element: String) -> String:
	match element.strip_edges().to_lower():
		"fire":
			return "\u706b"
		"water":
			return "\u6c34"
		"thunder", "lightning":
			return "\u96f7"
		"wood":
			return "\u6728"
		"earth":
			return "\u571f"
		"chaos":
			return "\u6df7\u6c8c"
		"soul":
			return "\u9b42"
	return element


func _status_label(status: String) -> String:
	match status.strip_edges().to_lower():
		"burn", "ignite":
			return "\u707c\u70e7"
		"slow":
			return "\u51cf\u901f"
		"freeze", "chill":
			return "\u51b0\u51bb"
		"paralyze", "shock", "stun":
			return "\u9ebb\u75f9"
		"poison":
			return "\u6bd2\u4f24"
		"root":
			return "\u7f20\u6839"
		"bleed":
			return "\u6d41\u8840"
		"curse":
			return "\u8bc5\u5492"
		"wet":
			return "\u6d78\u6da6"
		"shield", "guard":
			return "\u62a4\u4f53"
		"haste", "dodge":
			return "\u8eab\u6cd5"
		"dao":
			return "\u9053\u5370"
		"counter":
			return "\u53cd\u5236"
		"mutation":
			return "\u5f02\u5316"
		"windup":
			return "\u84c4\u52bf"
	return status


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
