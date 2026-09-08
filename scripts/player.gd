extends CharacterBody2D

@export var speed := 160.0
@onready var name_label = $NameLabel
@onready var chat_bubble = $ChatBubble
@onready var chat_bubble_label = $ChatBubble/Label
@onready var chat_bubble_timer = $ChatBubbleTimer
const CHARACTER1_FRAMES = preload("res://assets/characters/character1/character1.tres")
const CHARACTER2_FRAMES = preload("res://assets/characters/character2/character2.tres")
var avatar_id := 1
var last_direction := "down"
var current_animation := "idle_down"

var last_sent_position := Vector2.INF
var last_sent_animation := ""



@export var network_smoothing := 1000.0
var network_target_position := Vector2.ZERO
var network_target_animation := ""
var network_state_initialized := false



func set_player_name(player_name: String):
	name_label.text = player_name
	
func _ready():
	set_physics_process(is_multiplayer_authority())

	network_target_position = global_position

	var my_id := 0

	if multiplayer.has_multiplayer_peer():
		if multiplayer.multiplayer_peer != null:
			my_id = multiplayer.get_unique_id()

	print(
		"PLAYER READY: ",
		name,
		" | My ID: ",
		my_id,
		" | Authority: ",
		get_multiplayer_authority(),
		" | Physics: ",
		is_physics_processing()
	)

	chat_bubble_timer.timeout.connect(_hide_chat_bubble)

func _physics_process(_delta):

	var focused_control = get_viewport().gui_get_focus_owner()

	if focused_control is LineEdit:
		velocity = Vector2.ZERO
		return

	if not multiplayer.has_multiplayer_peer():
		set_physics_process(false)
		return

	if multiplayer.multiplayer_peer == null:
		set_physics_process(false)
		return

	var peer = multiplayer.multiplayer_peer

	if not multiplayer.is_server():
		if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			set_physics_process(false)
			return

	var direction := Vector2.ZERO

	direction.x = Input.get_axis(
		"move_left",
		"move_right"
	)

	direction.y = Input.get_axis(
		"move_up",
		"move_down"
	)

	if direction.length() > 0:
		direction = direction.normalized()
		velocity = direction * speed
		update_animation(direction)
	else:
		velocity = Vector2.ZERO
		set_animation("idle_" + last_direction)

	move_and_slide()
	send_state()
	
func _process(delta):

	if is_multiplayer_authority():
		return

	if not network_state_initialized:
		return

	global_position = global_position.lerp(
		network_target_position,
		1.0 - exp(-network_smoothing * delta)
	)

func update_animation(direction: Vector2):

	var animation_name := ""

	if direction.y > 0:

		if direction.x > 0:
			animation_name = "right_down"

		elif direction.x < 0:
			animation_name = "left_down"

		else:
			animation_name = "down"

	elif direction.y < 0:

		if direction.x > 0:
			animation_name = "right_up"

		elif direction.x < 0:
			animation_name = "left_up"

		else:
			animation_name = "up"

	else:

		if direction.x > 0:
			animation_name = "right_down"

		else:
			animation_name = "left_down"

	last_direction = animation_name

	set_animation(
		"walk_" + animation_name
	)


func set_animation(new_animation: String):

	if current_animation == new_animation:
		return

	current_animation = new_animation

	$AnimatedSprite2D.play(
		current_animation
	)


func send_state():

	if not is_multiplayer_authority():
		return

	if not multiplayer.has_multiplayer_peer():
		set_physics_process(false)
		return

	if multiplayer.multiplayer_peer == null:
		set_physics_process(false)
		return

	var peer = multiplayer.multiplayer_peer

	if not multiplayer.is_server():

		if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			set_physics_process(false)
			return

	var my_id := multiplayer.get_unique_id()

	if not NetworkManager.room_state_ready:
		return

	var my_room = NetworkManager.player_rooms.get(
		my_id,
		""
	)

	if my_room == "":
		return

	if (
		global_position == last_sent_position
		and current_animation == last_sent_animation
	):
		return

	last_sent_position = global_position
	last_sent_animation = current_animation
	

	# HOST
	if multiplayer.is_server():

		NetworkManager.receive_player_state_from_server(
			my_id,
			global_position,
			current_animation
		)

	# CLIENT
	else:

		NetworkManager.send_player_state.rpc_id(
			1,
			my_id,
			global_position,
			current_animation
		)

func show_chat_bubble(message: String):
	chat_bubble_label.text = message
	chat_bubble.visible = true
	chat_bubble_timer.start()


func _hide_chat_bubble():
	chat_bubble.visible = false
	
func set_avatar(new_avatar_id: int):
	avatar_id = new_avatar_id

	if avatar_id == 1:
		$AnimatedSprite2D.sprite_frames = CHARACTER1_FRAMES
	else:
		$AnimatedSprite2D.sprite_frames = CHARACTER2_FRAMES

	$AnimatedSprite2D.play(current_animation)


func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:

			PlayerCard.show_player(
				name_label.text,
				avatar_id
			)
