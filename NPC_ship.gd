extends "boid.gd"

# class member variables go here, for example:
var shields = 100
signal shield_changed


# bullets
export(PackedScene) var bullet
onready var bullet_container = $"bullet_container"
#onready var bullet = preload("res://bullet.tscn")
onready var gun_timer = $"gun_timer"

var targetted = false
signal AI_targeted

export(int) var kind_id = 0

enum kind { enemy, friendly}

func _ready():
	if kind_id == kind.enemy:
		add_to_group("enemy")
	elif kind_id == kind.friendly:
		add_to_group("friendly")
		
	print("Groups: " + str(get_groups()))
	# Called every time the node is added to the scene.
	# Initialization here
	
	connect("shield_changed", self, "_on_shield_changed")
	
	#pass

# using this because we don't need physics
func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.
	
	#target 
	#planet #1
	if get_tree().get_nodes_in_group("asteroid").size() > 3:
		target = get_tree().get_nodes_in_group("asteroid")[2].get_global_position()
	else:
		target = get_tree().get_nodes_in_group("planets")[2].get_global_position()
	

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
