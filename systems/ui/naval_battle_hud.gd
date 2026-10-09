extends CanvasLayer

var _system: Node
var _panel: PanelContainer
var _map: Control
var _badge: Button
var _lantern: Label
var _notice: Label
var _surrender: ConfirmationDialog
var _report: AcceptDialog
var _open_amount: float = 0
var _panel_collapsed: bool = false
var _clock: float = 0
var _report_time: float = -1
var _truce: Button
var _attack_notice: Label
var _attack_notice_until: float = -1.0
var _fit_pending: bool = false
var _game_theme = preload("res://systems/ui/game_ui_theme.gd").new()

func _ready() -> void:
	layer=145
	_badge=Button.new(); _badge.text="НАЧАТЬ БОЙ [Z]"; _badge.custom_minimum_size=Vector2(240,42)
	_badge.pressed.connect(_start_battle); add_child(_badge)
	_lantern=Label.new(); _lantern.text="◉"; _lantern.add_theme_font_size_override("font_size",30); _lantern.add_theme_color_override("font_color",Color("ffe15c")); _lantern.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(_lantern)
	_attack_notice=Label.new(); _attack_notice.text="ВЫ АТАКОВАНЫ"; _attack_notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; _attack_notice.add_theme_font_size_override("font_size",22); _attack_notice.add_theme_color_override("font_color",Color("ff806b")); _attack_notice.add_theme_color_override("font_outline_color",Color("101c27")); _attack_notice.add_theme_constant_override("outline_size",6); _attack_notice.mouse_filter=Control.MOUSE_FILTER_IGNORE; _attack_notice.z_index=20; add_child(_attack_notice)
	_panel=PanelContainer.new(); add_child(_panel)
	var style:=StyleBoxFlat.new(); style.bg_color=Color(0.025,0.075,0.105,0.88); style.border_color=Color("b59353"); style.set_border_width_all(1); style.set_corner_radius_all(5)
	_panel.set_meta("preserve_art_style",true); _panel.add_theme_stylebox_override("panel",style)
	var margin:=MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,10)
	_panel.add_child(margin)
	var column:=VBoxContainer.new(); column.add_theme_constant_override("separation",5); margin.add_child(column)
	var header:=HBoxContainer.new(); column.add_child(header)
	var title:=Label.new(); title.text="МОРСКОЙ БОЙ"; title.add_theme_color_override("font_color",Color("eac46f")); title.add_theme_font_size_override("font_size",16); title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; header.add_child(title)
	var close:=Button.new(); preload("res://systems/ui/brass_close_button.gd").apply(close); close.tooltip_text="Свернуть панель · бой продолжается · свободная камера возвращается"; close.pressed.connect(_collapse_panel); header.add_child(close)
	var actions:=HFlowContainer.new(); actions.add_theme_constant_override("separation",4); column.add_child(actions)
	_button(actions,"Сдаться",func(): _surrender.popup_centered(Vector2i(500,200)))
	_truce=_button(actions,"Перемирие",func(): _show_status(_system.propose_truce()))
	_button(actions,"Общий сбор",func(): _show_status(_system.rally()))
	_notice=Label.new(); _notice.set_meta("fixed_font_size",12); _notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; _notice.custom_minimum_size.y=22; _notice.add_theme_font_size_override("font_size",12); column.add_child(_notice)
	_map=preload("res://systems/ui/naval_tactical_map.gd").new(); _map.custom_minimum_size=Vector2(0,120); _map.size_flags_vertical=Control.SIZE_EXPAND_FILL; _map.size_flags_horizontal=Control.SIZE_EXPAND_FILL; column.add_child(_map)
	var hint:=Label.new(); hint.set_meta("fixed_font_size",11); hint.text="ЛКМ: свой корабль → враг или точка моря\nЗажатая ПКМ: двигать карту · колёсико: масштаб\nОгонь только по вашему приказу"; hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; hint.add_theme_font_size_override("font_size",11); column.add_child(hint)
	_surrender=ConfirmationDialog.new(); _surrender.title="Сдаться"; _surrender.dialog_text="Сдача означает поражение. Будет списано 10% текущей казны. Осколки, свитки, склад базы и контрактный груз защищены."; _surrender.ok_button_text="Сдаться"; _surrender.cancel_button_text="Продолжить бой"; _surrender.confirmed.connect(func(): _show_status(_system.surrender())); add_child(_surrender)
	_report=AcceptDialog.new(); _report.title="Итог морского боя"; add_child(_report)
	_badge.hide(); _panel.hide(); _lantern.hide(); _attack_notice.hide()
	for dialog in [_surrender,_report]:
		if dialog!=null: preload("res://systems/ui/brass_close_button.gd").apply_dialog(dialog)

func _button(parent: Control, text_value: String, callback: Callable) -> Button:
	var button:=Button.new(); button.set_meta("compact_hud",true); button.text=text_value; button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; button.custom_minimum_size.y=42; button.add_theme_font_size_override("font_size",13)
	_game_theme.apply_control(button); button.pressed.connect(callback); parent.add_child(button)
	return button

func initialize(system: Node) -> void:
	_system=system; _map.system=system
	_report_time=float(GameState.combat_state.get("naval_report",{}).get("time",-1))

func _show_status(result: Dictionary) -> void:
	_notice.text=str(result.get("message",""))

func tactical_view_open() -> bool:
	return _system!=null and _system.active() and not _panel_collapsed

func _collapse_panel() -> void:
	_panel_collapsed=true

func _open_panel() -> void:
	_panel_collapsed=false
	_fit_pending=true

func _start_battle() -> void:
	if _system==null: return
	if _system.active():
		_open_panel()
		return
	if _system.nearby_enemies().is_empty(): return
	_open_panel()
	_show_status(_system.begin_battle())

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode==KEY_Z or event.physical_keycode==KEY_Z):
		_start_battle(); get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _system==null: return
	_clock+=delta
	var engaged: bool = _system.active()
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	var width: float = clampf(viewport.x*.25, 290.0, 370.0)
	var coordinator: Node = get_tree().get_first_node_in_group("window_coordinator")
	var top: float = float(coordinator.get("_top_height"))+6.0 if coordinator!=null else 76.0
	var height: float = maxf(0,viewport.y-top)
	if engaged and _open_amount==0:
		_fit_pending=true
		_map.center=_system.vector(GameState.ship_state.position)
		var ids: Array = GameState.combat_state.naval_battle.ship_ids
		_map.selected=str(ids[0]) if not ids.is_empty() else ""
	_open_amount=move_toward(_open_amount,1.0 if engaged and not _panel_collapsed else 0.0,delta*4)
	_panel.visible=_open_amount>0
	_panel.size=Vector2(width,height)
	var slide: float = _open_amount*_open_amount*(3.0-2.0*_open_amount)
	_panel.position=Vector2(viewport.x-width*slide,top)
	if engaged and _fit_pending and _open_amount>=1.0 and _map.size.y>60:
		_map.fit_battle()
		_fit_pending=false
	if engaged:
		if _open_amount<.05: _map.center=_system.vector(GameState.ship_state.position)
		var battle: Dictionary = GameState.combat_state.naval_battle
		_notice.text=str(battle.get("notice","Бой идёт."))
		_notice.text+="\nВремя %d:%02d · выстрелов %d" % [floori(float(battle.get("elapsed",0))/60.0),int(battle.get("elapsed",0))%60,int(battle.get("shots",0))]
		_truce.disabled=bool(battle.get("truce_pending",false))
		if bool(battle.get("enemy_initiated",false)) and _attack_notice_until < 0.0:
			_attack_notice_until=_clock+4.0
	else:
		_attack_notice_until=-1.0
	_attack_notice.visible=engaged and _clock<_attack_notice_until
	if _attack_notice.visible:
		_attack_notice.size=Vector2(viewport.x,34)
		_attack_notice.position=_flagship_screen_position()+Vector2(-viewport.x*.5,-88)
	var alert: bool = not _system.nearby_enemies().is_empty()
	_badge.visible=alert or (engaged and _panel_collapsed); _badge.text="ОТКРЫТЬ БОЙ [Z]" if engaged else "НАЧАТЬ БОЙ [Z]"; _badge.position=Vector2((viewport.x-_badge.size.x)*.5,viewport.y-100)
	_lantern.visible=alert and fmod(_clock,1)<.55
	_lantern.position=_flagship_screen_position()+Vector2(-15,-55)
	var report: Dictionary = GameState.combat_state.get("naval_report",{})
	if not report.is_empty() and float(report.get("time",-1))!=_report_time:
		_report_time=float(report.time)
		var text_value: String = str(report.outcome)
		var loss: Dictionary = report.get("losses",{})
		if not loss.is_empty():
			if int(loss.get("money",0))>0: text_value+="\nСписано из казны: %d монет." % int(loss.money)
			if int(loss.get("magic_shards",0))>0: text_value+="\nПотеряно осколков: %d." % int(loss.magic_shards)
			for resource in loss.get("resources",{}): text_value+="\n%s: %d" % [str(GameData.get_good(str(resource)).get("name",resource)),int(loss.resources[resource])]
			for resource in loss.get("cargo",{}): text_value+="\nПохищено из трюма · %s: %d" % [str(GameData.get_good(str(resource)).get("name",resource)),int(loss.cargo[resource])]
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
