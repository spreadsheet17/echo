@tool
extends MultiMeshInstance3D
var global_entrance_position: Vector3

@export var reload := false :
	set(new_reload):
		reload = false
		set_mat()
		regenerate_mesh()
		update_global()

# Called when the node enters the scene tree for the first time.
func _ready():
	set_mat()
	regenerate_mesh()
	update_global()

# Called every frame. 'delta' is the elapsed time since the previous frame.
var t := 0.0
var interval := 60.0 # seconds
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
const N: int = 50 # no. of rooms
const room_types := [
	[14, 10], # bedroom			- 0
	[20, 10], # kitchen			- 1
	[16, 20], # dining room		- 2
	[20, 20], # living room		- 3
	[10, 8], # toilet			- 4
	[18, 18], # some room 1		- 5
	[15, 15] # some room 2		- 6
	]
const room_sizes: PackedInt32Array = [[]]
var mat := {}
const room_height = 200 # rows
const room_width = 150 # cols
const outdoor_space = 100
const exit_space = outdoor_space/3
const wall_height = 10
const transom = 3 # space above the door; prolly not really transom, but it sounds cool so
const door_height = wall_height - transom
const door_width = 3
const window_width = 3
const window_height = 2
const window_count = 4
const window_boundary = 10
const steps = 1
var rooms := {}
var lu := []
const max_retries = 10
const me_custom_door_width = 0

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
			hbound[0] = bottom_bound
			vbound[0] = right_bound

func set_mat() -> void:
	# initialize mat
	# U - unset - initial state of all room
	for row: int in room_height:
		for col: int in exit_space + room_width + outdoor_space:
			mat[Vector2(row,col)] = 'U'
	
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

		#print(i, ' room size: ', rooms[i].row_size, ' ', rooms[i].col_size)
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
	walls(room_height,exit_space+room_width+outdoor_space)
	Map.set_mat(mat)

func set_room() -> Array:
	var rng = RandomNumberGenerator.new()
	var half_height = room_height/2
	var half_width = room_width/2
	var row_min = (half_height/2)-1
	var col_min = exit_space + (half_width/2)-1
	# get randomized row and col values
	var row = rng.randi_range(row_min, row_min + half_height)
	var col = rng.randi_range(col_min, col_min + half_width)
	# get randomized room type
	var rtype = rng.randi_range(0,room_types.size()-1)

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
				if c == col_size-1:
					if mat[Vector2(row-r,col-(c+1))] != 'W':
						mat[Vector2(row-r,col-(c+1))] = 'W'
				if r == row_size-1 && c == col_size-1:
					if mat[Vector2(row-(r+1),col-(c+1))] != 'W':
						mat[Vector2(row-(r+1),col-(c+1))] = 'W'

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
				if c == col_size-1:
					if mat[Vector2(row-r,col+(c+1))] != 'W':
						mat[Vector2(row-r,col+(c+1))] = 'W'
				if r == row_size-1 && c == col_size-1:
					if mat[Vector2(row-(r+1),col+(c+1))] != 'W':
						mat[Vector2(row-(r+1),col+(c+1))] = 'W'

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
				if c == col_size-1:
					if mat[Vector2(row+r,col-(c+1))] != 'W':
						mat[Vector2(row+r,col-(c+1))] = 'W'
				if r == row_size-1 && c == col_size-1:
					if mat[Vector2(row+(r+1),col-(c+1))] != 'W':
						mat[Vector2(row+(r+1),col-(c+1))] = 'W'

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
				if c == col_size-1:
					if mat[Vector2(row+r,col+(c+1))] != 'W':
						mat[Vector2(row+r,col+(c+1))] = 'W'
				if r == row_size-1 && c == col_size-1:
					if mat[Vector2(row+(r+1),col+(c+1))] != 'W':
						mat[Vector2(row+(r+1),col+(c+1))] = 'W'

# add inner walls (W) for exposed rooms
# add outer walls (OW) for windows and main entrance
func walls(row_size, col_size) -> void:
	for row: int in row_size:
		for col: int in exit_space + room_width + outdoor_space:
			# check in all directions if room has incomplete walls (U next to F)
			# and if a wall is an outer wall (for assigning windows and doors)
			if row == 0 || col == 0 || row == row_size-1 || col == col_size-1:
				continue
			if (mat[Vector2(row,col)] == 'U' && check_directions(row,col,'F','all')) || (mat[Vector2(row,col)] == 'W' &&  check_directions(row,col,'U','all')):
				mat[Vector2(row,col)] = 'W'
	
	# ---- WALLS ----
	var max := [room_height,0,room_width,0] # top, bottom, left, right
	for row: int in row_size:
		for col: int in col_size:
			if mat[Vector2(row,col)] == 'W':
				# left
				if max[0] >= row:
					max[0] = row
				# right
				if max[1] <= row:
					max[1] = row
				# top
				if max[2] >= col:
					max[2] = col
				# bottom
				if max[3] <= col:
					max[3] = col

	# side walls
	for c in range(max[2],max[3]):
		mat[Vector2(max[0],c)] = 'OW'
		mat[Vector2(max[1],c)] = 'OW'

	# top and bottom walls
	for r in range(max[0],max[1]):
		mat[Vector2(r,max[2])] = 'OW'
		mat[Vector2(r,max[3])] = 'OW'
	
	# add floors
	for r in range(max[0],max[1]):
		for c in range(max[2],max[3]):
			if mat[Vector2(r,c)] == 'U':
				mat[Vector2(r,c)] = 'F'

	# ---- WINDOWS ----
	var width = max[1] - max[0]
	var length = max[3] - max[2]
	var win_width_half = window_width/2
	
	# LEFT AND RIGHT
	for c in range(max[2],max[3],width/(window_count)):
		if c == max[2] || c == max[3]:
			continue
		
		for w in window_width:
			if w < win_width_half:
				mat[Vector2(max[0],(c-window_boundary)-w)] = 'M'
				mat[Vector2(max[1],(c-window_boundary)-w)] = 'M'
			else:
				mat[Vector2(max[0],(c-window_boundary)+w)] = 'M'
				mat[Vector2(max[1],(c-window_boundary)+w)] = 'M'

	# TOP AND BOTTOM
	for r in range(max[0],max[1],length/(window_count)):
		if r == max[0] || r == max[1]:
			continue
		
		for w in window_width:
			if w < win_width_half:
				mat[Vector2((r-window_boundary)-w,max[2])] = 'M'
				mat[Vector2((r-window_boundary)-w,max[3])] = 'M'
			else:
				mat[Vector2((r-window_boundary)+w,max[2])] = 'M'
				mat[Vector2((r-window_boundary)+w,max[3])] = 'M'

	print('bounds (lrtb): ', max)
	
	# ---- MAIN ENTRANCE AND EXIT ----
	var me_length = length/4
	# place in the middle
	var center = (width/2)+max[0]
	var end = max[3]+outdoor_space/3
	var other_end = max[2]-outdoor_space/3 # for the exit
	global_entrance_position = Vector3(center, 3.5, end - steps)
	var main_door_width = door_width + me_custom_door_width

	# outer walls, the ones with windows
	# front wall
	for i in me_length:
		# entrance
		mat[Vector2(center-i,end)] = 'OW'
		mat[Vector2(center+i,end)] = 'OW'
		# exit
		mat[Vector2(center-i,other_end)] = 'OW'
		mat[Vector2(center+i,other_end)] = 'OW'
	
	# sides
	for i in end-max[3]:
		# entrance
		mat[Vector2(center-(me_length-1),max[3]+i)] = 'OW'
		mat[Vector2(center+(me_length-1),max[3]+i)] = 'OW'
	
	for i in max[2]-other_end:
		# exit
		mat[Vector2(center-(me_length-1),max[2]-i)] = 'OW'
		mat[Vector2(center+(me_length-1),max[2]-i)] = 'OW'

	# door to the house
	var type = 'OD'
	for i in main_door_width:
		if i == main_door_width-1: type = 'W'
		else: type = 'OD'
		
		# entrance
		mat[Vector2(center-i,end)] = type
		mat[Vector2(center+i,end)] = type
		mat[Vector2(center-i,max[3])] = type
		mat[Vector2(center+i,max[3])] = type
		
		if mat[Vector2(center-i,max[3]-1)] in ['W', 'OW', 'M']:
			mat[Vector2(center-i,max[3]-1)] = type
		if mat[Vector2(center+i,max[3]-1)] in ['W', 'OW', 'M']:
			mat[Vector2(center+i,max[3]-1)] = type
		
		# make sure space after door is clear
		mat[Vector2(center-i,max[3]-2)] = 'OF'
		mat[Vector2(center+i,max[3]-2)] = 'OF'
		
		# exit
		mat[Vector2(center-i,other_end)] = type
		mat[Vector2(center+i,other_end)] = type
		mat[Vector2(center-i,max[2])] = type
		mat[Vector2(center+i,max[2])] = type
		
		if mat[Vector2(center-i,max[2]+1)] in ['W', 'OW', 'M']:
			mat[Vector2(center-i,max[2]+1)] = type
		if mat[Vector2(center+i,max[2]+1)] in ['W', 'OW', 'M']:
			mat[Vector2(center+i,max[2]+1)] = type
		
		# make sure space before door is clear
		mat[Vector2(center-i,max[2]+2)] = 'OF'
		mat[Vector2(center+i,max[2]+2)] = 'OF'
	
	# door and corridor
	# entrance
	for i in end-max[3]:
		for d in main_door_width:
			if d == main_door_width-1:
				mat[Vector2(center-(main_door_width-1),max[3]+i)] = 'W'
				mat[Vector2(center+(main_door_width-1),max[3]+i)] = 'W'
			elif i == end-max[3]-1:
				mat[Vector2(center-d,max[3]+i)] = 'D'
				mat[Vector2(center+d,max[3]+i)] = 'D'
			elif i == 0:
				mat[Vector2(center-d,max[3]+i)] = 'D'
				mat[Vector2(center+d,max[3]+i)] = 'D'
			else:
				mat[Vector2(center-d,max[3]+i)] = 'OF'
				mat[Vector2(center+d,max[3]+i)] = 'OF'
	# exit
	for i in max[2]-other_end:
		for d in main_door_width:
			if d == main_door_width-1:
				mat[Vector2(center-(main_door_width-1),max[2]-i)] = 'W'
				mat[Vector2(center+(main_door_width-1),max[2]-i)] = 'W'
			elif i == end-max[3]-1:
				mat[Vector2(center-d,max[2]-i)] = 'D'
				mat[Vector2(center+d,max[2]-i)] = 'D'
			elif i == 0:
				mat[Vector2(center-d,max[2]-i)] = 'D'
				mat[Vector2(center+d,max[2]-i)] = 'D'
			else:
				mat[Vector2(center-d,max[2]-i)] = 'OF'
				mat[Vector2(center+d,max[2]-i)] = 'OF'

	# step -> changed to wall to block user from going out
	for d in main_door_width:
		# entrance
		mat[Vector2(center-d,end+steps)] = 'W'
		mat[Vector2(center+d,end+steps)] = 'W'
		
		# exit
		mat[Vector2(center-d,other_end-steps)] = 'W'
		mat[Vector2(center+d,other_end-steps)] = 'W'


func doors(row,col,lu,row_size,col_size) -> void:
	#print('lu ', lu)
	if mat[lu] != 'W': return
	var rng = RandomNumberGenerator.new()
	var row_start = lu[0]
	var col_start = lu[1]

	# top and bottom door
	var tb_door = col_start
	if col_size > 3:
		tb_door = rng.randi_range(col_start, (col_start + col_size)-door_width)

	for c: int in range(tb_door, tb_door+3):
		if mat[Vector2(row_start,c)] == 'W': 
			mat[Vector2(row_start,c)] = 'D'
		if mat[Vector2(row_start+row_size,c)] == 'W': 
			mat[Vector2(row_start+row_size,c)] = 'D'

	# left and right door
	var lr_door = row_start
	if row_size > 3:
		lr_door = rng.randi_range(row_start, (row_start + row_size)-door_width)
	
	for r: int in range(lr_door, lr_door+3):
		if mat[Vector2(r,col_start)] == 'W': 
			mat[Vector2(r,col_start)] = 'D'
		if mat[Vector2(r,col_start+col_size)] == 'W': 
			mat[Vector2(r,col_start+col_size)] = 'D'

# checks if all directions match to_check
func check_directions(row,col,to_check,dir) -> bool:
	if dir == 'up':
		if row-1 < 0: return false
		return mat[Vector2(row-1,col)] == to_check
	elif dir == 'down':
		if row+1 >= room_height: return false
		return mat[Vector2(row+1,col)] == to_check
	elif dir == 'left':
		if col-1 < 0: return false
		return mat[Vector2(row,col-1)] == to_check
	elif dir == 'right':
		if col+1 >= room_width: return false
		return mat[Vector2(row,col+1)] == to_check
	elif dir == 'lu':
		if row-1 < 0 || col-1 < 0: return false
		return mat[Vector2(row-1,col-1)] == to_check
	elif dir == 'ru':
		if row-1 < 0 || col+1 >= room_width: return false
		return mat[Vector2(row-1,col+1)] == to_check
	elif dir == 'lb':
		if row+1 > room_height || col-1 < 0: return false
		return mat[Vector2(row+1,col-1)] == to_check
	elif dir == 'rb':
		if row+1 > room_height || col+1 >= room_width: return false
		return mat[Vector2(row+1,col+1)] == to_check
	elif dir == 'all':
		if row-1<0 || col-1< 0 || row+1 > room_height || col+1 >= room_width: return false
		return mat[Vector2(row-1,col)] == to_check || mat[Vector2(row+1,col)] == to_check || mat[Vector2(row,col-1)] == to_check || mat[Vector2(row,col+1)] == to_check || mat[Vector2(row-1,col-1)] == to_check || mat[Vector2(row-1,col+1)] == to_check || mat[Vector2(row+1,col-1)] == to_check || mat[Vector2(row+1,col+1)] == to_check

	else: # strict-all-d; strict check for isolated doors
		var counter = 0 # 8 checks
		if row-1>=0 && (mat[Vector2(row-1,col)] == to_check || mat[Vector2(row-1,col)] == 'D'):
			counter += 1
		
		if col-1>=0 && (mat[Vector2(row,col-1)] == to_check || mat[Vector2(row,col-1)] == 'D'):
			counter += 1
				
		if row+1<room_height && (mat[Vector2(row+1,col)] == to_check || mat[Vector2(row+1,col)] == 'D'):
			counter += 1
		
		if col+1<room_width && (mat[Vector2(row,col+1)] == to_check || mat[Vector2(row,col+1)] == 'D'):
			counter += 1
		
		
		
		if row-1>=0 && col-1>=0 && (mat[Vector2(row-1,col-1)] == to_check || mat[Vector2(row-1,col-1)] == 'D'):
			counter += 1
				
		if row-1>=0 && col+1<room_width && (mat[Vector2(row-1,col+1)] == to_check || mat[Vector2(row-1,col+1)] == 'D'):
			counter += 1
		
		if row+1<room_height && col-1>=0 && (mat[Vector2(row+1,col-1)] == to_check || mat[Vector2(row+1,col-1)] == 'D'):
			counter += 1

		if row+1<room_height && col+1<room_width && (mat[Vector2(row+1,col+1)] == to_check || mat[Vector2(row+1,col+1)] == 'D'):
			counter += 1
		
		return counter == 8

func count_instances() -> int:
	var floor = [] # coordinates of floors
	var instance_count : int = 0
	for row in room_height:
		for col in exit_space + room_width + outdoor_space:
			if mat[Vector2(row,col)] == 'W' || mat[Vector2(row,col)] == 'OW':
				instance_count += wall_height
				instance_count += 1 # ceiling count
			elif mat[Vector2(row,col)] == 'D':
				instance_count += transom+2
				instance_count += 1 # ceiling count
			elif mat[Vector2(row,col)] == 'M':
				instance_count += (wall_height-window_height)
				instance_count += 1 # ceiling count
			
			# floor
			elif mat[Vector2(row,col)] == 'F' || mat[Vector2(row,col)][0] == 'C' || mat[Vector2(row,col)] == 'OF':
				instance_count += 1
				instance_count += 1 # ceiling count
				if mat[Vector2(row,col)] == 'F':
					floor.append([row,col])
	Map.set_floors(floor)
	
	print('instance count: ', instance_count)
	return instance_count

func print_mat():
	for i: int in room_height:
		var str = ""
		for j: int in exit_space + room_width + outdoor_space:
			if mat[Vector2(i,j)] == 'U': continue
			str += mat[Vector2(i,j)]
		print(str)

# ============================================
#             MULTIMESH STUFF
# ============================================
var mesh: MultiMesh
var instances = 0
func regenerate_mesh() -> void:
	if !mesh:
		mesh = MultiMesh.new()
		mesh.transform_format = MultiMesh.TRANSFORM_3D
		mesh.mesh = BoxMesh.new()
		multimesh = mesh

	multimesh.instance_count = count_instances()
	instances = count_instances()
	var counter = 0
	for row: int in room_height:
		for col: int in exit_space + room_width + outdoor_space:
			# wall: W
			# outer wall: OW
			if mat[Vector2(row,col)] == 'W' || mat[Vector2(row,col)] == 'OW':
				for w: int in wall_height:
					multimesh.set_instance_transform(counter, Transform3D(basis, Vector3(row,w+1,col)))
					counter += 1
				# ceiling
				multimesh.set_instance_transform(counter, Transform3D(basis, Vector3(row,wall_height,col)))
				counter += 1

			# door: D
			elif mat[Vector2(row,col)] == 'D':
				# door
				for d: int in transom+1:
					multimesh.set_instance_transform(counter, Transform3D(basis, Vector3(row,d+door_height,col)))
					counter += 1
				
				# floor
				multimesh.set_instance_transform(counter, Transform3D(basis, Vector3(row,1,col)))
				counter += 1
				# ceiling
				multimesh.set_instance_transform(counter, Transform3D(basis, Vector3(row,wall_height,col)))
				counter += 1
			
			# window: M
			elif mat[Vector2(row,col)] == 'M':
				for w: int in wall_height:
					if w >= (wall_height-(transom+window_height)) && w < wall_height-transom: continue
					multimesh.set_instance_transform(counter, Transform3D(basis, Vector3(row,w+1,col)))
					counter += 1
					
				# ceiling
				multimesh.set_instance_transform(counter, Transform3D(basis, Vector3(row,wall_height,col)))
				counter += 1
			
			# floor
			elif mat[Vector2(row,col)] == 'F' || mat[Vector2(row,col)][0] == 'C' || mat[Vector2(row,col)] == 'OF':
				multimesh.set_instance_transform(counter, Transform3D(basis, Vector3(row,1,col)))
				counter += 1
				
				# ceiling
				multimesh.set_instance_transform(counter, Transform3D(basis, Vector3(row,wall_height,col)))
				counter += 1
	build_collision()

const chunk_size = 32
func build_collision() -> void:
	remove_chunks()
	var chunks := {}
	for i in instances:
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
	print('chunks: ', chunks.keys().size())

var chunk_body : StaticBody3D
func create_chunk_collision(chunk_key: Vector3i, positions: Array):
	chunk_body = StaticBody3D.new()
	chunk_body.name = "Chunk_%d_%d" % [chunk_key.x, chunk_key.y]
	add_child(chunk_body)
	
	for pos in positions:
		var shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		shape.shape = box
		shape.transform.origin = pos.origin
		chunk_body.add_child(shape)

func remove_chunks() -> void:
	print('child count: ', get_child_count())
	for child in get_children():
		child.queue_free()

func update_global() -> void:
	# initialize props
	Map.init_props() # set all states to false
	# set map prop to true, to trigger creation of other props
	Map.set_prop_state('MAP')
 
func get_spawn_position() -> Vector3:
	return global_entrance_position
