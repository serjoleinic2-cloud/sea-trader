extends Control

const ARTICLES := {
	"Обзор": "Sea Trader — морская торговая стратегия. Исследуйте маршруты, перевозите грузы, развивайте домашний остров и решайте, когда торговать, а когда идти на риск.\n\nНачните с карты и подсказок первого рейса. Показатели и основные ресурсы всегда находятся в верхней полосе.",
	"Расы": "У каждой из шести рас свой облик, гербы, корабельная и архитектурная стилистика. Раса игрока определяет оформление базы и доступ к союзным отношениям. Нападать на порты своей расы нельзя.\n\nНа чужих островах смотрите на герб и владельца до начала переговоров.",
	"Юниты": "Гарнизон защищает порт и участвует в рейдах. Состав войск и потери показываются до и после боя. Солдаты отличаются ролью и характеристиками; набор доступных бойцов зависит от расы и развития гарнизона.\n\nЭкипаж корабля — отдельные специалисты: капитан, штурман и другие работники. Их нанимают на бирже персонала и назначают в свободные ячейки флота.",
	"Корабли": "Корабли отличаются грузоподъёмностью, скоростью, рангом допуска и числом мест экипажа. Торговые суда возят грузы; военные транспортники перевозят войска и орудия для рейдов.\n\nНа домашней базе откройте «Флот и верфь»: слева смотрите уровень и улучшения верфи, справа выбирайте корабль, изучайте характеристики и открывайте 3D-просмотр. Постройка требует материалов со склада.",
	"Постройки": "Постройки дают доступ к производству, войскам, услугам и кораблям. На домашней базе откройте «Порт → Строительство», выберите здание и передайте нужные материалы. Уровень и завершение стройки видны в карточке проекта.\n\nВерфь открывает строительство кораблей. Её развитие повышает возможности базы и доступ к более серьёзным судам.",
	"Строительство": "Стройка начинается с проекта здания. Материалы выделяются со склада, затем запускается таймер строительства. Пока проект не завершён, его можно продолжать или отменить по правилам карточки.\n\nУлучшайте ключевые здания постепенно: стоимость и требования растут с уровнем.",
	"Торговля": "В порту можно купить или продать доступные товары. Цена и наличие зависят от места и состояния рынка. Груз ограничен вместимостью корабля; проверяйте название порта в подсказках и карточке сделки.\n\nАвтоматические суда флота используют изученные маршруты и назначенный экипаж. Следите за расходами и запасом еды.",
	"Рейды": "Для рейда нужен боевой транспортник, войска и орудия. Победа наносит потери обеим сторонам; захват обходится дороже, чем установление дани. Перед отправкой проверьте состав отряда и боеспособность гарнизона.\n\nОнлайн-игрок после поражения получает защиту от повторного нападения. На порты ИИ можно наложить дань вместо постоянного захвата.",
	"Дань и бунты": "Побеждённый порт ИИ может платить дань — долю прибыли ежедневно. Для контроля там остаются войска и посланник. Повторно атаковать платящий дань порт нельзя, пока он не восстанет или не будет захвачен другой расой.\n\nПри бунте приходит экстренное сообщение с потерями и исходом. Освободившийся остров получает временную защиту.",
	"Флот и экипаж": "В окне флота собраны ваши суда, состояние, маршруты и ячейки экипажа. Новый персонал выбирается на бирже и нанимается на постоянной основе; его можно заменить или уволить. Навыки растут постепенно от действий в плавании.\n\nСуда высоких уровней требуют больше людей и обслуживания. Назначьте полный состав до отправки на маршрут.",
	"Порты и причаливание": "Подойдите к порту и используйте подсказку над кораблём, чтобы пришвартоваться. В чужом порту доступны торговля или бой — выбор зависит от отношений и ситуации.\n\nНа карте зелёным отмечаются ваша территория и порты, платящие дань. Следите за безопасными фарватерами и не пытайтесь проходить сквозь острова и причалы."
}

var _is_open := false
var _panel: PanelContainer
var _title: Label
var _body: RichTextLabel
var _tabs: HFlowContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 4096
	_panel = PanelContainer.new()
	_panel.name = "EncyclopediaPanel"
	add_child(_panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.075, 0.98)
	style.border_color = Color(0.72, 0.53, 0.26, 1.0)
	style.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_title = Label.new()
	_title.text = "БОРТОВАЯ ЭНЦИКЛОПЕДИЯ"
	_title.add_theme_font_size_override("font_size", 22)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(44, 38)
	close.pressed.connect(close_window)
	header.add_child(close)
	_tabs = HFlowContainer.new()
	_tabs.add_theme_constant_override("h_separation", 6)
	_tabs.add_theme_constant_override("v_separation", 6)
	column.add_child(_tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = false
	_body.fit_content = true
	_body.scroll_active = false
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("normal_font_size", 16)
	scroll.add_child(_body)
	for topic in ARTICLES:
		var button := Button.new()
		button.text = topic
		button.custom_minimum_size = Vector2(106, 34)
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(_select_topic.bind(topic))
		_tabs.add_child(button)
	_select_topic("Обзор")

func open() -> void:
	_is_open = true
	visible = true
	move_to_front()

func close_window() -> void:
	_is_open = false
	visible = false

func _select_topic(topic: String) -> void:
	_title.text = "БОРТОВАЯ ЭНЦИКЛОПЕДИЯ · " + topic if _title != null else topic
	_body.text = str(ARTICLES.get(topic, ARTICLES["Обзор"]))

func _process(_delta: float) -> void:
	if not _is_open or _panel == null:
		return
	var viewport := get_viewport_rect().size
	_panel.size = Vector2(minf(1120.0, viewport.x - 32.0), minf(760.0, viewport.y - 112.0))
	_panel.position = (viewport - _panel.size) * 0.5
