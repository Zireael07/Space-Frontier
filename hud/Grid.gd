tool
extends Control

const GRID_STEP = 40
const GRID_SIZE = 20

func _draw():
	for i in range(GRID_SIZE):
		var col = Color("#aaaaaa")
		var width = 1.0
		# origin
		if i == GRID_SIZE / 2:
			col = Color("#66cc66") # green
			width = 2.0
		draw_line(Vector2(i * GRID_STEP, 0), Vector2(i * GRID_STEP, GRID_SIZE * GRID_STEP), col, width)
	
	for j in range(GRID_SIZE):
		var col = Color("#aaaaaa")
		var width = 1.0
		# origin
		if j == GRID_SIZE / 2:
			col = Color("#cc6666") # red
			width = 2.0
		draw_line(Vector2(0, j * GRID_STEP), Vector2(GRID_SIZE * GRID_STEP, j * GRID_STEP), col, width)
