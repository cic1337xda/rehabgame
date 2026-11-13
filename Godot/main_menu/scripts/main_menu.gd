extends MainMenu

@onready var background_music_player: AudioStreamPlayer = $BackgroundMusicPlayer

func _ready() -> void:
	super._ready()
	
	# Ensure background track initiates upon navigating to the main landing menu
	if background_music_player and not background_music_player.playing:
		background_music_player.play()

	# Intercept level launch trigger to cleanly terminate menu audio streaming
	var new_game_btn = get_node_or_null("MenuContainer/MenuButtonsMargin/MenuButtonsContainer/MenuButtonsBoxContainer/NewGameButton")
	if new_game_btn and not new_game_btn.pressed.is_connected(_stop_menu_audio):
		new_game_btn.pressed.connect(_stop_menu_audio)

## Halts menu background track playback
func _stop_menu_audio() -> void:
	if background_music_player:
		background_music_player.stop()

func _exit_tree() -> void:
	_stop_menu_audio()
