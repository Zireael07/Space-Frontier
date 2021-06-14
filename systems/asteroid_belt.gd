tool
extends Node2D

# Declare member variables here. Examples:
export var radius = 0.2 # AU
export var num = 20
export var angle_inc = 15 # for small distances < 0.2 AU
var ast_chances = []
var types = { S = 0, C = 1, M = 2 }

var asteroid_s = preload("res://asteroid.tscn")


# Called when the node enters the scene tree for the first time.
func _ready():
	# C = 75%, C+S = 92% (i.e. S = 17%), M = 8%
	ast_chances.append([types.C, 75])
	ast_chances.append([types.S, 17])
	ast_chances.append([types.M, 8])
	
	randomize()
	var angle = randf() 
	for i in range(0, num):
		# spawn asteroid
		var ast = asteroid_s.instance()
		# randomize the type
		var ast_type = select_random()
		ast.type = ast_type
		
		add_child(ast)
		
		# place one on the left, one on the right
		if i % 2 == 0:
			place(angle+90, radius, ast)
		else:
			place(angle-90, radius, ast)
		
			# increase angle in degrees
			angle += angle_inc
	
	#pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func place(angle,dist,child):
	#print("Place : a " + str(angle) + " dist: " + str(dist) + " AU")
	var d = dist*game.AU
	var pos = Vector2(0, d).rotated(deg2rad(angle))
	#print("vec: 0, " + str(d) + " rot: " + str(deg2rad(angle)))
	#print("Position is " + str(pos))
	#get_parent().get_global_position() + 
	
	child.set_position(pos)

# ----------------------------------
func get_chance_roll_table(chances, pad=false):
	var num = -1
	var chance_roll = []
	for chance in chances:
		#print(chance)
		var old_num = num + 1
		num += 1 + chance[1]
		# clip top number to 100
		if num > 100:
			num = 100
		chance_roll.append([chance[0], old_num, num])

	if pad:
		# pad out to 100
		print("Last number is " + str(num))
		# print "Last number is " + str(num)
		chance_roll.append(["None", num, 100])

	return chance_roll

# wants a table of chances [[name, low, upper]]
func random_choice_table(table):
	var roll = randi() % 101 # between 0 and 100
	print("Roll: " + str(roll))
	
	for row in table:
		if roll >= row[1] and roll <= row[2]:
			print("Random roll picked: " + str(row[0]))
			return row[0]

# random select from a table
func select_random():
	var chance_roll_table = get_chance_roll_table(ast_chances)
	print(chance_roll_table)
	
	var res = random_choice_table(chance_roll_table)
	print("Res: " + str(res))
	return res
