extends RefCounted

static func validate(value: String, maximum: int, minimum: int = 1) -> String:
	var text: String = value.strip_edges()
	if text.length() < minimum or text.length() > maximum:
		return "Длина текста: от %d до %d символов." % [minimum, maximum]
	var normalized: String = text.to_lower().replace("ё", "е")
	# Collapse common Latin/Cyrillic lookalikes and leetspeak before checking.
	# This also catches words split with punctuation because `compact` is checked below.
	for pair in [["a", "а"], ["e", "е"], ["o", "о"], ["x", "х"], ["y", "у"], ["c", "с"], ["k", "к"], ["m", "м"], ["t", "т"], ["p", "р"], ["b", "в"], ["h", "н"], ["0", "о"], ["3", "з"], ["4", "ч"], ["6", "б"], ["@", "а"], ["$", "с"]]:
		normalized = normalized.replace(pair[0], pair[1])
	var strips := RegEx.new()
	strips.compile("[^a-zа-я0-9]+")
	var compact: String = strips.sub(normalized, "", true)
	var blocked_patterns: Array = GameData.read("res://data/social/clan_rules.json").get("blocked_patterns", [])
	for raw_pattern in blocked_patterns:
		var pattern := RegEx.new()
		pattern.compile(str(raw_pattern))
		if pattern.search(normalized) != null or pattern.search(compact) != null or pattern.search(text.to_lower()) != null:
			return "Используйте текст без ругани и оскорблений."
	for index in text.length():
		if text.unicode_at(index) < 32 and text.unicode_at(index) != 10:
			return "Недопустимый символ в тексте."
	return ""
