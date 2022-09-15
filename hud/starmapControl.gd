extends Control


# Declare member variables here. Examples:
var src = null
var tg = null

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func get_src_loc():
	var loc = src.rect_position
	if src.has_node("TextureRect3"):
		loc = loc + src.get_node("TextureRect3").rect_position
	elif src.has_node("TextureRect"):
		loc = loc + src.get_node("TextureRect").rect_position
	return loc
	
func get_tg_loc():
	#var loc = null
	var loc = tg.rect_position
	if tg.has_node("TextureRect3"):
		loc = loc + tg.get_node("TextureRect3").rect_position
		#loc = tg.get_node("TextureRect3").rect_global_position
	elif tg.has_node("TextureRect"):
		loc = loc + tg.get_node("TextureRect3").rect_position
		 #loc = tg.get_node("TextureRect").rect_global_position
	return loc
	
func get_tg():
	var tg = null
	for c in get_children():
		if "selected" in c and c.selected:
			tg = c
			break
	return tg
