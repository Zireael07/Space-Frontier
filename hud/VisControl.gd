extends Control


# Declare member variables here. Examples:
var cntr = null
var clicked = false
var font = null
var route = null # should contain pairs of starmap icons (i.e. Controls)
var secondary = [] # for visual debugging

var line = preload("res://hud/varying_line.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	cntr = $"../../Control"
	#font = Control.new().get_font("font")
	font = get_theme_default_font()

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

# NOTE: by itself, doesn't offset with the map
func draw_route():
	# clear any past lines
	for i in get_child_count():
		if i > 1:
			get_child(i).queue_free()
	
	# draw route
	if route:
		for p in route:
			# paranoia skip
			if p[0] == null or p[1] == null:
				continue
	
	
			var l = line.instantiate()
			add_child(l)
			l.position = p[0].position+cntr.position
			l.get_node("Line2D").points = PackedVector2Array([Vector2(0,0), p[1].position-p[0].position])
			l.get_node("Line2D").width = 10
			l.get_node("Line2D").width_curve = null # FIXME: assign a calculated curve here
			# need a gradient to display more than one color
			var grad = Gradient.new()
			grad.offsets = [0, 1]

			# can't append to grad.colors itself
			var tmp_colors = []
			# get colors matching the star's Z
			if 'depth' in p[0]:
				tmp_colors.append(p[0].get_z_color(p[0].depth)[0])
				#print("Color 0: ", p[0].get_z_color(p[0].depth)[0])
			else:
				tmp_colors.append(Color(1,1,1,1))
			if 'depth' in p[1]:
				#print("Color 1: ", p[1].get_z_color(p[1].depth)[0])
				tmp_colors.append(p[1].get_z_color(p[1].depth)[0])
			else:
				tmp_colors.append(Color(1,1,1,1))
			
			grad.colors = tmp_colors
			#print("Colors: ", grad.colors)
			#grad.colors = [Color(1,0,0), Color(0,0,1)]
			l.get_node("Line2D").gradient = grad


# this is why this script even exists - to draw lines over everything else (e.g. the grid)
func _draw():
	# those use yellow because it's the most eye catching color and shouldn't be mistaken for fleet color here
	# draw starmap connections
	# NOTE: no known function that would let us draw a multi-colored line, except maybe drawing two lines, stopping in the middle? or Line2D
	if not clicked:
		for n in cntr.get_parent().get_neighbors_for_icon(cntr.src):
			var connect_clr = Color(1, 0.8, 0) #if not second else Color(1,0.0,0)
			if 'pos' in cntr.src and 'pos' in n:
				if [cntr.src.pos, n.pos] in secondary: #or [n, cntr.src] in secondary:
					connect_clr = Color(1,0,0)
			var ch = cntr.src.get_node("StarTexture")
			if cntr.src.has_node("ShadowTexture"):
				ch = cntr.src.get_node("ShadowTexture")
			draw_line(ch.position+cntr.src.position+cntr.position, n.position+cntr.position, connect_clr) #Color(1, 0.8, 0)) # yellow
				
	else:
		# if we're not on a different Z layer
		if cntr.tg.get_parent().get_name().find("Z+") == -1 and cntr.tg.get_parent().get_name().find("Z-") == -1:
			for n in cntr.get_parent().get_neighbors_for_icon(cntr.tg):
				# paranoia
				if n == null:
					continue
				var connect_clr = Color(1, 0.8, 0) #if not second else Color(1,0.0,0)
				if 'pos' in cntr.tg and 'pos' in n:
					if [cntr.tg.pos, n.pos] in secondary: #or [n, cntr.tg] in secondary:
						connect_clr = Color(1,0,0)
				var ch = cntr.tg.get_node("StarTexture")
				if cntr.tg.has_node("ShadowTexture"):
					ch = cntr.tg.get_node("ShadowTexture")
				draw_line(ch.position+cntr.tg.position+cntr.position, n.position+cntr.position, connect_clr) #Color(1, 0.8, 0)) # yellow
		
	# draw route
#	if route:
#		for p in route:
#			# paranoia skip
#			if p[0] == null or p[1] == null:
#				continue
#

			
			# vary color if connection crosses Z
#			var clr = Color(1, 0.8, 0)
#			if 'depth' in p[0] and 'depth' in p[1] and abs(p[0].depth-p[1].depth) > 12:
#				clr = Color(0.5, 0.5, 0)
#			# tint if all on another layer
#			if 'depth' in p[0] and 'depth' in p[1] and p[0].depth > 12 and p[1].depth > 12:
#				clr = Color(0.5, 0.5, 0.3) # slight blue tint
#			if 'depth' in p[0] and 'depth' in p[1] and p[0].depth < -12 and p[1].depth < -12:
#				clr = Color(0.3, 0.3, 0)
			# this draws next to shadow icons
			#draw_line(p[0].position+cntr.position, p[1].position+cntr.position, clr, 3.0)
			
			# this draws next to stars themselves
			#draw_line(p[0].get_node("StarTexture").position+p[0].position+cntr.position, p[1].get_node("StarTexture").position+p[1].position+cntr.position, Color(1, 0.8, 0), 3.0)
	
	# draw sector borders
	var offs = get_parent().get_parent().offset
	var sector = get_parent().get_parent().pos_to_sector(Vector3(-offs.x/50, -offs.y/50, 0))
	var sector_zero_start = Vector2(-512,-512) #internal data, floats to represent ints (ax off the last digit)
	# because in Godot, +Y axis goes down (this is all for visual purposes)
	var sector_begin = Vector2(sector[0]*1024, sector[1]*1024)+sector_zero_start
	var visual_begin = (sector_begin/10)*get_parent().get_parent().LY_TO_PX
	#print("Sector ", sector, " begin: ", visual_begin)
	# 50 px to ly, sector 0 is -50,-50 to 50,50ly means it's -2500,-2500, 5000,5000 in absolute coords
	#visual_begin = Vector2(-2500,-2500)
	# this draws in ABSOLUTE coords!
	draw_rect(Rect2(cntr.position+visual_begin, Vector2(5000,5000)), Color(0,1,0), false, 3.0)
	# draw sector coords
	draw_string(font, cntr.position+visual_begin+Vector2(10, 20), str(sector), HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
 Color(0,1,0))

	#draw_circle(cntr.position+visual_begin+Vector2(2500,2500), 2.0, Color(0,1,0))

	# draw quadrants
	# this assumes visual coords
	var pretty_q_i = {0: "NW", 1: "NE", 2:"SE", 3:"SW"}
	var offset = {0: Vector2(-20,-25), 1: Vector2(20, -25), 2: Vector2(20,25), 3: Vector2(-20,25)}
	var quads = get_parent().get_parent().sector_to_quadrants(sector_begin)
	for i in quads.size():
		var q = quads[i]
		var vis_pos = (q.position/10)*get_parent().get_parent().LY_TO_PX
		#print("Drawing rect @", q.position/10*get_parent().get_parent().LY_TO_PX)
		draw_rect(Rect2(cntr.position+(q.position/10)*get_parent().get_parent().LY_TO_PX, Vector2(q.size*get_parent().get_parent().LY_TO_PX)), Color(0,1,0), false, 2.0)
		# draw them round the center point
		draw_string(font, cntr.position+visual_begin+(q.size/10)*get_parent().get_parent().LY_TO_PX+offset[i], str(pretty_q_i[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0,1,0))
		# ... and on the corners
		draw_string(font, cntr.position+vis_pos+Vector2(15,25), str(pretty_q_i[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0,1,0))
	
	# by hand
#	draw_rect(Rect2(cntr.position+visual_begin, Vector2(2500,2500)), Color(0,1,0), false, 2.0)
#	draw_string(font, cntr.position+visual_begin+Vector2(15, 25), str("NW"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0,1,0))
#	draw_string(font, cntr.position+visual_begin+Vector2(2465, 25), str("NW"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0,1,0))
#
#	draw_rect(Rect2(cntr.position+visual_begin+Vector2(2500, 0), Vector2(2500,2500)), Color(0,1,0), false, 2.0)
#	draw_string(font, cntr.position+visual_begin+Vector2(2515, 25), str("NE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0,1,0))
#
#	draw_rect(Rect2(cntr.position+visual_begin+Vector2(0,2500), Vector2(2500,2500)), Color(0,1,0), false, 2.0)
#	draw_string(font, cntr.position+visual_begin+Vector2(15, 2525), str("SW"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0,1,0))
#	draw_string(font, cntr.position+visual_begin+Vector2(2465, 2525), str("SW"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0,1,0))
#
#	draw_rect(Rect2(cntr.position+visual_begin+Vector2(2500,2500), Vector2(2500,2500)), Color(0,1,0), false, 2.0)
#	draw_string(font, cntr.position+visual_begin+Vector2(2515, 2525), str("SE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0,1,0))

	# debug
	if sector[0] == 0 and sector[1] == -1:
		#var smaller_quads_ne = get_parent().get_parent().quadrants(sector_begin+Vector2(512,512), 256, 256, false)
		var smaller_quads_ne = []
		for i in smaller_quads_ne.size():
			var q = smaller_quads_ne[i]
			var vis_pos = (q.position/10)*get_parent().get_parent().LY_TO_PX
			#print("Drawing rect @", q.position/10*get_parent().get_parent().LY_TO_PX)
			draw_rect(Rect2(cntr.position+(q.position/10)*get_parent().get_parent().LY_TO_PX, Vector2(q.size/10*get_parent().get_parent().LY_TO_PX)), Color(0,1,0), false, 1.5)
			# draw them round the center point
			draw_string(font, cntr.position+visual_begin+Vector2(51,0)*get_parent().get_parent().LY_TO_PX+(q.size/10)*get_parent().get_parent().LY_TO_PX+offset[i], str(pretty_q_i[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0,1,0))
		
		var smaller_quads_nw = get_parent().get_parent().quadrants(sector_begin+Vector2(512,512), 256, 256, false)	
		for i in smaller_quads_nw.size():
			var q = smaller_quads_nw[i]
			var vis_pos = (q.position/10)*get_parent().get_parent().LY_TO_PX
			#print("Drawing rect @", q.position/10*get_parent().get_parent().LY_TO_PX)
			draw_rect(Rect2(cntr.position+(q.position/10)*get_parent().get_parent().LY_TO_PX, Vector2((q.size/10)*get_parent().get_parent().LY_TO_PX)), Color(0,1,0), false, 1.5)
			# draw them round the center point
			draw_string(font, cntr.position+visual_begin+Vector2(51,51)*get_parent().get_parent().LY_TO_PX+(q.size/10)*get_parent().get_parent().LY_TO_PX+offset[i], str("sub-"+pretty_q_i[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0,1,0))
		
