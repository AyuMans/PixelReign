extends Node2D

const PLAYER_SCENE = preload("res://scenes/player.tscn")

const SPAWN_POSITION := Vector2(140, 540)


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

	if not NetworkManager.player_avatar_changed.is_connected(_on_player_avatar_changed):
		NetworkManager.player_avatar_changed.connect(_on_player_avatar_changed)

	if not NetworkManager.player_name_changed.is_connected(_on_player_name_changed):
		NetworkManager.player_name_changed.connect(_on_player_name_changed)


	_spawn_local_player()


	if multiplayer.is_server():

		_spawn_snow_forest_players()

	elif NetworkManager.room_state_ready:

		_request_snow_forest_players()

		NetworkManager.request_avatar_states.rpc_id(1)


func _spawn_local_player():

	var local_id = multiplayer.get_unique_id()

	if has_node("Player_" + str(local_id)):
		return

	_spawn_player(local_id)


func _spawn_snow_forest_players():

	for peer_id in NetworkManager.player_rooms:

		if NetworkManager.player_rooms[peer_id] == "snow_forest":
			_spawn_player(peer_id)


func _request_snow_forest_players():

	if multiplayer.is_server():
		return

	NetworkManager.request_room_players.rpc_id(
		1,
		"snow_forest"
	)


func _on_room_state_ready():

	if not multiplayer.is_server():
		_request_snow_forest_players()


func _on_room_player_received(peer_id):

	if NetworkManager.player_rooms.get(peer_id, "") != "snow_forest":
		return

	_spawn_player(peer_id)


func _spawn_player(peer_id):

	var player_name = "Player_" + str(peer_id)

	if has_node(player_name):
		return

	var player = PLAYER_SCENE.instantiate()

	player.name = player_name

	player.position = SPAWN_POSITION

	player.set_multiplayer_authority(peer_id)

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

	if peer_id == multiplayer.get_unique_id():

		if NetworkManager.pending_player_name != "":
			display_name = NetworkManager.pending_player_name

	player.set_player_name(display_name)


	

	print(
		"SNOW FOREST PLAYER SPAWNED: ",
		peer_id
	)


func _on_player_state_received(
	peer_id,
	new_position,
	new_animation
):

	if NetworkManager.player_rooms.get(
		peer_id,
		""
	) != "snow_forest":
		return

	var player = get_node_or_null(
		"Player_" + str(peer_id)
	)

	if player == null:

		_spawn_player(peer_id)

		player = get_node_or_null(
			"Player_" + str(peer_id)
		)

		if player == null:
			return


	if player.is_multiplayer_authority():
		return

	player.global_position = new_position

	player.set_animation(new_animation)


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


func _on_player_name_changed(
	peer_id,
	player_name
):

	var player = get_node_or_null(
		"Player_" + str(peer_id)
	)

	if player == null:
		return

	player.set_player_name(player_name)


func _on_peer_disconnected(peer_id):

	var player = get_node_or_null(
		"Player_" + str(peer_id)
	)

	if player:
		player.queue_free()


func _on_exit_door_body_entered(body):

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


func _on_room_changed(
	peer_id,
	new_room
):

	if new_room == "snow_forest":

		if peer_id == multiplayer.get_unique_id():

			var old_player = get_node_or_null(
				"Player_" + str(peer_id)
			)

			if old_player:
				old_player.queue_free()

			get_tree().call_deferred(
				"change_scene_to_file",
				"res://scenes/snow_forest.tscn"
			)

		else:

			_spawn_player(peer_id)


	elif new_room == "world":
		var player = get_node_or_null("Player_" + str(peer_id))

		if player:
			player.queue_free()

		if multiplayer.has_multiplayer_peer() and peer_id == multiplayer.get_unique_id():
			NetworkManager.returning_from_snow_forest = true

			get_tree().call_deferred(
				"change_scene_to_file",
				"res://scenes/world.tscn"
			)
