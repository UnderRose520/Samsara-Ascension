class_name CsvLoader


static func load_rows(path: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		push_warning("CsvLoader: missing %s" % path)
		return rows

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return rows

	var headers: PackedStringArray = []
	var reading_header := true
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var cells := _split_csv_line(line)
		if reading_header:
			headers = PackedStringArray(cells)
			reading_header = false
			continue
		var row: Dictionary = {}
		for i in headers.size():
			if i < cells.size():
				row[headers[i]] = cells[i]
		rows.append(row)
	file.close()
	return rows


static func _split_csv_line(line: String) -> Array[String]:
	var result: Array[String] = []
	var current := ""
	var in_quotes := false
	for i in line.length():
		var ch := line[i]
		if ch == "\"":
			in_quotes = not in_quotes
			continue
		if ch == "," and not in_quotes:
			result.append(current.strip_edges())
			current = ""
			continue
		current += ch
	result.append(current.strip_edges())
	return result
