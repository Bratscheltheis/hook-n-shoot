extends CharacterBody3D

#various vars

var current_speed = 5.0
var lerp_speed = 10.0
var air_lerp_speed = 3.0
var direction = Vector3.ZERO
var crouching_depth = -0.5
var free_look_tilt_ammount = 8
var last_velocity = Vector3.ZERO

#slide vars

var slide_timer = 0.0
var slide_timer_max = 1.0
var slide_vector = Vector2.ZERO
var slide_speed = 10.0

#head bobbing vars

const head_bobbing_sprinting_speed = 22.0
const head_bobbing_walking_speed = 14.0
const head_bobbing_crouching_speed = 10.0

const head_bobbing_sprinting_intensity = 0.2
const head_bobbing_walking_intensity = 0.1
const head_bobbing_crouching_intensity = 0.05

var head_bobbing_vector = Vector2.ZERO
var head_bobbing_index = 0.0
var head_bobbing_current_intensity = 0.0


#states

var walking = false
var sprinting = false
var crouching = false
var free_looking = false
var sliding = false

#Player nodes

@onready var head = $Neck/head
@onready var neck = $Neck
@onready var eyes = $Neck/head/eyes
@onready var camera_3d = $Neck/head/eyes/Camera3D
@onready var animation_player = $Neck/head/eyes/AnimationPlayer


@onready var stand_collision = $stand_collision
@onready var crouch_collision = $crouch_collision
@onready var ray_cast_3d = $RayCast3D


@export var walking_speed = 5.0
@export var sprinting_speed = 8.0
@export var crouching_speed = 3.0

const JUMP_VELOCITY = 5.5
const MOUSE_SENS = 0.4

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")




func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event):
	if event is InputEventMouse:
		if free_looking:
			neck.rotate_y(deg_to_rad(-event.relative.x * MOUSE_SENS))
			neck.rotation.y = clamp(neck.rotation.y, deg_to_rad(-120), deg_to_rad(120))
		else:
			rotate_y(deg_to_rad(-event.relative.x * MOUSE_SENS))
		head.rotate_x(deg_to_rad(-event.relative.y * MOUSE_SENS))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))


func _physics_process(delta):
	#getting movement input
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	
	#handle movement state
	
	#crouching
	
	if Input.is_action_pressed("crouch") || sliding:
		current_speed = lerp(current_speed,crouching_speed, delta*lerp_speed)
		head.position.y = lerp(head.position.y, crouching_depth, delta*lerp_speed)
		stand_collision.disabled = true
		crouch_collision.disabled = false
		
		#slide begin logic
		
		if sprinting && input_dir != Vector2.ZERO:
			sliding = true
			slide_timer = slide_timer_max
			slide_vector = input_dir
			free_looking = true
		
		walking = false
		sprinting = false
		crouching = true
		
		
	#stand
		
	elif !ray_cast_3d.is_colliding():
		stand_collision.disabled = false
		crouch_collision.disabled = true
		head.position.y = lerp(head.position.y, 0.0, delta*lerp_speed)
		
		#sprint
		
		if Input.is_action_pressed("sprint") && !ray_cast_3d.is_colliding():
			current_speed = lerp(current_speed,sprinting_speed, delta*lerp_speed)
			
			walking = false
			sprinting = true
			crouching = false
			
		#walk
			
		else:
			current_speed = lerp(current_speed,walking_speed, delta*lerp_speed)
			
			walking = true
			sprinting = false
			crouching = false
			
	#handle free_looking
	if Input.is_action_pressed("free_look") || sliding:
		free_looking = true
		
		if sliding:
			eyes.rotation.z = lerp(eyes.rotation.z,deg_to_rad(7.0), delta*lerp_speed)
		else:
			eyes.rotation.z = -deg_to_rad(neck.rotation.y*free_look_tilt_ammount)
		
	else:
		free_looking = false
		neck.rotation.y = lerp(neck.rotation.y, 0.0, delta*lerp_speed)
		eyes.rotation.z = lerp(eyes.rotation.z, 0.0, delta*lerp_speed)
	
	#handle sliding
	if sliding:
		slide_timer -= delta
		if slide_timer <= 0:
			sliding = false
			free_looking = false
			
	#handle bobbing
	
	if sprinting:
		head_bobbing_current_intensity = head_bobbing_sprinting_intensity
		head_bobbing_index += head_bobbing_sprinting_speed*delta
	elif walking:
		head_bobbing_current_intensity = head_bobbing_walking_intensity
		head_bobbing_index += head_bobbing_walking_speed*delta
	elif crouching:
		head_bobbing_current_intensity = head_bobbing_crouching_intensity
		head_bobbing_index += head_bobbing_crouching_speed*delta
	
	if is_on_floor() && !sliding && input_dir != Vector2.ZERO:
		head_bobbing_vector.y = sin(head_bobbing_index)
		head_bobbing_vector.x = sin(head_bobbing_index/2) +0.5
		eyes.position.y = lerp(eyes.position.y,head_bobbing_vector.y*(head_bobbing_current_intensity/2.0), delta* lerp_speed)
		eyes.position.x = lerp(eyes.position.x,head_bobbing_vector.x*head_bobbing_current_intensity, delta* lerp_speed)
	else:
		eyes.position.y = lerp(eyes.position.y, 0.0, delta*lerp_speed)
		eyes.position.x = lerp(eyes.position.x, 0.0, delta* lerp_speed)
		
		
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		sliding = false
		animation_player.play("jump")
		
	#handle landing
	if is_on_floor()&& last_velocity.y < -4.0:
		animation_player.play("landing")

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	if is_on_floor():
		direction = lerp(direction,(transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta*lerp_speed)
	else:
		if input_dir != Vector2.ZERO:
			direction = lerp(direction,(transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta*air_lerp_speed)
		
	if sliding:
		direction = transform.basis * Vector3(slide_vector.x, 0, slide_vector.y).normalized()
		current_speed = (slide_timer +0.1) *slide_speed
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		

	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
		
	last_velocity = velocity

	move_and_slide()
	
	
