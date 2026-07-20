extends Node2D

class_name RopeVerlet

class RopeSegment:
	var current_position: Vector2
	var last_positon: Vector2
	
	func _init(pos: Vector2):
		current_position = pos
		last_positon = pos
		
@onready var line_2d: Line2D = $Line2D

@export var number_of_rope_segments: int = 50 # Rope length
@export var rope_segment_length: float = 0.225 # The distance between rope segments
@export var gravity: Vector2 = Vector2(0, 2)
@export var dampening: float = 0.98 # To control swinging

@export var number_of_constraint_runs = 50;

var rope_segments: Array[RopeSegment] = []
var points: PackedVector2Array

func _ready() -> void:
	var start_position := get_global_mouse_position()
	
	# Initialize rope segments
	for i in range(number_of_rope_segments):
		rope_segments.append(RopeSegment.new(start_position)) 
		start_position.y += rope_segment_length
		
	points.resize(number_of_rope_segments)

func _process(delta: float) -> void:
	draw_rope()
	
func draw_rope() -> void:
	for i in range(number_of_rope_segments):
		points[i] = rope_segments[i].current_position
	line_2d.points = points

func simulate(delta: float) -> void:
	for i in range(number_of_rope_segments):
		var rope_segment = rope_segments[i]
		var velocity = (rope_segment.current_position - rope_segment.last_positon) * dampening
 
		rope_segment.last_positon = rope_segment.current_position
		rope_segment.current_position += velocity
		rope_segment.current_position += gravity * delta

# Apply constraints so the rope segments stay the right distance apart
func apply_constraints():
	# Keep first point attached to the mouse
	var first_rope_segment = rope_segments[0]
	first_rope_segment.current_position = get_global_mouse_position()
	
	# (len - 1) because we're going to be looking one step ahead
	for i in range(len(rope_segments) - 1):
		var current_segment = rope_segments[i]
		var next_segment = rope_segments[i+1]
		
		# TODO Check if it gives the same distance if you substract from next_segment
		var distance = (current_segment.current_position - next_segment.current_position).length()

func _draw() -> void:
	draw_polyline(points, Color.BROWN)
