extends CanvasLayer

## Emitted when the user requests an exercise session restart
signal restart

## Emitted when the user exits session to return to the Flappy Bird landing interface
signal quit

## Emitted when the user requests to inspect the clinical leaderboard
signal show_leaderboard

@onready var restart_button = $RestartButton
@onready var quit_button = $QuitButton
@onready var leaderboard_button = $LeaderboardButton

func _ready() -> void:
	if restart_button and not restart_button.pressed.is_connected(_on_restart_button_pressed):
		restart_button.pressed.connect(_on_restart_button_pressed)
	if quit_button and not quit_button.pressed.is_connected(_on_quit_button_pressed):
		quit_button.pressed.connect(_on_quit_button_pressed)
	if leaderboard_button and not leaderboard_button.pressed.is_connected(_on_leaderboard_button_pressed):
		leaderboard_button.pressed.connect(_on_leaderboard_button_pressed)

func _on_restart_button_pressed() -> void:
	restart.emit()

func _on_quit_button_pressed()-> void:
	quit.emit()

func _on_leaderboard_button_pressed() -> void:
	show_leaderboard.emit()
