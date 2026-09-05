extends Node

const PORT := 7777
const MAX_PLAYERS := 20
const MAX_CHAT_MESSAGES := 50

signal host_started
signal client_connected

signal room_changed(peer_id, new_room)
signal room_player_received(peer_id)
signal room_state_ready_signal

signal player_state_received(peer_id, new_position, new_animation)

signal player_name_ready
signal player_name_changed(peer_id, player_name)

signal chat_message_received(peer_id, player_name, message)
signal chat_history_received(messages)

var player_rooms := {}
var room_state_ready := false

var player_states := {}
var player_names := {}

var pending_player_name := ""

var network_ui_open := true

var is_connecting := false
var is_connected := false

var chat_logs := {
	"world": [],
	"house": []
}


func set_player_name(peer_id: int, player_name: String):

	if not multiplayer.is_server():
		return

	player_name = player_name.strip_edges()

	if player_name == "":
		player_name = "Player" + str(peer_id)

	if player_name.length() > 16:
		player_name = player_name.left(16)

	player_names[peer_id] = player_name

	_player_name_changed.rpc(
		peer_id,
		player_name
	)


func _ready():

	if not multiplayer.peer_connected.is_connected(
		_on_peer_connected
	):
		multiplayer.peer_connected.connect(
			_on_peer_connected
		)

	if not multiplayer.peer_disconnected.is_connected(
		_on_peer_disconnected
	):
		multiplayer.peer_disconnected.connect(
			_on_peer_disconnected
	)


# ============================================================
# HOST
# ============================================================

func host_game(player_name: String):

	if is_connecting:
		print("HOST IGNORED: Currently connecting.")
		return

	if is_connected:
		print("HOST IGNORED: Already connected.")
		return

	var peer = ENetMultiplayerPeer.new()

	var error = peer.create_server(
		PORT,
		MAX_PLAYERS
	)

	if error != OK:
		print(
			"FAILED TO CREATE SERVER: ",
			error
		)
		return

	multiplayer.multiplayer_peer = peer

	is_connecting = false
	is_connected = true

	player_rooms.clear()
	player_states.clear()
	player_names.clear()

	var host_id = multiplayer.get_unique_id()

	player_rooms[host_id] = "world"

	room_state_ready = true

	set_player_name(
		host_id,
		player_name
	)

	print("================================")
	print("PIXELREIGN LOCAL SERVER STARTED")
	print("PORT: ", PORT)
	print("HOST ID: ", host_id)
	print("HOST NAME: ", player_names[host_id])
	print("================================")

	host_started.emit()


# ============================================================
# JOIN
# ============================================================

func join_game(address: String):

	if is_connecting:
		print(
			"JOIN IGNORED: Already connecting to a server."
		)
		return

	if is_connected:
		print(
			"JOIN IGNORED: Already connected to a server."
		)
		return

	address = address.strip_edges()

	if address == "":
		print("ERROR: Empty server address.")
		return

	var host := address
	var port := PORT

	# ========================================================
	# HOST:PORT FORMAT
	# ========================================================

	if address.count(":") == 1:

		var parts = address.split(":")

		if parts.size() == 2:

			host = parts[0].strip_edges()

			if parts[1].is_valid_int():

				port = int(parts[1])

			else:

				print(
					"ERROR: Invalid port: ",
					parts[1]
				)

				return

	# ========================================================
	# VALIDATE PORT
	# ========================================================

	if port < 1 or port > 65535:

		print(
			"ERROR: Invalid port: ",
			port
		)

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

		print(
			"FAILED TO CREATE CLIENT: ",
			error
		)

		return

	# ========================================================
	# MARK AS CONNECTING BEFORE ASSIGNING PEER
	# ========================================================

	is_connecting = true
	is_connected = false

	player_rooms.clear()
	player_states.clear()
	player_names.clear()

	room_state_ready = false

	# ========================================================
	# CONNECT NETWORK SIGNALS
	# ========================================================

	if not multiplayer.connected_to_server.is_connected(
		_on_connected_to_server
	):

		multiplayer.connected_to_server.connect(
			_on_connected_to_server
		)

	if not multiplayer.connection_failed.is_connected(
		_on_connection_failed
	):

		multiplayer.connection_failed.connect(
			_on_connection_failed
		)

	if not multiplayer.server_disconnected.is_connected(
		_on_server_disconnected
	):

		multiplayer.server_disconnected.connect(
			_on_server_disconnected
		)

	# ========================================================
	# ASSIGN PEER
	# ========================================================

	multiplayer.multiplayer_peer = peer


# ============================================================
# CONNECTED TO SERVER
# ============================================================

func _on_connected_to_server():

	is_connecting = false
	is_connected = true

	print("================================")
	print("CONNECTED TO PIXELREIGN SERVER")
	print("MY PEER ID: ", multiplayer.get_unique_id())
	print("IS SERVER: ", multiplayer.is_server())
	print("================================")

	if pending_player_name != "":

		request_set_player_name.rpc_id(
			1,
			pending_player_name
		)


# ============================================================
# CONNECTION FAILED
# ============================================================

func _on_connection_failed():

	print("================================")
	print("FAILED TO CONNECT TO PIXELREIGN SERVER")
	print("================================")

	is_connecting = false
	is_connected = false

	room_state_ready = false


# ============================================================
# SERVER DISCONNECTED
# ============================================================

func _on_server_disconnected():

	print("================================")
	print("DISCONNECTED FROM PIXELREIGN SERVER")
	print("================================")

	is_connecting = false
	is_connected = false

	room_state_ready = false

	player_rooms.clear()
	player_states.clear()
	player_names.clear()


# ============================================================
# PEER CONNECTION
# ============================================================

func _on_peer_connected(peer_id):

	if not multiplayer.is_server():
		return

	print(
		"NETWORK PEER CONNECTED: ",
		peer_id
	)

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

	print(
		"NETWORK PEER DISCONNECTED: ",
		peer_id
	)

	if not multiplayer.is_server():
		return

	player_rooms.erase(peer_id)
	player_states.erase(peer_id)
	player_names.erase(peer_id)

	for client_id in multiplayer.get_peers():

		_player_left.rpc_id(
			client_id,
			peer_id
		)


@rpc("authority", "call_remote", "reliable")
func _player_left(peer_id: int):

	player_rooms.erase(peer_id)
	player_states.erase(peer_id)
	player_names.erase(peer_id)

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

			var player_name = player_names.get(
				peer_id,
				"Player" + str(peer_id)
			)

			send_room_player.rpc_id(
				requester,
				peer_id,
				player_name
			)


@rpc("authority", "reliable")
func send_room_player(
	peer_id: int,
	player_name: String
):

	player_names[peer_id] = player_name

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
# CHAT
# ============================================================

func _add_chat_message(
	room: String,
	peer_id: int,
	player_name: String,
	message: String
):

	if not chat_logs.has(room):
		chat_logs[room] = []

	var chat_entry = {
		"peer_id": peer_id,
		"player_name": player_name,
		"message": message
	}

	chat_logs[room].append(chat_entry)

	if chat_logs[room].size() > MAX_CHAT_MESSAGES:
		chat_logs[room].pop_front()


@rpc("any_peer", "reliable")
func send_chat_message(message: String):

	if not multiplayer.is_server():
		return

	var sender_id = multiplayer.get_remote_sender_id()

	if not player_rooms.has(sender_id):
		return

	var room = player_rooms[sender_id]

	if room != "world" and room != "house":
		return

	message = message.strip_edges()

	if message == "":
		return

	if message.length() > 200:
		message = message.left(200)

	var player_name = player_names.get(
		sender_id,
		"Player" + str(sender_id)
	)

	_add_chat_message(
		room,
		sender_id,
		player_name,
		message
	)

	_broadcast_chat_message.rpc(
		room,
		sender_id,
		player_name,
		message
	)


@rpc("authority", "call_local", "reliable")
func _broadcast_chat_message(
	room: String,
	peer_id: int,
	player_name: String,
	message: String
):

	var local_id = multiplayer.get_unique_id()

	if NetworkManager.player_rooms.get(
		local_id,
		""
	) != room:
		return

	chat_message_received.emit(
		peer_id,
		player_name,
		message
	)


@rpc("any_peer", "reliable")
func request_chat_history(room: String):

	if not multiplayer.is_server():
		return

	if room != "world" and room != "house":
		return

	var requester = multiplayer.get_remote_sender_id()

	if not player_rooms.has(requester):
		return

	if player_rooms[requester] != room:
		return

	var messages = chat_logs.get(
		room,
		[]
	)

	_receive_chat_history.rpc_id(
		requester,
		messages.duplicate(true)
	)


@rpc("authority", "reliable")
func _receive_chat_history(messages: Array):

	chat_history_received.emit(
		messages
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
# PLAYER NAME
# ============================================================

@rpc("authority", "call_local", "reliable")
func _player_name_changed(
	peer_id: int,
	player_name: String
):

	player_names[peer_id] = player_name

	print(
		"PLAYER NAME RECEIVED: ",
		peer_id,
		" -> ",
		player_name
	)

	player_name_changed.emit(
		peer_id,
		player_name
	)

	if (
		peer_id == multiplayer.get_unique_id()
		and not multiplayer.is_server()
	):

		print(
			"MY NAME RECEIVED: ",
			player_name
		)

		pending_player_name = player_name

		player_name_ready.emit()

		client_connected.emit()


@rpc("any_peer", "reliable")
func request_set_player_name(
	player_name: String
):

	if not multiplayer.is_server():
		return

	var sender_id = multiplayer.get_remote_sender_id()

	set_player_name(
		sender_id,
		player_name
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

func get_player_state(peer_id):

	return player_states.get(
		peer_id,
		null
	)
