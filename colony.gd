extends Area2D

# class member variables go here, for example:

# bullets
export(PackedScene) var bullet
onready var bullet_container = $"bullet_container"
#onready var bullet = preload("res://bullet.tscn")
onready var gun_timer = $"gun_timer"

var targetted = false
signal AI_targeted


func _ready():
	add_to_group("enemy")


	# Called every time the node is added to the scene.
	# Initialization here
	#pass

# using this because we don't need physics
func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.

	pass

func shoot():
	gun_timer.start()
	var b = bullet.instance()
	bullet_container.add_child(b)
	b.start_at(get_rotation(), $"muzzle".get_global_position())


# AI
# atan2(0,-1) returns 180 degrees in 3.0, we want 0
# this counts in radians
func fix_atan(x,y):
	var ret = 0
	var at = atan2(x,y)

	if at > 0:
		ret = at - PI
	else:
		ret= at + PI

	return ret


# draw a red rectangle around the target
func _draw():
	if targetted:
		var rect = Rect2(Vector2(-26, -26),	Vector2(91*0.6, 91*0.6))

		draw_rect(rect, Color(1,0,0), false)

# click to target functionality
func _on_Area2D_input_event(viewport, event, shape_idx):
	# any mouse click
	if event is InputEventMouseButton:
		targetted = true
		emit_signal("AI_targeted")
		# redraw
		update()
