extends Control

export var x = 0.0
export var y = 0.0
export var depth = 0.0
export var named = ""

# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	# positioning the stuff
	set_position(Vector2(x*50, y*50))
	# positive depth (above the plane) is negative y
	get_node("Line2D").points[0] = Vector2(18, -depth*50)
	
	var depth_s = sign(-depth)
	# 18 is the height of the star icon
	get_node("TextureRect3").rect_position = Vector2(0, -depth*50+18*depth_s) 
	# name label
	# above the plane (place next to star icon)
	if depth_s < 0:
		get_node("Label").rect_position = Vector2(-6.5, -depth*50+18)
	# below the plane (place next to "shadow" icon)
	else:
		get_node("Label").rect_position = Vector2(0, 0)
	
	# Z axis label if needed
	if depth < -8: 
		get_node("Label2").rect_position = Vector2(0, 25)
		get_node("Label2").set_text("Z: " + str(depth) + " ly")
		get_node("Label2").show()
	
	set_name(named)
	get_node("Label").set_text(named)
	
	#pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
