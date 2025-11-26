@tool
extends MultiMeshInstance3D

@export var reload := false :
	set(new_reload):
		reload = false
		set_mat()
		regenerate_mesh()

# Called when the node enters the scene tree for the first time.
func _ready():
	set_mat()
	regenerate_mesh()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

# ============================================
#             MAP GENERATION
# ============================================

# randomly place N rooms
# get room corner indices by assigning the type of room
# - move horizontally on both sides w/2 units
# - move vertically on both sides h/2 units
# w and h are pairs of room sizes randomly selected
# make sure no rooms are overlapping
# put door on the side that is not against a wall
const N: int = 40 # no. of rooms
const room_types := [
	[14, 10], # bedroom			- 0
	[20, 10], # kitchen			- 1
	[16, 20], # dining room		- 2
	[24, 24], # living room		- 3
	[10, 8], # toilet			- 4
	[18, 18], # some room 1		- 5
	[28, 28] # some room 2		- 6
	]
const room_sizes: PackedInt32Array = [[]]
var mat := {}
const room_height = 200 # rows
const room_width = 100 # cols
const wall_height = 10
const transom = 3 # space above the door; prolly not really transom, but it sounds cool so
const door_height = wall_height - transom
const door_width = 3


func set_mat() -> void:
	# initialize mat
	# U - unset - initial state of all room
	for row: int in room_height:
		for col: int in room_width:
			#if (row == 49 && col >= 24 && col <= 74) || (row == 149 && col >= 24 && col <= 74) || (col == 24 && row >= 49 && row <= 149) || (col == 74 && row >= 49 && row <= 149):
				#mat[Vector2(row,col)] = 'O' # outline, for doors
			#else: 
				#mat[Vector2(row,col)] = 'U'
			mat[Vector2(row,col)] = 'U'
			instance_count += 1
	
	# set walls for each room
	for i: int in N:
		var set_room_val = set_room()
		var row = set_room_val[0]
		var col = set_room_val[1]
		var row_size = set_room_val[2]
		var col_size = set_room_val[3]
		
		# if a room was detected along the current room's center axis, 
		# move units to the appropriate direction to be able to get the size specified by the room type
		var checker_val = checker(row, col, row_size, col_size)
		var redo = checker_val[0]

		# redo room assignment if room was mistakenly placed inside an existing room
		while redo: 
			set_room_val = set_room()
			row = set_room_val[0]
			col = set_room_val[1]
			row_size = set_room_val[2]
			col_size = set_room_val[3]
			
			# if a room was detected along the current room's center axis, 
			# move units to the appropriate direction to be able to get the size specified by the room type
			checker_val = checker(row, col, row_size, col_size)
			redo = checker_val[0]

		var cL = checker_val[1]
		var cR = checker_val[2]
		var cT = checker_val[3]
		var cB = checker_val[4]
		
		if cL > cR:
			cL += ((col_size/2)-cR)
		elif cL < cR:
			cR += ((col_size/2)-cL)
			
		if cT > cB:
			cT += ((row_size/2)-cB)
		elif cT < cB:
			cB += ((row_size/2)-cT)

		# assign walls and floors
		assign(row,col,cT,cL,'LU')
		assign(row,col,cT,cR,'RU')
		assign(row,col,cB,cL,'LB')
		assign(row,col,cB,cR,'RB')
	walls_checker(room_height,room_width)
	print_mat()
	print(instance_count)

func set_room() -> Array:
	var rng = RandomNumberGenerator.new()
	# get randomized row and col values
	var row = rng.randi_range(49,149)
	var col = rng.randi_range(24,74)
	# get randomized room type
	var rtype = rng.randi_range(0,6)

	# make sure to set unique rooms
	# and keep new rooms out of already existing rooms
	while mat[Vector2(row,col)] != 'U' || mat[Vector2(row,col)] == 'F' || mat[Vector2(row,col)][0] == 'C':
		row = rng.randi_range(49,149)
		col = rng.randi_range(24,74)

	# determine each room with their room type
	if mat[Vector2(row,col)] == 'U':
		mat[Vector2(row,col)] = 'C' + str(rtype)

	# get room type
	var rtype_size = room_types[rtype]
	var row_size = rtype_size[0]
	var col_size = rtype_size[1]
	
	return [row,col,row_size,col_size]

func checker(row, col, row_size, col_size) -> Array[int]:
	var cL = 0
	var cR = 0
	var cT = 0
	var cB = 0
	var cLStop = false
	var cRStop = false
	var cTStop = false
	var cBStop = false
	
	if mat[Vector2(row,col)] == 'F' || mat[Vector2(row,col-1)] == 'F' || mat[Vector2(row,col+1)] == 'F' || mat[Vector2(row-1,col)] == 'F' || mat[Vector2(row+1,col)] == 'F':
		return [1]
	
	for c in col_size/2:
		if c == 0: continue
		if mat[Vector2(row,col-c)] != 'W' && !cLStop:
			cL+=1
		else: cLStop = true
			
		if mat[Vector2(row,col+c)] != 'W' && !cRStop:
			cR+=1
		else: cRStop = true

	for r in row_size/2:
		if r == 0: continue
		if mat[Vector2(row-r,col)] != 'W' && !cTStop:
			cT+=1
		else: cTStop = true
		
		if mat[Vector2(row+r,col)] != 'W' && !cBStop:
			cB+=1
		else: cBStop = true

	return [0, cL, cR, cT, cB]

# assign walls and rooms
func assign(row,col,row_size,col_size,dir) -> void:
	if dir == 'LU':
		for r in row_size:
			for c in col_size:
				if r == 0 && col == 0:
					continue

				if mat[Vector2(row-r,col-c)] == 'W': break
				
				if mat[Vector2(row-r,col-c)] != 'W' && mat[Vector2(row-r,col-c)] == 'U':
					mat[Vector2(row-r,col-c)] = 'F'
				if r == row_size-1:
					if mat[Vector2(row-(r+1),col-c)] != 'W':
						mat[Vector2(row-(r+1),col-c)] = 'W'
						instance_count += (wall_height-1)
				if c == col_size-1:
					if mat[Vector2(row-r,col-(c+1))] != 'W':
						mat[Vector2(row-r,col-(c+1))] = 'W'
						instance_count += (wall_height-1)
				if r == row_size-1 && c == col_size-1:
					if mat[Vector2(row-(r+1),col-(c+1))] != 'W':
						mat[Vector2(row-(r+1),col-(c+1))] = 'W'
						instance_count += (wall_height-1)

	if dir == 'RU':
		for r in row_size:
			for c in col_size:
				if r == 0 && col == 0:
					continue
					
				if mat[Vector2(row-r,col+c)] == 'W': break
					
				if mat[Vector2(row-r,col+c)] != 'W' && mat[Vector2(row-r,col+c)] == 'U':
					mat[Vector2(row-r,col+c)] = 'F'
				if r == row_size-1:
					if mat[Vector2(row-(r+1),col+c)] != 'W':
						mat[Vector2(row-(r+1),col+c)] = 'W'
						instance_count += (wall_height-1)
				if c == col_size-1:
					if mat[Vector2(row-r,col+(c+1))] != 'W':
						mat[Vector2(row-r,col+(c+1))] = 'W'
						instance_count += (wall_height-1)
				if r == row_size-1 && c == col_size-1:
					if mat[Vector2(row-(r+1),col+(c+1))] != 'W':
						mat[Vector2(row-(r+1),col+(c+1))] = 'W'
						instance_count += (wall_height-1)

	if dir == 'LB':
		for r in row_size:
			for c in col_size:
				if r == 0 && col == 0:
					continue
				
				if mat[Vector2(row+r,col-c)] == 'W': break

				if mat[Vector2(row+r,col-c)] != 'W' && mat[Vector2(row+r,col-c)] == 'U':
					mat[Vector2(row+r,col-c)] = 'F'
				if r == row_size-1:
					if mat[Vector2(row+(r+1),col-c)] != 'W':
						mat[Vector2(row+(r+1),col-c)] = 'W'
						instance_count += (wall_height-1)
				if c == col_size-1:
					if mat[Vector2(row+r,col-(c+1))] != 'W':
						mat[Vector2(row+r,col-(c+1))] = 'W'
						instance_count += (wall_height-1)
				if r == row_size-1 && c == col_size-1:
					if mat[Vector2(row+(r+1),col-(c+1))] != 'W':
						mat[Vector2(row+(r+1),col-(c+1))] = 'W'
						instance_count += (wall_height-1)

	if dir == 'RB':
		for r in row_size:
			for c in col_size:
				if r == 0 && col == 0:
					continue

				if mat[Vector2(row+r,col+c)] == 'W': break

				if mat[Vector2(row+r,col+c)] != 'W' && mat[Vector2(row+r,col+c)] == 'U':
					mat[Vector2(row+r,col+c)] = 'F'
				if r == row_size-1:
					if mat[Vector2(row+(r+1),col+c)] != 'W':
						mat[Vector2(row+(r+1),col+c)] = 'W'
						instance_count += (wall_height-1)
				if c == col_size-1:
					if mat[Vector2(row+r,col+(c+1))] != 'W':
						mat[Vector2(row+r,col+(c+1))] = 'W'
						instance_count += (wall_height-1)
				if r == row_size-1 && c == col_size-1:
					if mat[Vector2(row+(r+1),col+(c+1))] != 'W':
						mat[Vector2(row+(r+1),col+(c+1))] = 'W'
						instance_count += (wall_height-1)

# add walls after room assignment
func walls_checker(row_size, col_size) -> void:
	for row: int in row_size:
		for col: int in col_size:
			# check in all directions if U is next to F
			if row == 0 || col == 0 || row == row_size-1 || col == col_size-1:
				continue
			if mat[Vector2(row,col)] == 'U' &&  (mat[Vector2(row-1,col)] == 'F' || mat[Vector2(row+1,col)] == 'F' || mat[Vector2(row,col-1)] == 'F' || mat[Vector2(row,col+1)] == 'F' || mat[Vector2(row-1,col-1)] == 'F' || mat[Vector2(row-1,col+1)] == 'F' || mat[Vector2(row+1,col-1)] == 'F' || mat[Vector2(row+1,col+1)] == 'F'):
				mat[Vector2(row,col)] = 'W'
				instance_count+=(wall_height-1)

func print_mat():
	for i: int in room_height:
		var str = ""
		for j: int in room_width:
			str += mat[Vector2(i,j)]
		print(str)

# ============================================
#             MULTIMESH STUFF
# ============================================
var mesh: MultiMesh
var instance_count : int = 0 # incremented by set_mat()

func regenerate_mesh() -> void:
	if !mesh:
		mesh = MultiMesh.new()
		mesh.transform_format = MultiMesh.TRANSFORM_3D
		mesh.mesh = BoxMesh.new()
		multimesh = mesh
	#multimesh.buffer.clear()
	
	multimesh.instance_count = instance_count
	var counter = 0
	for row in room_height:
		for col in room_width:
			# wall
			if mat[Vector2(row,col)] == 'W':
				for w in wall_height:
					multimesh.set_instance_transform(counter, Transform3D(basis, Vector3(row,w+1,col)))
					counter += 1

			# floor
			else:
				multimesh.set_instance_transform(counter, Transform3D(basis, Vector3(row,0,col)))
				counter += 1
