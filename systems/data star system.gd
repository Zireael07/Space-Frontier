extends Node2D


# Declare member variables here. Examples:
var data

var star = preload("res://bodies/star.tscn")
var star_script = preload("res://systems/star.gd")
var planet = preload("res://bodies/planet_rotating_procedural.tscn")

var holder = null

# Called when the node enters the scene tree for the first time.
func _ready():
	spawn_from_data(data)
	pass # Replace with function body.

func spawn_from_data(data):
	print("Spawning system for data: ", data)
	
	for i in data.size():
		# the first is always the star
		if i == 0:
			var s = star.instance()
			s.set_name(data[i][0])
			s.get_node("Label").set_text(data[i][0])
			var h = Node2D.new()
			h.set_name("planet_holder")
			s.add_child(h)
			holder = h
			add_child(s)
		else:
		#if i > 0:
			var d = data[i]
			print(d)
			var b = null
			if d[1].strip_edges() == "planet":
				b = planet.instance()
				b.set_name(data[i][0])
				b.get_node("Label").set_text(data[i][0])
				holder.add_child(b)
				# FIXME: placeholder values
				b.setup(0, float(d[2])*game.AU, 0, 0, false)
			else:
				b = star.instance()
				b.set_name(data[i][0])
				b.get_node("Label").set_text(data[i][0])
				b.set_script(star_script)
				var dist = float(d[2])*game.AU
				var pos = Vector2(0, dist).rotated(deg2rad(0))
				b.set_position(pos)
				add_child(b)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
