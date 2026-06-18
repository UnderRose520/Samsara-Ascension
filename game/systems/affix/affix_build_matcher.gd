class_name AffixBuildMatcher

const ElementUtils = preload("res://core/utils/element_utils.gd")


static func matches(tag, element_bias: String, desired_tags: Array) -> bool:
	if tag == null:
		return false
	if not element_bias.is_empty() and ElementUtils.key(tag.element) == element_bias:
		return true
	for combo_tag in tag.combo_tags:
		if str(combo_tag) in desired_tags:
			return true
	return false
