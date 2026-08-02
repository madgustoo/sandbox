extends CharacterBody2D

class_name Player

@export var speed = 150
@export var jump = 150

@onready var arm: Node2D = $Arm

var rope_verlet = preload("res://rope.tscn")

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		# Gravity is acceleration, so it changes velocity rather than position directly
		# acceleration changes velocity
		# velocity changes position
		velocity += get_gravity() * delta
	
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		
	if Input.is_action_just_pressed("jump"):
		velocity.y -= jump

	if Input.is_action_just_pressed("click"):
		swing()

	# Update shooter aim
	var aim_direction = (get_global_mouse_position() - arm.global_position).normalized()
	arm.rotation = aim_direction.angle() + PI/2
	
	move_and_slide()
	
func swing() -> void:
	# Calculate distance between arm (or player center) and the hit point
	var anchor_point = get_anchor_point()
	print("Got", anchor_point)
	if anchor_point != Vector2.ZERO:
		var rope = rope_verlet.instantiate() as RopeVerlet
		rope.pin_start = true
		rope.pin_end = true
		rope.create(anchor_point, global_position)
		add_child(rope)
	
func get_anchor_point() -> Vector2:
	var distance = 1000
	var from: Vector2 = arm.global_position
	var direction: Vector2 = (get_global_mouse_position() - from).normalized()
	print("direction: ", direction)
	var to: Vector2 = from + direction * distance
	
	var space_state = get_world_2d().direct_space_state
	# If it has a hit on collision layer 1
	var query := PhysicsRayQueryParameters2D.create(from, to, 2)
	var result := space_state.intersect_ray(query)
	if not result.is_empty():
		return result.position
	
	return Vector2.ZERO
