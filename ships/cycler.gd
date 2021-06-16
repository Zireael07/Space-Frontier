extends Node2D # cyclers don't move, so no need to extend boid.gd

# basically starbase.gd minus moving and shooting

# class member variables go here, for example:
onready var explosion = preload("res://explosion.tscn")

var shields = 150
signal shield_changed
var armor = 100
signal armor_changed

var targetted = false
# for player targeting the AI
signal AI_targeted
signal distress_called

# see asteroid.gd and debris_resource.gd
enum elements {CARBON, IRON, MAGNESIUM, SILICON, HYDROGEN, NICKEL, SILVER, PLATINUM, GOLD}
# carbon covers all allotropes of carbon, such as diamonds, graphene, graphite... 

#Methane = CH4, carborundum (silicon carbide) = SiC
# plastics are chains of (C2H4)n
# electronics are made out of Si + Al/Cu; durable variant (for higher temps & pressures) - SiC + Au/Ag/Pl
enum processed { METHANE, CARBORUNDUM, PLASTICS, ELECTRONICS, DURABLE_ELECTRONICS } 
var storage = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	set_z_index(game.BASE_Z)
	
	var _conn
	
	_conn = connect("distress_called", self, "_on_distress_called")
	_conn = connect("AI_targeted", game.player.HUD, "_on_AI_targeted")
	#add_to_group("enemy")
	
	randomize_storage()

func randomize_storage():
	randomize()
	for e in elements:
		storage[e] = int(rand_range(3.0, 10.0))

# draw a red rectangle around the target
func _draw():
	if game.player.HUD.target == self:
	#if targetted:
		var rect = Rect2(Vector2(-45, -45),	Vector2(91, 91))

		draw_rect(rect, Color(1,0,0), false)
	else:
		pass

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

func _on_distress_called(target):
	if is_in_group("enemy"):
		for n in get_tree().get_nodes_in_group("enemy"):
			if not n.is_in_group("starbase"):
				#if target.cloaked:
				#	return
					
				n.brain.target = target.get_global_position()
				n.brain.set_state(n.brain.STATE_IDLE)
				print("Targeting " + str(target.get_parent().get_name()) + " in response to distress call")

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
	print("Produce timer timed out!")
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
	else:
		# we're out of carbon, so try making things that don't need C
		if storage["SILICON"] >= 2:
			add_to_storage("ELECTRONICS")
			storage["SILICON"] -= 2
			# copper or aluminium components

		if storage["CARBORUNDUM"] >= 2 and (storage["SILVER"] > 0 or storage["GOLD"] > 0 or storage["PLATINUM"] > 0):
			add_to_storage("DURABLE_ELECTRONICS")
			storage["CARBORUNDUM"] -= 2
			if storage["SILVER"] > 0:
				storage["SILVER"] -= 1
			elif storage["GOLD"] > 0:
				storage["GOLD"] -= 1
			elif storage["PLATINUM"] > 0:
				storage["PLATINUM"] -= 1
