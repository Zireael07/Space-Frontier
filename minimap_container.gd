extends Control

# class member variables go here, for example:
onready var star = preload("res://assets/hud/yellow_circle.png")
onready var planet = preload("res://assets/hud/red_circle.png")
onready var asteroid = preload("res://assets/hud/grey_circle.png")

onready var arrow_star = preload("res://assets/hud/yellow_dir_arrow.png")

var stars
var planets
var asteroids

var star_sprites = []
var planet_sprites = []
var asteroid_sprites = []

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
	
	for s in stars:
		var star_sprite = TextureRect.new()
		star_sprite.set_texture(star)
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
		planet_sprites.append(planet_sprite)
		add_child(planet_sprite)
	
	for a in asteroids:
		var asteroid_sprite = TextureRect.new()
		asteroid_sprite.set_texture(asteroid)
		asteroid_sprite.set_scale(Vector2(0.5, 0.5))
		asteroid_sprites.append(asteroid_sprite)
		add_child(asteroid_sprite)
	
	
	
	# make sure player is the last child (to be drawn last)
	move_child($"player", stars.size()+planets.size()+asteroids.size()+2)
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
		

#	pass
