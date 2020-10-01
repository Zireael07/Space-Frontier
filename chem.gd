extends Node

# class member variables go here, for example:
# from Dole's book "Habitable Planets for Man", p. 38 
var weights = { "H": 1.0, "H2": 2.0, "He": 4.0, "N":14.0, "O": 16.0, "CH4":16.0, 
	"NH3":17.0, "H2O":18.0, "Ne":20.2, "N2":28.0, "CO":28.0, "NO":30.0, "O2": 32.0,
	"H2S":34.1, "Ar":39.9, "CO2":44.0, "N2O":44.0, "NO2":46.0, "O3":48.0, 
	"SO2": 64.1, "SO3":80.1, "Kr":83.8, "Xe":131.3 }
	
# "solar abundances" from Keris's elements.dat, no source given
# looks like magic values because they don't gel with any source on elemental abundances I can find
var abunds = {"H": 27925.4, "H2":27925.4, "He": 2722.4, "N":3.1333, "O":23.8232, "O2":23.8232, "Ne":3.4435e-5,
"NH3": 0.0001, "H2O":0.001, "CO2": 0.0005, "O3":0.000001, "CH4":0.0001}

var reactivity = { "He": 0.0, "N": 0.0, "Ne": 0.0, "H2O":0.0, "CO2":0.0,
"O": 10.0, "O2":10.0, # oxygen is one of the most reactive elements in the universe
 "NH3":1.0, "O3":2.0, "CH4":1.0, "H": 1.0, "H2":1.0}

# from Keris's elements.dat
var boil = {"H": 20.40, "H2":20.40, "O": 90.20, "O2": 90.20, 
"H2O": 373.15, "CH4":109.15, "NH3":239.66, "CO2":194.66, "O3": 161.15}


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
