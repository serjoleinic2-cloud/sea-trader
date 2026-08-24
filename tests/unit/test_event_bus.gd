extends GutTest

func test_event_bus_exists():
	assert_not_null(EventBus, "EventBus autoload should exist")

func test_signals_defined():
	# Verify key signals are connectable
	var callable: Callable = Callable(self, "_on_test_signal")
	EventBus.ship_moved.connect(callable)
	EventBus.ship_moved.disconnect(callable)
	assert_true(true, "ship_moved signal should be connectable")

func _on_test_signal(_pos: Vector2, _vel: Vector2) -> void:
	pass
