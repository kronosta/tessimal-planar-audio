class_name PlanarAudio extends Node2D

@export var song: Texture2D

func _ready():
	var sound_file = FileAccess.open("res://long_sound.raw", FileAccess.WRITE)
	
	for i in 44100 * 12:
		var time := float(i) / 44100.0
		
		sound_file.store_16(sin(time * TAU * 720.0) * 4096.0)
	
	sound_file.close()
