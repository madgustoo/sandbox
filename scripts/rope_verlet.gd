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
@export var gravity: Vector2 = Vector2(0, 9.81)
@export var dampening: float = 0.98 # To control swinging, the higher the number, the higher the system willl oscillate until stopping (loss of enegery)
 
@export var number_of_constraint_runs = 50; # To correct the rope, you can get stability with the rope by running 20 iterations, higher means slower but more accurate

# For collision handling
@export_flags_2d_physics var collision_mask = 1 # Where to look for collisions (detect)
@export var collision_radius = 0.28
@export var bounce_factor = 0.1
# @export var collection_clamp_amount = 0.1

@export var collision_segment_interval = 2

## To freeze rope start point. The start point is where the rope hits
@export var pin_start: bool = true
## To freeze rope end point. The end point is the point it spawns out from
@export var pin_end: bool = false

var start_position: Vector2
var end_position: Vector2

var rope_segments: Array[RopeSegment] = []
var points: PackedVector2Array
var collision_query: PhysicsShapeQueryParameters2D

func create(start: Vector2, end: Vector2) -> void:
	start_position = start
	end_position = end
	number_of_rope_segments = get_number_of_rope_segments()
	spawn_rope()

func get_number_of_rope_segments():
	return ceili(start_position.distance_to(end_position) / rope_segment_length)

func spawn_rope() -> void:	
	rope_segments.clear()
	points.clear()
	
	print("Spawn rope at start position: ", start_position)
	print("Rope ends at end position: ", end_position)
		
	var temp_start_position = start_position
	for i in range(number_of_rope_segments):
		rope_segments.append(RopeSegment.new(temp_start_position)) 
		temp_start_position.y += rope_segment_length
					
	# Because it's a fixed array, we have to set the size beforehand
	points.resize(number_of_rope_segments)
	
	# Create a collision object our rope will use
	# Each point of our rope will have a collider
	var collision_circle = CircleShape2D.new()
	collision_circle.radius = collision_radius

	collision_query = PhysicsShapeQueryParameters2D.new()
	collision_query.shape = collision_circle
	collision_query.collision_mask = collision_mask
	collision_query.collide_with_bodies = true
	collision_query.collide_with_areas = true

func _physics_process(delta: float) -> void:
	if rope_segments.is_empty():
		return
		
	simulate(delta)
	
	# It's not as expensive as you think because we're not dealing with all the overhead from Godot's built-in physic components
	for i in range(number_of_constraint_runs):
		apply_constraints()
		# For a bit of optimization, we can run it every segment interval
		if i % collision_segment_interval == 0:
			handle_collisions()
		
	draw_rope()
	# queue_redraw()
	
func draw_rope() -> void:
	# Update points position in the PackedVector2Array
	for i in range(number_of_rope_segments):
		points[i] = rope_segments[i].current_position
	line_2d.points = points

func simulate(delta: float) -> void:
	for i in range(number_of_rope_segments):
		# Run the simulation for all points EXCEPT the first and last one if they are pinned
		if (i == 0 && pin_start) || (i == number_of_rope_segments - 1 && pin_end) || (i == number_of_rope_segments - 1 && pin_end):
			continue

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
func apply_constraints() -> void:
	# Keep first point attached to start_position if pin_start is true
	if pin_start:
		rope_segments[0].current_position = start_position
		
	# Keep last point attached to end_position if pin_end is true
	if pin_end:
		rope_segments[number_of_rope_segments - 1].current_position = end_position
		
	for i in range(number_of_rope_segments):
		# Because we're going to be looking one step ahead, skips the last point because last point doesn't have a next
		if i == number_of_rope_segments - 1:
			return
			
		var current_segment = rope_segments[i]
		var next_segment = rope_segments[i + 1]
		
		# var distance = current_segment.current_position.distance_to(next_segment.current_position)
		var distance = (current_segment.current_position - next_segment.current_position).length()

		# This is the difference our constraint fixes, because each point needs to be a certain distance apart
		# So the verlet integration constraint comes and fixes this (assures we keep same distance between all points)
		var difference = distance - rope_segment_length
		
		# if the difference is greater than 0, then the rope is too stretched out
		# if the difference is less than 0, the rope is too compact
		
		var change_direction = (current_segment.current_position - next_segment.current_position).normalized()
		var change_vector = change_direction * difference
		
		if i == 0 && pin_start:
			# For first point, the next segment takes the full correction if the first point is pinned, we don't split the correction
			next_segment.current_position += change_vector
		elif i + 1 == number_of_rope_segments - 1 && pin_end:
			# We check one step ahead here to check the last point, the full correction is applied to the last point if it's pinned
			current_segment.current_position -= change_vector
		else:
			# We split the correction between the two segments we're comparing
			# Substract the current segment by half of our change vector, and add the 
			# half to the next segment which makes up the full correction amount
			current_segment.current_position -= change_vector * 0.5
			next_segment.current_position += change_vector * 0.5
		
func handle_collisions() -> void:
	# space_state is used to query collisions
	var space_state := get_world_2d().direct_space_state

	# Skip the first rope segment
	for i in range(1, number_of_rope_segments):
		var rope_segment = rope_segments[i]
		var velocity = rope_segment.current_position - rope_segment.last_position

		# Position the collision query over the rope segment to check whether the segment overlaps another physics object
		collision_query.transform = Transform2D(
			0.0,
			rope_segment.current_position
		)

		# Returns the nearest collision information intersecting the collision query
		var nearest_collision := space_state.get_rest_info(collision_query)

		if nearest_collision.is_empty():
			continue

		var hit_point: Vector2 = nearest_collision["point"]
		var normal: Vector2 = nearest_collision["normal"]
		var collider := instance_from_id(
			nearest_collision["collider_id"]
		) as CollisionObject2D

		# Distance between the current rope segment and the closest collision point
		var distance = (
			rope_segment.current_position - hit_point
		).length()

		# Here, we detect if an overlap happened to push back the rope_segment's collider away from the collision object
		if distance < collision_radius:
			# The normal is the direction used to push the rope segment out of the collider
			
			# Edge case where the normal is 0
			if normal.is_zero_approx():
				pass
				# Fallback method for this edge case where the normal is (0, 0)
				# Calculate the normal based on the collider's center instead
				normal = (
					rope_segment.current_position -
					collider.global_position
				).normalized()

			# Now we actually resolve the overlap: push the segment out of the collider
			# How much the segment overlapped with the collider
			var depth = collision_radius - distance

			# Move the current rope segment out of the collider
			rope_segment.current_position += normal * depth

			# Add a bounce / acts more like a stickiness variable
			# The higher the bounce_factor, the more slippery the rope appears
			# The lower the bounce_factor, the more it appears to stick
			velocity = velocity.bounce(normal) * bounce_factor

		rope_segment.last_position = (
			rope_segment.current_position - velocity
		)

# func _draw() -> void:
	# for rope_segment in rope_segments:
		# draw_circle(to_local(rope_segment.current_position), collision_radius, Color.GREEN, false, collision_radius)
