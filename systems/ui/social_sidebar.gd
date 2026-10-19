extends CanvasLayer

var _main: Node
var _window: Node
var _clans: Node
var _menu: VBoxContainer
var _boosts: Label
var _toast_until: int = 0
var _seen_boosts: Dictionary = {}
var _activity_toast: Label
var _activity_until: int = 0

func _ready() -> void:
	layer = 129
	_menu = VBoxContainer.new()
	_menu.name = "SocialSidebar"
	_menu.add_theme_constant_override("separation", 5)
	add_child(_menu)
	for entry in [["clan", "Клан"], ["clans", "Кланы · рейтинг"], ["shop", "Магазин"], ["chat", "Друзья и чат"]]:
		var button := Button.new()
		button.name = "Social_" + str(entry[0])
		button.tooltip_text = str(entry[1])
		button.icon = load("res://assets/ui/social/%s.svg" % ("chat" if str(entry[0]) == "chat" else str(entry[0])))
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.expand_icon = true
		button.custom_minimum_size = Vector2(54, 54)
		button.set_meta("compact_hud", true)
		button.set_meta("fixed_font_size", 12)
		button.set_meta("preserve_art_style", true)
		button.theme = preload("res://systems/ui/game_ui_theme.gd").new().get_theme()
		button.pressed.connect(func() -> void: _window.show_page(str(entry[0])))
		_menu.add_child(button)
	_boosts = Label.new()
	_boosts.name = "ClanBoostTimers"
	_boosts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boosts.add_theme_font_size_override("font_size", 12)
	_boosts.add_theme_color_override("font_color", Color("f2d697"))
	_boosts.add_theme_color_override("font_shadow_color", Color("071520"))
	_boosts.add_theme_constant_override("shadow_offset_x", 2)
	_boosts.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_boosts)
	_activity_toast = Label.new()
	_activity_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_activity_toast.set_meta("fixed_font_size", 13)
	_activity_toast.add_theme_font_size_override("font_size", 13)
	_activity_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color(0.02, 0.06, 0.09, 0.9)
	surface.border_color = Color("bc995a"); surface.set_border_width_all(1); surface.set_content_margin_all(10)
	_activity_toast.add_theme_stylebox_override("normal", surface)
	_activity_toast.hide(); add_child(_activity_toast)

func initialize(main: Node, window: Node, clans: Node) -> void:
	_main = main
	_window = window
	_clans = clans
	_clans.boost_activated.connect(func(_stat: String, _expires: int) -> void: _toast_until = int(Time.get_unix_time_from_system()) + 5)
	_clans.changed.connect(_refresh_base)
	_main.get_node("CompanyShop").changed.connect(_refresh_base)
	var progression: Node = _main.get_node_or_null("CompanyProgression")
	if progression != null:
		progression.activity_ready.connect(func(message: String) -> void:
			_activity_toast.text = message
			_activity_until = int(Time.get_unix_time_from_system()) + 5)

func _refresh_base() -> void:
	var view: Node = _main.get_node_or_null("Approach3DView")
	if view != null: view.call_deferred("sync_generated_world", _main.get("_world_data"))

func _process(_delta: float) -> void:
	if _main == null: return
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	var top: float = preload("res://systems/ui/workspace_layout.gd").safe_top(get_tree())
	_menu.position = Vector2(10, top + 20)
	var coordinator: Node = get_tree().get_first_node_in_group("window_coordinator")
	var workspace_open: bool = false
	if coordinator != null:
		for entry in coordinator.get("_entries"):
			if bool(entry.window.get(str(entry.flag))): workspace_open = true; break
	_menu.visible = not workspace_open
	var own: Dictionary = preload("res://systems/social/clan_bonuses.gd").own_clan()
	var lines: PackedStringArray = []
	var now: int = int(Time.get_unix_time_from_system())
	for stat in own.get("active_boosts", {}):
		var left: int = int(own.active_boosts[stat]) - now
		if left <= 0: continue
		if int(_seen_boosts.get(stat, 0)) != int(own.active_boosts[stat]):
			_seen_boosts[stat] = int(own.active_boosts[stat])
			_toast_until = now + 5
		var spec: Dictionary = _clans.rules.boosts.get(stat, {})
		lines.append("%s +%.2f%% · %02d:%02d:%02d" % [str(spec.get("name", stat)), preload("res://systems/social/clan_bonuses.gd").percent(str(stat)), left / 3600, left % 3600 / 60, left % 60])
	_boosts.text = ("КЛАН АКТИВИРОВАЛ БУСТ\n" if now < _toast_until else "") + "\n".join(lines)
	_boosts.position = Vector2(78, top + 24)
	_boosts.visible = not lines.is_empty() and not workspace_open
	_activity_toast.position = Vector2(78, maxf(top + 24, viewport.y - 195))
	_activity_toast.size = Vector2(minf(520, viewport.x - 100), 0)
	_activity_toast.visible = now < _activity_until and not workspace_open
