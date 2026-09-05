extends Node

const PORT := 7777
const MAX_PLAYERS := 20


func _ready():
	print("================================")
	print("PIXELREIGN DEDICATED SERVER")
	print("================================")

	var peer = ENetMultiplayerPeer.new()

	var error = peer.create_server(
		PORT,
		MAX_PLAYERS
	)

	if error != OK:
		print("FAILED TO START SERVER: ", error)
		return

	multiplayer.multiplayer_peer = peer

	print("SERVER STARTED")
	print("PORT: ", PORT)
	print("MAX PLAYERS: ", MAX_PLAYERS)

	multiplayer.peer_connected.connect(
		_on_peer_connected
	)

	multiplayer.peer_disconnected.connect(
		_on_peer_disconnected
	)


func _on_peer_connected(peer_id: int):
	print("PLAYER CONNECTED: ", peer_id)


func _on_peer_disconnected(peer_id: int):
	print("PLAYER DISCONNECTED: ", peer_id)
