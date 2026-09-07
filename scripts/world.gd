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

	if not NetworkManager.player_avatar_changed.is_connected(
	_on_player_avatar_changed
	):
		NetworkManager.player_avatar_changed.connect(
			_on_player_avatar_changed
		)
func _on_player_avatar_changed(
	peer_id,
	avatar_id
):

	var player = get_node_or_null(
		"Player_" + str(peer_id)
	)

	if player == null:
		return

	player.set_avatar(avatar_id)

	print(
		"WORLD: Avatar updated ",
		peer_id,
		" -> ",
		avatar_id
	)
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
	NetworkManager.request_avatar_states.rpc_id(1)


# ============================================================
# SPAWN LOCAL PLAYER
# ============================================================

func _spawn_local_player():
	if not multiplayer.has_multiplayer_peer():
		return

	var local_id = multiplayer.get_unique_id()

	if has_node("Player_" + str(local_id)):
		return

	if NetworkManager.returning_from_snow_forest:
		_spawn_player(local_id, Vector2(1000, 540))
		NetworkManager.returning_from_snow_forest = false
	else:
		_spawn_player(local_id, Vector2(576, 500))


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

func _spawn_player(peer_id, custom_position = null):

	var player_name = "Player_" + str(peer_id)

	if has_node(player_name):
		return

	var player = PLAYER_SCENE.instantiate()

	player.name = player_name

	if custom_position != null:
		player.position = custom_position
	else:
		player.position = Vector2(576,500)

	player.set_multiplayer_authority(
		peer_id
	)

	add_child(player)

	player.add_to_group("players")

	if NetworkManager.player_avatars.has(peer_id):
		player.set_avatar(
			NetworkManager.player_avatars[peer_id]
		)
	elif peer_id == multiplayer.get_unique_id():
		player.set_avatar(
			NetworkManager.selected_avatar
		)
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

	var saved_state = NetworkManager.get_player_state(peer_id)

	if saved_state != null and custom_position == null:
		player.global_position = saved_state["position"]
		player.network_target_position = saved_state["position"]
		player.network_state_initialized = true
		player.set_animation(saved_state["animation"])


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


	player.network_target_position = new_position
	player.network_state_initialized = true

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

func _on_room_changed(peer_id, new_room):
	print("WORLD ROOM CHANGED: ", peer_id, " -> ", new_room)

	if new_room == "house":
		var player = get_node_or_null("Player_" + str(peer_id))

		if player:
			player.queue_free()

		if multiplayer.has_multiplayer_peer() and peer_id == multiplayer.get_unique_id():
			print("CHANGING TO HOUSE")
			get_tree().call_deferred(
				"change_scene_to_file",
				"res://scenes/house_interior.tscn"
			)

	elif new_room == "snow_forest":
		var player = get_node_or_null("Player_" + str(peer_id))

		if player:
			player.queue_free()

		if multiplayer.has_multiplayer_peer() and peer_id == multiplayer.get_unique_id():
			print("CHANGING TO SNOW FOREST")
			get_tree().call_deferred(
				"change_scene_to_file",
				"res://scenes/snow_forest.tscn"
			)

	elif new_room == "world":
		var player = get_node_or_null("Player_" + str(peer_id))

		if player:
			player.queue_free()

		if multiplayer.has_multiplayer_peer() and peer_id == multiplayer.get_unique_id():
			if NetworkManager.returning_from_snow_forest:
				_spawn_player(peer_id, Vector2(1000, 540))
				NetworkManager.returning_from_snow_forest = false
			else:
				_spawn_player(peer_id, Vector2(576, 500))

	elif new_room == "disconnected":
		var disconnected_player = get_node_or_null(
			"Player_" + str(peer_id)
		)

		if disconnected_player:
			disconnected_player.queue_free()


func _on_snow_forest_door_body_entered(body):

	print("================================")
	print("SNOW FOREST DOOR TRIGGERED")
	print("BODY: ", body.name)
	print("================================")

	if not multiplayer.has_multiplayer_peer():
		print("NO MULTIPLAYER PEER")
		return

	if multiplayer.multiplayer_peer == null:
		print("MULTIPLAYER PEER IS NULL")
		return

	var local_id = multiplayer.get_unique_id()

	var local_player = get_node_or_null(
		"Player_" + str(local_id)
	)

	print("LOCAL ID: ", local_id)
	print("LOCAL PLAYER: ", local_player)

	if body != local_player:
		print("BODY IS NOT MY PLAYER")
		return

	print("MY PLAYER ENTERED SNOW FOREST DOOR")

	if multiplayer.is_server():

		print("SERVER: CHANGING ROOM TO SNOW_FOREST")

		NetworkManager.set_player_room(
			local_id,
			"snow_forest"
		)

	else:

		print("CLIENT: REQUESTING ROOM CHANGE")

		NetworkManager.request_room_change.rpc_id(
			1,
			local_id,
			"snow_forest"
		)
