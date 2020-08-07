extends Control


# Declare member variables here. Examples:
var targeted = false
# helper
var type_id = 0
enum type { ship, starbase} 
var rect = null

# Called when the node enters the scene tree for the first time.
func _ready():
	# calc the rect once only
	if type_id == type.ship:
		rect = Rect2(Vector2(0,0), Vector2(18,18))
	if type_id == type.starbase:
		rect = Rect2(Vector2(0,0), Vector2(36, 36))
	
	#print("Set rect to " + str(rect))

func _draw():
	# red outline for target
	if targeted == true and rect != null:
		draw_rect(rect, Color(1,0,0), false)
	else:
		pass
