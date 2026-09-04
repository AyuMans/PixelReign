extends Node

const PORT := 7777
const MAX_PLAYERS := 20

signal host_started
signal client_connected

signal room_changed(peer_id, new_room)
signal room_player_received(peer_id)
signal room_state_ready_signal

signal player_state_received(peer_id, new_position, new_animation)

var player_rooms := {}
var room_state_ready := false

var player_states := {}

var network_ui_open := true


func _ready():
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)

	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)


# ============================================================
# HOST
# ============================================================

func host_game():
	var peer = ENetMultiplayerPeer.new()

	var error = peer.create_server(
		PORT,
		MAX_PLAYERS
	)

	if error != OK:
		print("FAILED TO CREATE SERVER: ", error)
		return

	multiplayer.multiplayer_peer = peer

	player_rooms.clear()
	player_states.clear()

	var host_id = multiplayer.get_unique_id()

	player_rooms[host_id] = "world"

	room_state_ready = true

	print("================================")
	print("PIXELREIGN LOCAL SERVER STARTED")
	print("PORT: ", PORT)
	print("================================")

	host_started.emit()


# ============================================================
# JOIN
# ============================================================

func join_game(address: String):
	address = address.strip_edges()

	if address == "":
		print("ERROR: Empty server address.")
		return

	var host := address
	var port := PORT

	# --------------------------------------------------------
	# If the user entered host:port, split it.
	# Example:
	# cynthia-decatur.tun.ply.gg:34434
	# --------------------------------------------------------

	if address.count(":") == 1:
		var parts = address.split(":")

		if parts.size() == 2:
			host = parts[0].strip_edges()

			if parts[1].is_valid_int():
				port = int(parts[1])
			else:
				print("ERROR: Invalid port: ", parts[1])
				return

	# --------------------------------------------------------
	# Prevent invalid port numbers
	# --------------------------------------------------------

	if port < 1 or port > 65535:
		print("ERROR: Invalid port: ", port)
		return

	print("================================")
	print("CONNECTING TO PIXELREIGN SERVER")
	print("HOST: ", host)
	print("PORT: ", port)
	print("================================")

	var peer = ENetMultiplayerPeer.new()

	var error = peer.create_client(
		host,
		port
	)

	if error != OK:
		print("FAILED TO CREATE CLIENT: ", error)
		return

	player_rooms.clear()
	player_states.clear()

	room_state_ready = false

	if not multiplayer.connected_to_server.is_connected(
		_on_connected_to_server
	):
		multiplayer.connected_to_server.connect(
			_on_connected_to_server
	)

	multiplayer.multiplayer_peer = peer


# ============================================================
# CONNECTED TO SERVER
# ============================================================

func _on_connected_to_server():
	print("================================")
	print("CONNECTED TO PIXELREIGN SERVER")
	print("MY PEER ID: ", multiplayer.get_unique_id())
	print("IS SERVER: ", multiplayer.is_server())
	print("================================")

	client_connected.emit()


# ============================================================
# PEER CONNECTION
# ============================================================

func _on_peer_connected(peer_id):
	if not multiplayer.is_server():
		return

	print("NETWORK PEER CONNECTED: ", peer_id)

	player_rooms[peer_id] = "world"

	_room_changed.rpc(
		peer_id,
		"world"
	)

	call_deferred(
		"_send_room_state_to",
		peer_id
	)


# ============================================================
# PEER DISCONNECTION
# ============================================================

func _on_peer_disconnected(peer_id):
	print("NETWORK PEER DISCONNECTED: ", peer_id)

	# Only the server handles the network-wide
	# disconnect notification.

	if not multiplayer.is_server():
		return

	player_rooms.erase(peer_id)
	player_states.erase(peer_id)

	for client_id in multiplayer.get_peers():
		_player_left.rpc_id(
			client_id,
			peer_id
		)


@rpc("authority", "call_remote", "reliable")
func _player_left(peer_id: int):
	player_rooms.erase(peer_id)
	player_states.erase(peer_id)

	room_changed.emit(
		peer_id,
		"disconnected"
	)


# ============================================================
# ROOM STATE
# ============================================================

func _send_room_state_to(peer_id):
	if not multiplayer.is_server():
		return

	if not player_rooms.has(peer_id):
		return

	_receive_room_state.rpc_id(
		peer_id,
		player_rooms.duplicate()
	)


@rpc("authority", "reliable")
func _receive_room_state(rooms: Dictionary):
	player_rooms = rooms.duplicate()

	room_state_ready = true

	print(
		"ROOM STATE RECEIVED: ",
		player_rooms
	)

	room_state_ready_signal.emit()


# ============================================================
# ROOM CHANGE
# ============================================================

func set_player_room(
	peer_id: int,
	new_room: String
):
	if not multiplayer.is_server():
		return

	if not player_rooms.has(peer_id):
		return

	if new_room != "world" and new_room != "house":
		return

	if player_rooms[peer_id] == new_room:
		return

	player_rooms[peer_id] = new_room

	print(
		"PLAYER ",
		peer_id,
		" -> ",
		new_room
	)

	_room_changed.rpc(
		peer_id,
		new_room
	)


@rpc("any_peer", "reliable")
func request_room_change(
	peer_id: int,
	new_room: String
):
	if not multiplayer.is_server():
		return

	var sender_id = multiplayer.get_remote_sender_id()

	if sender_id != peer_id:
		return

	set_player_room(
		peer_id,
		new_room
	)


@rpc("authority", "call_local", "reliable")
func _room_changed(
	peer_id: int,
	new_room: String
):
	player_rooms[peer_id] = new_room

	room_changed.emit(
		peer_id,
		new_room
	)


# ============================================================
# REQUEST PLAYERS IN ROOM
# ============================================================

@rpc("any_peer", "reliable")
func request_room_players(room: String):
	if not multiplayer.is_server():
		return

	if room != "world" and room != "house":
		return

	var requester = multiplayer.get_remote_sender_id()

	for peer_id in player_rooms:

		if player_rooms[peer_id] == room:

			send_room_player.rpc_id(
				requester,
				peer_id
			)


@rpc("authority", "reliable")
func send_room_player(peer_id: int):

	room_player_received.emit(
		peer_id
	)

	if player_states.has(peer_id):

		var state = player_states[peer_id]

		player_state_received.emit(
			peer_id,
			state["position"],
			state["animation"]
		)


# ============================================================
# PLAYER MOVEMENT
# ============================================================

@rpc("any_peer", "call_remote", "unreliable")
func send_player_state(
	peer_id: int,
	new_position: Vector2,
	new_animation: String
):
	if not multiplayer.is_server():
		return

	var sender_id = multiplayer.get_remote_sender_id()

	if sender_id != peer_id:
		return

	player_states[peer_id] = {
		"position": new_position,
		"animation": new_animation
	}

	player_state_received.emit(
		peer_id,
		new_position,
		new_animation
	)

	broadcast_player_state.rpc(
		peer_id,
		new_position,
		new_animation
	)


# ============================================================
# SERVER -> CLIENTS
# ============================================================

@rpc("authority", "call_remote", "unreliable")
func broadcast_player_state(
	peer_id: int,
	new_position: Vector2,
	new_animation: String
):
	player_states[peer_id] = {
		"position": new_position,
		"animation": new_animation
	}

	player_state_received.emit(
		peer_id,
		new_position,
		new_animation
	)


# ============================================================
# HOST LOCAL STATE
# ============================================================

func receive_player_state_from_server(
	peer_id: int,
	new_position: Vector2,
	new_animation: String
):
	if not multiplayer.is_server():
		return

	player_states[peer_id] = {
		"position": new_position,
		"animation": new_animation
	}

	broadcast_player_state.rpc(
		peer_id,
		new_position,
		new_animation
	)


# ============================================================
# GET SAVED PLAYER STATE
# ============================================================

func get_player_state(peer_id: int):

	return player_states.get(
		peer_id,
		null
	)
