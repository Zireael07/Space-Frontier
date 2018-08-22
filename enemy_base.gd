extends "boid.gd"

# class member variables go here, for example:

# bullets
export(PackedScene) var bullet
onready var bullet_container = $"bullet_container"
#onready var bullet = preload("res://bullet.tscn")
onready var gun_timer = $"gun_timer"
onready var explosion = preload("res://explosion.tscn")

var targetted = false
signal AI_targeted

var shoot_target = null
var shoot_rel_pos = Vector2()

func _ready():
	add_to_group("enemy")
	
	#target
	# it's static so we don't need to do it in process()
	target = get_parent().get_position() + Vector2(200, -200)
	shoot_target = get_tree().get_nodes_in_group("player")[0].get_child(0)
	
	# Called every time the node is added to the scene.
	# Initialization here
	#pass

# using this because we don't need physics
func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.

	
	#print("Target: " + str(target))
	if shoot_target != null:
		shoot_rel_pos = get_global_transform().xform_inv(shoot_target.get_global_position())
	
		if shoot_rel_pos.length() < 500:
			if gun_timer.get_time_left() == 0:
				shoot()
	
	
	
	#print(shoot_rel_pos)

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
	
	# redraw
	update()

func shoot():
	gun_timer.start()
	var b = bullet.instance()
	bullet_container.add_child(b)
	var heading = fix_atan(shoot_rel_pos.x, shoot_rel_pos.y)
	b.start_at(get_rotation() - heading, $"muzzle".get_global_position())

# draw a red rectangle around the target
func _draw():
	if targetted:
		var rect = Rect2(Vector2(-45, -45),	Vector2(91, 91))

		draw_rect(rect, Color(1,0,0), false)
	else:
		pass
		
	draw_line(Vector2(0,0), shoot_rel_pos, Color(1,0,0))

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
