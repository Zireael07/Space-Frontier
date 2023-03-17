# based on minimap, but doesn't show ships, just system bodies
extends Control

# class member variables go here, for example:
@onready var star = preload("res://assets/hud/yellow_circle.png")
@onready var planet = preload("res://assets/hud/red_circle.png")
@onready var asteroid = preload("res://assets/hud/grey_circle.png")
@onready var ship = preload("res://assets/hud/arrow.png")

var stars
var planets
var asteroids
var wormholes
var star_main = null # main star of the system

var star_sprites = []
var planet_sprites = []
var asteroid_sprites = []
var wormhole_sprites = []
var ship_sprite = null

var center = Vector2(get_size().x/2, get_size().y/2)
var star_center = center

var zoom_scale = 24 # to see the entire proc system

func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	
	setup()

func setup():
	stars = get_tree().get_nodes_in_group("star")
	
	star_main = stars[0]
	if stars.size() > 1:
		star_main = stars[1]
	
	# set zoom scale
	zoom_scale = star_main.zoom_scale*2 # usually the zoom scale for orrery is twice of the normal minimap
	# unless we have a custom zoom specified
	if star_main.custom_orrery_scale != 0:
		zoom_scale = star_main.custom_orrery_scale
	
	if 'zoom_scale' in get_child(0):
		get_child(0).zoom_scale = zoom_scale
	
	planets = get_tree().get_nodes_in_group("planets")
	# given the scale, it doesn't make sense to show moons
	asteroids = get_tree().get_nodes_in_group("asteroid")
	
	wormholes = get_tree().get_nodes_in_group("wormhole")
	
	# adjust center offset based on central star scale
	var adj = 1
	# paranoia
	if 'star_radius_factor' in stars[0]:
		adj = stars[0].star_radius_factor
	
	var star_name = stars[0].get_node("Label").get_text()
	if star_name.ends_with(" A"):
		star_name = star_name.trim_suffix(" A")
	#print("Star name: ", star_name)
	
	for s in stars:
		# so that the icon and label have a common parent
		var con = Control.new()
		add_child(con)
		var star_sprite = TextureRect.new()
		star_sprite.set_texture(star)
		var sc = Vector2(1,1)
		# paranoia
		if 'star_radius_factor' in s:
			sc = Vector2(s.star_radius_factor, s.star_radius_factor)
			# fix scale for very small radius stars
			if s.star_radius_factor < 0.25:
				sc = Vector2(s.star_radius_factor*2, s.star_radius_factor*2)
			# fix for white dwarf
			if s.star_radius_factor < 0.01:
				sc = Vector2(0.25, 0.25)
		star_sprite.set_scale(sc)
		star_sprites.append(con)
		con.add_child(star_sprite)
		
		# label
		var label = Label.new()
		
		var txt = s.get_node("Label").get_text()
		label.set_text(txt) # default
		
		# if the names end in star name + A, B etc., show just the letter to save space
		# the planet listing does show us the full name, after all
		if txt.find(star_name) != -1:
			var ends = ["A", "B"]
			for e in ends:
				if txt.ends_with(e):
					label.set_text(e)
					break
		
		if zoom_scale > 200:
			label.set_position(Vector2(36*adj*0.75, 36*adj*0.5))
		else:
			label.set_position(Vector2(36*adj*0.75,36*adj*0.75))
		con.add_child(label)
	
	# center offset based on central star
	star_center = center - Vector2(16*adj,16*adj)
	
	# main star is the center
	if stars.size() > 1 and star_main == stars[1]:
		star_sprites[1].set_position(star_center)
	else:
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
		if txt.find(star_name) != -1:
			var ends = ["a", "b", "c", "d", "e"]
			for e in ends:
				if txt.ends_with(e):
					label.set_text(e)
					break
		
		planet_sprites.append(con)
		con.add_child(planet_sprite)
		
		if zoom_scale > 200:
			label.set_position(Vector2(36*adj*0.5, 36*adj*0.25))
		else:
			label.set_position(Vector2(36*adj*0.5,36*adj*0.5))
		con.add_child(label)
		
	
	for a in asteroids:
		var asteroid_sprite = TextureRect.new()
		asteroid_sprite.set_texture(asteroid)
		asteroid_sprite.set_scale(Vector2(0.25, 0.25))
		asteroid_sprites.append(asteroid_sprite)
		add_child(asteroid_sprite)
	
	for w in wormholes:
		var wormhole_sprite = TextureRect.new()
		wormhole_sprite.set_texture(planet)
		wormhole_sprite.set_scale(Vector2(0.5, 0.5))
		wormhole_sprite.set_modulate(Color(0.2, 0.2, 0.2)) # gray-ish instead of black for a black hole
		wormhole_sprites.append(wormhole_sprite)
		add_child(wormhole_sprite)
	
	set_clip_contents(true)
	
	# set map view stuff
	if self.get_name() == "map view":
		get_child(0).set_cntr(Vector2(80,80))
		if star_main.custom_orrery_scale != 0:
			zoom_scale = star_main.custom_orrery_scale*1.6
		else:
			zoom_scale = star_main.zoom_scale*2
			
		if star_main.custom_map_scale != 0:
			zoom_scale = star_main.custom_map_scale
			
		get_child(0).zoom_scale = zoom_scale
		
		ship_sprite = TextureRect.new()
		ship_sprite.set_texture(ship)
		#ship_sprite.set_scale()
		add_child(ship_sprite)
		
		# doesn't need to be updated in process() because at scales the map is displayed at, we won't see it move anyway
		update_ship_pos()
		
func update_ship_pos():
	# paranoia
	if not stars[0]:
		return
	if star_main == null:
		return
	
#	if game.player == null:
#		return
		
	var rel_loc = game.player.get_global_position() - star_main.get_global_position()
	var off = 9
	ship_sprite.set_position(Vector2((rel_loc.x/zoom_scale)+center.x-off, (rel_loc.y/zoom_scale)+center.y-off))

func _process(_delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.

	# paranoia
	if star_main == null or !is_instance_valid(star_main):
		return

	for i in range(stars.size()):
		# paranoia
		if stars[i] == null:
			continue
		
		# skip main star
		if stars[i] == star_main:
			continue
			
		# the minimap doesn't rotate
		var rel_loc = stars[i].get_global_position() - star_main.get_global_position()
		#var rel_loc = player.get_global_transform()stars[i].get_global_transform().origin * 
		#star_sprites[i].set_position(Vector2(rel_loc.x/zoom_scale, rel_loc.y/zoom_scale))
		star_sprites[i].set_position(Vector2(rel_loc.x/zoom_scale+center.x, rel_loc.y/zoom_scale+center.y))

		var dist = Vector2(rel_loc.x/zoom_scale, rel_loc.y/zoom_scale).length()
		#print ("Px to star: " + str(dist))


	for i in range(planets.size()):
		# paranoia
		if not planets[i]:
			return
		if not is_instance_valid(planets[i]):
			return
			
		# the minimap doesn't rotate
		var rel_loc = planets[i].get_global_position() - star_main.get_global_position()
		#var rel_loc = stars[0].get_global_transform()planets[i].get_global_transform().origin * 
		var off = 36*planets[i].planet_rad_factor*0.25
		var map_pos = Vector2((rel_loc.x/zoom_scale)+center.x-off, (rel_loc.y/zoom_scale)+center.y-off)
		planet_sprites[i].set_position(map_pos)

	for i in range(asteroids.size()):
		# the minimap doesn't rotate
		var rel_loc = asteroids[i].get_global_position() - star_main.get_global_position()
		asteroid_sprites[i].set_position(Vector2(rel_loc.x/zoom_scale+center.x, rel_loc.y/zoom_scale+center.y))

	for i in range(wormholes.size()):
		# the minimap doesn't rotate
		var rel_loc = wormholes[i].get_global_position() - star_main.get_global_position()
		wormhole_sprites[i].set_position(Vector2(rel_loc.x/zoom_scale+center.x, rel_loc.y/zoom_scale+center.y))


# called when leaving a system
func cleanup():
	print("Orrery cleanup...")
	star_sprites = []
	planet_sprites = []
	asteroid_sprites = []
	wormhole_sprites = []


func _on_ButtonPlus_pressed():
	if zoom_scale > 2:
		zoom_scale = zoom_scale/2
		get_child(0).zoom_scale = zoom_scale
		get_child(0).queue_redraw()


func _on_ButtonMinus_pressed():
	zoom_scale = zoom_scale*2
	get_child(0).zoom_scale = zoom_scale
	get_child(0).queue_redraw()
