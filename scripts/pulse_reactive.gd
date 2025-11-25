extends Node3D

@export var flash_color: Color = Color(1, 0.6, 0.2)
@export var flash_duration: float = 0.15
@export var flash_energy: float = 5.0  # brightness of the flash

var _orig_materials: Array[Material] = []
var _flashing: bool = false

func _ready() -> void:
	var mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")
	if mesh == null:
		return

	var surf_count := mesh.get_surface_override_material_count()
	for i in range(surf_count):
		var mat: Material = mesh.get_surface_override_material(i)
		if mat == null:
			mat = mesh.mesh.surface_get_material(i)
		if mat:
			_orig_materials.append(mat)
			# Ensure emission is enabled for all materials
			if mat is StandardMaterial3D:
				mat.emission_enabled = false
				mat.emission = Color(0, 0, 0)
				mat.emission_energy = 0.0

func flash() -> void:
	if _flashing:
		return
	_flashing = true
	print("I AM FLASHING")
	var mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")
	if mesh:
		for i in range(mesh.get_surface_override_material_count()):
			var mat: Material = mesh.get_surface_override_material(i)
			if mat == null:
				var base_mat: Material = mesh.mesh.surface_get_material(i)
				if base_mat:
					mat = base_mat.duplicate()
					mesh.set_surface_override_material(i, mat)
			if mat and mat is StandardMaterial3D:
				mat.emission_enabled = true
				mat.emission = flash_color
				mat.emission_energy = flash_energy

	await get_tree().create_timer(flash_duration).timeout

	# restore original emission
	if mesh:
		for i in range(mesh.get_surface_override_material_count()):
			var mat: Material = mesh.get_surface_override_material(i)
			if mat and mat is StandardMaterial3D:
				mat.emission_enabled = false
				mat.emission = Color(0, 0, 0)
				mat.emission_energy = 0.0

	_flashing = false
