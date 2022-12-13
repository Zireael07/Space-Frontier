extends Panel


# Declare member variables here. Examples:
var route_data = null # should contain a list of input data
#var draw_data = []

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _draw():
	# draw a white line at height 0
	draw_line(Vector2(0,self.rect_size.y/2), Vector2(self.rect_size.x, self.rect_size.y/2), Color(1,1,1))
	if route_data:
		var clr = Color(0,1,0)
		#draw_data.clear()
		for pt in route_data:
			# we want to draw from the bottom of graph
			draw_line(Vector2(pt[0], self.rect_size.y/2), Vector2(pt[0], self.rect_size.y/2-pt[1]), clr)
			draw_circle(Vector2(pt[0], self.rect_size.y/2-pt[1]), 4, Color(0,1,0))
		
		
		# width param has no effect :(
		#draw_multiline(draw_data, Color(0,1,0), 5)
