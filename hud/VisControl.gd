extends Control


# Declare member variables here. Examples:
var cntr = null
var clicked = false
var font = null
var route = null # should contain pairs of starmap icons (i.e. Controls)
var secondary = [] # for visual debugging

# Called when the node enters the scene tree for the first time.
func _ready():
	cntr = $"../../Control"
	#font = Control.new().get_font("font")
	font = get_theme_default_font()

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

# this is why this script even exists - to draw lines over everything else (e.g. the grid)
func _draw():
	# those use yellow because it's the most eye catching color and shouldn't be mistaken for fleet color here
	# draw starmap connections
	if not clicked:
		for n in cntr.get_parent().get_neighbors_for_icon(cntr.src):
			var connect_clr = Color(1, 0.8, 0) #if not second else Color(1,0.0,0)
			if [cntr.src, n] in secondary: #or [n, cntr.src] in secondary:
				connect_clr = Color(1,0,0)
			draw_line(cntr.src.get_node("StarTexture").position+cntr.src.position+cntr.position, n.position+cntr.position, connect_clr) #Color(1, 0.8, 0)) # yellow
	else:
		# if we're not on a different Z layer
		if cntr.tg.get_parent().get_name().find("Z+") == -1 and cntr.tg.get_parent().get_name().find("Z-") == -1:
			for n in cntr.get_parent().get_neighbors_for_icon(cntr.tg):
				var connect_clr = Color(1, 0.8, 0) #if not second else Color(1,0.0,0)
				if [cntr.tg.get_name().rstrip("*"), n.get_name().rstrip("*")] in secondary: #or [n, cntr.tg] in secondary:
					connect_clr = Color(1,0,0)
				draw_line(cntr.tg.get_node("StarTexture").position+cntr.tg.position+cntr.position, n.position+cntr.position, connect_clr) #Color(1, 0.8, 0)) # yellow
		
	# draw route
	if route:
		for p in route:
			# this draws next to shadow icons
			draw_line(p[0].position+cntr.position, p[1].position+cntr.position, Color(1, 0.8, 0), 3.0)
			# this draws next to stars themselves
			#draw_line(p[0].get_node("StarTexture").position+p[0].position+cntr.position, p[1].get_node("StarTexture").position+p[1].position+cntr.position, Color(1, 0.8, 0), 3.0)
	
	# draw sectors
	# 50 px to ly, sector is -50,-50 to 50,50ly means it's -2500,-2500, 5000,5000 in absolute coords
	draw_rect(Rect2(cntr.position+Vector2(-2500,-2500), Vector2(5000,5000)), Color(0,1,0), false, 3.0)
	# draw sector coords
	draw_string(font, cntr.position+Vector2(-2490, -2480), "0,0", HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
 Color(0,1,0))
