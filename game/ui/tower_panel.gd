extends PanelContainer
## Inspection and upgrade panel for one placed tower.
##
## Reads simulation state and emits requests; it never mutates anything. Every
## number on it comes from `TowerState` or the tower's `TowerDef`, so it cannot
## drift from what the sim will actually do - the sell figure in particular is
## computed with the same call `Simulation.try_sell()` pays out with, rather than
## with a copy of the formula.
##
## ## Speculative half
##
## The upgrade section is written against a schema `sim/` and `data/` do not have
## yet: `TowerDef.upgrade_ids` and `TowerDef.tier`, and an
## `apply_command("upgrade", {"tower_id", "def_id"})` the simulation does not
## accept. Every read of those is guarded by an existence check, so today the
## panel shows inspection only and the upgrade row is simply absent. When the
## schema lands the row appears with no change here.
##
## Deliberately NOT included: target-mode controls. `Simulation.set_target_mode()`
## exists and has never been driven from the UI, but docs/design/upgrades.md 8
## is explicit that it is its own backlog item and this panel is "nothing else".

signal upgrade_requested(tower_id: int, def_id: String)
signal sell_requested(cell: Vector2i)

const Economy := preload("res://sim/economy.gd")

const PANEL_WIDTH: float = 296.0

const COLOR_TITLE := Color(0.92, 0.95, 1.0)
const COLOR_LABEL := Color(0.62, 0.70, 0.80)
const COLOR_VALUE := Color(0.92, 0.95, 1.0)
const COLOR_BETTER := Color(0.45, 0.95, 0.55)
const COLOR_WORSE := Color(0.98, 0.45, 0.42)
const COLOR_COST := Color(0.98, 0.85, 0.45)

## Fields previewed in an upgrade's stat diff, in display order:
##   key, label, higher_is_better, format
## These are exactly the columns of the tier tables in
## docs/design/upgrades.md 4-6. A field the two tiers share is not shown - a diff
## listing eight unchanged rows hides the two that moved.
const DIFF_FIELDS: Array = [
	{"key": "damage", "label": "Damage", "up": true, "fmt": "%d"},
	{"key": "fire_interval_ticks", "label": "Interval", "up": false, "fmt": "%dt"},
	{"key": "range_world", "label": "Range", "up": true, "fmt": "%.1f"},
	{"key": "splash_radius", "label": "Splash", "up": true, "fmt": "%.1f"},
	{"key": "slow_percent", "label": "Slow", "up": true, "fmt": "%d%%"},
	{"key": "slow_ticks", "label": "Slow time", "up": true, "fmt": "%dt"},
]

var sim
var catalog

var _cell: Vector2i = Vector2i(-1, -1)
## The def the upgrade rows were last built for. Rebuilding a Button every frame
## would eat its own click, so the rows are rebuilt only when the tier changes.
var _rows_def_id: String = ""

var _title: Label
var _subtitle: Label
var _stats: GridContainer
var _stat_values: Dictionary = {}
var _upgrade_box: VBoxContainer
var _sell_button: Button


func build(simulation, catalog_ref) -> void:
	sim = simulation
	catalog = catalog_ref

	custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	visible = false

	# PanelContainer draws its background tight to its content, so without this
	# every label sits flush against the panel edge.
	var inset := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		inset.add_theme_constant_override(str(side), 12)
	add_child(inset)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	inset.add_child(column)

	_title = _label("", COLOR_TITLE, 20)
	column.add_child(_title)

	_subtitle = _label("", COLOR_LABEL, 13)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_subtitle)

	column.add_child(HSeparator.new())

	_stats = GridContainer.new()
	_stats.columns = 2
	_stats.add_theme_constant_override("h_separation", 14)
	column.add_child(_stats)
	for key in ["DPS", "Damage", "Range", "Kills", "Damage dealt", "Invested"]:
		_stats.add_child(_label(str(key), COLOR_LABEL, 14))
		var value := _label("-", COLOR_VALUE, 14)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_stats.add_child(value)
		_stat_values[str(key)] = value

	_upgrade_box = VBoxContainer.new()
	_upgrade_box.add_theme_constant_override("separation", 6)
	column.add_child(_upgrade_box)

	_sell_button = Button.new()
	_sell_button.custom_minimum_size = Vector2(0.0, 34.0)
	_sell_button.pressed.connect(_on_sell)
	column.add_child(_sell_button)


# ---------------------------------------------------------------------------
# Selection
# ---------------------------------------------------------------------------

func inspect(cell: Vector2i) -> void:
	_cell = cell
	_rows_def_id = ""
	refresh()


func close() -> void:
	_cell = Vector2i(-1, -1)
	_rows_def_id = ""
	visible = false


func inspected_cell() -> Vector2i:
	return _cell


# ---------------------------------------------------------------------------
# Per-frame
# ---------------------------------------------------------------------------

## Called every frame from hud.gd. Cheap: it writes label text and button states
## and only reconstructs the upgrade rows when the tower's def actually changes,
## which happens once per purchase.
func refresh() -> void:
	if sim == null or _cell.x < 0:
		visible = false
		return

	var tower = sim.tower_at(_cell)
	if tower == null:
		# Sold, or the match reset under us.
		close()
		return

	var def = catalog.get_tower(str(tower.def_id))
	if def == null:
		close()
		return

	visible = true
	_title.text = str(def.display_name)
	_subtitle.text = _tier_line(def)

	_stat_values["DPS"].text = "%.0f" % tower.nominal_dps()
	_stat_values["Damage"].text = "%d %s" % [tower.damage, _damage_type_name(tower.damage_type)]
	_stat_values["Range"].text = "%.1f" % tower.range_world
	_stat_values["Kills"].text = str(tower.kills)
	_stat_values["Damage dealt"].text = str(tower.damage_dealt)
	_stat_values["Invested"].text = "%d cr" % tower.credits_invested

	var refund: int = Economy.refund_for(tower.credits_invested, _refund_percent(def))
	_sell_button.text = "Sell   +%d cr" % refund

	if _rows_def_id != str(def.id):
		_rows_def_id = str(def.id)
		_rebuild_upgrade_rows(tower, def)
	_refresh_upgrade_affordability()


func _tier_line(def) -> String:
	var tier: int = _int_field(def, "tier", 0)
	if tier <= 0:
		return str(def.description)
	return "Tier %d" % tier


# ---------------------------------------------------------------------------
# Upgrades
# ---------------------------------------------------------------------------

## One button per available upgrade. The design calls for a single button at
## tiers 1-2 and a two-option choice at the fork; that shape is entirely in the
## data - `upgrade_ids` has one entry or two - so there is no branch here.
func _rebuild_upgrade_rows(tower, def) -> void:
	for child in _upgrade_box.get_children():
		_upgrade_box.remove_child(child)
		child.queue_free()

	var options: Array = _upgrade_ids(def)
	if options.is_empty():
		return

	_upgrade_box.add_child(HSeparator.new())
	var heading: String = "Upgrade" if options.size() == 1 else "Choose a specialisation"
	_upgrade_box.add_child(_label(heading, COLOR_LABEL, 13))

	for option_id in options:
		var target = catalog.get_tower(str(option_id))
		if target == null:
			# A branch whose .tres has not been authored yet. Skip it rather than
			# offering a button that cannot resolve.
			continue
		_upgrade_box.add_child(_upgrade_row(tower, def, target))


func _upgrade_row(_tower, current, target) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var button := Button.new()
	button.custom_minimum_size = Vector2(0.0, 32.0)
	button.text = "%s   %d cr" % [str(target.display_name), int(target.cost)]
	button.tooltip_text = str(target.description)
	button.pressed.connect(_on_upgrade.bind(str(target.id)))
	button.set_meta("upgrade_def_id", str(target.id))
	button.set_meta("upgrade_description", str(target.description))
	row.add_child(button)

	var diff: String = _diff_text(current, target)
	if diff != "":
		var line := _label(diff, COLOR_VALUE, 12)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(line)
	return row


## A compact "what changes" line: only fields that differ, each with its
## direction. The player is choosing between two branches, so the useful
## information is the delta, not the absolute stat block they already have above.
func _diff_text(current, target) -> String:
	var parts: PackedStringArray = PackedStringArray()

	var before_dps: float = _nominal_dps(current)
	var after_dps: float = _nominal_dps(target)
	if not is_equal_approx(before_dps, after_dps):
		parts.append("DPS %.0f->%.0f%s" % [before_dps, after_dps, _flag(after_dps > before_dps)])

	for entry in DIFF_FIELDS:
		var field: Dictionary = entry
		var key: String = str(field["key"])
		if not (key in current) or not (key in target):
			continue
		var before = current.get(key)
		var after = target.get(key)
		if typeof(before) == TYPE_FLOAT:
			if is_equal_approx(float(before), float(after)):
				continue
		elif before == after:
			continue
		var better: bool = (float(after) > float(before)) == bool(field["up"])
		parts.append("%s %s->%s%s" % [
			str(field["label"]),
			str(field["fmt"]) % before,
			str(field["fmt"]) % after,
			_flag(better),
		])

	return "   ".join(parts)


## Marks only the fields that get WORSE.
##
## Not colour: the palette already leans on colour alone to carry armour type,
## which ROADMAP Phase 4 names as a real accessibility problem, and adding a
## second colour-only channel here would make that worse. Not an up/down arrow
## either - most fields on an upgrade improve, so flagging every one of them
## makes the single regression harder to spot, not easier. A branch that trades
## slow duration for damage is exactly what the player needs pointed out.
static func _flag(better: bool) -> String:
	return "" if better else " (down)"


## Greys a button the simulation would refuse, and puts the refusal on the
## tooltip.
##
## The reason comes from `Simulation.upgrade_blocked_reason()` rather than from a
## credit check here. Re-deriving "can I afford this" in the UI is how a button
## ends up enabled for a purchase the sim then rejects: the sim knows about the
## ladder rule and the match being over as well as the price, and a copy of that
## logic in the panel would be a second set of rules to keep in step.
func _refresh_upgrade_affordability() -> void:
	var tower = sim.tower_at(_cell)
	if tower == null:
		return
	for row in _upgrade_box.get_children():
		for child in row.get_children():
			if not (child is Button and child.has_meta("upgrade_def_id")):
				continue
			var def_id: String = str(child.get_meta("upgrade_def_id"))
			var reason: String = _blocked_reason(int(tower.id), def_id)
			child.disabled = reason != ""
			if reason != "":
				child.tooltip_text = reason
			else:
				child.tooltip_text = str(child.get_meta("upgrade_description"))


## `upgrade_blocked_reason` arrived with the sim's upgrade command. Falling back
## to a plain affordability check keeps this panel working against a simulation
## that does not have it.
func _blocked_reason(tower_id: int, def_id: String) -> String:
	if sim.has_method("upgrade_blocked_reason"):
		return str(sim.upgrade_blocked_reason(tower_id, def_id))
	var target = catalog.get_tower(def_id)
	if target != null and not sim.economy.can_afford(int(target.cost)):
		return "not enough credits"
	return ""


# ---------------------------------------------------------------------------
# Schema probes
# ---------------------------------------------------------------------------

## `TowerDef.upgrade_ids` does not exist yet. Asking whether the property is
## there - rather than assuming - is what makes this panel inert instead of
## broken while the schema is in flight.
func _upgrade_ids(def) -> Array:
	if def == null or not ("upgrade_ids" in def):
		return []
	var raw = def.get("upgrade_ids")
	if raw == null:
		return []
	var out: Array = []
	for value in raw:
		var id: String = str(value)
		if id != "":
			out.append(id)
	return out


static func _int_field(def, field: String, fallback: int) -> int:
	if def == null or not (field in def):
		return fallback
	return int(def.get(field))


## The percentage the simulation will actually pay. Read from the def rather than
## hardcoded, because `Simulation.try_sell()` reads it from the def - a constant
## here would be a second source of truth for a number the player is shown before
## they commit to it.
static func _refund_percent(def) -> int:
	return _int_field(def, "sell_refund_percent", 70)


## Mirrors TowerState.nominal_dps() for a def, which has the same two fields but
## is not a TowerState.
static func _nominal_dps(def) -> float:
	var interval: int = maxi(int(def.fire_interval_ticks), 1)
	return float(def.damage) * 60.0 / float(interval)


static func _damage_type_name(damage_type: int) -> String:
	match damage_type:
		0:
			return "kinetic"
		1:
			return "energy"
		2:
			return "explosive"
	return "?"


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _on_upgrade(def_id: String) -> void:
	var tower = sim.tower_at(_cell)
	if tower == null:
		return
	upgrade_requested.emit(int(tower.id), def_id)


func _on_sell() -> void:
	sell_requested.emit(_cell)


static func _label(text: String, color: Color, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	return label
