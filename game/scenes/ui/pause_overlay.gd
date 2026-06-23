extends CanvasLayer

signal restart_run_requested
signal quit_game_requested

const UiHelpers = preload("res://ui/ui_helpers.gd")
const UiAnimations = preload("res://ui/ui_animations.gd")

@onready var dimmer: TextureRect = $Dimmer
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var seed_label: Label = $Panel/Margin/VBox/SeedLabel
@onready var lifetime_label: Label = $Panel/Margin/VBox/LifetimeLabel
@onready var copy_seed_button: Button = $Panel/Margin/VBox/CopySeedButton
@onready var enemy_hp_check: Button = $Panel/Margin/VBox/EnemyHpCheck
@onready var damage_numbers_check: Button = $Panel/Margin/VBox/DamageNumbersCheck
@onready var reduce_motion_check: Button = $Panel/Margin/VBox/ReduceMotionCheck
@onready var auto_aim_check: Button = $Panel/Margin/VBox/AutoAimCheck
@onready var auto_attack_check: Button = $Panel/Margin/VBox/AutoAttackCheck
@onready var normal_style_button: Button = $Panel/Margin/VBox/SpriteStyleRow/SpriteStyleSegment/NormalStyleButton
@onready var chibi_style_button: Button = $Panel/Margin/VBox/SpriteStyleRow/SpriteStyleSegment/ChibiStyleButton
@onready var end_run_button: Button = $Panel/Margin/VBox/EndRunButton
@onready var quit_game_button: Button = $Panel/Margin/VBox/QuitGameButton
@onready var confirm_box: VBoxContainer = $Panel/Margin/VBox/ConfirmBox
@onready var confirm_label: Label = $Panel/Margin/VBox/ConfirmBox/ConfirmLabel
@onready var confirm_restart_button: Button = $Panel/Margin/VBox/ConfirmBox/ConfirmRow/ConfirmRestartButton
@onready var cancel_restart_button: Button = $Panel/Margin/VBox/ConfirmBox/ConfirmRow/CancelRestartButton

var _shown := false
var _toggle_buttons: Array[Button] = []
var _sprite_style_buttons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	UiHelpers.apply_panel_polish(panel)
	UiHelpers.apply_modal_veil(dimmer, 0.70)
	UiHelpers.decorate_modal_header($Panel/Margin/VBox, title_label)
	_setup_asset_buttons()
	copy_seed_button.pressed.connect(_on_copy_seed_pressed)
	enemy_hp_check.toggled.connect(_on_enemy_hp_toggled)
	damage_numbers_check.toggled.connect(_on_damage_numbers_toggled)
	reduce_motion_check.toggled.connect(_on_reduce_motion_toggled)
	auto_aim_check.toggled.connect(_on_auto_aim_toggled)
	auto_attack_check.toggled.connect(_on_auto_attack_toggled)
	end_run_button.pressed.connect(_on_end_run_pressed)
	quit_game_button.pressed.connect(_on_quit_game_pressed)
	confirm_restart_button.pressed.connect(_on_confirm_restart_pressed)
	cancel_restart_button.pressed.connect(_on_cancel_restart_pressed)
	_setup_sprite_style_option()
	_sync_from_save()


func _setup_asset_buttons() -> void:
	_toggle_buttons = [
		enemy_hp_check,
		damage_numbers_check,
		reduce_motion_check,
		auto_aim_check,
		auto_attack_check,
		normal_style_button,
		chibi_style_button,
	]
	var secondary_buttons: Array[Button] = [
		copy_seed_button,
		enemy_hp_check,
		damage_numbers_check,
		reduce_motion_check,
		auto_aim_check,
		auto_attack_check,
		normal_style_button,
		chibi_style_button,
		end_run_button,
		quit_game_button,
		cancel_restart_button,
	]
	for button in secondary_buttons:
		UiHelpers.apply_button_asset(button, false)
		_apply_button_text_polish(button)
	UiHelpers.apply_button_asset(confirm_restart_button, true)
	_apply_button_text_polish(confirm_restart_button, true)
	for button in _toggle_buttons:
		_apply_toggle_button_state(button)


func _apply_button_text_polish(button: Button, primary: bool = false) -> void:
	if button == null:
		return
	button.custom_minimum_size.y = 38
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_constant_override("outline_size", 1)
	button.add_theme_color_override("font_outline_color", Color(0.02, 0.012, 0.004, 0.78))
	button.add_theme_color_override("font_color", Color(0.12, 0.065, 0.022, 1.0) if primary else Color(0.90, 0.86, 0.72, 0.96))
	button.add_theme_color_override("font_hover_color", Color(0.08, 0.04, 0.014, 1.0) if primary else Color(0.98, 0.94, 0.76, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.08, 0.04, 0.014, 1.0) if primary else Color(0.56, 0.98, 0.84, 1.0))
	button.focus_mode = Control.FOCUS_ALL


func _apply_toggle_button_state(button: Button) -> void:
	if button == null:
		return
	var base_text := _toggle_base_text(button)
	if button.button_pressed:
		button.text = "开  %s" % base_text
		button.add_theme_color_override("font_color", Color(0.54, 1.0, 0.82, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(0.54, 1.0, 0.82, 1.0))
	else:
		button.text = "关  %s" % base_text
		button.add_theme_color_override("font_color", Color(0.72, 0.68, 0.58, 0.86))
		button.add_theme_color_override("font_pressed_color", Color(0.72, 0.68, 0.58, 0.86))


func _toggle_base_text(button: Button) -> String:
	if button == enemy_hp_check:
		return "显示敌人血条"
	if button == damage_numbers_check:
		return "显示伤害飘字"
	if button == reduce_motion_check:
		return "减少动效"
	if button == auto_aim_check:
		return "自动瞄准"
	if button == auto_attack_check:
		return "自动普攻"
	if button == normal_style_button:
		return "正常"
	if button == chibi_style_button:
		return "Q版"
	return button.text.replace("开  ", "").replace("关  ", "")


func set_visible_pause(show: bool) -> void:
	if show == _shown:
		visible = show
		if show:
			_sync_from_save()
		return
	_shown = show
	visible = show
	if show:
		_sync_from_save()
		_set_confirm_visible(false)
		panel.modulate.a = 1.0
		dimmer.modulate.a = float(dimmer.get_meta("modal_veil_alpha", 0.70))
		UiAnimations.modal_open(panel, dimmer)
	else:
		_set_confirm_visible(false)
		UiAnimations.reset_modal(panel)


func _sync_from_save() -> void:
	_refresh_seed_display()
	if lifetime_label:
		lifetime_label.text = SaveManager.format_lifetime_summary()
	enemy_hp_check.button_pressed = SaveManager.get_display_setting("show_enemy_hp")
	damage_numbers_check.button_pressed = SaveManager.get_display_setting("show_damage_numbers")
	reduce_motion_check.button_pressed = SaveManager.get_display_setting("reduce_motion")
	auto_aim_check.button_pressed = SaveManager.get_display_setting("auto_aim")
	auto_attack_check.button_pressed = SaveManager.get_display_setting("auto_attack")
	for button in _toggle_buttons:
		_apply_toggle_button_state(button)
	end_run_button.disabled = not RunContext.run_active
	_sync_sprite_style_option()


func _on_enemy_hp_toggled(pressed: bool) -> void:
	SaveManager.set_display_setting("show_enemy_hp", pressed)
	_apply_toggle_button_state(enemy_hp_check)


func _on_damage_numbers_toggled(pressed: bool) -> void:
	SaveManager.set_display_setting("show_damage_numbers", pressed)
	_apply_toggle_button_state(damage_numbers_check)


func _on_reduce_motion_toggled(pressed: bool) -> void:
	SaveManager.set_display_setting("reduce_motion", pressed)
	_apply_toggle_button_state(reduce_motion_check)


func _on_auto_aim_toggled(pressed: bool) -> void:
	SaveManager.set_display_setting("auto_aim", pressed)
	_apply_toggle_button_state(auto_aim_check)


func _on_auto_attack_toggled(pressed: bool) -> void:
	SaveManager.set_display_setting("auto_attack", pressed)
	_apply_toggle_button_state(auto_attack_check)


func _setup_sprite_style_option() -> void:
	_sprite_style_buttons = {
		"normal": normal_style_button,
		"chibi": chibi_style_button,
	}
	if normal_style_button:
		normal_style_button.pressed.connect(func() -> void: _select_sprite_style("normal"))
	if chibi_style_button:
		chibi_style_button.pressed.connect(func() -> void: _select_sprite_style("chibi"))


func _sync_sprite_style_option() -> void:
	var style: String = SaveManager.get_sprite_style()
	if not _sprite_style_buttons.has(style):
		style = "normal"
	for key in _sprite_style_buttons.keys():
		var button := _sprite_style_buttons[key] as Button
		if button:
			button.set_pressed_no_signal(key == style)
			_apply_toggle_button_state(button)


func _select_sprite_style(style: String) -> void:
	if not _sprite_style_buttons.has(style):
		return
	SaveManager.set_sprite_style(style)
	_sync_sprite_style_option()


func _refresh_seed_display() -> void:
	if seed_label == null:
		return
	if RunContext.run_active:
		var suffix := " / 训练" if RunContext.training_mode else ""
		seed_label.text = "本局种子：%d%s" % [RunContext.seed_value, suffix]
		if copy_seed_button:
			copy_seed_button.visible = true
			copy_seed_button.disabled = false
	else:
		seed_label.text = "本局种子：未生成"
		if copy_seed_button:
			copy_seed_button.visible = false


func _on_copy_seed_pressed() -> void:
	if not RunContext.run_active:
		return
	DisplayServer.clipboard_set(str(RunContext.seed_value))
	copy_seed_button.text = "已复制"
	copy_seed_button.disabled = true
	get_tree().create_timer(1.2, true).timeout.connect(func() -> void:
		if is_instance_valid(copy_seed_button):
			copy_seed_button.text = "复制种子"
			copy_seed_button.disabled = false
	, CONNECT_ONE_SHOT)


func _on_end_run_pressed() -> void:
	if not RunContext.run_active:
		return
	_set_confirm_visible(true)


func _on_confirm_restart_pressed() -> void:
	if not RunContext.run_active:
		return
	restart_run_requested.emit()


func _on_cancel_restart_pressed() -> void:
	_set_confirm_visible(false)


func _on_quit_game_pressed() -> void:
	quit_game_requested.emit()


func _set_confirm_visible(show: bool) -> void:
	if confirm_box == null:
		return
	confirm_box.visible = show
	if end_run_button:
		end_run_button.visible = not show
	if quit_game_button:
		quit_game_button.visible = not show
