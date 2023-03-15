@tool
extends Path2D


# Declare member variables here. Examples:
@export var segments = 32
@export var xAxis = 50
@export var yAxis = 70

# Called when the node enters the scene tree for the first time.
func _ready():
	curve.clear_points()
	calculateEllipse()
	
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

# based on https://www.youtube.com/watch?v=mQKGRoV_jBc
func calculateEllipse():
	for i in range(segments):
		var angle = (float(i) / segments) * deg_to_rad(360);
		var x = sin(angle) * xAxis;
		var y = cos(angle) * yAxis;
		
		self.curve.add_point(Vector2(x,y))
		#points.append(Vector2(x,y))
	
	
	# close
	self.curve.add_point(self.curve.get_point_position(0))
	
	# debug
	#for i in curve.get_point_count():
	#	print(curve.get_point_position(i))
