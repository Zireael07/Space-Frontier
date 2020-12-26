extends Node2D

# class member variables go here, for example:
const LIGHT_SPEED = 400 # original Stellar Frontier seems to have used 200 px/s	

export var rot_speed = 2.6 #radians
export var thrust = 500
export var max_vel = 0.5 * LIGHT_SPEED
export var friction = 0.65
export var max_speed = 0.5 * LIGHT_SPEED

# motion
var rot = 0
var pos = Vector2()
var vel = Vector2()
var acc = Vector2()

var target = Vector2()
# debug
var rel_pos = Vector2()
var steer = Vector2(0,0)
var desired = Vector2(0,0)
var draw_tg = Vector2(0,0)

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
func get_steering_seek(tg, cap=(max_vel/4)):
	var steering = Vector2(0,0)
	desired = tg - get_global_position()
	
	# do nothing if very close to target
	#if desired.length() < 50:
	#	return Vector2(0,0)
	
	desired = desired.normalized() * max_speed
	steering = (desired - vel).clamped(cap)
	return steering
	
	
# arrive
func get_steering_arrive(tg):
	var steering = Vector2(0,0)
	desired = tg - get_global_position()
	
	var dist = desired.length()
	desired = desired.normalized()
	if dist < 100:
		var m = range_lerp(dist, 0, 100, 0, max_speed) # 100 is our max speed?
		desired = desired * m
	else:
		desired = desired * max_speed
		
	steering = (desired - vel).clamped(max_vel/4)
	return steering
	

func set_heading(tg):
	var steering = Vector2(0,0)
	desired = tg - get_global_position()
	
	# slow down to almost zero
	desired = desired.normalized() * 0.01

	#return desired
	steering = (desired - vel).clamped(max_vel/4)

	return steering

func get_steering_avoid(tg, max_range=600, cap=(max_vel/4)):
	var steering = Vector2(0,0)
	desired = get_global_position() - tg
	
	var dist = desired.length()
	#desired = Vector2(to_target.x, 0)
#	var sgn = sign(to_target.x)
#
#	desired = Vector2(1*sgn,0) #  # ignore y component
	# rotate by our heading
	#desired.rotated(rotat)
	
	desired = desired.normalized()*2
	
	var m = range_lerp(dist, max_range, 0, 0, max_speed) # 100 is our max speed?
	desired = desired * m
	
	#steering = Vector2(0,0)
	steering = (desired - vel).clamped(cap)
	
	return steering

func get_steering_flee(tg):
	var steering = Vector2(0,0)
	desired = get_global_position() - tg
	
	desired = desired.normalized() * max_speed
	steering = (desired - vel).clamped(max_vel/2)
	return steering
