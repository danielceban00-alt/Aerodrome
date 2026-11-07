extends CanvasLayer

signal day_passed(year: int, month: int, day: int)
signal month_changed(year: int, month: int)
signal year_changed(year: int)

const MONTHS := ["January", "February", "March", "April", "May", "June",
		"July", "August", "September", "October", "November", "December"]
const WEEKDAYS := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
const BUTTON_LABELS := ["II", ">", ">>"]
const BUTTON_TIPS := ["Pause (Space)", "Normal speed (1)", "Fast (2)"]
# game days per real second for: paused, x1, x2
const DAYS_PER_SECOND := [0.0, 0.5, 1.0]

var year := 1920
var month := 1
var day := 1
var weekday := 3  # 1 January 1920 was a Thursday (Monday = 0)
var speed_index := 1
var last_speed := 1
var day_progress := 0.0


var date_label: Label
var sub_label: Label
var progress_bar: ProgressBar
var buttons: Array[Button] = []

func _ready() -> void:
	_build_ui()
	_set_speed(1)
	_update_label()

func _box(bg: Color, border: Color, radius: int, margin: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s

func _style_button(b: Button) -> void:
	var normal := _box(Color(0.10, 0.16, 0.28, 0.9), Color(0.5, 0.7, 1.0, 0.25), 6, 3)
	var hover := _box(Color(0.16, 0.25, 0.42, 0.95), Color(0.6, 0.8, 1.0, 0.45), 6, 3)
	var active := _box(Color(0.20, 0.45, 0.85, 1.0), Color(0.7, 0.85, 1.0, 0.8), 6, 3)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", active)
	b.add_theme_stylebox_override("hover_pressed", active)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_font_size_override("font_size", 13)

func _build_ui() -> void:
	# full-screen holder that lets mouse clicks pass through to the globe
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# small panel in the top-left corner
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	panel.add_theme_stylebox_override("panel",
			_box(Color(0.04, 0.08, 0.16, 0.78), Color(0.5, 0.7, 1.0, 0.3), 10))
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	margin.add_child(col)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)

	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", -2)
	row.add_child(texts)

	date_label = Label.new()
	date_label.custom_minimum_size = Vector2(150, 0)
	date_label.add_theme_font_size_override("font_size", 17)
	texts.add_child(date_label)

	sub_label = Label.new()
	sub_label.add_theme_font_size_override("font_size", 10)
	sub_label.add_theme_color_override("font_color", Color(0.65, 0.78, 1.0, 0.8))
	texts.add_child(sub_label)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 5)
	btn_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(btn_row)

	var group := ButtonGroup.new()
	for i in BUTTON_LABELS.size():
		var b := Button.new()
		b.text = BUTTON_LABELS[i]
		b.tooltip_text = BUTTON_TIPS[i]
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(34, 26)
		b.focus_mode = Control.FOCUS_NONE  # so Space doesn't press a focused button
		_style_button(b)
		b.pressed.connect(_set_speed.bind(i))
		btn_row.add_child(b)
		buttons.append(b)

	# thin bar showing how far through the current month we are
	progress_bar = ProgressBar.new()
	progress_bar.min_value = 0.0
	progress_bar.max_value = 1.0
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(0, 3)
	progress_bar.add_theme_stylebox_override("background",
			_box(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 2))
	progress_bar.add_theme_stylebox_override("fill",
			_box(Color(0.45, 0.70, 1.0, 0.9), Color(0, 0, 0, 0), 2))
	col.add_child(progress_bar)

func _process(delta: float) -> void:
	var rate: float = DAYS_PER_SECOND[speed_index]
	if rate > 0.0:
		day_progress += rate * delta
		while day_progress >= 1.0:
			day_progress -= 1.0
			_advance_day()
	_update_label()

func _advance_day() -> void:
	day += 1
	weekday = (weekday + 1) % 7
	if day > _days_in_month(year, month):
		day = 1
		month += 1
		if month > 12:
			month = 1
			year += 1
			year_changed.emit(year)
		month_changed.emit(year, month)
	day_passed.emit(year, month, day)

func _days_in_month(y: int, m: int) -> int:
	match m:
		2:
			var leap := (y % 4 == 0 and y % 100 != 0) or y % 400 == 0
			return 29 if leap else 28
		4, 6, 9, 11:
			return 30
		_:
			return 31

func _set_speed(i: int) -> void:
	speed_index = i
	if i != 0:
		last_speed = i
	buttons[i].button_pressed = true

func _update_label() -> void:
	date_label.text = "%d %s %d" % [day, MONTHS[month - 1], year]
	sub_label.text = "PAUSED" if speed_index == 0 else WEEKDAYS[weekday].to_upper()
	progress_bar.value = (float(day - 1) + day_progress) / float(_days_in_month(year, month))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_set_speed(last_speed if speed_index == 0 else 0)
			KEY_1:
				_set_speed(1)
			KEY_2:
				_set_speed(2)
