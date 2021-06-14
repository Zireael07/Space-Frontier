extends "boid.gd"

# class member variables go here, for example:

# bullets
export(PackedScene) var bullet
onready var bullet_container = $"bullet_container"
#onready var bullet = preload("res://bullet.tscn")
onready var gun_timer = $"gun_timer"
onready var explosion = preload("res://explosion.tscn")

var shields = 150
signal shield_changed
var armor = 100
signal armor_changed

var targetted = false
# for player targeting the AI
signal AI_targeted
# for the AI targeting other ships
signal target_acquired_AI
signal target_lost_AI

# tells us we killed the target, whatever it was
signal target_killed

signal distress_called

var targetables = []
var shoot_target = null
var shoot_rel_pos = Vector2()
var shoot_range = 450

var target_p = Vector2()
var move_out = false # flag
var move_timer

export(int) var kind_id = 0

enum kind { enemy, friendly, pirate }

# see asteroid.gd and debris_resource.gd
enum elements {CARBON, IRON, MAGNESIUM, SILICON, HYDROGEN}
# carbon covers all allotropes of carbon, such as diamonds, graphene, graphite... 

#Methane = CH4, carborundum (silicon carbide) = SiC
# plastics are chains of (C2H4)n
# electronics are made out of Si + Al/Cu; durable variant (for higher temps & pressures) - SiC + Au/Ag/Pl
enum processed { METHANE, CARBORUNDUM, PLASTICS, ELECTRONICS } 
var storage = {}

func _ready():
	set_z_index(game.BASE_Z)
	
	var _conn
	
	_conn = connect("distress_called", self, "_on_distress_called")
	_conn = connect("target_killed", self, "_on_target_killed")
	_conn = connect("AI_targeted", game.player.HUD, "_on_AI_targeted")
	#add_to_group("enemy")
	
	randomize_storage()
	
	move_timer = get_node("move_timer")
	
	#target
	# it's static so we don't need to do it in process()
	target_p = get_parent().get_position() + Vector2(200, -200)
	target = target_p
	
	if is_in_group("enemy"):
		armor *= 2
		shields = 200 
	
	#if is_in_group("enemy"):
	#	targetables.append(get_tree().get_nodes_in_group("player")[0].get_child(0))


func randomize_storage():
	randomize()
	if is_in_group("processor"):
		for e in elements:
			storage[e] = int(rand_range(3.0, 10.0))
	else:
		for e in elements:
			storage[e] = int(rand_range(8.0, 20.0))

# using this because we don't need physics
func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.

	#print("Target: " + str(target))
	# select target
	targetables = get_enemies()
	if kind_id == kind.pirate:
		targetables = []
	
	# one target case (this avoids the sort by distance)
	if targetables.size() > 0 and targetables.size() < 2:
		#print("Get targetables")
		var dist = get_global_transform().xform_inv(targetables[0].get_global_position()).length()
		if shoot_target == null and dist < shoot_range:
			if 'cloaked' in targetables[0] and targetables[0].cloaked:
				return
			shoot_target = targetables[0]
			# signal player being attacked if it's the case
			if targetables[0].get_parent().is_in_group("player"):
				targetables[0].targeted_by.append(self)
				emit_signal("target_acquired_AI", self)
				print("AI acquired target")
	else:
		var closest = get_closest_enemy()
		if closest != null:
			var dist = get_global_transform().xform_inv(closest.get_global_position()).length()
			if shoot_target == null and dist < shoot_range:
				if 'cloaked' in closest and closest.cloaked:
					return
				shoot_target = closest
				# signal player being attacked if it's the case
				if closest.get_parent().is_in_group("player"):
					closest.targeted_by.append(self)
					emit_signal("target_acquired_AI", self)
					print("AI acquired target")
	
	if shoot_target == null or !is_instance_valid(shoot_target):
		return
	else:
		shoot_rel_pos = get_global_transform().xform_inv(shoot_target.get_global_position())
	
		# visual effect
		var color = Color(1,0,0)
		if kind_id == kind.friendly:
			color = Color(0,0,1)
			
		# some starbases don't have material
		if get_child(0).get_material() != null and get_child(0).get_material().get_shader().has_param("flash_color"):
			get_child(0).get_material().set_shader_param("flash_color", color)
	
		if shoot_rel_pos.length() < shoot_range:
			if gun_timer.get_time_left() == 0:
				shoot()
		
			# update target HUD panel if open and we're the target 
			if game.player.HUD.is_ship_view_open() and game.player.HUD.target == self:
				game.player.HUD.starbase_update_status(self)		
		
		else:
			if shoot_target.get_parent().is_in_group("player"):
				shoot_target.targeted_by.remove(shoot_target.targeted_by.find(self))
				if shoot_target.targeted_by.size() < 1:
					emit_signal("target_lost_AI", self)

			shoot_target = null
			print("AI lost target")
			# remove effect
			get_child(0).get_material().set_shader_param("flash_color", Color(1,1,1))
			# update target HUD panel if open and we're the target 
			if game.player.HUD.is_ship_view_open() and game.player.HUD.target == self:
				game.player.HUD.starbase_update_status(self)
	
	
	#print(shoot_rel_pos)

	rel_pos = get_global_transform().xform_inv(target)
	#print("Rel pos: " + str(rel_pos) + " abs y: " + str(abs(rel_pos.y)))

	# steering behavior
	var steer = Vector2(0,0)
	if move_out:
		#print("Rel pos: " + str(rel_pos) + " abs y: " + str(abs(rel_pos.y)))
		steer = get_steering_flee(target)
		#print("Steer", steer)
	else:
		steer = get_steering_arrive(target)
		#print("Arrive: ", steer)
	
	
	# normal case
	vel += steer


	var _a = fix_atan(vel.x,vel.y)

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
	
	# kill any remaining lasers
#	for c in bullet_container.get_children():
#		c.queue_free()
	
	var b = bullet.instance()
	# scale (otherwise the laser preview is difficult to view in editor)
	b.set_scale(Vector2(4, 1))
	bullet_container.add_child(b)
	var heading = fix_atan(shoot_rel_pos.x, shoot_rel_pos.y)
	b.start_at(get_rotation() - heading, $"muzzle".get_global_position())

# draw a red rectangle around the target
func _draw():
	if game.player.HUD.target == self:
	#if targetted:
		var rect = Rect2(Vector2(-45, -45),	Vector2(91, 91))

		draw_rect(rect, Color(1,0,0), false)
	else:
		pass
		
	draw_line(Vector2(0,0), shoot_rel_pos, Color(1,0,0))

# click to target functionality
func _on_Area2D_input_event(_viewport, event, _shape_idx):
	# any mouse click
	if event is InputEventMouseButton and event.pressed:
		#if not targetted:
		#targetted = true
		emit_signal("AI_targeted", self)
		#else:
		#	targetted = false
			
		# redraw
		update()

func _on_distress_called(tgt):
	# if hit by another starbase
	if tgt.is_in_group("starbase"):
		print("Hit by a starbase")
		target = tgt.get_global_position()
		move_timer.start()
		move_out = true
	
	if is_in_group("enemy"):
		for n in get_tree().get_nodes_in_group("enemy"):
			if not n.is_in_group("starbase") and not n.docked:
				#if target.cloaked:
				#	return
					
				n.brain.target = tgt.get_global_position()
				n.brain.set_state(n.brain.STATE_IDLE)
				print("Targeting " + str(tgt.get_parent().get_name()) + " in response to distress call")

func _on_target_killed(_tgt):
	print("Starbase killed target")
	shoot_target = null

func has_free_docks():
	# 7 is the default, and we have two docks so far
	if get_child_count() > 9:
		return false
	else:
		return true
		


# these two functions are repeated from ship_basic.gd
func get_enemies():
	var nodes = []

	if is_in_group("enemy"):
		nodes = get_tree().get_nodes_in_group("friendly")
		
		# more foolproof removing
		var to_rem = []
		for n in nodes:
			if n.is_in_group("drone"):
				to_rem.append(n)
				#nodes.remove(nodes.find(n))
		
		for r in to_rem:
			nodes.remove(nodes.find(r))
		
		var player = get_tree().get_nodes_in_group("player")[0].get_child(0)
		if player and not player.cloaked and not player.dead:
			# add player
			nodes.append(player)
	else:	
		nodes = get_tree().get_nodes_in_group("enemy")
		
	return nodes

func get_closest_enemy():
	var nodes = get_enemies()
	
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


func starbase_listing():
	# update listing
	var list = []
	#print(str(cargo.keys()))
	for i in range(0, storage.keys().size()):
		list.append(str(storage.keys()[i]) + ": " + str(storage[storage.keys()[i]]))
	
	var listing = str(list).lstrip("[").rstrip("]").replace(", ", "\n")
	return listing


#func _on_player_docked():

func add_to_storage(id):
	if not storage.has(id):
		storage[id] = 1
	else:
		storage[id] += 1

func _on_produce_timer_timeout():
	#print("Produce timer timed out!")
	# space wizard needs carbon badly!
	if storage["CARBON"] > 0:
		# prioritize plastics since they need more H
		if storage["HYDROGEN"] > 0:
			if storage["HYDROGEN"] > 10:
				add_to_storage("PLASTICS")
				storage["HYDROGEN"] -= 8
				storage["CARBON"] -= 2
			elif storage["HYDROGEN"] >= 4:
				add_to_storage("METHANE")
				storage["HYDROGEN"] -= 4
				storage["CARBON"] -= 1
			else:
				if storage["SILICON"] > 0:
					add_to_storage("CARBORUNDUM")
					storage["CARBON"] -= 1
					storage["SILICON"] -= 1
		# out of hydrogen, try something else
		else:
			if storage["SILICON"] > 0:
				add_to_storage("CARBORUNDUM")
				storage["CARBON"] -= 1
				storage["SILICON"] -= 1


func _on_move_timer_timeout():
	target = get_global_position() # dummy
	move_out = false # reset
