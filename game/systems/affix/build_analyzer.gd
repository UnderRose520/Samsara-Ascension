class_name BuildAnalyzer


static func layer_counts(equipped: Array) -> Dictionary:
	var counts := {"spell": 0, "constitution": 0, "synergy": 0, "other": 0}
	for tag in equipped:
		match tag.category:
			1: counts.spell += 1
			2: counts.constitution += 1
			4: counts.synergy += 1
			_: counts.other += 1
	return counts


static func format_layers(equipped: Array) -> String:
	var c: Dictionary = layer_counts(equipped)
	return "术%d·体%d·契%d" % [c.spell, c.constitution, c.synergy]
