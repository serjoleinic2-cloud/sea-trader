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
Каждый рейс -- лично, руками. Нет автопилота на новых маршрутах.

Коротко:
- Процедурный мир из seed (детерминированный).
- Ручное управление кораблем -- основной gameplay.
- Первое прохождение маршрута -- всегда вручную.
- Известные маршруты -- можно автоматизировать (флот, будущие рейсы).
- Торговля и контракты между портами.
- Fuel / Supplies ограничивает дальность.
- Повреждения корабля от скорости/стихий/пиратов.
- Развитие компании: сотрудники, флот, офлайн-доход.
- Прогрессия: XP, уровни, репутация, ачивки, открытие маршрутов.
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

Phase 01 (Foundation) завершена и проверена в runtime.
Phase 02 реализована и визуально проверена (острова, порты, камера).

**Ожидает:** seed persistence check для финального sign-off.

---

## COMPLETED

### Phase 01 -- Foundation
- Godot 4.x проект, autoloads (GameState, EventBus, SaveSystem)
- Структура папок, placeholder JSON, GUT-тесты
- Runtime verified

### Phase 02 -- World Generation
- Детерминированная генерация мира из seed
- Острова, порты, зоны опасностей (inactive)
- Placeholder визуализация, камера WASD + zoom
- 10 unit-тестов
- Runtime verified (визуально)

### Documentation (2026-08-24)
- Утверждены новые решения: Two Travel Modes, Route Discovery, Fuel/Supplies, Save During Voyage, Risk Levels, Intermediary Ports
- Все rules-файлы синхронизированы

---

## CURRENT TASK

Runtime-проверка Phase 02: seed persistence (закрыть/открыть проект -- мир тот же).

---

## NEXT TASK

**Phase 03 -- Ship Physics**
- ShipPhysics, ShipControl, клавиатурный ввод, сцена корабля

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
| **Manual Voyage = primary** | Личное управление -- основа игры | Владельца |
| **Known Routes for automation** | Исследование первое, автоматизация -- награда | Владельца |
| **Save during voyage** | Уважение к времени игрока | Владельца |
| **No punishment for exit** | Корабль не тонет при закрытии приложения | Владельца |
| **Fuel / Supplies limits range** | Ресурс дальности, пополняется в портах | Владельца |

---

## TBD

**НЕ РЕШАТЬ САМОСТОЯТЕЛЬНО.** Ожидают решения владельца:

- Exact Fuel / Supplies consumption formula
- Exact damage formulas
- Contract reward formula (time-bonus)
- Maximum offline progress cap
- Port fee specifics
- Full resource/goods catalog
- Pirate encounter mechanics (frequency, behavior, combat or avoidance?)
- Protection mechanic
- Storm mechanics detail
- Exact employee bonus values per role
- Port level progression path
- Company level milestones
- Reputation system specifics
- Achievement list
- Starter Pack contents
- Premium vs No Ads (same or separate?)
- Custom Company Logo mechanic
- Maximum fleet size cap
- Exact automated route risk formula
- Exact automated route duration formula
- Exact speed bonus formula for urgent contracts
- Fleet auto-route income formula
- Multiplayer (out of scope)

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
- **No game logic in UI.** UI читает state, отправляет действия.
- **SaveSystem = единая точка I/O.** Не писать файлы напрямую.
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

*Last Updated: 2026-08-24 | Phase 02 -- World Generation (pending seed persistence sign-off)*
