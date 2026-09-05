extends Node2D

const PLAYER_SCENE = preload("res://scenes/player.tscn")


func _ready():
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	if not NetworkManager.room_changed.is_connected(_on_room_changed):
		NetworkManager.room_changed.connect(_on_room_changed)

	if not NetworkManager.room_player_received.is_connected(_on_room_player_received):
		NetworkManager.room_player_received.connect(_on_room_player_received)

	if not NetworkManager.room_state_ready_signal.is_connected(_on_room_state_ready):
		NetworkManager.room_state_ready_signal.connect(
			_on_room_state_ready,
			CONNECT_ONE_SHOT
		)
	if not NetworkManager.player_state_received.is_connected(_on_player_state_received):
		NetworkManager.player_state_received.connect(_on_player_state_received)

	_spawn_local_player()

	# Server already knows everyone's room.
	if multiplayer.is_server():
		_spawn_house_players()

	# Client asks server who is inside.
	elif NetworkManager.room_state_ready:
		_request_house_players()

func _on_player_state_received(peer_id, new_position, new_animation):
	if NetworkManager.player_rooms.get(peer_id, "") != "house":
		return

	var player = get_node_or_null(
		"Player_" + str(peer_id)
	)

	if not player:
		return

	if player.is_multiplayer_authority():
		return

	player.global_position = new_position
	player.set_animation(new_animation)
# ============================================================
# ROOM STATE READY
# ============================================================

func _on_room_state_ready():
	if not multiplayer.is_server():
		_request_house_players()


# ============================================================
# SPAWN LOCAL PLAYER
# ============================================================

func _spawn_local_player():
	var local_id = multiplayer.get_unique_id()

	if has_node("Player_" + str(local_id)):
		return

	var player = PLAYER_SCENE.instantiate()

	player.name = "Player_" + str(local_id)
	player.position = Vector2(576, 500)
	player.scale = Vector2(1.5, 1.5)

	player.set_multiplayer_authority(local_id)

	add_child(player)
	player.add_to_group("players")

	var player_name = NetworkManager.player_names.get(
		local_id,
		"Player" + str(local_id)
	)

	player.set_player_name(player_name)

	print(
		"INTERIOR LOCAL PLAYER: ",
		player.name,
		" | Authority: ",
		player.get_multiplayer_authority()
	)

# ============================================================
# ASK SERVER FOR HOUSE PLAYERS
# ============================================================

func _request_house_players():
	if multiplayer.is_server():
		return

	NetworkManager.request_room_players.rpc_id(
		1,
		"house"
	)


# ============================================================
# SERVER SPAWNS HOUSE PLAYERS
# ============================================================

func _spawn_house_players():
	for peer_id in NetworkManager.player_rooms:
		if NetworkManager.player_rooms[peer_id] == "house":
			_spawn_player(peer_id)


# ============================================================
# CLIENT RECEIVES HOUSE PLAYER
# ============================================================

func _on_room_player_received(peer_id):
	if NetworkManager.player_rooms.get(peer_id, "") != "house":
		return

	_spawn_player(peer_id)


# ============================================================
# SPAWN PLAYER
# ============================================================

func _spawn_player(peer_id):
	var player_name = "Player_" + str(peer_id)

	if has_node(player_name):
		return

	var player = PLAYER_SCENE.instantiate()

	player.name = player_name
	player.position = Vector2(576, 500)
	player.scale = Vector2(1.5, 1.5)

	player.set_multiplayer_authority(peer_id)

	add_child(player)
	player.add_to_group("players")
	player_name = NetworkManager.player_names.get(
		peer_id,
		"Player" + str(peer_id)
	)

	player.set_player_name(player_name)
	var saved_state = NetworkManager.get_player_state(peer_id)

	if saved_state != null:
		player.global_position = saved_state["position"]
		player.set_animation(saved_state["animation"])
	print(
		"INTERIOR SPAWNED: ",
		player.name,
		" | Authority: ",
		player.get_multiplayer_authority()
	)


# ============================================================
# PLAYER DISCONNECT
# ============================================================

func _on_peer_disconnected(peer_id):
	var player = get_node_or_null(
		"Player_" + str(peer_id)
	)

	if player:
		player.queue_free()


# ============================================================
# ROOM CHANGED
# ============================================================

func _on_room_changed(peer_id, new_room):

	# Someone entered the house.
	if new_room == "house":

		_spawn_player(peer_id)

	# Someone left the house.
	elif new_room == "world":

		var player = get_node_or_null(
			"Player_" + str(peer_id)
		)

		if player:
			player.queue_free()

		# If it is my player, return to World.
		if peer_id == multiplayer.get_unique_id():
			_return_to_world()


# ============================================================
# EXIT HOUSE
# ============================================================

func _on_exit_door_body_entered(body):
	var local_id = multiplayer.get_unique_id()

	var local_player = get_node_or_null(
		"Player_" + str(local_id)
	)

	if body != local_player:
		return

	if multiplayer.is_server():
		NetworkManager.set_player_room(
			local_id,
			"world"
		)
	else:
		NetworkManager.request_room_change.rpc_id(
			1,
			local_id,
			"world"
		)


func _return_to_world():
	get_tree().call_deferred(
		"change_scene_to_file",
		"res://scenes/world.tscn"
	)
