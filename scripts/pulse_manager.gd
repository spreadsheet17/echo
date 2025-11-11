# PulseManager.gd
extends Node3D

@export var quad_node_path: NodePath  # assign the fullscreen quad MeshInstance3D
@export var origin_node_path: NodePath  # assign the player or node to use as origin (or camera)
@export var pulse_scene_limit := 16  # must match shader array length
@export var max_distance := 100.0
@export var pulse_speed := 10.0
@export var spawn_interval := 1
@export var pulse_width := 5.0
@export var world_scale := 0.95

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

func _process(delta):
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
	_enqueue_pulse(origin_pos, 0.0, pulse_speed)

# internal: add new pulse or reuse oldest if full (queue behavior)
func _enqueue_pulse(origin: Vector3, radius: float, speed: float):
	if pulses.size() < pulse_scene_limit:
		pulses.append({"origin": origin, "radius": radius, "speed": speed})
	else:
		# recycle the oldest (FIFO), reset its properties
		pulses[0] = {"origin": origin, "radius": radius, "speed": speed}
		pulses = pulses.slice(1, pulses.size()) + [pulses[0]]  # move it to back

func _update_pulses(delta):
	# update radii and remove finished pulses
	var i := 0
	while i < pulses.size():
		pulses[i].radius += pulses[i].speed * delta
		if pulses[i].radius > max_distance:
			pulses.remove_at(i)
		else:
			i += 1

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
	mat.set_shader_parameter("pulse_width", pulse_width)
	
