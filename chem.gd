extends Node

# class member variables go here, for example:
# from Dole's book "Habitable Planets for Man", p. 38 
var weights = { "H": 1.0, "H2": 2.0, "He": 4.0, "N":14.0, "O": 16.0, "CH4":16.0, 
	"NH3":17.0, "H2O":18.0, "Ne":20.2, "N2":28.0, "CO":28.0, "NO":30.0, "O2": 32.0,
	"H2S":34.1, "Ar":39.9, "CO2":44.0, "N2O":44.0, "NO2":46.0, "O3":48.0, 
	"SO2": 64.1, "SO3":80.1, "Kr":83.8, "Xe":131.3 }
	
# "solar abundances" from Keris's elements.dat, no source given
# https://github.com/zakski/accrete-starform-stargen/blob/master/originals/keris/src/main/c/propert.c
# 2008 version of Starform, from the same repo, tweaks molecule abundance a bit to not be uniform 0.001
# looks like magic values because they don't gel with any source on elemental abundances I can find
var abunds = {"H": 27925.4, "H2":27925.4, "He": 2722.4, "N":3.1333, "O":23.8232, "O2":23.8232, "Ne":3.4435e-5,
"NH3": 0.0001, "H2O":0.001, "CO2": 0.0005, "O3":0.000001, "CH4":0.0001}

var reactivity = { "He": 0.0, "N": 0.0, "Ne": 0.0, "H2O":0.0, # noble gases and nitrogen are inert
"CO2":2.0, # CO2 does react - it hangs around for around 1000 years before being put into rock
"O": 10.0, "O2":10.0, # oxygen is one of the most reactive elements in the universe
 "NH3":1.0, "O3":2.0, "CH4":1.0, "H": 1.0, "H2":1.0}

# from Keris's elements.dat
var boil = {"H": 20.40, "H2":20.40, "O": 90.20, "O2": 90.20, 
"H2O": 373.15, "CH4":109.15, "NH3":239.66, "CO2":194.66, "O3": 161.15}

# https://github.com/hakt0r/nuu/blob/610c02919392238365e5d57b75a6b4477cd168db/mod/core/common/elements.coffee
# which fits abundances data from Wolfram Alpha presented at https://periodictable.com/Properties/A/UniverseAbundance.html
var abundance = {"H":0.75, "He":0.23, "O":0.01, #1%
 "O2": 0.01, "H2":0.75,
 "Ne":0.0013,#0.13%
 "N": 0.001, #0.1%
 "Ar":0.0002, #0.002%

# molecules copied from abunds above because no actual data could be found
"NH3": 0.0001, "H2O":0.001, "CO2": 0.0005, "O3":0.000001, "CH4":0.0001,
}

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
