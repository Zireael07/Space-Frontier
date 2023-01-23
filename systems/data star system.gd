extends Node2D


# Declare member variables here. Examples:
var data

var star = preload("res://bodies/star.tscn")
var star_script = preload("res://systems/star.gd")
var planet = preload("res://bodies/planet_rotating_procedural.tscn")

var holder = null

var yellow = preload("res://assets/bodies/star_yellow04.png")
var red = preload("res://assets/bodies/star_red01.png")
var orange = preload("res://assets/bodies/star_orange04.png")
var white = preload("res://assets/bodies/star_white01.png")

# Called when the node enters the scene tree for the first time.
func _ready():
	
	spawn_from_data(data)
	pass # Replace with function body.

func spawn_from_data(data):
	print("Spawning system for data: ", data)
	
	for i in data.size():
		# the first is always the star
		if i == 0:
			var s = star.instance()
			s.set_name(data[i][0])
			s.get_node("Label").set_text(data[i][0])
			var h = Node2D.new()
			h.set_name("planet_holder")
			s.add_child(h)
			holder = h
			setup_star(s, data[i][2], data[i][3], data[i][1])
			add_child(s)
		else:
		#if i > 0:
			var d = data[i]
			print(d)
			var b = null
			if d[1].strip_edges() == "planet":
				b = planet.instance()
				b.set_name(data[i][0])
				b.get_node("Label").set_text(data[i][0])
				holder.add_child(b)
				# actually load planet radius and mass from data
				var rad = 0
				if d[3] != "?":
					rad = float(d[3])
				var mas = d[4]
				if mas.find("E") != -1:
					mas = mas.strip_edges()
					mas = mas.trim_suffix("E")
					mas = mas.to_float()
				else:
					mas = mas.trim_suffix("J")
					mas = mas.to_float() * 318 # 1 MJ is 318 ME
				b.setup(0, float(d[2])*game.AU, mas, rad, false)
			else:
				b = star.instance()
				b.set_name(data[i][0])
				b.get_node("Label").set_text(data[i][0])
				b.set_script(star_script)
				var dist = float(d[2])*game.AU
				var pos = Vector2(0, dist).rotated(deg2rad(0))
				b.set_position(pos)
				setup_star(b, data[i][4], data[i][5], data[i][3])
				add_child(b)
	

func setup_star(star, lum, star_type, radius):
	star.luminosity = float(lum)
	star.star_radius_factor = float(radius)
	
	if star_type == "":
		star_type = "red"
	
	#print("Star type: *", star_type,"*")
	if star_type == "red":
		star.get_node("Sprite").set_texture(red)
	elif star_type == "yellow":
		star.get_node("Sprite").set_texture(yellow)
	elif star_type == "orange":
		star.get_node("Sprite").set_texture(orange)
	elif star_type == "white":
		star.get_node("Sprite").set_texture(white)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
