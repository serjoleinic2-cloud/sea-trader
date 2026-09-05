extends Node

## TestBase — replaces GutTest. No external dependencies.
## Usage: extends "res://tests/test_base.gd"
## Name test functions starting with test_

var passed: int = 0
var failed: int = 0
var errors: Array = []
var _current_test: String = ""

func run_all() -> void:
	before_all()
	var methods: Array = []
	for m in get_method_list():
		if m["name"].begins_with("test_"):
			methods.append(m["name"])
	methods.sort()
	for method in methods:
		_current_test = method
		before_each()
		call(method)
		after_each()
	after_all()
	var status: String = "OK" if failed == 0 else "FAIL"
	print("[%s] %s  pass=%d fail=%d" % [
		status,
		get_script().resource_path.get_file(),
		passed, failed
	])

func before_all() -> void: pass
func after_all()  -> void: pass
func before_each() -> void: pass
func after_each()  -> void: pass

func assert_true(value: bool, msg: String = "") -> void:
	if value:
		passed += 1
	else:
		failed += 1
		_record("assert_true FAILED: " + msg)

func assert_false(value: bool, msg: String = "") -> void:
	assert_true(not value, msg if msg != "" else "expected false")

func assert_eq(a: Variant, b: Variant, msg: String = "") -> void:
	if a == b:
		passed += 1
	else:
		failed += 1
		_record("assert_eq FAILED [%s != %s]: %s" % [str(a), str(b), msg])

func assert_ne(a: Variant, b: Variant, msg: String = "") -> void:
	if a != b:
		passed += 1
	else:
		failed += 1
		_record("assert_ne FAILED [both == %s]: %s" % [str(a), msg])

func assert_gt(a: Variant, b: Variant, msg: String = "") -> void:
	if a > b:
		passed += 1
	else:
		failed += 1
		_record("assert_gt FAILED [%s not > %s]: %s" % [str(a), str(b), msg])

func assert_lt(a: Variant, b: Variant, msg: String = "") -> void:
	if a < b:
		passed += 1
	else:
		failed += 1
		_record("assert_lt FAILED [%s not < %s]: %s" % [str(a), str(b), msg])

func assert_gte(a: Variant, b: Variant, msg: String = "") -> void:
	if a >= b:
		passed += 1
	else:
		failed += 1
		_record("assert_gte FAILED [%s not >= %s]: %s" % [str(a), str(b), msg])

func assert_lte(a: Variant, b: Variant, msg: String = "") -> void:
	if a <= b:
		passed += 1
	else:
		failed += 1
		_record("assert_lte FAILED [%s not <= %s]: %s" % [str(a), str(b), msg])

func assert_almost_eq(a: float, b: float, tol: float, msg: String = "") -> void:
	if absf(a - b) <= tol:
		passed += 1
	else:
		failed += 1
		_record("assert_almost_eq FAILED [|%s-%s|>%s]: %s" % [str(a), str(b), str(tol), msg])

func assert_not_null(value: Variant, msg: String = "") -> void:
	if value != null:
		passed += 1
	else:
		failed += 1
		_record("assert_not_null FAILED: " + msg)

func assert_has(dict: Dictionary, key: String, msg: String = "") -> void:
	if dict.has(key):
		passed += 1
	else:
		failed += 1
		_record("assert_has FAILED [key '%s' missing]: %s" % [key, msg])

func _record(msg: String) -> void:
	var full: String = "%s::%s — %s" % [
		get_script().resource_path.get_file(),
		_current_test,
		msg
	]
	errors.append(full)
	push_warning(full)
