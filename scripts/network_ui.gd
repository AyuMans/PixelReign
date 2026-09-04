extends CanvasLayer

@onready var panel = $Panel

@onready var host_button = $Panel/HostButton
@onready var join_button = $Panel/JoinButton
@onready var ip_input = $Panel/IPInput

@onready var close_button = $Panel/CloseButton
@onready var open_button = $OpenButton


func _ready():
	print("NETWORK UI READY")

	if not host_button.pressed.is_connected(_on_host_pressed):
		host_button.pressed.connect(_on_host_pressed)

	if not join_button.pressed.is_connected(_on_join_pressed):
		join_button.pressed.connect(_on_join_pressed)

	if not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)

	if not open_button.pressed.is_connected(_on_open_pressed):
		open_button.pressed.connect(_on_open_pressed)

	panel.visible = NetworkManager.network_ui_open
	open_button.visible = not NetworkManager.network_ui_open


func _on_host_pressed():
	print("HOST BUTTON CLICKED")

	NetworkManager.host_game()


func _on_join_pressed():
	print("JOIN BUTTON CLICKED")

	var ip = ip_input.text.strip_edges()

	if ip == "":
		ip = "127.0.0.1"

	NetworkManager.join_game(ip)


# ============================================================
# CLOSE NETWORK MENU
# ============================================================

func _on_close_pressed():
	NetworkManager.network_ui_open = false

	panel.visible = false
	open_button.visible = true


# ============================================================
# OPEN NETWORK MENU
# ============================================================

func _on_open_pressed():
	NetworkManager.network_ui_open = true

	panel.visible = true
	open_button.visible = false
