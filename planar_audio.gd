class_name PlanarAudio extends Node2D

@export var tracks: Array[Texture2D]
@export var phase_tracks: Array[Texture2D]
@export var wavetable_tracks: Array[Texture2D]
@export var angle: float 	# where we're slicing
@export var offset: Vector2 # offset in seconds
@export var sample_rate := 44100.0

func _ready():
	var sound_file = FileAccess.open("res://song.raw", FileAccess.WRITE)

	if offset.x < 0.0 or offset.y < 0.0:
		print("offset must be greater than 0 in both axes")
		return
	
	# extract song data
	var track_images: Array[Image]
	for t in tracks:
		track_images.append(t.get_image())
	
	var phase_track_images: Array[Image]
	for t in phase_tracks:
		phase_track_images.append(t.get_image())
		
	var wavetable_track_images: Array[Image]
	for t in wavetable_tracks:
		wavetable_track_images.append(t.get_image())
	
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
	
	# loop setup
	
	var amplitudes := PackedFloat32Array()
	amplitudes.resize(tracks.size())
	
	var frequencies := PackedFloat32Array()
	frequencies.resize(tracks.size())
	
	var phases := PackedFloat32Array()
	phases.resize(tracks.size()) # use dummy values for the unfilled ones
	
	# Some optimization to avoid a huge conditional every sample
	var cells_x = track_images[0].get_width()
	var cells_y = track_images[0].get_width()
	var wavetable_callables : Array
	for i in cells_x:
		wavetable_callables.append([])
		for j in cells_y:
			wavetable_callables[i].append([])
			for t in track_images.size():
				if t < wavetable_track_images.size():
					wavetable_callables[i][j].append(get_wave_function(wavetable_track_images[t].get_pixel(i, j)))
				else:
					wavetable_callables[i][j].append(compute_sine_sample)
	
	for i in sample_rate * length * seconds_in_a_pixel:
		var time := float(i) / sample_rate
		var sample := 0
		
		var pixelcoords := Vector2i(
			int(floor(((time / seconds_in_a_pixel) * cos(angle)) + (offset.x / seconds_in_a_pixel))),
			int(floor(((time / seconds_in_a_pixel) * sin(angle)) + (offset.y / seconds_in_a_pixel)))
		)
		for t in track_images.size():
			if ((time / seconds_in_a_pixel) * cos(angle)) + (offset.x / seconds_in_a_pixel) >= 16:
				print(((time / seconds_in_a_pixel) * cos(angle)) + (offset.x / seconds_in_a_pixel))
			var color := track_images[t].get_pixel(pixelcoords.x, pixelcoords.y)
			
			var phase_color : Color
			if t >= phase_tracks.size():
				phase_color = Color.BLACK
			else:
				phase_color = phase_track_images[t].get_pixel(pixelcoords.x, pixelcoords.y)
			
			
			
			if color != Color.BLACK:
				frequencies[t] = pow(2.0, color.h * 4.0) * 64.0
			
			amplitudes[t] = lerpf(amplitudes[t], color.v, 0.002)
			
			phases[t] = phase_color.v * TAU
			sample += wavetable_callables[pixelcoords.x][pixelcoords.y][t].call(amplitudes[t], (time * TAU + phases[t]) * frequencies[t])
		
		sound_file.store_16(sample)
	
	sound_file.close()
	
	var dir = DirAccess.open(".")
	dir.remove("./song.wav")
	OS.create_process("ffmpeg", PackedStringArray(["-f", "s16le", "-ar", "44100", "-ac", "1", "-i", "./song.raw", "./song.wav"]))

func get_wave_function(color : Color) -> Callable:
	match color.to_html(false):
		"000000": # Sine wave
			return compute_sine_sample
		"ff0000": # Square wave
			return compute_square_sample
		"00ff00": # Triangle wave
			return compute_triangle_sample
		"ffff00": # Sawtooth wave
			return compute_sawtooth_sample
		_:
			return compute_sine_sample
			
func compute_sine_sample(amplitude: float, cycle_pos: float) -> int:
	return sin(cycle_pos) * amplitude * 4096.0 # Sine wave again
			
func compute_square_sample(amplitude: float, cycle_pos: float) -> int:
	return (amplitude if fmod(cycle_pos, TAU) > PI else -amplitude) * 4096.0
	
func compute_triangle_sample(amplitude: float, cycle_pos: float) -> int:
	return abs(fmod(cycle_pos, TAU) / PI - 1) * amplitude * 4096.0

func compute_sawtooth_sample(amplitude: float, cycle_pos: float) -> int:
	return (cycle_pos / TAU - floor(cycle_pos / TAU)) * amplitude * 4096.0
