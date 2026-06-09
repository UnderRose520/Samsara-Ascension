extends CanvasLayer

@onready var banner: Label = $Banner
@onready var subtitle: Label = $Subtitle

var _end_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	banner.visible = false
	subtitle.visible = false
	EventBus.dao_tradition_awakened.connect(_on_awakened)


func _on_awakened(tradition: Dictionary) -> void:
	banner.text = str(tradition.get("name", "道统觉醒"))
	subtitle.text = "%s · %s" % [tradition.get("title", ""), tradition.get("description", "")]
	banner.visible = true
	subtitle.visible = true
	banner.modulate.a = 1.0
	subtitle.modulate.a = 1.0
	_end_ms = Time.get_ticks_msec() + 1800
	get_tree().paused = true
	RunContext.ui_blocking = true
	Engine.time_scale = 0.2


func _process(_delta: float) -> void:
	if _end_ms <= 0:
		return
	if Time.get_ticks_msec() < _end_ms:
		return
	_end_ms = 0
	banner.visible = false
	subtitle.visible = false
	RunContext.ui_blocking = false
	get_tree().paused = false
	Engine.time_scale = 1.0
