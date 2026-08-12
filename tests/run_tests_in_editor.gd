extends Node
## In-editor test runner. Open `tests/run_tests_in_editor.tscn` and press F6.
##
## Exists so the suite can be run without a terminal or a configured PATH.
## Results appear in the editor's Output panel. CI still uses `run_tests.gd`,
## and both share `runner_core.gd`, so they can never report different things.

const RunnerCore := preload("res://tests/runner_core.gd")


func _ready() -> void:
	var result: Dictionary = RunnerCore.run_all()
	var passed: bool = RunnerCore.print_report(result)

	if passed:
		print("All green. Close this window to return to the editor.")
	else:
		# push_error surfaces in the editor's Errors panel as well as Output.
		push_error("Test suite failed: %d failure(s). See the Output panel." % result["failures"].size())

	# Give the editor a frame to flush the output before the window closes.
	await get_tree().process_frame
	get_tree().quit(0 if passed else 1)
