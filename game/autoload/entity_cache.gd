extends Node

## 场景内玩家/灵宠节点缓存，避免每帧 get_nodes_in_group。

var _player_cache: Node = null
var _pet_cache: Node = null


func get_player() -> Node:
	if _player_cache != null and is_instance_valid(_player_cache):
		return _player_cache
	var tree := get_tree()
	if tree:
		_player_cache = tree.get_first_node_in_group("player")
	return _player_cache


func get_pet() -> Node:
	if _pet_cache != null and is_instance_valid(_pet_cache):
		return _pet_cache
	var tree := get_tree()
	if tree:
		_pet_cache = tree.get_first_node_in_group("pet")
	return _pet_cache


func invalidate_player() -> void:
	_player_cache = null


func invalidate_pet() -> void:
	_pet_cache = null
