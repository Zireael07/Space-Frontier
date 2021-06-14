extends Node2D

# class member variables go here, for example:
var elements = { CARBON = 0, IRON = 1, MAGNESIUM = 2, SILICON = 3, HYDROGEN = 4, NICKEL = 5, SILVER = 6, PLATINUM = 7, GOLD = 8 }
var contains = []
var resource_debris = preload("res://debris_resource.tscn")
# C = 75%, C+S = 92% (i.e. S = 17%), M = 8%
var types = { S = 0, C = 1, M = 2 }
export (int) var type = 1 


func _ready():
	# Called when the node is added to the scene for the first time.
	# Initialization here
	set_z_index(game.ASTEROID_Z)
	
	if type == types.C:
		# adapted from carbonacerous meteorite compositions from https://www.permanent.com/meteorite-compositions.html
		contains.append([elements.CARBON, 10]) # boosted to be noticeable to the player
		contains.append([elements.SILICON, 33])
		contains.append([elements.IRON, 25])
		contains.append([elements.MAGNESIUM, 24])
		
		# visual
		get_child(0).set_modulate(Color(0.66, 0.66, 0.66)) # darken it
		
	elif type == types.S:
		# based on S-type asteroids (mostly iron and silicon)
		contains.append([elements.CARBON, 5])
		contains.append([elements.IRON, 67])
		contains.append([elements.SILICON, 22])
		contains.append([elements.HYDROGEN, 3])
	
	elif type == types.M:
		# https://www.universetoday.com/37425/what-are-asteroids-made-of/
		contains.append([elements.IRON, 80])
		# "20% a mixture of nickel, iridium, palladium, platinum, gold, magnesium and other precious metals such as osmium, ruthenium and rhodium"
		contains.append([elements.NICKEL, 8])
		contains.append([elements.SILVER, 2])
		contains.append([elements.PLATINUM, 3])
		contains.append([elements.GOLD, 5])
		contains.append([elements.MAGNESIUM, 2])


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
	#print("Roll: " + str(roll))
	
	for row in table:
		if roll >= row[1] and roll <= row[2]:
			#print("Random roll picked: " + str(row[0]))
			return row[0]

# random select from a table
func select_random():
	var chance_roll_table = get_chance_roll_table(contains)
	#print(chance_roll_table)
	
	var res = random_choice_table(chance_roll_table)
	#print("Res: " + str(res))
	return res

#func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.
#	pass
