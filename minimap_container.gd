extends Control

# class member variables go here, for example:
onready var star = preload("res://assets/hud/yellow_circle.png")
onready var planet = preload("res://assets/hud/red_circle.png")
onready var asteroid = preload("res://assets/hud/grey_circle.png")

onready var arrow_star = preload("res://assets/hud/yellow_dir_arrow.png")

onready var friendly = preload("res://assets/hud/arrow.png")
onready var hostile = preload("res://assets/hud/red_arrow.png")

onready var colony_tex = preload("res://assets/hud/blue_button06.png")

onready var starbase = preload("res://assets/hud/blue_boxTick.png")
onready var sb_enemy = preload("res://assets/hud/red_boxTick.png")


var stars
var planets
var asteroids

var friendlies
var hostiles
var starbases
var sb_enemies = []

var colonies = []

var star_sprites = []
var planet_sprites = []
var asteroid_sprites = []

var friendly_sprites = []
var hostile_sprites = []
var starbase_sprites = []
var sb_enemy_sprites = []
var colony_sprites = []

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
	# remove starbases from this list
	for i in range(hostiles.size()-1):
		var h = hostiles[i]
		if h.is_in_group("starbase"):
			hostiles.remove(hostiles.find(h))
	
	
	# more tricky
	starbases = get_tree().get_nodes_in_group("starbase")
	for i in range(starbases.size()-1):
		var sb = starbases[i]
		# move to correct list
		if sb.is_in_group("enemy"):
			#print("Move sb to enemy list")
			starbases.remove(starbases.find(sb))
			sb_enemies.append(sb)
	
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
		# so that the icon and label have a common parent
		var con = Control.new()
		add_child(con)
		
		var planet_sprite = TextureRect.new()
		planet_sprite.set_texture(planet)
		if p.planet_rad_factor < 0.5:
			planet_sprite.set_scale(Vector2(p.planet_rad_factor*2, p.planet_rad_factor*2))
		else:
			planet_sprite.set_scale(Vector2(p.planet_rad_factor, p.planet_rad_factor))
		
		# label
		var label = Label.new()
		label.set_text(p.get_node("Label").get_text())
		label.set_position(Vector2(36*stars[0].star_radius_factor,36*stars[0].star_radius_factor))
		con.add_child(label)
			
		
		planet_sprites.append(con)
		con.add_child(planet_sprite)
	
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
		
	for sb in starbases:
		var starbase_sprite = TextureRect.new()
		starbase_sprite.set_texture(starbase)
		starbase_sprite.set_scale(Vector2(0.5, 0.5))
		starbase_sprites.append(starbase_sprite)
		add_child(starbase_sprite)
	
	for sb in sb_enemies:
		var sb_sprite = TextureRect.new()
		sb_sprite.set_texture(sb_enemy)
		sb_sprite.set_scale(Vector2(0.5, 0.5))
		sb_enemy_sprites.append(sb_sprite)
		add_child(sb_sprite)
	
	# make sure player is the last child (to be drawn last)
	move_child($"player", stars.size()+planets.size()+asteroids.size()+friendlies.size()+hostiles.size()+starbases.size()+2)
	center = Vector2($"player".get_position().x, $"player".get_position().y)
	set_clip_contents(true)

func _on_colony_picked(colony):
	print("On colony picked")
	var col_sprite = TextureRect.new()
	col_sprite.set_texture(colony_tex)
	col_sprite.set_scale(Vector2(0.25, 0.25))
	colony_sprites.append(col_sprite)
	add_child(col_sprite)
	colonies.append(colony)
	

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
	
	for i in range(starbases.size()):
		# the minimap doesn't rotate
		var rel_loc = starbases[i].get_global_position() - player.get_child(0).get_global_position()
		starbase_sprites[i].set_position(Vector2(rel_loc.x/zoom_scale+center.x, rel_loc.y/zoom_scale+center.y))
	
	for sb in sb_enemies:
		var i = sb_enemies.find(sb)
		if is_instance_valid(sb):
			# the minimap doesn't rotate
			var rel_loc = sb_enemies[i].get_global_position() - player.get_child(0).get_global_position()
			sb_enemy_sprites[i].set_position(Vector2(rel_loc.x/zoom_scale+center.x, rel_loc.y/zoom_scale+center.y))			
		else:
			# remove all references to killed starbase
			remove_child(sb_enemy_sprites[i])
			sb_enemies.remove(i)
			sb_enemy_sprites.remove(i)
	
	# draw colonies before ships
	for c in colonies:
		var i = colonies.find(c)
		if is_instance_valid(c):
			# the minimap doesn't rotate
			var rel_loc = c.get_global_position() - player.get_child(0).get_global_position()
			colony_sprites[i].set_position(Vector2(rel_loc.x/zoom_scale+center.x, rel_loc.y/zoom_scale+center.y))
			
		else:
			# remove all references to the killed ship and its minimap icon
			remove_child(colony_sprites[i])
			colonies.remove(i)
			colony_sprites.remove(i)
	
	
	# friendlies and hostiles can be removed in-game, so we're not doing it with indices
	for f in friendlies:
		var i = friendlies.find(f)
		if is_instance_valid(f):
			# the minimap doesn't rotate
			var rel_loc = f.get_global_position() - player.get_child(0).get_global_position()
			friendly_sprites[i].set_position(Vector2(rel_loc.x/zoom_scale+center.x, rel_loc.y/zoom_scale+center.y))
		else:
			# remove all references to the killed ship and its minimap icon
			remove_child(friendly_sprites[i])
			friendlies.remove(i)
			friendly_sprites.remove(i)

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

			