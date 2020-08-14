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
var wormholes

var friendlies
var hostiles
var starbases
var sb_enemies = []

var colony_map = {}
var colonies = []

var star_sprites = []
var planet_sprites = []
var asteroid_sprites = []
var wormhole_sprites = []

var friendly_sprites = []
var hostile_sprites = []
var starbase_sprites = []
var sb_enemy_sprites = []
var colony_sprites = []

# direction arrows
var star_arrow
var wh_arrow

#var center = Vector2(get_size().x/2-5, get_size().y/2-5)
var center = Vector2()

var player

var zoom_scale = 12

var sprite_script = load("res://hud/minimap_sprite.gd")

func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	print("Minimap init")
	
	get_system_bodies()
	
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
	
	colonies = get_tree().get_nodes_in_group("colony")
	
	var to_rem = []
	for i in range(colonies.size()):
		var col = colonies[i]
		print(col.get_name())
		# skip colonies on planets
		if col.get_child(0).is_on_planet():
			to_rem.append(col)
		
	for r in to_rem:	
		colonies.remove(colonies.find(r))
	
	add_system_bodies()
	
	# ships/etc.
	for f in friendlies:
		var friendly_sprite = TextureRect.new()
		friendly_sprite.set_texture(friendly)
		friendly_sprites.append(friendly_sprite)
		var label = Label.new()
		label.set_text(f.get_node("Label").get_text())
		label.set_modulate(Color(0,1,1)) # cyan
		label.set_position(Vector2(10,10))
		add_child(friendly_sprite)
		friendly_sprite.add_child(label)
	
	for h in hostiles:
		var hostile_sprite = TextureRect.new()
		hostile_sprite.set_texture(hostile)
		# enable red outlines
		hostile_sprite.set_script(sprite_script)
		hostile_sprite.type_id = 0
		hostile_sprites.append(hostile_sprite)
		add_child(hostile_sprite)
		
	for sb in starbases:
		var starbase_sprite = TextureRect.new()
		starbase_sprite.set_texture(starbase)
		starbase_sprite.set_scale(Vector2(0.5, 0.5))
		# enable red outlines
		starbase_sprite.set_script(sprite_script)
		starbase_sprite.type_id = 1
		starbase_sprites.append(starbase_sprite)
		add_child(starbase_sprite)
	
	for sb in sb_enemies:
		var sb_sprite = TextureRect.new()
		sb_sprite.set_texture(sb_enemy)
		sb_sprite.set_scale(Vector2(0.5, 0.5))
		# enable red outlines
		sb_sprite.set_script(sprite_script)
		sb_sprite.type_id = 1
		sb_enemy_sprites.append(sb_sprite)
		add_child(sb_sprite)
	
	for c in colonies:
		var col_sprite = TextureRect.new()
		col_sprite.set_texture(colony_tex)
		col_sprite.set_scale(Vector2(0.25, 0.25))
		colony_sprites.append(col_sprite)
		add_child(col_sprite)
		colony_map[c] = col_sprite
	
	move_player_sprite()

# ---------------
# those are necessary for the HUD to update after a system change
func get_system_bodies():
	stars = get_tree().get_nodes_in_group("star")
	
	# set zoom scale
	zoom_scale = stars[0].zoom_scale
	
	
	planets = get_tree().get_nodes_in_group("planets")
	# treat moons as planets
	var moons = get_tree().get_nodes_in_group("moon")
	for m in moons:
		planets.append(m)
	
	asteroids = get_tree().get_nodes_in_group("asteroid")
	
	wormholes = get_tree().get_nodes_in_group("wormhole")

func add_system_bodies():
	for s in stars:
		var star_sprite = TextureRect.new()
		star_sprite.set_texture(star)
		var sc = Vector2(s.star_radius_factor*1.5, s.star_radius_factor*1.5)
		# fix scale for very small radius stars
		if s.star_radius_factor < 0.25:
			sc = Vector2(s.star_radius_factor*3, s.star_radius_factor*3)
		star_sprite.set_scale(sc)
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
		
		# moons
		if p.is_in_group("moon"):
			planet_sprite.set_scale(Vector2(0.5, 0.5))
			
		# center sprite
		# for some reason, get_size() doesn't work yet
		var siz = Vector2(36,36)*planet_sprite.get_scale()
		planet_sprite.set_pivot_offset(siz/2)
		
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
		
		label.set_position(siz)
		con.add_child(label)
			
	
	for a in asteroids:
		var asteroid_sprite = TextureRect.new()
		asteroid_sprite.set_texture(asteroid)
		asteroid_sprite.set_scale(Vector2(0.5, 0.5))
		asteroid_sprites.append(asteroid_sprite)
		add_child(asteroid_sprite)
	
	for w in wormholes:
		var wormhole_sprite = TextureRect.new()
		wormhole_sprite.set_texture(planet)
		wormhole_sprite.set_scale(Vector2(0.5, 0.5))
		wormhole_sprite.set_modulate(Color(0.2, 0.2, 0.2)) # gray-ish instead of black for a black hole
		wormhole_sprites.append(wormhole_sprite)
		add_child(wormhole_sprite)
		
		# add an arrow pointing to wormhole
		wh_arrow = TextureRect.new()
		wh_arrow.set_texture(arrow_star)
		#wh_arrow.set_modulate(Color(0.2, 0.2, 0.2))
		wh_arrow.set_name("wormholearrow")
		add_child(wh_arrow)
		# center it
		wh_arrow.set_pivot_offset(wh_arrow.get_size()/2)
		wh_arrow.set_visible(false)
		
		#print(wh_arrow.get_name())

func move_player_sprite():
	# make sure player is the last child (to be drawn last)
	move_child($"player", get_child_count()-1) #stars.size()+planets.size()+asteroids.size()+friendlies.size()+hostiles.size()+starbases.size()+2)
	center = Vector2($"player".get_position().x, $"player".get_position().y)
	set_clip_contents(true)

# ---------------------------

func _on_friendly_ship_spawned(ship):
	print("On ship spawned")
	var friendly_sprite = TextureRect.new()
	friendly_sprite.set_texture(friendly)
	friendly_sprites.append(friendly_sprite)
	var label = Label.new()
	label.set_text(ship.get_node("Label").get_text())
	label.set_position(Vector2(10,10))
	label.set_modulate(Color(0,1,1)) # cyan
	add_child(friendly_sprite)
	friendly_sprite.add_child(label)
	friendlies.append(ship)
	
func _on_enemy_ship_spawned(ship):
	print("On enemy ship spawned")
	var enemy_sprite = TextureRect.new()
	enemy_sprite.set_texture(hostile)
	# enable red outlines
	enemy_sprite.set_script(sprite_script)
	enemy_sprite.type_id = 0
	hostile_sprites.append(enemy_sprite)
	add_child(enemy_sprite)
	hostiles.append(ship)

func _on_starbase_spawned(sb):
	print("On starbase spawned")
	var starbase_sprite = TextureRect.new()
	starbase_sprite.set_texture(starbase)
	starbase_sprite.set_scale(Vector2(0.5, 0.5))
	starbase_sprites.append(starbase_sprite)
	add_child(starbase_sprite)
	starbases.append(sb)

func _on_enemy_starbase_spawned(sb):
	#print("On enemy starbase spawned")
	var sb_sprite = TextureRect.new()
	sb_sprite.set_texture(sb_enemy)
	sb_sprite.set_scale(Vector2(0.5, 0.5))
	# enable red outlines
	sb_sprite.set_script(sprite_script)
	sb_sprite.type_id = 1
	sb_enemy_sprites.append(sb_sprite)
	add_child(sb_sprite)
	sb_enemies.append(sb)

func _on_wormhole_spawned(wormhole):
	var wormhole_sprite = TextureRect.new()
	wormhole_sprite.set_texture(planet)
	wormhole_sprite.set_scale(Vector2(0.5, 0.5))
	wormhole_sprite.set_modulate(Color(0.2, 0.2, 0.2)) # black would be for real black hole, this is gray-ish
	wormhole_sprites.append(wormhole_sprite)
	add_child(wormhole_sprite)
	wormholes.append(wormhole)

	# add an arrow pointing to wormhole
	wh_arrow = TextureRect.new()
	wh_arrow.set_texture(arrow_star)
	wh_arrow.set_modulate(Color(0.4, 0.4, 0.4))
	wh_arrow.set_name("wormholearrow")
	add_child(wh_arrow)
	# center it
	wh_arrow.set_pivot_offset(wh_arrow.get_size()/2)
	wh_arrow.set_visible(false)
	
	print(wh_arrow.get_name())

# this takes the node that has colony group. i.e. parent of actual colony area
func _on_colony_picked(colony):
	print("On colony picked")
	var col_sprite = TextureRect.new()
	col_sprite.set_texture(colony_tex)
	col_sprite.set_scale(Vector2(0.25, 0.25))
	colony_sprites.append(col_sprite)
	add_child(col_sprite)
	colonies.append(colony)
	colony_map[colony] = col_sprite

func _on_colony_colonized(colony):
	print("Removing colony from minimap...")
	# paranoia
	if colony in colony_map:
		var spr = colony_map[colony]
		remove_child(spr)
		colonies.remove(colonies.find(colony))
		colony_sprites.remove(colony_sprites.find(spr))

# ----------------------------
func clear_outline():
	for h in hostile_sprites:
		h.targeted = false
	for s in sb_enemy_sprites:
		s.targeted = false

func update_outline(target):
	# before doing anything, clear any old ones
	clear_outline()
	
	var i = null
	if target in hostiles:
		i = hostiles.find(target)
		hostile_sprites[i].targeted = true
		hostile_sprites[i].update()
		
	if target in sb_enemies:
		i = sb_enemies.find(target)
		sb_enemy_sprites[i].targeted = true
		sb_enemy_sprites[i].update()

func _process(_delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.

	for i in range(stars.size()):
		# paranoia
		if not stars[i]:
			return
			
		# the minimap doesn't rotate
		var rel_loc = stars[i].get_global_position() - player.get_child(0).get_global_position()
		#var rel_loc = player.get_global_transform().xform_inv(stars[i].get_global_transform().origin)
		#star_sprites[i].set_position(Vector2(rel_loc.x/zoom_scale, rel_loc.y/zoom_scale))
		star_sprites[i].set_position(Vector2(rel_loc.x/zoom_scale+center.x, rel_loc.y/zoom_scale+center.y))
		
		var dist = Vector2(rel_loc.x, rel_loc.y).length()
		#print ("Px to star: " + str(dist))
		
		# if star is so far away that it is outside of the minimap area
		if dist > (100*zoom_scale): # experimentally determined value
			# indicate distant stars
			#print("Star out of minimap area")
			star_arrow.set_visible(true)
			var pos = Vector2(rel_loc.x, rel_loc.y).clamped((100*zoom_scale)-50) # experimentally determined value
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
	
	for i in range(wormholes.size()):
		var rel_loc = wormholes[i].get_global_position() - player.get_child(0).get_global_position()
		wormhole_sprites[i].set_position(Vector2(rel_loc.x/zoom_scale+center.x, rel_loc.y/zoom_scale+center.y))
		
		var dist = Vector2(rel_loc.x, rel_loc.y).length()
		#print ("Px to wh: " + str(dist))

		# if close to a wormhole
		if dist < (100*zoom_scale): # experimentally determined value
			# indicate wormhole
			wh_arrow.set_visible(true)
			var pos = Vector2(rel_loc.x/2, rel_loc.y/2)  #.clamped((100*zoom_scale)-75) # experimentally determined value
			var a = atan2(rel_loc.x, rel_loc.y)
			
			#print("Pos: " + str(pos) + " for rel_pos" + str(rel_loc))
			wh_arrow.set_position(Vector2(pos.x/zoom_scale+center.x, pos.y/zoom_scale+center.y))
			
			# add 180 deg because we want the arrow to point at the wormhole, not away
			wh_arrow.set_rotation((-a+3.141593))
			
		else:
			wh_arrow.set_visible(false)
	
	# ships/etc. (dynamic sprites) start here
	for i in range(starbases.size()):
		# paranoia
		if not starbases[i] or not starbase_sprites[i]:
			return
			
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

# called when leaving a system
func cleanup():
	print("Minimap cleanup...")
	star_sprites = []
	planet_sprites = []
	asteroid_sprites = []
	wormhole_sprites = []
	
	# as a bonus, hide the wormhole arrow
	wh_arrow.hide()
