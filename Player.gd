extends KinematicBody

var speed = 5
var direction = Vector3()
var gravity = -9.8
var velocity = Vector3()

func _physics_process(delta):
	direction = Vector3(0, 0, 0)
	
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_action_pressed("ui_right"):
		direction.x += 1
	if Input.is_action_pressed("ui_up"):
		direction.z -= 1
	if Input.is_action_pressed("ui_down"):
		direction.z += 1
		
	direction = direction.normalized() * speed
	
	if velocity.y > 0:
		gravity = -20
	else:
		gravity = -30
		
	velocity.x = direction.x
	velocity.y += gravity * delta
	velocity.z = direction.z
	
	velocity = move_and_slide(velocity, Vector3(0, 1, 0))
	
	if is_on_floor() and Input.is_key_pressed(KEY_SPACE):
		velocity.y += 10
		
	var hit_count = get_slide_count()
	
	if hit_count > 0:
		var collision = get_slide_collision(0)
		
		if collision.collider is RigidBody:
			collision.collider.apply_impulse(collision.position, -collision.normal)
