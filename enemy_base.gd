extends "boid.gd"

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
	
	#target
	# it's static so we don't need to do it in process()
	target = get_parent().get_position() + Vector2(200, -200)
	
	
	# Called every time the node is added to the scene.
	# Initialization here
	#pass

# using this because we don't need physics
func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.

	
	#print("Target: " + str(target))

	rel_pos = get_global_transform().xform_inv(target)
	#print("Rel pos: " + str(rel_pos) + " abs y: " + str(abs(rel_pos.y)))

	# steering behavior
	var steer = get_steering_arrive(target)
	# normal case
	vel += steer


	var a = fix_atan(vel.x,vel.y)

#	# effects
#	if vel.length() > 40:
#		$"engine_flare".set_emitting(true)
#	else:
#		$"engine_flare".set_emitting(false)


	# movement happens!
	#acc += vel * -friction
	#vel += acc *delta
	pos += vel * delta
	set_position(pos)

	# starbases are round so don't rotate...
	# rotation
	#set_rotation(-a)

func shoot():
	gun_timer.start()
	var b = bullet.instance()
	bullet_container.add_child(b)
	b.start_at(get_rotation(), $"muzzle".get_global_position())

# draw a red rectangle around the target
func _draw():
	if targetted:
		var rect = Rect2(Vector2(-45, -45),	Vector2(91, 91))

		draw_rect(rect, Color(1,0,0), false)
	else:
		pass

# click to target functionality
func _on_Area2D_input_event(viewport, event, shape_idx):
	# any mouse click
	if event is InputEventMouseButton:
		#if not targetted:
		targetted = true
		emit_signal("AI_targeted")
		#else:
		#	targetted = false
			
		# redraw
		update()