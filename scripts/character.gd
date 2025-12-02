extends CharacterBody3D

@export var speed := 20.0
@export var jump_velocity := 5.0
@export var mouse_sensitivity := 0.003
@export var pulse_mesh_ref: MeshInstance3D 
@onready var camera = $CameraPivot/Camera3D

var pitch := 0.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var environment_type := "outside"
@onready var footstep_player = $Footsteps

var footstep_paths_inside :Array[String]= [
	"res://assets/Footsteps_Tile_Walk/Footsteps_Tile_Walk_01.wav",
	"res://assets/Footsteps_Tile_Walk/Footsteps_Tile_Walk_02.wav",
	"res://assets/Footsteps_Tile_Walk/Footsteps_Tile_Walk_03.wav",
	"res://assets/Footsteps_Tile_Walk/Footsteps_Tile_Walk_04.wav",
	"res://assets/Footsteps_Tile_Walk/Footsteps_Tile_Walk_05.wav",
	"res://assets/Footsteps_Tile_Walk/Footsteps_Tile_Walk_06.wav",
	"res://assets/Footsteps_Tile_Walk/Footsteps_Tile_Walk_07.wav",
	"res://assets/Footsteps_Tile_Walk/Footsteps_Tile_Walk_08.wav"
	
]
var footstep_paths_outside: Array[String] = [
	"res://assets/Outside/Footsteps_DirtyGround_Walk_01.wav",
	"res://assets/Outside/Footsteps_DirtyGround_Walk_02.wav",
	"res://assets/Outside/Footsteps_DirtyGround_Walk_03.wav",
	"res://assets/Outside/Footsteps_DirtyGround_Walk_04.wav",
	"res://assets/Outside/Footsteps_DirtyGround_Walk_05.wav",
	"res://assets/Outside/Footsteps_DirtyGround_Walk_06.wav",
	"res://assets/Outside/Footsteps_DirtyGround_Walk_07.wav",
	"res://assets/Outside/Footsteps_DirtyGround_Walk_08.wav",
	"res://assets/Outside/Footsteps_DirtyGround_Walk_09.wav",
	"res://assets/Outside/Footsteps_DirtyGround_Walk_10.wav",
	"res://assets/Outside/Footsteps_Gravel_Walk_01.wav",
	"res://assets/Outside/Footsteps_Gravel_Walk_02.wav",
	"res://assets/Outside/Footsteps_Gravel_Walk_03.wav",
	"res://assets/Outside/Footsteps_Gravel_Walk_04.wav",
	"res://assets/Outside/Footsteps_Gravel_Walk_05.wav",
	"res://assets/Outside/Footsteps_Gravel_Walk_06.wav",
	"res://assets/Outside/Footsteps_Gravel_Walk_07.wav",
	"res://assets/Outside/Footsteps_Gravel_Walk_08.wav",
	"res://assets/Outside/Footsteps_Gravel_Walk_09.wav",
	"res://assets/Outside/Footsteps_Gravel_Walk_10.wav",
	"res://assets/Outside/Footsteps_Leaves_Walk_01.wav",
	"res://assets/Outside/Footsteps_Leaves_Walk_02.wav",
	"res://assets/Outside/Footsteps_Leaves_Walk_03.wav",
	"res://assets/Outside/Footsteps_Leaves_Walk_04.wav",
	"res://assets/Outside/Footsteps_Leaves_Walk_05.wav",
	"res://assets/Outside/Footsteps_Leaves_Walk_06.wav",
	"res://assets/Outside/Footsteps_Mud_Walk_01.wav",
	"res://assets/Outside/Footsteps_Mud_Walk_02.wav",
	"res://assets/Outside/Footsteps_Mud_Walk_03.wav",
	"res://assets/Outside/Footsteps_Mud_Walk_04.wav",
	"res://assets/Outside/Footsteps_Mud_Walk_05.wav",
	"res://assets/Outside/Footsteps_Mud_Walk_06.wav",
	"res://assets/Outside/Footsteps_Mud_Walk_07.wav",
	"res://assets/Outside/Footsteps_Mud_Walk_08.wav",
	"res://assets/Outside/Footsteps_Mud_Walk_09.wav",
	"res://assets/Outside/Footsteps_Mud_Walk_10.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_01.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_02.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_03.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_04.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_05.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_06.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_07.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_08.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_09.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_10.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_11.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_12.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_13.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_14.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_15.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_16.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_17.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_18.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_19.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_20.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_21.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_22.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_23.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_24.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_25.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_26.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_27.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_28.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_29.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_30.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_31.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_32.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_33.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_34.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_35.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_36.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_37.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_38.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_39.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_40.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_41.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_42.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_43.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_44.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_45.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_46.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_47.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_48.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_49.wav",
	"res://assets/Outside/Footsteps_Walk_Grass_Mono_50.wav"
]

#func load_audio_folder(path: String) -> Array:
	#var files := []
	#var dir := DirAccess.open(path)
	#
	#if dir:
		#dir.list_dir_begin()
		#var file_name = dir.get_next()
		#while file_name != "":
			#if file_name.get_extension() == "wav":
				#files.append(load(path + "/" + file_name))
			#file_name = dir.get_next()
		#dir.list_dir_end()
		#
	#return files
var footstep_sounds_inside: Array[AudioStream] = []
var footstep_sounds_outside: Array[AudioStream] = []
# --- CRITICAL FIX: This function now returns the MeshInstance3D directly ---
# Simplified function: Just returns the variable you assigned in the Inspector
func get_pulse_quad() -> MeshInstance3D:
	if pulse_mesh_ref == null:
		push_error("CRITICAL: You forgot to assign 'Pulse Mesh Ref' in the Character Inspector!")
	return pulse_mesh_ref
func _ready():
	var loaded_inside_streams = footstep_paths_inside.map(func(path): return load(path))
	
	for stream in loaded_inside_streams:
		# Only append if the resource successfully loaded as an AudioStream
		if stream is AudioStream:
			footstep_sounds_inside.append(stream)
		else:
			push_error("Failed to load INSIDE audio stream.")


	# 2. Load outside sounds
	var loaded_outside_streams = footstep_paths_outside.map(func(path): return load(path))
	
	for stream in loaded_outside_streams:
		if stream is AudioStream:
			footstep_sounds_outside.append(stream)
		else:
			push_error("Failed to load OUTSIDE audio stream.")
	
	# Clear path arrays (optional, to save memory)
	footstep_paths_inside.clear()
	footstep_paths_outside.clear()

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

func _process(delta):
	pass

		
func play_random_footstep():
	var sfx: AudioStream
	var target_array: Array[AudioStream]
	
	if environment_type == "inside" and footstep_sounds_inside.size() > 0:
		target_array = footstep_sounds_inside
	elif footstep_sounds_outside.size() > 0:
		target_array = footstep_sounds_outside
	else:
		return # Avoid crash if arrays are empty

	sfx = target_array[randi() % target_array.size()]
	
	footstep_player.stream = sfx # Now sfx is a loaded AudioStream object!
	footstep_player.pitch_scale = randf_range(0.95, 1.05)# slight variation
	footstep_player.play()
