extends CharacterBody2D

class_name Player

@export var speed = 150
@export var jump = 200

## Rope connect distance
@export var distance = 1000

@onready var arm: Node2D = $Arm
@onready var crossair: Node2D = $Arm/Crossair

# Where projectiles spawn out from
@onready var shooter: Marker2D = $Arm/Crossair/Shooter
@onready var sprite_2d: Sprite2D = $Arm/Crossair/Sprite2D

var rope_verlet = preload("res://rope.tscn")

# The player's rope
var rope: RopeVerlet

enum State {
	NORMAL,
	JUMPING,
	SWINGING
}

var state = State.NORMAL

# The radius of the circular arm range around the player. The shooter can move freely inside that range
var radius = 0.0

func _ready() -> void:
	radius = arm.global_position.distance_to(shooter.global_position)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		# Gravity is acceleration, so it changes velocity rather than position directly
		# acceleration changes velocity
		# velocity changes position
		velocity += get_gravity() * delta
	
	match state:
		State.NORMAL:
			var direction := Input.get_axis("ui_left", "ui_right")
			if direction:
				velocity.x = direction * speed
			else:
				velocity.x = move_toward(velocity.x, 0, speed)
			if Input.is_action_just_pressed("jump"):
				state = State.JUMPING
				velocity.y -= jump
		State.JUMPING:
			if is_on_floor():
				state = State.NORMAL
		State.SWINGING:
			velocity.x = 0
			pass
	
	if Input.is_action_just_pressed("click") || Input.is_action_just_released("click"):
		try_swing()
	
	# Hold rope
	if Input.is_action_pressed("click"):
		if rope:
			rope.set_end_position(shooter.global_position)
			
	# Update shooter aim
	var aim_direction = (get_global_mouse_position() - arm.global_position).normalized()
	arm.rotation = aim_direction.angle() + PI/2
		
	if get_global_mouse_position().distance_to(arm.global_position) < radius:
		# Can move freely, so at this range, the shooter now has the same global position as the cursor
		shooter.global_position = get_global_mouse_position()
		sprite_2d.global_position = get_global_mouse_position()
	#else:
		#crossair.global_position = Vector2(radius * cos(angle), radius * sin(angle))
	
	move_and_slide()
	
	
func try_swing() -> void:
	if rope == null:
		state = State.SWINGING
		swing()
	else:
		# Rope was released
		rope.queue_free()
		state = State.NORMAL
		rope = null
	
func swing() -> void:
	# Calculate distance between arm (or player center) and the hit point
	var anchor_point = get_anchor_point()
	if anchor_point != Vector2.ZERO:
		rope = rope_verlet.instantiate() as RopeVerlet
		rope.pin_start = true
		rope.pin_end = true
		rope._try_spawn(anchor_point, shooter.global_position)
		get_parent().add_child(rope)
	
func get_anchor_point() -> Vector2:
	var from: Vector2 = shooter.global_position
	var direction: Vector2 = (get_global_mouse_position() - from).normalized()
	var to: Vector2 = from + (direction * distance)
	var space_state = get_world_2d().direct_space_state
	# If it has a hit on collision layer 1
	var query := PhysicsRayQueryParameters2D.create(from, to, 2)
	var result := space_state.intersect_ray(query)
	if not result.is_empty():
		return result.position
	
	return Vector2.ZERO
