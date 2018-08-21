extends Area2D

# class member variables go here, for example:
export var rot_speed = 2.6 #radians
export var thrust = 500
export var max_vel = 400
export var friction = 0.65

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
onready var explosion = preload("res://explosion.tscn")

var target = null
var tractor = null

func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	pass

# using this because we don't need physics
func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.

	# shoot
	if Input.is_action_pressed("ui_select"):
		if gun_timer.get_time_left() == 0:
			shoot()

	# tractor
	if tractor:
		var dist = get_global_position().distance_to(tractor.get_child(0).get_global_position())
		
		# too far away, deactivate
		if dist > 100:
			tractor.get_child(0).tractor = null
			tractor = null
			print("Deactivating tractor")
			
		else:
			#print("Tractor active on: " + str(tractor.get_name()) + " " + str(dist))
			tractor.get_child(0).tractor = self

	# rotations
	if Input.is_action_pressed("ui_left"):
		rot -= rot_speed*delta
	if Input.is_action_pressed("ui_right"):
		rot += rot_speed*delta
	# thrust
	if Input.is_action_pressed("ui_up"):
		acc = Vector2(0, -thrust).rotated(rot)
		$"engine_flare".set_emitting(true)
	else:
		acc = Vector2(0,0)
		$"engine_flare".set_emitting(false)
	
	
	# movement happens!
	acc += vel * -friction
	vel += acc *delta
	pos += vel * delta
	set_position(pos)
	# rotation
	set_rotation(rot)

func _input(event):
	if Input.is_action_pressed("tractor"):
		# toggle
		if not tractor:
		#tractor = true
			# TODO: closest colony
			tractor = get_tree().get_nodes_in_group("colony")[0]
		else:
			tractor = null

	if Input.is_action_pressed("undock_tractor"):
		print("Undock pressed")
		
		tractor = null
		
		# we normally have 7 children nodes
		# TODO: is there a way to check if any child is in group and return the first?
		if get_child_count() > 7 and get_child(8).is_in_group("colony"):
			var col = get_child(8)
			print("We have a colony in dock")
			
			# undock
			remove_child(col)
			get_parent().get_parent().add_child(col)
			
			# restore original z
			col.set_z_index(0)
			
			col.set_global_position(get_node("dock").get_global_position() + Vector2(0, 20))
			
			print("Undocked")

func shoot():
	gun_timer.start()
	var b = bullet.instance()
	bullet_container.add_child(b)
	b.start_at(get_rotation(), $"muzzle".get_global_position())

# draw a red rectangle around the target
func _draw():
	if target == self:
		var rect = Rect2(Vector2(-35, -25),	Vector2(112*0.6, 75*0.6)) 
		
		draw_rect(rect, Color(1,0,0), false)

# click to target functionality
func _on_Area2D_input_event(viewport, event, shape_idx):
	# any mouse click
	if event is InputEventMouseButton:
		target = self
		# redraw 
		update()
