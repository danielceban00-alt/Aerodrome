extends Node3D

@onready var globe: MeshInstance3D = $Globe
@onready var cam: Camera3D = $Camera3D

const MIN_DIST := 1.3
const MAX_DIST := 8.0
const IDLE_SPIN := 0.15  # radians per second when nothing is happening

var distance := 3.0
var dragging := false
var velocity := Vector2.ZERO

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
		if velocity.length() < 0.0005:
			globe.global_rotate(Vector3.UP, IDLE_SPIN * delta)
	cam.position.z = lerpf(cam.position.z, distance, 10.0 * delta)

func _spin(v: Vector2) -> void:
	globe.global_rotate(Vector3.UP, v.x)
	globe.global_rotate(Vector3.RIGHT, v.y)
