extends ParallaxBackground


# Declare member variables here. Examples:
var init_pos = Vector2()


# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	#
	# send parallax offset to shader
	var parallax = get_scroll_offset()*get_scroll_base_scale()*get_node("ParallaxLayer").get_motion_scale()
	get_node("ParallaxLayer/Node2D/Sprite").get_material().set_shader_param("offset", parallax)
