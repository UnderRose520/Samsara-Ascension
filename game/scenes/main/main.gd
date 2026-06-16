extends Node

const ARENA_SCENE = preload("res://scenes/rooms/run_controller.tscn")
const SETUP_SCENE = preload("res://scenes/ui/run_setup_panel.tscn")
const AFFIX_PANEL_SCENE = preload("res://scenes/ui/affix_choice_panel.tscn")
const BREAKTHROUGH_SCENE = preload("res://scenes/ui/breakthrough_panel.tscn")
const PATH_PANEL_SCENE = preload("res://scenes/ui/path_choice_panel.tscn")
const CRIT_OVERLAY_SCENE = preload("res://scenes/ui/crit_moment_overlay.tscn")
const RUN_RESULT_SCENE = preload("res://scenes/ui/run_result_panel.tscn")
const LEGACY_SCENE = preload("res://scenes/ui/legacy_select_panel.tscn")
const PAUSE_OVERLAY_SCENE = preload("res://scenes/ui/pause_overlay.tscn")
const COMBAT_FEEDBACK_SCENE = preload("res://scenes/ui/combat_feedback_layer.tscn")
const EVENT_PANEL_SCENE = preload("res://scenes/ui/event_panel.tscn")
const DAO_TRADITION_SCENE = preload("res://scenes/ui/dao_tradition_overlay.tscn")
const TOP_ANNOUNCEMENT_SCENE = preload("res://scenes/ui/top_announcement_overlay.tscn")
const SHOP_PANEL_SCENE = preload("res://scenes/ui/shop_panel.tscn")
const META_PANEL_SCENE = preload("res://scenes/ui/meta_upgrade_panel.tscn")
const WEAPON_MOD_PANEL_SCENE = preload("res://scenes/ui/weapon_mod_choice_panel.tscn")

@onready var world: Node2D = $World

var _pause_overlay: CanvasLayer
var _map_debug_overlay_visible := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(AFFIX_PANEL_SCENE.instantiate())
	add_child(BREAKTHROUGH_SCENE.instantiate())
	add_child(PATH_PANEL_SCENE.instantiate())
	add_child(CRIT_OVERLAY_SCENE.instantiate())
	add_child(RUN_RESULT_SCENE.instantiate())
	add_child(LEGACY_SCENE.instantiate())
	add_child(SETUP_SCENE.instantiate())
	_pause_overlay = PAUSE_OVERLAY_SCENE.instantiate()
	add_child(_pause_overlay)
	add_child(COMBAT_FEEDBACK_SCENE.instantiate())
	add_child(TOP_ANNOUNCEMENT_SCENE.instantiate())
	add_child(EVENT_PANEL_SCENE.instantiate())
	add_child(DAO_TRADITION_SCENE.instantiate())
	add_child(SHOP_PANEL_SCENE.instantiate())
	add_child(META_PANEL_SCENE.instantiate())
	add_child(WEAPON_MOD_PANEL_SCENE.instantiate())
	EventBus.run_setup_confirmed.connect(_on_run_setup_confirmed)


func _on_run_setup_confirmed() -> void:
	if world.get_child_count() > 0:
		return
	var arena: Node2D = ARENA_SCENE.instantiate()
	world.add_child(arena)
	_apply_map_debug_overlay_to_arena(arena)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if _is_debug_quick_event(event):
		_toggle_map_debug_overlay()
		return
	if _is_map_debug_overlay_event(event):
		_toggle_map_debug_overlay()
		return
	if not event.is_action_pressed("pause"):
		return
	if RunContext.ui_blocking:
		return
	get_tree().paused = not get_tree().paused
	if _pause_overlay.has_method("set_visible_pause"):
		_pause_overlay.set_visible_pause(get_tree().paused)


func _toggle_map_debug_overlay() -> void:
	_map_debug_overlay_visible = not _map_debug_overlay_visible
	for arena in world.get_children():
		_apply_map_debug_overlay_to_arena(arena)
	EventBus.pet_coord_feedback.emit("地图调试层：%s" % ("开启" if _map_debug_overlay_visible else "关闭"))


func _apply_map_debug_overlay_to_arena(arena: Node) -> void:
	if arena == null or not arena.has_method("get_combat_floor"):
		return
	var floor: Node = arena.call("get_combat_floor")
	if floor and floor.has_method("set_debug_overlay_visible"):
		floor.call("set_debug_overlay_visible", _map_debug_overlay_visible)


func _is_map_debug_overlay_event(event: InputEvent) -> bool:
	if event.is_action_pressed("debug_map_overlay"):
		return true
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return false
	return key_event.ctrl_pressed and key_event.physical_keycode == KEY_M


func _is_debug_quick_event(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return false
	return key_event.physical_keycode == KEY_F9
