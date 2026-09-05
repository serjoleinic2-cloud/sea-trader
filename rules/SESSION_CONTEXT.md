# SEA TRADER — SESSION CONTEXT

> Short handoff document for new AI sessions.
> Read this first, then rules/*. Do not start coding before reading.
> Last Updated: 2026-09-05

---

## PROJECT

| Field | Value |
|-------|-------|
| Название | Sea Trader |
| Жанр | Offline top-down 2D maritime trading simulation |
| Платформа | Android primary, iOS secondary |
| Engine | Godot 4.x (GDScript) |
| Offline/Online | Offline-first. No backend. Ever. |

---

## CORE CONCEPT

Игрок — капитан грузового корабля на процедурно генерируемом море.
Ручное управление кораблем (tilt телефона).
Доставка грузов между портами, развитие торговой компании, расширение флота.
Каждый рейс — лично, руками. Нет автопилота на новых маршрутах.

---

## CURRENT DEVELOPMENT METHOD

```
User (задание)
    |
    v
AI assistant (Claude / Kimi / другой)
    |
    v
ZIP-архив с проектом
    |
    v
Local project (Godot 4.x Editor)
    |
    v
Godot verification (runtime check)
    |
    v
GitHub Desktop (коммит)
    |
    v
GitHub (push)
```

---

## CURRENT PHASE

**Phase 03 — Ship Physics**

Phase 01 (Foundation) завершена и проверена.
Phase 02 (World Generation) реализована и проверена.
Phase 03 реализована, ожидает runtime sign-off.

---

## COMPLETED

### Phase 01 — Foundation
- Godot 4.x проект, autoloads (GameState, EventBus, SaveSystem)
- Структура папок, placeholder JSON, GUT-тесты
- Runtime verified

### Phase 02 — World Generation
- Детерминированная генерация мира из seed
- Острова, порты, зоны опасностей (inactive)
- Placeholder визуализация
- 10 unit-тестов
- Runtime verified

### Phase 03 — Ship Physics
- `systems/ship/ship_physics.gd` — движение, инерция, поворот, визуальный крен, расход топлива
- `systems/ship/ship_control.gd` — нормализованный интерфейс команд
- `systems/input/sensor_input.gd` — абстракция акселерометра (stub, Phase 04 активирует)
- `systems/input/input_adapter.gd` — keyboard debug fallback + tilt path готов
- `scenes/game/ship/ship.gd` — сцена корабля, HUD, основа collision
- `scenes/game/ship/ship.tscn` — Polygon2D, Camera2D (следит за кораблём), Area2D, DebugHUD
- `scripts/main.gd` — обновлён: спавн Ship, Camera2D перенесена в Ship
- `autoloads/game_state.gd` — добавлены `fuel_max`, `cargo_capacity` в ship_state
- `data/ships/ship_sloop.json` — version bump to 2
- `tests/unit/test_ship_physics.gd` — 11 тестов

---

## CURRENT TASK

Runtime sign-off Phase 03:
1. Открыть проект в Godot
2. Запустить игру
3. Убедиться, что море/мир Phase 02 сохранился
4. Убедиться, что корабль появился (Polygon2D треугольник)
5. Проверить WASD управление (W — газ, S — тормоз, A/D — повороты)
6. Проверить плавность движения и инерцию
7. Проверить визуальный крен при повороте
8. Проверить Camera2D follow за кораблём
9. Проверить debug HUD (SPEED / FUEL / HULL / CARGO)
10. Проверить отсутствие parser/runtime errors

**После runtime sign-off → Phase 04.**

---

## IMPORTANT NOTE FOR NEXT SESSION

`CollisionShape2D` в `scenes/game/ship/ship.tscn` требует назначения shape resource в Godot Editor:
- Открыть `ship.tscn` в редакторе
- Выбрать узел `Area2D/CollisionShape2D`
- В Inspector → Shape → New CircleShape2D, Radius: 14

---

## NEXT TASK

**Phase 04 — Sensors**
- Активировать `SensorInput` (реальный акселерометр Android)
- Калибровка нейтрального положения (базовый UI)
- Sensitivity configurable через `SettingsState`
- Keyboard fallback сохраняется

---

## IMPORTANT DECISIONS

| Решение | Почему | Не менять без |
|---------|--------|---------------|
| Godot 4.x / GDScript | Легкий, бесплатный, нативный Android sensor API | Владельца |
| Offline-first | Без интернета, без backend | Владельца |
| Tilt = primary input | Телефон как физический контроллер | Владельца |
| Deterministic world | Одинаковый seed = одинаковый мир | Владельца |
| Data-driven | Баланс в JSON, не в коде | Владельца |
| GameState = single source of truth | Все runtime state в одном месте | Владельца |
| EventBus для декомпозиции | Сигналы вместо хаотичных зависимостей | Владельца |
| GUT для тестов | Стандарт Godot | Владельца |
| No ship autopilot | Ручное управление — core fantasy | Владельца |
| No pay-to-win | Монетизация только косметика/удобство | Владельца |
| Camera2D inside Ship scene | Следует за кораблём автоматически | Владельца |
| SensorInput stub Phase 03 | Абстракция готова, активация в Phase 04 | Владельца |

---

## TBD

**НЕ РЕШАТЬ САМОСТОЯТЕЛЬНО.** Ожидают решения владельца:

- Exact Fuel / Supplies consumption formula (сейчас placeholder: 0.5/s at full speed)
- Exact damage formulas
- Contract reward formula
- Maximum offline progress cap
- Port fee specifics
- Full resource/goods catalog
- Pirate encounter mechanics
- Protection mechanic
- Storm mechanics
- Employee bonus values
- Port level progression
- Company level milestones
- Reputation system
- Achievement list
- Starter Pack contents
- Premium vs No Ads
- Custom Company Logo
- Maximum fleet size cap
- Automated route formulas
- Fleet auto-route income formula

---

## DEVELOPMENT RULES

- **Offline-first.** Никаких сетевых вызовов.
- **Deterministic world.** Фиксированный seed.
- **Data-driven.** Статические данные только в `data/*.json`.
- **Не менять концепцию.** Не добавлять фичи вне текущей Phase.
- **Не решать TBD.** Фиксировать в KNOWN ISSUES.
- **Не переписывать архитектуру.** Расширять существующие системы.
- **Phase gate.** Не переходить к следующей Phase без runtime sign-off.
- **SensorInput only.** Android accelerometer только в `systems/input/sensor_input.gd`.
- **No game logic in UI.** UI читает state, отправляет действия.
- **SaveSystem = единая точка I/O.**

---

*Last Updated: 2026-09-05 | Phase 03 — Ship Physics (pending runtime sign-off)*
