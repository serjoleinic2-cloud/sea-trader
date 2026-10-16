extends Control

var system: Node
var selected: String = ""
var center: Vector2 = Vector2.ZERO
var zoom: float = .24
var _dragging: bool = false
var _shots: Array = []
const MAP_TO_METERS: float = 0.04

func _ready() -> void:
	clip_contents=true; mouse_filter=MOUSE_FILTER_STOP
	EventBus.naval_shot_fired.connect(func(a: Vector2,b: Vector2,hit: bool): _shots.append({"from":a,"to":b,"ttl":.4,"hit":hit}))

func _process(delta: float) -> void:
	for shot in _shots: shot.ttl-=delta
	_shots=_shots.filter(func(shot): return float(shot.ttl)>0)
	queue_redraw()

func point(at: Vector2) -> Vector2:
	return size*.5+(at-center)*zoom

func world(at: Vector2) -> Vector2:
	return center+(at-size*.5)/zoom

func fit_battle() -> void:
	if system==null or size.x<60 or size.y<60: return
	var bounds := Rect2(system.vector(GameState.ship_state.position),Vector2.ZERO)
	for vessel in _vessels():
		var half_length: float = float(vessel.get("length", 130.0)) * 0.5
		var half_beam: float = float(vessel.get("beam", 24.0)) * 0.5
		var extent_radius: float = maxf(half_length, half_beam) + 20.0
		var extent := Vector2(extent_radius, extent_radius)
		bounds = bounds.expand(vessel.position - extent)
		bounds = bounds.expand(vessel.position + extent)
	center=bounds.get_center()
	zoom=clampf(minf((size.x-64)/maxf(1,bounds.size.x),(size.y-80)/maxf(1,bounds.size.y)),.03,1.2)

func _visual_length(ship_type_id: String) -> float:
	var visuals: Dictionary = system.get("_visuals") if system != null else {}
	var visual: Dictionary = visuals.get(ship_type_id, {})
	return maxf(30.0, float(visual.get("display_length", 5.1)) / MAP_TO_METERS)

func _visual_beam(ship_type_id: String) -> float:
	return _visual_length(ship_type_id) * 0.19

func _input(event: InputEvent) -> void:
	# A release outside the map must never leave its drag mode latched on.
	if event is InputEventMouseButton and not event.pressed and event.button_index in [MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]: _dragging=false

func _gui_input(event: InputEvent) -> void:
	if system==null: return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]:
			_dragging=event.pressed; accept_event(); return
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var anchor: Vector2 = world(event.position)
			zoom=clampf(zoom*(1.2 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1/1.2),.03,1.2)
			center=anchor-(event.position-size*.5)/zoom; accept_event()
		if event.button_index==MOUSE_BUTTON_LEFT and event.pressed and system.active():
			var clicked: Vector2 = event.position
			for vessel in _vessels():
				if not GameState.combat_state.naval_battle.ship_ids.has(str(vessel.get("id", ""))): continue
				if float(vessel.get("hull", 0.0)) <= 0.0: continue
				if _contains_ship_at(vessel, clicked):
					selected=str(vessel.id); GameState.combat_state.naval_battle.notice="Выбран «%s». Нажмите красный корабль, чтобы атаковать." % str(vessel.name); accept_event(); return
			if selected!="":
				var enemy_id: String = ""
				for enemy in system.get_enemy_snapshots():
					if not GameState.combat_state.naval_battle.enemy_ids.has(str(enemy.id)): continue
					var raw: Dictionary = GameState.combat_state.naval_enemies.get(str(enemy.id), {})
					var vessel: Dictionary = enemy.duplicate()
					vessel["hull"] = float(raw.get("hull", 0.0))
					vessel["length"] = _visual_length(str(enemy.get("ship_type_id", "")))
					vessel["beam"] = _visual_beam(str(enemy.get("ship_type_id", "")))
					if _contains_ship_at(vessel, clicked): enemy_id=str(enemy.id); break
				var result: Dictionary=system.issue_order(selected,world(clicked),enemy_id)
				if not bool(result.get("ok",false)): GameState.combat_state.naval_battle.notice=str(result.get("message","Приказ не принят."))
				accept_event()
	if event is InputEventMouseMotion:
		if _dragging: center-=event.relative/zoom; accept_event()
		tooltip_text=""
		for vessel in _vessels():
			if _contains_ship_at(vessel, event.position): tooltip_text=str(vessel.name)

func _contains_ship_at(vessel: Dictionary, screen_point: Vector2) -> bool:
	var relative: Vector2 = screen_point - point(system.vector(vessel.position))
	var heading: Vector2 = system.vector(vessel.get("heading", Vector2.UP)).normalized()
	if heading.length_squared() < 0.1: heading = Vector2.UP
	var half_length: float = maxf(7.0, float(vessel.get("length", 130.0)) * zoom * 0.5)
	var half_beam: float = maxf(2.5, float(vessel.get("beam", 24.0)) * zoom * 0.5)
	return absf(relative.dot(heading)) <= half_length + 5.0 and absf(relative.dot(heading.orthogonal())) <= half_beam + 5.0

func _vessels() -> Array:
	var result: Array = []
	if system==null: return result
	for ship in system.warships():
		if not system.active() or not GameState.combat_state.naval_battle.ship_ids.has(str(ship.instance_id)): continue
		var ship_type_id: String = str(ship.get("ship_type_id", ""))
		result.append({"id":str(ship.instance_id),"name":str(ship.name),"ship_type_id":ship_type_id,"position":system.position(ship),"heading":system.vector(ship.get("escort_state",{}).get("heading",Vector2.UP)),"hull":float(ship.hull),"max":system.hull_max(ship),"length":_visual_length(ship_type_id),"beam":_visual_beam(ship_type_id),"color":Color("6be8ec")})
	for enemy in system.get_enemy_snapshots():
		if not system.active() or not GameState.combat_state.naval_battle.enemy_ids.has(str(enemy.id)): continue
		var raw: Dictionary = GameState.combat_state.naval_enemies.get(enemy.id,{})
		var ship_type_id: String = str(enemy.get("ship_type_id", raw.get("ship_type_id", "")))
		enemy["hull"]=float(raw.get("hull",0)); enemy["max"]=float(raw.get("hull_max",1)); enemy["ship_type_id"]=ship_type_id; enemy["length"]=_visual_length(ship_type_id); enemy["beam"]=_visual_beam(ship_type_id); enemy["color"]=Color("ff8464")
		result.append(enemy)
	return result

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("081a24"))
	for x in range(0,int(size.x),40): draw_line(Vector2(x,0),Vector2(x,size.y),Color("163540"))
	for y in range(0,int(size.y),40): draw_line(Vector2(0,y),Vector2(size.x,y),Color("163540"))
	if system==null: return
	if system._main!=null:
		for island in system._main.get("_navigation_world").get("islands",[]):
			draw_circle(point(system.vector(island.get("position",Vector2.ZERO))),float(island.get("radius",0))*zoom,Color("294438"))
	var flagship: Vector2 = point(system.vector(GameState.ship_state.get("position",Vector2.ZERO)))
	draw_circle(flagship,8,Color("eac46f")); draw_arc(flagship,13,0,TAU,24,Color("eac46f"),1.5)
	for vessel in _vessels():
		var at: Vector2 = point(vessel.position)
		var heading: Vector2 = system.vector(vessel.heading).normalized()
		if heading.length_squared()<.1: heading=Vector2.UP
		var side: Vector2 = heading.orthogonal()
		var color: Color = vessel.color if float(vessel.hull)>0 else Color("53616b")
		var half_length: float = maxf(7.0, float(vessel.get("length", 130.0)) * zoom * 0.5)
		var half_beam: float = maxf(2.5, float(vessel.get("beam", 24.0)) * zoom * 0.5)
		draw_colored_polygon(PackedVector2Array([at+heading*half_length,at-heading*half_length+side*half_beam,at-heading*half_length-side*half_beam]),color)
		var bar_size := Vector2(maxf(18.0, half_length * 1.35), 3.0)
		var bar_center: Vector2 = at - side * (half_beam + 6.0)
		draw_rect(Rect2(bar_center - bar_size * 0.5,bar_size),Color("273e48"))
		draw_rect(Rect2(bar_center - bar_size * 0.5,Vector2(bar_size.x*clampf(float(vessel.hull)/maxf(1,float(vessel.max)),0,1),bar_size.y)),color)
		if str(vessel.id)==selected:
			draw_arc(at,maxf(16.0,half_length*1.12),0,TAU,32,Color("ffda82"),2)
			draw_string(ThemeDB.fallback_font,at+Vector2(-30,-maxf(20.0,half_length+10.0)),str(vessel.name),HORIZONTAL_ALIGNMENT_LEFT,140,12,Color("f4e4c2"))
	for shot in _shots: draw_line(point(shot.from),point(shot.to),Color("ffe5a0") if shot.hit else Color("566774"),2)
