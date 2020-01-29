class_name GameManager extends Spatial

var InstanceType = NetworkManager.InstanceType
var network_manager: NetworkManager

func _ready():
	network_manager = get_parent().get_node("NetworkManager")
	network_manager.connect("network_objects_sync", self, "create_player")
	
func create_player():
	print("Creating Player...")
	network_manager.instantiate(InstanceType.Player, Vector3())
