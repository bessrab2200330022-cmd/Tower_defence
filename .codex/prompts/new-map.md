# Prompt: add a map

Add a new map called **`<NAME>`**.

Design intent: `<what does this map ask of the player that The Crossing doesn't? longer route? fewer build spots? a chokepoint?>`

## Requirements

1. Create `data/maps/<id>.layout.txt` — the ASCII board. Rows must all be the same length, with exactly one `S` and one `G`.

   ```
   .  buildable ground      #  enemy path
   X  blocked scenery       S  spawn (walkable)      G  goal (walkable)
   ```

2. Create `data/maps/<id>.tres` pointing at it via `layout_path`, following `data/maps/crossing.tres`.
3. Verify the route is contiguous and reachable — `PathFinder` uses 4-neighbour movement, so diagonal "connections" are not connections. Two path corridors that run adjacent to each other will merge and short-circuit the route; check for that.
4. Tune `starting_credits` and `starting_lives` for the map's length. A longer route means more tower uptime per enemy, so it can afford a tighter budget.
5. Add a test in `tests/cases/test_content.gd` (or a new suite) that loads the map, builds a path, and asserts the route length is what you intended.

## Done when

- `MapDef.is_valid()` returns `""` for the new map
- `PathFinder.build()` succeeds from spawn to goal
- An undefended wave 1 costs lives, and a modestly defended wave 1 survives — the two smoke tests in `test_content.gd` are the pattern to copy
- The test suite exits 0
