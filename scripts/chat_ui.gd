extends CanvasLayer

@onready var chat_panel = $ChatPanel
@onready var history_button = $HistoryButton
@onready var input_row = $InputRow
@onready var chat_input = $InputRow/ChatInput
@onready var send_button = $InputRow/SendButton
@onready var scroll_container = $ChatPanel/ScrollContainer
@onready var chat_log = $ChatPanel/ScrollContainer/ChatLog

var history_open := false


func _ready():
	history_button.pressed.connect(_toggle_history)
	send_button.pressed.connect(_send_message)
	chat_input.text_submitted.connect(_on_text_submitted)
	chat_input.focus_entered.connect(_on_chat_focus_entered)
	chat_input.focus_exited.connect(_on_chat_focus_exited)
	if not NetworkManager.chat_message_received.is_connected(_on_chat_message_received):
		NetworkManager.chat_message_received.connect(_on_chat_message_received)

	if not NetworkManager.chat_history_received.is_connected(_on_chat_history_received):
		NetworkManager.chat_history_received.connect(_on_chat_history_received)

	_set_history_closed()

	_request_current_room_history()

func _on_chat_focus_entered():
	chat_input.set_meta("typing", true)


func _on_chat_focus_exited():
	chat_input.set_meta("typing", false)
func _toggle_history():
	if history_open:
		_set_history_closed()
	else:
		_set_history_open()


func _set_history_closed():
	history_open = false

	# Hide ONLY the chat history panel.
	chat_panel.visible = false

	# These ALWAYS remain visible.
	history_button.visible = true
	input_row.visible = true

	history_button.text = "▲"


func _set_history_open():
	history_open = true

	# Show ONLY the chat history panel.
	chat_panel.visible = true

	# These ALWAYS remain visible.
	history_button.visible = true
	input_row.visible = true

	history_button.text = "▼"

	await get_tree().process_frame
	_scroll_to_bottom()


func _send_message():
	var message = chat_input.text.strip_edges()

	if message == "":
		chat_input.release_focus()
		return

	if not multiplayer.has_multiplayer_peer():
		chat_input.release_focus()
		return

	if multiplayer.multiplayer_peer == null:
		chat_input.release_focus()
		return

	NetworkManager.send_chat_message.rpc_id(
		1,
		message
	)

	chat_input.clear()
	chat_input.release_focus()
	
func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.pressed:
			if not chat_input.get_global_rect().has_point(event.position):
				chat_input.release_focus()
func _on_text_submitted(_text):
	_send_message()


func _on_chat_message_received(
	peer_id: int,
	player_name: String,
	message: String
):
	_add_message(
		player_name,
		message
	)

	for player in get_tree().get_nodes_in_group("players"):
		if player.get_multiplayer_authority() == peer_id:
			player.show_chat_bubble(message)
			break


func _on_chat_history_received(messages: Array):
	_clear_chat()

	for message in messages:
		if not message.has("player_name"):
			continue

		if not message.has("message"):
			continue

		_add_message(
			message["player_name"],
			message["message"]
		)

	await get_tree().process_frame
	_scroll_to_bottom()


func _add_message(player_name: String, message: String):
	var label = Label.new()

	label.text = player_name + ": " + message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size.x = 400

	chat_log.add_child(label)

	await get_tree().process_frame
	_scroll_to_bottom()


func _clear_chat():
	for child in chat_log.get_children():
		child.queue_free()


func _scroll_to_bottom():
	scroll_container.scroll_vertical = (
		scroll_container.get_v_scroll_bar().max_value
	)


func _request_current_room_history():
	if not multiplayer.has_multiplayer_peer():
		return

	if multiplayer.multiplayer_peer == null:
		return

	var local_id = multiplayer.get_unique_id()

	var room = NetworkManager.player_rooms.get(
		local_id,
		""
	)

	if (
		room != "world"
		and room != "house"
		and room != "snow_forest"
	):
		return

	if multiplayer.is_server():
		if NetworkManager.chat_logs.has(room):
			_on_chat_history_received(
				NetworkManager.chat_logs[room]
			)
	else:
		NetworkManager.request_chat_history.rpc_id(
			1,
			room
		)
