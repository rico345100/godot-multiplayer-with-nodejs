extends KinematicBody

var MessageType = NetworkManager.MessageType

var speed = 5
var direction = Vector3()
var gravity = -9.8
var velocity = Vector3()
var sync_position = Vector3()

# Values that initialize from NetworkManager
var client_id: int
var is_local: bool
var local_id: int
var network_manager: NetworkManager

# Other network related
export (float) var sync_rate = 0.1

func initialize():
	if not is_local:
		return
	
	sync_rate = min(sync_rate, 0.1) # 0.1s is minimal value
	
	var timer: Timer = Timer.new()
	timer.set_wait_time(sync_rate)
	timer.connect("timeout", self, "broadcast_vars")
	add_child(timer)
	timer.start()
	
func _process(delta):
	if not is_local:
		transform.origin.linear_interpolate(sync_position, delta)

func _physics_process(delta):
	if not is_local:
		return
		
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

func broadcast_vars():
	var sending_data: StreamPeerBuffer = StreamPeerBuffer.new()
	sending_data.put_32(local_id)
	sending_data.put_float(transform.origin.x)
	sending_data.put_float(transform.origin.y)
	sending_data.put_float(transform.origin.z)
	
	network_manager.send_message(MessageType.SyncTransform, sending_data)

# NetworkManager will invoke this.
func sync_transform(position: Vector3):
	sync_position = position
