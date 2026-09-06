# EVENT BUS — PATCH для Phase 05
# Добавь эти три сигнала в существующий autoloads/event_bus.gd
# если их там ещё нет.
#
# Найди в event_bus.gd раздел с сигналами и добавь:

signal port_discovered(port_id: String)   # первое обнаружение порта
signal port_entered(port_id: String)      # повторный вход в известный порт
signal port_exited(port_id: String)       # выход из радиуса порта

# Это НЕ отдельный файл для замены — это инструкция.
# Сам файл event_bus.gd не заменяй целиком — только добавь эти строки.
