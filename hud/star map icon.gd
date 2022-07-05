extends Control

const LY_TO_PX = 50;
export var x = 0.0
export var y = 0.0
export var depth = 0.0
export var named = ""

# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	# set name first so that debugging knows what we're dealing with
	set_name(named)
	get_node("Label").set_text(named)
	
	# positioning the stuff
	# in Godot, +Y goes down so we need to minus the Y we get from data
	set_position(Vector2(x*LY_TO_PX, -y*LY_TO_PX))
	
	# positive depth (above the plane) is negative y
	var depth_s = sign(-depth)
	var end = -depth*LY_TO_PX

	# 18 is the height of the star icon
	get_node("TextureRect3").rect_position = Vector2(0, end+18*depth_s) 
	
	# now check if icon(s) are out of view
	var ab_shadow = get_node("TextureRect2").get_position().y + get_position().y
	var ab_planet = get_node("TextureRect3").get_position().y + get_position().y
	# because the parent control is in the middle of the panel, at 525/2px
	# shadow can legitimately be out of view bounds
	if abs(ab_planet) > 250 and ab_shadow < -250:
		print("Icon for ", get_name(), " is out of view")
		# snap planet and not shadow
		# snap to panel top: -270px
		# snap to bottom: 230px
		# get_position y is negative here because shadow is negative
		# so just zero the y and add what we need
		get_node("TextureRect3").rect_position = Vector2(0, abs(-get_position().y+230))
		# make icon semi-transparent
		get_node("TextureRect3").set_modulate(Color(1,1,1,0.5))
	
	var y_pos = get_node("TextureRect3").get_position().y
	get_node("Line2D").points[0] = Vector2(18, y_pos+18*depth_s)
	
	# name label
	# above the plane (place next to star icon)
	if depth_s < 0:
		get_node("Label").rect_position = Vector2(-6.5, y_pos+4)
	# below the plane (place next to "shadow" icon)
	else:
		get_node("Label").rect_position = Vector2(0, 0)
	
	# Z axis label if needed
	if abs(depth) > 8:
		# above the plane (place next to star icon)
		if depth_s < 0:
			get_node("Label2").rect_position = Vector2(-6.5, y_pos+18)	
		else:
			# place next to shadow icon for below the plane
			get_node("Label2").rect_position = Vector2(0, 25)
		get_node("Label2").set_text("Z: " + str(depth) + " ly")
		get_node("Label2").show()

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
