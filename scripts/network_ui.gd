extends CanvasLayer

@onready var panel = $Panel

@onready var host_button = $Panel/HostButton
@onready var join_button = $Panel/JoinButton
@onready var ip_input = $Panel/IPInput
@onready var name_input = $Panel/NameInput

@onready var close_button = $Panel/CloseButton
@onready var open_button = $OpenButton


func _ready():

	print("NETWORK UI READY")

	if not host_button.pressed.is_connected(
		_on_host_pressed
	):
		host_button.pressed.connect(
			_on_host_pressed
		)

	if not join_button.pressed.is_connected(
		_on_join_pressed
	):
		join_button.pressed.connect(
			_on_join_pressed
		)

	if not close_button.pressed.is_connected(
		_on_close_pressed
	):
		close_button.pressed.connect(
			_on_close_pressed
		)

	if not open_button.pressed.is_connected(
		_on_open_pressed
	):
		open_button.pressed.connect(
			_on_open_pressed
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

	panel.visible = NetworkManager.network_ui_open

	open_button.visible = not NetworkManager.network_ui_open


# ============================================================
# GET PLAYER NAME
# ============================================================

func _get_player_name() -> String:

	var player_name = name_input.text.strip_edges()

	if player_name == "":
		player_name = "Player"

	if player_name.length() > 16:
		player_name = player_name.left(16)

	return player_name


# ============================================================
# HOST
# ============================================================

func _on_host_pressed():

	print("HOST BUTTON CLICKED")

	if NetworkManager.is_connecting:

		print(
			"HOST IGNORED: Currently connecting."
		)

		return

	if NetworkManager.is_connected:

		print(
			"HOST IGNORED: Already connected."
		)

		return

	var player_name = _get_player_name()

	NetworkManager.pending_player_name = player_name

	host_button.disabled = true
	join_button.disabled = true

	NetworkManager.host_game(
		player_name
	)


# ============================================================
# JOIN
# ============================================================

func _on_join_pressed():

	print("JOIN BUTTON CLICKED")

	if NetworkManager.is_connecting:

		print(
			"JOIN IGNORED: Already connecting."
		)

		return

	if NetworkManager.is_connected:

		print(
			"JOIN IGNORED: Already connected."
		)

		return

	var address = ip_input.text.strip_edges()

	if address == "":

		print(
			"No server address entered."
		)

		return

	var player_name = _get_player_name()

	NetworkManager.pending_player_name = player_name

	join_button.disabled = true
	host_button.disabled = true

	NetworkManager.join_game(
		address
	)


# ============================================================
# CONNECTION FAILED
# ============================================================

func _on_connection_failed():

	print(
		"NETWORK UI: Connection failed"
	)

	join_button.disabled = false
	host_button.disabled = false


# ============================================================
# SERVER DISCONNECTED
# ============================================================

func _on_server_disconnected():

	print(
		"NETWORK UI: Server disconnected"
	)

	join_button.disabled = false
	host_button.disabled = false


# ============================================================
# CLOSE
# ============================================================

func _on_close_pressed():

	NetworkManager.network_ui_open = false

	panel.visible = false
	open_button.visible = true


# ============================================================
# OPEN
# ============================================================

func _on_open_pressed():

	NetworkManager.network_ui_open = true

	panel.visible = true
	open_button.visible = false
