extends PanelContainer

var _image: TextureRect
var _heading: Label
var _effect: Label
var _description: Label
var _status: Label
var _action: Button
var _reader: Callable
var _elapsed: float = 0.0

func _ready() -> void:
	name = "BoostTile"
	custom_minimum_size = Vector2(264, 204)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	theme = preload("res://systems/ui/game_ui_theme.gd").new().get_theme()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	_image = TextureRect.new()
	_image.name = "BoostArtwork"
	_image.custom_minimum_size = Vector2(96, 96)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_image)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 4)
	row.add_child(copy)
	_heading = _label(copy, 14)
	_heading.add_theme_font_override("font", preload("res://systems/ui/game_ui_theme.gd").button_font())
	_effect = _label(copy, 24)
	_effect.add_theme_color_override("font_color", Color("83ded9"))
	_status = _label(copy, 12)
	_status.add_theme_color_override("font_color", Color("e2c184"))
	_description = _label(column, 12)
	_description.max_lines_visible = 2
	_description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_action = Button.new()
	_action.name = "BoostAction"
	_action.set_meta("fixed_font_size", 12)
	_action.set_meta("boost_tile_action", true)
	_action.custom_minimum_size.y = 34
	_action.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(_action)

func _label(parent: Node, font_size: int) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.set_meta("fixed_font_size", font_size)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func configure(title: String, effect: String, description: String, stat: String, action: Callable, reader: Callable) -> void:
	_heading.text = title
	_effect.text = effect
	_description.text = description
	_description.tooltip_text = description
	_image.texture = preload("res://systems/ui/boost_item_art.gd").texture(stat)
	_action.pressed.connect(action)
	_reader = reader
	_refresh_status()

func _refresh_status() -> void:
	if not _reader.is_valid(): return
	var state: Dictionary = _reader.call()
	_status.text = str(state.get("status", ""))
	_action.text = str(state.get("action", "Активировать"))
	_action.disabled = bool(state.get("disabled", false))
	_action.tooltip_text = str(state.get("tooltip", ""))

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 1.0:
		_elapsed = 0.0
		_refresh_status()
