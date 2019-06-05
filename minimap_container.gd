extends Control

# class member variables go here, for example:
onready var star = preload("res://assets/hud/yellow_circle.png")
onready var planet = preload("res://assets/hud/red_circle.png")
onready var asteroid = preload("res://assets/hud/grey_circle.png")

onready var arrow_star = preload("res://assets/hud/yellow_dir_arrow.png")

onready var friendly = preload("res://assets/hud/arrow.png")
onready var hostile = preload("res://assets/hud/red_arrow.png")

var stars
var planets
var asteroids

var friendlies
var hostiles

var star_sprites = []
var planet_sprites = []
var asteroid_sprites = []

var friendly_sprites = []
var hostile_sprites = []

var star_arrow

#var center = Vector2(get_size().x/2-5, get_size().y/2-5)
var center = Vector2()

var player

var zoom_scale = 12

func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	
	stars = get_tree().get_nodes_in_group("star")
	planets = get_tree().get_nodes_in_group("planets")
	asteroids = get_tree().get_nodes_in_group("asteroid")
	
	player = get_tree().get_nodes_in_group("player")[0]
	friendlies = get_tree().get_nodes_in_group("friendly")
	hostiles = get_tree().get_nodes_in_group("enemy")
	
	
	for s in stars:
		var star_sprite = TextureRect.new()
		star_sprite.set_texture(star)
		star_sprite.set_scale(Vector2(s.star_radius_factor*1.5, s.star_radius_factor*1.5))
		star_sprites.append(star_sprite)
		add_child(star_sprite)
		
		star_arrow = TextureRect.new()
		star_arrow.set_texture(arrow_star)
		add_child(star_arrow)
		# center it
		star_arrow.set_pivot_offset(star_arrow.get_size()/2)
		star_arrow.set_visible(false)
		
	for p in planets:
		var planet_sprite = TextureRect.new()
		planet_sprite.set_texture(planet)
		if p.planet_rad_factor < 0.5:
			planet_sprite.set_scale(Vector2(p.planet_rad_factor*2, p.planet_rad_factor*2))
		else:
			planet_sprite.set_scale(Vector2(p.planet_rad_factor, p.planet_rad_factor))
		planet_sprites.append(planet_sprite)
		add_child(planet_sprite)
	
	for a in asteroids:
		var asteroid_sprite = TextureRect.new()
		asteroid_sprite.set_texture(asteroid)
		asteroid_sprite.set_scale(Vector2(0.5, 0.5))
		asteroid_sprites.append(asteroid_sprite)
		add_child(asteroid_sprite)
	
	
	for f in friendlies:
		var friendly_sprite = TextureRect.new()
		friendly_sprite.set_texture(friendly)
		friendly_sprites.append(friendly_sprite)
		add_child(friendly_sprite)
	
	for h in hostiles:
		var hostile_sprite = TextureRect.new()
		hostile_sprite.set_texture(hostile)
		hostile_sprites.append(hostile_sprite)
		add_child(hostile_sprite)
	
	
	# make sure player is the last child (to be drawn last)
	move_child($"player", stars.size()+planets.size()+asteroids.size()+friendlies.size()+hostiles.size()+2)
	center = Vector2($"player".get_position().x, $"player".get_position().y)
	set_clip_contents(true)
	

func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.

	for i in range(stars.size()):
		# the minimap doesn't rotate
		var rel_loc = stars[i].get_global_position() - player.get_child(0).get_global_position()
		#var rel_loc = player.get_global_transform().xform_inv(stars[i].get_global_transform().origin)
		#star_sprites[i].set_position(Vector2(rel_loc.x/zoom_scale, rel_loc.y/zoom_scale))
		star_sprites[i].set_position(Vector2(rel_loc.x/zoom_scale+center.x, rel_loc.y/zoom_scale+center.y))
		
		var dist = Vector2(rel_loc.x, rel_loc.y).length()
		#print ("Px to star: " + str(dist))
		
		if dist > 1200:
			# indicate distant stars
			#print("Star out of minimap area")
			star_arrow.set_visible(true)
			var pos = Vector2(rel_loc.x, rel_loc.y).clamped(1200-50)
			var a = atan2(rel_loc.x, rel_loc.y)
			
			#print("Pos: " + str(pos) + " for rel_pos" + str(rel_loc))
			star_arrow.set_position(Vector2(pos.x/zoom_scale+center.x, pos.y/zoom_scale+center.y))
			
			# add 180 deg because we want the arrow to point at the star, not away
			star_arrow.set_rotation((-a+3.141593))
			
		else:
			star_arrow.set_visible(false)
		

	for i in range(planets.size()):
		# the minimap doesn't rotate
		var rel_loc = planets[i].get_global_position() - player.get_child(0).get_global_position()
		#var rel_loc = player.get_global_transform().xform_inv(planets[i].get_global_transform().origin)
		#planet_sprites[i].set_position(Vector2(rel_loc.x/zoom_scale, rel_loc.y/zoom_scale))
		planet_sprites[i].set_position(Vector2(rel_loc.x/zoom_scale+center.x, rel_loc.y/zoom_scale+center.y))

	for i in range(asteroids.size()):
		# the minimap doesn't rotate
		var rel_loc = asteroids[i].get_global_position() - player.get_child(0).get_global_position()
		asteroid_sprites[i].set_position(Vector2(rel_loc.x/zoom_scale+center.x, rel_loc.y/zoom_scale+center.y))
		
	# friendlies and hostiles can be removed in-game, so we're not doing it with indices
	for f in friendlies:
		var i = friendlies.find(f)
		# the minimap doesn't rotate
		var rel_loc = f.get_global_position() - player.get_child(0).get_global_position()
		friendly_sprites[i].set_position(Vector2(rel_loc.x/zoom_scale+center.x, rel_loc.y/zoom_scale+center.y))

	for h in hostiles:
		var i = hostiles.find(h)
		if is_instance_valid(h):
			# the minimap doesn't rotate
			var rel_loc = h.get_global_position() - player.get_child(0).get_global_position()
			hostile_sprites[i].set_position(Vector2(rel_loc.x/zoom_scale+center.x, rel_loc.y/zoom_scale+center.y))
		else:
			#print("Removing i: " + str(i))
			# remove all references to the killed ship and its minimap icon
			remove_child(hostile_sprites[i])
			hostiles.remove(i)
			hostile_sprites.remove(i)
			# to prevent errors with subsequent indices not found
			#break