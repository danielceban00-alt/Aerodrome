extends CanvasLayer

signal airport_chosen(airport: Dictionary)

# NOTE: "savings" and "difficulty" are placeholder balance numbers, tune them later.
# "start" = the date you begin playing (when the airport opened, never before 1 Jan 1920).
# "real_end" is for later: the date the real airport closed / changed.
const AIRPORTS := [
	{
		"id": "croydon", "name": "Croydon Aerodrome", "place": "London, United Kingdom",
		"lon": -0.117, "lat": 51.357, "savings": 40000, "difficulty": 2, "start": "1920-03-29",
		"tagline": "The glamorous one. Opens 29 March 1920",
		"opened": "Opens 29 March 1920",
		"joke": "A public road runs across the airfield. Pilots are asked to look both ways, then up.",
		"history": "Croydon is being formed from two wartime fields, RAF Beddington and Waddon Aerodrome. On 29 March 1920 it becomes the approved gateway for flights from London to the continent, replacing Hounslow Heath. Passengers climb into converted wartime bombers. About 6,400 people fly from London to the continent in the first year (counting the first months at Hounslow), and the London to Paris run soon becomes the busiest air route in the world. In 1924 Imperial Airways, Britain's national airline, makes Croydon its base.",
		"fate": "In real life Croydon is Britain's only major international airport between the wars. It gets too small for bigger aircraft and closes in 1959, when Heathrow takes over.",
	},
	{
		"id": "lebourget", "name": "Le Bourget", "place": "Paris, France",
		"lon": 2.441, "lat": 48.969, "savings": 45000, "difficulty": 2, "start": "1920-01-01",
		"tagline": "Paris's first civil airport",
		"opened": "Civil since 1919",
		"joke": "The pilots will fly anywhere, as long as lunch is respected.",
		"history": "A wartime military field that became the first civil airport of Paris in 1919. Young airlines fly mail and passengers from here to Lille, Brussels and London in converted wartime bombers. The Compagnie des Messageries Aeriennes started its Lille mail run in April 1919 and a London passenger service in September, and a rival, the Compagnie des Grands Express Aeriens, was founded in March 1919. The two compete fiercely for the same passengers.",
		"fate": "In real life Le Bourget stays Paris's only airport until Orly opens in 1932. Charles Lindbergh lands here in 1927 after crossing the Atlantic.",
	},
	{
		"id": "schiphol", "name": "Schiphol", "place": "Amsterdam, Netherlands",
		"lon": 4.764, "lat": 52.309, "savings": 30000, "difficulty": 3, "start": "1920-01-01",
		"tagline": "A military field and a brand-new airline",
		"opened": "Military field since 1916",
		"joke": "Flat as a pancake. Great for runways, terrible for dramatic arrivals.",
		"history": "The first aircraft landed here on 19 September 1916, a Dutch army plane. In October 1919 a group of businessmen founded KLM, with the aviator Albert Plesman as its first director. Today it is the oldest airline still flying under its original name. Its first flight lands at Schiphol on 17 May 1920 from Croydon, carrying two British journalists and a bundle of newspapers. In its first year the airline has only a few aircraft and about a dozen crew.",
		"fate": "In real life Schiphol becomes KLM's home airport and is still in use today.",
	},
	{
		"id": "checkerboard", "name": "Checkerboard Field", "place": "Chicago, United States",
		"lon": -87.845, "lat": 41.875, "savings": 25000, "difficulty": 3, "start": "1920-05-15",
		"tagline": "Your customers are letters. They never complain.",
		"opened": "Air mail field from 15 May 1920",
		"joke": "Your passengers are sacks of mail. They don't complain, but they don't tip either.",
		"history": "The US Post Office extended its air mail route from Cleveland to Chicago in 1919, landing at first in Grant Park by the lakefront. Flying conditions by the lake were often poor, so in 1920 the service moves to Checkerboard Field in Maywood, which gets new runways and regular flights to Omaha from 15 May 1920. Early on it also carried clothing deliveries for a local firm, but before long it is exclusively an air mail field. By the end of 1920 the United States has 145 municipally owned airports.",
		"fate": "In real life Checkerboard handles air mail until 1927.",
	},
	{
		"id": "mascot", "name": "Mascot Aerodrome", "place": "Sydney, Australia",
		"lon": 151.177, "lat": -33.946, "savings": 15000, "difficulty": 4, "start": "1920-01-09",
		"tagline": "A paddock, one pilot and two aeroplanes",
		"opened": "Opens 9 January 1920",
		"joke": "The grass is mown by cattle and sheep. Union disputes are frequent.",
		"history": "Nigel Love, a First World War pilot, leased a grazing paddock at Mascot in 1919 and started Australia's first flying school and aircraft business there. It has a canvas hangar and a very cheap lawn service of cattle and sheep. The official opening flight is on 9 January 1920. A month later, on 14 February, the Smith brothers' Vickers Vimy lands here after its flight from England. Later in 1920 Love flies the first paying passenger from Sydney to Melbourne: two days of travel, and a fare of 200 pounds. Joyrides at four guineas keep the business alive.",
		"fate": "In real life the government buys the land in 1921, and regular flights start in 1924. Today it is Sydney Airport, Australia's busiest.",
	},
	{
		"id": "johannisthal", "name": "Johannisthal Airfield", "place": "Berlin, Germany",
		"lon": 13.518, "lat": 52.437, "savings": 10000, "difficulty": 4, "start": "1920-01-01",
		"tagline": "Germany's first airfield, under a treaty cloud",
		"opened": "Airfield since 1909",
		"joke": "Allied inspectors visit often. Please do not hide any aeroplanes in the hangar. They know that trick.",
		"history": "Johannisthal opened in 1909 and was Germany's first airfield. On 5 February 1919 the airline Deutsche Luft-Reederei flew German civil air mail from here to Weimar, carrying newspapers for the national assembly. But the Treaty of Versailles has crushed German aviation. Hundreds of military aircraft are being scrapped on this very field, and the Allied commission is slow to allow civil flying to grow.",
		"fate": "In real life Tempelhof opens in 1923 and Johannisthal's traffic collapses. The field closes in 1952.",
	},
	{
		"id": "hounslow", "name": "Hounslow Heath Aerodrome", "place": "London, United Kingdom",
		"lon": -0.38, "lat": 51.47, "savings": 8000, "difficulty": 5, "start": "1920-01-01", "real_end": "1920-03-27",
		"tagline": "HARD MODE: the army wants its field back in March",
		"opened": "Military 1914, civil 1919",
		"joke": "The only airport with a leaving party already on the calendar.",
		"history": "Hounslow Heath was an army airfield until the RAF handed it to civilians in 1919. That summer it ran the first scheduled daily international flights of the British Empire, London to Paris, starting on 25 August 1919. The trouble: a better-equipped field at Croydon is about to become London's approved airport, and the army wants the heath back.",
		"fate": "In real life the last commercial flights leave on 27 March 1920, the airlines move to Croydon and the army takes the land back. You have under three months to prove history wrong.",
	},
]

const DIFF_NAMES := ["", "Very easy", "Easy", "Medium", "Hard", "Brutal"]
const MONTHS := ["January", "February", "March", "April", "May", "June",
		"July", "August", "September", "October", "November", "December"]

const MARKER_RADIUS := 0.503
const COL_AVAILABLE := Color(0.5, 0.85, 1.0)
const COL_SELECTED := Color(1.0, 0.85, 0.3)
const COL_LOCKED := Color(0.4, 0.4, 0.45)

var main: Node
var clock: Node
var panel: PanelContainer
var content: VBoxContainer
var open := true
var chosen: Dictionary = {}
var chosen_id := ""
var tween: Tween
var markers := {}   # id -> MeshInstance3D

func _ready() -> void:
	layer = 60
	main = get_parent()
	clock = _find_clock(get_tree().root)
	_make_markers()
	_build_panel()
	_show_list()

func _process(_d: float) -> void:
	# keep the game paused while the player is choosing
	if open and clock and clock.speed_index != 0:
		clock._set_speed(0)
	# the chosen airport's dot pulses
	if chosen_id != "" and markers.has(chosen_id):
		var s := 2.0 + 0.4 * sin(Time.get_ticks_msec() / 300.0)
		markers[chosen_id].scale = Vector3.ONE * s

func _find_clock(n: Node):
	if n.has_signal("day_passed"):
		return n
	for c in n.get_children():
		var r = _find_clock(c)
		if r:
			return r
	return null

# ---------- dots on the globe ----------

func _to_sphere(lon_deg: float, lat_deg: float) -> Vector3:
	var lon := deg_to_rad(lon_deg)
	var lat := deg_to_rad(lat_deg)
	return Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))

func _make_markers() -> void:
	var globe := main.get_node_or_null("Globe")
	if globe == null:
		return
	var holder := Node3D.new()
	holder.name = "AirportMarkers"
	globe.add_child(holder)
	for a in AIRPORTS:
		var sphere := SphereMesh.new()
		sphere.radius = 0.005
		sphere.height = 0.01
		sphere.radial_segments = 12
		sphere.rings = 6
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var mi := MeshInstance3D.new()
		mi.mesh = sphere
		mi.material_override = mat
		mi.position = _to_sphere(a["lon"], a["lat"]) * MARKER_RADIUS
		holder.add_child(mi)
		markers[a["id"]] = mi
	_paint_markers("")

func _paint_markers(selected_id: String) -> void:
	for id in markers:
		var mi: MeshInstance3D = markers[id]
		var mat := mi.material_override as StandardMaterial3D
		if chosen_id != "":
			# game started: your airport glows, the others are locked
			mat.albedo_color = COL_SELECTED if id == chosen_id else COL_LOCKED
			if id != chosen_id:
				mi.scale = Vector3.ONE * 0.8
		else:
			mat.albedo_color = COL_SELECTED if id == selected_id else COL_AVAILABLE
			mi.scale = Vector3.ONE * (1.8 if id == selected_id else 1.0)

# ---------- UI helpers ----------

func _box(bg: Color, border: Color, radius := 8, margin := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s

func _label(text: String, size: int, color: Color, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _money(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return "$" + s + out

func _pretty_date(iso: String) -> String:
	var p := iso.split("-")
	return "%d %s %d" % [int(p[2]), MONTHS[int(p[1]) - 1], int(p[0])]

func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 8
	panel.offset_right = -8
	panel.offset_top = 8
	panel.offset_bottom = -8
	panel.add_theme_stylebox_override("panel", _box(Color(0.04, 0.07, 0.13, 0.96), Color(0.25, 0.4, 0.65), 12, 20))
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	add_child(panel)

func _clear() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()

# ---------- list view ----------

func _show_list() -> void:
	_clear()
	_zoom_out()
	_paint_markers("")
	content.add_child(_label("Choose your airport", 30, Color.WHITE))
	content.add_child(_label("1 January 1920. The war is over, the sky is open and every airfield is a bit muddy. Click one to read its story. Don't like it? Go back and try another, history won't mind.", 15, Color(0.7, 0.8, 0.95), true))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	content.add_child(scroll)
	for a in AIRPORTS:
		list.add_child(_make_card(a))

func _make_card(a: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 92)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("normal", _box(Color(0.09, 0.14, 0.24), Color(0.22, 0.32, 0.5)))
	b.add_theme_stylebox_override("hover", _box(Color(0.14, 0.22, 0.38), Color(0.45, 0.7, 1.0)))
	b.add_theme_stylebox_override("pressed", _box(Color(0.18, 0.28, 0.46), Color(0.45, 0.7, 1.0)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 12)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	var name_l := _label(a["name"], 20, Color.WHITE)
	var place_l := _label("%s  |  %s" % [a["place"], a["opened"]], 13, Color(0.6, 0.75, 1.0))
	var tag_l := _label(a["tagline"], 14, Color(0.85, 0.88, 0.95))
	tag_l.clip_text = true
	tag_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(name_l)
	v.add_child(place_l)
	v.add_child(tag_l)
	m.add_child(v)
	b.add_child(m)
	b.pressed.connect(_show_detail.bind(a))
	return b

# ---------- detail view ----------

func _show_detail(a: Dictionary) -> void:
	_clear()
	_fly_to(a["lon"], a["lat"])
	_paint_markers(a["id"])
	var back := Button.new()
	back.text = "< Back to the list"
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.pressed.connect(_show_list)
	content.add_child(back)
	content.add_child(_label(a["name"], 32, Color.WHITE, true))
	content.add_child(_label("%s  |  %s" % [a["place"], a["opened"]], 15, Color(0.6, 0.75, 1.0), true))
	content.add_child(_label('"%s"' % a["joke"], 15, Color(1.0, 0.85, 0.5), true))
	var d: int = a["difficulty"]
	content.add_child(_label("Starting savings: %s     Difficulty: %d/5 (%s)" % [_money(a["savings"]), d, DIFF_NAMES[d]], 16, Color(0.8, 1.0, 0.8), true))
	content.add_child(_label("You start playing on: %s" % _pretty_date(a["start"]), 16, Color(0.8, 1.0, 0.8), true))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_size_override("normal_font_size", 16)
	rt.add_theme_font_size_override("bold_font_size", 18)
	rt.text = "[b]How it was born[/b]\n%s\n\n[b]What history has in store[/b]\n%s" % [a["history"], a["fate"]]
	scroll.add_child(rt)
	content.add_child(scroll)
	var go := Button.new()
	go.text = "Run this airport"
	go.custom_minimum_size = Vector2(0, 52)
	go.add_theme_font_size_override("font_size", 20)
	go.add_theme_stylebox_override("normal", _box(Color(0.12, 0.45, 0.25), Color(0.4, 0.9, 0.55)))
	go.add_theme_stylebox_override("hover", _box(Color(0.16, 0.58, 0.32), Color(0.6, 1.0, 0.7)))
	go.add_theme_stylebox_override("pressed", _box(Color(0.1, 0.35, 0.2), Color(0.6, 1.0, 0.7)))
	go.pressed.connect(_choose.bind(a))
	content.add_child(go)

# ---------- choosing ----------

func _fast_forward(start: String) -> void:
	if clock == null:
		return
	var p := start.split("-")
	var target := int(p[0]) * 10000 + int(p[1]) * 100 + int(p[2])
	var guard := 0
	while clock.year * 10000 + clock.month * 100 + clock.day < target and guard < 4000:
		clock._advance_day()
		guard += 1

func _choose(a: Dictionary) -> void:
	chosen = a
	chosen_id = a["id"]
	open = false
	panel.queue_free()
	_fast_forward(a["start"])
	_paint_markers(chosen_id)
	if clock:
		clock._set_speed(1)
	var hud := Label.new()
	hud.text = "Running: %s" % a["name"]
	hud.add_theme_font_size_override("font_size", 16)
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	hud.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hud.offset_top = 10
	hud.offset_right = -14
	add_child(hud)
	airport_chosen.emit(a)

# ---------- camera ----------

func _zoom_out() -> void:
	if main and "distance" in main:
		main.distance = 0.9

func _fly_to(lon: float, lat: float) -> void:
	if main == null or not ("yaw" in main) or not ("pitch" in main):
		return
	var start_yaw: float = main.yaw
	var end_yaw: float = start_yaw + wrapf(-deg_to_rad(lon) - start_yaw, -PI, PI)
	var start_pitch: float = main.pitch
	var end_pitch: float = clampf(deg_to_rad(lat), -deg_to_rad(80.0), deg_to_rad(80.0))
	main.velocity = Vector2.ZERO
	main.distance = 0.75
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(func(t: float) -> void:
		main.yaw = lerpf(start_yaw, end_yaw, t)
		main.pitch = lerpf(start_pitch, end_pitch, t)
		main._apply_rotation(), 0.0, 1.0, 1.2)
