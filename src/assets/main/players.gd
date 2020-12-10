extends YSort

signal positions_updated(last_received_input)

func _ready():
	pass # Replace with function body.
func _player_disconnected(id):
	get_parent().players[id].queue_free() #deletes player node when a player disconnects
	get_parent().players.erase(id)
	PlayerManager.players.erase(id)

func get_network_id_from_player_node_name(node_name: String) -> int:
	"""Fetch a player's network ID from the name of their KinematicBody2D."""
	var players_dict: Dictionary = PlayerManager.players
	var players_array: Array = players_dict.values()
	for index in range(len(players_array)):
		if players_array[index].name == node_name:
			return players_dict.keys()[index]
	return -1

func deletePlayers() -> void:
	for i in get_parent().players.keys():
		get_parent().players[i].queue_free()
	get_parent().players.clear()
	PlayerManager.players.clear()

func player_killed(killer_id: int, killed_player_id: int) -> void:
	"""Runs on a client; responsible for actually killing off a player."""
	var killed_player_death_handler: Node2D = get_parent().players[killed_player_id].get_node("DeathHandler")
	killed_player_death_handler.die_by(killer_id)

# Called from server when the server's players move
func update_positions(positions_dict: Dictionary, last_received_input: int) -> void:
	for id in positions_dict.keys():
		if get_parent().players.keys().has(id):
			get_parent().players[id].move_to(positions_dict[id][0], positions_dict[id][1])
			get_parent().players[id].velocity = positions_dict[id][2]
	emit_signal("positions_updated", last_received_input)

func createPlayer(id: int, playerName: String, spawnPoint: Vector2 = Vector2(0,0), player_data: Dictionary = {}) -> void:
	print("creating player ", id)
	if get_parent().players.keys().has(id):
		print("not creating player, already exists")
		return
	var newPlayer = get_parent().player_scene.instance()
	newPlayer.id = id
	newPlayer.setName(playerName)
	#newPlayer.set_network_master(id)
	if id == Network.get_my_id():
		newPlayer.main_player = true
		newPlayer.connect("main_player_moved", self, "_on_main_player_moved")
		self.connect("positions_updated", newPlayer, "_on_positions_updated")
		player_data = SaveLoadHandler.load_data(get_parent().player_data_path)
		get_parent().get_node("appearance")._apply_customizations(newPlayer, player_data)
	get_parent().players[id] = newPlayer
	$".".add_child(newPlayer)
	newPlayer.move_to(spawnPoint, Vector2(0,0))
	if get_tree().is_network_server():
		get_parent().query_player_data()
	else:
		rpc_id(1, "query_player_data")
	print("New player: ", id)
