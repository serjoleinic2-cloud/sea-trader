extends CanvasLayer

## A single layout owns the title, message and actions; no absolute dialog overlays.
signal confirmed
signal canceled

var _panel: PanelContainer
var _message: Label
var _title: Label
var _confirm_button: Button
var _cancel_button: Button
var _backdrop: ColorRect
var _center: CenterContainer
var _resolved: bool = false

func _ready() -> void:
	layer = 170
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.0, 0.025, 0.04, 0.78)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)
	_center = CenterContainer.new()
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	_panel = PanelContainer.new()
	_panel.name = "SocialConfirmationPanel"
	_panel.theme = preload("res://systems/ui/game_ui_theme.gd").new().get_theme()
	_center.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 12)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_title = Label.new()
	_title.text = "Подтверждение"
	_title.set_meta("fixed_font_size", 18)
	_title.add_theme_font_size_override("font_size", 18)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_title)
	var close := Button.new()
	preload("res://systems/ui/brass_close_button.gd").apply(close)
	close.pressed.connect(_resolve.bind(false))
	header.add_child(close)
	_message = Label.new()
	_message.name = "ConfirmationMessage"
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message.set_meta("fixed_font_size", 14)
	_message.add_theme_font_size_override("font_size", 14)
	column.add_child(_message)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)
	_cancel_button = _action(actions, "Отмена", false)
	_confirm_button = _action(actions, "Подтвердить", true)
	_layout()
	_cancel_button.grab_focus.call_deferred()

func _action(parent: Node, text: String, accept: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.set_meta("fixed_font_size", 14)
	button.set_meta("compact_hud", true)
	button.custom_minimum_size.y = 36
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(_resolve.bind(accept))
	parent.add_child(button)
	return button

func set_message(text: String) -> void:
	_message.text = text

func _layout() -> void:
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_backdrop.size = viewport
	_center.size = viewport
	_panel.custom_minimum_size.x = minf(560.0, maxf(200.0, viewport.x - 32.0))

func _process(_delta: float) -> void:
	_layout()

func _resolve(accept: bool) -> void:
	if _resolved: return
	_resolved = true
	if accept: confirmed.emit()
	else: canceled.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_resolve(false)
