extends Node3D
@onready var map = $Test/map
@onready var player = $CharacterBody3D
@onready var doorway = $Area3D
@onready var central_pulse_manager = $PulseManager 
@onready var box_origin = $CSGBox3D # ASSUMING THIS IS THE BOX NODE YOU WANT TO PULSE
@onready var exit_area = $ExitArea
# Called when the node enters the scene tree for the first time.
@onready var cicadas = $Outside/Cicada
@onready var forest = $Outside/Forest
@onready var wind = $Outside/Wind

@export var exit_menu_scene: PackedScene # Drag your ExitMenu.tscn here
var exit_menu: CanvasLayer
var menu_script_instance: Node

@onready var box_audio_player: AudioStreamPlayer3D = $BoxAudioPlayer 

# Called when the node enters the scene tree for the first time.
func _ready():
	_setup_pulse_manager()
	_setup_exit_menu()
	if exit_area:
		# Connect the signal assuming it's a standard Area3D on the map
		exit_area.body_entered.connect(_on_exit_area_body_entered)
	else:
		push_error("Main: ExitArea node not found. Win condition will not trigger.")
	_setup_box_audio()
	await get_tree().process_frame# let map generate fully
	_play_with_random_pitch(cicadas)
	_play_with_random_pitch(forest)
	_play_with_random_pitch(wind)

var cooldown := 0.0
var box_pulse_cooldown := 3.0 # Cooldown for the new object's pulse

func _setup_box_audio():
	if box_audio_player and box_origin:
		# 1. Reparent the AudioStreamPlayer3D to the box node. 
		# This makes its position exactly match the box.
		box_audio_player.reparent(box_origin)
		
		# 2. Connect the 'finished' signal to the loop function
		box_audio_player.finished.connect(_on_box_audio_finished)
		
		# 3. Start playback immediately
		#box_audio_player.play()
		
	elif not box_audio_player:
		push_error("Main: BoxAudioPlayer (AudioStreamPlayer3D) node not found. Please add a node named 'BoxAudioPlayer'.")
	elif not box_origin:
		push_error("Main: Box origin node (CSGBox3D) not found. Cannot attach audio.")

func _on_box_audio_finished():
	# This function ensures the audio loops continuously
	box_audio_player.play()

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
	#if cooldown <= 0.0:
		#central_pulse_manager.emit_fixed_player_pulse(0.1) 
		#cooldown = 2.0
	#cooldown -= delta
	#
	# Box Pulse (uses the dedicated function that relies on _box_origin_node)
	if box_pulse_cooldown <= 0.0:
		central_pulse_manager.emit_box_pulse()
		box_pulse_cooldown = 5.0
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

func _setup_exit_menu():
	if exit_menu_scene:
		exit_menu = exit_menu_scene.instantiate()
		add_child(exit_menu)
		if exit_menu.get_child_count() > 0:
			menu_script_instance = exit_menu.get_child(0)
		else:
			# Fallback: Try to use the CanvasLayer root itself if no children exist
			menu_script_instance = exit_menu 
			
		# Connect the menu's signals to local functions
		menu_script_instance.restart_requested.connect(_on_restart_requested)
		menu_script_instance.quit_requested.connect(_on_quit_requested)
	else:
		push_error("Main: Exit Menu Scene is not assigned.")

func _on_restart_requested():
	# Reloads the entire scene (including the map generation)
	get_tree().reload_current_scene()

func _on_quit_requested():
	# This function simply exists to handle the signal locally, 
	# but the menu script handles the actual quit() call.
	pass

func _on_area_3d_body_entered(body):
	if body == player:
		player.environment_type = "inside"
		cicadas.stop()
		wind.stop()
		forest.stop()
		enter_maze()

func _on_exit_area_body_entered(body):
	# Check if the body that entered the Area3D is the player
	if body == player:
		if menu_script_instance:
			menu_script_instance.show_exit_menu("for game off 2025.")
