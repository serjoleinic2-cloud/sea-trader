extends CanvasLayer

var _system: Node
var _panel: PanelContainer
var _map: Control
var _badge: Button
var _lantern: Label
var _notice: Label
var _surrender: ConfirmationDialog
var _repair_panel: PanelContainer
var _repair_rows: VBoxContainer
var _repair_status: Label
var _repair_scroll: ScrollContainer
var _report_panel: PanelContainer
var _report_text: Label
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
	_build_report_panel()
	_build_repair_panel()
	_badge.hide(); _panel.hide(); _lantern.hide(); _attack_notice.hide()
	preload("res://systems/ui/brass_close_button.gd").apply_dialog(_surrender)

func _build_report_panel() -> void:
	_report_panel = PanelContainer.new()
	_report_panel.name = "NavalBattleReport"
	_report_panel.visible = false
	_report_panel.custom_minimum_size = Vector2(500, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("081a24")
	style.border_color = Color("b59353")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	_report_panel.add_theme_stylebox_override("panel", style)
	add_child(_report_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 18)
	_report_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "ИТОГ МОРСКОГО БОЯ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color("eac46f"))
	title.add_theme_font_size_override("font_size", 17)
	header.add_child(title)
	var close := Button.new()
	preload("res://systems/ui/brass_close_button.gd").apply(close)
	close.pressed.connect(_close_battle_report)
	header.add_child(close)
	_report_text = Label.new()
	_report_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_report_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_report_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_report_text.custom_minimum_size.y = 120
	_report_text.add_theme_font_size_override("font_size", 13)
	column.add_child(_report_text)
	var ok := Button.new()
	ok.text = "ОК"
	ok.custom_minimum_size = Vector2(120, 36)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(_close_battle_report)
	column.add_child(ok)

func _close_battle_report() -> void:
	_report_panel.hide()
	_open_repair_after_report()

func _show_battle_report(text_value: String) -> void:
	_report_text.text = text_value
	_report_panel.show()
	_report_panel.z_index = 30
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_report_panel.size = Vector2(minf(600.0, viewport.x - 32.0), minf(360.0, viewport.y - 32.0))
	_report_panel.position = (viewport - _report_panel.size) * 0.5
	_report_panel.move_to_front()

func _build_repair_panel() -> void:
	_repair_panel = PanelContainer.new()
	_repair_panel.name = "PostBattleRepairPanel"
	_repair_panel.visible = false
	_repair_panel.custom_minimum_size = Vector2(540, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("081a24")
	style.border_color = Color("b59353")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	_repair_panel.add_theme_stylebox_override("panel", style)
	add_child(_repair_panel)
	var margins := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margins.add_theme_constant_override("margin_" + side, 14)
	_repair_panel.add_child(margins)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margins.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "РЕМОНТ ПОСЛЕ БОЯ"
	title.add_theme_color_override("font_color", Color("eac46f"))
	title.add_theme_font_size_override("font_size", 17)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	preload("res://systems/ui/brass_close_button.gd").apply(close)
	close.pressed.connect(func(): _repair_panel.hide())
	header.add_child(close)
	_repair_status = Label.new()
	_repair_status.custom_minimum_size.y = 28
	_repair_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_repair_status.add_theme_font_size_override("font_size", 12)
	column.add_child(_repair_status)
	_repair_scroll = ScrollContainer.new()
	_repair_scroll.name = "RepairShipRowsScroll"
	_repair_scroll.custom_minimum_size.y = 250
	_repair_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_repair_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_repair_scroll)
	_repair_rows = VBoxContainer.new()
	_repair_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_repair_rows.add_theme_constant_override("separation", 6)
	_repair_scroll.add_child(_repair_rows)

func _open_repair_after_report() -> void:
	if _system == null or _system.active(): return
	var damaged := false
	for ship in _system.warships():
		if float(ship.get("hull", 0.0)) > 0.0 and float(ship.get("hull", 0.0)) < float(_system.hull_max(ship)):
			damaged = true
			break
	if not damaged: return
	_refresh_repair_rows()
	_repair_panel.show()
	_repair_panel.z_index = 31
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_repair_panel.size = Vector2(minf(680.0, viewport.x - 32.0), minf(600.0, viewport.y - 32.0))
	_repair_panel.position = (viewport - _repair_panel.size) * 0.5
	_repair_panel.move_to_front()

func _refresh_repair_rows() -> void:
	for child in _repair_rows.get_children():
		_repair_rows.remove_child(child)
		child.queue_free()
	var damaged_count := 0
	for ship in _system.warships():
		var hull: float = float(ship.get("hull", 0.0))
		var maximum: float = float(_system.hull_max(ship))
		if hull <= 0.0 or hull >= maximum: continue
		damaged_count += 1
		var id: String = str(ship.get("instance_id", ""))
		var quote: Dictionary = _system.repair_quote(id)
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 40
		row.add_theme_constant_override("separation", 8)
		_repair_rows.add_child(row)
		var label := Label.new()
		label.text = "%s · корпус %.0f / %.0f · %d монет" % [str(ship.get("name", "Корабль")), hull, maximum, int(quote.get("cost", 0))]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.clip_text = true
		label.add_theme_font_size_override("font_size", 11)
		row.add_child(label)
		var repair := Button.new()
		repair.text = "Ремонт"
		repair.custom_minimum_size = Vector2(92, 34)
		repair.disabled = float(GameState.player_state.get("money", 0.0)) < float(quote.get("cost", 0))
		repair.tooltip_text = "Восстановить корпус до максимума за %d монет" % int(quote.get("cost", 0))
		repair.pressed.connect(_repair_after_battle.bind(id))
		row.add_child(repair)
	_repair_status.text = "Выберите корабль: цена указана в строке. Потопленные суда нельзя восстановить." if damaged_count > 0 else "Все боевые корабли исправны."

func _repair_after_battle(ship_id: String) -> void:
	var result: Dictionary = _system.repair_ship_after_battle(ship_id)
	_repair_status.text = str(result.get("message", ""))
	_refresh_repair_rows()

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
	if _report_panel.visible:
		var report_viewport: Vector2 = get_viewport().get_visible_rect().size
		_report_panel.size = Vector2(minf(600.0, report_viewport.x - 32.0), minf(360.0, report_viewport.y - 32.0))
		_report_panel.position = (report_viewport - _report_panel.size) * 0.5
	if _repair_panel.visible:
		var repair_viewport: Vector2 = get_viewport().get_visible_rect().size
		_repair_panel.size = Vector2(minf(680.0, repair_viewport.x - 32.0), minf(600.0, repair_viewport.y - 32.0))
		_repair_panel.position = (repair_viewport - _repair_panel.size) * 0.5
		_repair_panel.position = (repair_viewport - _repair_panel.size) * 0.5
	var report: Dictionary = GameState.combat_state.get("naval_report",{})
	if not report.is_empty() and float(report.get("time",-1))!=_report_time:
		_report_time=float(report.time)
		var text_value: String = str(report.outcome)
		if int(report.get("reward_money", 0)) > 0:
			text_value += "\nПодняты трофеи: +%d монет." % int(report.reward_money)
		if str(report.get("naval_superiority_port_id", "")) != "":
			text_value += "\nПатруль у порта разбит: морское превосходство действует 15 минут."
		var loss: Dictionary = report.get("losses",{})
		if not loss.is_empty():
			if int(loss.get("money",0))>0: text_value+="\nСписано из казны: %d монет." % int(loss.money)
			if int(loss.get("magic_shards",0))>0: text_value+="\nПотеряно осколков: %d." % int(loss.magic_shards)
			for resource in loss.get("resources",{}): text_value+="\n%s: %d" % [str(GameData.get_good(str(resource)).get("name",resource)),int(loss.resources[resource])]
			for resource in loss.get("cargo",{}): text_value+="\nПохищено из трюма · %s: %d" % [str(GameData.get_good(str(resource)).get("name",resource)),int(loss.cargo[resource])]
		_show_battle_report(text_value)

func _flagship_screen_position() -> Vector2:
	var main: Node = _system._main
	if main!=null:
		var approach: Node = main.get_node_or_null("Approach3DView")
		if approach!=null and bool(approach.get("_camera_initialized")):
			var camera: Camera3D = approach.get("_camera")
			var ship: Node3D = approach.get("_ship")
			if camera!=null and ship!=null:
				var point: Vector3 = ship.global_position+Vector3.UP*1.5
				if not camera.is_position_behind(point):
					return camera.unproject_position(point)
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera!=null: return camera.get_canvas_transform()*_system.vector(GameState.ship_state.position)
	return get_viewport().get_visible_rect().size*.5
