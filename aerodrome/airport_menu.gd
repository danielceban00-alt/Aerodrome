extends CanvasLayer

signal enter_airport

const OPTIONS := [
	{
		"id": "enter", "name": "Enter airport", "ready": true,
		"tagline": "Walk the field, meet the staff, make decisions",
		"joke": "Please wipe your boots. The runway is mostly mud and ambition.",
		"desc": "Fly down to your airfield and see it up close: the runway, the hangars, the planes coming and going. Click a building there to upgrade it.",
	},
	{
		"id": "ledger", "name": "Open the ledger", "ready": true,
		"tagline": "Income, costs and what the accountant is crying about",
		"joke": "Every number in here is somebody's fault. Usually yours.",
		"desc": "",
	},
]

const SLIDE_DISTANCE := 520.0
const HIT_RADIUS := 24.0

var airport: Dictionary = {}
var picker: Node
var economy: Node
var main: Node
var panel: PanelContainer
var content: VBoxContainer
var hover_label: Label
var ledger_rt: RichTextLabel
var started := false
var closing := false
var event_open := false
var pending_open := false
var anim: Tween
var focus_tween: Tween
var press_pos := Vector2.ZERO
var press_time := 0

func _ready() -> void:
	layer = 55
	main = get_parent()
	picker = get_node_or_null("../AirportPicker")
	economy = get_node_or_null("../AirportEconomy")
	if picker:
		picker.airport_chosen.connect(_on_chosen)
	else:
		push_error("AirportPicker not found next to AirportMenu")
	if economy:
		economy.changed.connect(_refresh_ledger)
	_build_hover_label()
	var manager := get_node_or_null("../Globe")
	if manager and manager.has_signal("popup_opened"):
		manager.popup_opened.connect(_on_event_opened)
		manager.popup_closed.connect(_on_event_closed)

func _on_chosen(a: Dictionary) -> void:
	airport = a
	started = true
	_open()

func _on_event_opened() -> void:
	event_open = true
	pending_open = pending_open or panel != null
	if anim:
		anim.kill()
	if focus_tween:
		focus_tween.kill()
	if panel:
		panel.queue_free()
		panel = null
	ledger_rt = null
	closing = false

func _on_event_closed() -> void:
	event_open = false
	if pending_open:
		pending_open = false
		_open()

func _view_active() -> bool:
	var v := get_node_or_null("../AirportView")
	return v != null and v.active

func _marker() -> Node3D:
	if picker == null or not started:
		return null
	return picker.markers.get(picker.chosen_id)

func _airport_screen_pos() -> Variant:
	var cam := get_viewport().get_camera_3d()
	var mk := _marker()
	if cam == null or mk == null:
		return null
	var g: Vector3 = mk.global_position
	if cam.is_position_behind(g):
		return null
	var globe := mk.get_parent().get_parent() as Node3D
	var n := (g - globe.global_position).normalized()
	var to_cam := (cam.global_position - g).normalized()
	if n.dot(to_cam) < 0.05:
		return null
	return cam.unproject_position(g)

func _mouse_on_panel(mp: Vector2) -> bool:
	return panel != null and mp.x > get_viewport().get_visible_rect().size.x * 0.5

func _process(_d: float) -> void:
	if not started:
		return
	var mp := get_viewport().get_mouse_position()
	var over := false
	var sp = _airport_screen_pos()
	if sp != null and sp.distance_to(mp) < HIT_RADIUS and not _mouse_on_panel(mp) and not event_open and not _view_active():
		over = true
	hover_label.visible = over
	if over:
		hover_label.text = "Close airport menu" if panel != null else "Open airport menu"
		hover_label.position = mp + Vector2(16, 14)
	if not _view_active():
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if over else Input.CURSOR_ARROW)

func _unhandled_input(event: InputEvent) -> void:
	if not started:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			press_pos = event.position
			press_time = Time.get_ticks_msec()
		else:
			var moved: float = event.position.distance_to(press_pos)
			var elapsed := Time.get_ticks_msec() - press_time
			if moved < 6.0 and elapsed < 350:
				var sp = _airport_screen_pos()
				if sp != null and sp.distance_to(event.position) < HIT_RADIUS:
					_toggle()

func _toggle() -> void:
	if closing or event_open or _view_active():
		return
	if panel:
		_close()
	else:
		_open()

func _build_hover_label() -> void:
	hover_label = Label.new()
	hover_label.visible = false
	hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_label.add_theme_font_size_override("font_size", 14)
	hover_label.add_theme_stylebox_override("normal", _box(Color(0.04, 0.07, 0.13, 0.92), Color(1.0, 0.85, 0.3), 6, 6))
	add_child(hover_label)

func _open() -> void:
	if event_open:
		pending_open = true
		return
	if panel or closing:
		return
	_build_panel()
	_show_list()
	_focus_airport()
	_set_dx(SLIDE_DISTANCE)
	panel.modulate.a = 0.0
	if anim:
		anim.kill()
	anim = create_tween().set_parallel(true)
	anim.tween_method(_set_dx, SLIDE_DISTANCE, 0.0, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	anim.tween_property(panel, "modulate:a", 1.0, 0.25)

func _close() -> void:
	if panel == null or closing:
		return
	closing = true
	if anim:
		anim.kill()
	anim = create_tween().set_parallel(true)
	anim.tween_method(_set_dx, 0.0, SLIDE_DISTANCE, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	anim.tween_property(panel, "modulate:a", 0.0, 0.22)
	anim.chain().tween_callback(func() -> void:
		if panel:
			panel.queue_free()
			panel = null
		ledger_rt = null
		closing = false)

func _enter_airport() -> void:
	_close()
	enter_airport.emit()

func _set_dx(dx: float) -> void:
	if panel:
		panel.offset_left = 8 + dx
		panel.offset_right = -8 + dx

func _fade_content() -> void:
	content.modulate.a = 0.0
	create_tween().tween_property(content, "modulate:a", 1.0, 0.18)

func _focus_airport() -> void:
	if main == null or not ("yaw" in main) or not ("pitch" in main) or airport.is_empty():
		return
	var lon := deg_to_rad(airport["lon"])
	var lat := deg_to_rad(airport["lat"])
	var start_yaw: float = main.yaw
	var end_yaw: float = start_yaw + wrapf(-lon - 0.30 - start_yaw, -PI, PI)
	var start_pitch: float = main.pitch
	var end_pitch: float = clampf(lat, -deg_to_rad(80.0), deg_to_rad(80.0))
	main.velocity = Vector2.ZERO
	main.distance = 0.72
	if focus_tween:
		focus_tween.kill()
	focus_tween = create_tween()
	focus_tween.set_trans(Tween.TRANS_CUBIC)
	focus_tween.set_ease(Tween.EASE_OUT)
	focus_tween.tween_method(func(t: float) -> void:
		main.yaw = lerpf(start_yaw, end_yaw, t)
		main.pitch = lerpf(start_pitch, end_pitch, t)
		main._apply_rotation(), 0.0, 1.0, 1.0)

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
	ledger_rt = null
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()

func _show_list() -> void:
	_clear()
	var top := HBoxContainer.new()
	var title := _label(airport.get("name", "Your airport"), 30, Color.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(_close)
	top.add_child(close)
	content.add_child(top)
	content.add_child(_label(airport.get("place", ""), 15, Color(0.6, 0.75, 1.0), true))
	content.add_child(_label("What would you like to do?", 17, Color(0.85, 0.9, 1.0)))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	for o in OPTIONS:
		list.add_child(_make_card(o))
	content.add_child(list)
	_fade_content()

func _make_card(o: Dictionary) -> Button:
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
	v.add_theme_constant_override("separation", 4)
	v.add_child(_label(o["name"], 22, Color.WHITE))
	var tag := _label(o["tagline"], 14, Color(0.85, 0.88, 0.95))
	tag.clip_text = true
	tag.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(tag)
	m.add_child(v)
	b.add_child(m)
	b.pressed.connect(_show_detail.bind(o))
	return b

func _refresh_ledger() -> void:
	if ledger_rt != null and is_instance_valid(ledger_rt) and economy:
		ledger_rt.text = economy.ledger_bbcode()

func _show_ledger(o: Dictionary) -> void:
	_clear()
	var back := Button.new()
	back.text = "< Back"
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.pressed.connect(_show_list)
	content.add_child(back)
	content.add_child(_label(o["name"], 32, Color.WHITE, true))
	content.add_child(_label('"%s"' % o["joke"], 15, Color(1.0, 0.85, 0.5), true))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ledger_rt = RichTextLabel.new()
	ledger_rt.bbcode_enabled = true
	ledger_rt.fit_content = true
	ledger_rt.scroll_active = false
	ledger_rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ledger_rt.add_theme_font_size_override("normal_font_size", 16)
	ledger_rt.add_theme_font_size_override("bold_font_size", 18)
	ledger_rt.text = economy.ledger_bbcode() if economy else "The ledger is empty. AirportEconomy was not found."
	scroll.add_child(ledger_rt)
	content.add_child(scroll)
	_fade_content()

func _show_detail(o: Dictionary) -> void:
	if o["id"] == "ledger":
		_show_ledger(o)
		return
	_clear()
	var ready_now: bool = o.get("ready", false)
	var back := Button.new()
	back.text = "< Back"
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.pressed.connect(_show_list)
	content.add_child(back)
	content.add_child(_label(o["name"], 32, Color.WHITE, true))
	content.add_child(_label('"%s"' % o["joke"], 15, Color(1.0, 0.85, 0.5), true))
	if not ready_now:
		content.add_child(_label("Not working yet. This part is still being built.", 16, Color(1.0, 0.6, 0.4), true))
	content.add_child(_label(o["desc"], 16, Color(0.85, 0.9, 1.0), true))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	var go := Button.new()
	go.text = "Go to the airport" if ready_now else "Coming soon"
	go.disabled = not ready_now
	go.custom_minimum_size = Vector2(0, 52)
	go.add_theme_font_size_override("font_size", 20)
	if ready_now:
		go.add_theme_stylebox_override("normal", _box(Color(0.12, 0.45, 0.25), Color(0.4, 0.9, 0.55)))
		go.add_theme_stylebox_override("hover", _box(Color(0.16, 0.58, 0.32), Color(0.6, 1.0, 0.7)))
		go.add_theme_stylebox_override("pressed", _box(Color(0.1, 0.35, 0.2), Color(0.6, 1.0, 0.7)))
		go.pressed.connect(_enter_airport)
	content.add_child(go)
	_fade_content()
