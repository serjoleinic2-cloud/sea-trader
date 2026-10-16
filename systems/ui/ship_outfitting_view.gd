extends HBoxContainer

const Loadout = preload("res://systems/fleet/ship_loadout.gd")
const Art = preload("res://systems/characters/character_art_catalog.gd")
const GUN_ART_ATLAS_PATH := "res://assets/ui/naval_guns/naval_gun_atlas.png"
const GUN_ART_CELLS := {"cannon":0,"rune":1,"heavy_cannon":2,"long_cannon":3,"mortar":4,"heavy_rune":5,"swivel_cannon":6,"deck_mortar":7,"focused_rune":8,"piercing_cannon":9,"bombard":10,"siege_mortar":11,"storm_rune":12,"dread_cannon":13,"void_mortar":14,"leviathan_rune":15}
var _ship_id := ""
var _crew: VBoxContainer
var _right: VBoxContainer
var _preview: Control
var _bars: Control
var _title: Label
var _notice: Label
var _picker: Control
var _choices: VBoxContainer
var _picker_notice: Label
var _timer_labels: Array[Label] = []
var _gun_art_atlas: Texture2D
var _comparison: Dictionary = {}
var _signature := ""
var _stats_signature := ""
var _tick := 0.0

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",16)
	_crew = _side("ЭКИПАЖ",232)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.size_flags_stretch_ratio = 1.5
	center.add_theme_constant_override("separation",2)
	add_child(center)
	_title = _label("",15)
	center.add_child(_title)
	_preview = preload("res://systems/ui/ship_preview.gd").new()
	center.add_child(_preview)
	_preview.custom_minimum_size = Vector2(260,200)
	var hint: Label = _label("Мышь — вращение · колесо — масштаб",10)
	center.add_child(hint)
	_bars = preload("res://systems/ui/ship_stat_bars.gd").new()
	center.add_child(_bars)
	_notice = _label("Ячейка → выбор сотрудника, орудия или свитка. Зелёное — улучшение, красное — ухудшение.",11)
	center.add_child(_notice)
	_right = _side("ОСНАЩЕНИЕ",330)
	if ResourceLoader.exists(GUN_ART_ATLAS_PATH): _gun_art_atlas=load(GUN_ART_ATLAS_PATH) as Texture2D
	_picker = Control.new()
	_picker.name = "LoadoutPicker"
	_picker.set_as_top_level(true)
	_picker.z_index = 4095
	_picker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_picker)
	_picker.hide()

func _label(text: String, font_size: int = 12) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.set_meta("fixed_font_size",font_size)
	label.add_theme_font_size_override("font_size",font_size)
	return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.custom_minimum_size.y = 30
	button.set_meta("compact_description",true)
	button.set_meta("ui_base_font_size",11)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _side(title: String, width: float) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = width
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(column)
	column.add_child(_label(title,14))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",8)
	scroll.add_child(content)
	return content

func _clear(parent: Node) -> void:
	for child in parent.get_children(): parent.remove_child(child); child.queue_free()

func open_ship(id: String) -> void:
	if _ship_id != id:
		_ship_id=id; _comparison={}; _signature=""; _picker.hide()
	var ship: Dictionary = Loadout.vessel(id)
	var equipment: Array = []
	for gun in ship.get("guns",[]): equipment.append([gun.get("kind",""),gun.get("level",0)])
	var current_signature: String = str(hash([id,ship.get("crew",[]),equipment,ship.get("commander",{}).get("skills",{}),GameState.employee_state,_boost_state()]))
	if current_signature != _signature:
		_signature=current_signature
		_refresh()

func _navy() -> Node:
	return get_tree().get_first_node_in_group("naval_combat_system")

func _rewards() -> Node:
	return get_tree().get_first_node_in_group("reward_system")

func _boost_state() -> Array:
	var result: Array=[]
	for boost in Loadout.boost_slots(Loadout.vessel(_ship_id)):
		result.append([str(boost.get("id","")),float(boost.get("seconds_remaining",0))>0])
	return result

func _refresh() -> void:
	_clear(_crew); _clear(_right); _timer_labels.clear()
	var ship: Dictionary = Loadout.vessel(_ship_id)
	var definition: Dictionary = Loadout.definition(ship)
	_title.text = str(ship.get("name",definition.get("name","Корабль")))
	_preview.show_ship(str(definition.get("id","ship_sloop")))
	var roles: Dictionary = GameData.read("res://data/employees/hiring_rules.json").get("roles",{})
	for slot in Loadout.crew_slots(_ship_id):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",8)
		_crew.add_child(row)
		var person: Dictionary = slot.person
		var button: Button = _button(row,"+" if person.is_empty() else "",_open_crew.bind(str(slot.key)))
		button.name="CrewSlot_"+str(slot.key)
		button.set_meta("selection_card",true)
		button.custom_minimum_size = Vector2(64,68)
		button.tooltip_text="Нанять или назначить: "+str(roles.get(str(slot.role),{}).get("name",slot.role))
		if bool(slot.get("player",false)):
			button.text=""; button.disabled=true; _slot_image(button,GameData.get_faction_portrait(str(GameState.player_state.get("origin_race_id","humans")))); button.tooltip_text="Здесь ваш капитан; его облик и личность сохраняются."
		elif not person.is_empty(): _portrait_button(button,person)
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(copy)
		copy.add_child(_label(str(roles.get(str(slot.role),{}).get("name",slot.role)) + (" · вы" if bool(slot.get("player",false)) else ""),11))
		copy.add_child(_label(str(person.get("name","Свободная ячейка")) if not bool(slot.get("player",false)) else "Капитан игрока",10))
	_right.add_child(_label("ВРЕМЕННЫЕ СВИТКИ · 4 ЯЧЕЙКИ",12))
	var boost_row := HBoxContainer.new()
	boost_row.add_theme_constant_override("separation",6)
	_right.add_child(boost_row)
	var slots: Array = Loadout.boost_slots(ship)
	for index in 4:
		var column := VBoxContainer.new()
		boost_row.add_child(column)
		var active: Dictionary=slots[index]
		var definition_boost: Dictionary=Loadout.boost_catalog().get(str(active.get("id","")),{})
		var button: Button=_button(column,"+",_open_boost.bind(index))
		button.name="BoostSlot_%d" % index
		button.set_meta("selection_card",true)
		button.custom_minimum_size=Vector2(68,64)
		if float(active.get("seconds_remaining",0))>0:
			button.text=""
			var path: String=str(definition_boost.get("icon",""))
			if ResourceLoader.exists(path): _slot_image(button,load(path))
			button.tooltip_text=str(definition_boost.get("name","Свиток"))
		var timer: Label=_label("",9)
		timer.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(timer); _timer_labels.append(timer)
	_right.add_child(_label("Время идёт в игре. Свиток обучения сюда не ставится.",10))
	if bool(definition.get("warship",false)) and _navy()!=null:
		var navy: Node=_navy()
		navy.normalize_ship(ship)
		var layout: Array=navy.gun_slot_layout(ship)
		for group in [["Носовые орудия",["bow"]],["Бортовые орудия",["port","starboard"]],["Кормовые орудия",["stern"]]]:
			_right.add_child(_label(str(group[0]),12))
			var row := HFlowContainer.new()
			row.add_theme_constant_override("h_separation",5)
			_right.add_child(row)
			var count: int=0
			for index in layout.size():
				if not group[1].has(layout[index]): continue
				count+=1
				var gun: Dictionary=ship.guns[index]
				var gun_definition: Dictionary=navy._rules.guns.get(str(gun.get("kind","")),{})
				var caption: String=("Л" if str(layout[index])=="port" else "П") if str(layout[index]) in ["port","starboard"] else str(index+1)
				var cell:=VBoxContainer.new()
				cell.custom_minimum_size.x=72
				cell.add_theme_constant_override("separation",2)
				row.add_child(cell)
				var button: Button=_button(cell,"",_open_gun.bind(index))
				button.name="GunSlot_%d" % index
				button.custom_minimum_size=Vector2(68,54)
				var weapon_id:String=str(gun.get("kind","cannon")) if not gun.is_empty() else "cannon"
				var texture:Texture2D=_gun_texture(weapon_id)
				if texture!=null: _slot_image(button,texture)
				var slot_caption:String=caption+" · "+(str(gun_definition.get("caliber_mm",0))+" мм" if not gun.is_empty() else "Свободно")
				var caption_label:Label=_label(slot_caption,9)
				caption_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
				cell.add_child(caption_label)
				button.tooltip_text=navy.gun_mount_name(str(layout[index]))+" · "+str(gun_definition.get("name","Свободная ячейка"))
			if count==0:
				var empty: Label=_label("Нет точек установки",10)
				empty.custom_minimum_size.x=260
				row.add_child(empty)
	_refresh_stats()
	_update_timers()

func _slot_image(button: Button, texture: Texture2D) -> void:
	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left=7;art.offset_right=-7;art.offset_top=7;art.offset_bottom=-7
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	art.texture=texture
	button.add_child(art)

func _gun_texture(weapon_id: String) -> Texture2D:
	if _gun_art_atlas==null or not GUN_ART_CELLS.has(weapon_id): return null
	var cell:int=int(GUN_ART_CELLS[weapon_id])
	var width:float=float(_gun_art_atlas.get_width())/4.0
	var height:float=float(_gun_art_atlas.get_height())/4.0
	var art:=AtlasTexture.new()
	art.atlas=_gun_art_atlas
	art.region=Rect2(Vector2(float(cell%4)*width,floori(float(cell)/4.0)*height),Vector2(width,height))
	return art

func _portrait_button(button: Button, person: Dictionary) -> void:
	_slot_image(button,Art.ship_officer_portrait(str(person.get("race_id","humans")),str(person.get("role_id","captain")),int(person.get("portrait_id",0)),load("res://assets/characters/crew/crew_portrait_atlas.png")))


func _refresh_stats() -> void:
	var rows: Array=Loadout.statistics(_ship_id,_navy())
	var signature: String=str(hash([rows,_comparison]))
	if signature==_stats_signature: return
	_stats_signature=signature
	_bars.display(rows,_comparison)

func _begin_change() -> void:
	_comparison={}
	for row in Loadout.statistics(_ship_id,_navy()): _comparison[str(row.id)]=float(row.value)

func _done(result: Dictionary) -> void:
	_notice.text=str(result.get("message",""))
	if bool(result.get("ok",false)):
		_picker.hide(); _signature=""; open_ship(_ship_id)
	elif is_instance_valid(_picker_notice):
		_picker_notice.text=_notice.text
		_picker_notice.show()

func _show_picker(title: String) -> void:
	_clear(_picker)
	_picker.position=Vector2.ZERO; _picker.size=get_viewport().get_visible_rect().size
	var shade:=ColorRect.new()
	shade.color=Color(0,0.01,0.02,0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picker.add_child(shade)
	var panel:=PanelContainer.new()
	panel.theme=preload("res://systems/ui/game_ui_theme.gd").new().get_theme()
	var screen:Vector2=_picker.size
	var top:float=preload("res://systems/ui/workspace_layout.gd").safe_top(get_tree())
	panel.position=Vector2(maxf(12,(screen.x-700)*0.5),top+12)
	panel.size=Vector2(minf(700,screen.x-24),screen.y-top-24)
	_picker.add_child(panel)
	var margin:=MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
	panel.add_child(margin)
	var column:=VBoxContainer.new()
	margin.add_child(column)
	var header:=HBoxContainer.new()
	column.add_child(header)
	var label:Label=_label(title,16); label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.add_child(label)
	var close:Button=_button(header,"×",func():_picker.hide())
	preload("res://systems/ui/brass_close_button.gd").apply(close)
	_picker_notice=_label("",12)
	_picker_notice.add_theme_color_override("font_color",Color("ee987e"))
	column.add_child(_picker_notice)
	_picker_notice.hide()
	var scroll:=ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_choices=VBoxContainer.new()
	_choices.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_choices.add_theme_constant_override("separation",10)
	scroll.add_child(_choices)
	_picker.show()

func _open_crew(key: String) -> void:
	var slot:Dictionary={}
	for item in Loadout.crew_slots(_ship_id):
		if str(item.key)==key: slot=item
	if slot.is_empty(): return
	_show_picker("ЭКИПАЖ · "+str(GameData.read("res://data/employees/hiring_rules.json").get("roles",{}).get(str(slot.role),{}).get("name",slot.role)))
	var service=Loadout.new(get_tree())
	var status:Dictionary=Loadout.management_status(_ship_id)
	if not bool(status.ok): _choices.add_child(_label(str(status.message))); return
	if not slot.person.is_empty():
		_button(_choices,"Снять в резерв компании",func():_begin_change(); _done(service.remove_crew(_ship_id,key)))
		var commander:Dictionary=Loadout.vessel(_ship_id).get("commander",{})
		if str(slot.role)=="captain" and not commander.is_empty() and _navy()!=null:
			_choices.add_child(_label("Навыки командира · свободных очков %d"%int(commander.get("skill_points",0)),12))
			for skill in [["gunnery","Мощность залпа"],["accuracy","Точность"],["reload","Перезарядка"]]:
				var upgrade:Button=_button(_choices,"%s · %d  +"%[str(skill[1]),int(commander.get("skills",{}).get(skill[0],0))],func():_begin_change();_done(_navy().train_skill(_ship_id,str(skill[0]))))
				upgrade.disabled=int(commander.get("skill_points",0))<=0
	for person in GameState.employee_state:
		if str(person.get("assigned_to",""))!="reserve" or str(person.get("role_id",""))!=str(slot.role) or str(person.get("race_id",""))!=str(GameState.player_state.get("origin_race_id","humans")): continue
		var row:HBoxContainer=_person_row(person)
		_button(row,"Назначить из резерва",func():_begin_change();_done(service.assign_reserve(_ship_id,key,str(person.employee_instance_id))))
	_choices.add_child(_label("Кандидаты вашей расы · найм навсегда",13))
	for person in service.candidates(str(slot.role)):
		var row:HBoxContainer=_person_row(person)
		_button(row,"Нанять · %d" % int(person.get("hire_price",0)),func():_begin_change();_done(service.hire_into_slot(_ship_id,key,str(person.candidate_id))))
	_button(_choices,"Обновить кандидатов",func():get_tree().get_first_node_in_group("hiring_system").refresh_candidates();_open_crew(key))

func _person_row(person: Dictionary) -> HBoxContainer:
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	_choices.add_child(row)
	var portrait:=TextureRect.new()
	portrait.custom_minimum_size=Vector2(78,88)
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture=Art.ship_officer_portrait(str(person.get("race_id","humans")),str(person.get("role_id","captain")),int(person.get("portrait_id",0)),load("res://assets/characters/crew/crew_portrait_atlas.png"))
	row.add_child(portrait)
	var info:=VBoxContainer.new(); info.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(info)
	info.add_child(_label(str(person.get("name","Сотрудник")),13))
	var details:Array[String]=[]
	var labels:Dictionary=GameData.read("res://data/employees/hiring_rules.json").get("stat_labels",{})
	for stat in person.get("stats",{}): details.append("%s %+.1f%%" % [str(labels.get(stat,stat)),float(person.stats[stat])+float(person.get("skill_stats",{}).get(stat,0))])
	info.add_child(_label(" · ".join(details),10))
	return row

func _open_boost(slot: int) -> void:
	_show_picker("ВРЕМЕННЫЙ СВИТОК · ЯЧЕЙКА %d" % (slot+1))
	var rewards:Node=_rewards()
	if rewards==null: return
	var ship:Dictionary=Loadout.vessel(_ship_id)
	var active:Dictionary=Loadout.boost_slots(ship)[slot]
	if float(active.get("seconds_remaining",0))>0:
		_choices.add_child(_label("Свиток уже действует. Его нельзя снять для сброса таймера; дождитесь окончания."));return
	for id in Loadout.boost_catalog():
		var spec:Dictionary=Loadout.boost_catalog()[id]
		if str(spec.stat) in ["damage","reload","accuracy"] and not bool(Loadout.definition(ship).get("warship",false)): continue
		var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);_choices.add_child(row)
		var icon:=TextureRect.new();icon.custom_minimum_size=Vector2(68,76);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists(str(spec.get("icon",""))):icon.texture=load(str(spec.icon))
		row.add_child(icon)
		var effect:String={"speed":"Скорость","fuel":"Расход топлива","damage":"Урон","reload":"Перезарядка","accuracy":"Точность"}.get(str(spec.stat),str(spec.stat))
		var percent:float=float(spec.percent)*(-1.0 if str(spec.stat) in ["fuel","reload"] else 1.0)
		var text:Label=_label("%s\n%s %+.0f%% · %d мин" % [str(spec.name),effect,percent,int(float(spec.duration_seconds)/60.0)],11);text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(text)
		var count:int=int(rewards.get_state().get("boosts",{}).get(id,0))
		if count>0:_button(row,"Из запаса · %d"%count,func():_begin_change();_done(rewards.equip_ship_boost(_ship_id,slot,str(id))))
		else:_button(row,"Купить · %d"%int(spec.get("price",0)),func():_begin_change();_done(rewards.equip_ship_boost(_ship_id,slot,str(id),true)))

func _open_gun(slot: int) -> void:
	var navy:Node=_navy()
	if navy==null:return
	var ship:Dictionary=Loadout.vessel(_ship_id)
	_show_picker("ОРУДИЯ · "+navy.gun_mount_name(navy.gun_slot_mount(ship,slot)))
	var status:Dictionary=navy.management_status(_ship_id)
	if not bool(status.ok):_choices.add_child(_label(str(status.message)));return
	_choices.add_child(_label("Склад орудий: %d / %d"%[GameState.combat_state.get("naval_arsenal",[]).size(),navy.arsenal_capacity()],12))
	_button(_choices,"Расширить склад · %d"%navy.arsenal_expansion_cost(),func():_begin_change();_done(navy.expand_arsenal(_ship_id)))
	if not ship.guns[slot].is_empty():
		_button(_choices,"Снять на склад",func():_begin_change();_done(navy.remove_gun(_ship_id,slot)))
		_button(_choices,"Улучшить орудие",func():_begin_change();_done(navy.upgrade_gun(_ship_id,slot)))
		_choices.add_child(_label("Для замены сначала снимите орудие: оно останется на складе."));return
	for index in GameState.combat_state.get("naval_arsenal",[]).size():
		var stored:Dictionary=GameState.combat_state.naval_arsenal[index]
		var spec:Dictionary=navy._rules.guns[str(stored.kind)]
		var stored_row:=HBoxContainer.new();stored_row.add_theme_constant_override("separation",8);_choices.add_child(stored_row)
		var stored_icon:=TextureRect.new();stored_icon.custom_minimum_size=Vector2(78,62);stored_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;stored_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;stored_icon.texture=_gun_texture(str(stored.get("kind","")));stored_row.add_child(stored_icon)
		var stored_info:=VBoxContainer.new();stored_info.size_flags_horizontal=Control.SIZE_EXPAND_FILL;stored_row.add_child(stored_info)
		stored_info.add_child(_label("%s · ур. %d"%[str(spec.name),int(stored.get("level",1))],11))
		var install:Button=_button(stored_info,"Установить со склада",func():_begin_change();_done(navy.install_gun(_ship_id,slot,"",index)))
		var compatibility:Dictionary=navy.gun_install_status(ship,slot,str(stored.get("kind","")))
		install.disabled=not bool(compatibility.ok);install.tooltip_text=str(compatibility.message)
		_button(stored_row,"Продать · %d"%int(float(spec.get("cost",0))*.5),func():_begin_change();_done(navy.sell_arsenal_gun(_ship_id,index)))
	for id in navy._rules.guns:
		var spec:Dictionary=navy._rules.guns[id]
		if not spec.get("mounts",[]).has(navy.gun_slot_mount(ship,slot)):continue
		var compatible:Dictionary=navy.gun_install_status(ship,slot,str(id))
		var buy_row:=HBoxContainer.new();buy_row.add_theme_constant_override("separation",8);_choices.add_child(buy_row)
		var gun_icon:=TextureRect.new();gun_icon.custom_minimum_size=Vector2(78,62);gun_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;gun_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;gun_icon.texture=_gun_texture(str(id));buy_row.add_child(gun_icon)
		var gun_info:=VBoxContainer.new();gun_info.size_flags_horizontal=Control.SIZE_EXPAND_FILL;buy_row.add_child(gun_info)
		gun_info.add_child(_label("%s · %d мм · ур. от %d"%[str(spec.name),int(spec.get("caliber_mm",0)),int(spec.get("min_ship_level",1))],11))
		gun_info.add_child(_label("Урон %.0f · дальность %.0f · перезарядка %.0f с"%[float(spec.damage),float(spec.range),float(spec.reload)],10))
		if not bool(compatible.ok): gun_info.add_child(_label(str(compatible.message),10))
		var buy:Button=_button(gun_info,"Купить и установить · %d"%int(spec.cost),func():_begin_change();_done(navy.install_gun(_ship_id,slot,str(id))))
		buy.disabled=not bool(compatible.ok) or float(GameState.player_state.money)<float(spec.cost)

func _update_timers() -> void:
	var slots:Array=Loadout.boost_slots(Loadout.vessel(_ship_id))
	for index in mini(_timer_labels.size(),4):
		var seconds:int=ceili(float(slots[index].get("seconds_remaining",0)))
		_timer_labels[index].text="%02d:%02d"%[int(seconds/60.0),seconds%60] if seconds>0 else "Свободно"

func _process(delta: float) -> void:
	if not is_visible_in_tree():_picker.hide();return
	_tick+=delta
	if _tick<0.25:return
	_tick=0
	open_ship(_ship_id);_refresh_stats();_update_timers()
