extends Node3D

@onready var globe: MeshInstance3D = $Globe
@onready var cam: Camera3D = $Camera3D

const MIN_DIST := 0.53
const MAX_DIST := 0.9
const IDLE_SPIN := 0.0
const MAX_PITCH := 85.0  # degrees, so you can see the poles but never flip

var distance := 0.9
var dragging := false
var velocity := Vector2.ZERO
var yaw := 0.0    # left-right turn
var pitch := 0.4  # up-down tilt (starts showing a bit of the north)

func _ready() -> void:
	_apply_rotation()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if dragging:
				velocity = Vector2.ZERO
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = max(MIN_DIST, distance * 0.9)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = min(MAX_DIST, distance * 1.1)
	elif event is InputEventMouseMotion and dragging:
		var speed := 0.004 * (distance - 0.5)  # slower when zoomed in
		velocity = event.relative * speed
		_spin(velocity)

func _process(delta: float) -> void:
	if not dragging:
		_spin(velocity)
		velocity = velocity.lerp(Vector2.ZERO, 4.0 * delta)
		if velocity.length() < 0.0005 and IDLE_SPIN != 0.0:
			yaw += IDLE_SPIN * delta
			_apply_rotation()
	cam.position.z = lerpf(cam.position.z, distance, 10.0 * delta)

func _spin(v: Vector2) -> void:
	yaw += v.x
	pitch = clampf(pitch + v.y, -deg_to_rad(MAX_PITCH), deg_to_rad(MAX_PITCH))
	_apply_rotation()

func _apply_rotation() -> void:
	# spin around the globe's own axis first, then tilt the whole globe toward the camera
	globe.basis = Basis(Vector3.RIGHT, pitch) * Basis(Vector3.UP, yaw)
