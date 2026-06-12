extends Node

## 局内业力与事件出现次数，供事件筛选与 HUD 展示。

var karma: Dictionary = {}
var events_seen: Dictionary = {}


func reset() -> void:
	karma.clear()
	events_seen.clear()


func add_karma(kind: String, amount: int = 1) -> void:
	karma[kind] = int(karma.get(kind, 0)) + amount
	EventBus.karma_changed.emit(karma.duplicate())


func get_karma(kind: String) -> int:
	return int(karma.get(kind, 0))


func record_event(event_id: String) -> void:
	if event_id.is_empty():
		return
	events_seen[event_id] = int(events_seen.get(event_id, 0)) + 1
