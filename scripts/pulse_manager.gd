# PulseManager.gd
extends Node3D

@export var quad_node_path: NodePath  # assign the fullscreen quad MeshInstance3D
@export var origin_node_path: NodePath  # assign the player or node to use as origin (or camera)
@export var pulse_scene_limit := 50 # must match shader array length
@export var max_distance := 100.0
@export var pulse_speed := 10.0
@export var spawn_interval := 2.0
@export var pulse_width := 5.0
@export var world_scale := 0.95
@export var pulse_hitbox_scene: PackedScene

var _quad: MeshInstance3D
var _origin_node: Node3D
var _last_emit := 0.0

# pulses is an array of dictionaries: {origin:Vector3, radius:float, speed:float}
var pulses: Array = []

func _ready():
	_quad = get_node(quad_node_path) if quad_node_path != null else null
	_origin_node = get_node(origin_node_path) if origin_node_path != null else null

	if not _quad:
		push_error("PulseManager: quad_node_path not assigned or invalid.")
	if not _origin_node:
		push_warning("PulseManager: origin_node_path not assigned. You can emit with explicit caller.")
var local_cooldown := 0.0

func _process(delta):
	local_cooldown -= delta
	_last_emit += delta
	_update_pulses(delta)
	_upload_pulses_to_shader()
# call this to emit a new pulse at origin_node.global_transform.origin
func emit_wave():
	if _origin_node == null:
		return
	if _last_emit < spawn_interval:
		return
	_last_emit = 0.0

	var origin_pos: Vector3 = _origin_node.global_transform.origin
	_enqueue_pulse(origin_pos, 0.0, pulse_speed, pulse_width, Color(1, 1, 1), 1.0, max_distance)
	
	_spawn_hitbox(origin_pos)
	
func emit_wave_with_params(loudness: float):
	if local_cooldown > 0.0:
		return  # too soon
	# Normalize loudness into a usable 0..1 range
	var intensity : float = clamp(loudness * 2.0, 0.0, 1.0)

	# Modify speed, width, and max distance based on loudness
	var speed : float = lerp(5.0, 50.0, intensity)           # quiet → slow, loud → very fast
	var width : float = lerp(1.0, 10.0, intensity)           # quiet → thin, loud → fat wave
	var distance : float = lerp(30.0, max_distance, intensity)      # quiet → dies fast, loud → reaches far
	var alpha : float = 1.0
	var quiet_threshold := 0.1
	var medium_threshold := 0.2
	var loud_threshold := 0.4   # anything above this = red

	# Emit
	var origin_pos := _origin_node.global_position

	var color : Color = Color(1, 1, 1) 
	if loudness < quiet_threshold:
		color = Color(1, 1, 1)  # pure white
	elif loudness < medium_threshold:
		color = Color(1.0, 0.9, 0.2)  # bright yellow
	else:
		color = Color(0.9, 0.0, 0.0)  # deep blood red
	#_quad.get_active_material(0).set_shader_parameter("pulse_color", color)
	_enqueue_pulse(origin_pos, 0.0, speed, width, color, alpha, distance)
	#pulse_width = width
	#max_distance = distance
	
	_spawn_hitbox(origin_pos)
	local_cooldown = 1.5
func _spawn_hitbox(origin_pos: Vector3):
	if pulse_hitbox_scene == null:
		return
	var h = pulse_hitbox_scene.instantiate()
	add_child(h)
	h.start(origin_pos, pulse_speed, max_distance, self)

# internal: add new pulse or reuse oldest if full (queue behavior)
func _enqueue_pulse(origin: Vector3, radius: float, speed: float, width: float, color: Color, alpha: float, distance: float):
	if pulses.size() < pulse_scene_limit:
		pulses.append({"origin": origin, "radius": radius, "speed": speed, "width": width, "color": color, "alpha": alpha, "distance": distance})
	else:
		# recycle the oldest (FIFO), reset its properties
		pulses[0] = {"origin": origin, "radius": radius, "speed": speed, "width": width, "color": color, "alpha": alpha, "distance": distance}
		pulses = pulses.slice(1, pulses.size()) + [pulses[0]]  # move it to back

func _update_pulses(delta):
	# update radii and remove finished pulses
	var i := 0
	while i < pulses.size():
		var p = pulses[i]
		p.radius += p.speed * delta
		var t : float = clamp(p.radius / p.distance, 0.0, 1.0)
		p.alpha = 1.0 - t
		pulses[i] = p  # IMPORTANT

		if p.alpha <= 0.01:
			pulses.remove_at(i)
		else:
			i += 1
	var n := pulses.size()
	var i2 := 0
	while i2 < n:
		var p1 = pulses[i2]

		var j2 := i2 + 1
		while j2 < n:
			var p2 = pulses[j2]

			# p1 overtakes p2
			if p1.radius > p2.radius and p1.speed > p2.speed:
				pulses.remove_at(j2)
				n -= 1
				continue

			# p2 overtakes p1 → kill p1
			elif p2.radius > p1.radius and p2.speed > p1.speed:
				pulses.remove_at(i2)
				n -= 1
				i2 -= 1
				break

			j2 += 1

		i2 += 1
func _upload_pulses_to_shader():
	if _quad == null:
		return
	var mat := _quad.get_active_material(0)
	if not mat:
		return

	var count := pulses.size()
	# Build arrays with fixed max length (fill unused with zeros)
	var origins_arr := []
	var radii_arr := []
	for i in range(pulse_scene_limit):
		if i < count:
			origins_arr.append(pulses[i].origin)
			radii_arr.append(pulses[i].radius)
		else:
			origins_arr.append(Vector3.ZERO)
			radii_arr.append(0.0)

	mat.set_shader_parameter("pulse_count", count)
	mat.set_shader_parameter("pulse_origins", origins_arr)
	mat.set_shader_parameter("pulse_radii", radii_arr)
	mat.set_shader_parameter("world_scale", world_scale)
	var color_arr := []
	var width_arr := []
	var alpha_arr := []
	for i in range(pulse_scene_limit):
		if i < count:
			width_arr.append(pulses[i]["width"])
			var c: Color = pulses[i]["color"]
			color_arr.append(Vector4(c.r, c.g, c.b, c.a))
			var a = pulses[i]["alpha"]
			alpha_arr.append(Vector4(a, a, a, a))  # or Vector4(0,0,0,a)

		else:
			width_arr.append(0.0)
			alpha_arr.append(0.0)
			color_arr.append(Vector4(1.0, 1.0, 1.0, 1.0))
			
	mat.set_shader_parameter("pulse_widths", width_arr)
	mat.set_shader_parameter("pulse_colors", color_arr)
	mat.set_shader_parameter("pulse_alphas", alpha_arr)
