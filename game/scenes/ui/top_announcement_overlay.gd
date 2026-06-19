extends CanvasLayer

const UiTokens = preload("res://ui/theme/ui_tokens.gd")
const UiAnimations = preload("res://ui/ui_animations.gd")

@onready var bar: PanelContainer = $Bar
@onready var label: Label = $Bar/Margin/Label

var _timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 55
	bar.visible = false
	_apply_bar_style()
	EventBus.pet_coord_feedback.connect(_on_announce)


func _on_announce(text: String) -> void:
	if text.is_empty():
		return
	if not _should_show_as_announcement(text):
		return
	_show(text, UiTokens.ACCENT_GOLD_SOFT, 1.35)


func _apply_bar_style() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.006, 0.014, 0.016, 0.58)
	panel.border_width_left = 1
	panel.border_width_top = 1
	panel.border_width_right = 1
	panel.border_width_bottom = 1
	panel.border_color = Color(UiTokens.ACCENT_JADE.r, UiTokens.ACCENT_JADE.g, UiTokens.ACCENT_JADE.b, 0.38)
	panel.corner_radius_top_left = 8
	panel.corner_radius_top_right = 8
	panel.corner_radius_bottom_left = 8
	panel.corner_radius_bottom_right = 8
	bar.add_theme_stylebox_override("panel", panel)


func _show(text: String, color: Color, duration: float) -> void:
	label.text = text
	label.add_theme_color_override("font_color", color)
	bar.visible = true
	bar.modulate.a = 0.0
	_timer = duration
	UiAnimations.modal_open(bar, null)


func _process(delta: float) -> void:
	if _timer <= 0.0:
		return
	_timer = maxf(_timer - delta, 0.0)
	if _timer <= 0.0:
		UiAnimations.modal_close(bar, null, func() -> void:
			bar.visible = false
		)


func _should_show_as_announcement(text: String) -> bool:
	var blocked_keys := [
		"魔劫进度",
		"最后 10 秒",
		"下一波",
		"波来袭",
		"第 ",
		"协同",
		"击杀",
		"道势",
		"陷入",
		"天象共鸣",
	]
	for key in blocked_keys:
		if text.find(key) >= 0:
			return false
	var critical_keys := [
		"道统觉醒",
		"突破成功",
		"本命器祭炼",
		"精英词缀",
		"敌人异变",
	]
	for key in critical_keys:
		if text.find(key) >= 0:
			return true
	return false
