extends "boid.gd"

# class member variables go here, for example:
	
# FSM
onready var state = InitialState.new(self)
var prev_state

const STATE_INITIAL = 0
const STATE_IDLE   = 1
const STATE_ORBIT  = 2
const STATE_ATTACK = 3
const STATE_REFIT = 4
const STATE_MINE = 5 # not in original Stellar Frontier

signal state_changed	

# -------------	
var shields = 100
signal shield_changed


# bullets
export(PackedScene) var bullet
onready var bullet_container = $"bullet_container"
#onready var bullet = preload("res://bullet.tscn")
onready var gun_timer = $"gun_timer"
onready var explosion = preload("res://explosion.tscn")
onready var debris = preload("res://debris_enemy.tscn")

var orbiting = false

var docked = false

# AI specific stuff
onready var task_timer = $"task_timer"
var target_type = null

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

# fsm
func set_state(new_state, param=null):
	# if we need to clean up
	#state.exit()
	prev_state = get_state()
	
	if new_state == STATE_INITIAL:
		state = InitialState.new(self)
	elif new_state == STATE_IDLE:
		state = IdleState.new(self)
	elif new_state == STATE_ORBIT:
		state = OrbitState.new(self)
	elif new_state == STATE_MINE:
		state = MineState.new(self)
	elif new_state == STATE_ATTACK:
		state = AttackState.new(self, param)
	elif new_state == STATE_REFIT:
		state = RefitState.new(self, param)
	
	emit_signal("state_changed", self)
	
#	print(get_name() + " setting state to " + str(new_state))

func get_state():
	if state is InitialState:
		return STATE_INITIAL
	elif state is IdleState:
		return STATE_IDLE
	elif state is OrbitState:
		return STATE_ORBIT
	elif state is MineState:
		return STATE_MINE
	elif state is AttackState:
		return STATE_ATTACK
	elif state is RefitState:
		return STATE_REFIT
		
#--------------------------------		

func get_colonized_planet():
	var ret
	var ps = get_tree().get_nodes_in_group("planets")
	for p in ps:
		# is it colonized?
		var col = p.has_colony()
		if col and col == "colony":
			ret = p

	if ret != null:
		return ret
	else:
		print("No colonized planet found")
		return null

func select_target():
	#target 
	#planet #1
	if get_tree().get_nodes_in_group("asteroid").size() > 3:
		if kind_id == kind.friendly and get_colonized_planet() != null:
			target = get_colonized_planet().get_global_position()
			set_state(STATE_ORBIT)
			#target_type = "COLONY_PLANET"
		else:
			target = get_tree().get_nodes_in_group("asteroid")[2].get_global_position()
			set_state(STATE_IDLE)
	else:
		if kind_id == kind.friendly:
			target = get_colonized_planet().get_global_position()
			set_state(STATE_ORBIT)
		else:
			target = get_tree().get_nodes_in_group("planets")[2].get_global_position()
			set_state(STATE_IDLE)

# using this because we don't need physics
# generic
func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.

	# use states
	state.update(delta)

# --------------------

func move_AI(vel, delta):
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

#------------------------------
# TODO: we really need to refactor this somehow, it accounts for 200+ lines
# copied from player
func orbit_planet(planet):
	# nuke any velocity left
	vel = Vector2(0,0)
	acc = Vector2(0,0)
	
	var rel_pos = planet.get_node("orbit_holder").get_global_transform().xform_inv(get_global_position())
	var dist = planet.get_global_position().distance_to(get_global_position())
#	print("AI Dist: " + str(dist))
#	print("AI Relative to planet: " + str(rel_pos) + " dist " + str(rel_pos.length()))

	planet.emit_signal("planet_orbited", self)
				
	# reparent
	get_parent().get_parent().remove_child(get_parent())
	planet.get_node("orbit_holder").add_child(get_parent())
#	print("Reparented")
			
	orbiting = planet.get_node("orbit_holder")
			
	# placement is handled by the planet in the signal

	
	# AI specific
	vel = set_heading(target)
	
	# task timer allows the AI to deorbit after some time passed
	task_timer.start()

func deorbit():
	var rel_pos = orbiting.get_parent().get_global_transform().xform_inv(get_global_position())
	print("Deorbiting, relative to planet " + str(rel_pos) + " " + str(rel_pos.length()))
	
	# remove from list of planet orbiters
	orbiting.get_parent().remove_orbiter(self)
	
	orbiting = null
			
	print("Deorbiting, " + str(get_global_position()) + str(get_parent().get_global_position()))
			
	# reparent
	var root = get_node("/root/Control")
	var gl = get_global_position()
			
	get_parent().get_parent().remove_child(get_parent())
	root.add_child(get_parent())
			
	get_parent().set_global_position(gl)
	set_position(Vector2(0,0))
	pos = Vector2(0,0)
			
	set_global_rotation(get_global_rotation())

	# AI switch to other target
	if get_tree().get_nodes_in_group("asteroid").size() > 3:
		target = get_tree().get_nodes_in_group("asteroid")[2].get_global_position()
		set_state(STATE_MINE)

func get_closest_enemy():
	var nodes = get_tree().get_nodes_in_group("enemy")
	
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
			
func get_friendly_base():
	var bases = get_tree().get_nodes_in_group("starbase")
	print(str(bases))
	for b in bases:
		print(b.get_name())
		if not b.is_in_group("enemy"):
			print(b.get_name() + " is not enemy")
			return b

func resource_picked():
	# refit

	# get the base
	var base = get_friendly_base()
	if base != null:
		print("Resource picked, refit")
		target = base.get_global_position()
		set_state(STATE_REFIT, base)

		
func move_generic(delta):
	# steering behavior
	var steer = get_steering_arrive(target)	
	# normal case
	vel += steer
	
	move_AI(vel, delta)		

func move_orbit(delta):
	# orbiting temporarily limited to friendlies
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
	
	move_AI(vel, delta)	

func refit_tractor(refit_target):
	# reparent			
	get_parent().get_parent().remove_child(get_parent())
	# refit target needs to be a node because here
	refit_target.add_child(get_parent())
	# set better z so that we don't overlap parent ship
	get_parent().set_z_index(-1)
	
	# nuke any velocity left
	vel = Vector2(0,0)
	acc = Vector2(0,0)
	
	# all local positions relative to the immediate parent
	get_parent().set_position(Vector2(0,50))
	set_position(Vector2(0,0))
	pos = Vector2(0,0)
	
	print("Adding ship as tractoring ship's child")

	docked = true


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


func _on_task_timer_timeout():
	print("Task timer timeout")
	if orbiting:
		# deorbit
		deorbit()

# -----------------------------
# states
class InitialState:
	var ship
	
	func _init(shp):
		ship = shp
		
	func update(delta):
		if not ship.target:
			ship.select_target()
	

		ship.rel_pos = ship.get_global_transform().xform_inv(ship.target)
		#print("Rel pos: " + str(rel_pos) + " abs y: " + str(abs(rel_pos.y)))	
		
		#ship.set_state(STATE_IDLE)
		
		
class IdleState:
	var ship
	
	func _init(shp):
		ship = shp
		
	func update(delta):
		ship.move_generic(delta)
		

class OrbitState:
	var ship
	
	func _init(shp):
		ship = shp
		
	func update(delta):
		ship.move_orbit(delta)

class AttackState:
	var ship
	var target
	
	func _init(shp, tg):
		ship = shp
		target = tg
	
	func update(delta):
		# steering behavior
		var steer = ship.set_heading(ship.target)	
		# normal case
		ship.vel += steer
	
		ship.move_AI(ship.vel, delta)
		
		var enemy = ship.get_closest_enemy()
		if enemy != null and enemy == target:
			ship.shoot()
		else:
			ship.set_state(ship.prev_state)
			
class RefitState:
	var ship
	var base
	
	func _init(shp, sb):
		ship = shp
		base = sb
	
	func update(delta):
		ship.move_generic(delta)
		
		# if close, do tractor effect
		if ship.get_global_position().distance_to(ship.target) < 50 and not ship.docked:
			print("Should be tractoring")
			ship.refit_tractor(base)
			# dummy
			ship.target = ship.get_global_position()

# completely original	
class MineState:
	var ship
	var shot = false
	
	func _init(shp):
		ship = shp
		
	func update(delta):
		ship.move_generic(delta)
		
		var enemy = ship.get_closest_enemy()
		if enemy:
			var dist = ship.get_global_position().distance_to(enemy.get_global_position())
			#print(str(dist))
			if dist < 100:
				print("We are close to an enemy, switching")
				#ship.target = enemy.get_global_position()
				ship.set_state(STATE_ATTACK, enemy)

		
		# if close to target, shoot it
		if ship.get_global_position().distance_to(ship.target) < 10 and not shot:
			print("Close to target")
			ship.shoot()
			
			var ress = ship.get_tree().get_nodes_in_group("resource")
			if ress.size() > 0:
				shot = true
				ship.target = ress[0].get_global_position()
				
				