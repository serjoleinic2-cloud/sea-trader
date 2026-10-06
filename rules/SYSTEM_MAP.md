# Карта работающих систем

Обновлено: 2026-10-06. Источник полного списка подключений — data/config/game_modules.json.

Последняя правка домашней базы: гильдия магов открывает прямую кнопку перехода в оборону, а окно гарнизона показывает последовательность установки кристалла в башню. Позиции зданий на сцене задаются `data/world/home_base_visuals.json`; эти координаты влияют только на визуальную компоновку домашнего острова.

Последняя UI-связка: `HarborTownView` показывает на двух свободных домашних площадках **Дом капитанов** и **Казармы**. Они открывают существующие `HiringWindow` и `GarrisonWindow`; верхняя кнопка «Гарнизон» удалена, а переход из гильдии магов остаётся общим. `HiringWindow`/`CrewWindow` выбирают арты капитанов и офицеров из расовых папок с атласом как запасным источником.

Дрейфующие находки подключены через `WindowCoordinator → DebrisResearchHUD`: 22 детерминированных по seed ящика, бочки и обломка; при приближении появляется удержание F или экранной кнопки и круговой прогресс. После сбора ID сохраняется в `GameState.world_state`, а деньги, материал и свиток обучения сразу поступают на домашнюю базу.

| Действие | Путь выполнения | Состояние |
| --- | --- | --- |
| Новый запуск | Main → GameData (каталог шести народов) → RaceSelectionScreen (шесть капитанов: галерея → досье → предупреждение → подтверждение) → GameState.player_state.origin_race_id → SaveSystem → WorldGenerator → Ship → модули | Выбор необратим в этом сохранении; раса, мир и остальные разделы GameState |
| Продолжение | Main → GameData/ModuleLoader → SaveSystem → WorldGenerator → Ship → модули | Восстановленные разделы GameState; старым сохранениям назначается постоянная раса по умолчанию |
| Ручное управление | SensorInput/InputAdapter → ShipControl → ShipPhysics | ship_state, world_state |
| Исследование океана | Main → WorldGenerator.generate_chunk → PortSystem / Approach3DView | Seed-карта, известные области и текущая 3D-геометрия |
| Швартовка и маршрут | Main → PortSystem | ship_state, port_state, known_routes_state, player_state |
| Покупка, продажа, погрузка | PortWindow → CargoTransferSystem → TradeLineSystem при продаже | ship_state.cargo, port_state, деньги/статистика |
| Рейс основного судна | LogisticsWindow → LogisticsSystem → ActiveRouteAutopilot → PortSystem → CargoTransferSystem | voyage_state, ship_state, рынок/склад |
| Рейс флота | TradeLineSystem → FleetSystem → TradeLineSystem.settle_freight | fleet_state, economy_state, port_state |
| Стройка и улучшение | Окно проекта без ползунков → BuildingProjectSystem/ShipyardSystem → ConstructionMaterials → SaveSystem | company_state, port_state.inventory, fleet_state; списание при запуске, учёт старых резервов |
| Военное сопровождение | FleetWindow → MilitaryTransportSystem → ручной выбор общего порта / движение каждый кадр | fleet_state.escort_enabled/escort_state; погрузка войск остаётся на базе |
| Производство | PortProductionSystem → рецепт | port_state.inventory |
| Наём | HiringWindow → HiringSystem; назначение → FleetSystem | employee_state, экипаж судна |
| Карьера | CareerSystem ← статистика GameState | Вычисляемые ранг и допуски |
| Челлендж | ChallengeWindow → ChallengeSystem → RewardSystem | economy_state.challenges/rewards |
| Гарнизон и бой | GarrisonWindow → CombatSystem → GameState/SaveSystem | combat_state; скрытый бой и сохранённая сводка |
| Бонус награды | RewardSystem → ShipPhysics / TradeLineSystem | Скорость / фактическая цена продажи |
| Сохранение | Система или жизненный цикл Main → SaveSystem | Версионированный JSON |

UI читает состояние и вызывает команды. PortWindow не списывает деньги или груз самостоятельно. NavigationHUD передаёт выбор назначения PortSystem. Закрытие и взаимное исключение рабочих окон обеспечивает WindowCoordinator.

Названия EconomyEngine, KnownRoutesSystem, CompanySystem из ранних проектных схем не обозначают существующие модули. Их обязанности частично реализованы перечисленными системами; не создавать дубли без конкретной причины.
