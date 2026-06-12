extends PanelContainer

signal talent_selected(talent_id: String)

@onready var frame_bg: TextureRect = $FrameBg
@onready var name_label: Label = $Margin/VBox/NameLabel
@onready var desc_label: Label = $Margin/VBox/DescLabel
@onready var select_button: Button = $Margin/VBox/SelectButton

var _talent_id := ""


func _ready() -> void:
	select_button.pressed.connect(_on_select_pressed)
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())


func bind_talent(talent: Dictionary) -> void:
	_talent_id = str(talent.get("id", ""))
	name_label.text = str(talent.get("name", "天赋"))
	desc_label.text = str(talent.get("description", ""))
	visible = not _talent_id.is_empty()
	scale = Vector2.ONE
	modulate = Color.WHITE
	frame_bg.modulate = Color.WHITE


func play_entrance(delay: float = 0.0) -> void:
	call_deferred("_play_entrance_deferred", delay)


func _play_entrance_deferred(delay: float) -> void:
	pivot_offset = size * 0.5
	modulate.a = 0.0
	scale = Vector2(0.88, 0.88)
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.28)
	tw.parallel().tween_property(self, "scale", Vector2.ONE, 0.32)


func _on_select_pressed() -> void:
	if not _talent_id.is_empty():
		talent_selected.emit(_talent_id)
