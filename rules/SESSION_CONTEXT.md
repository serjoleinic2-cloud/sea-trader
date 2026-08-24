# SEA TRADER -- SESSION CONTEXT

> Short handoff document for new AI sessions.
> Read this first, then rules/*. Do not start coding before reading.
> Last Updated: 2026-08-24

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

Игрок -- капитан грузового корабля на процедурно генерируемом море.
Ручное управление кораблем (tilt телефона).
Доставка грузов между портами, развитие торговой компании, расширение флота.
Каждый рейс -- лично, руками. Нет автопилота.

Коротко:
- Процедурный мир из seed (детерминированный).
- Ручное управление кораблем.
- Торговля и контракты между портами.
- Повреждения корабля от скорости/стихий/пиратов.
- Развитие компании: сотрудники, флот, офлайн-доход.
- Прогрессия: XP, уровни, репутация, ачивки.
- Монетизация: косметика, отключение рекламы. Без pay-to-win.

---

## CURRENT DEVELOPMENT METHOD

```
User (задание)
    |
    v
AI assistant (Claude / Kimi / другой)
    |
    v
Kimi (формулирует чистые таски для opencode, проверяет дубли, аудит)
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

**OpenCode: NOT USED CURRENTLY.**

---

## SOURCE OF TRUTH

Приоритет документов (сверху вниз):

1. `rules/TRUTH.md` -- принципы и ограничения проекта
2. `rules/GAME_RULES.md` -- non-negotiable правила
3. `rules/ARCHITECTURE.md` -- архитектура систем
4. `rules/SYSTEM_MAP.md` -- потоки данных
5. `rules/DATA_SCHEMA.md` -- модели данных
6. `rules/DEVELOPMENT_PHASES.md` -- план фаз
7. `rules/AI_DEVELOPMENT_RULES.md` -- правила для AI
8. `rules/PROJECT_STATE.md` -- текущее состояние

**При конфликте:**
- Не разрешать молча.
- Явно указать конфликт.
- Использовать TRUTH.md и GAME_RULES.md как авторитет.

---

## CURRENT PHASE

**Phase 02 -- World Generation**

Phase 01 (Foundation) завершена и проверена в runtime:
- Godot 4.x проект открывается без ошибок.
- GameState, EventBus, SaveSystem -- autoloads работают.
- Сохранение/загрузка, миграция, backup -- функциональны.

Phase 02 реализована:
- Детерминированная генерация мира из seed.
- Острова, порты, зоны опасностей (inactive).
- Placeholder визуализация (океан, острова, порты, зоны).
- Камера с WASD + zoom для отладки.
- 10 unit-тестов на генерацию.

**Ожидает runtime-проверки:** seed persistence, визуальная проверка, камера.

---

## COMPLETED

### Phase 01 -- Foundation
- Godot 4.x проект (`project.godot`)
- `autoloads/game_state.gd` -- 12 state-классов, `reset_to_defaults()`
- `autoloads/event_bus.gd` -- 24 сигнала
- `autoloads/save_system.gd` -- save/load/backup/migration, Vector2 сериализация
- Структура папок по `ARCHITECTURE.md`
- Placeholder JSON в `data/`
- GUT-совместимые unit-тесты

### Phase 02 -- World Generation
- `data/world/world_gen_config.json` -- параметры генерации
- `systems/world/world_generator.gd` -- детерминированная генерация
- `systems/world/world_renderer.gd` -- placeholder визуализация
- `scenes/game/world.tscn` -- сцена мира
- `scenes/game/main.tscn` -- обновлена с World + Camera2D
- `scripts/main.gd` -- инициализация мира, seed, камера
- `tests/unit/test_world_generation.gd` -- 10 тестов

---

## CURRENT TASK

Runtime-проверка Phase 02:
1. Закрыть проект, открыть снова -- мир тот же (seed persistence).
2. Output консоль Godot -- нет красных ошибок.
3. WASD и +/- -- камера двигается, зум работает.
4. Одинаковый seed -> одинаковый мир.

После проверки -- обновить `PROJECT_STATE.md` и подписать Phase 02.

---

## NEXT TASK

**Phase 03 -- Ship Physics**

Системы:
- `ShipPhysics` -- импульс, инерция, радиус поворота, визуальный наклон
- `ShipControl` -- прием нормализованных команд (-1..1)
- Клавиатурный ввод WASD для тестирования (tilt -- Phase 04)
- Сцена корабля с tilt-анимацией
- Обновление `ShipState.position/velocity`

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
| Dictionary-based state (Phase 01-02) | Гибкость, позже можно typed Resources | Владельца |
| GUT для тестов | Стандарт Godot, не кастомная система | Владельца |
| No ship autopilot | Ручное управление -- core fantasy | Владельца |
| No pay-to-win | Монетизация только косметика/удобство | Владельца |

---

## TBD

**НЕ РЕШАТЬ САМОСТОЯТЕЛЬНО.** Ожидают решения владельца:

- Fuel mechanic (ресурс vs абстрактная стоимость)
- Exact damage formulas
- Contract reward formula
- Maximum offline progress cap
- Port fee specifics
- Full resource/goods catalog
- Pirate encounter mechanics (combat? только уклонение?)
- Storm mechanics detail
- Employee bonus values
- Starter Pack contents
- Premium vs No Ads (один продукт или разные?)
- Custom company logo mechanic
- Maximum fleet size

---

## DEVELOPMENT RULES

- **Offline-first.** Никаких сетевых вызовов, backend, Firebase.
- **Deterministic world.** `RandomNumberGenerator` с фиксированным seed.
- **Data-driven.** Статические данные только в `data/*.json`. Не хардкодить в `.gd`.
- **Не менять концепцию.** Не добавлять фичи вне текущей Phase.
- **Не решать TBD.** Фиксировать в `KNOWN ISSUES`, не имплементировать.
- **Не переписывать архитектуру.** Расширять существующие системы, не создавать v2.
- **Phase gate.** Не переходить к следующей Phase без проверки текущей.
- **Update PROJECT_STATE.md.** После каждого значимого изменения.
- **Read rules/.** Перед изменением -- прочитать relevant документы.
- **No game logic in UI.** UI читает state, отправляет действия. Не считает цены/XP/урон.
- **SaveSystem = единая точка I/O.** Не писать файлы напрямую из других систем.
- **SensorInput only.** Android accelerometer только в `systems/input/sensor_input.gd`.

---

## HANDOFF INSTRUCTION

> **При начале новой AI-сессии:**
> 1. Сначала прочитать этот файл (`SESSION_CONTEXT.md`).
> 2. Затем актуальные документы из `rules/`.
> 3. Не начинать разработку, пока не определён `CURRENT PHASE` и `CURRENT TASK`.
> 4. Проверить `PROJECT_STATE.md` на актуальность.
> 5. Не предполагать, что предыдущая сессия завершила Phase -- проверить runtime.

---

*Last Updated: 2026-08-24 | Phase 02 -- World Generation (pending runtime sign-off)*
