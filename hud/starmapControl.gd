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

func get_src_loc(src):
	var loc = src.rect_position
	if src.has_node("TextureRect3"):
		loc = loc + src.get_node("TextureRect3").rect_position
	elif src.has_node("TextureRect"):
		loc = loc + src.get_node("TextureRect").rect_position
	return loc
	
func get_tg():
	var tg = null
	for c in get_children():
		if "selected" in c and c.selected:
			tg = c
			break
	return tg

# this is why this script even exists - to draw a line to target over everything else (e.g. the grid)
# func _draw():
#	for c in get_children():
#		if "selected" in c and c.selected:
#			tg = c
#			break
#
#	if tg:
#		draw_line(get_src_loc(src), tg.rect_position+tg.get_node("TextureRect3").rect_position, Color(1,0.5, 0), 3.0) # orange


# Note: doesn't draw if source control is out of view - hence drawing moved to grid
