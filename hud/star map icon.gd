extends Control

# Declare member variables here. Examples:
const LY_TO_PX = 50;
export var x = 0.0
export var y = 0.0
export var depth = 0.0
export var named = ""
export var planets = false
var star_type = ""
var pos = null #Vector3()
var selected = false

# Called when the node enters the scene tree for the first time.
func _ready():
	# set name first so that debugging knows what we're dealing with
	set_name(named)
	var txt = named
	if planets:
		txt += "*"
	
	# special case: break Alpha and Proxima Centauri into two lines
	if txt.find("Centauri") != -1:
		var txts = txt.split(" ")
		txt = txts[0] + '\n' + txts[1]
		
		if txts[0] == "Proxima":
			get_node("Label").rect_position = Vector2(0, -25)
		if txts[0] == "Alpha":
			get_node("Label").rect_position = Vector2(0, 25)
	
	get_node("Label").set_text(txt)
	
	# select icon based on star type
	var star_icons = {
		"red" : preload("res://assets/hud/red_circle.png"),
		"yellow": preload("res://assets/hud/yellow_circle.png"),
		"blue": preload("res://assets/hud/blue_circle.png"),
	}
	
	get_node("PlanetTexture").set_texture(star_icons[star_type])
	
	# positioning the shadow icon
	# in Godot, +Y goes down so we need to minus the Y we get from data
	set_position(Vector2(x*LY_TO_PX, -y*LY_TO_PX))
	
	# positive depth (above the plane) is negative y
	var depth_s = sign(-depth)
	var end = -depth*LY_TO_PX

	# no need to draw planet and line if very small Z
	if abs(depth) < 0.2:
		print(get_name(), " has very small Z")
		get_node("PlanetTexture").rect_position = Vector2(0,0)
		get_node("ShadowTexture").hide()
		get_node("Line2D").hide()
		return

	# star icon positioned according to the depth
	# 18 is the height of the star icon
	get_node("PlanetTexture").rect_position = Vector2(0, end+18*depth_s) 
	
	# clamp depth to two significant decimal places
	var depth_str = "%.2f" % depth
	
	var y_pos = get_node("PlanetTexture").get_position().y
	get_node("Line2D").points[0] = Vector2(18, y_pos+20) #*depth_s)
	
	# Z axis label if needed
	if abs(depth) > 8:
		# above the plane (place next to star icon)
		if depth_s < 0:
			get_node("Label2").rect_position = Vector2(-6.5, y_pos+25)	
		else:
			# place next to shadow icon for below the plane
			get_node("Label2").rect_position = Vector2(0, 25)
		get_node("Label2").set_text("Z: " + depth_str + " ly")
		get_node("Label2").show()
	
	calculate_label_and_sfx()
	
# recalculated after the map moved
func calculate_label_and_sfx(offset=Vector2(0,0)):
	var y_pos = get_node("PlanetTexture").get_position().y
	var depth_s = sign(-depth)
	
	# now check if icon(s) are out of view
	var ab_shadow = get_node("ShadowTexture").get_global_position()
	var ab_planet = get_node("PlanetTexture").get_global_position()

	# name label
	
	# special case 
	if named.find("Centauri") != -1:
		return
	
	# above the plane (place next to star icon)
	if depth_s < 0:
		get_node("Label").rect_position = Vector2(-6.5, y_pos+4)
	# below the plane (place next to "shadow" icon)
	else:
		get_node("Label").rect_position = Vector2(0, 0)

	# shadow in bounds but planet is not (place name & Z-label next to shadow icon)
	if ab_planet.y < 0 or ab_planet.y > 525:
		get_node("Label").rect_position = Vector2(0, 0)
		# Z axis label
		get_node("Label2").rect_position = Vector2(0, 25)
		#get_node("Label2").set_text("Z: " + depth_str + " ly")
		get_node("Label2").show()
	# imverse (shadow not in bounds), place labels next to planet icon
	if ab_shadow.y < 0 or ab_shadow.y > 525:
		get_node("Label").rect_position = Vector2(-6.5, y_pos+4)
		# Z axis label
		get_node("Label2").rect_position = Vector2(-6.5, y_pos+29) # 25+4
		get_node("Label2").show()

	if not_in_bounds(offset):
		get_node("Line2D").set_modulate(Color(1,1,1,0.5)) # make semi-transparent
	else:
		get_node("Line2D").set_modulate(Color(1,1,1,1)) # restore normal opacity

func not_in_bounds(offset):
	# reworked to use Rect2
	# rect2 origin is the top-left corner!!!
	#var rect = Rect2(get_parent().rect_position.x-(805/2), get_parent().rect_position.y-(525/2), 805, 525)
	#var ab_shadow = get_node("ShadowTexture").get_position() + get_position() + get_parent().rect_position
	#var ab_planet = get_node("PlanetTexture").get_position() + get_position() + get_parent().rect_position
	
	# use a global (screen) rect and global positions
	var rect = Rect2(Vector2(0,0), Vector2(805, 525))
	var ab_shadow = get_node("ShadowTexture").get_global_position()
	var ab_planet = get_node("PlanetTexture").get_global_position()
	
	#print("rect: ", rect, "c: ", rect.get_center(), " ", get_node("Label").get_text(), " shadow: ", ab_shadow, " planet: ", ab_planet)
	var planet_out = !rect.has_point(ab_planet)
	var shadow_out = !rect.has_point(ab_shadow)
	
#	# rect_global_position doesn't seem to be working correctly?
#	#print("planet icon: ", get_node("PlanetTexture").rect_global_position.y, " shadow icon: ", get_node("ShadowTexture").rect_global_position.y)
#	var ab_shadow = get_node("ShadowTexture").get_position().y + get_position().y
#	var ab_planet = get_node("PlanetTexture").get_position().y + get_position().y
#	# because the parent control is in the middle of the panel, at 525/2px
#
#	var planet_out = ab_planet < -250 or ab_planet > 250
#	var shadow_out = ab_shadow < -250 or ab_shadow > 250
#	print(get_node("Label").get_text(), " planet icon out of bounds: ", planet_out, " shadow out of bounds ", shadow_out) 
#	#print("not in bounds: ", planet_out and shadow_out)
	return (planet_out and shadow_out)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func on_click():
	# clear any previous tint
	for c in get_parent().get_children():
		# skip wormhole target
		if c.get_node("Label").get_self_modulate() == Color(0,1,1):
			continue
		c.get_node("Label").set_self_modulate(Color(1,1,1))
		if "selected" in c:
			c.selected = false
	print("Clicked on ", get_node("Label").get_text())
	get_node("Label").set_self_modulate(Color(1,0.5, 0)) # orange-red to match starmap icon and Z line color
	get_node("../../Grid/VisControl/Label").set("custom_colors/font_color", Color(1,0.5,0))
	
	selected = true
	get_parent().tg = get_parent().get_tg()
	# line/distance label redrawing
	get_node("../../Grid/VisControl").clicked = true
	var gl_loc = (get_parent().get_tg_loc() - get_parent().get_src_loc())/2
	get_node("../../Grid/VisControl/Label").set_global_position(gl_loc)
	#get_node("../../Grid/VisControl/Label").rect_position = get_parent().rect_position + (get_parent().get_tg_loc() - get_parent().get_src_loc())/2
	var dist = get_node("../../").get_star_distance(get_parent().src, get_parent().tg)
	get_node("../../Grid/VisControl/Label").set_text("%.2f ly" % (dist))
	get_node("../../Grid/VisControl").update()
	
# we don't want actual buttons, hence this
func _on_TextureRect2_gui_input(event):
	if event is InputEventMouseButton:
		if event.is_pressed():
			on_click()

func _on_TextureRect3_gui_input(event):
	if event is InputEventMouseButton:
		if event.is_pressed():
			on_click()
