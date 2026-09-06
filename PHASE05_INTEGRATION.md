# Phase 05 — Инструкция по интеграции в Godot Editor

## Что заменить файлами из архива

| Файл из архива | Куда положить |
|---|---|
| `systems/rendering/world_renderer.gd` | `D:\sea-trader\systems\rendering\world_renderer.gd` |
| `systems/ports/port_system.gd` | `D:\sea-trader\systems\ports\port_system.gd` |
| `systems/ports/port_debug_hud.gd` | `D:\sea-trader\systems\ports\port_debug_hud.gd` |
| `scripts/main.gd` | `D:\sea-trader\scripts\main.gd` |
| `tests/unit/test_phase05_ports.gd` | `D:\sea-trader\tests\unit\test_phase05_ports.gd` |

## event_bus.gd — НЕ заменяй целиком

Открой `D:\sea-trader\autoloads\event_bus.gd` и добавь три сигнала если их нет:

```gdscript
signal port_discovered(port_id: String)
signal port_entered(port_id: String)
signal port_exited(port_id: String)
```

## В Godot Editor — добавить узлы в main.tscn

Открой `scenes/game/main.tscn` в Godot Editor.

Добавь как дочерние узлы к корневому узлу Main:

1. **Node2D** → назови `WorldRenderer`
   - Attach script: `systems/rendering/world_renderer.gd`

2. **Node** → назови `PortSystem`
   - Attach script: `systems/ports/port_system.gd`

3. **CanvasLayer** → назови `PortDebugHUD`
   - Attach script: `systems/ports/port_debug_hud.gd`

## Убедись что в main.tscn есть узел Ship

main.gd обращается к `$Ship`.
Если твой корабль называется иначе — измени строку в main.gd:

```gdscript
@onready var ship_node: Node2D = $Ship   # ← замени Ship на своё имя узла
```

## Проверка в Godot

1. Запусти игру (F5).
2. В debug HUD (снизу слева) должно появиться:
   `Ports: 0 / N` (N = кол-во портов в мире)
3. Подплыви кораблём к любому порту.
4. Счётчик должен смениться на `Ports: 1 / N`.
5. Имя порта должно появиться под маркером.

## Если WorldGenerator не имеет generate_geometry_only()

В main.gd есть вызов:
```gdscript
WorldGenerator.generate_geometry_only(GameState.world_state.seed)
```

Если такого метода нет — замени на:
```gdscript
WorldGenerator.generate(GameState.world_state.seed)
```

Но убедись что generate() не перезаписывает port_state при загрузке.
Если перезаписывает — это проблема из предыдущего задания (Fix Persistent World),
которая должна быть уже исправлена.
