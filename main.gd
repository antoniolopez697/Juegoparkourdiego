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
	{"name": "Torre Gigante", "ground": true, "gsize": 260.0, "tower": true,
		"spawn": Vector3(14, 2, 0), "steps": []},
]

var level_index := 0
var level_root: Node3D
var player
var time := 0.0
var best := -1.0
var running := false
var finished := false
var msg_id := 0
var load_id := 0
var is_tower := false
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

	var b_next := _btn(layer, ">", 20)
	b_next.pressed.connect(func(): _load_level(level_index + 1))
	var b_prev := _btn(layer, "<", 120)
	b_prev.pressed.connect(func(): _load_level(level_index + LEVELS.size() - 1))

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
	if is_tower:
		txt += "   Altura: %d m" % int(maxf(player.global_position.y, 0.0))
	hud_label.text = txt

# ---------- Niveles ----------
func _load_level(i: int) -> void:
	level_index = i % LEVELS.size()
	load_id += 1
	if level_root:
		level_root.queue_free()
	level_root = Node3D.new()
	add_child(level_root)
	var lv = LEVELS[level_index]
	if lv["ground"]:
		var g: float = lv.get("gsize", 80.0)
		_block(Vector3(0, -0.5, 0), Vector3(g, 1, g), Color("4caf3a"))
	is_tower = lv.get("tower", false)
	if is_tower:
		_build_tower()
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
	player.teleport(lv.get("spawn", Vector3(0, 2, 0)))
	_say(lv["name"], 2.0)

func _zone(top: Vector3, size: Vector3, kind: String, mat: StandardMaterial3D) -> void:
	var a := Area3D.new()
	a.position = top + Vector3(0, 1.5, 0)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = maxf(size.x, size.z) * 0.5 + 0.2
	cyl.height = 3.0
	cs.shape = cyl
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
	var my := load_id
	await get_tree().create_timer(3.0).timeout
	if my == load_id:
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

func _block(pos: Vector3, size: Vector3, color: Color, rot: float = 0.0) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = rot
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

# ---------- Torre en espiral ----------
func _build_tower() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var radius := 14.0
	var stages := 12
	var per_stage := 24
	var ang := 0.0
	var y := 0.0
	var prev := 4.0
	for st in range(stages):
		var t := float(st) / float(stages - 1)
		var base := lerpf(3.4, 2.0, t)
		for k in range(per_stage):
			var last := st == stages - 1 and k == per_stage - 1
			var kind := ""
			var s := base
			if last:
				kind = "g"
				s = 6.0
			elif k % 12 == 11:
				kind = "c"
				s = 4.0
			var gap := lerpf(2.6, 3.6, t) + rng.randf_range(-0.3, 0.3)
			var chord := (prev + s) * 0.5 + gap
			ang += 2.0 * asin(clampf(chord / (2.0 * radius), 0.0, 1.0))
			y += rng.randf_range(0.4, 0.9)
			var top := Vector3(cos(ang) * radius, y, sin(ang) * radius)
			var col := Color.from_hsv(fmod(st * 0.083 + k * 0.004, 1.0), 0.55, 1.0)
			if kind == "c":
				col = Color("22d3d3")
			elif kind == "g":
				col = Color("ffc400")
			_block(top - Vector3(0, 0.5, 0), Vector3(s, 1.0, s), col, -(ang + PI / 2.0))
			if kind != "":
				var mat := _pole(top, kind == "g")
				_zone(top, Vector3(s, 1.0, s), kind, mat)
			prev = s
	var core := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 9.0
	cm.bottom_radius = 11.0
	cm.height = y + 6.0
	core.mesh = cm
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color("9aa5b8")
	core.material_override = cmat
	core.position = Vector3(0, cm.height / 2.0, 0)
	level_root.add_child(core)

func _btn(layer: CanvasLayer, text: String, from_right: float) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 36)
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.offset_left = -from_right - 90.0
	b.offset_right = -from_right
	b.offset_top = 20.0
	b.offset_bottom = 90.0
	layer.add_child(b)
	return b
