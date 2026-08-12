extends SceneTree
## Headless test runner.
##
##   godot --headless --path . --script res://tests/run_tests.gd
##
## Exits 0 when everything passes, 1 otherwise, so CI and agents can rely on the
## exit code rather than scraping stdout.
##
## No terminal handy? Open `tests/run_tests_in_editor.tscn` in the Godot editor
## and press F6 — same suites, results in the Output panel.

const RunnerCore := preload("res://tests/runner_core.gd")


func _initialize() -> void:
	var result: Dictionary = RunnerCore.run_all()
	var passed: bool = RunnerCore.print_report(result)
	quit(0 if passed else 1)
