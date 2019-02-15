extends "boid.gd"

# class member variables go here, for example:
var shields = 100
signal shield_changed


# bullets
export(PackedScene) var bullet
onready var bullet_container = $"bullet_container"
#onready var bullet = preload("res://bullet.tscn")
onready var gun_timer = $"gun_timer"

var orbiting = false


var targetted = false
signal AI_targeted

export(int) var kind_id = 0

enum kind { enemy, friendly}

func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	if kind_id == kind.enemy:
		add_to_group("enemy")
	elif kind_id == kind.friendly:
		add_to_group("friendly")
		
#	print("Groups: " + str(get_groups()))
	
	connect("shield_changed", self, "_on_shield_changed")
	
	#pass

func get_colonized_planet():
	var ps = get_tree().get_nodes_in_group("planets")
	for p in ps:
		# is the last child a colony?
		var last = p.get_child(p.get_child_count()-1)
		if last.is_in_group("colony") and not last.is_in_group("enemy_col"):
			return p

# using this because we don't need physics
func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.
	
	#target 
	#planet #1
	if get_tree().get_nodes_in_group("asteroid").size() > 3:
		if kind_id == kind.friendly:
			target = get_colonized_planet().get_global_position()
		else:
			target = get_tree().get_nodes_in_group("asteroid")[2].get_global_position()
	else:
		if kind_id == kind.friendly:
			target = get_colonized_planet().get_global_position()
		else:
			target = get_tree().get_nodes_in_group("planets")[2].get_global_position()
	

	rel_pos = get_global_transform().xform_inv(target)
	#print("Rel pos: " + str(rel_pos) + " abs y: " + str(abs(rel_pos.y)))
	
	
	# steering behavior
	if kind_id == kind.friendly:
		if (target - get_global_position()).length() < 300 and not orbiting:
			##orbit
			print("NPC wants to orbit: " + get_colonized_planet().get_name()) 
			orbit_planet(get_colonized_planet())
		elif not orbiting:
			var steer = get_steering_arrive(target)
			# normal case
			vel += steer
	else:
		var steer = get_steering_arrive(target)	
		# normal case
		vel += steer
	
	
	var a = fix_atan(vel.x,vel.y)
	
	# effects
	if vel.length() > 40:
		$"engine_flare".set_emitting(true)
	else:
		$"engine_flare".set_emitting(false)
	
	if not orbiting:
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

# copied from player
func orbit_planet(planet):
	planet.get_node("orbit_holder").set_rotation(0)

	# nuke any velocity left
	vel = Vector2(0,0)
	acc = Vector2(0,0)
	
	var rel_pos = planet.get_global_transform().xform_inv(get_global_position())
	var dist = planet.get_global_position().distance_to(get_global_position())
	print("AI Dist: " + str(dist))
	print("AI Relative to planet: " + str(rel_pos) + " dist " + str(rel_pos.length()))
				
	planet.emit_signal("planet_orbited", self)
				
	# reparent
	get_parent().get_parent().remove_child(get_parent())
	planet.get_node("orbit_holder").add_child(get_parent())
	print("Reparented")
			
	orbiting = planet.get_node("orbit_holder")
			
	# placement is handled by the planet in the signal
	
	# AI specific
	vel = set_heading(target)

# draw a red rectangle around the target
func _draw():
	if game.player.HUD.target == self:
	#if targetted:
		var rect = Rect2(Vector2(-28, -25),	Vector2(97*0.6, 84*0.6)) 
		
		draw_rect(rect, Color(1,0,0), false)
	else:
		pass

# click to target functionality
func _on_Area2D_input_event(viewport, event, shape_idx):
	# any mouse click
	if event is InputEventMouseButton:
		#if not targetted:
		#targetted = true
		emit_signal("AI_targeted", self)
		#else:
		#	targetted = false
		
		# redraw 
		update()

func _on_shield_changed(shield):
	$"shield_effect".show()
	$"shield_timer".start()

func _on_shield_timer_timeout():
	$"shield_effect".hide()
	#pass # replace with function body
