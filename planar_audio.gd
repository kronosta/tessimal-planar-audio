class_name PlanarAudio extends Node2D

@export var song: Texture2D

func _ready():
	var sound_file = FileAccess.open("res://song.raw", FileAccess.WRITE)
	
	var song_image := song.get_image()
	var seconds_in_a_pixel := 0.25
	
	var angle := TAU / 8.0
	
	var offset := Vector2.ZERO
	
	for i in 44100:
		var time := float(i) / 44100.0
		
		var magnitude := song_image.get_pixel(
			int((time / seconds_in_a_pixel) + offset.x) * cos(angle),
			int((time / seconds_in_a_pixel) + offset.y) * sin(angle)
		).r
		
		sound_file.store_16(sin(time * TAU * 720.0) * magnitude * 4096.0)
	
	sound_file.close()
