@tool
extends MultiMeshInstance3D

@export var reload := false :
	set(new_reload):
		reload = false
		regenerate_mesh()
		Map.set_prop_state('CW')

# Called when the node enters the scene tree for the first time.
func _ready():
	#regenerate_mesh()
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Map.get_prop_state('T') && !Map.get_prop_state('CW'):
		regenerate_mesh()
		Map.set_prop_state('CW')


# ============================================
#             MULTIMESH STUFF
# ============================================
const N = 20 # no. of instances
var mesh: MultiMesh
const max_retries := 10
var used_pos := [] # keys
var mat_floor := []
var instance_counter = 0
var mesh_src = load("res://assets/Mesh/chair_with_wheels.mesh")

func regenerate_mesh() -> void:
	# put back previously used positions on the map
	for i in range(0,used_pos.size()):
		if used_pos[i] in Map.used_floor:
			Map.used_floor.erase(used_pos[i])
			Map.add_floor(used_pos[i]) # add position back to mat_floor
	instance_counter = 0
	used_pos = []
	
	if !mesh:
		mesh = MultiMesh.new()
		mesh.transform_format = MultiMesh.TRANSFORM_3D
		mesh.mesh = mesh_src
		multimesh = mesh

	multimesh.instance_count = 0
	multimesh.instance_count = N
	var rng = RandomNumberGenerator.new()
	const degs = [0, 90, 180, 270, 360]
	var deg = degs.pick_random()
	var rotation = Vector3(deg_to_rad(-90), 0, deg_to_rad(deg))
	var scale = Vector3(150, 150, 150)
	for i in N:
		# get updated values
		mat_floor = Map.mat_floor

		# get pos
		var pos = rng.randi_range(0,mat_floor.size()) # get starting point, index of the coords
		var tries = 0
		while mat_floor[pos] in Map.used_floor and tries < max_retries:
			pos = rng.randi_range(0,mat_floor.size())
			tries += 1
		if tries == max_retries: continue
		var row = mat_floor[pos][0]
		var col = mat_floor[pos][1]
		used_pos.append([row,col])

		deg = degs.pick_random()
		rotation = Vector3(deg_to_rad(-90), 0, deg_to_rad(deg))
		multimesh.set_instance_transform(instance_counter, Transform3D(Basis.from_euler(rotation).scaled(scale), Vector3(row,3,col)))
		instance_counter+=1
	
	build_collision()

const chunk_size = 32
var rotations = []
func build_collision() -> void:
	rotations = []
	remove_chunks()
	var chunks := {}
	for i in instance_counter:
		var instance = multimesh.get_instance_transform(i)
		var chunk_key = Vector3i(
			instance.origin[0] / chunk_size,
			instance.origin[1] / chunk_size,
			instance.origin[2] / chunk_size
		)
		
		if chunk_key not in chunks:
			chunks[chunk_key] = []
		chunks[chunk_key].append(instance)
		
	for key in chunks.keys():
		var pos = chunks[key]
		create_chunk_collision(key, pos)

var chunk_body : StaticBody3D
var mesh_shape = mesh_src.create_convex_shape()
func create_chunk_collision(chunk_key: Vector3i, positions: Array):
	chunk_body = StaticBody3D.new()
	chunk_body.name = "Chunk_%d_%d" % [chunk_key.x, chunk_key.y]
	add_child(chunk_body)
	
	for pos in positions:
		var shape = CollisionShape3D.new()
		shape.shape = mesh_shape
		shape.transform.origin = pos.origin
		shape.transform = pos
		chunk_body.add_child(shape)

func remove_chunks() -> void:
	for child in get_children():
		child.queue_free()
