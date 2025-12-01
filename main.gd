extends Node3D
@onready var map = $Test/map
@onready var player = $CharacterBody3D
@onready var doorway = $Area3D
@onready var central_pulse_manager = $PulseManager 
@onready var box_origin = $CSGBox3D # ASSUMING THIS IS THE BOX NODE YOU WANT TO PULSE

# Called when the node enters the scene tree for the first time.
@onready var cicadas = $Outside/Cicada
@onready var forest = $Outside/Forest
@onready var wind = $Outside/Wind
# Called when the node enters the scene tree for the first time.
func _ready():
	print("PLAYER =", player)

	_setup_pulse_manager()
	await get_tree().process_frame# let map generate fully
	_play_with_random_pitch(cicadas)
	_play_with_random_pitch(forest)
	_play_with_random_pitch(wind)

var cooldown := 0.0
var box_pulse_cooldown := 3.0 # Cooldown for the new object's pulse

func _setup_pulse_manager():
		# === CENTRALIZED PULSE MANAGER SETUP ===
	# 1. Set the visualization quad for the single, central manager.
	central_pulse_manager.set_quad_node(player.get_pulse_quad())
	
	# 2. Tell the central manager where the player is (for mic input pulses)
	# This must be the main player node to track its global position.
	central_pulse_manager.set_player_origin_node(player)
	
	# 3. Tell the central manager where the box is (for box pulses)
	# This uses the node referenced above.
	central_pulse_manager.set_box_origin_node(box_origin)
	# =======================================

func _process(delta):
	# Fixed Player Pulse
	if cooldown <= 0.0:
		central_pulse_manager.emit_fixed_player_pulse(0.1) 
		cooldown = 2.0
	cooldown -= delta
	
	# Box Pulse (uses the dedicated function that relies on _box_origin_node)
	if box_pulse_cooldown <= 0.0:
		central_pulse_manager.emit_box_pulse()
		box_pulse_cooldown = 3.0
	box_pulse_cooldown -= delta
		
func _play_with_random_pitch(sfxplayer: AudioStreamPlayer3D):
	# Random pitch range (adjust to taste)
	sfxplayer.pitch_scale = randf_range(0.97, 1.03)

	sfxplayer.play()

	# Reapply variation on each loop
	sfxplayer.finished.connect(func():
		_play_with_random_pitch(sfxplayer))
	


func enter_maze():
	var spawn = map.get_spawn_position()
	player.global_position = map.to_global(spawn)

func _on_area_3d_body_entered(body):
	if body == player:
		player.environment_type = "inside"
		cicadas.stop()
		wind.stop()
		forest.stop()
		enter_maze()
