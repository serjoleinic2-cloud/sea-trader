from pathlib import Path
import json
ROOT = Path(__file__).resolve().parents[2]
def edit(path, old, new):
    p=ROOT/path; s=p.read_text(encoding='utf-8-sig'); assert old in s,(path,old[:80]); p.write_text(s.replace(old,new),encoding='utf-8')
def jsonedit(path, fn):
    p=ROOT/path; d=json.loads(p.read_text(encoding='utf-8-sig')); fn(d); p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
edit('systems/ui/port_window.gd','var icon_path: String = str(building.get("ui_icon", ""))','var icon_path: String = "res://assets/ui/ports/%s/%s.png" % [str(GameState.player_state.get("origin_race_id", "humans")), building_id]\n\t\tif not ResourceLoader.exists(icon_path): icon_path = str(building.get("ui_icon", ""))')
edit('systems/ui/port_window.gd','\t\tgrid.add_child(button)\n\nfunc _open_building_card','\t\tvar card := VBoxContainer.new()\n\t\tgrid.add_child(card)\n\t\tcard.add_child(button)\n\t\tvar inspect := Button.new()\n\t\tinspect.text = "Осмотреть в 3D"\n\t\tinspect.pressed.connect(func(): preload("res://systems/ui/ship_inspection_window.gd").show_ship(self, ship_id))\n\t\tcard.add_child(inspect)\n\nfunc _open_building_card')
edit('systems/ui/fleet_window.gd','\tbox.add_child(icon)\n','\tbox.add_child(icon)\n\tvar inspect := Button.new()\n\tinspect.text = "Осмотреть в 3D"\n\tinspect.pressed.connect(func(): preload("res://systems/ui/ship_inspection_window.gd").show_ship(self, ship_type_id))\n\tbox.add_child(inspect)\n')
edit('systems/ui/shipyard_window.gd','\tbox.add_child(_ship_icon)\n','\tbox.add_child(_ship_icon)\n\tvar inspect := Button.new()\n\tinspect.text = "Осмотреть корабль в 3D"\n\tinspect.pressed.connect(func(): preload("res://systems/ui/ship_inspection_window.gd").show_ship(self,str(_system.get_project().get("ship_type_id","ship_sloop"))))\n\tbox.add_child(inspect)\n')
edit('systems/ui/building_project_window.gd','var icon_path: String = _system.get_building_icon_path(building_id)','var icon_path: String = "res://assets/ui/ports/%s/%s.png" % [str(GameState.player_state.get("origin_race_id", "humans")), building_id]\n\tif not ResourceLoader.exists(icon_path): icon_path = _system.get_building_icon_path(building_id)')
for path in ['systems/ui/building_project_window.gd','systems/ui/shipyard_window.gd']:
    p=ROOT/path; s=p.read_text(encoding='utf-8')
    for old,new in [(30,22),(23,15),(22,16),(21,16),(20,16)]: s=s.replace('"font_size", '+str(old)+')','"font_size", '+str(new)+')')
    s=s.replace('scroll.custom_minimum_size.y = 360','scroll.custom_minimum_size.y = 190').replace('scroll.custom_minimum_size.y = 340','scroll.custom_minimum_size.y = 190').replace('Vector2(0, 104)','Vector2(0, 180)')
    s=s.replace('_details = Label.new()','_details = Label.new()\n\t_details.set_meta("compact_description", true)').replace('var label: Label = Label.new()','var label: Label = Label.new()\n\tlabel.set_meta("compact_description", true)')
    p.write_text(s,encoding='utf-8')
edit('systems/ui/ui_accessibility.gd','11 if control.has_meta("compact_hud") else MINIMUM_READABLE_SIZE','11 if control.has_meta("compact_hud") else (14 if control.has_meta("compact_description") else MINIMUM_READABLE_SIZE)')
jsonedit('data/config/game_modules.json',lambda d:d['modules'].insert(6,{'id':'MilitaryTransportSystem','script':'res://systems/fleet/military_transport_system.gd','initialize':'initialize','args':['$main'],'after':['FleetSystem']}))
def ships(d):
    rows=d if isinstance(d,list) else d.get('ships',[])
    for ship in rows:
        if ship['id']=='ship_combat_cutter': ship.update(name='Военный транспорт',role='Десант и сопровождение',cargo_capacity=0,soldier_capacity=60,artillery_capacity=6,military_transport=True)
jsonedit('data/ships/ship_catalog.json',ships)
edit('systems/world/fleet_traffic_renderer.gd','\t\tvar ship: Dictionary = raw_ship\n','\t\tvar ship: Dictionary = raw_ship\n\t\tif str(ship.get("ship_type_id","")) == "ship_combat_cutter" and ship.get("autopilot",{}).is_empty(): continue\n')
edit('systems/world/fleet_traffic_renderer.gd','\treturn snapshots\n\nfunc _clearance_at','\tvar military: Node = get_tree().get_first_node_in_group("military_transport_system")\n\tif military != null: snapshots.append_array(military.get_vessel_snapshots())\n\treturn snapshots\n\nfunc _clearance_at')
edit('systems/ui/port_window.gd','var combat_ship: bool = str(GameState.ship_state.get("ship_id", "")) == "ship_combat_cutter"','var transports: Node = get_tree().get_first_node_in_group("military_transport_system")\n\tvar combat_ship: bool = transports != null and not transports.raid_transports().is_empty()')
edit('systems/ui/port_window.gd','Сначала постройте боевой катер на верфи и возьмите его под командование.','Погрузите войска из гарнизона в военный транспорт и дождитесь эскадры у порта.')
edit('systems/ui/port_window.gd','Капитан поведёт боевой катер лично.','Высадить десант с транспортов сопровождения.')
