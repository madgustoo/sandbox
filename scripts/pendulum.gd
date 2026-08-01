extends Node2D

class_name Pendulum

@export var gravity: Vector2 = Vector2(0, 9.81)
## To control swinging, the higher the number, the higher the system willl oscillate until stopping (loss of enegery)
@export var dampening: float = 0.98 
@export var end_position: Vector2 # The end of the rope

var pivot_point: Vector2 # Point the pendulum rotates around
var arm_length: float # Distance from pivoit_point to end_position

var angle # The angle from the pivot point to which direction it's pointing

var angular_velocity = 0.0
var angular_accleration = 0.0

func set_start_position(start_pos: Vector2, end_pos: Vector2):
	pivot_point = start_pos
	end_position = end_pos
	
	# The length of the pendulum rope which vector comes first in the calculation 
	# doesn't matter because we're calculating the length
	arm_length = (end_position - pivot_point).length()
	# arm_length = pivot_point.distance_to(end_position)
	
	# We subtract by PI/2 so the angle settles down in the pivot line
	# so the angle calculated here is the angle between the pivot line and the y axis
	angle = (end_position - pivot_point).angle() - PI/2
	
	# angle_to finds the angle between the two vectors
	# Longer definition: Finds the signed angle between the origin (Vector2.ZERO) to end_position and origin to pivot_point vectors
	# In Godot, the origin starts in the upper left
	# angle = end_position.angle_to(pivot_point) - PI/2
	
	angular_velocity = 0.0
	angular_accleration = 0.0

func _ready() -> void:
	set_start_position(global_position, end_position)
	
func process_velocity(delta: float) -> void:
	angular_accleration = -(gravity.y * sin(angle)) / arm_length
		
	# Integrating accleration into velocity
	angular_velocity += angular_accleration * delta
	angular_velocity *= dampening
	
	angle += angular_velocity
	
	# Position of the object at the end of the pendulum
	end_position = pivot_point + Vector2(arm_length * sin(angle), arm_length * cos(angle))
	
# To add impulse (force) to angular velocity
func add_angular_velocity(force: float) -> void:
	angular_velocity += force
	
func game_input() -> void:
	var direction = 0
	if Input.is_action_just_pressed("ui_right"):
		direction = 1
	elif Input.is_action_just_pressed("ui_left"):
		direction = -1
	add_angular_velocity(direction * 0.02)

func _draw() -> void:
	var point := end_position - pivot_point
	draw_line(Vector2.ZERO, point, Color.WHITE, 1.0, false)
	draw_circle(point, 3.0, Color.SEA_GREEN)
	
func _physics_process(delta) -> void:
	game_input()
	
	# Updates angular velocity and angular accleration here
	process_velocity(delta)
	
	queue_redraw()		
