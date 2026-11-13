extends CanvasLayer
const PlaneData = preload("res://plane_data.gd")

signal changed
signal fee_paid(label: String, amount: float, where: String)

const RATES := [0.0, 0.5, 1.0]
const VISIT_DAYS := 4.0
const BASE_DEMAND := 0.6
const DEMAND_GROWTH := 1.06
const STAFF_INTAKE := 1.5
const DEPARTURE_TAX := 25.0
const WAGE := 1.2
const HANGAR_UPKEEP := 1.0
const RUNWAY_UPKEEP := 1.5
const BASE_COST := 6.0
const ARRIVAL_CHANCE := 0.5
const DEBT_DAYS_LIMIT := 30
const MAX_HANGARS := 6
const MAX_RUNWAY := 3
const MAX_WAITING := 3
const MAX_STAFF := 24

var started := false
var is_over := false
var airport: Dictionary = {}
var clock: Node
var rng := RandomNumberGenerator.new()
var year := 1920
var month := 1
var cash := 0.0
var staff := 4
var hangars := 1
var runway := 1
var waiting := 0
var luck := 0.0
var diff_mult := 1.0
var pool := 0
var pool_fraction := 0.0
var debt_days := 0
var lost_total := 0
var flights_total := 0
var pax_total := 0
var visit: Dictionary = {}
var visits: Array = []
var month_in := {"landing": 0.0, "takeoff": 0.0, "tax": 0.0}
var month_out := {"wages": 0.0, "upkeep": 0.0, "running": 0.0}
var last_in: Dictionary = {}
var last_out: Dictionary = {}
var hud: Label

func _ready() -> void:
	layer = 36
	rng.randomize()
	clock = _find_clock(get_tree().root)
	if clock:
		clock.day_passed.connect(_on_day)
	else:
		push_error("Clock with day_passed signal not found")
	var picker := get_node_or_null("../AirportPicker")
	if picker:
		picker.airport_chosen.connect(_on_chosen)
	else:
		push_error("AirportPicker not found next to AirportEconomy")
	_build_hud()

func _find_clock(n: Node):
	if n.has_signal("day_passed"):
		return n
	for c in n.get_children():
		var r = _find_clock(c)
		if r:
			return r
	return null

func _on_chosen(a: Dictionary) -> void:
	airport = a
	cash = float(a["savings"])
	diff_mult = 1.3 - 0.15 * float(a["difficulty"])
	if clock:
		year = clock.year
		month = clock.month
	started = true
	hud.visible = true
	_refresh_hud()
	changed.emit()

func demand_per_day() -> float:
	return BASE_DEMAND * pow(DEMAND_GROWTH, year - 1920) * diff_mult * (1.0 + 0.25 * waiting)

func intake_limit() -> float:
	return staff * STAFF_INTAKE

func pool_cap() -> int:
	return 40 + 40 * waiting

func fee_mult() -> float:
	return 1.0 + 0.25 * (runway - 1)

func _process(delta: float) -> void:
	if is_over:
		if clock and clock.speed_index != 0:
			clock._set_speed(0)
		return
	if not started or visit.is_empty() or clock == null:
		return
	var days := delta * float(RATES[clock.speed_index])
	if days <= 0.0:
		return
	visit["elapsed"] = float(visit["elapsed"]) + days
	var progress := float(visit["elapsed"]) / float(visit["duration"])
	var plane: Dictionary = PlaneData.ALL[visit["plane"]]
	if not visit["landed"] and progress >= PlaneData.landing_frac():
		visit["landed"] = true
		_earn("landing", "Landing fee", float(plane["landing"]) * fee_mult(), "landing")
	if not visit["departed"] and progress >= PlaneData.takeoff_frac():
		visit["departed"] = true
		_earn("takeoff", "Takeoff fee", float(plane["takeoff"]) * fee_mult(), "takeoff")
		var pax: int = visit["pax"]
		if pax > 0:
			_earn("tax", "Departure tax x%d" % pax, pax * DEPARTURE_TAX, "takeoff")
	if progress >= 1.0:
		_finish_visit(plane)

func _earn(kind: String, label: String, amount: float, where: String) -> void:
	cash += amount
	month_in[kind] = float(month_in[kind]) + amount
	if not visit.is_empty():
		visit["income"] = float(visit["income"]) + amount
	fee_paid.emit(label, amount, where)
	_refresh_hud()
	changed.emit()

func _finish_visit(plane: Dictionary) -> void:
	flights_total += 1
	pax_total += int(visit["pax"])
	visits.push_front({"plane": plane["name"], "pax": int(visit["pax"]), "income": float(visit["income"])})
	if visits.size() > 6:
		visits.pop_back()
	visit = {}
	changed.emit()

func _on_day(y: int, m: int, _d: int) -> void:
	if not started or is_over:
		return
	year = y
	if m != month:
		last_in = month_in.duplicate()
		last_out = month_out.duplicate()
		month_in = {"landing": 0.0, "takeoff": 0.0, "tax": 0.0}
		month_out = {"wages": 0.0, "upkeep": 0.0, "running": 0.0}
		month = m
	_charge_costs()
	_intake()
	_dispatch()
	if cash < 0.0:
		debt_days += 1
		if debt_days >= DEBT_DAYS_LIMIT:
			_refresh_hud()
			changed.emit()
			_bankrupt()
			return
	else:
		debt_days = 0
	_refresh_hud()
	changed.emit()

func _charge_costs() -> void:
	var wages := staff * WAGE
	var upkeep := hangars * HANGAR_UPKEEP + runway * RUNWAY_UPKEEP
	cash -= wages + upkeep + BASE_COST
	month_out["wages"] = float(month_out["wages"]) + wages
	month_out["upkeep"] = float(month_out["upkeep"]) + upkeep
	month_out["running"] = float(month_out["running"]) + BASE_COST

func _intake() -> void:
	pool_fraction += minf(demand_per_day(), intake_limit())
	var whole := int(pool_fraction)
	pool_fraction -= whole
	var room := pool_cap() - pool
	if whole > room:
		lost_total += whole - room
		whole = room
	pool += whole

func _dispatch() -> void:
	if not visit.is_empty():
		return
	var ids := PlaneData.eligible(pool, runway)
	if ids.is_empty():
		return
	if rng.randf() > clampf(ARRIVAL_CHANCE + luck, 0.0, 1.0):
		return
	var weights: Array = []
	var total := 0.0
	for id in ids:
		var p: Dictionary = PlaneData.ALL[id]
		var w := float(p["weight"]) * clampf(float(pool) / float(p["min_pax"]), 1.0, 3.0)
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	var chosen: String = ids[ids.size() - 1]
	for i in ids.size():
		roll -= float(weights[i])
		if roll <= 0.0:
			chosen = ids[i]
			break
	var plane: Dictionary = PlaneData.ALL[chosen]
	var pax := mini(pool, int(plane["seats"]))
	pool -= pax
	visit = {
		"plane": chosen, "pax": pax,
		"slot": rng.randi() % clampi(hangars, 1, MAX_HANGARS),
		"elapsed": 0.0,
		"duration": VISIT_DAYS / (1.0 + 0.12 * (hangars - 1)),
		"landed": false, "departed": false, "income": 0.0,
	}
	changed.emit()

func level_of(kind: String) -> int:
	match kind:
		"staff": return staff
		"hangar": return hangars
		"runway": return runway
		"waiting": return waiting
	return 0

func max_of(kind: String) -> int:
	match kind:
		"staff": return MAX_STAFF
		"hangar": return MAX_HANGARS
		"runway": return MAX_RUNWAY
		"waiting": return MAX_WAITING
	return 0

func cost_of(kind: String) -> int:
	match kind:
		"staff": return 200
		"hangar": return 600 * hangars
		"runway": return 2000 * runway
		"waiting": return 800 * (waiting + 1)
	return 0

func can_buy(kind: String) -> bool:
	return started and not is_over and level_of(kind) < max_of(kind) and cash >= cost_of(kind)

func buy(kind: String) -> bool:
	if not can_buy(kind):
		return false
	cash -= cost_of(kind)
	match kind:
		"staff": staff = mini(staff + 2, MAX_STAFF)
		"hangar": hangars += 1
		"runway": runway += 1
		"waiting": waiting += 1
	_refresh_hud()
	changed.emit()
	return true

func upgrade_info(kind: String) -> Dictionary:
	var names := {"staff": "Staff office", "hangar": "Hangars", "runway": "Runway", "waiting": "Waiting room"}
	var effects := {
		"staff": "Hire 2 more staff. Each one can process 1.5 passengers a day, so they decide how many passengers can reach your waiting room. Wages are paid every day.",
		"hangar": "Build another hangar. Each extra hangar speeds up ground handling by 12%, so more planes pass through every month. Hangars cost upkeep every day.",
		"runway": "Improve the runway. Level 2 lets the big Farman Goliath land, and every level raises landing and takeoff fees by 25%. A better runway costs more upkeep.",
		"waiting": "Add a waiting room. Each level brings 25% more passengers and has room for 40 more of them waiting at once.",
	}
	var levels := {
		"staff": "Staff: %d of %d",
		"hangar": "Hangars: %d of %d",
		"runway": "Runway level: %d of %d",
		"waiting": "Waiting room level: %d of %d",
	}
	return {
		"name": names.get(kind, kind),
		"level_text": String(levels.get(kind, "%d of %d")) % [level_of(kind), max_of(kind)],
		"effect": effects.get(kind, ""),
		"cost": cost_of(kind),
		"can_buy": can_buy(kind),
		"maxed": level_of(kind) >= max_of(kind),
	}

func held_back_by() -> String:
	if demand_per_day() > intake_limit():
		return "staff: they cannot process more passengers a day"
	if pool >= pool_cap():
		return "the runway: passengers are being turned away"
	if not visit.is_empty():
		return "one plane at a time: the runway is busy"
	if pool < 2:
		return "passengers: not enough are waiting yet"
	return "nothing right now, a plane is on its way soon"

func money(n: float) -> String:
	var neg := n < -0.5
	var s := str(int(round(absf(n))))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-$" if neg else "$") + s + out

func _block(inc: Dictionary, out: Dictionary) -> String:
	var landing := float(inc.get("landing", 0.0))
	var takeoff := float(inc.get("takeoff", 0.0))
	var tax := float(inc.get("tax", 0.0))
	var wages := float(out.get("wages", 0.0))
	var upkeep := float(out.get("upkeep", 0.0))
	var running := float(out.get("running", 0.0))
	var total_in := landing + takeoff + tax
	var total_out := wages + upkeep + running
	var t := ""
	t += "Income: landing fees %s, takeoff fees %s, departure tax %s\n" % [money(landing), money(takeoff), money(tax)]
	t += "Total income: %s\n" % money(total_in)
	t += "Costs: wages %s, upkeep %s, running costs %s\n" % [money(wages), money(upkeep), money(running)]
	t += "Total costs: %s\n" % money(total_out)
	t += "Net: %s\n" % money(total_in - total_out)
	return t

func ledger_bbcode() -> String:
	if not started:
		return "No airport chosen yet."
	var t := "[b]Cash[/b]   %s\n\n" % money(cash)
	if debt_days > 0:
		t += "[b]In debt:[/b] day %d of %d before the creditors arrive\n\n" % [debt_days, DEBT_DAYS_LIMIT]
	t += "[b]This month so far[/b]\n" + _block(month_in, month_out)
	if not last_in.is_empty():
		t += "\n[b]Last month[/b]\n" + _block(last_in, last_out)
	t += "\n[b]Passengers[/b]\n"
	t += "Waiting: %d of %d\n" % [pool, pool_cap()]
	t += "Demand: %.1f a day  |  Staff can process: %.1f a day\n" % [demand_per_day(), intake_limit()]
	t += "Turned away so far: %d\n" % lost_total
	t += "\n[b]Held back by[/b]\n%s\n" % held_back_by()
	t += "\n[b]Totals[/b]\nFlights: %d  |  Passengers carried: %d\n" % [flights_total, pax_total]
	if not visits.is_empty():
		t += "\n[b]Recent visits[/b]\n"
		for v in visits:
			t += "%s, %d passengers, %s\n" % [v["plane"], int(v["pax"]), money(float(v["income"]))]
	return t

func _box(bg: Color, border: Color, radius := 8, margin := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s

func _build_hud() -> void:
	hud = Label.new()
	hud.visible = false
	hud.position = Vector2(12, 130)
	hud.add_theme_font_size_override("font_size", 16)
	hud.add_theme_stylebox_override("normal", _box(Color(0.04, 0.07, 0.13, 0.9), Color(0.25, 0.4, 0.65), 6, 8))
	add_child(hud)

func _refresh_hud() -> void:
	if hud == null:
		return
	hud.text = "%s   |   %d waiting" % [money(cash), pool]
	hud.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45) if cash < 0.0 else Color(0.7, 1.0, 0.75))

func _bankrupt() -> void:
	is_over = true
	if clock:
		clock._set_speed(0)
	var over_layer := CanvasLayer.new()
	over_layer.layer = 80
	add_child(over_layer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over_layer.add_child(center)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(520, 0)
	p.add_theme_stylebox_override("panel", _box(Color(0.12, 0.04, 0.05, 0.97), Color(0.9, 0.3, 0.3), 12, 24))
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var title := Label.new()
	title.text = "Bankrupt"
	title.add_theme_font_size_override("font_size", 32)
	v.add_child(title)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = "%s ran out of money and stayed that way for %d days. The creditors have arrived, and they brought a very short pencil.\n\nMany early airfields really did end this way. Try again, and maybe hire fewer cows." % [airport.get("name", "Your airport"), DEBT_DAYS_LIMIT]
	v.add_child(body)
	var b := Button.new()
	b.text = "Try again"
	b.custom_minimum_size = Vector2(0, 46)
	b.pressed.connect(func() -> void:
		Engine.time_scale = 1.0
		get_tree().reload_current_scene())
	v.add_child(b)
