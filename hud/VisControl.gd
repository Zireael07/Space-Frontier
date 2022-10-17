extends Control


# Declare member variables here. Examples:
var cntr = null
var clicked = false
var font = null

# Called when the node enters the scene tree for the first time.
func _ready():
	cntr = $"../../Control"
	font = Control.new().get_font("font")


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

# this is why this script even exists - to draw a line to target over everything else (e.g. the grid)
func _draw():
	# drawing a direction line
	var clr = Color(0,1,1) if not clicked else Color(1,0.5,0) # orange-red to match map icons and Z lines
	if cntr.tg:
		draw_line(cntr.src.get_node("StarTexture").rect_position+cntr.src.rect_position+cntr.rect_position, cntr.tg.rect_position+cntr.tg.get_node("StarTexture").rect_position+cntr.rect_position, clr, 3.0)
	
	# draw starmap connections
	if not clicked:
		for n in cntr.get_parent().get_neighbors_for_icon(cntr.src):
			draw_line(cntr.src.get_node("StarTexture").rect_position+cntr.src.rect_position+cntr.rect_position, n.rect_position+cntr.rect_position, Color(1, 0.8, 0)) # yellow
	else:
		for n in cntr.get_parent().get_neighbors_for_icon(cntr.tg):
			draw_line(cntr.tg.get_node("StarTexture").rect_position+cntr.tg.rect_position+cntr.rect_position, n.rect_position+cntr.rect_position, Color(1, 0.8, 0)) # yellow
	
	
	# draw sectors
	# 50 px to ly, sector is -50,-50 to 50,50ly means it's -2500,-2500, 5000,5000 in absolute coords
	draw_rect(Rect2(cntr.rect_position+Vector2(-2500,-2500), Vector2(5000,5000)), Color(0,1,0), false, 3.0)
	# draw sector coords
	draw_string(font, cntr.rect_position+Vector2(-2490, -2480), "0,0", Color(0,1,0))
