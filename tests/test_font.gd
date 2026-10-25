extends SceneTree
## The bundled font must render Chinese without relying on the developer OS.
const FONT := preload("res://assets/fonts/interface.otf")


func _initialize() -> void:
	var required := {}
	for file in DirAccess.get_files_at("res://scripts"):
		if not file.ends_with(".gd"): continue
		var source := FileAccess.get_file_as_string("res://scripts/" + file)
		for character in source:
			var code := character.unicode_at(0)
			if code >= 0x3400 and code <= 0x9fff: required[character] = true
	var supported := FONT.get_supported_chars()
	var missing := ""
	for character: String in required:
		if not supported.contains(character): missing += character
	if not missing.is_empty():
		printerr("FAIL font: bundled UI font lacks Chinese glyphs: ", missing)
		quit(1)
	else:
		print("PASS font: %d runtime Chinese glyphs available in the bundled font" % required.size())
		quit()
