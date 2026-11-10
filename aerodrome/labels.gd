extends Node3D

const GLOBE_RADIUS := 0.5
const LABEL_RADIUS := 0.504
const FONT_SIZE := 96
const MIN_SCREEN_FRAC := 0.015  # label must be at least this tall (fraction of the screen) to show

var labels: Array = []

func _ready() -> void:
	# the timeline manager (on the Globe) tells us which territories exist at each date
	get_parent().map_changed.connect(_rebuild)

func _rebuild(territories: Array) -> void:
	for l in labels:
		l["node"].queue_free()
	labels.clear()
	for c in territories:
		var country_name: String = c["n"]
		var width_world := deg_to_rad(c["w"]) * GLOBE_RADIUS
		var pixel_size := 0.6 * width_world / (maxf(country_name.length(), 1.0) * FONT_SIZE * 0.5)

		var label := Label3D.new()
		label.text = country_name
		label.font_size = FONT_SIZE
		label.pixel_size = pixel_size
		label.outline_size = 12
		label.modulate = Color(1, 1, 1, 0.95)
		label.outline_modulate = Color(0, 0, 0, 0.85)
		label.double_sided = false
		label.visible = false

		var n := _to_sphere(c["lon"], c["lat"])
		label.transform = Transform3D(Basis.looking_at(-n, Vector3.UP), n * LABEL_RADIUS)
		add_child(label)
		labels.append({"node": label, "height": FONT_SIZE * pixel_size})

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var altitude := cam.global_position.distance_to(global_position) - GLOBE_RADIUS
	var view_height := 2.0 * tan(deg_to_rad(cam.fov) / 2.0) * maxf(altitude, 0.001)
	for l in labels:
		var node: Label3D = l["node"]
		if is_instance_valid(node):
			node.visible = (l["height"] / view_height) > MIN_SCREEN_FRAC

func _to_sphere(lon_deg: float, lat_deg: float) -> Vector3:
	var lon := deg_to_rad(lon_deg)
	var lat := deg_to_rad(lat_deg)
	return Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))
