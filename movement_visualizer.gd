extends Node2D

# GDquest colors
var colors = {
	WHITE = Color(1.0, 1.0, 1.0),
	YELLOW = Color(1.0, .757, .027),
	GREEN = Color(.282, .757, .255),
	BLUE = Color(.098, .463, .824),
	PINK = Color(.914, .118, .388)
}

const WIDTH = 2

const MUL = 1

var parent = null
var source = null

func _ready():
	parent = get_parent()
	#print(parent.get_name())

	source = parent
		
	set_physics_process(true)
	update()


func _draw():
	if source == null:
		print("No source!")
		return
	
	if "desired" in source:
		draw_vector(source.desired, Vector2(), colors['BLUE'])

	draw_vector(source.steer * 5, Vector2(), colors['PINK'])

	draw_vector(source.vel, Vector2(), colors['YELLOW'])

	#draw_vector(parent.forward_vec, Vector2(), colors['WHITE'])


func draw_vector(vector, offset, _color):
	if vector == Vector2():
		return
	draw_line(offset * MUL, vector * MUL, _color, WIDTH)

	var dir = vector.normalized()
	# prevent errors with very short vectors
	if vector.length() > 5:
		draw_triangle_equilateral(vector * MUL, dir, 10, _color)
	draw_circle(offset, 6, _color)


func draw_triangle_equilateral(center=Vector2(), direction=Vector2(), radius=50, _color=colors.WHITE):
	var point_1 = center + direction * radius
	var point_2 = center + direction.rotated(2*PI/3) * radius
	var point_3 = center + direction.rotated(4*PI/3) * radius

	var points = PoolVector2Array([point_1, point_2, point_3])
	draw_polygon(points, PoolColorArray([_color]))


func _physics_process(delta):
	# avoid lines rotating
	set_rotation(-get_parent().get_rotation())
	update()
