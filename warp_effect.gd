extends AnimatedSprite2D

# class member variables go here, for example:
# var a = 2
# var b = "textvar"

#func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.
#	pass


func _on_explosion_animation_finished():
	queue_free()
	
	get_parent().warping = true
	
	#print("animation finished")
