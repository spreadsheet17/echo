@tool
extends MultiMeshInstance3D

@export var reload := false :
	set(new_reload):
		reload = false
		regenerate_mesh()
		Map.set_prop_state('BS')

# Called when the node enters the scene tree for the first time.
func _ready():
	#regenerate_mesh()
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Map.get_prop_state('MAP') && !Map.get_prop_state('BS'):
		regenerate_mesh()
		Map.set_prop_state('BS')
	pass


# ============================================
#             MULTIMESH STUFF
# ============================================
const N = 10 # no. of instances
var mesh: MultiMesh
const max_retries := 10
const shelf_width = 6
var used_pos := [] # keys
var mat_floor := []
var instance_counter = 0
var mesh_src = load("res://assets/Mesh/bookshelf.mesh")

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
	var shelf_half = shelf_width/2
	var rotated = basis
	for i in N:
		
		# get updated values
		rotated = basis # reset
		mat_floor = Map.mat_floor
		
		# get rotation
		var rot = rng.randi_range(0,1) # 0: horizontal, 1: vertical
		
		# get pos
		var pos = rng.randi_range(0,mat_floor.size()) # get starting point, index of the coords
		var tries = 0
		while mat_floor[pos] in Map.used_floor and tries < max_retries:
			pos = rng.randi_range(0,mat_floor.size())
			tries += 1
		if tries == max_retries: continue
		var row = mat_floor[pos][0]
		var col = mat_floor[pos][1]

		if rot == 0: # horizontal
			rotated = basis
			var l = 0
			var r = 0
			var l_stop = false # to make sure no position is skipped
			var r_stop = false
			# iterate through row
			for w in range(1, shelf_half+1):
				# check left
				if [row-w,col] in mat_floor && !l_stop:
					l+=1
				else: l_stop = true
				# check right
				if [row+w,col] in mat_floor && !r_stop:
					r+=1
				else: r_stop = true
				if l_stop && r_stop: break # stop if both directions don't have enough space
			if l == shelf_half && r == shelf_half: # pos is ok
				# use center pos
				Map.use_floor([row,col])
				used_pos.append([row,col])
				for w in range(1, shelf_half+1):
					#Map.mat[Vector2(row-w,col)] = 'P' # prop (P)
					#Map.mat[Vector2(row+w,col)] = 'P'

					# add to used_floor
					Map.use_floor([row-w,col])
					Map.use_floor([row+w,col])
					used_pos.append([row-w,col])
					used_pos.append([row+w,col])
			elif l < shelf_half && r == shelf_half: # left encountered something
				# check how many spaces are needed
				var spaces_needed = shelf_half - l
				var counter = 0
				# check the right side
				for sn in range(1,spaces_needed+1):
					if [row+r+sn,col] in mat_floor:
						counter += 1
				if counter == spaces_needed: # all spaces to the right are ok
					# change starting pos
					# W W F F F (F) (F)
					# find the index of the new starting pos
					pos = Map.find_floor([row+counter,col])
					row = mat_floor[pos][0]
					col = mat_floor[pos][1]
					# get all needed positions
					Map.use_floor([row,col])
					used_pos.append([row,col])
					for w in range(1, shelf_half+1):
						#Map.mat[Vector2(row-w,col)] = 'P' # prop (P)
						#Map.mat[Vector2(row+w,col)] = 'P'

						# add to used floor
						Map.use_floor([row-w,col])
						Map.use_floor([row+w,col])
						used_pos.append([row-w,col])
						used_pos.append([row+w,col])
				else: continue
			elif l == shelf_half && r < shelf_half: # right encountered something
				# check how many spaces are needed
				var spaces_needed = shelf_half - r
				var counter = 0
				# check if the left side has free space
				for sn in range(1,spaces_needed+1):
					if [row-l-sn,col] in mat_floor:
						counter += 1
				if counter == spaces_needed: # all spaces to the right are ok
					# change starting pos
					# (F) (F) F F F W W
					# find the index of the new starting pos
					pos = Map.find_floor([row-counter,col])
					row = mat_floor[pos][0]
					col = mat_floor[pos][1]
					Map.use_floor([row,col])
					used_pos.append([row,col])
					# get all needed positions
					for w in range(1, shelf_half+1):
						#Map.mat[Vector2(row-w,col)] = 'P' # prop (P)
						#Map.mat[Vector2(row+w,col)] = 'P'

						# add to used floor
						Map.use_floor([row-w,col])
						Map.use_floor([row+w,col])
						used_pos.append([row-w,col])
						used_pos.append([row+w,col])
				else: continue
			else: # no spaces available to place the whole bookshelf
				continue
					
		else: # vertical
			rotated = Basis.from_euler(Vector3(0, 90, 0) * deg_to_rad(1))
			var u = 0
			var d = 0
			var u_stop = false # to make sure no position is skipped
			var d_stop = false
			# iterate through col
			for w in range(1, shelf_half+1):
				# check up
				if [row,col-w] in mat_floor && !u_stop:
					u+=1
				else: u_stop = true
				# check down
				if [row,col+w] in mat_floor && !d_stop:
					d+=1
				else: d_stop = true
				if u_stop && d_stop: break # stop if both directions don't have enough space
			if u == shelf_half && d == shelf_half: # pos is ok
				# use center pos
				Map.use_floor([row,col])
				used_pos.append([row,col])
				for w in range(1, shelf_half+1):
					#Map.mat[Vector2(row-w,col)] = 'P' # prop (P)
					#Map.mat[Vector2(row+w,col)] = 'P'

					# add to used_floor
					Map.use_floor([row,col-w])
					Map.use_floor([row,col+w])
					used_pos.append([row,col-w])
					used_pos.append([row,col+w])
			elif u < shelf_half && d == shelf_half: # up encountered something
				# check how many spaces are needed
				var spaces_needed = shelf_half - u
				var counter = 0
				# check the bottom
				for sn in range(1,spaces_needed+1):
					if [row,col+d+sn] in mat_floor:
						counter += 1
				if counter == spaces_needed: # all spaces to the bottom are ok
					# change starting pos
					# W W F F F (F) (F)
					# find the index of the new starting pos
					pos = Map.find_floor([row,col+counter])
					row = mat_floor[pos][0]
					col = mat_floor[pos][1]
					# get all needed positions
					Map.use_floor([row,col])
					used_pos.append([row,col])
					for w in range(1, shelf_half+1):
						#Map.mat[Vector2(row-w,col)] = 'P' # prop (P)
						#Map.mat[Vector2(row+w,col)] = 'P'

						# add to used floor
						Map.use_floor([row,col-w])
						Map.use_floor([row,col+w])
						used_pos.append([row,col-w])
						used_pos.append([row,col+w])
				else: continue
			elif u == shelf_half && d < shelf_half: # right encountered something
				# check how many spaces are needed
				var spaces_needed = shelf_half - d
				var counter = 0
				# check if the left side has free space
				for sn in range(1,spaces_needed+1):
					if [row,col-u-sn] in mat_floor:
						counter += 1
				if counter == spaces_needed: # all spaces to the right are ok
					# change starting pos
					# (F) (F) F F F W W
					# find the index of the new starting pos
					pos = Map.find_floor([row,col-counter])
					row = mat_floor[pos][0]
					col = mat_floor[pos][1]
					Map.use_floor([row,col])
					used_pos.append([row,col])
					# get all needed positions
					for w in range(1, shelf_half+1):
						#Map.mat[Vector2(row-w,col)] = 'P' # prop (P)
						#Map.mat[Vector2(row+w,col)] = 'P'

						# add to used floor
						Map.use_floor([row,col-w])
						Map.use_floor([row,col+w])
						used_pos.append([row,col-w])
						used_pos.append([row,col+w])
				else: continue
			else: # no spaces available to place the whole bookshelf
				continue

		multimesh.set_instance_transform(instance_counter, Transform3D(rotated, Vector3(Map.mat_floor[pos][0],2.5,Map.mat_floor[pos][1])))
		#multimesh.set_instance_transform(instance_counter, Transform3D(rotated, Vector3(0,2.5,0)))
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
