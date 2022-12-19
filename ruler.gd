tool
extends Control


# Declare member variables here. Examples:
export var pts = []
var text = ""


# Called when the node enters the scene tree for the first time.
func _ready():
	if pts.empty():
		return
	set_ruler()

func set_ruler():
	var mid = pts[0]+(pts[1]-pts[0])/2
	
	$Label.set_position(mid)
	
	if text == "":
		var dist = pts[1].distance_to(pts[0])
		$Label.set_text("%2.f" % dist)
	else:
		$Label.set_text(text)
	$Line2D.points = pts
	
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
