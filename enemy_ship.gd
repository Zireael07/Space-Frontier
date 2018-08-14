extends Area2D

# class member variables go here, for example:
export var rot_speed = 2.6 #radians
export var thrust = 500
export var max_vel = 400
export var friction = 0.65
export var max_speed = 100

# motion
var rot = 0
var pos = Vector2()
var vel = Vector2()
var acc = Vector2()

# bullets
export(PackedScene) var bullet
onready var bullet_container = $"bullet_container"
#onready var bullet = preload("res://bullet.tscn")
onready var gun_timer = $"gun_timer"

var target = Vector2()
# debug
var rel_pos = Vector2()
var steer = Vector2(0,0)
var desired = Vector2(0,0)

var targetted = false


func _ready():
	add_to_group("enemy")
	# Called every time the node is added to the scene.
	# Initialization here
	pass

# using this because we don't need physics
func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.
	
	#target 
	#planet #1
	target = get_tree().get_nodes_in_group("planets")[1].get_global_position()
	

	rel_pos = get_global_transform().xform_inv(target)
	#print("Rel pos: " + str(rel_pos) + " abs y: " + str(abs(rel_pos.y)))
	
	# steering behavior
	var steer = get_steering_arrive(target)
	# normal case
	vel += steer
	
	
	var a = fix_atan(vel.x,vel.y)
	
	# effects
	if vel.length() > 40:
		$"engine_flare".set_emitting(true)
	else:
		$"engine_flare".set_emitting(false)
	
	
	# movement happens!
	#acc += vel * -friction
	#vel += acc *delta
	pos += vel * delta
	set_position(pos)
	
	# rotation
	set_rotation(-a)

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
	
# AI - steering behaviors
# seek
func get_steering_seek(target):
	var steering = Vector2(0,0)
	desired = target - get_global_position()
	
	# do nothing if very close to target
	#if desired.length() < 50:
	#	return Vector2(0,0)
	
	desired = desired.normalized() * max_speed
	steering = (desired - vel).clamped(max_vel/4)
	return steering
	
	
# arrive
func get_steering_arrive(target):
	var steering = Vector2(0,0)
	desired = target - get_global_position()
	
	var dist = desired.length()
	desired = desired.normalized()
	if dist < 100:
		var m = range_lerp(dist, 0, 100, 0, max_speed) # 100 is our max speed?
		desired = desired * m
	else:
		desired = desired * max_speed
		
	steering = (desired - vel).clamped(max_vel/4)
	return steering

# draw a red rectangle around the target
func _draw():
	if targetted:
		var rect = Rect2(Vector2(-28, -25),	Vector2(97*0.6, 84*0.6)) 
		
		draw_rect(rect, Color(1,0,0), false)

# click to target functionality
func _on_Area2D_input_event(viewport, event, shape_idx):
	# any mouse click
	if event is InputEventMouseButton:
		targetted = true
		# redraw 
		update()
