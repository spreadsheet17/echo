extends CharacterBody3D

@export var speed := 10.0
@export var jump_velocity := 5.0
@export var mouse_sensitivity := 0.003

@onready var camera = $CameraPivot/Camera3D
@onready var pulse_mesh = $CameraPivot/Camera3D/PulseManager
var wave_cooldown := 0.0

var mic_capture
var loudness_threshold = 0.0005

var pitch := 0.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready():
	var bus_index = AudioServer.get_bus_index("Master")
	for i in range(AudioServer.get_bus_effect_count(bus_index)):
		var effect = AudioServer.get_bus_effect(bus_index, i)
		if effect is AudioEffectCapture:
			mic_capture = effect
			break
# --- Input and rotation ---
func _unhandled_input(event):
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
 
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
	
func _process(delta):
	if mic_capture: 
		var buffer = mic_capture.get_buffer(256) 
		if buffer.size() == 0: 
			return 
		# Compute average loudness 
		var loudness := 0.0 
		for sample in buffer: 
			var mono = (sample.x + sample.y)
			loudness += abs(mono)
			loudness /= buffer.size() 
		print("Mic loudness:", loudness) 
		if loudness > loudness_threshold and wave_cooldown <= 0.0: 
			pulse_mesh.emit_wave() 
