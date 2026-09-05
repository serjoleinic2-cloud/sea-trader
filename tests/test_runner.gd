extends Node

## TestRunner — runs all unit tests without GUT.
## Attach to a Node in tests/test_runner.tscn and run that scene.

const TEST_FILES: Array = [
	"res://tests/unit/test_game_state.gd",
	"res://tests/unit/test_event_bus.gd",
	"res://tests/unit/test_save_system.gd",
	"res://tests/unit/test_world_generation.gd",
	"res://tests/unit/test_ship_physics.gd",
	"res://tests/unit/test_sensor_input.gd",
]

var _total_pass: int = 0
var _total_fail: int = 0

func _ready() -> void:
	print("\n========== SEA TRADER TEST SUITE ==========")
	for path in TEST_FILES:
		_run_file(path)
	print("-------------------------------------------")
	print("TOTAL  pass=%d  fail=%d" % [_total_pass, _total_fail])
	print("===========================================\n")

func _run_file(path: String) -> void:
	var script: GDScript = load(path) as GDScript
	if script == null:
		push_error("TestRunner: cannot load " + path)
		_total_fail += 1
		return
	var instance: Node = script.new()
	if not instance.has_method("run_all"):
		push_error("TestRunner: no run_all() in " + path)
		instance.free()
		_total_fail += 1
		return
	add_child(instance)
	instance.run_all()
	_total_pass += instance.passed
	_total_fail += instance.failed
	instance.queue_free()
