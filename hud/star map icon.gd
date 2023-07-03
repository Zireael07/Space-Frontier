extends Control

# Declare member variables here. Examples:
const LY_TO_PX = 50;
@export var x = 0.0
@export var y = 0.0
@export var depth = 0.0
@export var named = ""
@export var planets = false
var star_type = ""
var multiple = false
var pos = null #Vector3()

var selected = false

# Called when the node enters the scene tree for the first time.
func _ready():
	if !named.is_empty():
		# set name first so that debugging knows what we're dealing with
		set_name(named)
	var txt = named
	if planets:
		txt += "*"
	
	# layers
	var Z_level_down = preload("res://assets/hud/grey_sliderDown.png")
	var Z_level_up = preload("res://assets/hud/grey_sliderUp.png")
	if get_parent().get_name().find("Z+") != -1:
		get_node("ZTexture").set_texture(Z_level_up)
		get_node("ZTexture").scale = Vector2(0.35, 0.35)
	if get_parent().get_name().find("Z-") != -1:
		get_node("ZTexture").set_texture(Z_level_down)
		get_node("ZTexture").scale = Vector2(0.35, 0.35)
	
	# special case: break Alpha and Proxima Centauri into two lines
	if txt.find("Centauri") != -1:
		var txts = txt.split(" ")
		txt = txts[0] + '\n' + txts[1]
		
		# special case - labels
		if txts[0] == "Proxima":
			get_node("Label").position = Vector2(0, -25)
		if txts[0] == "Alpha":
			get_node("Label").position = Vector2(0, 25)
	
	#print(txt, " len: ", txt.length())
	# if long name that has a space and doesn't have a line break already
	if txt.length() > 13 and txt.find(" ") != -1 and txt.find("\n") == -1:
		var txts = txt.split(" ")
		# don't split things like "AX Microscopii"
		if txts[0].length() > 4:
			txt = txts[0] + '\n' + txts[1]
	# if a long name with a dash separator and doesn't have a line break already
	if txt.length() > 8 and txt.find("--") != -1 and txt.find("\n") == -1:
		var txts = txt.split("--")
		txt = txts[0] + '\n' + "--" + txts[1]
	
	get_node("Label").set_text(txt)
	
	# select icon based on star type
	var star_icons = {
		"red" : preload("res://assets/hud/red_circle.png"),
		"orange": preload("res://assets/hud/red_circle.png"), ##bit of a misnomer, it's more orange than red 
		"yellow": preload("res://assets/hud/yellow_circle.png"),
		"blue": preload("res://assets/hud/blue_circle.png"),
		"white": preload("res://assets/hud/grey_circle.png"),
		"black": preload("res://assets/hud/grey_circle.png"), # theoretical black dwarf star
		"brown": preload("res://assets/hud/grey_circle.png"), # short for brown dwarf, which is something between a planet and a star. star catalogs include them though so.. so do we
		"black hole": preload("res://assets/hud/grey_circle.png"),
	}
	
	if star_type != "":
		get_node("StarTexture").set_texture(star_icons[star_type])
		
		if "black" in star_type:
			get_node("StarTexture").set_self_modulate(Color(0.1,0.1,0.1)) # darken
		
		if star_type == "red":
			get_node("StarTexture").set_self_modulate(Color(1,0.5,0.5)) # darken to actual red
		
		if star_type == "brown":
			get_node("StarTexture").set_self_modulate(Color(0.5, 0.25, 0.2))
	else:
		get_node("StarTexture").set_texture(star_icons["red"])
		get_node("StarTexture").set_self_modulate(Color(1,0.5,0.5)) # darken to actual red
	
	# positioning the shadow icon
	# in Godot, +Y goes down so we need to minus the Y we get from data
	set_position(Vector2(x*LY_TO_PX, -y*LY_TO_PX))
	
	# positive depth (above the plane) is negative y
	var depth_s = sign(-depth)
	var end = -depth*LY_TO_PX

	# no need to draw planet and line if very small Z
	if abs(depth) < 0.2:
		if abs(depth) != 0.0:
			print(get_name(), " has very small Z")
		get_node("Label2").set_text("%.2f" % depth) #+ " ly") # all distances, e.g on ruler, are in ly anyway
		get_node("StarTexture").show()
		get_node("StarTexture").position = Vector2(0,0)
		get_node("ShadowTexture").hide()
		get_node("Line2D").points[0] = Vector2(18,18)
		get_node("Line2D").hide()
		get_node("ZTexture").hide()
		return

	# star icon positioned according to the depth (Z axis)
	# 18 is the height of the star icon
	#get_node("StarTexture").position = Vector2(0, end+18*depth_s) 
	get_node("StarTexture").hide()
	
	# clamp depth to two significant decimal places
	var depth_str = "%.2f" % depth
	
	#var y_pos = get_node("StarTexture").get_position().y
	#get_node("Line2D").points[0] = Vector2(18, y_pos+20) #*depth_s)
	
#	# Z axis label if needed
#	if abs(depth) > 8:
#		# above the plane (place next to star icon)
#		if depth_s < 0:
#			get_node("Label2").position = Vector2(-6.5, y_pos+25)	
#		else:
#			# place next to shadow icon for below the plane
#			get_node("Label2").position = Vector2(0, 25)
#		get_node("Label2").set_text("Z: "+ str(depth_str) + " ly")
#		get_node("Label2").show()
#
#	else:
#		get_node("Label2").set_text("Z: "+ str(depth_str) + " ly")
#		get_node("Label2").hide()
	
	# color-code the Z direction
	# this is a variation of blue-red diverging color scale
	var clr_dir = Color(0,1,1) if depth_s < 0 else Color(1,0,0) # cyan if positive, red if neg
	var clr = clr_dir.darkened(abs(depth)/30) # 20 is max Z distance away from the plane
	#print(get_name() + "calculated Clr: ", clr)

	# this doesn't quite work?
	#get_node("ShadowTexture").self_modulate = Color(0.75,0.75,0.75).darkened(abs(depth)/30)

	get_node("ZTexture").flip_v = true if depth_s > 0 else false
	get_node("ZTexture").set_self_modulate(clr)
	
	if get_parent().get_name().find("Z-") != -1:
		get_node("ZTexture").flip_v = false
	
	get_node("Label2").set_text(str(depth_str)) #+ " ly") # all distances, e.g on ruler, are in ly anyway
	
	# test visualizing Z as icon size
	#var factor = abs(depth)/20 # 20 is max Z distance away from the plane on a single layer
	var factor = clamp(inverse_lerp(-10, +10, depth), 0.2, 1.0)
	get_node("ShadowTexture").set_scale(Vector2(1,1)*factor)
	
	var grad = preload("res://hud/new_gradient.tres")
	get_node("ShadowTexture").self_modulate = grad.sample(factor)
	
	# TODO: draw star color if option ticked
	
	calculate_label_and_sfx()

func add_planets_mark():
	var txt = get_node("Label").get_text()
	# if we don't have a marker already
	if planets and not "*" in txt:
		txt += "*"
		get_node("Label").set_text(txt)
		
# recalculated after the map moved
func calculate_label_and_sfx(offset=Vector2(0,0)):
	# do nothing if we're on a different Z layer
	if get_parent().get_name().find("Z+") != -1 or get_parent().get_name().find("Z-") != -1:
		return
	
	var y_pos = get_node("StarTexture").get_position().y
	var depth_s = sign(-depth)
	
	# now check if icon(s) are out of view
	var ab_shadow = get_node("ShadowTexture").get_global_position()
	var ab_planet = get_node("StarTexture").get_global_position()
	#if named.find("TST") != -1:
	#	print(get_name(), " shadow: ", ab_shadow, " star: ", ab_planet)
		
	# name label
	
	# special case 
	if named.find("Centauri") != -1:
		return
		
	#if ab_shadow > 0 and ab_shadow < 525:
		
	
#	# above the plane (place next to star icon)
#	if depth_s < 0:
#		# only do this if star icon visible
#		if get_node("StarTexture").visible:
#			get_node("Label").position = Vector2(-6.5, y_pos+2)
#		# if multi-line label
#		if get_node("Label").get_text().find("\n") != -1:
#			get_node("Label").position = Vector2(-6.5, y_pos-20)
#	# below the plane (place next to "shadow" icon)
#	else:
#		get_node("Label").position = Vector2(0, 0)

	# shadow in bounds but star is not (place name & Z-label next to shadow icon)
#	if (ab_planet.y < 0 or ab_planet.y > 525) and ab_planet != ab_shadow:
#		#if named.find("TST") != -1:
#		#print(get_name(), " shadow in bounds but star not...")
#		get_node("Label").position = Vector2(0, 0)
#		# if multi-line label
#		if get_node("Label").get_text().find("\n") != -1:
#			get_node("Label").position = Vector2(0, -20)
#		# Z axis label
#		get_node("Label2").position = Vector2(30, 25)
#		#get_node("Label2").set_text("Z: " + depth_str + " ly")
#		get_node("Label2").show()
#		# add direction arrow
#		#get_node("Label2").set_text("Z: "+ "%.2f" % depth + " ly " + "↓")
#
#	# inverse (shadow not in bounds), place labels next to star icon
#	if (ab_shadow.y < 0 or ab_shadow.y > 525):
#		#if named.find("TST") != -1:
#		#print("Force show star for: ", self.get_name())
#		# force show star
#		get_node("StarTexture").show()
#		get_node("Label").position = Vector2(-6.5, y_pos+2)
#		# if multi-line label
#		if get_node("Label").get_text().find("\n") != -1:
#			get_node("Label").position = Vector2(-6.5, y_pos-20)
#		# Z axis label
#		#get_node("Label2").position = Vector2(-6.5, y_pos+29) # 25+4
#		get_node("Label2").show()
#		#get_node("Label2").set_text("Z: "+ "%.2f" % depth + " ly " + "↑")
#	# force update if situation changes (map is panned)
#	else:
#		#print(get_name(), " shadow in bounds...")
#		get_node("StarTexture").hide()
#		get_node("Label").position = Vector2(0, 0)
#		# if multi-line label
#		if get_node("Label").get_text().find("\n") != -1:
#			get_node("Label").position = Vector2(0, -20)
#		# Z axis label
#		#get_node("Label2").position = Vector2(30, 25)
#		get_node("Label2").show()
#
#	if not_in_bounds(offset):
#		get_node("Line2D").set_modulate(Color(1,1,1,0.5)) # make semi-transparent
#	else:
#		get_node("Line2D").set_modulate(Color(1,1,1,1)) # restore normal opacity
	
	#get_node("Label2").hide()
	
	# special case for low Z icons
	if ab_planet == ab_shadow:
		#print("Low Z icon: ", named)
		if !not_in_bounds(offset):
			#print("Force show special!")
			# force show star
			get_node("StarTexture").show()
		
	# don't hide if we're the target
#	if get_parent().get_parent().tg == self:
#		# force show star
#		get_node("StarTexture").show()

func not_in_bounds(offset):
	# reworked to use Rect2
	# rect2 origin is the top-left corner!!!
	#var rect = Rect2(get_parent().position.x-(805/2), get_parent().position.y-(525/2), 805, 525)
	#var ab_shadow = get_node("ShadowTexture").get_position() + get_position() + get_parent().position
	#var ab_planet = get_node("PlanetTexture").get_position() + get_position() + get_parent().position
	
	# use a global (screen) rect and global positions
	var rect = Rect2(Vector2(0,0), Vector2(805, 525))
	var ab_shadow = get_node("ShadowTexture").get_global_position()
	var ab_planet = get_node("StarTexture").get_global_position()
	
	#print("rect: ", rect, "c: ", rect.get_center(), " ", get_node("Label").get_text(), " shadow: ", ab_shadow, " planet: ", ab_planet)
	var planet_out = !rect.has_point(ab_planet)
	var shadow_out = !rect.has_point(ab_shadow)
	
#	# global_position doesn't seem to be working correctly?
#	#print("planet icon: ", get_node("PlanetTexture").global_position.y, " shadow icon: ", get_node("ShadowTexture").global_position.y)
#	var ab_shadow = get_node("ShadowTexture").get_position().y + get_position().y
#	var ab_planet = get_node("PlanetTexture").get_position().y + get_position().y
#	# because the parent control is in the middle of the panel, at 525/2px
#
#	var planet_out = ab_planet < -250 or ab_planet > 250
#	var shadow_out = ab_shadow < -250 or ab_shadow > 250
#	print(get_node("Label").get_text(), " planet icon out of bounds: ", planet_out, " shadow out of bounds ", shadow_out) 

#	print("not in bounds: ", planet_out and shadow_out)
	return (planet_out and shadow_out)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func on_click():
	var vis = get_node("../../../Grid/VisControl")
	# clear any previous tint
	for l in get_parent().get_parent().get_children():
		for c in l.get_children():
			if !c.has_node("Label"):
				continue
			# skip wormhole target
			if c.get_node("Label").get_self_modulate() == Color(1,0,1):
				continue
			c.get_node("Label").set_self_modulate(Color(1,1,1))
			# FIXME: this isn't reliable!!! should be tracked elsewhere in one place instead
			if "selected" in c:
				c.selected = false
	print("Clicked on ", get_node("Label").get_text())
	# debug
	var ab_shadow = get_node("ShadowTexture").get_global_position()
	var ab_planet = get_node("StarTexture").get_global_position()
	#print("Shadow: ", ab_shadow, ", planet: ", ab_planet)
	
	get_node("Label").set_self_modulate(Color(1,0.5, 0)) # orange-red to match starmap icon and Z line color
	get_node("../../ruler/Label").set("custom_colors/font_color", Color(1,0.5, 0))
	get_node("../../ruler/Line2D").default_color = Color(1,0.5,0)
	#vis.get_node("Label").set("custom_colors/font_color", Color(1,0.5,0))
	
	# force reveal
	# unless we're on a different Z layer
#	if get_parent().get_name().find("Z+") == -1 and get_parent().get_name().find("Z-") == -1:
#		$Line2D.show()
#		$StarTexture.show()
	
	selected = true
	get_parent().get_parent().tg = get_parent().get_parent().get_tg()
	# line/distance ruler redrawing
	vis.clicked = true

	var dist = get_node("../../..").get_star_distance(get_node("../..").src, get_node("../..").tg)

	# no ruler if distances involved are very large
	if typeof(dist) != TYPE_FLOAT or (typeof(dist) == TYPE_FLOAT and dist > 100):
		get_node("../../ruler").hide()
	else:
		get_node("../../ruler").show()

	var tg_pos = get_node("../..").tg.position
	if get_node("../..").tg.get_node("StarTexture").visible:
		tg_pos += get_node("../..").tg.get_node("StarTexture").position
	get_node("../../ruler").pts = [get_node("../..").src.position, tg_pos]
	get_node("../../ruler").set_ruler()
	if typeof(dist) == TYPE_FLOAT: 
		get_node("../../ruler/Label").set_text("%.2f ly" % (dist))
	else:
		get_node("../../ruler/Label").set_text("Unknown")
	
	# update displayed starmap info
	get_node("../../../").display_star_map_info(get_node("../..").tg)
	# try to route
	if not pos in get_node("../../..").mapping:
		return
		
	var r = get_node("../../..").get_route_icons(get_node("../..").src, get_node("../..").tg)
	vis.route = r
	vis.queue_redraw()
	var r_heights = get_node("../../..").get_route_distance_height(get_node("../..").src, get_node("../..").tg)
	#get_node("../../RouteHeightPanel").route_data = r_heights
	#get_node("../../RouteHeightPanel").queue_redraw()
	#get_node("../../RouteHeightPanel").show()
	get_node("../../../../../Control2/Panel_rightHUD/Control/RouteHeightPanel").route_data = r_heights
	get_node("../../../../../Control2/Panel_rightHUD/Control/RouteHeightPanel").queue_redraw()
	get_node("../../../../../Control2/Panel_rightHUD/Control/RouteHeightPanel").show()
	
	# test
	var stars = get_node("../../..").get_closest_stars_to(get_node("../..").tg.pos)
	stars = get_node("../../..").closest_stars_postprocess(stars)
	#get_node("../../..").pretty_print_stars(stars)
	
# we don't want actual buttons, hence this
func _on_TextureRect2_gui_input(event):
	#if $"ShadowTexture".visible:
	if event is InputEventMouseButton:
		if event.is_pressed():
			on_click()

func _on_TextureRect3_gui_input(event):
	if $"StarTexture".visible:
		if event is InputEventMouseButton:
			if event.is_pressed():
				on_click()

# TODO: those won't be necessary if we display Z in some other way
# reveal Z line and star icon on mouse over
func _on_ShadowTexture_mouse_entered():
	# don't show lines if we're on a different Z layer
	if get_parent().get_name().find("Z+") != -1 or get_parent().get_name().find("Z-") != -1:
		return
	
	#$Line2D.show()
	#$StarTexture.show()


func _on_ShadowTexture_mouse_exited():
	pass
	# don't hide if we're the target
#	if get_parent().get_parent().tg == self:
#		return
#
#	$Line2D.hide()
#	$StarTexture.hide()


func _on_PlanetTexture_mouse_entered():
	# don't show lines if we're on a different Z layer
	if get_parent().get_name().find("Z+") != -1 or get_parent().get_name().find("Z-") != -1:
		return
		
	#if $"StarTexture".visible:
	#	$Line2D.show()


func _on_PlanetTexture_mouse_exited():
	pass
	#if $"StarTexture".visible:
	#	$Line2D.hide()
