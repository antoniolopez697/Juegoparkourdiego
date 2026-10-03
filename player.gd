extends CharacterBody3D

const SPEED := 9.0
const ACCEL := 70.0
const FRICTION := 60.0
const AIR_ACCEL := 35.0
const JUMP_VELOCITY := 11.5
const GRAVITY := 30.0
const FALL_MULT := 1.4
const COYOTE_TIME := 0.12
const BUFFER_TIME := 0.12

var move_input := Vector2.ZERO
var jump_held := false
var coyote := 0.0
var buffer := 0.0
var yaw := 0.0
var pitch := -0.35
var spawn := Vector3.ZERO
var kill_y := -15.0
var walk_t := 0.0
var pivot: Node3D
var model: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D

func _ready() -> void:
	spawn = position
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 2.2
	shape.shape = cap
	shape.position.y = 1.1
	add_child(shape)
	_build_model()
	_build_camera()

# ---------- Modelo estilo Roblox ----------
func _part(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.4
	m.material_override = mat
	m.position = pos
	parent.add_child(m)

func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

func _build_model() -> void:
	model = Node3D.new()
	add_child(model)
	var skin := Color("ffd23f")
	_part(model, Vector3(0.9, 0.9, 0.5), Vector3(0, 1.25, 0), Color("2f7fff"))
	_part(model, Vector3(0.6, 0.6, 0.6), Vector3(0, 2.0, 0), skin)
	_part(model, Vector3(0.1, 0.12, 0.05), Vector3(-0.14, 2.05, -0.31), Color("222222"))
	_part(model, Vector3(0.1, 0.12, 0.05), Vector3(0.14, 2.05, -0.31), Color("222222"))
	arm_l = _pivot(model, Vector3(-0.62, 1.65, 0))
	arm_r = _pivot(model, Vector3(0.62, 1.65, 0))
	_part(arm_l, Vector3(0.3, 0.8, 0.3), Vector3(0, -0.4, 0), skin)
	_part(arm_r, Vector3(0.3, 0.8, 0.3), Vector3(0, -0.4, 0), skin)
	leg_l = _pivot(model, Vector3(-0.22, 0.8, 0))
	leg_r = _pivot(model, Vector3(0.22, 0.8, 0))
	_part(leg_l, Vector3(0.4, 0.8, 0.4), Vector3(0, -0.4, 0), Color("3ac45a"))
	_part(leg_r, Vector3(0.4, 0.8, 0.4), Vector3(0, -0.4, 0), Color("3ac45a"))

# ---------- Cámara tercera persona ----------
func _build_camera() -> void:
	pivot = Node3D.new()
	pivot.top_level = true
	add_child(pivot)
	pivot.global_position = global_position + Vector3(0, 1.7, 0)
	var arm := SpringArm3D.new()
	arm.spring_length = 8.0
	arm.margin = 0.3
	arm.add_excluded_object(get_rid())
	pivot.add_child(arm)
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.current = true
	arm.add_child(cam)

func _process(delta: float) -> void:
	pivot.global_position = pivot.global_position.lerp(global_position + Vector3(0, 1.7, 0), 1.0 - exp(-14.0 * delta))
	pivot.rotation = Vector3(pitch, yaw, 0.0)

# ---------- Entrada ----------
func set_move(v: Vector2) -> void:
	move_input = v

func set_jump(pressed: bool) -> void:
	jump_held = pressed
	if pressed:
		buffer = BUFFER_TIME

func add_look(d: Vector2) -> void:
	yaw -= d.x * 0.006
	pitch = clampf(pitch - d.y * 0.006, -1.2, 0.5)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_SPACE and not event.echo:
		set_jump(event.pressed)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		add_look(event.relative)

# ---------- Movimiento ----------
func _physics_process(delta: float) -> void:
	var mv := move_input
	var kb := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if kb != Vector2.ZERO:
		mv = kb.normalized()

	var dir := Vector3(mv.x, 0, mv.y).rotated(Vector3.UP, yaw)
	var hv := Vector3(velocity.x, 0, velocity.z)
	var grounded := is_on_floor()
	if dir != Vector3.ZERO:
		hv = hv.move_toward(dir * SPEED * mv.length(), (ACCEL if grounded else AIR_ACCEL) * delta)
	else:
		hv = hv.move_toward(Vector3.ZERO, (FRICTION if grounded else 8.0) * delta)

	coyote = COYOTE_TIME if grounded else coyote - delta
	buffer -= delta
	var vy := velocity.y
	if not grounded:
		vy -= GRAVITY * (FALL_MULT if vy < 0.0 else 1.0) * delta
	if buffer > 0.0 and coyote > 0.0:
		vy = JUMP_VELOCITY
		buffer = 0.0
		coyote = 0.0
	if vy > 0.0 and not jump_held:
		vy -= GRAVITY * 1.2 * delta

	velocity = Vector3(hv.x, vy, hv.z)
	move_and_slide()

	if hv.length() > 0.5:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-hv.x, -hv.z), 1.0 - exp(-14.0 * delta))
	_animate(hv, delta)

	if global_position.y < maxf(kill_y, spawn.y - 30.0):
		respawn()

func respawn() -> void:
	global_position = spawn
	velocity = Vector3.ZERO
	pivot.global_position = global_position + Vector3(0, 1.7, 0)

func teleport(p: Vector3) -> void:
	spawn = p
	respawn()

func set_checkpoint(p: Vector3) -> void:
	spawn = p

func _animate(hv: Vector3, delta: float) -> void:
	var k := 1.0 - exp(-16.0 * delta)
	var a_l := 0.0
	var a_r := 0.0
	var l_l := 0.0
	var l_r := 0.0
	if is_on_floor():
		var f := hv.length() / SPEED
		walk_t += delta * 11.0 * f
		var swing := sin(walk_t) * 0.9 * f
		a_l = swing
		a_r = -swing
		l_l = -swing
		l_r = swing
	else:
		a_l = 2.6
		a_r = 2.6
		l_l = 0.4
		l_r = -0.4
	arm_l.rotation.x = lerpf(arm_l.rotation.x, a_l, k)
	arm_r.rotation.x = lerpf(arm_r.rotation.x, a_r, k)
	leg_l.rotation.x = lerpf(leg_l.rotation.x, l_l, k)
	leg_r.rotation.x = lerpf(leg_r.rotation.x, l_r, k)
