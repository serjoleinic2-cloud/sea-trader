extends Node

# main.gd — обновлён для Phase 05
# Добавлена инициализация WorldRenderer и PortSystem.
# Логика New Game / Load Game остаётся как в предыдущей фазе.
# НЕ трогает физику корабля, сенсоры, NavHUD, экономику.

@onready var world_renderer: Node2D  = $WorldRenderer
@onready var port_system: Node       = $PortSystem
@onready var port_debug_hud: CanvasLayer = $PortDebugHUD

# Ссылка на узел корабля — должен существовать в сцене из Phase 03
@onready var ship_node: Node2D = $Ship


func _ready() -> void:
	_boot()


func _boot() -> void:
	if SaveSystem.has_save():
		_load_existing_game()
	else:
		_start_new_game()

	_init_rendering()
	_init_port_system()


# ---------------------------------------------------------------------------
# New Game / Load Game
# ---------------------------------------------------------------------------

func _start_new_game() -> void:
	# Генерируем seed и мир только для новой игры
	GameState.world_state.seed = randi()
	WorldGenerator.generate(GameState.world_state.seed)
	# port_state заполняется WorldGenerator'ом (Phase 02 logic)
	SaveSystem.save_game()


func _load_existing_game() -> void:
	# Восстанавливаем существующее состояние — НЕ перегенерируем порты
	SaveSystem.load_game()
	# WorldGenerator нужен только чтобы воссоздать геометрию мира из seed,
	# но НЕ перезаписывает port_state / player knowledge
	WorldGenerator.generate_geometry_only(GameState.world_state.seed)


# ---------------------------------------------------------------------------
# Инициализация систем Phase 05
# ---------------------------------------------------------------------------

func _init_rendering() -> void:
	if world_renderer == null:
		push_warning("main.gd: WorldRenderer node not found in scene. Add it as child.")
		return
	world_renderer.render_world()


func _init_port_system() -> void:
	if port_system == null:
		push_warning("main.gd: PortSystem node not found in scene. Add it as child.")
		return
	if ship_node == null:
		push_warning("main.gd: Ship node not found in scene.")
		return
	port_system.initialize(ship_node)

	if port_debug_hud != null:
		port_debug_hud.initialize(port_system)
