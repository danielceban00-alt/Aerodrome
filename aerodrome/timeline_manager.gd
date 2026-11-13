extends MeshInstance3D

const RADIUS := 0.502

var events: Array = []
var snapshots: Dictionary = {}
var pool: Dictionary = {}
var meshes: Dictionary = {}
var next_event := 0
var line_mat: StandardMaterial3D
var popup: CanvasLayer
var holder: Node3D

var y := 1920
var m := 1
var d := 1

var test_speed := 1.0
var speed_btn: Button

signal map_changed(territories)
signal popup_opened
signal popup_closed

func _read(path):
	if not FileAccess.file_exists(path):
		push_error("FILE NOT FOUND: " + path)
		return null
	var json := JSON.new()
	var err := json.parse(FileAccess.get_file_as_string(path))
	if err != OK:
		push_error("JSON error in %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data

func _ready() -> void:
	var old = get_node_or_null("Borders")
	if old:
		old.visible = false
	var t = _read("res://timeline/timeline.json")
	pool = _read("res://timeline/borders_pool.json")
	if t == null or pool == null:
		return
	events = t["events"]
	snapshots = t["snapshots"]
	holder = Node3D.new()
	add_child(holder)
	_make_speed_button()
	line_mat = StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Color(0.8, 0.9, 1.0)
	if material_override == null:
		push_error("Globe has no Material Override with the shader")
	_apply("s00")
	var clock = _find_clock(get_tree().root)
	if clock:
		clock.day_passed.connect(_on_day)
	else:
		push_error("Clock with day_passed signal not found")

func _find_clock(n: Node):
	if n.has_signal("day_passed"):
		return n
	for c in n.get_children():
		var r = _find_clock(c)
		if r:
			return r
	return null

func _days_in_month(yy: int, mm: int) -> int:
	if mm == 2:
		return 29 if (yy % 4 == 0 and (yy % 100 != 0 or yy % 400 == 0)) else 28
	return 30 if mm in [4, 6, 9, 11] else 31

func _on_day(_a = null, _b = null, _c = null) -> void:
	d += 1
	if d > _days_in_month(y, m):
		d = 1
		m += 1
		if m > 12:
			m = 1
			y += 1
	while next_event < events.size():
		var ev = events[next_event]
		var p = ev["date"].split("-")
		var due = int(p[0]) * 10000 + int(p[1]) * 100 + int(p[2])
		if y * 10000 + m * 100 + d >= due:
			next_event += 1
			_apply(ev["id"])
			_show_popup(ev)
			return
		break

func _apply(id: String) -> void:
	var snap = snapshots[id]
	var tex = load("res://timeline/" + snap["land"])
	if material_override:
		material_override.set_shader_parameter("land_tex", tex)
	var want := {}
	for terr in snap["territories"]:
		want[terr["g"]] = true
	for h in meshes:
		meshes[h].visible = want.has(h)
	for h in want:
		if not meshes.has(h):
			meshes[h] = _make_mesh(h)
	map_changed.emit(snap["territories"])

func _make_mesh(h: String) -> MeshInstance3D:
	var verts := PackedVector3Array()
	for ring in pool[h]:
		for i in ring.size():
			var a = ring[i]
			var b = ring[(i + 1) % ring.size()]
			verts.append(_to_sphere(a[0], a[1]))
			verts.append(_to_sphere(b[0], b[1]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = line_mat
	holder.add_child(mi)
	return mi

func _to_sphere(lon: float, lat: float) -> Vector3:
	var lo := deg_to_rad(lon)
	var la := deg_to_rad(lat)
	return Vector3(cos(la) * sin(lo), sin(la), cos(la) * cos(lo)) * RADIUS

func _show_popup(ev: Dictionary) -> void:
	if popup:
		popup.queue_free()
	popup = CanvasLayer.new()
	popup.layer = 50
	add_child(popup)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.15, 0.96)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var date := Label.new()
	date.text = ev["date"]
	date.modulate = Color(0.6, 0.8, 1.0)
	var title := Label.new()
	title.text = ev["title"]
	title.add_theme_font_size_override("font_size", 24)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var body := Label.new()
	body.text = ev["text"]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var btn := Button.new()
	btn.text = "Continue"
	btn.pressed.connect(_close_popup)
	box.add_child(date)
	box.add_child(title)
	box.add_child(body)
	box.add_child(btn)
	Engine.time_scale = 0.0
	popup_opened.emit()

func _close_popup() -> void:
	if popup:
		popup.queue_free()
		popup = null
	Engine.time_scale = test_speed
	popup_closed.emit()

func _make_speed_button() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	speed_btn = Button.new()
	speed_btn.toggle_mode = true
	speed_btn.text = "x50 (test)"
	speed_btn.position = Vector2(12, 90)
	speed_btn.toggled.connect(func(on: bool):
		test_speed = 50.0 if on else 1.0
		if popup == null:
			Engine.time_scale = test_speed)
	layer.add_child(speed_btn)
