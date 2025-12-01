# PulseManager.gd - Now the Centralized Manager
extends Node3D

# Config/Setup variables
@export var quad_node: MeshInstance3D
@export var pulse_scene_limit := 50 # must match shader array length
@export var max_distance := 100.0
@export var pulse_speed := 10.0
@export var pulse_width := 5.0
@export var world_scale := 0.95
@export var pulse_hitbox_scene: PackedScene
# Origin nodes for different pulse types
var _quad: MeshInstance3D
var _player_origin_node: Node3D # For fixed and mic pulses
var _box_origin_node: Node3D # For box pulses

# Mic Input variables (moved from character.gd)
var mic_capture
var loudness_threshold = 0.0001
var mic_wave_cooldown := 0.0

# Pulses array (now handles ALL pulses)
var pulses: Array = []
var local_cooldown := 0.0

# --- Setup Functions ---

func set_quad_node(node: MeshInstance3D) -> void:
	# Called by main.gd to assign the visualization quad
	quad_node = node
	_quad = node
	if not _quad:
		push_error("PulseManager: quad_node set is null!")

func set_player_origin_node(node: Node3D) -> void:
	# Called by main.gd to assign the player node for player-centric pulses
	_player_origin_node = node

func set_box_origin_node(node: Node3D) -> void:
	# Called by main.gd to assign the box node for box pulses
	_box_origin_node = node
	
func _ready():
	_quad = quad_node
	
	# Mic Setup (moved from character.gd)
	var bus_index = AudioServer.get_bus_index("Mic")
	for i in range(AudioServer.get_bus_effect_count(bus_index)):
		var effect = AudioServer.get_bus_effect(bus_index, i)
		if effect is AudioEffectCapture:
			mic_capture = effect
			break
	if mic_capture == null:
		push_warning("PulseManager: AudioEffectCapture not found on 'Mic' bus. Mic pulses disabled.")


# --- Process Loop ---

func _process(delta):
	local_cooldown -= delta
	mic_wave_cooldown -= delta
	
	# Add helpful warning if the player node wasn't set correctly
	if _player_origin_node == null:
		push_warning("PulseManager: Player origin node is NOT set. Fixed/Mic pulses disabled.")
	
	_process_mic_input(delta) # Handle mic pulse
	
	_update_pulses(delta) # Update all pulses
	_upload_pulses_to_shader() # Render all pulses


# --- New Pulse-Handling Logic (Moved from character.gd) ---

func _process_mic_input(_delta):
	if mic_capture and mic_wave_cooldown <= 0.0 and _player_origin_node:
		var buffer = mic_capture.get_buffer(256)
		if buffer.size() == 0:
			return
			
		var loudness := 0.0
		for sample in buffer:
			var mono = (sample.x + sample.y)
			loudness += abs(mono)
		loudness /= buffer.size()
		
		if loudness > loudness_threshold:
			emit_wave_with_params(loudness, _player_origin_node.global_position)
			mic_wave_cooldown = 0.3 # Reduced cooldown for rapid mic pulses (can be adjusted)
			print("MIC PULSE: ", loudness)


# --- Public Emission Functions ---

# Used by main.gd for the player's automatic pulse
func emit_fixed_player_pulse(loudness: float):
	if _player_origin_node:
		emit_wave_with_params(loudness, _player_origin_node.global_position)

# Used by main.gd for the box's automatic pulse
func emit_box_pulse():
	# This warning confirms your path issue in main.gd
	if _box_origin_node == null:
		push_warning("Cannot emit box pulse: Box origin not assigned.")
		return
	# Use standard pulse parameters for the box
	# Using the original pulse speed/width for a basic box pulse
	_enqueue_pulse(_box_origin_node.global_position, 0.0, pulse_speed, pulse_width, Color.DEEP_PINK, 1.0, max_distance, "enemy")
	_spawn_hitbox(_box_origin_node.global_position)
	
# Consolidated function to emit a pulse from any location with custom parameters
func emit_wave_with_params(loudness: float, origin_pos: Vector3):
	if local_cooldown > 0.0:
		return# too soon

	# Calculate pulse parameters based on loudness (same logic as before)
	var intensity : float = clamp(loudness * 2.0, 0.0, 1.0)
	var speed : float = lerp(5.0, 50.0, intensity)
	var width : float = lerp(1.0, 10.0, intensity)
	var distance : float = lerp(30.0, max_distance, intensity)
	var alpha : float = 1.0
	var quiet_threshold := 0.05
	var medium_threshold := 0.1
	# var loud_threshold := 0.1 # Not explicitly used, but can be if needed

	var color : Color = Color(1, 1, 1)
	if loudness < quiet_threshold:
		color = Color(1, 1, 1)# pure white
	elif loudness < medium_threshold:
		color = Color(1.0, 1, 0.2)# bright yellow
	else:
		color = Color(0.9, 0.0, 0.0)# deep blood red

	_enqueue_pulse(origin_pos, 0.0, speed, width, color, alpha, distance, "player")
	_spawn_hitbox(origin_pos)
	
	# Note: I removed the local_cooldown = 1.0 here as mic_wave_cooldown handles mic rate
	# and the fixed pulses are controlled by the main script's cooldown.


# internal: add new pulse or reuse oldest if full (queue behavior)
func _enqueue_pulse(origin: Vector3, radius: float, speed: float, width: float, color: Color, alpha: float, distance: float, type: String):
	if pulses.size() < pulse_scene_limit:
		pulses.append({"origin": origin, "radius": radius, "speed": speed, "width": width, "color": color, "alpha": alpha, "distance": distance, "type": type})
	else:
		# recycle the oldest (FIFO), reset its properties
		pulses[0] = {"origin": origin, "radius": radius, "speed": speed, "width": width, "color": color, "alpha": alpha, "distance": distance, "type": type}
		pulses = pulses.slice(1, pulses.size()) + [pulses[0]]# move it to back

func _spawn_hitbox(origin_pos: Vector3):
	if pulse_hitbox_scene == null:
		return
	var h = pulse_hitbox_scene.instantiate()
	add_child(h)
	h.start(origin_pos, pulse_speed, max_distance, self)

func _update_pulses(delta):
	# update radii and remove finished pulses
	var i := 0
	while i < pulses.size():
		var p = pulses[i]
		p.radius += p.speed * delta
		var t : float = clamp(p.radius / p.distance, 0.0, 1.0)
		p.alpha = 1.0 - t
		pulses[i] = p# IMPORTANT

		if p.alpha <= 0.01:
			pulses.remove_at(i)
		else:
			i += 1
	# ... (Overtake logic remains the same, but simplified for brevity)
	var n := pulses.size()
	var i2 := 0
	while i2 < n:
		var p1 = pulses[i2]

		var j2 := i2 + 1
		while j2 < n:
			var p2 = pulses[j2]

			# p1 overtakes p2
			if p1.type == p2.type:
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
	# --- ADDED ERROR CHECKS ---
	if _quad == null:
		push_error("PulseManager: Quad Mesh is NULL. Cannot render pulses. Check 'main.gd' to ensure 'player.get_pulse_quad()' is returning a valid node.")
		return
	var mat := _quad.get_active_material(0)
	if not mat:
		push_error("PulseManager: Shader Material is missing on Quad Mesh. Cannot render pulses. Ensure your MeshInstance3D has a SpatialMaterial/ShaderMaterial.")
		return
	# --- END ADDED ERROR CHECKS ---

	var count := pulses.size()
	# Build arrays with fixed max length (fill unused with zeros)
	var origins_arr := []
	var radii_arr := []
	# Rest of _upload_pulses_to_shader remains the same, using the single 'pulses' array.
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
			alpha_arr.append(Vector4(a, a, a, a))#or Vector4(0,0,0,a)

		else:
			width_arr.append(0.0)
			alpha_arr.append(0.0)
			color_arr.append(Vector4(1.0, 1.0, 1.0, 1.0))
			
	mat.set_shader_parameter("pulse_widths", width_arr)
	mat.set_shader_parameter("pulse_colors", color_arr)
	mat.set_shader_parameter("pulse_alphas", alpha_arr)
