extends Panel


# Declare member variables here. Examples:
var route_data = null # should contain a list of input data
#var draw_data = []
var vis = null

# Called when the node enters the scene tree for the first time.
func _ready():
	# this is for being under the starmap itself
	#vis = get_node("../Grid/VisControl")
	pass

func _draw():
	# draw a white line at height 0
	draw_line(Vector2(0,self.size.y/2), Vector2(self.size.x, self.size.y/2), Color(1,1,1))
	if route_data:
		var clr = Color(1,0.8,0) # yellow like the route itself 
		#draw_data.clear()
		for pt in route_data:
			# if planet is on different Z-level, fade it out
			if abs(pt[1]) > 120: clr = Color(0.5, 0.5, 0.5)
			# we want to draw from the bottom of graph
			draw_line(Vector2(pt[0], self.size.y/2), Vector2(pt[0], self.size.y/2-pt[1]), clr)
			# ... and don't draw a circle for planets on different Z-levels
			if abs(pt[1]) < 120:
				draw_circle(Vector2(pt[0], self.size.y/2-pt[1]), 4, clr)
			
		# width param has no effect :(
		#draw_multiline(draw_data, Color(0,1,0), 5)
	else:
		var clr = Color(1,0,1) if not vis.clicked else Color(1,0.5,0) # orange-red to match map icons and Z lines	
		
		if vis.cntr.tg:
			var z = 0
			if 'depth' in vis.cntr.src:
				z = vis.cntr.src.depth
			# we want to draw from the bottom of graph
			draw_line(Vector2(0, self.size.y/2), Vector2(0, self.size.y/2-z), clr)
			draw_circle(Vector2(0, self.size.y/2-z), 4, clr)

			var dist = (vis.cntr.tg.pos if "pos" in vis.cntr.tg else Vector3(0,0,0) - Vector3(0,0,0)).length()
			if 'pos' in vis.cntr.src:
				dist = (vis.cntr.tg.pos if "pos" in vis.cntr.tg else Vector3(0,0,0) -vis.cntr.src.pos).length()
			
			# icon's depth is the original float so we use pos[2] to get the int 
			# (which is multiplied by 10, hence this panel's scale)
			# if planet is on different Z-level, fade it out
			if "pos" in vis.cntr.tg and abs(vis.cntr.tg.pos[2]) > 120: clr = Color(0.5, 0.5, 0.5)
			draw_line(Vector2(dist, self.size.y/2), Vector2(dist, self.size.y/2-vis.cntr.tg.pos[2] if "pos" in vis.cntr.tg else 0), clr)
			if not 'pos' in vis.cntr.tg:
				return
			# ... and don't draw a circle for planets on different Z-levels
			if abs(vis.cntr.tg.pos[2]) < 120:
				draw_circle(Vector2(dist, self.size.y/2-vis.cntr.tg.pos[2]), 4, clr)

