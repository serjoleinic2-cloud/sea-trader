extends CanvasLayer

var _system: Node
var _panel: PanelContainer
var _map: Control
var _badge: Button
var _lantern: Label
var _notice: Label
var _choice: ConfirmationDialog
var _surrender: ConfirmationDialog
var _report: AcceptDialog
var _open_amount: float = 0
var _clock: float = 0
var _report_time: float = -1
var _truce: Button

func _ready() -> void:
	layer=145
	_badge=Button.new(); _badge.text="ОБНАРУЖЕН ФЛОТ [Z]"; _badge.custom_minimum_size=Vector2(240,42)
	_badge.pressed.connect(_show_choice); add_child(_badge)
	_lantern=Label.new(); _lantern.text="◉"; _lantern.add_theme_font_size_override("font_size",30); _lantern.add_theme_color_override("font_color",Color("ffe15c")); _lantern.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(_lantern)
	_panel=PanelContainer.new(); add_child(_panel)
	var style:=StyleBoxFlat.new(); style.bg_color=Color("10212d"); style.border_color=Color("b59353"); style.set_border_width_all(2)
	_panel.set_meta("preserve_art_style",true); _panel.add_theme_stylebox_override("panel",style)
	var margin:=MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,10)
	_panel.add_child(margin)
	var column:=VBoxContainer.new(); column.add_theme_constant_override("separation",8); margin.add_child(column)
	var title:=Label.new(); title.text="МОРСКОЙ БОЙ"; title.add_theme_color_override("font_color",Color("eac46f")); title.add_theme_font_size_override("font_size",20); column.add_child(title)
	var actions:=HFlowContainer.new(); actions.add_theme_constant_override("separation",4); column.add_child(actions)
	_button(actions,"Сдаться",func(): _surrender.popup_centered(Vector2i(500,200)))
	_truce=_button(actions,"Перемирие",func(): _show_status(_system.propose_truce()))
	_button(actions,"Общий сбор",func(): _show_status(_system.rally()))
	_notice=Label.new(); _notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; _notice.custom_minimum_size.y=52; _notice.add_theme_font_size_override("font_size",14); column.add_child(_notice)
	_map=preload("res://systems/ui/naval_tactical_map.gd").new(); _map.size_flags_vertical=Control.SIZE_EXPAND_FILL; _map.size_flags_horizontal=Control.SIZE_EXPAND_FILL; column.add_child(_map)
	var hint:=Label.new(); hint.text="Синий — свой · красный — враг\nЛКМ: выбрать → курс / атака\nПКМ: двигать карту · колесо: масштаб"; hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; hint.add_theme_font_size_override("font_size",13); column.add_child(hint)
	_choice=ConfirmationDialog.new(); _choice.title="Встречен боевой флот"; _choice.dialog_text="Начать бой? Корабли выйдут из сопровождения.\nВраждебный патруль может атаковать вооружённую эскадру."; _choice.ok_button_text="Начать бой"; _choice.cancel_button_text="Продолжить путь"; _choice.confirmed.connect(func(): _show_status(_system.begin_battle())); add_child(_choice)
	_surrender=ConfirmationDialog.new(); _surrender.title="Сдаться"; _surrender.dialog_text="Сдача означает поражение. Будет списано 10% монет, осколков и свободных ресурсов домашнего склада."; _surrender.ok_button_text="Сдаться"; _surrender.cancel_button_text="Продолжить бой"; _surrender.confirmed.connect(func(): _show_status(_system.surrender())); add_child(_surrender)
	_report=AcceptDialog.new(); _report.title="Итог морского боя"; add_child(_report)
	_badge.hide(); _panel.hide(); _lantern.hide()

func _button(parent: Control, text_value: String, callback: Callable) -> Button:
	var button:=Button.new(); button.set_meta("preserve_art_style",true); button.set_meta("compact_hud",true); button.text=text_value; button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; button.custom_minimum_size.y=42; button.add_theme_font_size_override("font_size",13)
	var style:=StyleBoxFlat.new(); style.bg_color=Color("d1ad64"); style.border_color=Color("f5d996"); style.set_border_width_all(1); style.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal",style); button.add_theme_color_override("font_color",Color("10212d")); button.pressed.connect(callback); parent.add_child(button)
	return button

func initialize(system: Node) -> void:
	_system=system; _map.system=system
	_report_time=float(GameState.combat_state.get("naval_report",{}).get("time",-1))

func _show_status(result: Dictionary) -> void:
	_notice.text=str(result.get("message",""))

func _show_choice() -> void:
	if _system==null or _system.nearby_enemies().is_empty(): return
	_choice.popup_centered(Vector2i(500,210))

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode==KEY_Z or event.physical_keycode==KEY_Z):
		_show_choice(); get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _system==null: return
	_clock+=delta
	var engaged: bool = _system.active()
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	var width: float = viewport.x*.25
	if engaged and _open_amount==0: _map.center=_system.vector(GameState.ship_state.position)
	_open_amount=move_toward(_open_amount,1.0 if engaged else 0.0,delta*4)
	_panel.visible=_open_amount>0
	_panel.size=Vector2(width,viewport.y)
	_panel.position=Vector2(viewport.x-width*_open_amount,0)
	if engaged:
		_choice.hide()
		if _open_amount<.05: _map.center=_system.vector(GameState.ship_state.position)
		var battle: Dictionary = GameState.combat_state.naval_battle
		_notice.text=str(battle.get("notice","Бой идёт."))
		_truce.disabled=bool(battle.get("truce_pending",false))
	var alert: bool = not _system.nearby_enemies().is_empty()
	_badge.visible=alert; _badge.position=Vector2((viewport.x-_badge.size.x)*.5,viewport.y-100)
	_lantern.visible=alert and fmod(_clock,1)<.55
	_lantern.position=_flagship_screen_position()+Vector2(-15,-55)
	var report: Dictionary = GameState.combat_state.get("naval_report",{})
	if not report.is_empty() and float(report.get("time",-1))!=_report_time:
		_report_time=float(report.time)
		var text_value: String = str(report.outcome)
		var loss: Dictionary = report.get("losses",{})
		if not loss.is_empty():
			text_value+="\nСписано из казны: %d монет, %d осколков." % [int(loss.money),int(loss.magic_shards)]
			for resource in loss.get("resources",{}): text_value+="\n%s: %d" % [str(GameData.get_good(str(resource)).get("name",resource)),int(loss.resources[resource])]
		_report.dialog_text=text_value; _report.popup_centered(Vector2i(500,250))

func _flagship_screen_position() -> Vector2:
	var main: Node = _system._main
	if main!=null:
		var approach: Node = main.get_node_or_null("Approach3DView")
		if approach!=null:
			var camera: Camera3D = approach.get("_camera")
			var ship: Node3D = approach.get("_ship")
			if camera!=null and ship!=null:
				return camera.unproject_position(ship.global_position+Vector3.UP*1.5)
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera!=null: return camera.get_canvas_transform()*_system.vector(GameState.ship_state.position)
	return get_viewport().get_visible_rect().size*.5
