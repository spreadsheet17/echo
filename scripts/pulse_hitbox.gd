extends Area3D

var radius := 0.0
var speed := 1.0
var max_distance := 20.0
var origin := Vector3.ZERO
var manager

@onready var col := $CollisionShape3D
func _ready():
	body_entered.connect(_on_body_entered)
	
func start(origin_pos, _speed, _max_distance, _manager):
	manager = _manager
	origin = origin_pos
	radius = 0.0
	speed = _speed
	max_distance = _max_distance
	global_position = origin

	# reset collider
	var shape := SphereShape3D.new()
	shape.radius = 0.1
	col.shape = shape

func _process(delta):
	radius += delta * speed
	# grow collider with the visible radius
	col.shape.radius = radius

	if radius > max_distance:
		queue_free()

func _on_body_entered(body):
	# Godot names must match exactly
	if body.has_method("flash"):
		print("flash!")
		body.flash()
