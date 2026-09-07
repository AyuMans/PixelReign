extends CanvasLayer

@onready var avatar_button = $AvatarButton
@onready var panel = $Panel

@onready var character1_button = $Panel/Character1Button
@onready var character2_button = $Panel/Character2Button
@onready var confirm_button = $Panel/ConfirmButton

var selected_avatar := 1


func _ready():
	avatar_button.pressed.connect(_toggle_menu)

	character1_button.pressed.connect(_select_character1)
	character2_button.pressed.connect(_select_character2)
	confirm_button.pressed.connect(_confirm_selection)

	panel.visible = false

	_update_selection()


func _toggle_menu():
	panel.visible = not panel.visible


func _select_character1():
	selected_avatar = 1
	_update_selection()


func _select_character2():
	selected_avatar = 2
	_update_selection()


func _update_selection():
	if selected_avatar == 1:
		character1_button.modulate = Color(1.0, 1.0, 0.7)
		character2_button.modulate = Color(1.0, 1.0, 1.0)
	else:
		character1_button.modulate = Color(1.0, 1.0, 1.0)
		character2_button.modulate = Color(1.0, 1.0, 0.7)


func _confirm_selection():
	print("SELECTED AVATAR: ", selected_avatar)

	NetworkManager.selected_avatar = selected_avatar

	var local_id = multiplayer.get_unique_id()

	for player in get_tree().get_nodes_in_group("players"):
		if player.get_multiplayer_authority() == local_id:
			player.set_avatar(selected_avatar)
			break

	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			NetworkManager.player_avatars[local_id] = selected_avatar

			NetworkManager._broadcast_avatar.rpc(
				local_id,
				selected_avatar
			)
		else:
			NetworkManager.request_set_avatar.rpc_id(
				1,
				selected_avatar
			)

	panel.visible = false
