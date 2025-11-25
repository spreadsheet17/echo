extends Node3D

@export var flash_color: Color = Color(1, 0.6, 0.2)
@export var flash_duration: float = 0.15
@export var flash_scale: float = 1.05  # slightly bigger than original to avoid z-fighting

var _glow_mesh: MeshInstance3D = null
var _flashing: bool = false

func _ready():
	var mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")
	if mesh == null:
		push_warning("GlowMesh: No MeshInstance3D found")
		return

	# Create glow mesh instance
	_glow_mesh = MeshInstance3D.new()
	_glow_mesh.mesh = mesh.mesh
	_glow_mesh.scale = Vector3.ONE * flash_scale
	_glow_mesh.visible = false
	add_child(_glow_mesh)

	# Create emissive material
	if _glow_mesh.mesh and _glow_mesh.mesh.get_surface_count() > 0:
		var mat = StandardMaterial3D.new()
		mat.emission_enabled = true
		mat.emission = flash_color
		mat.emission_energy = 5.0
		mat.albedo_color = Color(0,0,0)  # ensure it doesn’t get overwritten by albedo
		for i in range(_glow_mesh.mesh.get_surface_count()):
			_glow_mesh.set_surface_override_material(i, mat)

func flash():
	print("FHASK")
	if _flashing:
		return
	_flashing = true
	if _glow_mesh:
		_glow_mesh.visible = true

	await get_tree().create_timer(flash_duration).timeout

	if _glow_mesh:
		_glow_mesh.visible = false
	_flashing = false
