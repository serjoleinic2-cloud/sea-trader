extends Control

var system: Node
var selected: String = ""
var center: Vector2 = Vector2.ZERO
var zoom: float = .24
var _dragging: bool = false
var _shots: Array = []

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

func _gui_input(event: InputEvent) -> void:
	if system==null: return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]: _dragging=event.pressed; accept_event()
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var anchor: Vector2 = world(event.position)
			zoom=clampf(zoom*(1.2 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1/1.2),.03,1.2)
			center=anchor-(event.position-size*.5)/zoom; accept_event()
		if event.button_index==MOUSE_BUTTON_LEFT and event.pressed and system.active():
			var clicked: Vector2 = event.position
			for id in GameState.combat_state.naval_battle.ship_ids:
				var ship: Dictionary = system.ship_by_id(str(id))
				if not ship.is_empty() and point(system.position(ship)).distance_to(clicked)<16:
					selected=str(id); accept_event(); return
			if selected!="":
				var enemy_id: String = ""
				for enemy in system.get_enemy_snapshots():
					if point(enemy.position).distance_to(clicked)<16: enemy_id=str(enemy.id); break
				system.issue_order(selected,world(clicked),enemy_id); accept_event()
	if event is InputEventMouseMotion:
		if _dragging: center-=event.relative/zoom; accept_event()
		tooltip_text=""
		for vessel in _vessels():
			if point(vessel.position).distance_to(event.position)<18: tooltip_text=str(vessel.name)

func _vessels() -> Array:
	var result: Array = []
	if system==null: return result
	for ship in system.warships():
		if not system.active() or not GameState.combat_state.naval_battle.ship_ids.has(str(ship.instance_id)): continue
		result.append({"id":str(ship.instance_id),"name":str(ship.name),"position":system.position(ship),"heading":system.vector(ship.get("escort_state",{}).get("heading",Vector2.UP)),"hull":float(ship.hull),"max":system.hull_max(ship),"color":Color("6be8ec")})
	for enemy in system.get_enemy_snapshots():
		var raw: Dictionary = GameState.combat_state.naval_enemies.get(enemy.id,{})
		enemy["hull"]=float(raw.get("hull",0)); enemy["max"]=float(raw.get("hull_max",1)); enemy["color"]=Color("ff8464")
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
		draw_colored_polygon(PackedVector2Array([at+heading*10,at-heading*8+side*5,at-heading*8-side*5]),color)
		draw_rect(Rect2(at+Vector2(-12,15),Vector2(24,3)),Color("273e48"))
		draw_rect(Rect2(at+Vector2(-12,15),Vector2(24*clampf(float(vessel.hull)/maxf(1,float(vessel.max)),0,1),3)),color)
		if str(vessel.id)==selected:
			draw_arc(at,16,0,TAU,32,Color("ffda82"),2)
			draw_string(ThemeDB.fallback_font,at+Vector2(-30,-20),str(vessel.name),HORIZONTAL_ALIGNMENT_LEFT,140,12,Color("f4e4c2"))
	for shot in _shots: draw_line(point(shot.from),point(shot.to),Color("ffe5a0") if shot.hit else Color("566774"),2)
