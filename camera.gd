class_name Camera extends Camera3D

var directional_flight = true
var current_chunk_coords : Vector2i = Vector2i(0,0)

@export var sens = 0.03
@export var speed = 0.1
@export var sprint_factor = 2.0

var current_rotation = Vector3.ZERO

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	# camera movement
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var rotation_delta = event.relative * sens
		
		# clamp x rotation (up/down) to ensure it doesnt rotate more than 180 degrees
		current_rotation.x = clampf(current_rotation.x-rotation_delta.y, -PI/2, PI/2)
		
		# wrap y rotation (left/right) between 0 and 2PI since having a y rotation of -1000 is just unecessary
		current_rotation.y = wrap(current_rotation.y-rotation_delta.x, 0, 2*PI)
		
		quaternion = Quaternion.from_euler(current_rotation)
		
	
	if event.is_action_pressed("E"):
		toggle_mouse_lock()
	
	if event.is_action_pressed("V"):
		$Control/DataTextures.visible = !$Control/DataTextures.visible

func _process(delta):
	# movement
	var ws_input = Input.get_axis("W", "S")
	var ad_input = Input.get_axis("A", "D")
	var sprinting = Input.get_action_strength("Shift")
	
	var movement = basis * Vector3(ad_input, 0.0, ws_input)
	if not directional_flight:
		movement.y = 0
	
	var current_speed = speed * (sprint_factor if sprinting else 1.0)
	position += (movement.normalized() + Vector3(0,0,0)) * current_speed * delta
	
	# update coord label
	$Control/Label.text = "FPS: %s\nCoords: (%s, %s, %s)\nDirection: %s" % [
		Engine.get_frames_per_second(),
		roundf(position.x*10)/10, roundf(position.y*10)/10, roundf(position.z*10)/10,
		["S","E","N","W"][wrap(round(rad_to_deg(current_rotation.y)/90.0), 0, 4)]
		]
	


func toggle_mouse_lock():
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
