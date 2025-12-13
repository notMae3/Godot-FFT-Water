extends Node

# Visual nodes
@onready var WindDirections_node = get_node_or_null("/root//main/3D/Camera/Control/DataTextures/LeftLeft/WindDirections")
@onready var InitialSpectrumTextures_node = get_node_or_null("/root//main/3D/Camera/Control/DataTextures/Left/InitialSpectrumTextures")
@onready var SpectrumTextures_node = get_node_or_null("/root//main/3D/Camera/Control/DataTextures/Left/SpectrumTextures")
@onready var FoamData_node = get_node_or_null("/root//main/3D/Camera/Control/DataTextures/Middle/FoamData")
@onready var DisplacementTextures_node = get_node_or_null("/root//main/3D/Camera/Control/DataTextures/Middle/DisplacementTextures")
@onready var SlopeTextures_node = get_node_or_null("/root//main/3D/Camera/Control/DataTextures/Right/SlopeTextures")
@onready var BouyancyData_node = get_node_or_null("/root//main/3D/Camera/Control/DataTextures/Right/BouyancyData")

# Shader file paths
var AssembleMaps_shader_path = "res:///shaders/AssembleMaps.glsl"
var InitializeSpectrum_shader_path = "res:///shaders/InitializeSpectrum.glsl"
var PackSpectrumConjugate_shader_path = "res:///shaders/PackSpectrumConjugate.glsl"
var UpdateSpectrumForFFT_shader_path = "res:///shaders/UpdateSpectrumForFFT.glsl"
var GenerateMipMaps_shader_path = "res:///shaders/GenerateMipMaps.glsl"
var FFT_shader_path = {
	1024: "res://shaders/FFT_1024.glsl",
	512: "res://shaders/FFT_512.glsl",
	256: "res://shaders/FFT_256.glsl",
	128: "res://shaders/FFT_128.glsl",
	64: "res://shaders/FFT_64.glsl"
}



# Constant params
const compute_work_group_size : int = 8 # aka local_size_x and local_size_y in the compute shaders
const spectrum_count : int = 8
var spectrum_texture_size : int = 512 # aka _N
var spectrum_texture_mipmap_factor : int = 2
var spectrum_texture_mipmap_size : int = 256
var water_msecpf : float = 16.6 # milliseconds per water frame, default 60fps

# Variable params
var debug_spectrums : bool = false
var spectrum_seed : int = 1
var depth : float = 20.0
var gravity : float = 9.81
var length_scales : Vector4 = Vector4(94, 128, 64, 32)
var low_cutoff : float = 0.001
var high_cutoff : float = 9000.0
var repeat_time : float = 200.0
var time_factor : float = 1.0
var lambda : Vector2 = Vector2(1, 1)
var foam_bias : float = -0.5
var foam_decayRate : float = 0.05
var foam_add : float = 0.5
var foam_threshold : float = 0.0

var spectrums : Array[SpectrumParameters] = [] # len 8
var params_received = false
var last_water_update_msec : float = 0.0 # value is msec since engine start

# RenderingDevice related
var rd : RenderingDevice
var initial_spectrum_textures : RID # 4 rgba32f
var spectrum_textures : RID # 8 rgba32f
var displacement_textures : RID # 4 rgba32f
var displacement_textures_mipmap : RID
var slope_textures : RID # 4 rg32f
var slope_textures_mipmap : RID
var buoyancy_data : RID # r32f
var buoyancy_data_mipmap : RID

# Compute shader instances
var InitializeSpectrum : ComputeShader
var PackSpectrumConjugate : ComputeShader
var UpdateSpectrumForFFT : ComputeShader
var FFT : ComputeShader
var AssembleMaps : ComputeShader
var GenerateMipMaps : ComputeShader


class SpectrumParameters extends RefCounted:
	var _gravity : float

	var _scale : float
	var _windSpeed : float
	var _windDirection : float
	var _fetch : float
	var _spreadBlend : float
	var _swell : float
	var _peakEnhancement : float
	var _shortWavesFade : float

	var serialized_byte_array : PackedByteArray

	func _init(gravity : float, scale : float, windSpeed : float, windDirection : float, fetch : float,
				spreadBlend : float, swell : float, peakEnhancement : float, shortWavesFade : float):
		_gravity = gravity

		_scale = scale
		_windSpeed = windSpeed
		_windDirection = windDirection
		_fetch = fetch
		_spreadBlend = spreadBlend
		_swell = swell
		_peakEnhancement = peakEnhancement
		_shortWavesFade = shortWavesFade

	func JonswapAlpha(gravity) -> float:
		return 0.076 * pow(gravity * _fetch / _windSpeed / _windSpeed, -0.22)

	func JonswapPeakFrequency(gravity) -> float:
		return 22 * pow(_windSpeed * _fetch / gravity / gravity, -0.33)

	## Turns the input spectrum parameters defined earlier into those the compute shader uses.
	## This return value is meant to be used with the param buffer
	func serialize() -> PackedByteArray:
		if not serialized_byte_array:
			serialized_byte_array = PackedFloat32Array([
				_scale,
				_windDirection / 180.0 * PI,
				_spreadBlend,
				clamp(_swell, 0.01, 1),
				JonswapAlpha(_gravity),
				JonswapPeakFrequency(_gravity),
				_peakEnhancement,
				_shortWavesFade
			]).to_byte_array()
		
		return serialized_byte_array


class ComputeShader extends RefCounted:
	var _N : int
	var _work_groups : Vector3i
	var _texture_rids : Array[RID]

	var _rd : RenderingDevice
	var shader_rid : RID
	var param_buffer_rid : RID
	var pipeline_rid : RID

	var param_type_to_packed_byte_array = {
		TYPE_VECTOR4: func(data): return PackedVector4Array([data]).to_byte_array(),
		TYPE_VECTOR2: func(data): return PackedVector2Array([data]).to_byte_array(),
		TYPE_INT: func(data): return PackedInt32Array([data]).to_byte_array(),
		TYPE_FLOAT: func(data): return PackedFloat32Array([data]).to_byte_array(),
		TYPE_BOOL: func(data): return PackedByteArray([data])
	}

	var param_type_to_memory_padding = {
		TYPE_VECTOR4: 16,
		TYPE_VECTOR2: 8,
		TYPE_INT: 4,
		TYPE_FLOAT: 4,
		TYPE_BOOL: 4
	}

	## Meant to be called with super._init at the begining of inheirited _init functions.
	## param_types is an dictionary of datatypes (eg. TYPE_ARRAY) and how many times they occur in the param buffer. eg. {TYPE_FLOAT: 3, TYPE_VECTOR4: 1}
	func _init(N, shader_file_path : String, rd : RenderingDevice, texture_rids : Array[RID], param_types : Dictionary, custom_work_groups : Vector3i = Vector3i.ZERO):
		_N = N
		_texture_rids = texture_rids
		_rd = rd
		_work_groups = Vector3i(int(_N/float(compute_work_group_size)), int(_N/float(compute_work_group_size)), 1) if custom_work_groups == Vector3i.ZERO else custom_work_groups

		# setup the param buffer if this compute shader uses one
		if not param_types.is_empty():
			var buffer_size = 0
			for data_type in param_types.keys():
				var data_type_size = param_type_to_memory_padding[data_type]
				var occurances = param_types[data_type]
				buffer_size += data_type_size * occurances
			
			param_buffer_rid = rd.storage_buffer_create(buffer_size)

		# setup the shader file and pipeline
		var shader_file_data : RDShaderFile = load(shader_file_path)
		var shader_spriv : RDShaderSPIRV = shader_file_data.get_spirv()
		shader_rid = rd.shader_create_from_spirv(shader_spriv)

		pipeline_rid = rd.compute_pipeline_create(shader_rid)
	
	## Assumes that the values in params array are orderd by memory padding size
	## ie. [Vec4, Vec2, int, float, bool]
	func _serialize_params(params : Array[Variant]) -> PackedByteArray:
		var bytes = PackedByteArray()

		for param in params:
			if param is SpectrumParameters:
				bytes += param.serialize()
			else:
				var packed_byte_array_constructor = param_type_to_packed_byte_array[typeof(param)]
				bytes += packed_byte_array_constructor.call(param)

		return bytes

	## Assumes that the values in params array are orderd by memory padding size
	## ie. [Vec4, Vec2, int, float, bool]
	func run(params : Array = []):
		
		# update the param buffer, if its used
		if param_buffer_rid:
			var param_bytes := _serialize_params(params)
			_rd.buffer_update(param_buffer_rid, 0, param_bytes.size(), param_bytes)

		# setup the param buffer uniform
		var param_buffer_uniform : RDUniform
		if param_buffer_rid:
			param_buffer_uniform = RDUniform.new()
			param_buffer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
			param_buffer_uniform.binding = 0
			param_buffer_uniform.add_id(param_buffer_rid)

		# setup the texture uniforms
		# binding increments but starts at either 1 or 0, depending on if param_buffer_rid exists
		var idx = 1 if param_buffer_rid else 0
		var texture_uniforms : Array[RDUniform] = []
		for texture_rid in _texture_rids:
			var texture_uniform := RDUniform.new()
			texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
			texture_uniform.binding = idx
			texture_uniform.add_id(texture_rid)

			texture_uniforms.append(texture_uniform)
			idx += 1

		var uniforms = ([param_buffer_uniform] + texture_uniforms) if param_buffer_rid else texture_uniforms
		var uniform_set : RID = _rd.uniform_set_create(uniforms, self.shader_rid, 0)

		# setup the compute list and dispatch
		var compute_list := _rd.compute_list_begin()
		_rd.compute_list_bind_compute_pipeline(compute_list, pipeline_rid)
		_rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
		_rd.compute_list_dispatch(compute_list, _work_groups.x, _work_groups.y, _work_groups.z)
		_rd.compute_list_end()

		_rd.free_rid(uniform_set)
	
	func destroy():
		_rd.free_rid(shader_rid) ; shader_rid = RID()
		_rd.free_rid(param_buffer_rid) ; param_buffer_rid = RID()
		_rd.free_rid(pipeline_rid) ; pipeline_rid = RID()



func _create_rd_texture(format : RenderingDevice.DataFormat, array_layers : int, is_mipmap : bool) -> RID:
	var texture_format := RDTextureFormat.new()
	texture_format.format = format
	texture_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D_ARRAY if array_layers != 1 else RenderingDevice.TEXTURE_TYPE_2D
	texture_format.width = spectrum_texture_mipmap_size if is_mipmap else spectrum_texture_size
	texture_format.height = spectrum_texture_mipmap_size if is_mipmap else spectrum_texture_size
	texture_format.array_layers = array_layers
	texture_format.usage_bits = \
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + \
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + \
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	# var img_format = {RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT: Image.FORMAT_RGBAF, RenderingDevice.DATA_FORMAT_R32G32_SFLOAT: Image.FORMAT_RGF, RenderingDevice.DATA_FORMAT_R32_SFLOAT: Image.FORMAT_RF}
	# var img = Image.create(128, 128, false, img_format[format])
	# img.fill(Color(1.0, 0.0, 0.0, 1.0))

	return rd.texture_create(texture_format, RDTextureView.new()) #, [img.get_data(), img.get_data(), img.get_data(), img.get_data()] if is_image_array else [img.get_data()])

func _create_texture_array_2drd(texture_rd_rid : RID, is_image_array = true):
		@warning_ignore("incompatible_ternary")
		var tex = Texture2DArrayRD.new() if is_image_array else Texture2DRD.new()
		tex.texture_rd_rid = texture_rd_rid
		return tex

func _ready():
	$/root/main/VisualizationTimer.timeout.connect(_update_visuals)
	rd = RenderingServer.get_rendering_device()



func insert_params(_water_fps : float, _debug_spectrums : bool, _spectrum_texture_size : int, _spectrum_texture_mipmap_factor : int, _spectrum_seed : int, _depth : float, _gravity : float, _length_scales : Vector4, _low_cutoff : float,
					_high_cutoff : float, _repeat_time : float, _time_factor : float, _lambda : Vector2, _foam_bias : float,
					_foam_decayRate : float, _foam_add : float, _foam_threshold : float, _spectrums : Array[SpectrumParameters]):
	if not params_received: # stuff that cant be updated at runtime
		spectrum_texture_size = _spectrum_texture_size 
		spectrum_texture_mipmap_factor = _spectrum_texture_mipmap_factor
		@warning_ignore("integer_division")
		spectrum_texture_mipmap_size = spectrum_texture_size / spectrum_texture_mipmap_factor
	
	water_msecpf = 1000 / _water_fps
	debug_spectrums = _debug_spectrums
	spectrum_seed = _spectrum_seed
	depth = _depth
	gravity = _gravity
	length_scales = _length_scales
	low_cutoff = _low_cutoff
	high_cutoff = _high_cutoff
	repeat_time = _repeat_time
	time_factor = _time_factor
	lambda = _lambda
	foam_bias = _foam_bias
	foam_decayRate = _foam_decayRate
	foam_add = _foam_add
	foam_threshold = _foam_threshold

	spectrums = _spectrums
	
	if not params_received:
		_init_rendering_device()
		_init_jonswap_spectrum()
		params_received = true

	if debug_spectrums:
		_init_jonswap_spectrum()
		

func _init_rendering_device():
	# setup the RenderingDevice textures
	var spectrum_count_half : int = int(spectrum_count/2.0)
	initial_spectrum_textures = 	 _create_rd_texture(RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT, spectrum_count_half, false)
	spectrum_textures =				 _create_rd_texture(RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT, spectrum_count, false)
	displacement_textures = 		 _create_rd_texture(RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT, spectrum_count_half, false)
	displacement_textures_mipmap = 	 _create_rd_texture(RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT, spectrum_count_half, true)
	slope_textures = 				 _create_rd_texture(RenderingDevice.DATA_FORMAT_R32G32_SFLOAT, spectrum_count_half, false)
	slope_textures_mipmap = 		 _create_rd_texture(RenderingDevice.DATA_FORMAT_R32G32_SFLOAT, spectrum_count_half, true)
	buoyancy_data = 				 _create_rd_texture(RenderingDevice.DATA_FORMAT_R32_SFLOAT, 1, false)
	buoyancy_data_mipmap = 			 _create_rd_texture(RenderingDevice.DATA_FORMAT_R32_SFLOAT, 1, true)

	# setup the compute shader handlers
	InitializeSpectrum = ComputeShader.new(
		spectrum_texture_size, InitializeSpectrum_shader_path, rd,
		[initial_spectrum_textures], {TYPE_VECTOR4: 1, TYPE_INT: 2, TYPE_FLOAT: 68}
	)

	PackSpectrumConjugate = ComputeShader.new(
		spectrum_texture_size, PackSpectrumConjugate_shader_path, rd,
		[initial_spectrum_textures], {TYPE_INT: 1}
	)

	UpdateSpectrumForFFT = ComputeShader.new(
		spectrum_texture_size, UpdateSpectrumForFFT_shader_path, rd,
		[initial_spectrum_textures, spectrum_textures], {TYPE_VECTOR4: 1, TYPE_INT: 1, TYPE_FLOAT: 3}
	)

	FFT = ComputeShader.new(
		spectrum_texture_size, FFT_shader_path[spectrum_texture_size], rd,
		[spectrum_textures], {TYPE_BOOL: 1}, Vector3i(1, spectrum_texture_size, 1)
	)

	AssembleMaps = ComputeShader.new(
		spectrum_texture_size, AssembleMaps_shader_path, rd,
		[spectrum_textures, displacement_textures, slope_textures, buoyancy_data], {TYPE_VECTOR2: 1, TYPE_FLOAT: 4}
	)

	GenerateMipMaps = ComputeShader.new(
		spectrum_texture_mipmap_size, GenerateMipMaps_shader_path, rd,
		[displacement_textures, displacement_textures_mipmap, slope_textures, slope_textures_mipmap, buoyancy_data, buoyancy_data_mipmap], {}
	)
	

	# connect the texture array RIDs to the water shader
	RenderingServer.global_shader_parameter_set("displacement_textures", _create_texture_array_2drd(displacement_textures))
	RenderingServer.global_shader_parameter_set("displacement_textures_mipmap", _create_texture_array_2drd(displacement_textures_mipmap))
	RenderingServer.global_shader_parameter_set("slope_textures", _create_texture_array_2drd(slope_textures))
	RenderingServer.global_shader_parameter_set("slope_textures_mipmap", _create_texture_array_2drd(slope_textures_mipmap))

func _init_jonswap_spectrum():
	InitializeSpectrum.run([
		length_scales, spectrum_texture_size, spectrum_seed,
		depth, gravity, low_cutoff, high_cutoff] + spectrums
	)

	# return

	PackSpectrumConjugate.run([spectrum_texture_size])

func should_update_water(ticks_msec) -> bool:
	var msec_since_update = ticks_msec - last_water_update_msec
	return msec_since_update > water_msecpf


func _process(_delta):
	var ticks_msec = Time.get_ticks_msec()
	if params_received and should_update_water(ticks_msec):
		update_water(ticks_msec)

func update_water(ticks_msec):
	last_water_update_msec = ticks_msec

	# Progress Spectrum For FFT
	UpdateSpectrumForFFT.run([
		length_scales, spectrum_texture_size, gravity,
		repeat_time, ticks_msec * time_factor / 1000.0 + 120.0 # skip 2min to avoid initial artifacts
	])

	FFT.run([true]) # horizontal FFT
	FFT.run([false]) # vertical FFT

	AssembleMaps.run([
		lambda, foam_bias, foam_decayRate, foam_add,
		foam_threshold
	])

	GenerateMipMaps.run()


func _input(event):
	if event.is_action_pressed("Esc"):
		get_tree().quit()

	if event.is_action_pressed("Space"):
		_update_visuals()
	
	if event.is_action_pressed("F"):
		# low quality debug code
		
		var img_bytes = rd.texture_get_data(displacement_textures, 0)
		var img = Image.create_from_data(spectrum_texture_size, spectrum_texture_size, false, Image.FORMAT_RGBAF, img_bytes)
		print(img.get_pixel(1,1))

		var images = []
		for i in range(spectrum_count/2.0):
			var data = rd.texture_get_data(displacement_textures, i)
			@warning_ignore("confusable_local_declaration")
			var img_ = Image.create_from_data(spectrum_texture_size, spectrum_texture_size, false, Image.FORMAT_RGBAF, data)
			images.append(img_)

		# disp
		var texture_array = Texture2DArray.new()
		texture_array.create_from_images(images)

		ResourceSaver.save(texture_array, "res://example_displacement_Texture2DArray.tres")

		images = []
		for i in range(spectrum_count/2.0):
			var data = rd.texture_get_data(displacement_textures_mipmap, i)
			@warning_ignore("confusable_local_declaration")
			var img_ = Image.create_from_data(spectrum_texture_mipmap_size, spectrum_texture_mipmap_size, false, Image.FORMAT_RGBAF, data)
			images.append(img_)

		texture_array = Texture2DArray.new()
		texture_array.create_from_images(images)

		ResourceSaver.save(texture_array, "res://example_displacement_Texture2DArray_mipmap.tres")

		# slope
		images = []
		for i in range(spectrum_count/2.0):
			var data = rd.texture_get_data(slope_textures, i)
			@warning_ignore("confusable_local_declaration")
			var img_ = Image.create_from_data(spectrum_texture_size, spectrum_texture_size, false, Image.FORMAT_RGF, data)
			images.append(img_)

		texture_array = Texture2DArray.new()
		texture_array.create_from_images(images)

		ResourceSaver.save(texture_array, "res://example_slope_Texture2DArray.tres")

		images = []
		for i in range(spectrum_count/2.0):
			var data = rd.texture_get_data(slope_textures_mipmap, i)
			@warning_ignore("confusable_local_declaration")
			var img_ = Image.create_from_data(spectrum_texture_mipmap_size, spectrum_texture_mipmap_size, false, Image.FORMAT_RGF, data)
			images.append(img_)

		texture_array = Texture2DArray.new()
		texture_array.create_from_images(images)

		ResourceSaver.save(texture_array, "res://example_slope_Texture2DArray_mipmap.tres")

		# buoyancy
		var data_ = rd.texture_get_data(buoyancy_data, 0)
		var img_ = Image.create_from_data(spectrum_texture_size, spectrum_texture_size, false, Image.FORMAT_RF, data_)

		ResourceSaver.save(img_, "res://example_buoyancy_Texture2D.tres")

		data_ = rd.texture_get_data(buoyancy_data_mipmap, 0)
		img_ = Image.create_from_data(spectrum_texture_mipmap_size, spectrum_texture_mipmap_size, false, Image.FORMAT_RF, data_)

		ResourceSaver.save(img_, "res://example_buoyancy_Texture2D_mipmap.tres")

func _update_visuals():
	if !get_node("/root/main/3D/Camera/Control/DataTextures").visible:
		return

	for i in range(spectrum_count):
		var direction = spectrums[i]._windDirection
		var visualizer : Control = WindDirections_node.get_child(i)
		visualizer.pivot_offset = visualizer.size/2.0
		visualizer.rotation_degrees = direction

	for i in range(spectrum_count):
		var spec_img : Image = Image.create_from_data(spectrum_texture_size, spectrum_texture_size, false, Image.FORMAT_RGBAF, rd.texture_get_data(spectrum_textures, i))
		spec_img.convert(Image.FORMAT_RGBF)
		SpectrumTextures_node.get_child(i).texture = ImageTexture.create_from_image(spec_img)

	for i in range(spectrum_count/2.0):
		var init_spec_img : Image = Image.create_from_data(spectrum_texture_size, spectrum_texture_size, false, Image.FORMAT_RGBAF, rd.texture_get_data(initial_spectrum_textures, i))
		init_spec_img.convert(Image.FORMAT_RGBF)
		InitialSpectrumTextures_node.get_child(i).texture = ImageTexture.create_from_image(init_spec_img)
		
		var disp_img : Image = Image.create_from_data(spectrum_texture_size, spectrum_texture_size, false, Image.FORMAT_RGBAF, rd.texture_get_data(displacement_textures, i))
		var foam_img : Image = disp_img.duplicate()
		disp_img.convert(Image.FORMAT_RGBF)
		FoamData_node.get_child(i).texture = ImageTexture.create_from_image(foam_img)
		DisplacementTextures_node.get_child(i).texture = ImageTexture.create_from_image(disp_img)
		
		SlopeTextures_node.get_child(i).texture = ImageTexture.create_from_image(Image.create_from_data(spectrum_texture_size, spectrum_texture_size, false, Image.FORMAT_RGF, rd.texture_get_data(slope_textures, i)))
	
	BouyancyData_node.get_child(0).texture = ImageTexture.create_from_image(Image.create_from_data(spectrum_texture_size, spectrum_texture_size, false, Image.FORMAT_RF, rd.texture_get_data(buoyancy_data, 0)))


func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		rd.free_rid(initial_spectrum_textures) ; initial_spectrum_textures = RID()
		rd.free_rid(spectrum_textures) ; spectrum_textures = RID()
		rd.free_rid(displacement_textures) ; displacement_textures = RID()
		rd.free_rid(slope_textures) ; slope_textures = RID()
		rd.free_rid(buoyancy_data) ; buoyancy_data = RID()

		InitializeSpectrum.destroy()
		PackSpectrumConjugate.destroy()
		UpdateSpectrumForFFT.destroy()
		FFT.destroy()
		AssembleMaps.destroy()
