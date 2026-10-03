extends Control

signal move_changed(v: Vector2)
signal look_delta(d: Vector2)
signal jump_changed(pressed: bool)

const STICK_RADIUS := 110.0
const JUMP_RADIUS := 90.0

var stick_index := -1
var look_index := -1
var jump_index := -1
var stick_origin := Vector2.ZERO
var stick_pos := Vector2.ZERO
var jump_center := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void:
	var s := get_viewport_rect().size
	jump_center = Vector2(s.x - 170, s.y - 170)
	queue_redraw()

func _input(event: InputEvent) -> void:
	var half := get_viewport_rect().size.x * 0.45
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if event.pressed:
			if jump_index == -1 and p.distance_to(jump_center) < JUMP_RADIUS * 1.3:
				jump_index = event.index
				jump_changed.emit(true)
			elif stick_index == -1 and p.x < half:
				stick_index = event.index
				stick_origin = p
				stick_pos = p
			elif look_index == -1 and p.x >= half:
				look_index = event.index
		else:
			if event.index == jump_index:
				jump_index = -1
				jump_changed.emit(false)
			elif event.index == stick_index:
				stick_index = -1
				move_changed.emit(Vector2.ZERO)
			elif event.index == look_index:
				look_index = -1
		queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == stick_index:
			var v: Vector2 = event.position - stick_origin
			if v.length() > STICK_RADIUS:
				v = v.normalized() * STICK_RADIUS
			stick_pos = stick_origin + v
			var n := v / STICK_RADIUS
			if n.length() < 0.12:
				n = Vector2.ZERO
			move_changed.emit(n)
		elif event.index == look_index:
			look_delta.emit(event.relative)
		queue_redraw()

func _draw() -> void:
	draw_circle(jump_center, JUMP_RADIUS, Color(1, 1, 1, 0.25))
	draw_string(ThemeDB.fallback_font, jump_center + Vector2(-45, 10), "SALTO", HORIZONTAL_ALIGNMENT_CENTER, 90, 28)
	if stick_index != -1:
		draw_circle(stick_origin, STICK_RADIUS, Color(1, 1, 1, 0.15))
		draw_circle(stick_pos, 45, Color(1, 1, 1, 0.45))
