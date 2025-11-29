extends CharacterBody3D

@export var speed := 20.0
@export var jump_velocity := 5.0
@export var mouse_sensitivity := 0.003

@onready var camera = $CameraPivot/Camera3D
@onready var pulse_mesh = $CameraPivot/Camera3D/PulseManager
var wave_cooldown := 0
var mic_capture
var loudness_threshold = 0.001

var pitch := 0.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var footstep_player = $Footsteps

var footstep_sounds := [
	preload("res://assets/Footsteps_Tile_Walk/Footsteps_Tile_Walk_01.wav"),
	preload("res://assets/Footsteps_Tile_Walk/Footsteps_Tile_Walk_02.wav"),
	preload("res://assets/Footsteps_Tile_Walk/Footsteps_Tile_Walk_03.wav"),
	preload("res://assets/Footsteps_Tile_Walk/Footsteps_Tile_Walk_04.wav"),
	preload("res://assets/Footsteps_Tile_Walk/Footsteps_Tile_Walk_05.wav"),
	preload("res://assets/Footsteps_Tile_Walk/Footsteps_Tile_Walk_06.wav"),
	preload("res://assets/Footsteps_Tile_Walk/Footsteps_Tile_Walk_07.wav"),
	preload("res://assets/Footsteps_Tile_Walk/Footsteps_Tile_Walk_08.wav")	
]
func _ready():
	var bus_index = AudioServer.get_bus_index("Mic")

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
var step_distance := 10
var step_accum := 0.0

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
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horizontal_speed > 0.1:
		step_accum += horizontal_speed * delta
		
		if step_accum >= step_distance:
			step_accum = 0
			play_random_footstep()

	move_and_slide()

var last_loudness := 0.0
func _process(delta):
	wave_cooldown -= delta
	if mic_capture and wave_cooldown <= 0: 
		var buffer = mic_capture.get_buffer(256) 
		if buffer.size() == 0: 
			return 
		# Compute average loudness 
		var loudness := 0.0 
		for sample in buffer: 
			var mono = (sample.x + sample.y)
			loudness += abs(mono)
		loudness /= buffer.size() 
		#print(loudness)
		if (loudness-last_loudness) > loudness_threshold and wave_cooldown <= 0.0: 
			pulse_mesh.emit_wave_with_params(loudness)
			print("PULSE!")
			wave_cooldown = 1.5
		last_loudness = loudness
	#if Input.is_action_just_pressed("ui_accept"):
		#pulse_mesh.emit_wave_with_params(loudness)
		
func play_random_footstep():
	var sfx = footstep_sounds[randi() % footstep_sounds.size()]
	footstep_player.stream = sfx
	footstep_player.pitch_scale = randf_range(0.95, 1.05)  # slight variation
	footstep_player.play()
