tool
extends Control


# Declare member variables here. Examples:

var icon = preload("res://hud/star map icon.tscn")

# data
var data = []


# Called when the node enters the scene tree for the first time.
func _ready():
	data = load_data()
	for line in data:
		# name, x, y, z, color
		print(line)
		if line[0] == "Barnard's Star" or line[0] == "Wolf 359":
			var ic = icon.instance()
			ic.named = str(line[0])
			ic.x = float(line[1])
			ic.y = float(line[2])
			ic.depth = float(line[3])
			
			get_node("Control").add_child(ic)
	
	
	#pass # Replace with function body.

func load_data():
	var file = File.new()
	var opened = file.open("res://hud/starmap.csv", file.READ)
	if opened == OK:
		while !file.eof_reached():
			var csv = file.get_csv_line()
			if csv != null:
				# skip header
				if csv[0] == "name":
					continue
				# skip empty lines
				if csv.size() > 1:
					data.append(csv)
					#print(str(csv))
	
		file.close()
		return data


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
