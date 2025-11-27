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
const room_width = 200 # cols
const outdoor_space = 100 # width, height is room_height; for trees and stuff
const wall_height = 10
const transom = 3 # space above the door; prolly not really transom, but it sounds cool so
const door_height = wall_height - transom
const door_width = 3
var rooms := {}
var lu := []
const max_retries = 10

class Room:
	var center_row = 0
	var center_col = 0
	var type = 0
	var row_size = 0
	var col_size = 0
	var hbound = [0,0]
	var vbound = [0,0]
	var own_mat = {}
	var global_mat = {}
	
	func _init(r,c,t):
		set_center(r,c)
		set_type(t)
		
	func update_mat(mat):
		global_mat = mat
		
	func set_center(r,c):
		center_row = r
		center_col = c
		
	func set_type(t):
		type = t
		
	func set_dims(r_size,c_size):
		row_size = r_size
		col_size = c_size
		
	func init_room():
		for row in row_size:
			for col in col_size:
				own_mat[Vector2(row,col)] = 'U'
				
	func find_bounds(mat,cT,cL,dir):
		if dir == 'lu':
			var upper_bound = 0
			var left_bound = 0
			for r in cT+1:
				if mat[Vector2(center_row-r,center_col)] == 'W':
					upper_bound = center_row-r
					break
					
			for c in cL+1:
				if mat[Vector2(center_row,center_col-c)] == 'W':
					left_bound = center_col-c
					break
			print('in room: ', upper_bound, ' ', left_bound)
			print('cT cL- ', cT, ' ', cL)
			print('center- ', center_row, ' ', center_col)
			print('mat lu: ', mat[Vector2(upper_bound,left_bound)])
			print(': ', mat[Vector2(upper_bound-1,left_bound)])
			print(': ', mat[Vector2(upper_bound+1,left_bound)])
			hbound[0] = upper_bound
			vbound[0] = left_bound
		
		elif dir == 'ru':
			var upper_bound = 0
			var right_bound = 0
			for r in cT+1:
				if mat[Vector2(center_row-r,center_col)] == 'W':
					upper_bound = center_row-r
					break
					
			for c in cL+1:
				if mat[Vector2(center_row,center_col+c)] == 'W':
					right_bound = center_col+c
					break
			print('in room: ', upper_bound, ' ', right_bound)
			print('cT cL- ', cT, ' ', cL)
			print('center- ', center_row, ' ', center_col)
			print('mat lu: ', mat[Vector2(upper_bound,right_bound)])
			print(': ', mat[Vector2(upper_bound-1,right_bound)])
			print(': ', mat[Vector2(upper_bound+1,right_bound)])
			hbound[0] = upper_bound
			vbound[0] = right_bound

		elif dir == 'lb':
			var bottom_bound = 0
			var left_bound = 0
			for r in cT+1:
				if mat[Vector2(center_row+r,center_col)] == 'W':
					bottom_bound = center_row+r
					break
					
			for c in cL+1:
				if mat[Vector2(center_row,center_col-c)] == 'W':
					left_bound = center_col-c
					break
			print('in room: ', bottom_bound, ' ', left_bound)
			print('cT cL- ', cT, ' ', cL)
			print('center- ', center_row, ' ', center_col)
			print('mat lu: ', mat[Vector2(bottom_bound,left_bound)])
			print(': ', mat[Vector2(bottom_bound-1,left_bound)])
			print(': ', mat[Vector2(bottom_bound+1,left_bound)])
			hbound[0] = bottom_bound
			vbound[0] = left_bound
			
		else:
			var bottom_bound = 0
			var right_bound = 0
			for r in cT+1:
				if mat[Vector2(center_row+r,center_col)] == 'W':
					bottom_bound = center_row+r
					break
					
			for c in cL+1:
				if mat[Vector2(center_row,center_col+c)] == 'W':
					right_bound = center_col+c
					break
			print('in room: ', bottom_bound, ' ', right_bound)
			print('cT cL- ', cT, ' ', cL)
			print('center- ', center_row, ' ', center_col)
			print('mat lu: ', mat[Vector2(bottom_bound,right_bound)])
			print(': ', mat[Vector2(bottom_bound-1,right_bound)])
			print(': ', mat[Vector2(bottom_bound+1,right_bound)])
			hbound[0] = bottom_bound
			vbound[0] = right_bound

func set_mat() -> void:
	# initialize mat
	# U - unset - initial state of all room
	for row: int in room_height:
		for col: int in room_width + outdoor_space:
			#if (row == 49 && col >= 24 && col <= 74) || (row == 149 && col >= 24 && col <= 74) || (col == 24 && row >= 49 && row <= 149) || (col == 74 && row >= 49 && row <= 149):
				#mat[Vector2(row,col)] = 'O' # outline, for doors
			#else: 
				#mat[Vector2(row,col)] = 'U'
			mat[Vector2(row,col)] = 'U'
			instance_count += 1
	
	# set walls for each room
	for i: int in N:
		var set_room_val = set_room()
		if set_room_val.size() == 0: continue
		var row = set_room_val[0]
		var col = set_room_val[1]
		var row_size = set_room_val[2]
		var col_size = set_room_val[3]
		var rtype = set_room_val[4]
		
		# if a room was detected along the current room's center axis, 
		# move units to the appropriate direction to be able to get the size specified by the room type
		var checker_val = checker(row, col, row_size, col_size)
		var redo = checker_val[0]

		# redo room assignment if room was mistakenly placed inside an existing room
		var retries_failed = false
		var counter = 0
		while redo: 
			set_room_val = set_room()
			if set_room_val.size() == 0 || counter == max_retries:
				retries_failed = true
				break
			row = set_room_val[0]
			col = set_room_val[1]
			row_size = set_room_val[2]
			col_size = set_room_val[3]
			rtype = set_room_val[4]
			
			# if a room was detected along the current room's center axis, 
			# move units to the appropriate direction to be able to get the size specified by the room type
			checker_val = checker(row, col, row_size, col_size)
			redo = checker_val[0]
			counter+=1
		
		if retries_failed: continue
		var new_room = Room.new(row,col,rtype)
		rooms[i] = new_room

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

		new_room.set_dims(cT+cB,cL+cR)

		print(i, ' room size: ', rooms[i].row_size, ' ', rooms[i].col_size)
		# assign walls and floors
		assign(row,col,cT,cL,'LU')
		assign(row,col,cT,cR,'RU')
		assign(row,col,cB,cL,'LB')
		assign(row,col,cB,cR,'RB')
		if cT == 0:
			if cL == 0:
				new_room.find_bounds(mat,cB,cR,'rb')
			else:
				new_room.find_bounds(mat,cB,cL,'lb')
		else:
			if cL == 0:
				new_room.find_bounds(mat,cT,cR,'ru')
			else:
				new_room.find_bounds(mat,cT,cL,'lu')
		doors(row,col,Vector2(new_room.hbound[0], new_room.vbound[0]),cT+cB,cL+cR)
	#walls(room_height,room_width)
	#old_doors()
	print_mat()
	print(instance_count)

func set_room() -> Array:
	var rng = RandomNumberGenerator.new()
	var half_height = room_height/2
	var half_width = room_width/2
	var row_min = (half_height/2)-1
	var col_min = (half_width/2)-1
	# get randomized row and col values
	var row = rng.randi_range(49,149)
	var col = rng.randi_range(24,74)
	# get randomized room type
	var rtype = rng.randi_range(0,6)

	# make sure to set unique rooms
	# and keep new rooms out of already existing rooms
	var counter = 0
	while counter < max_retries && mat[Vector2(row,col)] != 'U' && (mat[Vector2(row,col)] == 'F' || mat[Vector2(row,col)][0] == 'C' || mat[Vector2(row,col)] == 'W' || mat[Vector2(row,col)] == 'D'):
		row = rng.randi_range(row_min, row_min + half_height)
		col = rng.randi_range(col_min, col_min + half_width)
		counter+=1
	
	if counter == max_retries:
		return []
	# determine each room with their room type
	if mat[Vector2(row,col)] == 'U':
		mat[Vector2(row,col)] = 'C' + str(rtype)

	# get room type
	var rtype_size = room_types[rtype]
	var row_size = rtype_size[0]
	var col_size = rtype_size[1]
	
	return [row,col,row_size,col_size,rtype]

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

# add walls
func walls(row_size, col_size) -> void:
	for row: int in row_size:
		for col: int in col_size:
			# check in all directions if room has incomplete walls (U next to F)
			# and if a wall is an outer wall (for assigning windows and doors)
			if row == 0 || col == 0 || row == row_size-1 || col == col_size-1:
				continue
			if (mat[Vector2(row,col)] == 'U' && check_directions(row,col,'F','all')) || (mat[Vector2(row,col)] == 'W' &&  check_directions(row,col,'U','all')):
				mat[Vector2(row,col)] = 'OW'
				instance_count+=(wall_height-1)

# add doors to all inside walls
func old_doors() -> void:
	var rng = RandomNumberGenerator.new()
	# horizontally check walls
	for row: int in room_height:
		for col: int in room_width:
			if row == 0 || col == 0:
				continue
			
			if mat[Vector2(row,col)] == 'W':
				var wall = mat[Vector2(row,col)]
				var counter = 0
				var door_found = false
				var r = row
				var c = col
				var c_door = col
				while wall == 'W':
					if mat[Vector2(r-1,c)] == 'D':
						door_found = true
						c_door = c
						break
						
					counter += 1
					c+=1
					wall = mat[Vector2(r,c)]

				if door_found:
					var d = 0
					while wall == 'W':
						if d < door_width:
							mat[Vector2(r,c_door)] = 'D'
							c_door+=1
							d+=1
					
					
				elif counter > door_width:
					var start_pos = rng.randi_range(0,counter-3)
					c = col + start_pos
					while wall == 'W':
						mat[Vector2(r,c)] = 'D'
						c+=1

func doors(row,col,lu,row_size,col_size) -> void:
	print('lu ', lu)
	if mat[lu] != 'W': return
	var rng = RandomNumberGenerator.new()
	var row_start = lu[0]
	var col_start = lu[1]

	# top and bottom door
	var tb_door = col_start
	if col_size > 3:
		tb_door = rng.randi_range(col_start, (col_start + col_size)-door_width)

	for c: int in range(tb_door, tb_door+3):
		mat[Vector2(row_start,c)] = 'D'
		mat[Vector2(row_start+row_size,c)] = 'D'

	# left and right door
	var lr_door = row_start
	if row_size > 3:
		lr_door = rng.randi_range(row_start, (row_start + row_size)-door_width)
	
	for r: int in range(lr_door, lr_door+3):
		mat[Vector2(r,col_start)] = 'D'
		mat[Vector2(r,col_start+col_size)] = 'D'


# checks if all directions match to_check
func check_directions(row,col,to_check,dir) -> bool:
	if dir == 'up':
		return mat[Vector2(row-1,col)] == to_check
	elif dir == 'down':
		return mat[Vector2(row+1,col)] == to_check
	elif dir == 'left':
		return mat[Vector2(row,col-1)] == to_check
	elif dir == 'right':
		return mat[Vector2(row,col+1)] == to_check
	elif dir == 'lu':
		return mat[Vector2(row-1,col-1)] == to_check
	elif dir == 'ru':
		return mat[Vector2(row-1,col+1)] == to_check
	elif dir == 'lb':
		return mat[Vector2(row+1,col-1)] == to_check
	elif dir == 'rb':
		return mat[Vector2(row+1,col+1)] == to_check
	else:
		return mat[Vector2(row-1,col)] == to_check || mat[Vector2(row+1,col)] == to_check || mat[Vector2(row,col-1)] == to_check || mat[Vector2(row,col+1)] == to_check || mat[Vector2(row-1,col-1)] == to_check || mat[Vector2(row-1,col+1)] == to_check || mat[Vector2(row+1,col-1)] == to_check || mat[Vector2(row+1,col+1)] == to_check

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
	for row: int in room_height:
		for col: int in room_width + outdoor_space:
			# wall: W
			# outer wall: OW
			if mat[Vector2(row,col)] == 'W' || mat[Vector2(row,col)] == 'OW':
				for w: int in wall_height:
					multimesh.set_instance_transform(counter, Transform3D(basis, Vector3(row,w+1,col)))
					counter += 1

			# door
			elif mat[Vector2(row,col)] == 'D':
				# floor below
				multimesh.set_instance_transform(counter, Transform3D(basis, Vector3(row,0,col)))
				counter += 1
				
				# then door
				for d: int in range(door_height, wall_height+1):
					multimesh.set_instance_transform(counter, Transform3D(basis, Vector3(row,d,col)))
					counter += 1

			# floor
			else:
				multimesh.set_instance_transform(counter, Transform3D(basis, Vector3(row,0,col)))
				counter += 1
