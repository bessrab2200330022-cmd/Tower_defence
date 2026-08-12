extends RefCounted
## Minimal xUnit-style base class.
##
## Deliberately zero third-party dependencies: the only thing a fresh checkout
## needs to run the suite is the Godot binary. Subclass, add `test_*` methods,
## drop the file in `tests/cases/`. The runner finds it automatically.

var failures: Array[String] = []
var assertions: int = 0
var tests_run: int = 0

var _current: String = ""


## Override for per-test setup.
func before_each() -> void:
	pass


## Override for per-test teardown.
func after_each() -> void:
	pass


func run() -> Array[String]:
	failures = []
	assertions = 0
	tests_run = 0

	var names: Array[String] = []
	for method in get_method_list():
		var method_name: String = str(method["name"])
		if method_name.begins_with("test_") and not names.has(method_name):
			names.append(method_name)
	names.sort()

	for method_name in names:
		_current = method_name
		tests_run += 1
		before_each()
		callv(method_name, [])
		after_each()

	return failures


func suite_name() -> String:
	var path: String = get_script().resource_path
	return path.get_file().trim_suffix(".gd")


# ---------------------------------------------------------------------------
# Assertions
# ---------------------------------------------------------------------------

func _fail(message: String) -> void:
	failures.append("%s::%s - %s" % [suite_name(), _current, message])


func assert_true(condition: bool, message: String = "") -> void:
	assertions += 1
	if not condition:
		_fail("expected true. %s" % message)


func assert_false(condition: bool, message: String = "") -> void:
	assertions += 1
	if condition:
		_fail("expected false. %s" % message)


func assert_eq(actual, expected, message: String = "") -> void:
	assertions += 1
	if actual != expected:
		_fail("expected %s, got %s. %s" % [str(expected), str(actual), message])


func assert_ne(actual, unexpected, message: String = "") -> void:
	assertions += 1
	if actual == unexpected:
		_fail("expected value different from %s. %s" % [str(unexpected), message])


func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.0001, message: String = "") -> void:
	assertions += 1
	if absf(actual - expected) > tolerance:
		_fail("expected %f +/- %f, got %f. %s" % [expected, tolerance, actual, message])


func assert_gt(actual, threshold, message: String = "") -> void:
	assertions += 1
	if not (actual > threshold):
		_fail("expected %s > %s. %s" % [str(actual), str(threshold), message])


func assert_lt(actual, threshold, message: String = "") -> void:
	assertions += 1
	if not (actual < threshold):
		_fail("expected %s < %s. %s" % [str(actual), str(threshold), message])


func assert_null(value, message: String = "") -> void:
	assertions += 1
	if value != null:
		_fail("expected null, got %s. %s" % [str(value), message])


func assert_not_null(value, message: String = "") -> void:
	assertions += 1
	if value == null:
		_fail("expected non-null. %s" % message)


func assert_empty(value, message: String = "") -> void:
	assertions += 1
	if value.size() != 0:
		_fail("expected empty, got %s. %s" % [str(value), message])
