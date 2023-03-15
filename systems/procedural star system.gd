@tool
extends "star system.gd"

# class member variables go here, for example:
var star_types = { RED_DWARF = 0, YELLOW = 1}
var star_chances = []
var star_type
@export var forced_type = -1

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
	
	# force if any
	if forced_type != -1:
		star_type = forced_type
	
	# human-readable
	var rev = get_star_type(star_type)
	print(str(rev))
	
	
	# luminosities from https://github.com/irskep/stellardream/blob/master/src/stars.ts
	
	if star_type == star_types.YELLOW:
		$Sprite2D.set_texture(yellow)
		# set luminosity
		luminosity = randf_range(0.58, 1.54)
		
		
	elif star_type == star_types.RED_DWARF:
		$Sprite2D.set_texture(red)
		# red dwarf is smaller
		var star_scale = randf_range(0.25, 0.5) # M0V can go up to 60% Sun's radius but let's ignore them for now
		$Sprite2D.set_scale(Vector2(star_scale, star_scale))
		star_radius_factor = star_scale
		# set luminosity
		luminosity = randf_range(0.000158, 0.086)
	
	print("Stellar luminosity: " + str(luminosity))
	
	# names
	# 4 random letters plus hyphen plus 4 digits make "scientific-sounding names"
	# see: https://web.archive.org/web/20200201191722/http://www.jongware.com/galaxy6.html
	# 'A' is 65 in ASCII
	var chr = 65+randi() % 26  # random character
	var arr = [65 + randi() % 26, 65 + randi() % 26, 65 + randi() % 26, 65 + randi() % 26]
	var star_name = PackedByteArray(arr).get_string_from_ascii()
	star_name = star_name + "-"
	var nm = [randi() % 10, randi() % 10, randi() % 10, randi() % 10]
	# sufficiently big number
	#var num = 1000 + randi() % 1000
	#var star_name = "Kepler " + str(num)
	
	star_name = star_name + str(nm[0]) + str(nm[1]) + str(nm[2]) + str(nm[3])
	
	$"Label".set_text(star_name)
	
	# modern naming, from b onwards (instead of Roman numerals)
	var numerals = {0:"b", 1:"c", 2:"d", 3:"e"}
	
	# test periods
	# https://academic.oup.com/mnras/article/490/4/4575/5613397 section 2.1.2.
	# they calculate periods in days, I prefer AUs
	var periods = draw_power_law_rep(2, 0.04, 1, 4)
	
	# planets
	var planets = get_tree().get_nodes_in_group("planets")
	for i in planets.size():
		var p = planets[i]
		p.get_node("Label").set_text(star_name + str(numerals[i]))
		# random mass
		var m = randf_range(0.5,5) # upper bound of super-Earth is 10 Earth masses, but we don't have art yet
		p.mass = m
		
		var mol = p.molecule_limit()
		print("Smallest molecule planet ", p.get_node("Label").get_text(), " holds: ", mol)
		
		# more stuff
		# if it can hold to at least CO2
		if mol <= 44.0:
			p.atm = randf_range(0.01, 1.5)
			p.greenhouse = randf_range(0.2, 0.7)
			if mol > 18.0:
				p.hydro = randf_range(0.1, 0.45)
				# water freezes
				if p.temp < game.ZEROC_IN_K-1:
					print("Water freezes on ", p.get_node("Label").get_text())
					p.ice = p.hydro
					p.hydro = 0.0

#		if p.is_habitable():
#			p.hydro = randf_range(0.1, 0.45)
#			p.atm = randf_range(0.01, 1.5)
#			p.greenhouse = randf_range(0.2, 0.99)

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


# we split into two functions to achieve the same
func draw_power_law_rep(n:float, mn, mx, r: int):
	var results = []
	for i in r:
		# more random
		randomize()
		results.append(draw_power_law(n, mn, mx))
	
	print("Power law drawn results: ", results)
	return results

# https://github.com/ExoJulia/ExoplanetsSysSim.jl/blob/3150dc64437909be15270aca4101e68c0a7a0dc2/src/planetary_system.jl#L271
# based on code by the authors of https://academic.oup.com/mnras/article/490/4/4575/5613397
# Julia has tricks here to do rng and calculations for several things at once 
# '.' is the Julia vectorized op that does thing for all elements of an array, and passing the size to rand() draws a random value x times
func draw_power_law(n:float, mn, mx):
	if n != -1:
		var ind = (1/(n+1))
		return pow(((pow(mx, n+1) - pow(mn, n+1)) * randf() + pow(mn, n-1)), ind)
		#return ((mx^(n+1) - mn^(n+1)).*rand(r) .+ mn^(n+1)).^(1/(n+1))
	else: #if n == -1
		return pow(mn*(mx/mn), randf())
		#return mn*(mx/mn).^rand(r)

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
