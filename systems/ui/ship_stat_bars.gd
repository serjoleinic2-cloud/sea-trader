extends GridContainer

## Compact numeric scales shared by ship equipment and construction previews.
func _ready() -> void:
	columns = 2
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("h_separation", 12)
	add_theme_constant_override("v_separation", 2)

func display(rows: Array, previous: Dictionary = {}) -> void:
	for child in get_children(): remove_child(child); child.queue_free()
	for row in rows:
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 2)
		add_child(box)
		var value: float = float(row.value)
		var before: float = float(previous.get(str(row.id), row.base))
		var difference: float = value - before
		var improving: bool = difference < 0 if bool(row.get("lower_better",false)) else difference > 0
		if bool(row.get("lower_better",false)) and is_zero_approx(before): improving = value > 0
		var color := Color("7ee1c3") if improving else Color("ee987e")
		if is_zero_approx(difference): color = Color("d4dfdf")
		var label := Label.new()
		label.set_meta("fixed_font_size", 11)
		label.add_theme_font_size_override("font_size", 11)
		label.text = "%s  %s / %s%s" % [str(row.get("label",row.id)), _number(value), _number(float(row.maximum)), str(row.get("unit",""))]
		if not is_zero_approx(difference): label.text += "  %+.1f" % difference
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.tooltip_text = "%s: %s → %s %s\nШкала 0–%s; базовое значение %s. %s" % [str(row.get("label",row.id)),_number(before),_number(value),str(row.get("unit","")),_number(float(row.maximum)),_number(float(row.base)),"Меньше — лучше." if bool(row.get("lower_better",false)) else "Больше — лучше."]
		box.add_child(label)
		var bar := ProgressBar.new()
		bar.name = "Stat_" + str(row.id)
		bar.set_meta("preserve_art_style",true)
		bar.custom_minimum_size.y = 6
		bar.show_percentage = false
		bar.min_value = 0
		bar.max_value = float(row.maximum)
		bar.value = value
		bar.tooltip_text = label.tooltip_text
		var background := StyleBoxFlat.new()
		background.bg_color = Color("112531")
		background.border_color = Color("756245")
		background.set_border_width_all(1)
		bar.add_theme_stylebox_override("background",background)
		var fill := StyleBoxFlat.new()
		fill.bg_color = color.darkened(0.18)
		bar.add_theme_stylebox_override("fill",fill)
		box.add_child(bar)
		var marker := ColorRect.new()
		marker.color = Color("eee0b2")
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.size = Vector2(2,6)
		bar.add_child(marker)
		var ratio: float = clampf(before / maxf(0.001,float(row.maximum)),0,1)
		bar.resized.connect(func(): marker.position.x=clampf(bar.size.x*ratio,0,maxf(0,bar.size.x-2)))
		label.add_theme_color_override("font_color",color)

func _number(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value,float(roundi(value))) else "%.1f" % value
