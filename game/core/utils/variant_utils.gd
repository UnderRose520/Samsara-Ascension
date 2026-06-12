class_name VariantUtils


static func as_bool(value, default: bool = false) -> bool:
	if value == null:
		return default
	if value is bool:
		return value
	return str(value).strip_edges().to_lower() in ["true", "1", "yes"]
