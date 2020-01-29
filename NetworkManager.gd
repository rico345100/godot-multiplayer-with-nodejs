class_name NetworkManager extends Spatial

signal network_connected
signal network_objects_sync

enum InstanceType {
	Player = 0,
}

enum MessageType {
	AssignID = 0,
	ClientRequestObjectSync = 10,
	ServerRequestObjectSync = 11,
	ServerRequestObjectSyncComplete = 12,
	Instantiate = 20,
	Destroy = 21,
	DestroyNetworkObjects = 22,
	SyncTransform = 30,
}

export (String) var host = '127.0.0.1'
export (int) var port = 1337

var client: StreamPeerTCP
var client_id: int
var local_id_counter: int = 0
var player_scene: PackedScene
var network_objects: Array

func _ready():
	client = StreamPeerTCP.new()
	player_scene = load("res://Player.tscn")
	network_objects = Array()
	
	var ip: String = "{host}:{port}".format({
		"host": host,
		"port": port
	})
	
	print("Try Connect : " + ip + "...")
	
	var error = client.connect_to_host(host, port)
	
	if error:
		print("Failed to Connect. Please re-start application to retry.")
		return
	
	emit_signal("network_connected")
	
	set_process(true)
	
func _process(delta):
	if client.is_connected_to_host() && client.get_available_bytes()  > 0:
		var message_type = client.get_8()
		
		match message_type:
			MessageType.AssignID:
				set_client_id()
				request_sync_network_objects()
			MessageType.ServerRequestObjectSync:
				create_network_object()
			MessageType.ServerRequestObjectSyncComplete:
				network_object_sync_complete()
			MessageType.DestroyNetworkObjects:
				destroy_network_objects()
			MessageType.Instantiate:
				do_instantiate()
			MessageType.SyncTransform:
				sync_transform()
			_:
				print("Invalid MessageType : " + str(message_type))

func send_message(message_type: int, data: StreamPeerBuffer = null):	
	if not data:
		data = StreamPeerBuffer.new()
		
	# Byte Order
	# byte message_type
	# byte[] data
	var sending_data: StreamPeerBuffer = StreamPeerBuffer.new()
	sending_data.put_8(message_type)
	sending_data.put_32(client_id)
	sending_data.put_data(data.data_array)
	
	client.put_data(sending_data.data_array)

func set_client_id():
	client_id = client.get_32()
	print("Received Client ID: " + str(client_id))
	
func request_sync_network_objects():
	print("Request Server to Sync Network Objects")
	send_message(MessageType.ClientRequestObjectSync)

func create_network_object():
	var cid: int = client.get_32()
	var local_id: int = client.get_32()
	var instance_type = client.get_8()
	var position: Vector3 = Vector3(
		client.get_float(),
		client.get_float(),
		client.get_float()
	)
	
	print("Instantiate Object: {instance_type} {client_id} {local_id}".format({
		"instance_type": str(instance_type),
		"client_id": str(cid),
		"local_id": str(local_id)
	}))

	instantiate_from_network(instance_type, cid, local_id, position)	

func network_object_sync_complete():
	print("All Network Objects synchronized.")
	emit_signal("network_objects_sync")

func destroy_network_objects():
	var cid: int = client.get_32()
	var new_network_objects: Array = Array()
	
	for i in range(network_objects.size()):
		var player_node = network_objects[i]
		
		if player_node.client_id == cid:
			network_objects[i].queue_free()
			network_objects.remove(i)
		else:
			new_network_objects.append(player_node)
			
	network_objects = new_network_objects

func do_instantiate():
	var cid: int = client.get_32()
	var local_id: int = client.get_32()
	var instance_type = client.get_8()
	var position: Vector3 = Vector3(
		client.get_float(),
		client.get_float(),
		client.get_float()
	)
	
	instantiate_from_network(instance_type, cid, local_id, position)

func sync_transform():
	var cid: int = client.get_32()
	var local_id: int = client.get_32()
	var position: Vector3 = Vector3(
		client.get_float(),
		client.get_float(),
		client.get_float()
	)
	
	for i in range(network_objects.size()):
		var network_object = network_objects[i]
		
		if network_object.client_id == cid && network_object.local_id == local_id:
			network_object.sync_transform(position)
			break

func instantiate(instance_type: int, position: Vector3) -> Spatial:
	# Byte Order
	# int local_id
	# byte instance_type
	# Vector3 position
	var sending_data: StreamPeerBuffer = StreamPeerBuffer.new()
	sending_data.put_32(local_id_counter)
	sending_data.put_8(instance_type)
	sending_data.put_float(position.x)
	sending_data.put_float(position.y)
	sending_data.put_float(position.z)
	
	print("Instantiating Object...")
	print("Assigned LocalID: " + str(local_id_counter))
	
	send_message(MessageType.Instantiate, sending_data)
	
	var instance = get_instance(instance_type)
	instance.transform.origin = position
	add_child(instance)
	
	instance.client_id = client_id
	instance.is_local = true;
	instance.local_id = local_id_counter
	instance.network_manager = self
	instance.initialize()
	
	local_id_counter += 1
	
	network_objects.append(instance)
	
	return instance

func instantiate_from_network(instance_type: int, cid: int, local_id: int, position: Vector3):
	var instance = get_instance(instance_type)
	instance.transform.origin = position
	
	instance.is_local = false;
	instance.client_id = cid
	instance.local_id = local_id

	network_objects.append(instance)

func get_instance(instance_type: int) -> Node:
	match instance_type:
		InstanceType.Player:
			return player_scene.instance()
		_:
			print("Invalid Instance Type: " + str(instance_type))
			return null;
