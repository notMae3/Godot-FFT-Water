extends Control

@export var mesh_follow_camera : bool
@export var sun_rotation : Vector2 = Vector2.ZERO
@export var debug_spectrums : bool = false
@export_enum("64:64", "128:128", "256:256", "512:512", "1024:1024") var spectrum_texture_size : int = 512
@export_enum("2:2", "4:4", "8:8") var spectrum_texture_mipmap_factor : int = 2

@export_range(1.0, 144.0, 1.0) var water_fps : float = 60

@export var spectrum_seed : int = 1
@export var depth : float = 20.0
@export var gravity : float = 9.81
@export var length_scales : Vector4 = Vector4(94, 128, 64, 32)
@export var low_cutoff : float = 0.001
@export var high_cutoff : float = 9000.0
@export var repeat_time : float = 200.0
@export var time_factor : float = 1.0
@export var lambda : Vector2 = Vector2(1, 1)
@export var foam_bias : float = -0.5
@export var foam_decayRate : float = 0.05
@export var foam_add : float = 0.5
@export var foam_threshold : float = 0.0

@export_category("Layer1")
@export_group("Spec1 uniforms")
@export_range(0.0, 5.0, 0.001, "or_greater") var Spec1_scale : float = 0.1
@export_range(0.001, 250.0, 0.001, "or_greater") var Spec1_windSpeed : float = 2
@export_range(0.0, 360.0) var Spec1_windDirection : float = 22
@export_range(0.0, 1e+08, 100.0, "exp") var Spec1_fetch : float = 100000
@export var Spec1_spreadBlend : float = 0.642
@export var Spec1_swell : float = 1
@export var Spec1_peakEnhancement : float = 1
@export var Spec1_shortWavesFade : float = 0.025

@export_group("Spec2 uniforms")
@export_range(0.0, 5.0, 0.001, "or_greater") var Spec2_scale : float = 0.07
@export_range(0.001, 250.0, 0.001, "or_greater") var Spec2_windSpeed : float = 2
@export_range(0.0, 360.0) var Spec2_windDirection : float = 59
@export_range(0.0, 1e+08, 100.0, "exp") var Spec2_fetch : float = 1000
@export var Spec2_spreadBlend : float = 0
@export var Spec2_swell : float = 1
@export var Spec2_peakEnhancement : float = 1
@export var Spec2_shortWavesFade : float = 0.01

@export_category("Layer2")
@export_group("Spec3 uniforms")
@export_range(0.0, 5.0, 0.001, "or_greater") var Spec3_scale : float = 0.25
@export_range(0.001, 250.0, 0.001, "or_greater") var Spec3_windSpeed : float = 20
@export_range(0.0, 360.0) var Spec3_windDirection : float = 97
@export_range(0.0, 1e+08, 100.0, "exp") var Spec3_fetch : float = 1e+08
@export var Spec3_spreadBlend : float = 0.14
@export var Spec3_swell : float = 1
@export var Spec3_peakEnhancement : float = 1
@export var Spec3_shortWavesFade : float = 0.5

@export_group("Spec4 uniforms")
@export_range(0.0, 5.0, 0.001, "or_greater") var Spec4_scale : float = 0.25
@export_range(0.001, 250.0, 0.001, "or_greater") var Spec4_windSpeed : float = 20
@export_range(0.0, 360.0) var Spec4_windDirection : float = 67
@export_range(0.0, 1e+08, 100.0, "exp") var Spec4_fetch : float = 1000000
@export var Spec4_spreadBlend : float = 0.47
@export var Spec4_swell : float = 1
@export var Spec4_peakEnhancement : float = 1
@export var Spec4_shortWavesFade : float = 0.5

@export_category("Layer3")
@export_group("Spec5 uniforms")
@export_range(0.0, 5.0, 0.001, "or_greater") var Spec5_scale : float = 0.15
@export_range(0.001, 250.0, 0.001, "or_greater") var Spec5_windSpeed : float = 5
@export_range(0.0, 360.0) var Spec5_windDirection : float = 105
@export_range(0.0, 1e+08, 100.0, "exp") var Spec5_fetch : float = 1000000
@export var Spec5_spreadBlend : float = 0.2
@export var Spec5_swell : float = 1
@export var Spec5_peakEnhancement : float = 1
@export var Spec5_shortWavesFade : float = 0.5

@export_group("Spec6 uniforms")
@export_range(0.0, 5.0, 0.001, "or_greater") var Spec6_scale : float = 0.1
@export_range(0.001, 250.0, 0.001, "or_greater") var Spec6_windSpeed : float = 1
@export_range(0.0, 360.0) var Spec6_windDirection : float = 19
@export_range(0.0, 1e+08, 100.0, "exp") var Spec6_fetch : float = 10000
@export var Spec6_spreadBlend : float = 0.298
@export var Spec6_swell : float = 0.695
@export var Spec6_peakEnhancement : float = 1
@export var Spec6_shortWavesFade : float = 0.5

@export_category("Layer4")
@export_group("Spec7 uniforms")
@export_range(0.0, 5.0, 0.001, "or_greater") var Spec7_scale : float = 1
@export_range(0.001, 250.0, 0.001, "or_greater") var Spec7_windSpeed : float = 1
@export_range(0.0, 360.0) var Spec7_windDirection : float = 209
@export_range(0.0, 1e+08, 100.0, "exp") var Spec7_fetch : float = 200000
@export var Spec7_spreadBlend : float = 0.56
@export var Spec7_swell : float = 1
@export var Spec7_peakEnhancement : float = 1
@export var Spec7_shortWavesFade : float = 0.0001

@export_group("Spec8 uniforms")
@export_range(0.0, 5.0, 0.001, "or_greater") var Spec8_scale : float = 0.23
@export_range(0.001, 250.0, 0.001, "or_greater") var Spec8_windSpeed : float = 1
@export_range(0.0, 360.0) var Spec8_windDirection : float = 0
@export_range(0.0, 1e+08, 100.0, "exp") var Spec8_fetch : float = 1000
@export var Spec8_spreadBlend : float = 0
@export var Spec8_swell : float = 0
@export var Spec8_peakEnhancement : float = 1
@export var Spec8_shortWavesFade : float = 0.0001

@onready var water_mesh = $"3D/MeshInstance3D"

func _process(_delta):
	$"3D/WorldEnvironment/Sun".rotation = Vector3(sun_rotation.x, sun_rotation.y, 0.0)
	if mesh_follow_camera: water_mesh.position = Vector3($"3D/Camera".position.x, water_mesh.position.y, $"3D/Camera".position.z)
	
	if debug_spectrums or !Water.params_received:
		Water.insert_params(
			water_fps, debug_spectrums, spectrum_texture_size, spectrum_texture_mipmap_factor, spectrum_seed, depth, gravity, length_scales, low_cutoff, high_cutoff, repeat_time, time_factor, lambda, foam_bias, foam_decayRate, foam_add, foam_threshold,
			[
				Water.SpectrumParameters.new(gravity, Spec1_scale, Spec1_windSpeed, Spec1_windDirection, Spec1_fetch, Spec1_spreadBlend, Spec1_swell, Spec1_peakEnhancement, Spec1_shortWavesFade),
				Water.SpectrumParameters.new(gravity, Spec2_scale, Spec2_windSpeed, Spec2_windDirection, Spec2_fetch, Spec2_spreadBlend, Spec2_swell, Spec2_peakEnhancement, Spec2_shortWavesFade),
				Water.SpectrumParameters.new(gravity, Spec3_scale, Spec3_windSpeed, Spec3_windDirection, Spec3_fetch, Spec3_spreadBlend, Spec3_swell, Spec3_peakEnhancement, Spec3_shortWavesFade),
				Water.SpectrumParameters.new(gravity, Spec4_scale, Spec4_windSpeed, Spec4_windDirection, Spec4_fetch, Spec4_spreadBlend, Spec4_swell, Spec4_peakEnhancement, Spec4_shortWavesFade),
				Water.SpectrumParameters.new(gravity, Spec5_scale, Spec5_windSpeed, Spec5_windDirection, Spec5_fetch, Spec5_spreadBlend, Spec5_swell, Spec5_peakEnhancement, Spec5_shortWavesFade),
				Water.SpectrumParameters.new(gravity, Spec6_scale, Spec6_windSpeed, Spec6_windDirection, Spec6_fetch, Spec6_spreadBlend, Spec6_swell, Spec6_peakEnhancement, Spec6_shortWavesFade),
				Water.SpectrumParameters.new(gravity, Spec7_scale, Spec7_windSpeed, Spec7_windDirection, Spec7_fetch, Spec7_spreadBlend, Spec7_swell, Spec7_peakEnhancement, Spec7_shortWavesFade),
				Water.SpectrumParameters.new(gravity, Spec8_scale, Spec8_windSpeed, Spec8_windDirection, Spec8_fetch, Spec8_spreadBlend, Spec8_swell, Spec8_peakEnhancement, Spec8_shortWavesFade)
			]
		)
