extends CharacterBody2D

@export var speed = 150

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

	move_and_slide()
