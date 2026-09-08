extends Panel

@onready var player_name_label = $PlayerName
@onready var avatar = $Avatar
@onready var close_button = $CloseButton

const AVATAR1_CARD = preload("res://assets/avatars/avatar1_card.png")
const AVATAR2_CARD = preload("res://assets/avatars/avatar2_card.png")


func _ready():
	close_button.pressed.connect(_on_close_pressed)
	visible = false

	avatar.custom_minimum_size = Vector2(150, 150)
	avatar.size = Vector2(150, 150)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func show_player(player_name: String, selected_avatar_id: int):

	player_name_label.text = player_name

	if selected_avatar_id == 1:
		avatar.texture = AVATAR1_CARD
	else:
		avatar.texture = AVATAR2_CARD

	avatar.custom_minimum_size = Vector2(150, 150)
	avatar.size = Vector2(150, 150)

	visible = true
	move_to_front()

	var viewport_size = get_viewport().get_visible_rect().size
	position = (viewport_size - size) / 2.0


func _on_close_pressed():
	visible = false
