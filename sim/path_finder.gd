class_name PathFinder
extends RefCounted
## Breadth-first search over walkable grid cells.
##
## Uniform step cost, 4-neighbour movement, so BFS is optimal and cheaper than
## A*. Neighbour order is fixed (see SimGrid.neighbours4) which makes the chosen
## path identical on every run - required for determinism.

const UNREACHABLE: int = -1

## distance_field[index] = number of steps from that cell to the goal.
var distance_field: PackedInt32Array = PackedInt32Array()
## Ordered waypoints from spawn to goal, inclusive of both.
var path: Array[Vector2i] = []
var last_error: String = ""


## Returns true if a path exists. Populates `path` and `distance_field`.
func build(grid, start: Vector2i, goal: Vector2i) -> bool:
	path = []
	last_error = ""
	distance_field = PackedInt32Array()
	distance_field.resize(grid.width * grid.height)
	distance_field.fill(UNREACHABLE)

	if not grid.in_bounds(start) or not grid.in_bounds(goal):
		last_error = "start or goal outside grid"
		return false
	if not grid.is_walkable(start) or not grid.is_walkable(goal):
		last_error = "start or goal is not a walkable cell"
		return false

	# Flood from the goal so the field doubles as a "steps remaining" heatmap.
	var queue: Array[Vector2i] = [goal]
	distance_field[grid.index_of(goal)] = 0
	var head: int = 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		var current_distance: int = distance_field[grid.index_of(current)]
		for n in grid.neighbours4(current):
			if not grid.is_walkable(n):
				continue
			var ni: int = grid.index_of(n)
			if distance_field[ni] != UNREACHABLE:
				continue
			distance_field[ni] = current_distance + 1
			queue.append(n)

	if distance_field[grid.index_of(start)] == UNREACHABLE:
		last_error = "no walkable route from start to goal"
		return false

	# Walk downhill from start to goal.
	var cursor: Vector2i = start
	path.append(cursor)
	var guard: int = grid.width * grid.height + 1
	while cursor != goal and guard > 0:
		guard -= 1
		var best: Vector2i = cursor
		var best_distance: int = distance_field[grid.index_of(cursor)]
		for n in grid.neighbours4(cursor):
			if not grid.is_walkable(n):
				continue
			var d: int = distance_field[grid.index_of(n)]
			if d != UNREACHABLE and d < best_distance:
				best_distance = d
				best = n
		if best == cursor:
			last_error = "path walk stalled at %s" % str(cursor)
			path = []
			return false
		cursor = best
		path.append(cursor)

	if cursor != goal:
		last_error = "path walk exceeded guard limit"
		path = []
		return false
	return true


func steps_to_goal(grid, cell: Vector2i) -> int:
	if not grid.in_bounds(cell):
		return UNREACHABLE
	var i: int = grid.index_of(cell)
	if i < 0 or i >= distance_field.size():
		return UNREACHABLE
	return distance_field[i]


## Total world-space length of the path, used for pacing and wave budgeting.
func world_length(grid) -> float:
	if path.size() < 2:
		return 0.0
	return float(path.size() - 1) * grid.cell_size
