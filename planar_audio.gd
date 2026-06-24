class_name PlanarAudio extends Node2D

@export var tracks: Array[Texture2D]

func _ready():
	var sound_file = FileAccess.open("res://song.raw", FileAccess.WRITE)
	
	# where we're slicing
	var angle := 0.62
	var offset := Vector2.ZERO
	if offset.x < 0.0 or offset.y < 0.0:
		print("offset must be greater than 0 in both axes")
		return
	
	# extract song data
	var track_images: Array[Image]
	for t in tracks:
		track_images.append(t.get_image())
	var seconds_in_a_pixel := 0.25
	
	# get length of slice
	var ray_start := Vector3(offset.x, offset.y, 0.5)
	var ray_dir := Vector3(cos(angle), sin(angle), 0.0)
	var diagonal := tracks[0].get_size().length()
	var intersection = AABB(Vector3.ZERO, Vector3(tracks[0].get_width(), tracks[0].get_height(), 1.0)).intersects_ray(ray_start + (ray_dir * diagonal * 2.0), -ray_dir)
	if !intersection:
		print("failed to get length of song slice")
		return
	
	var length := ray_start.distance_to(intersection)
	
	var sample_rate := 44100.0
	for i in sample_rate * length * seconds_in_a_pixel:
		var time := float(i) / sample_rate
		var sample := 0
		
		for track_image in track_images:
			var color := track_image.get_pixel(
				int(floor((time / seconds_in_a_pixel) + offset.x)) * cos(angle),
				int(floor((time / seconds_in_a_pixel) + offset.y)) * sin(angle)
			)
			
			var frequency := pow(2.0, color.h * 4.0) * 64.0
			
			sample += compute_tone(time, frequency, color.v)
		
		sound_file.store_16(sample)
	
	sound_file.close()
	
	var dir = DirAccess.open(".")
	dir.remove("./song.wav")
	OS.execute("ffmpeg", PackedStringArray(["-f", "s16le", "-ar", "44100", "-ac", "1", "-i", "./song.raw", "./song.wav"]))
	
	$AudioStreamPlayer.stream = load("res://song.wav")
	get_tree().create_timer(0.5).connect("timeout", $AudioStreamPlayer.play)

func compute_tone(time: float, frequency: float, amplitude: float) -> int:
	return sin(time * TAU * frequency) * amplitude * 4096.0
