tool
extends "star system.gd"

# class member variables go here, for example:
var star_types = { RED_DWARF = 0, YELLOW = 1}
var star_chances = []
var star_type

func _ready():
	# Called when the node is added to the scene for the first time.
	# Initialization here
	
	var yellow = preload("res://assets/bodies/star_yellow04.png")
	var red = preload("res://assets/bodies/star_red01.png")
	
	star_chances.append([star_types.RED_DWARF, 70])
	star_chances.append([star_types.YELLOW, 30])
	
	# select star type
	star_type = select_random()
#	print("Selected: " + str(selected))
	# human-readable
	var rev = get_star_type(star_type)
	print(str(rev))
	
	
	# luminosities from https://github.com/irskep/stellardream/blob/master/src/stars.ts
	
	if star_type == star_types.YELLOW:
		$Sprite.set_texture(yellow)
		# set luminosity
		luminosity = rand_range(0.58, 1.54)
		
		
	elif star_type == star_types.RED_DWARF:
		$Sprite.set_texture(red)
		# red dwarf is smaller
		var star_scale = rand_range(0.25, 0.5) # M0V can go up to 60% Sun's radius but let's ignore them for now
		$Sprite.set_scale(Vector2(star_scale, star_scale))
		star_radius_factor = star_scale
		# set luminosity
		luminosity = rand_range(0.000158, 0.086)
	
	print("Stellar luminosity: " + str(luminosity))
	
	# names
	# sufficiently big number
	var num = 1000 + randi() % 1000
	var star_name = "Kepler " + str(num)
	
	$"Label".set_text(star_name)
	
	# modern naming, from b onwards (instead of Roman numerals)
	var numerals = {0:"b", 1:"c", 2:"d", 3:"e"}
	
	# planets
	var planets = get_tree().get_nodes_in_group("planets")
	for i in planets.size():
		var p = planets[i]
		p.get_node("Label").set_text(star_name + str(numerals[i]))
		# random mass
		var m = rand_range(0.5,5) # upper bound of super-Earth is 10 Earth masses, but we don't have art yet
		p.mass = m

func get_star_type(sel):
	# swap the dictionary around
	var reverse = {}
	
	for i in range(star_types.keys().size()):
#		print(str(i))
#		print(str(star_type.keys()[i]))
		reverse[i] = star_types.keys()[i]
	
	print(str(reverse))

	if reverse.has(sel):
		return reverse[reverse.keys().find(sel)]


#func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.
#	pass

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
	var chance_roll_table = get_chance_roll_table(star_chances)
	print(chance_roll_table)
	
	var res = random_choice_table(chance_roll_table)
	print("Res: " + str(res))
	return res