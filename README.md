# Sea Trader

Схематический прототип морской торговли на Godot 4. Основная игра работает офлайн. Финальный визуал и 3D — следующий этап.

- [Где менять параметры и как добавить модуль](rules/DEVELOPER_GUIDE.md)
- [Фактическое состояние и ограничения](rules/PROJECT_STATE.md)
- [Архитектура](rules/ARCHITECTURE.md)
- [Челленджи, награды и будущий магазин](rules/CHALLENGES_AND_MARKET.md)
- [Остальная документация](rules/README.md)

Открыть `project.godot` в Godot и запустить `scenes/game/main.tscn` (F6) либо проект (F5). Проверенная автоматическими тестами версия движка — 4.4.1; отображение на Windows проверяется отдельно.

В PowerShell из папки проекта:

```powershell
git fetch origin
git switch codex/persistent-state-foundation
git pull --ff-only
```

После изменения JSON перезапустить игру: определения кэшируются на время запуска. Не удалять сохранения для применения изменений.

Для разработчика на Linux: `GODOT_BIN=/path/to/godot bash tests/run_tests.sh`. Тесты используют отдельный временный каталог и не затрагивают игровые сохранения.
