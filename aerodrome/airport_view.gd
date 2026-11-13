extends CanvasLayer
const PlaneData = preload("res://plane_data.gd")

const DESIGN := Vector2(1600, 900)
const GRASS := Color(0.29, 0.45, 0.21)
const PATCH_A := Color(0.24, 0.38, 0.17, 0.5)
const PATCH_B := Color(0.34, 0.51, 0.25, 0.5)
const DIRT := Color(0.55, 0.46, 0.31)
const GRAVEL := Color(0.58, 0.57, 0.52)
const TARMAC := Color(0.21, 0.21, 0.24)
const ROAD := Color(0.62, 0.55, 0.42)
const WOOD := Color(0.48, 0.34, 0.2)
const WOOD_DARK := Color(0.32, 0.22, 0.13)
const ROOF := Color(0.42, 0.5, 0.58)
const ROOF_DARK := Color(0.33, 0.4, 0.47)
const RUNWAY_Y := 520.0
const TAXI_X := 470.0
const APRON_Y := 335.0
const HANGAR_X0 := 330.0
const HANGAR_STEP := 150.0
const SHED_POS := Vector2(1250, 190)
const HUT_RECT := Rect2(1130, 330, 50, 50)
const MAX_HANGARS := 6
const COATS := [Color(0.35, 0.3, 0.22), Color(0.25, 0.3, 0.4), Color(0.4, 0.22, 0.2), Color(0.3, 0.35, 0.25)]
const KIND_NAMES := {"hangar": "Hangars", "waiting": "Waiting room", "staff": "Staff office", "runway": "Runway"}

var menu: Node
var economy: Node
var airport: Dictionary = {}
var canvas: Control
var fade: ColorRect
var title_l: Label
var back_btn: Button
var active := false
var busy := false
var t := 0.0
var patches: Array = []
var trees: Array = []
var cows: Array = []
var floaters: Array = []
var hover: Dictionary = {}
var rng := RandomNumberGenerator.new()
var upg_panel: PanelContainer
var upg_kind := ""
var upg_title: Label
var upg_level: Label
var upg_effect: Label
var upg_buy: Button
var last_origin := Vector2.ZERO
var last_k := 1.0

func _ready() -> void:
	layer = 0
	menu = get_node_or_null("../AirportMenu")
	economy = get_node_or_null("../AirportEconomy")
	_build_ui()
	if menu and menu.has_signal("enter_airport"):
		menu.enter_airport.connect(_enter)
	else:
		push_error("AirportMenu with enter_airport signal not found")
	if economy:
		economy.fee_paid.connect(_on_fee)
		economy.changed.connect(_on_econ_changed)
	else:
		push_error("AirportEconomy not found next to AirportView")

func _build_ui() -> void:
	canvas = Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.visible = false
	canvas.draw.connect(_on_draw)
	canvas.gui_input.connect(_on_canvas_input)
	add_child(canvas)
	title_l = Label.new()
	title_l.add_theme_font_size_override("font_size", 26)
	title_l.add_theme_constant_override("outline_size", 6)
	title_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title_l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title_l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title_l.offset_top = 14
	canvas.add_child(title_l)
	back_btn = Button.new()
	back_btn.text = "Back to the globe"
	back_btn.custom_minimum_size = Vector2(220, 48)
	back_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	back_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	back_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	back_btn.offset_bottom = -24
	back_btn.pressed.connect(_leave)
	canvas.add_child(back_btn)
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.modulate.a = 0.0
	add_child(fade)

func _enter() -> void:
	if active or busy:
		return
	airport = menu.airport
	busy = true
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 0.35)
	tw.tween_callback(_show_view)
	tw.tween_property(fade, "modulate:a", 0.0, 0.45)
	tw.tween_callback(_transition_done)

func _leave() -> void:
	if busy:
		return
	busy = true
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 0.3)
	tw.tween_callback(_hide_view)
	tw.tween_property(fade, "modulate:a", 0.0, 0.35)
	tw.tween_callback(_transition_done)

func _show_view() -> void:
	_generate()
	floaters.clear()
	t = 0.0
	title_l.text = "%s  |  %s" % [airport.get("name", ""), airport.get("place", "")]
	canvas.visible = true
	active = true

func _hide_view() -> void:
	active = false
	canvas.visible = false
	if upg_panel:
		upg_panel.visible = false
	if menu:
		menu._open()

func _transition_done() -> void:
	busy = false
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _n(prop: String, default_value: int) -> int:
	if economy:
		var v = economy.get(prop)
		if v != null:
			return int(v)
	return default_value

func _money(n: float) -> String:
	var s := str(int(round(absf(n))))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-$" if n < -0.5 else "$") + s + out

func _generate() -> void:
	var id: String = airport.get("id", "x")
	rng.seed = hash(id)
	patches.clear()
	trees.clear()
	cows.clear()
	for i in 240:
		patches.append([Vector2(rng.randf_range(-150, 1750), rng.randf_range(-100, 1000)), rng.randf_range(14, 50), rng.randi() % 2])
	var wanted := 90 if id == "hounslow" else 48
	var tries := 0
	while trees.size() < wanted and tries < 900:
		tries += 1
		var p := Vector2(rng.randf_range(-100, 1700), rng.randf_range(-60, 960))
		if p.y > 420.0 and p.y < 620.0:
			continue
		if Rect2(250, 120, 1280, 310).has_point(p):
			continue
		trees.append([p, rng.randf_range(16, 30)])
	if id == "mascot":
		for i in 6:
			cows.append({
				"pos": Vector2(rng.randf_range(100, 1500), rng.randf_range(680, 850)),
				"dir": Vector2.RIGHT.rotated(rng.randf() * TAU),
				"timer": rng.randf_range(1.0, 4.0),
				"face": 1,
			})

func _process(delta: float) -> void:
	if not active:
		return
	var dt := delta / Engine.time_scale if Engine.time_scale > 0.0 else 0.0
	t += dt
	_update_cows(dt)
	_update_hover()
	canvas.queue_redraw()

func _update_cows(dt: float) -> void:
	for c in cows:
		c["timer"] = float(c["timer"]) - dt
		if c["timer"] <= 0.0:
			c["timer"] = rng.randf_range(1.5, 5.0)
			c["dir"] = Vector2.ZERO if rng.randf() < 0.4 else Vector2.RIGHT.rotated(rng.randf() * TAU)
		var dir: Vector2 = c["dir"]
		if dir.x < -0.1:
			c["face"] = -1
		elif dir.x > 0.1:
			c["face"] = 1
		var pos: Vector2 = c["pos"]
		pos += dir * 14.0 * dt
		pos.x = clampf(pos.x, 80.0, 1520.0)
		pos.y = clampf(pos.y, 670.0, 860.0)
		c["pos"] = pos

func _runway_thickness() -> float:
	return 64.0 + 8.0 * (clampi(_n("runway", 1), 1, 3) - 1)

func _hit_at(dp: Vector2) -> Dictionary:
	if economy == null:
		return {}
	var hangars := clampi(_n("hangars", 1), 1, MAX_HANGARS)
	var waiting := clampi(_n("waiting", 0), 0, 3)
	for i in hangars:
		var hr := Rect2(HANGAR_X0 + i * HANGAR_STEP, 170, 120, 120)
		if hr.has_point(dp):
			return {"kind": "hangar", "rect": hr}
	if hangars < MAX_HANGARS:
		var er := Rect2(HANGAR_X0 + hangars * HANGAR_STEP, 170, 120, 120)
		if er.has_point(dp):
			return {"kind": "hangar", "rect": er}
	var shed := Rect2(SHED_POS.x, SHED_POS.y - 14, 150 + 30 * waiting, 114)
	if shed.has_point(dp):
		return {"kind": "waiting", "rect": shed}
	var hut := HUT_RECT.grow(6)
	if hut.has_point(dp):
		return {"kind": "staff", "rect": hut}
	var th := _runway_thickness()
	var rr := Rect2(-200, RUNWAY_Y - th / 2.0, 2000, th)
	if rr.has_point(dp):
		return {"kind": "runway", "rect": rr}
	return {}

func _update_hover() -> void:
	var mp := canvas.get_local_mouse_position()
	if upg_panel != null and upg_panel.visible and upg_panel.get_rect().has_point(mp):
		hover = {}
	else:
		hover = _hit_at((mp - last_origin) / maxf(last_k, 0.0001))
	canvas.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not hover.is_empty() else Control.CURSOR_ARROW

func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := _hit_at((event.position - last_origin) / maxf(last_k, 0.0001))
		if not hit.is_empty():
			_open_upgrade(hit["kind"])

func _on_econ_changed() -> void:
	if upg_panel != null and upg_panel.visible:
		_fill_upgrade()

func _on_fee(label: String, amount: float, where: String) -> void:
	if not active:
		return
	var base := Vector2(120, 470) if where == "landing" else Vector2(150, 470)
	var stack := 0
	for f in floaters:
		if f["where"] == where:
			stack += 1
	floaters.append({
		"text": "+%s  %s" % [_money(amount), label],
		"pos": base + Vector2(0, -24 * stack),
		"born": Time.get_ticks_msec(),
		"where": where,
	})

func _open_upgrade(kind: String) -> void:
	if economy == null:
		return
	upg_kind = kind
	if upg_panel == null:
		_build_upgrade_panel()
	_fill_upgrade()
	upg_panel.visible = true

func _box(bg: Color, border: Color, radius := 8, margin := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s

func _build_upgrade_panel() -> void:
	upg_panel = PanelContainer.new()
	upg_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	upg_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	upg_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	upg_panel.custom_minimum_size = Vector2(480, 0)
	upg_panel.add_theme_stylebox_override("panel", _box(Color(0.04, 0.07, 0.13, 0.97), Color(0.25, 0.4, 0.65), 12, 20))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var top := HBoxContainer.new()
	upg_title = Label.new()
	upg_title.add_theme_font_size_override("font_size", 26)
	upg_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(upg_title)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func() -> void: upg_panel.visible = false)
	top.add_child(close)
	v.add_child(top)
	upg_level = Label.new()
	upg_level.add_theme_font_size_override("font_size", 15)
	upg_level.add_theme_color_override("font_color", Color(0.6, 0.75, 1.0))
	v.add_child(upg_level)
	upg_effect = Label.new()
	upg_effect.add_theme_font_size_override("font_size", 16)
	upg_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(upg_effect)
	upg_buy = Button.new()
	upg_buy.custom_minimum_size = Vector2(0, 48)
	upg_buy.add_theme_font_size_override("font_size", 18)
	upg_buy.pressed.connect(func() -> void:
		if economy:
			economy.buy(upg_kind))
	v.add_child(upg_buy)
	upg_panel.add_child(v)
	canvas.add_child(upg_panel)

func _fill_upgrade() -> void:
	var info: Dictionary = economy.upgrade_info(upg_kind)
	upg_title.text = info["name"]
	upg_level.text = info["level_text"]
	upg_effect.text = info["effect"]
	if info["maxed"]:
		upg_buy.text = "Fully upgraded"
		upg_buy.disabled = true
	else:
		var price := _money(float(info["cost"]))
		upg_buy.text = ("Buy for %s" % price) if info["can_buy"] else ("%s (not enough cash)" % price)
		upg_buy.disabled = not info["can_buy"]

func _route_points(slot: int) -> Array:
	var park_x := HANGAR_X0 + slot * HANGAR_STEP + 60.0
	return [
		Vector3(-140, 380, 1.6), Vector3(120, RUNWAY_Y, 1.0), Vector3(TAXI_X, RUNWAY_Y, 1.0),
		Vector3(TAXI_X, APRON_Y, 1.0), Vector3(park_x, APRON_Y, 1.0), Vector3(park_x, APRON_Y, 1.0),
		Vector3(TAXI_X, APRON_Y, 1.0), Vector3(TAXI_X, RUNWAY_Y, 1.0), Vector3(140, RUNWAY_Y, 1.0),
		Vector3(1000, RUNWAY_Y, 1.0), Vector3(1800, 400, 1.6),
	]

func _seg_angle(pts: Array, i: int) -> float:
	var a: Vector3 = pts[i]
	var b: Vector3 = pts[i + 1]
	var d := Vector2(b.x - a.x, b.y - a.y)
	if d.length() < 1.0:
		return _seg_angle(pts, i - 1) if i > 0 else 0.0
	return d.angle()

func _ease(i: int, u: float) -> float:
	match i:
		1: return 1.0 - (1.0 - u) * (1.0 - u)
		2, 3, 5, 6, 7: return u * u * (3.0 - 2.0 * u)
		8: return u * u
	return u

func _plane_state(progress: float, slot: int) -> Dictionary:
	var times: Array = PlaneData.ROUTE_TIMES
	var total := PlaneData.route_total()
	var target := clampf(progress, 0.0, 0.9999) * total
	var pts := _route_points(slot)
	var i := 0
	var acc := 0.0
	while i < times.size() - 1 and acc + float(times[i]) <= target:
		acc += float(times[i])
		i += 1
	var u := clampf((target - acc) / float(times[i]), 0.0, 1.0)
	var e := _ease(i, u)
	var a: Vector3 = pts[i]
	var b: Vector3 = pts[i + 1]
	var prev := _seg_angle(pts, i - 1) if i > 0 else _seg_angle(pts, 0)
	var ang := lerp_angle(prev, _seg_angle(pts, i), smoothstep(0.0, 0.35, u))
	return {
		"pos": Vector2(lerpf(a.x, b.x, e), lerpf(a.y, b.y, e)),
		"scale": lerpf(a.z, b.z, e),
		"angle": ang,
	}

func _on_draw() -> void:
	var sz := canvas.size
	var k := minf(sz.x / DESIGN.x, sz.y / DESIGN.y)
	var origin := (sz - DESIGN * k) / 2.0
	last_origin = origin
	last_k = k
	canvas.draw_rect(Rect2(Vector2.ZERO, sz), GRASS)
	canvas.draw_set_transform(origin, 0.0, Vector2(k, k))
	_draw_ground()
	_draw_buildings()
	_draw_queue()
	_draw_cows()
	_draw_trees()
	_draw_windsock()
	_draw_hover()
	_draw_visit(origin, k)
	_draw_floaters()
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_ground() -> void:
	for p in patches:
		canvas.draw_circle(p[0], p[1], PATCH_A if int(p[2]) == 0 else PATCH_B)
	if airport.get("id", "") == "croydon":
		canvas.draw_rect(Rect2(132, -200, 36, 1300), ROAD)
		canvas.draw_line(Vector2(132, -200), Vector2(132, 1100), WOOD_DARK, 2.0)
		canvas.draw_line(Vector2(168, -200), Vector2(168, 1100), WOOD_DARK, 2.0)
	canvas.draw_rect(Rect2(300, 295, 960, 85), DIRT)
	canvas.draw_rect(Rect2(TAXI_X - 18, APRON_Y - 20, 36, RUNWAY_Y - APRON_Y + 20), DIRT)
	var level := clampi(_n("runway", 1), 1, 3)
	var thickness := _runway_thickness()
	var surface := DIRT if level == 1 else (GRAVEL if level == 2 else TARMAC)
	canvas.draw_rect(Rect2(-200, RUNWAY_Y - thickness / 2.0, 2000, thickness), surface)
	if level >= 2:
		canvas.draw_line(Vector2(-200, RUNWAY_Y - thickness / 2.0 + 3), Vector2(1800, RUNWAY_Y - thickness / 2.0 + 3), Color(1, 1, 1, 0.7), 3.0)
		canvas.draw_line(Vector2(-200, RUNWAY_Y + thickness / 2.0 - 3), Vector2(1800, RUNWAY_Y + thickness / 2.0 - 3), Color(1, 1, 1, 0.7), 3.0)
		var x := 60.0
		while x < 1560.0:
			canvas.draw_rect(Rect2(x, RUNWAY_Y - 2, 32, 4), Color(1, 1, 1, 0.8))
			x += 70.0
	var m := 60.0
	while m < 1600.0:
		canvas.draw_rect(Rect2(m, RUNWAY_Y - thickness / 2.0 - 12, 8, 8), Color(1, 1, 1, 0.9))
		canvas.draw_rect(Rect2(m, RUNWAY_Y + thickness / 2.0 + 4, 8, 8), Color(1, 1, 1, 0.9))
		m += 200.0

func _draw_buildings() -> void:
	var hangars := clampi(_n("hangars", 1), 1, MAX_HANGARS)
	for i in hangars:
		var hx := HANGAR_X0 + i * HANGAR_STEP
		var body := Rect2(hx, 170, 120, 120)
		canvas.draw_rect(body, ROOF)
		for j in range(1, 10):
			canvas.draw_line(Vector2(hx, 170 + j * 12), Vector2(hx + 120, 170 + j * 12), ROOF_DARK, 1.0)
		canvas.draw_line(Vector2(hx + 60, 170), Vector2(hx + 60, 290), ROOF_DARK, 3.0)
		canvas.draw_rect(body, WOOD_DARK, false, 3.0)
		canvas.draw_rect(Rect2(hx + 20, 262, 80, 28), WOOD_DARK)
	if hangars < MAX_HANGARS:
		var px := HANGAR_X0 + hangars * HANGAR_STEP
		canvas.draw_rect(Rect2(px, 170, 120, 120), Color(1, 1, 1, 0.3), false, 2.0)
		canvas.draw_line(Vector2(px + 44, 230), Vector2(px + 76, 230), Color(1, 1, 1, 0.5), 3.0)
		canvas.draw_line(Vector2(px + 60, 214), Vector2(px + 60, 246), Color(1, 1, 1, 0.5), 3.0)
		canvas.draw_string(ThemeDB.fallback_font, Vector2(px + 8, 276), "Build hangar", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.55))
	var waiting := clampi(_n("waiting", 0), 0, 3)
	var tw := 150.0 + 30.0 * waiting
	var tx := SHED_POS.x
	var ty := SHED_POS.y
	canvas.draw_rect(Rect2(tx, ty, tw, 100), WOOD)
	canvas.draw_rect(Rect2(tx - 6, ty - 14, tw + 12, 30), ROOF_DARK)
	canvas.draw_rect(Rect2(tx + tw / 2.0 - 14, ty + 62, 28, 38), WOOD_DARK)
	canvas.draw_rect(Rect2(tx + 14, ty + 34, 24, 20), Color(0.7, 0.85, 0.95))
	canvas.draw_rect(Rect2(tx + tw - 38, ty + 34, 24, 20), Color(0.7, 0.85, 0.95))
	canvas.draw_string(ThemeDB.fallback_font, Vector2(tx + 8, ty + 8), "PASSENGERS", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.9))
	for i in waiting + 1:
		canvas.draw_rect(Rect2(tx + 10 + i * 40, ty + 108, 28, 8), WOOD_DARK)
	canvas.draw_rect(HUT_RECT, WOOD)
	canvas.draw_rect(Rect2(HUT_RECT.position.x - 6, HUT_RECT.position.y - 8, 62, 14), ROOF_DARK)
	canvas.draw_rect(Rect2(HUT_RECT.position.x + 10, HUT_RECT.position.y + 16, 14, 12), Color(0.7, 0.85, 0.95))
	var staff := clampi(_n("staff", 4), 0, 24)
	for i in staff:
		var sp := Vector2(310.0 + (i * 41) % 900, 392.0 + (i * 17) % 18)
		canvas.draw_circle(sp, 6.0, Color(0.35, 0.3, 0.22))
		canvas.draw_circle(sp + Vector2(0, -1), 3.5, Color(0.9, 0.78, 0.62))

func _draw_queue() -> void:
	var n := mini(_n("pool", 0), 60)
	for i in n:
		var col := i % 12
		var row := floori(float(i) / 12.0)
		var p := Vector2(SHED_POS.x + 12 + col * 13 + (row % 2) * 6, SHED_POS.y + 128 + row * 14)
		canvas.draw_circle(p, 5.0, COATS[i % 4])
		canvas.draw_circle(p + Vector2(0, -3), 3.2, Color(0.9, 0.78, 0.62))

func _draw_cows() -> void:
	for c in cows:
		var pos: Vector2 = c["pos"]
		var face: int = c["face"]
		canvas.draw_rect(Rect2(pos.x - 12, pos.y - 6, 24, 12), Color(0.95, 0.95, 0.92))
		canvas.draw_rect(Rect2(pos.x - 6, pos.y - 5, 7, 6), Color(0.2, 0.15, 0.1))
		canvas.draw_rect(Rect2(pos.x + 3, pos.y, 6, 5), Color(0.2, 0.15, 0.1))
		var hx := pos.x + 10.0 if face > 0 else pos.x - 18.0
		canvas.draw_rect(Rect2(hx, pos.y - 4, 8, 8), Color(0.88, 0.85, 0.8))

func _draw_trees() -> void:
	for tr in trees:
		var pos: Vector2 = tr[0]
		var r: float = tr[1]
		canvas.draw_circle(pos + Vector2(4, 5), r, Color(0, 0, 0, 0.2))
		canvas.draw_circle(pos, r, Color(0.15, 0.32, 0.13))
		canvas.draw_circle(pos + Vector2(-r * 0.25, -r * 0.25), r * 0.6, Color(0.2, 0.4, 0.17))

func _draw_windsock() -> void:
	var base := Vector2(200, 440)
	var top := base + Vector2(0, -60)
	canvas.draw_line(base, top, Color(0.9, 0.9, 0.9), 3.0)
	var a := -0.15 + sin(t * 1.7) * 0.25
	var d := Vector2.RIGHT.rotated(a)
	var perp := d.rotated(PI / 2.0)
	canvas.draw_colored_polygon(PackedVector2Array([top + perp * 8.0, top - perp * 8.0, top + d * 44.0 - perp * 3.0, top + d * 44.0 + perp * 3.0]), Color(0.95, 0.5, 0.15))
	canvas.draw_colored_polygon(PackedVector2Array([top + d * 16.0 + perp * 6.0, top + d * 16.0 - perp * 6.0, top + d * 26.0 - perp * 5.0, top + d * 26.0 + perp * 5.0]), Color(0.97, 0.97, 0.97))

func _draw_hover() -> void:
	if hover.is_empty():
		return
	var r: Rect2 = hover["rect"]
	var shown := r.intersection(Rect2(-100, -100, 1800, 1100))
	canvas.draw_rect(shown, Color(1.0, 1.0, 0.6, 0.95), false, 3.0)
	var label := "Click to upgrade: %s" % KIND_NAMES.get(hover["kind"], "")
	var at := Vector2(clampf(shown.position.x, 20.0, 1300.0), maxf(shown.position.y - 10.0, 24.0))
	canvas.draw_string(ThemeDB.fallback_font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 1.0, 0.7))

func _draw_visit(origin: Vector2, k: float) -> void:
	if economy == null or economy.visit.is_empty():
		return
	var v: Dictionary = economy.visit
	var data: Dictionary = PlaneData.ALL[v["plane"]]
	var progress := float(v["elapsed"]) / float(v["duration"])
	var st := _plane_state(progress, int(v["slot"]))
	var pos: Vector2 = st["pos"]
	var sc: float = float(st["scale"]) * float(data["size"])
	var ang: float = st["angle"]
	var lift := (float(st["scale"]) - 1.0) * 60.0 + 3.0
	canvas.draw_set_transform(origin + (pos + Vector2(lift, lift * 1.3)) * k, ang, Vector2.ONE * k * sc)
	_plane_shape(true, data)
	canvas.draw_set_transform(origin + pos * k, ang, Vector2.ONE * k * sc)
	_plane_shape(false, data)
	canvas.draw_set_transform(origin, 0.0, Vector2(k, k))
	var tag := "%s  |  %d passengers" % [data["name"], int(v["pax"])]
	canvas.draw_string(ThemeDB.fallback_font, pos + Vector2(-60, -48.0 * sc - 8.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.95))

func _plane_shape(shadow: bool, data: Dictionary) -> void:
	var sh := Color(0, 0, 0, 0.22)
	var body: Color = data["body"]
	var wing: Color = data["wing"]
	var engines: int = data["engines"]
	canvas.draw_rect(Rect2(-36, -13, 10, 26), sh if shadow else wing)
	canvas.draw_rect(Rect2(-28, -5, 56, 10), sh if shadow else body)
	canvas.draw_rect(Rect2(-14, -32, 6, 64), sh if shadow else wing.darkened(0.15))
	canvas.draw_rect(Rect2(-9, -36, 20, 72), sh if shadow else wing)
	if engines >= 2:
		for sy in [-18.0, 18.0]:
			canvas.draw_rect(Rect2(-6, sy - 4, 20, 8), sh if shadow else Color(0.3, 0.3, 0.32))
	if shadow:
		return
	canvas.draw_circle(Vector2(0, -26), 4.0, Color(0.8, 0.2, 0.2))
	canvas.draw_circle(Vector2(0, 26), 4.0, Color(0.8, 0.2, 0.2))
	canvas.draw_rect(Rect2(-4, -3.5, 9, 7), Color(0.15, 0.12, 0.1))
	canvas.draw_rect(Rect2(24, -6, 8, 12), Color(0.3, 0.3, 0.32))
	canvas.draw_rect(Rect2(31, -13, 3, 26), Color(0.2, 0.2, 0.2, 0.45))
	if engines >= 2:
		for sy in [-18.0, 18.0]:
			canvas.draw_rect(Rect2(14, sy - 8, 3, 16), Color(0.2, 0.2, 0.2, 0.45))

func _draw_floaters() -> void:
	var now := Time.get_ticks_msec()
	var alive: Array = []
	for f in floaters:
		var age := float(now - int(f["born"])) / 1800.0
		if age < 1.0:
			alive.append(f)
			var p: Vector2 = f["pos"]
			canvas.draw_string(ThemeDB.fallback_font, p + Vector2(0, -age * 50.0), f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.7, 1.0, 0.7, 1.0 - age))
	floaters = alive
