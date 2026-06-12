extends RefCounted

var id: String
var name: String
var category: int = 1
var element: int = 0
var quality: int = 0
var dao_bucket: int = 0
var combo_tags: PackedStringArray = []
var description: String = ""
var passives: Array = []
var on_hit: Array = []


func duplicate_tag():
	var copy = get_script().new()
	copy.id = id
	copy.name = name
	copy.category = category
	copy.element = element
	copy.quality = quality
	copy.dao_bucket = dao_bucket
	copy.combo_tags = combo_tags.duplicate()
	copy.description = description
	copy.passives = passives.duplicate(false)
	copy.on_hit = on_hit.duplicate(false)
	return copy
