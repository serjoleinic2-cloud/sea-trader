extends Control

## Dedicated warship armament screen: hardpoints, live ship preview, store and arsenal.

signal closed

var _system: Node
var _ship_id: String = ""
var _selected_slot: int = 0
var _panel: PanelContainer
var _title: Label
var _slot_list: VBoxContainer
var _shop_list: VBoxContainer
var _storage_list: VBoxContainer
var _ship_name: Label
var _ship_stats: Label
var _selected_details: Label
var _selected_actions: HBoxContainer
var _notice: Label
var _preview_viewport: SubViewport
var _preview_root: Node3D
var _preview_model: Node3D
var _money: Label
var _class_filter: OptionButton
var _compatible_filter: CheckButton
var _selected_progress: ProgressBar
var _preview_container: SubViewportContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme=preload("res://systems/ui/game_ui_theme.gd").new().get_theme()
	visibility_changed.connect(_sync_preview_visibility)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new()
	shade.color=Color(0.005,0.015,0.025,.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_panel=PanelContainer.new()
	_panel.size=Vector2(1220,700)
	var panel_style:=StyleBoxFlat.new()
	panel_style.bg_color=Color(0.025,0.055,0.075,.99)
	panel_style.border_color=Color("b89144")
	panel_style.set_border_width_all(3)
	panel_style.corner_radius_top_left=8; panel_style.corner_radius_top_right=8
	panel_style.corner_radius_bottom_left=8; panel_style.corner_radius_bottom_right=8
	panel_style.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel",panel_style)
	add_child(_panel)
	var root:=VBoxContainer.new()
	root.add_theme_constant_override("separation",10)
	_panel.add_child(root)
	var header:=HBoxContainer.new()
	header.add_theme_constant_override("separation",10)
	root.add_child(header)
	_title=Label.new()
	_title.text="КОРАБЕЛЬНОЕ ВООРУЖЕНИЕ"
	_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_title.clip_text=true
	_title.add_theme_font_size_override("font_size",20)
	_title.add_theme_color_override("font_color",Color("f0d58d"))
	header.add_child(_title)
	_money=Label.new()
	_money.add_theme_font_size_override("font_size",14)
	_money.add_theme_color_override("font_color",Color("f0d58d"))
	header.add_child(_money)
	var close:=Button.new()
	preload("res://systems/ui/brass_close_button.gd").apply(close)
	close.tooltip_text="Закрыть вооружение"
	close.pressed.connect(_close)
	header.add_child(close)
	var content:=HBoxContainer.new()
	content.size_flags_vertical=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12)
	root.add_child(content)
	_slot_list=_column_panel(content,"ТОЧКИ УСТАНОВКИ",230)
	var center:=_column_panel(content,"ВЫБРАННЫЙ КОРАБЛЬ",0)
	center.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
	center.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_ship_name=Label.new(); _ship_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; _ship_name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; _ship_name.add_theme_font_size_override("font_size",16); center.add_child(_ship_name)
	_create_preview(center)
	_ship_stats=Label.new(); _ship_stats.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; _ship_stats.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; _ship_stats.add_theme_font_size_override("font_size",12); center.add_child(_ship_stats)
	_selected_details=Label.new(); _selected_details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; _selected_details.add_theme_font_size_override("font_size",12); center.add_child(_selected_details)
	_selected_progress=ProgressBar.new(); _selected_progress.custom_minimum_size.y=16; _selected_progress.show_percentage=false; center.add_child(_selected_progress)
	_selected_actions=HBoxContainer.new(); _selected_actions.add_theme_constant_override("separation",6); center.add_child(_selected_actions)
	_notice=Label.new(); _notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; _notice.add_theme_font_size_override("font_size",13); _notice.add_theme_color_override("font_color",Color("7ee5dd")); center.add_child(_notice)
	var market:=VBoxContainer.new()
	market.custom_minimum_size.x=320
	market.size_flags_vertical=Control.SIZE_EXPAND_FILL
	content.add_child(market)
	var filters:=HBoxContainer.new()
	filters.add_theme_constant_override("separation",6)
	market.add_child(filters)
	_class_filter=OptionButton.new()
	_class_filter.add_item("Все классы")
	for value in range(1,6): _class_filter.add_item("Класс %d" % value)
	_class_filter.add_theme_font_size_override("font_size",12)
	_class_filter.item_selected.connect(func(_index: int): _refresh_shop(_system.ship_by_id(_ship_id)))
	filters.add_child(_class_filter)
	_compatible_filter=CheckButton.new()
	_compatible_filter.text="Для слота"
	_compatible_filter.add_theme_font_size_override("font_size",12)
	_compatible_filter.tooltip_text="Показать только орудия, подходящие выбранной точке и уровню корабля."
	_compatible_filter.toggled.connect(func(_pressed: bool): _refresh_shop(_system.ship_by_id(_ship_id)))
	filters.add_child(_compatible_filter)
	var tabs:=TabContainer.new()
	tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL
	market.add_child(tabs)
	_shop_list=_tab_list(tabs,"МАГАЗИН")
	_storage_list=_tab_list(tabs,"СКЛАД")
	hide()

func _column_panel(parent: Control, heading: String, width: float) -> VBoxContainer:
	var panel:=PanelContainer.new()
	if width>0: panel.custom_minimum_size.x=width
	panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var style:=StyleBoxFlat.new()
	style.bg_color=Color(0.04,0.075,0.095,.98)
	style.border_color=Color(0.34,0.28,0.15,1)
	style.set_border_width_all(1); style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	var column:=VBoxContainer.new(); column.add_theme_constant_override("separation",8); panel.add_child(column)
	var title:=Label.new(); title.text=heading; title.add_theme_font_size_override("font_size",16); title.add_theme_color_override("font_color",Color("d8bd72")); column.add_child(title)
	return column

func _tab_list(tabs: TabContainer, tab_name: String) -> VBoxContainer:
	var scroll:=ScrollContainer.new()
	scroll.name=tab_name
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var list:=VBoxContainer.new(); list.size_flags_horizontal=Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation",7); scroll.add_child(list)
	return list

func _create_preview(parent: Control) -> void:
	var container:=SubViewportContainer.new()
	_preview_container=container
	container.set_meta("armament_ship_preview",true)
	container.custom_minimum_size=Vector2(260,260)
	container.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	container.stretch=true
	parent.add_child(container)
	_preview_viewport=SubViewport.new()
	_preview_viewport.size=Vector2i(640,420)
	_preview_viewport.transparent_bg=true
	_preview_viewport.own_world_3d=true
	_preview_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	container.add_child(_preview_viewport)
	_preview_root=Node3D.new(); _preview_viewport.add_child(_preview_root)
	var camera:=Camera3D.new(); camera.position=Vector3(0,3.2,9.5); camera.fov=25; camera.current=true; _preview_root.add_child(camera); camera.look_at(Vector3(0,.8,0))
	var world:=WorldEnvironment.new()
	var environment:=Environment.new()
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("b8cfda")
	environment.ambient_light_energy=.6
	world.environment=environment
	_preview_root.add_child(world)
	var key:=DirectionalLight3D.new(); key.rotation_degrees=Vector3(-42,-32,0); key.light_energy=.9; key.shadow_enabled=false; _preview_root.add_child(key)
	var fill:=OmniLight3D.new(); fill.position=Vector3(-3,2,4); fill.light_color=Color("65d8e8"); fill.light_energy=.7; fill.omni_range=12; _preview_root.add_child(fill)

func _sync_preview_visibility() -> void:
	if _preview_viewport!=null:
		_preview_viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE if is_visible_in_tree() else SubViewport.UPDATE_DISABLED

func initialize(system: Node) -> void:
	_system=system

func open_ship(ship_id: String) -> void:
	_ship_id=ship_id
	_selected_slot=0
	_class_filter.select(0)
	_compatible_filter.set_pressed_no_signal(false)
	_notice.text="Выберите точку установки и орудие со склада."
	_refresh_preview()
	_refresh()
	show()

func _close() -> void:
	hide()
	closed.emit()

func _process(delta: float) -> void:
	if not visible: return
	var viewport_size: Vector2=get_viewport_rect().size
	_preview_container.custom_minimum_size.y=clampf(viewport_size.y*.33-40,130,260)
	_panel.size=Vector2(minf(1220,viewport_size.x-24),minf(700,viewport_size.y-24))
	_panel.position=(viewport_size-_panel.size)*.5
	if _preview_model!=null: _preview_model.rotate_y(delta*.18)

func _refresh_preview() -> void:
	if _preview_model!=null and is_instance_valid(_preview_model): _preview_model.queue_free()
	var ship: Dictionary=_system.ship_by_id(_ship_id) if _system!=null else {}
	if ship.is_empty(): return
	var definition: Dictionary=GameData.get_ship(str(ship.get("ship_type_id","")))
	_preview_model=preload("res://systems/rendering/naval_ship_factory.gd").new().attach(_preview_root,str(definition.get("id","")),6.8,false,str(definition.get("faction_id","")))
	if _preview_model!=null:
		_preview_model.position=Vector3(0,0,0)
		_preview_model.rotation_degrees=Vector3(0,-18,0)

func _clear(list: VBoxContainer) -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()

func _refresh() -> void:
	if _system==null: return
	var ship: Dictionary=_system.ship_by_id(_ship_id)
	if ship.is_empty(): _notice.text="Корабль недоступен."; return
	_system.normalize_ship(ship)
	var definition: Dictionary=GameData.get_ship(str(ship.get("ship_type_id","")))
	_title.text="ВООРУЖЕНИЕ · %s" % str(ship.get("name","Корабль"))
	_money.text="Монеты: %s" % str(int(GameState.player_state.money))
	_ship_name.text=str(definition.get("name",ship.get("name","Корабль"))).to_upper()
	_ship_stats.text="Проект %d · уровень %d/30 · допуск вооружения: класс %d\nКорпус %.0f/%.0f · орудий %d/%d · %s" % [int(definition.get("tier",1)),int(ship.get("level",1)),_system.ship_gun_class_cap(ship),float(ship.get("hull",0)),_system.hull_max(ship),_installed_count(ship),ship.guns.size(),_next_class_hint(ship)]
	_ship_stats.tooltip_text="Проект I: 2 точки · II: 3 · III: 4 · IV: 6 · V: 8.\nУровни 1–9: класс проекта; 10–19: +1 класс; 20–30: +2.\nМаксимальный класс — V. Поздние орудия требуют дополнительного уровня."
	_refresh_slots(ship)
	_refresh_selected(ship)
	_refresh_shop(ship)
	_refresh_storage(ship)

func _installed_count(ship: Dictionary) -> int:
	var count:=0
	for gun in ship.get("guns",[]):
		if not gun.is_empty(): count+=1
	return count

func _next_class_hint(ship: Dictionary) -> String:
	var level: int=int(ship.get("level",1))
	if _system.ship_gun_class_cap(ship)>=5: return "достигнут максимальный класс"
	if level<10: return "следующий класс на уровне 10"
	if level<20: return "следующий класс на уровне 20"
	return "предел проекта достигнут"

func _refresh_slots(ship: Dictionary) -> void:
	_clear(_slot_list)
	var heading:=Label.new(); heading.text="ТОЧКИ УСТАНОВКИ"; heading.add_theme_font_size_override("font_size",16); heading.add_theme_color_override("font_color",Color("d8bd72")); _slot_list.add_child(heading)
	for mount in ["bow","stern","port","starboard"]:
		var mount_title:=Label.new(); mount_title.text=_system.gun_mount_name(mount).to_upper(); mount_title.add_theme_font_size_override("font_size",13); _slot_list.add_child(mount_title)
		var found:=false
		for index in ship.guns.size():
			if _system.gun_slot_mount(ship,index)!=mount: continue
			found=true
			var gun: Dictionary=ship.guns[index]
			var definition: Dictionary=_system._rules.guns.get(str(gun.get("kind","")),{})
			var button:=Button.new()
			button.set_meta("armament_slot",index)
			button.text="%s %d · %s" % [_system.gun_mount_name(mount),index+1,"ПУСТО" if gun.is_empty() else str(definition.get("name",gun.get("kind","")))]
			button.add_theme_font_size_override("font_size",12)
			button.clip_text=true
			button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
			button.tooltip_text="%s\nСектор огня: %s" % [button.text,_system.gun_mount_name(mount)]
			button.toggle_mode=true
			button.button_pressed=index==_selected_slot
			button.pressed.connect(_select_slot.bind(index))
			_slot_list.add_child(button)
		if not found:
			var absent:=Label.new(); absent.text="— нет точки установки"; absent.add_theme_font_size_override("font_size",11); _slot_list.add_child(absent)

func _select_slot(index: int) -> void:
	_selected_slot=index
	_refresh()

func _refresh_selected(ship: Dictionary) -> void:
	for child in _selected_actions.get_children():
		_selected_actions.remove_child(child)
		child.queue_free()
	var mount: String=_system.gun_slot_mount(ship,_selected_slot)
	var gun: Dictionary=ship.guns[_selected_slot] if _selected_slot>=0 and _selected_slot<ship.guns.size() else {}
	if gun.is_empty():
		_selected_progress.hide()
		_selected_details.text="ВЫБРАНО: %s · слот %d\nСвободная точка. Купите орудие в магазине, затем установите его со склада." % [_system.gun_mount_name(mount),_selected_slot+1]
		return
	var definition: Dictionary=_system._rules.guns.get(str(gun.kind),{})
	var stats: Dictionary=_system.gun_combat_stats(ship,gun)
	var xp: int=int(gun.get("level",1))*int(_system._rules.gun_level_xp)
	var cost: int=int(gun.get("level",1))*int(_system._rules.gun_level_cost)
	_selected_details.text="%s · слот %d\n%s · %d мм · ур. %d\nУрон %.1f · дальность %.0f · заряд %.1f с · точность %d%%\nОпыт %d/%d · предел командира: ур. %d" % [_system.gun_mount_name(mount),_selected_slot+1,str(definition.get("name",gun.kind)),int(definition.get("caliber_mm",0)),int(gun.get("level",1)),float(stats.damage),float(stats.range),float(stats.reload),roundi(float(stats.accuracy)*100),int(gun.get("experience",0)),xp,_system.gun_level_cap(ship,gun)]
	_selected_details.tooltip_text="Характеристики учитывают уровень орудия и навыки назначенного командира."
	_selected_progress.show()
	_selected_progress.max_value=xp
	_selected_progress.value=mini(xp,int(gun.get("experience",0)))
	var upgrade:=_button(_selected_actions,"Улучшить · %d" % cost,func(): return _system.upgrade_gun(_ship_id,_selected_slot))
	var status: Dictionary=_system.gun_upgrade_status(_ship_id,_selected_slot)
	upgrade.disabled=not bool(status.ok)
	upgrade.tooltip_text=str(status.message)
	var remove:=_button(_selected_actions,"На склад",func(): return _system.remove_gun(_ship_id,_selected_slot))
	remove.disabled=GameState.combat_state.naval_arsenal.size()>=_system.arsenal_capacity()
	remove.tooltip_text="Склад заполнен." if remove.disabled else "Снять орудие с сохранением уровня и опыта."

func _refresh_shop(ship: Dictionary) -> void:
	_clear(_shop_list)
	var inventory: Array=GameState.combat_state.get("naval_arsenal",[])
	var capacity:=Label.new(); capacity.text="Склад после покупки: %d / %d" % [inventory.size(),_system.arsenal_capacity()]; capacity.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; capacity.add_theme_font_size_override("font_size",13); _shop_list.add_child(capacity)
	var kinds: Array=_system._rules.guns.keys(); kinds.sort_custom(func(a,b): return int(_system._rules.guns[a].cost)<int(_system._rules.guns[b].cost))
	var shown: int=0
	for raw_kind in kinds:
		var kind: String=str(raw_kind)
		var definition: Dictionary=_system._rules.guns[kind]
		if _class_filter.selected>0 and int(definition.get("weight_class",1))!=_class_filter.selected: continue
		var compatibility: Dictionary=_system.gun_install_status(ship,_selected_slot,kind)
		if _compatible_filter.button_pressed and not bool(compatibility.ok): continue
		shown+=1
		var row:=_gun_row(_shop_list,definition)
		var copy:=row.get_meta("copy") as VBoxContainer
		var stats:=Label.new(); stats.text="Класс %d · корабль ур. %d · %d мм\nУрон %.0f · дальность %.0f · перезарядка %.0f с\n%s" % [int(definition.get("weight_class",1)),int(definition.get("min_ship_level",1)),int(definition.get("caliber_mm",0)),float(definition.damage),float(definition.range),float(definition.reload),str(definition.get("description",""))]; stats.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; stats.add_theme_font_size_override("font_size",11); copy.add_child(stats)
		var eligibility:=Label.new()
		eligibility.text="Подходит выбранному слоту" if bool(compatibility.ok) else str(compatibility.message)
		eligibility.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		eligibility.add_theme_font_size_override("font_size",11)
		eligibility.add_theme_color_override("font_color",Color("7ee1c3") if bool(compatibility.ok) else Color("d4a677"))
		copy.add_child(eligibility)
		var buy:=_button(copy,"Купить · %d" % int(definition.cost),func(): return _system.buy_gun(_ship_id,kind))
		buy.set_meta("armament_buy",kind)
		buy.disabled=float(GameState.player_state.money)<float(definition.cost) or inventory.size()>=_system.arsenal_capacity()
		buy.tooltip_text="Склад заполнен." if inventory.size()>=_system.arsenal_capacity() else ("Не хватает монет." if buy.disabled else ("Купить на склад для будущего оснащения." if not bool(compatibility.ok) else "Купить на склад."))
	if shown==0:
		var empty:=Label.new(); empty.text="Нет орудий для этого класса и слота. Измените фильтры."; empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; empty.add_theme_font_size_override("font_size",12); _shop_list.add_child(empty)

func _refresh_storage(ship: Dictionary) -> void:
	_clear(_storage_list)
	var inventory: Array=GameState.combat_state.get("naval_arsenal",[])
	var capacity:=Label.new(); capacity.text="СКЛАД ОРУДИЙ · %d / %d" % [inventory.size(),_system.arsenal_capacity()]; capacity.add_theme_font_size_override("font_size",15); _storage_list.add_child(capacity)
	_button(_storage_list,"Расширить на %d мест · %d монет" % [int(_system._rules.get("arsenal_expansion_size",5)),_system.arsenal_expansion_cost()],func(): return _system.expand_arsenal(_ship_id))
	if inventory.is_empty():
		var empty:=Label.new(); empty.text="Склад пуст. Купленные орудия появятся здесь."; empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; _storage_list.add_child(empty); return
	for index in inventory.size():
		var gun: Dictionary=inventory[index]
		var definition: Dictionary=_system._rules.guns.get(str(gun.get("kind","")),{})
		var row:=_gun_row(_storage_list,definition)
		var copy:=row.get_meta("copy") as VBoxContainer
		var progress:=Label.new(); progress.text="Уровень %d · опыт %d" % [int(gun.get("level",1)),int(gun.get("experience",0))]; progress.add_theme_font_size_override("font_size",12); copy.add_child(progress)
		var mount_status: Dictionary=_system.gun_install_status(ship,_selected_slot,str(gun.get("kind","")))
		var install:=_button(copy,"Установить в выбранный слот",func(): return _system.install_gun(_ship_id,_selected_slot,"",index))
		install.disabled=not bool(mount_status.ok) or not ship.guns[_selected_slot].is_empty()
		install.tooltip_text="Сначала снимите установленное орудие." if not ship.guns[_selected_slot].is_empty() else str(mount_status.message)
		install.set_meta("armament_install",index)
		var explanation:=Label.new(); explanation.text=install.tooltip_text; explanation.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; explanation.add_theme_font_size_override("font_size",11); copy.add_child(explanation)
		var refund: int=int(floor(float(definition.get("cost",0))*float(_system._rules.get("gun_sell_fraction",.5))))
		_button(copy,"Продать · %d монет" % refund,func(): return _system.sell_arsenal_gun(_ship_id,index))

func _gun_row(parent: VBoxContainer, definition: Dictionary) -> HBoxContainer:
	var panel:=PanelContainer.new()
	var style:=StyleBoxFlat.new()
	style.bg_color=Color(0.055,0.085,0.105,1)
	style.border_color=Color(0.32,0.27,0.16,1)
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	panel.add_child(row)
	var icon:=TextureRect.new()
	var path: String=str(definition.get("icon",""))
	if path!="" and ResourceLoader.exists(path): icon.texture=load(path) as Texture2D
	icon.custom_minimum_size=Vector2(86,58)
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var copy:=VBoxContainer.new()
	copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	row.set_meta("copy",copy)
	var name:=Label.new()
	name.text=str(definition.get("name","Орудие"))
	name.add_theme_color_override("font_color",Color("ebd18b"))
	name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(name)
	return row

func _button(parent: Control, text_value: String, callback: Callable) -> Button:
	var button:=Button.new(); button.text=text_value; button.custom_minimum_size.y=32; button.add_theme_font_size_override("font_size",12); button.pressed.connect(_action.bind(callback)); parent.add_child(button); return button

func _action(callback: Callable) -> void:
	var result: Dictionary=callback.call()
	_notice.text=str(result.get("message",""))
	_refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()
