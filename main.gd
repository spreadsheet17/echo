extends Node3D
@onready var map = $Test/map
@onready var player = $CharacterBody3D
@onready var doorway = $Area3D



# Called when the node enters the scene tree for the first time.
@onready var cicadas = $Outside/Cicada
@onready var forest = $Outside/Forest
@onready var wind = $Outside/Wind
# Called when the node enters the scene tree for the first time.
func _ready():
	await get_tree().process_frame  # let map generate fully
	_play_with_random_pitch(cicadas)
	_play_with_random_pitch(forest)
	_play_with_random_pitch(wind)

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
