extends RefCounted
## Shared test-running logic.
##
## Two front ends use this: `run_tests.gd` (headless CLI, exit code is the gate)
## and `run_tests_in_editor.tscn` (press F6 in the Godot editor, no terminal).
## Keeping the discovery and reporting in one place means they can never drift.

const CASE_DIR := "res://tests/cases"


## Discovers and runs every suite in tests/cases/.
## Returns { suites, tests, assertions, failures: Array[String], lines: Array[String] }.
static func run_all() -> Dictionary:
	var lines: Array[String] = []
	var failures: Array[String] = []
	var total_assertions: int = 0
	var total_tests: int = 0
	var suites: int = 0

	var file_names: Array = Array(DirAccess.get_files_at(CASE_DIR))
	file_names.sort()

	for raw_name in file_names:
		var file_name: String = str(raw_name)
		if file_name.ends_with(".remap"):
			file_name = file_name.trim_suffix(".remap")
		if not file_name.ends_with(".gd"):
			continue

		var script: GDScript = load("%s/%s" % [CASE_DIR, file_name])
		if script == null:
			failures.append("%s - failed to load" % file_name)
			lines.append("  [FAIL] %-30s could not be loaded" % file_name)
			continue

		var suite = script.new()
		var suite_failures: Array = suite.run()
		suites += 1
		total_assertions += suite.assertions
		total_tests += suite.tests_run

		var status: String = "ok" if suite_failures.is_empty() else "FAIL"
		lines.append("  [%4s] %-30s %2d tests, %3d assertions" % [status, file_name, suite.tests_run, suite.assertions])
		for failure in suite_failures:
			failures.append(str(failure))

	return {
		"suites": suites,
		"tests": total_tests,
		"assertions": total_assertions,
		"failures": failures,
		"lines": lines,
	}


## Prints a full report. Returns true if everything passed.
static func print_report(result: Dictionary) -> bool:
	print("")
	print("Running suites from %s" % CASE_DIR)
	print("--------------------------------------------------------------")
	for line in result["lines"]:
		print(line)
	print("--------------------------------------------------------------")

	var failures: Array = result["failures"]
	if failures.is_empty():
		print("PASS  %d suites, %d tests, %d assertions" % [result["suites"], result["tests"], result["assertions"]])
		print("")
		return true

	print("FAIL  %d failure(s):" % failures.size())
	for failure in failures:
		print("  - %s" % failure)
	print("")
	return false
