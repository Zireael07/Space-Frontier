extends "ships/boid.gd"

# class member variables go here, for example:

# bullets
@export var bullet: PackedScene
@onready var bullet_container = $"bullet_container"
#onready var bullet = preload("res://bullet.tscn")
@onready var gun_timer = $"gun_timer"

var targetted = false
var tractor = false
signal colony_targeted

var population = 0.5 # in milions
signal colony_colonized
var to_reward = null # which ship gets rewarded for the colonization?

var shoot_rel_pos = Vector2()
var armor = 100
signal armor_changed

signal distress_called

var labl_loc = Vector2()

func _ready():
	var _conn = null
	get_parent().add_to_group("colony")
	_conn = connect("colony_colonized",Callable(self,"_on_colony_colonized"))
	_conn = connect("distress_called",Callable(self,"_on_distress_called"))
	
	labl_loc = $"Label".get_position()

# using this because we don't need physics
func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.

	# straighten out labels
	#	if not Engine.is_editor_hint():
	$"Label".set_rotation(-get_parent().get_parent().get_rotation())
			
	# get the label to stay in one place from player POV
	var angle = -get_parent().get_parent().get_rotation() + deg_to_rad(45) # because the label is located at 45 deg angle...
	# effectively inverse of atan2()
	var angle_loc = Vector2(cos(angle), sin(angle))
	#Controls don't have transforms so we have to manually set position
	$"Label"._set_position(angle_loc*labl_loc.length())

	# redraw 
	queue_redraw()
	
	# shoot targets
	if not tractor and not get_parent().get_parent().is_in_group("friendly"):
		var enemy = get_closest_enemy()
		if enemy:
			shoot_rel_pos = enemy.get_global_position() * get_global_transform()
			var dist = get_global_position().distance_to(enemy.get_global_position())
			#print(str(dist))
			if dist < 350:
				#print("Colony is close to an enemy " + str(enemy.get_parent().get_name()))
				if gun_timer.get_time_left() == 0:
					shoot()
			
					
	
	
	if tractor:
		if not get_parent().get_parent().get_parent().is_in_group("player") and not get_parent().get_parent().is_in_group("friendly"):
			# paranoia
			if not tractor.has_node("dock"):
				print("Tractorer " + tractor.get_name() + " has no dock?!")
				return
			#print("Parent is " + get_parent().get_parent().get_parent().get_name())
			target = tractor.get_node("dock").get_global_position()
		
			rel_pos = target * get_global_transform()
			#print("Rel pos: " + str(rel_pos) + " abs y: " + str(abs(rel_pos.y)))
			
			# steering behavior
			var steer = get_steering_seek(target, 80)
			# normal case
			vel += steer
		
			# movement happens!
			#acc += vel * -friction
			#vel += acc *delta
			pos += vel * delta
			set_position(pos)
			
			# snap once close enough
			var dist = get_global_position().distance_to(tractor.get_node("dock").get_global_position())
			if dist < 20:
				# reparent
				get_parent().get_parent().remove_child(get_parent())
				tractor.add_child(get_parent())
				# set better z so that we don't overlap parent ship
				get_parent().set_z_index(-1)
				
				# all local positions relative to the immediate parent
				get_parent().set_position(tractor.get_node("dock").get_position()+Vector2(0,20))
				set_position(Vector2(0,0))
				#print("Adding colony as tractoring ship's child")
				# switch off tractor
				tractor = null
				get_parent().get_parent().tractor = null

# helper
func is_in_groups(node, groups):
	var ret = false
	for g in groups:
		if node.is_in_group(g):
			ret = true
			break
	
	#print("In groups " + str(ret))
	return ret

func is_on_planet():
	var ret = false
	var groups = ["planets", "moon"]
	if is_in_groups(get_parent().get_parent(), groups):
		ret = true
	return ret
			
func is_floating():
	var ret = false
		#not get_parent().get_parent().is_in_group("friendly") and not get_parent().get_parent().is_in_group("planets") \
	var groups = ["friendly", "planets", "moon"]
	if not tractor and not is_in_groups(get_parent().get_parent(), groups) \
	and not get_parent().get_parent().get_parent().is_in_group("player"):
		ret = true
	#print("Colony is floating: " + str(ret))
	return ret

func get_closest_enemy():
	var nodes = []
	nodes = get_tree().get_nodes_in_group("enemy")
	
	var dists = []
	var targs = []
	
	for t in nodes:
		var dist = t.get_global_position().distance_to(get_global_position())
		dists.append(dist)
		targs.append([dist, t])

	dists.sort()
	#print("Dists sorted: " + str(dists))
	
	for t in targs:
		if t[0] == dists[0]:
			#print("Target is : " + t[1].get_parent().get_name())
			
			return t[1]

func shoot():
	# paranoia
	if not bullet:
		return
 
	gun_timer.start()
	var b = bullet.instantiate()
	# fix z-ordering over planets
	b.set_z_index(game.PLANET_Z+2)
	# scale until smaller gfx is found
	b.set_scale(Vector2(0.5, 1))
	# reduced damage
	b.dmg = 4
	# increase effective colony bullet range
	b.get_node("lifetime").wait_time = 0.3
	bullet_container.add_child(b)
	var heading = fix_atan(shoot_rel_pos.x, shoot_rel_pos.y)
	b.start_at(get_global_rotation() - heading, $"muzzle".get_global_position())


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
	if game.player and game.player.HUD.target == self:
	#if targetted:
		var rect = Rect2(Vector2(-26, -26),	Vector2(91*0.6, 91*0.6))

		draw_rect(rect, Color(1,0,0), false)
	else:
		pass
	
	
	if tractor:
		var tr = get_child(0)
		var rc_h = tr.get_texture().get_height() * tr.get_scale().x
		var rc_w = tr.get_texture().get_height() * tr.get_scale().y
		#var rect = Rect2(Vector2(-rc_w/2, -rc_h/2), Vector2(rc_w, rc_h))
		#draw_rect(rect, Color(1,1,0), false)
		
		# better looking effect
		draw_line(rel_pos, Vector2(-rc_w/2, -rc_h/2), Color(1,1,0))
		draw_line(rel_pos, Vector2(rc_w/2, rc_h/2), Color(1,1,0))
		draw_line(rel_pos, Vector2(rc_w/2, -rc_h/2), Color(1,1,0))
		draw_line(rel_pos, Vector2(-rc_w/2, rc_h/2), Color(1,1,0))
		
	else:
		pass
	
	
# click to target functionality
func _on_Area2D_input_event(_viewport, event, _shape_idx):
	# any mouse click
	if event is InputEventMouseButton and event.pressed:
		#if targetted:
		#targetted = true
		emit_signal("colony_targeted", self)
		#else:
		#	targetted = false
			
		# redraw
		queue_redraw()

func show_shadow():
	get_node("Sprite2D").show()
	# piggyback
	get_child(1).get_node("dome").show()
	
func show_dome():
	# piggyback
	get_child(1).get_node("dome").show()

func _on_distress_called(target):
	#print("Colony distress called: ", target)
	for n in get_tree().get_nodes_in_group("friendly"):
		if not n.is_in_group("starbase") and not n.is_in_group("drone"):
			if n.get_colony_in_dock() != null:
				return
				
			if n.brain.get_state() in [n.brain.STATE_ATTACK, n.brain.STATE_IDLE]:
				return
				
			#if target.cloaked:
			#	return
			
			# warp in on idle and then attack	
			n.brain.target = target.get_global_position()
			n.warp_target = n.brain.target
			n.brain.set_state(n.brain.STATE_IDLE)
			print(n.get_parent().get_name(), " targeting " + str(target.get_parent().get_name()) + " in response to distress call")
			
	# player
	var player = game.player
	player.emit_signal("officer_message", "Colony is under attack! Press G to respond") 
	# press key to respond functionality
	player.distress_caller = self

func _on_colony_colonized(_colony, planet):
	get_node("Label").hide()
	# don't show hub shadow for very small planets
	if planet.planet_rad_factor > 0.2 and not planet.is_in_group("aster_named"):
		show_shadow()
	else:
		show_dome()

