extends Node3D

const SAVE := "user://records.cfg"

# Cada paso: [dx, dy, dz, ancho, fondo, tipo]
# Es relativo al bloque anterior (cara superior).
# tipo: "" normal, "s" inicio, "c" checkpoint, "g" meta
const LEVELS = [
	{"name": "Nivel 1", "ground": true, "steps": [
		[0, 1, -7, 4, 4, ""], [0, 1, -6, 3, 3, ""], [0, 1, -6, 3, 3, ""],
		[6, 0, 0, 3, 3, "c"], [6, 1, 0, 3, 3, ""], [6, 0, 0, 3, 3, ""],
		[0, 1, 6, 3, 3, ""], [0, 1, 6, 3, 3, ""], [-6, 1, 0, 3, 3, ""],
		[-6, 0, 0, 4, 4, "g"]]},
	{"name": "Nivel 2", "ground": false, "steps": [
		[0, 0, 0, 6, 6, "s"], [0, 0, -7, 3, 3, ""], [4, 0, -4, 3, 3, ""],
		[6, 1, 0, 3, 3, ""], [0, 1, 6, 3, 3, ""], [-6, 0, 0, 2, 2, ""],
		[-5, 1, 0, 2, 2, ""], [0, 0, -6, 4, 4, "c"], [0, 1, -6, 2, 2, ""],
		[5, 0, 0, 2, 2, ""], [5, 1, 0, 2, 2, ""], [5, 0, 0, 2, 2, ""],
		[5, 1, 0, 2, 2, ""], [0, 0, 6, 4, 4, "g"]]},
	{"name": "Nivel 3", "ground": false, "steps": [
		[0, 0, 0, 6, 6, "s"], [0, 1, -6, 3, 3, ""], [6, 1, 0, 3, 3, ""],
		[0, 1, 6, 3, 3, ""], [0, 1, 6, 3, 3, ""], [-6, 0, 0, 3, 3, "c"],
		[-6, 1, 0, 2, 2, ""], [0, 1, -5, 2, 2, ""], [0, 1, -5, 2, 2, ""],
		[0, 0, -5, 2, 2, ""], [5, 1, 0, 2, 2, ""], [5, 0, 0, 2, 2, ""],
		[0, 1, -5, 3, 3, "c"], [5, 1, 0, 2, 2, ""], [5, 1, 0, 2, 2, ""],
		[5, 0, 0, 2, 2, ""], [0, 1, 5, 4, 4, "g"]]},
	{"name": "Nivel 4", "ground": false, "steps": [
		[0, 0, 0, 6, 6, "s"], [7, 0, 0, 2, 2, ""], [5, 1, 0, 2, 2, ""],
		[5, 1, 0, 2, 2, ""], [5, 1, 0, 3, 3, "c"], [0, 1, 6, 2, 2, ""],
		[0, 1, 5, 2, 2, ""], [-5, 0, 0, 2, 2, ""], [-5, 1, 0, 2, 2, ""],
		[-5, 0, 0, 3, 3, "c"], [-5, 1, 0, 2, 2, ""], [-5, 1, 0, 2, 2, ""],
		[0, 0, -5, 2, 2, ""], [0, 1, -5, 2, 2, ""], [0, 0, -5, 2, 2, ""],
		[5, 1, 0, 3, 3, "c"], [5, 0, 0, 2, 2, ""], [5, 1, 0, 2, 2, ""],
		[5, 1, 0, 2, 2, ""], [5, 1, 0, 2, 2, ""], [0, 0, -5, 2, 2, ""],
		[0, 1, -5, 4, 4, "g"]]},
]

var level_index := 0
var level_root: Node3D
var player
var time := 0.0
var best := -1.0
var running := false
var finished := false
var msg_id := 0
var hud_label: Label
var msg_label: Label

func _ready() -> void:
	_environment()
	player = CharacterBody3D.new()
	player.set_script(load("res://player.gd"))
	player.position = Vector3(0, 2, 0)
	add_child(player)

	var layer := CanvasLayer.new()
	add_child(layer)
	hud_label = _label(layer, 32)
	hud_label.position = Vector2(24, 10)
	msg_label = _label(layer, 54)
	msg_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.offset_top = 90.0
	msg_label.offset_bottom = 300.0

	var touch = Control.new()
	touch.set_script(load("res://touch_controls.gd"))
	layer.add_child(touch)
	touch.move_changed.connect(player.set_move)
	touch.look_delta.connect(player.add_look)
	touch.jump_changed.connect(player.set_jump)

	_load_level(0)

func _process(delta: float) -> void:
	if not running and not finished:
		var v: Vector3 = player.velocity
		if Vector2(v.x, v.z).length() > 1.0:
			running = true
	if running:
		time += delta
	var txt := "%s   %s" % [LEVELS[level_index]["name"], _fmt(time)]
	if best >= 0.0:
		txt += "   Récord: " + _fmt(best)
	hud_label.text = txt

# ---------- Niveles ----------
func _load_level(i: int) -> void:
	level_index = i % LEVELS.size()
	if level_root:
		level_root.queue_free()
	level_root = Node3D.new()
	add_child(level_root)
	var lv = LEVELS[level_index]
	if lv["ground"]:
		_block(Vector3(0, -0.5, 0), Vector3(80, 1, 80), Color("4caf3a"))
	var top := Vector3.ZERO
	var n := 0
	for s in lv["steps"]:
		top += Vector3(s[0], s[1], s[2])
		var size := Vector3(s[3], 1.0, s[4])
		var kind: String = s[5]
		var col := Color.from_hsv(fmod(n * 0.11, 1.0), 0.6, 1.0)
		if kind == "s":
			col = Color("4caf3a")
		elif kind == "c":
			col = Color("22d3d3")
		elif kind == "g":
			col = Color("ffc400")
		_block(top - Vector3(0, 0.5, 0), size, col)
		if kind == "c" or kind == "g":
			var mat := _pole(top, kind == "g")
			_zone(top, size, kind, mat)
		n += 1
	time = 0.0
	running = false
	finished = false
	best = _best(level_index)
	player.teleport(Vector3(0, 2, 0))
	_say(lv["name"], 2.0)

func _zone(top: Vector3, size: Vector3, kind: String, mat: StandardMaterial3D) -> void:
	var a := Area3D.new()
	a.position = top + Vector3(0, 1.5, 0)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x, 3.0, size.z)
	cs.shape = bs
	a.add_child(cs)
	level_root.add_child(a)
	a.body_entered.connect(_on_zone.bind(kind, top, mat))

func _on_zone(body: Node3D, kind: String, top: Vector3, mat: StandardMaterial3D) -> void:
	if body != player or finished:
		return
	if kind == "c":
		var p: Vector3 = top + Vector3(0, 0.6, 0)
		if player.spawn.distance_to(p) > 0.1:
			player.set_checkpoint(p)
			mat.albedo_color = Color("3aff6a")
			_say("¡Checkpoint!", 1.2)
	elif kind == "g":
		_finish()

func _finish() -> void:
	finished = true
	running = false
	var txt := "¡Nivel completado!\n" + _fmt(time)
	if best < 0.0 or time < best:
		_save_best(level_index, time)
		best = time
		txt += "\n¡Nuevo récord!"
	if level_index == LEVELS.size() - 1:
		txt = "¡Has completado todos los niveles!\n" + _fmt(time)
	_say(txt, 3.0)
	await get_tree().create_timer(3.0).timeout
	_load_level(level_index + 1)

# ---------- Récords ----------
func _best(i: int) -> float:
	var cf := ConfigFile.new()
	cf.load(SAVE)
	return float(cf.get_value("best", str(i), -1.0))

func _save_best(i: int, t: float) -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE)
	cf.set_value("best", str(i), t)
	cf.save(SAVE)

# ---------- Interfaz ----------
func _label(layer: CanvasLayer, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	layer.add_child(l)
	return l

func _say(text: String, secs: float) -> void:
	msg_id += 1
	var my := msg_id
	msg_label.text = text
	await get_tree().create_timer(secs).timeout
	if my == msg_id:
		msg_label.text = ""

func _fmt(t: float) -> String:
	var m := int(t / 60.0)
	var s := t - m * 60.0
	var pad := "0" if s < 10.0 else ""
	return "%d:%s%.1f" % [m, pad, s]

# ---------- Mundo ----------
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
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)

func _pole(top: Vector3, gold: bool) -> StandardMaterial3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.3, 3.0 if gold else 2.2, 0.3)
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ffc400") if gold else Color("ffee33")
	m.material_override = mat
	m.position = top + Vector3(0, b.size.y / 2.0, 0)
	level_root.add_child(m)
	return mat

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
	level_root.add_child(body)
