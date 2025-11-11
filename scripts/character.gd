extends CharacterBody3D

@export var speed := 5.0
@export var jump_velocity := 5.0
@export var mouse_sensitivity := 0.003

@onready var camera = $CameraPivot/Camera3D

var wave_cooldown := 0.0
var loudness_threshold = 0.05

var pitch := 0.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- Input and rotation ---
func _unhandled_input(event):
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
 
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		pitch = clamp(pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-89), deg_to_rad(89))
		camera.rotation.x = pitch

# --- Movement ---
func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_dir = Input.get_vector("move_left","move_right","move_forward","move_back")
	var dir = (transform.basis * Vector3(input_dir.x,0,input_dir.y)).normalized()

	if dir:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	move_and_slide()
