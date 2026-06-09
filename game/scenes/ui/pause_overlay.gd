extends CanvasLayer

@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var enemy_hp_check: CheckButton = $Panel/Margin/VBox/EnemyHpCheck
@onready var damage_numbers_check: CheckButton = $Panel/Margin/VBox/DamageNumbersCheck


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	enemy_hp_check.toggled.connect(_on_enemy_hp_toggled)
	damage_numbers_check.toggled.connect(_on_damage_numbers_toggled)
	_sync_from_save()


func set_visible_pause(show: bool) -> void:
	visible = show
	if show:
		_sync_from_save()


func _sync_from_save() -> void:
	enemy_hp_check.button_pressed = SaveManager.get_display_setting("show_enemy_hp")
	damage_numbers_check.button_pressed = SaveManager.get_display_setting("show_damage_numbers")


func _on_enemy_hp_toggled(pressed: bool) -> void:
	SaveManager.set_display_setting("show_enemy_hp", pressed)


func _on_damage_numbers_toggled(pressed: bool) -> void:
	SaveManager.set_display_setting("show_damage_numbers", pressed)
