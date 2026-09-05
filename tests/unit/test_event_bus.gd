extends "res://tests/test_base.gd"

var _signal_received: bool = false
var _received_pos: Vector2 = Vector2.ZERO

func test_event_bus_exists() -> void:
	assert_not_null(EventBus, "EventBus autoload should exist")

func test_ship_moved_connectable() -> void:
	var callable: Callable = Callable(self, "_on_ship_moved")
	EventBus.ship_moved.connect(callable)
	EventBus.ship_moved.disconnect(callable)
	assert_true(true, "ship_moved signal is connectable")

func test_ship_moved_fires() -> void:
	_signal_received = false
	var callable: Callable = Callable(self, "_on_ship_moved")
	EventBus.ship_moved.connect(callable)
	EventBus.ship_moved.emit(Vector2(10.0, 20.0), Vector2(1.0, 0.0))
	EventBus.ship_moved.disconnect(callable)
	assert_true(_signal_received, "ship_moved signal should fire")
	assert_eq(_received_pos, Vector2(10.0, 20.0), "received position should match emitted value")

func test_ship_damaged_connectable() -> void:
	var callable: Callable = Callable(self, "_on_ship_damaged")
	EventBus.ship_damaged.connect(callable)
	EventBus.ship_damaged.disconnect(callable)
	assert_true(true, "ship_damaged signal is connectable")

func _on_ship_moved(pos: Vector2, _vel: Vector2) -> void:
	_signal_received = true
	_received_pos = pos

func _on_ship_damaged(_component: String, _amount: float) -> void:
	pass
