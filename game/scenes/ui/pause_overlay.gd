extends CanvasLayer

const UiHelpers = preload("res://ui/ui_helpers.gd")
const UiAnimations = preload("res://ui/ui_animations.gd")

@onready var dimmer: ColorRect = $Dimmer
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var seed_label: Label = $Panel/Margin/VBox/SeedLabel
@onready var copy_seed_button: Button = $Panel/Margin/VBox/CopySeedButton
@onready var enemy_hp_check: CheckButton = $Panel/Margin/VBox/EnemyHpCheck
@onready var damage_numbers_check: CheckButton = $Panel/Margin/VBox/DamageNumbersCheck
@onready var reduce_motion_check: CheckButton = $Panel/Margin/VBox/ReduceMotionCheck
@onready var auto_aim_check: CheckButton = $Panel/Margin/VBox/AutoAimCheck
@onready var auto_attack_check: CheckButton = $Panel/Margin/VBox/AutoAttackCheck
@onready var sprite_style_option: OptionButton = $Panel/Margin/VBox/SpriteStyleRow/SpriteStyleOption

var _shown := false
var _sprite_style_labels := ["正常", "Q版"]
var _sprite_style_values := ["normal", "chibi"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	UiHelpers.apply_panel_polish(panel)
	UiHelpers.decorate_modal_header($Panel/Margin/VBox, title_label)
	copy_seed_button.pressed.connect(_on_copy_seed_pressed)
	enemy_hp_check.toggled.connect(_on_enemy_hp_toggled)
	damage_numbers_check.toggled.connect(_on_damage_numbers_toggled)
	reduce_motion_check.toggled.connect(_on_reduce_motion_toggled)
	auto_aim_check.toggled.connect(_on_auto_aim_toggled)
	auto_attack_check.toggled.connect(_on_auto_attack_toggled)
	_setup_sprite_style_option()
	_sync_from_save()


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
		panel.modulate.a = 1.0
		dimmer.modulate.a = 1.0
		UiAnimations.modal_open(panel, dimmer)
	else:
		UiAnimations.reset_modal(panel)


func _sync_from_save() -> void:
	_refresh_seed_display()
	enemy_hp_check.button_pressed = SaveManager.get_display_setting("show_enemy_hp")
	damage_numbers_check.button_pressed = SaveManager.get_display_setting("show_damage_numbers")
	reduce_motion_check.button_pressed = SaveManager.get_display_setting("reduce_motion")
	auto_aim_check.button_pressed = SaveManager.get_display_setting("auto_aim")
	auto_attack_check.button_pressed = SaveManager.get_display_setting("auto_attack")
	_sync_sprite_style_option()


func _on_enemy_hp_toggled(pressed: bool) -> void:
	SaveManager.set_display_setting("show_enemy_hp", pressed)


func _on_damage_numbers_toggled(pressed: bool) -> void:
	SaveManager.set_display_setting("show_damage_numbers", pressed)


func _on_reduce_motion_toggled(pressed: bool) -> void:
	SaveManager.set_display_setting("reduce_motion", pressed)


func _on_auto_aim_toggled(pressed: bool) -> void:
	SaveManager.set_display_setting("auto_aim", pressed)


func _on_auto_attack_toggled(pressed: bool) -> void:
	SaveManager.set_display_setting("auto_attack", pressed)


func _setup_sprite_style_option() -> void:
	if sprite_style_option == null:
		return
	sprite_style_option.clear()
	for label in _sprite_style_labels:
		sprite_style_option.add_item(label)
	sprite_style_option.item_selected.connect(_on_sprite_style_selected)


func _sync_sprite_style_option() -> void:
	if sprite_style_option == null:
		return
	var style: String = SaveManager.get_sprite_style()
	var selected: int = _sprite_style_values.find(style)
	if selected < 0:
		selected = 0
	sprite_style_option.select(selected)


func _on_sprite_style_selected(index: int) -> void:
	if index < 0 or index >= _sprite_style_values.size():
		return
	SaveManager.set_sprite_style(_sprite_style_values[index])


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
