# Карта работающих систем

Обновлено: 2026-09-19. Источник полного списка подключений — data/config/game_modules.json.

| Действие | Путь выполнения | Состояние |
| --- | --- | --- |
| Запуск | Main → GameData/ModuleLoader → SaveSystem → WorldGenerator → Ship → модули | Восстановленные разделы GameState |
| Ручное управление | SensorInput/InputAdapter → ShipControl → ShipPhysics | ship_state, world_state |
| Швартовка и маршрут | Main → PortSystem | ship_state, port_state, known_routes_state, player_state |
| Покупка, продажа, погрузка | PortWindow → CargoTransferSystem → TradeLineSystem при продаже | ship_state.cargo, port_state, деньги/статистика |
| Рейс основного судна | LogisticsWindow → LogisticsSystem → ActiveRouteAutopilot → PortSystem → CargoTransferSystem | voyage_state, ship_state, рынок/склад |
| Рейс флота | TradeLineSystem → FleetSystem → TradeLineSystem.settle_freight | fleet_state, economy_state, port_state |
| Стройка | Окно проекта → BuildingProjectSystem/ShipyardSystem | company_state, port_state, fleet_state |
| Производство | PortProductionSystem → рецепт | port_state.inventory |
| Наём | HiringWindow → HiringSystem; назначение → FleetSystem | employee_state, экипаж судна |
| Карьера | CareerSystem ← статистика GameState | Вычисляемые ранг и допуски |
| Челлендж | ChallengeWindow → ChallengeSystem → RewardSystem | economy_state.challenges/rewards |
| Бонус награды | RewardSystem → ShipPhysics / TradeLineSystem | Скорость / фактическая цена продажи |
| Сохранение | Система или жизненный цикл Main → SaveSystem | Версионированный JSON |

UI читает состояние и вызывает команды. PortWindow не списывает деньги или груз самостоятельно. NavigationHUD передаёт выбор назначения PortSystem. Закрытие и взаимное исключение рабочих окон обеспечивает WindowCoordinator.

Названия EconomyEngine, KnownRoutesSystem, CompanySystem из ранних проектных схем не обозначают существующие модули. Их обязанности частично реализованы перечисленными системами; не создавать дубли без конкретной причины.
