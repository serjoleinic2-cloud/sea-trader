extends Control

## Programmatic screen inspired by the approved composition. Only character
## portraits and canonical emblems are textures; every frame/stat is live UI.
const DESIGN := Vector2(1672,944)
const GROUPS := [["coast_guard","rune_spearman","stone_warden"],["crystal_mortar"],["wind_rider","storm_drake"]]
const UNIT_ART := ["coast_guard","crystal_mortar","wind_rider"]
const PORTRAIT_CATALOG_PATH := "res://data/combat/commander_portraits.json"
const CANDIDATE_NAMES := {
	"humans":[["Мара Торн","Эдрик Восс","Лина Фаррел"],["Анна Вейл","Дарен Кроу","Эва Морн"]],
	"nerids":[["Сирена Вальтэра","Найр Таласс","Лиара Вейн"],["Найра Тей","Кайрен Дол","Селлиа Мар" ]],
	"surr":[["Бранна Келл","Рагнар Келл","Кара Денн"],["Бранна Келл","Торек Вальд","Кара Денн"]],
	"meridians":[["Лиора Вейн","Орен Валлис","Мира Солен"],["Алира Нейт","Киран Восс","Сера Вейн"]],
	"aery":[["Элиан Саэр","Тарен Лиор","Ириэль Вей"],["Лиэн Раэ","Аэрон Таль","Фейра Ним"]],
	"crystari":[["Вейра Нокс","Тарен Нокс","Лисса Кварц"],["Вейра Нокс","Корн Тай","Дара Кристалл"]]
}
var owner_window: Node
var system: Node
var canvas: Control
var slot: int = 0
var role: int = 0
var _money: Label
var _summary: Label
var _hero: TextureRect
var _hero_emblem: TextureRect
var _hero_name: Label
var _hero_title: Label
var _profile_heading: Label
var _hero_frame: Panel
var _status: Label
var _description: Label
var _notice: Label
var _hire: Button
var _stats: Dictionary = {}
var _groups: Array = []
var _slots: Array = []
var _role_buttons: Array[Button] = []
var _candidate_cards: Array = []
var _candidate_heading: Label
var _candidate_refresh: Button
var _candidate_offers: Dictionary = {}
var _selected_candidate_indices: Dictionary = {}
var _previous_offer_orders: Dictionary = {}
var _portrait_catalog: Dictionary = {}
var _roll_serial: int = 0

class Backdrop extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,Vector2(1672,944)),Color("0a1b26"))
		for y in range(100,944,24):
			var points:=PackedVector2Array()
			for x in range(0,1680,24): points.append(Vector2(x,y+sin(x*.007+y*.03)*14))
			draw_polyline(points,Color(.12,.35,.4,.08),1)
		for x in range(36,1660,80):
			draw_line(Vector2(x,81),Vector2(x+18,63),Color("6e623f"),1)
			draw_line(Vector2(x+18,63),Vector2(x+36,81),Color("6e623f"),1)
		draw_line(Vector2(28,86),Vector2(1644,86),Color("b48e50"),2)
		draw_line(Vector2(28,710),Vector2(1644,710),Color("b48e50"),2)
		for radius in [180,205,225]: draw_arc(Vector2(840,364),radius,0,TAU,90,Color(.14,.52,.58,.25),2)

func _ready() -> void:
	mouse_filter=MOUSE_FILTER_STOP
	_portrait_catalog=GameData.read(PORTRAIT_CATALOG_PATH).get("portraits",{})
	var surround:=ColorRect.new(); surround.color=Color("07131c"); surround.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); surround.mouse_filter=MOUSE_FILTER_IGNORE; add_child(surround)
	canvas=Control.new(); canvas.size=DESIGN; add_child(canvas)
	var background:=Backdrop.new(); background.size=DESIGN; background.mouse_filter=MOUSE_FILTER_IGNORE; canvas.add_child(background)
	_button(Rect2(28,20,125,48),"НАЗАД",func(): owner_window._close())
	_label(Rect2(184,20,700,45),"КАЗАРМЫ · КОМАНДОВАНИЕ",30,Color("efdcac"))
	_money=_label(Rect2(1120,20,480,48),"",22,Color("edce80"))
	_label(Rect2(34,106,500,44),"ВАША АРМИЯ",26,Color("edce80"))
	_summary=_label(Rect2(34,144,510,55),"",19,Color("dce8e8"))
	for index in 3:
		var x: float = 34+index*170
		_frame(Rect2(x,214,158,285),false)
		_texture(Rect2(x+10,226,138,130),load("res://assets/characters/units/%s.webp" % UNIT_ART[index]) as Texture2D)
		var title:=_label(Rect2(x+8,357,142,28),["ПЕХОТА","ТЕХНИКА","ЛЕТУЧИЕ"][index],17,Color("edce80"))
		var count:=_label(Rect2(x+8,387,142,28),"",17,Color("e6eeee"))
		var attack:=_label(Rect2(x+8,420,142,22),"",12,Color("73e3d1"))
		var attack_bar:=_bar(Rect2(x+10,447,138,6),Color("4ccbb7"))
		var defense:=_label(Rect2(x+8,461,142,22),"",12,Color("8ed6f1"))
		var defense_bar:=_bar(Rect2(x+10,486,138,6),Color("61adce"))
		_button(Rect2(x,214,158,285),"",func(): owner_window._show_art_tab([1,3,2][index]),true)
		_groups.append({"count":count,"attack":attack,"defense":defense,"attack_bar":attack_bar,"defense_bar":defense_bar,"title":title})
	_label(Rect2(34,516,510,35),"КОМАНДНЫЕ СЛОТЫ · 2 / 2 ДОСТУПНЫ",19,Color("edce80"))
	for index in 2:
		var x: float = 34+index*255
		var frame:=_frame(Rect2(x,564,240,130),false)
		var portrait:=_texture(Rect2(x+10,574,78,78),null)
		var name_label:=_label(Rect2(x+98,573,132,45),"",16,Color("ede5cf"))
		var status_label:=_label(Rect2(x+98,625,132,66),"",13,Color("77e7cf"))
		_button(Rect2(x,564,240,130),"",func(): slot=index; role=index; _refresh_now(),true)
		_slots.append({"frame":frame,"portrait":portrait,"name":name_label,"status":status_label})
	_hero_frame=_frame(Rect2(588,139,502,548),true)
	_hero=_texture(Rect2(600,150,478,450),null)
	_hero.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero_emblem=_texture(Rect2(589,112,60,60),null)
	_status=_label(Rect2(671,116,392,42),"",20,Color("edce80"))
	_hero_name=_label(Rect2(596,609,484,37),"",25,Color("f0dfb0"))
	_hero_title=_label(Rect2(596,650,484,25),"",17,Color("a9dcda"))
	_profile_heading=_label(Rect2(1135,111,510,38),"ПРОФИЛЬ КОМАНДИРА",25,Color("edce80"))
	_description=_label(Rect2(1135,160,505,62),"",18,Color("d1e1df"))
	for i in 3:
		var y: float = 240+i*103
		_label(Rect2(1135,y,310,30),["АТАКА АРМИИ","ОБОРОНА АРМИИ","РАСХОДЫ НА ОБУЧЕНИЕ"][i],19,Color("d1e1df"))
		var value:=_label(Rect2(1460,y,165,36),"",26,Color("6fe7d1"))
		var bar:=_bar(Rect2(1137,y+51,475,15),Color("4bc6b6") if i<2 else Color("cd9970"))
		_stats[["attack","defense","expenses"][i]]={"label":value,"bar":bar}
	_role_buttons.append(_button(Rect2(1135,572,225,44),"Главный командир",func(): _select_command_slot(0)))
	_role_buttons.append(_button(Rect2(1375,572,250,44),"Заместитель",func(): _select_command_slot(1)))
	for role_button in _role_buttons: role_button.toggle_mode=true
	_candidate_refresh=_button(Rect2(1135,516,490,44),"СМЕНИТЬ КАНДИДАТА",_reroll_candidate)
	_hire=_button(Rect2(1135,633,490,54),"",_appoint)
	_candidate_heading=_label(Rect2(34,714,1604,22),"КАНДИДАТЫ ВАШЕЙ РАСЫ",16,Color("edce80"))
	for index in 3:
		var x: float = 264+index*389
		var frame:=_frame(Rect2(x,738,365,170),false)
		var portrait:=_texture(Rect2(x+12,748,112,112),null)
		var name_label:=_label(Rect2(x+136,750,214,42),"",18,Color("ede5cf"))
		var title_label:=_label(Rect2(x+136,795,214,34),"",14,Color("a9dcda"))
		var stats_label:=_label(Rect2(x+12,864,340,32),"",14,Color("77e7cf"))
		var select_button:=_button(Rect2(x,738,365,170),"",_select_candidate.bind(index),true)
		_candidate_cards.append({"frame":frame,"portrait":portrait,"name":name_label,"title":title_label,"stats":stats_label,"button":select_button})
	_notice=_label(Rect2(35,914,1590,27),"",17,Color("edd295"))

func configure(window: Node) -> void:
	owner_window=window

func _process(_delta: float) -> void:
	var viewport: Vector2 = get_viewport_rect().size
	var factor: float = minf(viewport.x/DESIGN.x,viewport.y/DESIGN.y)
	canvas.scale=Vector2.ONE*factor; canvas.position=(viewport-DESIGN*factor)*.5

func _profile(race: String, profile_role: int) -> Dictionary:
	var profiles: Array = GameData.read("res://data/combat/commander_catalog.json").get("profiles",{}).get(race,[])
	return profiles[profile_role].duplicate(true) if profiles.size()>profile_role else {}

func _portrait_path(race: String, variant: int) -> String:
	var paths: Array = _portrait_catalog.get(race,[])
	variant=clampi(variant,0,paths.size()-1) if not paths.is_empty() else 0
	return str(paths[variant]) if not paths.is_empty() else str(_profile(race,0).get("portrait",""))

func _candidate_portrait(race: String, variant: int) -> Texture2D:
	return load(_portrait_path(race,variant)) as Texture2D

func _make_candidate(race: String, candidate_role: int, variant: int) -> Dictionary:
	var candidate := _profile(race,candidate_role)
	if candidate.is_empty(): return candidate
	var rng := RandomNumberGenerator.new()
	_roll_serial+=1
	rng.randomize()
	variant=clampi(variant,0,2)
	var name_groups: Array = CANDIDATE_NAMES.get(race,[])
	var names: Array = name_groups[candidate_role] if candidate_role>=0 and candidate_role<name_groups.size() else []
	candidate["id"]="%s_offer_%d_%d" % [race,Time.get_unix_time_from_system(),_roll_serial]
	if variant<names.size(): candidate["name"]=str(names[variant])
	candidate["portrait_variant"]=variant
	candidate["portrait"]=_portrait_path(race,variant)
	# Offers vary slightly around the role's faction balance, so rerolling changes
	# both the face and the tactical profile without creating extreme bonuses.
	for stat in ["attack","defense","expenses"]:
		candidate[stat]=snappedf(float(candidate.get(stat,0.0))+float(rng.randi_range(-1,1)),0.5)
	return candidate

func _roll_candidate_offers() -> void:
	var race := str(GameState.player_state.get("origin_race_id","humans"))
	var variants: Array[int] = [0,1,2]
	variants.shuffle()
	var previous: Array = _previous_offer_orders.get(slot,[])
	if previous.size()==variants.size() and previous==variants:
		variants=[variants[1],variants[2],variants[0]]
	var other_variant := _other_slot_portrait_variant()
	if other_variant in variants and variants[0]==other_variant:
		var swap_index: int = 1 if variants[1]!=other_variant else 2
		var first_variant: int = variants[0]
		variants[0]=variants[swap_index]
		variants[swap_index]=first_variant
	_previous_offer_orders[slot]=variants.duplicate()
	var offers: Array[Dictionary] = []
	for variant in variants: offers.append(_make_candidate(race,slot,variant))
	_candidate_offers[slot]=offers
	_selected_candidate_indices[slot]=0

func _other_slot_portrait_variant() -> int:
	if system==null: return -1
	var appointed: Dictionary = system.get_commander(1-slot)
	if not appointed.is_empty(): return int(appointed.get("portrait_variant",-1))
	var other_offers: Array = _candidate_offers.get(1-slot,[])
	if other_offers.is_empty(): return -1
	var other_index: int = clampi(int(_selected_candidate_indices.get(1-slot,0)),0,other_offers.size()-1)
	return int(other_offers[other_index].get("portrait_variant",-1))

func _select_candidate(index: int) -> void:
	if index<0 or index>=3: return
	_selected_candidate_indices[slot]=index
	_refresh_now()

func _selected_candidate() -> Dictionary:
	var offers: Array = _candidate_offers.get(slot,[])
	if offers.is_empty(): return {}
	var index: int = clampi(int(_selected_candidate_indices.get(slot,0)),0,offers.size()-1)
	return offers[index]

func _reroll_candidate() -> void:
	_roll_candidate_offers()
	_refresh_now()

func refresh(combat: Node) -> void:
	system=combat
	if owner_window==null: return
	var race: String = str(GameState.player_state.get("origin_race_id","humans"))
	var offers: Array = _candidate_offers.get(slot,[])
	if offers.is_empty() or str(offers[0].get("race_id",""))!=race:
		_roll_candidate_offers()
		offers=_candidate_offers.get(slot,[])
	var selected_index: int = clampi(int(_selected_candidate_indices.get(slot,0)),0,offers.size()-1)
	var candidate: Dictionary = offers[selected_index]
	var hired: Dictionary = system.get_commander(slot)
	var is_hired: bool = not hired.is_empty()
	_money.text="✦ %d монет     ◇ %d осколков" % [int(GameState.player_state.money),system.get_magic_shards()]
	_candidate_heading.text="КАНДИДАТЫ ВАШЕЙ РАСЫ · %s" % str(GameData.get_faction(race).get("name",race)).split(" — ")[0].to_upper()
	_summary.text="Сила атаки %d  ·  Оборона %d\nБонусы применены ко всем отрядам" % [system.get_attack_power(),system.get_defense_power()]
	var bonuses: Dictionary = system.get_commander_bonuses()
	for index in 3:
		var count: int = 0
		var a: float = 0; var d: float = 0; var base_a: float = 0; var base_d: float = 0
		for id in GROUPS[index]:
			var effect: Dictionary = system.get_unit_command_effect(str(id))
			count+=int(effect.count); a+=float(effect.attack)*int(effect.count); d+=float(effect.defense)*int(effect.count)
			base_a+=float(effect.base_attack)*int(effect.count); base_d+=float(effect.base_defense)*int(effect.count)
		var controls: Dictionary = _groups[index]
		controls.count.text="%d бойцов" % count if index!=1 else "%d орудий" % count
		controls.attack.text="⚔ %.0f → %.0f (%+.0f%%)" % [base_a,a,float(bonuses.attack)]
		controls.defense.text="◇ %.0f → %.0f (%+.0f%%)" % [base_d,d,float(bonuses.defense)]
		controls.attack_bar.max_value=maxf(1,base_a*1.3); controls.attack_bar.value=a
		controls.defense_bar.max_value=maxf(1,base_d*1.3); controls.defense_bar.value=d
		controls.attack.tooltip_text="Атака группы без командиров → с командирами. Численность при назначении не меняется."
		controls.defense.tooltip_text="Защита группы без командиров → с командирами. Итоговая оборона выше учитывает также башни, удачу и прочность базы."
	for index in 2:
		var commander: Dictionary = system.get_commander(index)
		var controls: Dictionary = _slots[index]
		controls.name.text=str(commander.get("name","Главный командир" if index==0 else "Заместитель"))
		controls.status.text="Свободен · назначить" if commander.is_empty() else "Назначен\n⚔ %+.1f%%\n◇ %+.1f%%" % [float(commander.get("attack_bonus",0)),float(commander.get("defense_bonus",0))]
		controls.portrait.texture=_candidate_portrait(str(commander.get("race_id",race)),int(commander.get("portrait_variant",index))) if not commander.is_empty() else null
		_set_frame_selected(controls.frame,index==slot)
		_role_buttons[index].set_pressed_no_signal(index==role)
	_hero.texture=_candidate_portrait(race,int(candidate.get("portrait_variant",0)))
	_hero_emblem.texture=GameData.get_faction_emblem(race)
	_hero_name.text=str(candidate.get("name","Командир")); _hero_title.text=str(candidate.get("title",""))
	_profile_heading.text="КАНДИДАТ · %s" % ("КОМАНДИР" if slot==0 else "ЗАМЕСТИТЕЛЬ")
	_status.text="КАНДИДАТ ВАШЕЙ РАСЫ · СЛОТ %d" % (slot+1)
	_description.text="Слот %d: %s\nЦентральный портрет совпадает с выбранной карточкой снизу." % [slot+1,"главный командир" if slot==0 else "заместитель"]
	for key in _stats:
		var value: float = float(candidate.get(str(key)+"_bonus",candidate.get(key,0)))
		_stats[key].label.text="%+.1f%%" % value
		_stats[key].bar.max_value=10; _stats[key].bar.value=absf(value)
		_stats[key].label.add_theme_color_override("font_color",Color("ee8d75") if key=="expenses" and value>0 else Color("6fe7d1"))
	var other_hired: Dictionary = system.get_commander(1-slot)
	var portrait_in_use: bool = not other_hired.is_empty() and int(other_hired.get("portrait_variant",-1))==int(candidate.get("portrait_variant",-2))
	_hire.text="СНЯТЬ НАЗНАЧЕННОГО" if is_hired else "НАНЯТЬ В СЛОТ %d · %d МОНЕТ" % [slot+1,int(candidate.get("cost",0))]
	_hire.disabled=not system.is_at_home() or (not is_hired and (not hired.is_empty() or str(candidate.get("race_id",""))!=race or portrait_in_use or float(GameState.player_state.money)<int(candidate.get("cost",0))))
	_candidate_refresh.disabled=not system.is_at_home()
	_candidate_refresh.tooltip_text="Обновляет весь ряд кандидатов вашей расы для выбранного слота."
	_hire.tooltip_text="Снимает текущего командира со слота." if is_hired else "Нанимает персонажа с выбранной карточки в пустой слот."
	for index in _candidate_cards.size():
		var card: Dictionary = _candidate_cards[index]
		var offer: Dictionary = offers[index]
		card.portrait.texture=_candidate_portrait(race,int(offer.get("portrait_variant",index)))
		card.name.text=str(offer.get("name","Кандидат"))
		card.title.text="%s · ранг %d" % [str(offer.get("title","")),int(offer.get("rank",1))]
		card.stats.text="⚔ %+.1f%%   ◇ %+.1f%%" % [float(offer.get("attack",0)),float(offer.get("defense",0))]
		_set_frame_selected(card.frame,index==selected_index)
	_notice.text=str(owner_window._notice.text)

func _refresh_now() -> void:
	if system!=null: refresh(system)

func _select_command_slot(index: int) -> void:
	# The right-side role tabs and the left-side slot cards must address the same
	# appointment; otherwise a deputy candidate can be shown while slot 0 stays selected.
	slot=index
	role=index
	_refresh_now()

func _appoint() -> void:
	if system==null: return
	var candidate: Dictionary = _selected_candidate()
	if candidate.is_empty(): return
	var commander: Dictionary = system.get_commander(slot)
	var result: Dictionary = system.dismiss_commander(slot) if not commander.is_empty() else system.hire_commander(candidate,slot)
	owner_window._notice.text=str(result.get("message",""))
	owner_window._cards_dirty=true; owner_window._refresh(); refresh(system)

func _frame(rect: Rect2, hero: bool) -> Panel:
	var panel:=Panel.new(); panel.set_meta("preserve_art_style",true); panel.mouse_filter=MOUSE_FILTER_IGNORE
	var style:=StyleBoxFlat.new(); style.bg_color=Color(.04,.11,.15,.94); style.border_color=Color("ae8a4e") if hero else Color("416575"); style.set_border_width_all(2); style.set_corner_radius_all(8); style.shadow_color=Color(0,0,0,.45); style.shadow_size=8
	panel.add_theme_stylebox_override("panel",style); panel.position=rect.position; panel.size=rect.size; canvas.add_child(panel)
	return panel

func _set_frame_selected(panel: Panel, selected: bool) -> void:
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color=Color("e6c573") if selected else Color("416575"); style.set_border_width_all(3 if selected else 2); panel.add_theme_stylebox_override("panel",style)

func _label(rect: Rect2, value: String, font_size: int, color: Color) -> Label:
	var label:=Label.new(); label.position=rect.position; label.size=rect.size; label.text=value; label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; label.mouse_filter=MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",color); label.set_meta("compact_description",true); canvas.add_child(label)
	return label

func _texture(rect: Rect2, texture: Texture2D) -> TextureRect:
	var image:=TextureRect.new(); image.position=rect.position; image.size=rect.size; image.texture=texture; image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED; image.mouse_filter=MOUSE_FILTER_IGNORE; canvas.add_child(image)
	return image

class Meter extends Control:
	var value: float = 0:
		set(new_value): value=new_value; queue_redraw()
	var max_value: float = 100:
		set(new_value): max_value=new_value; queue_redraw()
	var color: Color = Color("4ccbb7")
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color("102e3b"))
		draw_rect(Rect2(Vector2.ZERO,Vector2(size.x*clampf(value/maxf(1,max_value),0,1),size.y)),color)

func _bar(rect: Rect2, color: Color) -> Control:
	var bar:=Meter.new(); bar.position=rect.position; bar.size=rect.size; bar.color=color; bar.mouse_filter=MOUSE_FILTER_IGNORE; canvas.add_child(bar)
	return bar

func _button(rect: Rect2, value: String, action: Callable, overlay: bool = false) -> Button:
	var button:=Button.new(); button.set_meta("preserve_art_style",true); button.position=rect.position; button.size=rect.size; button.text=value; button.add_theme_font_size_override("font_size",17); button.set_meta("compact_description",true)
	if overlay:
		button.flat=true
		var style:=StyleBoxFlat.new(); style.bg_color=Color(0,0,0,0); button.add_theme_stylebox_override("normal",style)
		var hover:=style.duplicate() as StyleBoxFlat; hover.border_color=Color("e6c573"); hover.set_border_width_all(2); button.add_theme_stylebox_override("hover",hover)
	button.pressed.connect(action); canvas.add_child(button)
	return button
