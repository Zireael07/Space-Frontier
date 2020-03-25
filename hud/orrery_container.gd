# based on minimap, but doesn't show ships, just system bodies
extends Control

# class member variables go here, for example:
onready var star = preload("res://assets/hud/yellow_circle.png")
onready var planet = preload("res://assets/hud/red_circle.png")
onready var asteroid = preload("res://assets/hud/grey_circle.png")

var stars
var planets
var asteroids

var star_sprites = []
var planet_sprites = []
var asteroid_sprites = []

var center = Vector2(get_size().x/2, get_size().y/2)
var star_center = center

var zoom_scale = 24 # to see the entire proc system

func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	
	stars = get_tree().get_nodes_in_group("star")
	
	# set zoom scale
	zoom_scale = stars[0].zoom_scale*2 # usually the zoom scale for orrery is twice of the normal minimap
	# unless we have a custom zoom specified
	if stars[0].custom_orrery_scale != 0:
		zoom_scale = stars[0].custom_orrery_scale
	
	planets = get_tree().get_nodes_in_group("planets")
	asteroids = get_tree().get_nodes_in_group("asteroid")
	
	
	for s in stars:
		var star_sprite = TextureRect.new()
		star_sprite.set_texture(star)
		star_sprite.set_scale(Vector2(s.star_radius_factor, s.star_radius_factor))
		star_sprites.append(star_sprite)
		add_child(star_sprite)
	
	# adjust center offset based on star scale
	star_center = center - Vector2(16*stars[0].star_radius_factor,16*stars[0].star_radius_factor)
	
	# star 1 is the center
	star_sprites[0].set_position(star_center)
		
	for p in planets:
		# so that the icon and label have a common parent
		var con = Control.new()
		add_child(con)
		
		var planet_sprite = TextureRect.new()
		planet_sprite.set_texture(planet)
		if p.planet_rad_factor < 0.5:
			planet_sprite.set_scale(Vector2(p.planet_rad_factor, p.planet_rad_factor))
		else:
			planet_sprite.set_scale(Vector2(p.planet_rad_factor*0.5, p.planet_rad_factor*0.5))
		
		# label
		var label = Label.new()
		
		var txt = p.get_node("Label").get_text()
		label.set_text(txt) # default
		
		# if the names end in star name + a,b,c, etc., show just the letter to save space
		var star_name = stars[0].get_node("Label").get_text()
		if txt.find(star_name) != -1:
			var ends = ["a", "b", "c", "d", "e"]
			for e in ends:
				if txt.ends_with(e):
					label.set_text(e)
					break
		
		planet_sprites.append(con)
		con.add_child(planet_sprite)
		
		label.set_position(Vector2(36*stars[0].star_radius_factor*0.5,36*stars[0].star_radius_factor*0.5))
		con.add_child(label)
		
	
	for a in asteroids:
		var asteroid_sprite = TextureRect.new()
		asteroid_sprite.set_texture(asteroid)
		asteroid_sprite.set_scale(Vector2(0.25, 0.25))
		asteroid_sprites.append(asteroid_sprite)
		add_child(asteroid_sprite)
	
	
	set_clip_contents(true)

func _process(_delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.

#	for i in range(stars.size()):
#		# the minimap doesn't rotate
#		var rel_loc = stars[i].get_global_position() - player.get_child(0).get_global_position()
#		#var rel_loc = player.get_global_transform().xform_inv(stars[i].get_global_transform().origin)
#		#star_sprites[i].set_position(Vector2(rel_loc.x/zoom_scale, rel_loc.y/zoom_scale))
#		star_sprites[i].set_position(Vector2(rel_loc.x/zoom_scale+center.x, rel_loc.y/zoom_scale+center.y))
#
#		var dist = Vector2(rel_loc.x, rel_loc.y).length()
#		#print ("Px to star: " + str(dist))
#

	for i in range(planets.size()):
		# the minimap doesn't rotate
		var rel_loc = planets[i].get_global_position() - stars[0].get_global_position()
		#var rel_loc = stars[0].get_global_transform().xform_inv(planets[i].get_global_transform().origin)
		var off = 36*planets[i].planet_rad_factor*0.25
		var map_pos = Vector2((rel_loc.x/zoom_scale)+center.x-off, (rel_loc.y/zoom_scale)+center.y-off)
		planet_sprites[i].set_position(map_pos)

	for i in range(asteroids.size()):
		# the minimap doesn't rotate
		var rel_loc = asteroids[i].get_global_position() - stars[0].get_global_position()
		asteroid_sprites[i].set_position(Vector2(rel_loc.x/zoom_scale+center.x, rel_loc.y/zoom_scale+center.y))
