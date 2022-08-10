extends Control

# Declare member variables here. Examples:
const LY_TO_PX = 50;
export var x = 0.0
export var y = 0.0
export var depth = 0.0
export var named = ""
export var planets = false
var snapped = false


# Called when the node enters the scene tree for the first time.
func _ready():
	# set name first so that debugging knows what we're dealing with
	set_name(named)
	var txt = named
	if planets:
		txt += "*"
	
	get_node("Label").set_text(txt)
	
	
	# positioning the shadow icon
	# in Godot, +Y goes down so we need to minus the Y we get from data
	set_position(Vector2(x*LY_TO_PX, -y*LY_TO_PX))
	
	# positive depth (above the plane) is negative y
	var depth_s = sign(-depth)
	var end = -depth*LY_TO_PX

	# star icon positioned according to the depth
	# 18 is the height of the star icon
	get_node("TextureRect3").rect_position = Vector2(0, end+18*depth_s) 
	
	# clamp depth to two significant decimal places
	var depth_str = "%.2f" % depth
	
	# now check if icon(s) are out of view
#	var ab_shadow = get_node("TextureRect2").get_position().y + get_position().y
	var ab_planet = get_node("TextureRect3").get_position().y + get_position().y
#	# because the parent control is in the middle of the panel, at 525/2px
#	# shadow can legitimately be out of view bounds
#	if abs(ab_planet) > 250 and ab_shadow < -250:
#		print("Icon for ", get_name(), " is out of view")
#		# snap planet and not shadow
#		# snap to panel top: -270px
#		# snap to bottom: 230px
#		# get_position y is negative here because shadow is negative
#		# so just zero the y and add what we need
#		get_node("TextureRect3").rect_position = Vector2(0, abs(-get_position().y+230))
#		# make icon semi-transparent
#		get_node("TextureRect3").set_modulate(Color(1,1,1,0.75))
#		# force labels
#		snapped = true
#		get_node("Label2").rect_position = Vector2(-6.5, get_node("TextureRect3").get_position().y+25)
#		get_node("Label2").set_text("Z: " + depth_str + " ly")
#		get_node("Label2").show()
	
	var y_pos = get_node("TextureRect3").get_position().y
	get_node("Line2D").points[0] = Vector2(18, y_pos+20) #*depth_s)
	
	# name label		
	# above the plane (place next to star icon)
	if depth_s < 0 or snapped:
		get_node("Label").rect_position = Vector2(-6.5, y_pos+4)
	# below the plane (place next to "shadow" icon)
	else:
		get_node("Label").rect_position = Vector2(0, 0)
	
	# Z axis label if needed
	if abs(depth) > 8 and not snapped:
		# above the plane (place next to star icon)
		if depth_s < 0:
			get_node("Label2").rect_position = Vector2(-6.5, y_pos+25)	
		else:
			# place next to shadow icon for below the plane
			get_node("Label2").rect_position = Vector2(0, 25)
		get_node("Label2").set_text("Z: " + depth_str + " ly")
		get_node("Label2").show()

	# shadow in bounds but planet is not (place name & Z-label next to shadow icon)
	if ab_planet < -250:
		get_node("Label").rect_position = Vector2(0, 0)
		# Z axis label
		get_node("Label2").rect_position = Vector2(0, 25)
		get_node("Label2").set_text("Z: " + depth_str + " ly")
		get_node("Label2").show()

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
