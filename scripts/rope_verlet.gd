extends Node2D

class_name RopeVerlet

class RopeSegment:
	var current_position: Vector2
	var last_position: Vector2
	
	func _init(pos: Vector2):
		current_position = pos
		last_position = pos
		
@onready var line_2d: Line2D = $Line2D

@export var number_of_rope_segments: int = 50 # Rope length
@export var rope_segment_length: float = 0.225 # The distance between rope segments
@export var gravity: Vector2 = Vector2(0, 2)
@export var dampening: float = 0.98 # To control swinging, the higher the number, the higher the system willl oscillate until stopping (loss of enegery)

@export var number_of_constraint_runs = 50; # To correct the rope, you can get stability with the rope by running 20 iterations, higher means slower but more accurate

var rope_segments: Array[RopeSegment] = []
var points: PackedVector2Array

func _ready() -> void:
	var start_position := get_global_mouse_position()
	
	# Initialize rope segments
	for i in range(number_of_rope_segments):
		rope_segments.append(RopeSegment.new(start_position)) 
		start_position.y += rope_segment_length
		
	points.resize(number_of_rope_segments)

func _physics_process(delta: float) -> void:
	simulate(delta)
	
	# It's not as expensive as you think because we're not dealing with all the overhead from Godot's built-in physic components
	for i in range(number_of_constraint_runs):
		apply_constraints()
		
	draw_rope()
	
func draw_rope() -> void:
	for i in range(number_of_rope_segments):
		points[i] = rope_segments[i].current_position
	line_2d.points = points

func simulate(delta: float) -> void:
	for i in range(number_of_rope_segments):
		var rope_segment = rope_segments[i]
		var velocity = (rope_segment.current_position - rope_segment.last_position) * dampening
 
		rope_segment.last_position = rope_segment.current_position
		rope_segment.current_position += velocity
		rope_segment.current_position += gravity * delta

# Apply constraints so the rope segments stay the right distance apart
# Each time we apply a constraint, each segment adjusts based on its neighbour, so changing one affects the next one
# which affects the next one and the changes propagate down the chain. 
# One pass of the constraints is not going to fully resolve or correct the rope points to where they should be, 
# so we have to run the constraints multiple time
func apply_constraints():
	# Keep first point attached to the mouse
	var first_rope_segment = rope_segments[0]
	first_rope_segment.current_position = get_global_mouse_position()
	
	# (len - 1) because we're going to be looking one step ahead
	for i in range(len(rope_segments) - 1):
		var current_segment = rope_segments[i]
		var next_segment = rope_segments[i+1]
		
		var distance = (current_segment.current_position - next_segment.current_position).length()
		var difference = distance - rope_segment_length
		
		# if the difference is greater than 0, then the rope is too stretched out
		# if the difference is less than 0, the rope is too compact
		
		var change_direction = (current_segment.current_position - next_segment.current_position).normalized()
		var change_vector = change_direction * difference
		
		if (i != 0):
			# We split the correction between the two segments we're comparing
			# Substract the current segment by half of our change vector, and add the 
			# half to the next segment which makes up the full correction amount
			current_segment.current_position -= change_vector * 0.5
			next_segment.current_position += change_vector * 0.5
		else:
			# First point we don't split the correction, we apply the full correction to the next segment
			next_segment.current_position += change_vector
		
			rope_segments[i] = current_segment
			rope_segments[i+1] = next_segment
		
