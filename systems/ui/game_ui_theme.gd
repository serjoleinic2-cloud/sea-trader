extends RefCounted

var _theme: Theme
var _faction_id: String = ""

func get_theme() -> Theme:
	var faction_id: String = str(GameState.player_state.get("origin_race_id", "humans"))
	if _theme != null and faction_id == _faction_id:
		return _theme
	_faction_id = faction_id
	var faction: Dictionary = GameData.get_faction(faction_id)
	var palette: Array = faction.get("palette", ["#132b43", "#2bbcc1", "#c49a58"])
	var accent := Color(str(palette[1]))
	var brass := Color(str(palette[2]))
	var faction_shape: Dictionary = {
		"nerids": {"radius": 14, "edge": 3},
		"surr": {"radius": 5, "edge": 3},
		"meridians": {"radius": 8, "edge": 2},
		"aery": {"radius": 17, "edge": 2},
		"crystari": {"radius": 3, "edge": 3},
		"humans": {"radius": 10, "edge": 2}
	}
	var frame_shape: Dictionary = faction_shape.get(faction_id, faction_shape["humans"])
	_theme = Theme.new()
	_theme.default_font_size = 16
	var panel: StyleBoxTexture = _texture_box("res://assets/ui/styles/approved_hud/button_frame.png", 17, 9, 17, 9)
	panel.content_margin_left = 16
	panel.content_margin_right = 16
	panel.content_margin_top = 14
	panel.content_margin_bottom = 12
	_theme.set_stylebox("panel", "PanelContainer", panel)
	_theme.set_stylebox("panel", "Panel", panel)
	var title_font := SystemFont.new()
	title_font.font_names = PackedStringArray(["Georgia", "Noto Serif", "serif"])
	title_font.font_weight = 700
	for type in ["Button", "OptionButton", "CheckButton"]:
		_theme.set_font("font", type, title_font)
		var normal_button := _button_style(Color.WHITE)
		var hover_button: StyleBoxTexture = normal_button.duplicate() as StyleBoxTexture
		hover_button.modulate_color = Color(1.12, 1.08, 0.98, 1.0)
		var pressed_button: StyleBoxTexture = normal_button.duplicate() as StyleBoxTexture
		pressed_button.modulate_color = Color(0.78, 0.80, 0.83, 1.0)
		_theme.set_stylebox("normal", type, normal_button)
		_theme.set_stylebox("hover", type, hover_button)
		_theme.set_stylebox("pressed", type, pressed_button)
		_theme.set_stylebox("focus", type, _box(Color(0, 0, 0, 0), brass, int(frame_shape["radius"]), 2))
		var disabled_button: StyleBoxTexture = normal_button.duplicate() as StyleBoxTexture
		disabled_button.modulate_color = Color(0.52, 0.56, 0.59, 1.0)
		_theme.set_stylebox("disabled", type, disabled_button)
		for state in ["font_color", "font_hover_color", "font_pressed_color"]:
			_theme.set_color(state, type, Color("f0e9d8"))
		_theme.set_color("font_disabled_color", type, Color("718791"))
		_theme.set_constant("h_separation", type, 10)
	for type in ["Label", "RichTextLabel", "LineEdit", "TextEdit", "SpinBox", "CheckBox"]:
		_theme.set_color("font_color", type, Color("e4e9e7"))
	_theme.set_stylebox("normal", "LineEdit", _box(Color("071824"), Color("365b67"), 7, 1))
	_theme.set_stylebox("focus", "LineEdit", _box(Color(0, 0, 0, 0), accent, 7, 2))
	_theme.set_color("caret_color", "LineEdit", accent)
	_theme.set_stylebox("background", "ProgressBar", _box(Color("071521"), Color("345462"), 5, 1))
	_theme.set_stylebox("fill", "ProgressBar", _box(accent.darkened(0.2), accent, 5, 0))
	_theme.set_color("font_color", "ProgressBar", Color("f0e9d8"))
	for type in ["HSlider", "VSlider"]:
		_theme.set_stylebox("slider", type, _box(Color("0b2330"), Color("365b67"), 4, 1))
		_theme.set_stylebox("grabber_area", type, _box(accent.darkened(0.25), accent, 4, 0))
		_theme.set_stylebox("grabber_area_highlight", type, _box(accent, brass, 4, 0))
	_theme.set_constant("separation", "VBoxContainer", 10)
	_theme.set_constant("separation", "HBoxContainer", 10)
	_theme.set_stylebox("panel", "PopupMenu", panel)
	_theme.set_color("font_color", "PopupMenu", Color("f0e9d8"))
	_theme.set_stylebox("hover", "PopupMenu", _box(Color("204653"), brass, 6, 1))
	return _theme

func apply_control(control: Control) -> void:
	var theme: Theme = get_theme()
	if control.theme != theme:
		control.theme = theme
	if control.has_meta("preserve_art_style"):
		return
	if control.has_meta("sea_game_theme"):
		return
	if control is Button:
		for style in ["normal", "hover", "pressed", "focus", "disabled"]:
			control.remove_theme_stylebox_override(style)
		for color in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
			control.remove_theme_color_override(color)
	elif control is PanelContainer:
		control.remove_theme_stylebox_override("panel")
	control.set_meta("sea_game_theme", true)

func _box(fill: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _texture_box(path: String, left: float, top: float, right: float, bottom: float) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(path) as Texture2D
	style.texture_margin_left = left
	style.texture_margin_top = top
	style.texture_margin_right = right
	style.texture_margin_bottom = bottom
	return style

func _button_style(modulate: Color) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load("res://assets/ui/styles/approved_hud/button_frame.png") as Texture2D
	style.texture_margin_left = 18.0
	style.texture_margin_top = 11.0
	style.texture_margin_right = 18.0
	style.texture_margin_bottom = 11.0
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	style.modulate_color = modulate
	return style
