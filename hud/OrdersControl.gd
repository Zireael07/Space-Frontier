extends TextureButton


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	# fix weird sizing bug
	_set_size(Vector2(100,100))


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_Control_pressed():
	print("Control pressed")
	get_node("VBoxContainer").set_position(Vector2(60, 60))
	#get_node("VBoxContainer").show()
