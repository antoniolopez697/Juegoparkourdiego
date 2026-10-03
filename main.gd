extends Node3D

# [posición, tamaño, color]
const COURSE = [
	[Vector3(0, 0.75, -8), Vector3(4, 1.5, 4), "ff8a2b"],
	[Vector3(0, 1.5, -14), Vector3(3, 1.5, 3), "ffd23f"],
	[Vector3(3, 2.5, -19), Vector3(3, 1, 3), "ff4b4b"],
	[Vector3(7, 3.5, -23), Vector3(3, 1, 3), "a24bff"],
	[Vector3(12, 4.5, -24), Vector3(3, 1, 3), "2f7fff"],
	[Vector3(17, 5.5, -21), Vector3(3, 1, 3), "22d3d3"],
	[Vector3(20, 6.5, -16), Vector3(2.5, 1, 2.5), "ff6fb5"],
	[Vector3(20, 7.5, -10), Vector3(2.5, 1, 2.5), "ff8a2b"],
	[Vector3(15, 8.5, -6), Vector3(2.5, 1, 2.5), "3ac45a"],
	[Vector3(9, 9.5, -4), Vector3(4, 1, 4), "ffc400"],
]

func _ready() -> void:
	_environment()
	_block(Vector3(0, -0.5, 0), Vector3(80, 1, 80), Color("5fb04a"))
	for b in COURSE:
		_block(b[0], b[1], Color(b[2]))

	var player = CharacterBody3D.new()
	player.set_script(load("res://player.gd"))
	player.position = Vector3(0, 2, 0)
	add_child(player)

	var layer := CanvasLayer.new()
	add_child(layer)
	var touch = Control.new()
	touch.set_script(load("res://touch_controls.gd"))
	layer.add_child(touch)
	touch.move_changed.connect(player.set_move)
	touch.look_delta.connect(player.add_look)
	touch.jump_changed.connect(player.set_jump)

func _environment() -> void:
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color("4aa8ff")
	mat.sky_horizon_color = Color("bfe4ff")
	mat.ground_horizon_color = Color("bfe4ff")
	mat.ground_bottom_color = Color("7ec850")
	var sky := Sky.new()
	sky.sky_material = mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)

func _block(pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.4
	mesh.material_override = mat
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	col.shape = bs
	body.add_child(col)
	add_child(body)
