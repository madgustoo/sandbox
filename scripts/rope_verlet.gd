extends Node2D

class_name RopeVerlet

class RopeSegment:
	var current_position: Vector2
	var last_position: Vector2
	
	func _init(pos: Vector2):
		current_position = pos # The current position of the rope segment
		last_position = pos # The last position of the (current) rope segment (not the next)
		
@onready var line_2d: Line2D = $Line2D

@export var number_of_rope_segments: int = 50 # Rope length
@export var rope_segment_length: float = 0.225 # The distance between rope segments
@export var gravity: Vector2 = Vector2(0, 2)
@export var dampening: float = 0.98 # To control swinging, the higher the number, the higher the system willl oscillate until stopping (loss of enegery)
 
@export var number_of_constraint_runs = 50; # To correct the rope, you can get stability with the rope by running 20 iterations, higher means slower but more accurate

# For collision handling
@export_flags_2d_physics var collision_mask = 1 # Where to look for collisions (detect)
@export var collision_radius = 0.1
@export var bounce_factor = 0.1
@export var collection_clamp_amount = 0.1

@export var collision_segment_interval = 2

var collision_query: PhysicsShapeQueryParameters2D

var rope_segments: Array[RopeSegment] = []
var points: PackedVector2Array

func _ready() -> void:
	var start_position := get_global_mouse_position()
	
	# Initialize rope segments
	for i in range(number_of_rope_segments):
		rope_segments.append(RopeSegment.new(start_position)) 
		start_position.y += rope_segment_length
		
	# Because it's an array, we have to set the size beforehand
	points.resize(number_of_rope_segments)
	
	# Create a collision object our rope will use
	var collision_circle = CircleShape2D.new()
	collision_circle.radius = collision_radius

	collision_query = PhysicsShapeQueryParameters2D.new()
	collision_query.shape = collision_circle
	collision_query.collision_mask = collision_mask
	collision_query.collide_with_bodies = true
	collision_query.collide_with_areas = true

func _physics_process(delta: float) -> void:
	simulate(delta)
	
	# It's not as expensive as you think because we're not dealing with all the overhead from Godot's built-in physic components
	for i in range(number_of_constraint_runs):
		apply_constraints()
		
		# For a bit of optimization, we can run it every segment interval
		if i % collision_segment_interval == 0:
			handle_collisions()
		
	draw_rope()
	queue_redraw()
	
func draw_rope() -> void:
	for i in range(number_of_rope_segments):
		points[i] = rope_segments[i].current_position
	line_2d.points = points

func simulate(delta: float) -> void:
	for i in range(number_of_rope_segments):
		var rope_segment = rope_segments[i]
		# It's that simple to get velocity, because velocity is the change of position
		var velocity = (rope_segment.current_position - rope_segment.last_position) * dampening
 
		rope_segment.last_position = rope_segment.current_position
		rope_segment.current_position += velocity
		rope_segment.current_position += gravity * delta

# Apply constraints so the rope segments stay the right distance apart
# Each time we apply a constraint, each segment adjusts based on its neighbour, so changing one affects the next one
# which affects the next one and the changes propagate down the chain. 
# One pass of the constraints is not going to fully resolve or correct the rope points to where they should be, 
# so we have to run the constraints multiple time (number_of_constraint_runs)
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
		
func handle_collisions() -> void:
	# space_state is used to query collisions
	var space_state := get_world_2d().direct_space_state

	# Skip the first rope segment
	for i in range(1, number_of_rope_segments):
		var rope_segment = rope_segments[i]
		var velocity = rope_segment.current_position - rope_segment.last_position
		
		# Position the collision query over the rope segment to check wether the segment overlaps another physic object
		collision_query.transform = Transform2D(
			0.0,
			rope_segment.current_position
		)
		
		var colliders := space_state.intersect_shape(collision_query)
		
		for result in colliders:
			var collider := result["collider"] as CollisionObject2D
			# print("Segment ", i, " collided with: ", collider)
		
			# For each collider, returns the nearest collision info intersecting the collision_query
			var nearest_collision := space_state.get_rest_info(collision_query)
					
			if nearest_collision:
				var hit_point = nearest_collision.get("point")
				# Distance between current rope segment and closest collision point from the collision_query
				var distance = (rope_segment.current_position - hit_point).length()
			
				if (distance < collision_radius):
					# The normal (direction) to push out the rope segment from the collider
					var normal = (rope_segment.current_position - hit_point).normalized() 
					if (normal == Vector2.ZERO):
						# Fallback method for this edge case where the normal is (0,0)
						# calculate the normal based on the collider's center instead
						# normal = (rope.current_position - co) 
						pass
					
					# Now we actually resolve the overlap: we push the segment out of the collider
					# How much the segment overlapped with the collider
					var depth = collision_radius - distance;
					# Move the current rope segment out of the collider
					rope_segment.current_position += normal * depth
					
		rope_segment.last_position = rope_segment.current_position - velocity
			
#func _draw() -> void:
	#for rope_segment in rope_segments:
		#draw_circle(to_local(rope_segment.current_position), collision_radius, Color.GREEN, false, 1.0)
