extends RefCounted

## Shared square hit target with a circular brass rim. Existing signals stay intact.
static var _icon: ImageTexture

static func apply(button: Button) -> void:
	if _icon == null:
		var image := Image.new()
		image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 40 40"><defs><linearGradient id="brass" x2="0.8" y2="1"><stop stop-color="#fff0b0"/><stop offset="0.35" stop-color="#cc9946"/><stop offset="0.65" stop-color="#805622"/><stop offset="1" stop-color="#f2cd76"/></linearGradient><radialGradient id="face"><stop stop-color="#203743"/><stop offset="1" stop-color="#07141d"/></radialGradient></defs><circle cx="20" cy="20" r="18" fill="url(#face)" stroke="#47321b" stroke-width="3"/><circle cx="20" cy="20" r="17" fill="none" stroke="url(#brass)" stroke-width="3"/><circle cx="20" cy="20" r="14.7" fill="none" stroke="#ddbd74" stroke-width="0.6"/><path d="M14 14L26 26M26 14L14 26" stroke="#f9e6b4" stroke-width="2.5" stroke-linecap="round"/></svg>')
		_icon = ImageTexture.create_from_image(image)
	button.set_meta("brass_close", true)
	button.set_meta("preserve_art_style", true)
	button.text = ""
	button.icon = _icon
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", 36)
	button.custom_minimum_size = Vector2(40, 40)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.tooltip_text = "Закрыть окно · Esc"
	for state in ["normal", "pressed", "hover", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_color_override("icon_hover_color", Color(1.2, 1.12, 0.9))
	button.add_theme_color_override("icon_pressed_color", Color(0.8, 0.8, 0.75))

static func apply_dialog(dialog: AcceptDialog) -> void:
	if dialog.has_meta("brass_dialog"): return
	dialog.set_meta("brass_dialog",true)
	dialog.borderless = true
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("0c202d")
	panel.border_color = Color("bd9752")
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(9)
	panel.content_margin_top = 54
	panel.content_margin_bottom = 12
	panel.content_margin_left = 16
	panel.content_margin_right = 16
	dialog.add_theme_stylebox_override("panel",panel)
	var title := Label.new()
	title.text = dialog.title
	title.position = Vector2(16,15)
	title.add_theme_font_size_override("font_size",16)
	title.add_theme_color_override("font_color",Color("f0d18d"))
	dialog.add_child(title)
	var close := Button.new()
	apply(close)
	close.name="CloseButton"
	close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close.offset_left=-48; close.offset_right=-8
	close.offset_top=8; close.offset_bottom=48
	close.z_index=10
	close.pressed.connect(func(): dialog.hide(); dialog.canceled.emit())
	dialog.add_child(close)
