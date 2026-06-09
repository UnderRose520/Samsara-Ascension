extends CanvasLayer

const DaoHeartConfig = preload("res://systems/realm/dao_heart_config.gd")

@onready var panel: PanelContainer = $Panel
@onready var start_button: Button = $Panel/Margin/VBox/StartButton
@onready var detail_label: Label = $Panel/Margin/VBox/Detail
@onready var shard_label: Label = $Panel/Margin/VBox/ShardLabel
@onready var heart_demon_check: CheckButton = $Panel/Margin/VBox/HeartDemonCheck
@onready var points_label: Label = $Panel/Margin/VBox/PointsLabel
@onready var meta_button: Button = $Panel/Margin/VBox/MetaButton
@onready var buttons: Array[Button] = [
	$Panel/Margin/VBox/Hearts/AskDao,
	$Panel/Margin/VBox/Hearts/Enlighten,
	$Panel/Margin/VBox/Hearts/ProveDao,
]

var _selected: int = DaoHeartConfig.DaoHeart.ENLIGHTEN
var _meta_panel: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	start_button.pressed.connect(_on_start_pressed)
	heart_demon_check.toggled.connect(_on_heart_demon_toggled)
	meta_button.pressed.connect(_on_meta_pressed)
	buttons[0].pressed.connect(func(): _select(DaoHeartConfig.DaoHeart.ASK_DAO))
	buttons[1].pressed.connect(func(): _select(DaoHeartConfig.DaoHeart.ENLIGHTEN))
	buttons[2].pressed.connect(func(): _select(DaoHeartConfig.DaoHeart.PROVE_DAO))
	_refresh_meta()
	_select(DaoHeartConfig.DaoHeart.ENLIGHTEN)


func _refresh_meta() -> void:
	var shards := SaveManager.get_heart_demon_shards()
	var dao_count: Array = SaveManager.get_awakened_dao_traditions()
	var points := SaveManager.get_reincarnation_points()
	shard_label.text = "心魔碎片 %d/3 · 已觉醒道统 %d" % [shards, dao_count.size()]
	points_label.text = "轮回点 %d · 可永久强化真元/灵石/重随" % points
	var can_boost := shards >= 3
	heart_demon_check.visible = can_boost
	heart_demon_check.disabled = not can_boost
	if can_boost:
		heart_demon_check.text = "心魔强化开局（消耗3碎片 · 仙品词条 · 敌人+10%）"
	else:
		heart_demon_check.button_pressed = false


func _select(heart: int) -> void:
	_selected = heart
	for i in buttons.size():
		buttons[i].modulate = Color(1, 1, 1, 1.0 if _heart_for_index(i) == heart else 0.55)
	match heart:
		DaoHeartConfig.DaoHeart.ASK_DAO:
			detail_label.text = "问道：敌人 -20% 真元，数量 -1，无心魔试炼台"
		DaoHeartConfig.DaoHeart.ENLIGHTEN:
			detail_label.text = "悟道：标准体验，机缘房 20% 出现心魔试炼台"
		DaoHeartConfig.DaoHeart.PROVE_DAO:
			detail_label.text = "证道：敌人 +20% 真元，数量 +1，必遇心魔试炼台"


func _heart_for_index(index: int) -> int:
	match index:
		0: return DaoHeartConfig.DaoHeart.ASK_DAO
		1: return DaoHeartConfig.DaoHeart.ENLIGHTEN
		2: return DaoHeartConfig.DaoHeart.PROVE_DAO
	return DaoHeartConfig.DaoHeart.ENLIGHTEN


func _on_heart_demon_toggled(_pressed: bool) -> void:
	pass


func _on_meta_pressed() -> void:
	if _meta_panel == null:
		_meta_panel = get_parent().get_node_or_null("MetaUpgradePanel")
	if _meta_panel and _meta_panel.has_method("open_panel"):
		_meta_panel.open_panel()
		_refresh_meta()


func _on_start_pressed() -> void:
	panel.visible = false
	visible = false
	var use_boost := heart_demon_check.visible and heart_demon_check.button_pressed
	RunContext.begin_run(_selected, -1, use_boost)
	EventBus.run_setup_confirmed.emit()
