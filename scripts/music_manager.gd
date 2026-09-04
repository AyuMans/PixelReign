extends Node

func _ready():
	$Music.play()

func _process(_delta):
	if not $Music.playing:
		$Music.play()
