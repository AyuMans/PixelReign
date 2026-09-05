extends Node2D

const PLAYER_SCENE = preload("res://scenes/player.tscn")


func _ready():

	# ========================================================
	# MULTIPLAYER SIGNALS
	# ========================================================

	if not multiplayer.peer_disconnected.is_connected(
		_on_peer_disconnected
	):
		multiplayer.peer_disconnected.connect(
			_on_peer_disconnected
	)


	# ========================================================
	# NETWORK MANAGER SIGNALS
	# ========================================================

	if not NetworkManager.host_started.is_connected(
		_on_host_started
	):
		NetworkManager.host_started.connect(
			_on_host_started
	)


	if not NetworkManager.client_connected.is_connected(
		_on_client_connected
	):
		NetworkManager.client_connected.connect(
			_on_client_connected
	)


	if not NetworkManager.room_changed.is_connected(
		_on_room_changed
	):
		NetworkManager.room_changed.connect(
			_on_room_changed
	)


	if not NetworkManager.room_player_received.is_connected(
		_on_room_player_received
	):
		NetworkManager.room_player_received.connect(
			_on_room_player_received
	)


	if not NetworkManager.player_state_received.is_connected(
		_on_player_state_received
	):
		NetworkManager.player_state_received.connect(
			_on_player_state_received
	)


	# ========================================================
	# IF NETWORK IS ALREADY ACTIVE
	# ========================================================

	if multiplayer.has_multiplayer_peer():

		# HOST
		if multiplayer.is_server():

			_spawn_world_players()


		# CLIENT
		else:

			var peer = multiplayer.multiplayer_peer

			if peer != null:

				if peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:

					_spawn_local_player()

					_request_world_players()
	if not NetworkManager.player_name_changed.is_connected(_on_player_name_changed):

		NetworkManager.player_name_changed.connect(_on_player_name_changed)


# ============================================================
# HOST STARTED
# ============================================================
func _on_player_name_changed(
	peer_id,
	player_name
):
	var player = get_node_or_null(
		"Player_" + str(peer_id)
	)

	if player == null:
		return

	player.set_player_name(
		player_name
	)

	print(
		"WORLD: Updated name for ",
		peer_id,
		" -> ",
		player_name
	)
func _on_host_started():

	if not multiplayer.is_server():
		return

	print("WORLD: Host started")

	_spawn_world_players()


# ============================================================
# CLIENT CONNECTED
# ============================================================

func _on_client_connected():

	print("WORLD: Client connected")

	_spawn_local_player()

	await get_tree().process_frame

	if not multiplayer.has_multiplayer_peer():
		return

	if multiplayer.multiplayer_peer == null:
		return

	var peer = multiplayer.multiplayer_peer

	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return

	_request_world_players()


# ============================================================
# SPAWN LOCAL PLAYER
# ============================================================

func _spawn_local_player():

	if not multiplayer.has_multiplayer_peer():
		return

	var local_id = multiplayer.get_unique_id()

	if has_node(
		"Player_" + str(local_id)
	):
		return

	print(
		"WORLD: Spawning local player ",
		local_id
	)

	_spawn_player(local_id)


# ============================================================
# SPAWN ALL WORLD PLAYERS
# ============================================================

func _spawn_world_players():

	print("WORLD: Spawning world players")

	for peer_id in NetworkManager.player_rooms:

		if NetworkManager.player_rooms[peer_id] == "world":

			_spawn_player(peer_id)


# ============================================================
# ASK SERVER FOR WORLD PLAYERS
# ============================================================

func _request_world_players():

	if not multiplayer.has_multiplayer_peer():
		return

	if multiplayer.multiplayer_peer == null:
		return

	if multiplayer.is_server():
		return

	var peer = multiplayer.multiplayer_peer

	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return

	print("WORLD: Requesting world players")

	NetworkManager.request_room_players.rpc_id(
		1,
		"world"
	)


# ============================================================
# RECEIVE PLAYER FROM SERVER
# ============================================================

func _on_room_player_received(peer_id):

	print(
		"WORLD: Received player ",
		peer_id
	)

	# The server already filtered this request to the
	# requested room, so we can safely spawn the player.

	if NetworkManager.player_rooms.get(
		peer_id,
		"world"
	) != "world":

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

	player.position = Vector2(
		576,
		500
	)

	player.set_multiplayer_authority(
		peer_id
	)

	add_child(player)

	player.add_to_group("players")
	var display_name = NetworkManager.player_names.get(
	peer_id,
	"Player" + str(peer_id)
	)

	# For our own player, we already know the name
	# the user entered.
	if peer_id == multiplayer.get_unique_id():
		if NetworkManager.pending_player_name != "":
			display_name = NetworkManager.pending_player_name

	player.set_player_name(display_name)

	# ========================================================
	# APPLY SAVED NETWORK STATE
	# ========================================================

	var saved_state = NetworkManager.get_player_state(
		peer_id
	)

	if saved_state != null:

		player.global_position = saved_state["position"]

		player.set_animation(
			saved_state["animation"]
		)


	print(
		"SPAWNED: ",
		player.name,
		" | My ID: ",
		multiplayer.get_unique_id(),
		" | Authority: ",
		player.get_multiplayer_authority(),
		" | Physics: ",
		player.is_physics_processing()
	)


# ============================================================
# PLAYER STATE RECEIVED
# ============================================================

func _on_player_state_received(
	peer_id,
	new_position,
	new_animation
):

	# Ignore players who aren't currently in this room.

	if NetworkManager.player_rooms.get(
		peer_id,
		""
	) != "world":

		return


	var player = get_node_or_null(
		"Player_" + str(peer_id)
	)


	# Player hasn't spawned yet.
	# Spawn it first.

	if player == null:

		_spawn_player(peer_id)

		player = get_node_or_null(
			"Player_" + str(peer_id)
		)

		if player == null:
			return


	# Never overwrite our own movement.

	if player.is_multiplayer_authority():
		return


	player.global_position = new_position

	player.set_animation(
		new_animation
	)


# ============================================================
# PLAYER DISCONNECTED
# ============================================================

func _on_peer_disconnected(peer_id):

	print(
		"WORLD: Player disconnected ",
		peer_id
	)

	var player = get_node_or_null(
		"Player_" + str(peer_id)
	)

	if player:

		player.queue_free()


# ============================================================
# ENTER HOUSE
# ============================================================

func _on_door_body_entered(body):

	if not multiplayer.has_multiplayer_peer():
		return

	if multiplayer.multiplayer_peer == null:
		return

	var local_id = multiplayer.get_unique_id()

	var local_player = get_node_or_null(
		"Player_" + str(local_id)
	)

	if body != local_player:
		return


	# ========================================================
	# HOST
	# ========================================================

	if multiplayer.is_server():

		NetworkManager.set_player_room(
			local_id,
			"house"
		)


	# ========================================================
	# CLIENT
	# ========================================================

	else:

		NetworkManager.request_room_change.rpc_id(
			1,
			local_id,
			"house"
		)


# ============================================================
# ROOM CHANGED
# ============================================================

func _on_room_changed(
	peer_id,
	new_room
):

	# ========================================================
	# PLAYER ENTERED HOUSE
	# ========================================================

	if new_room == "house":

		var player = get_node_or_null(
			"Player_" + str(peer_id)
		)

		if player:

			player.queue_free()


		# This is MY player.
		# Change to house scene.

		if (
			multiplayer.has_multiplayer_peer()
			and peer_id == multiplayer.get_unique_id()
		):

			get_tree().call_deferred(
				"change_scene_to_file",
				"res://scenes/house_interior.tscn"
			)


	# ========================================================
	# PLAYER RETURNED TO WORLD
	# ========================================================

	elif new_room == "world":

		_spawn_player(peer_id)


	# ========================================================
	# PLAYER DISCONNECTED
	# ========================================================

	elif new_room == "disconnected":

		var disconnected_player = get_node_or_null(
			"Player_" + str(peer_id)
		)

		if disconnected_player:

			disconnected_player.queue_free()
