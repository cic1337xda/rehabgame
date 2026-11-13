# Kod Sumber Flappy Bird

## main.gd
```gdscript
extends Node

@export var pipe_scene : PackedScene

var game_running : bool
var game_over : bool
var scroll
var score

# Dynamic scrolling velocity and spawn interval for rehabilitative gameplay pacing
var scroll_speed : float = 1.5
var pipe_spawn_delay : float = 3.5

var screen_size : Vector2i
var ground_height : int
var ground_width : float # Variable declared for seamless background looping

var pipes : Array
const PIPE_DELAY : int = 100
const PIPE_RANGE : int = 150

# Interface references for exercise management buttons and difficulty selection
@onready var start_button: TextureButton = $UI/StartButton
@onready var quit_button: TextureButton = $UI/QuitButton
@onready var level_selection_menu: VBoxContainer = $UI/LevelSelectionMenu
@onready var slow_button: TextureButton = $UI/LevelSelectionMenu/SlowButton
@onready var medium_button: TextureButton = $UI/LevelSelectionMenu/MediumButton
@onready var fast_button: TextureButton = $UI/LevelSelectionMenu/FastButton

# Primary menu scene destination path
const MAIN_MENU_PATH : String = "res://main_menu/scenes/main_menu.tscn"

# Called when the node enters the scene tree for the first time.
func _ready():
	screen_size = get_window().size
	ground_height = $Ground.get_node("Sprite2D").texture.get_height()
	
	# Calculate the effective width by accounting for the node's horizontal scale
	ground_width = $Ground.get_node("Sprite2D").texture.get_width() * $Ground.scale.x
	
	# Connect Start Button signal for user-triggered session initialization
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
		
	# Connect Start Page Quit Button signal
	if quit_button:
		quit_button.pressed.connect(_on_quit_button_pressed)
		
	# Connect difficulty level selection button signals
	if slow_button:
		slow_button.pressed.connect(_on_slow_button_pressed)
	if medium_button:
		medium_button.pressed.connect(_on_medium_button_pressed)
	if fast_button:
		fast_button.pressed.connect(_on_fast_button_pressed)
		
	# Connect GameOver layer signals dynamically
	if $GameOver:
		if not $GameOver.restart.is_connected(_on_game_over_restart):
			$GameOver.restart.connect(_on_game_over_restart)
		if $GameOver.has_signal("quit") and not $GameOver.quit.is_connected(_on_quit_button_pressed):
			$GameOver.quit.connect(_on_quit_button_pressed)
		
	new_game()

func new_game():
	# Reset state variables
	game_running = false
	game_over = false
	score = 0
	scroll = 0
	$ScoreLabel.text = "SCORE: " + str(score)
	$GameOver.hide()
	
	# Ensure difficulty menu is concealed during initial menu presentation
	if level_selection_menu:
		level_selection_menu.hide()

	# Present start and quit action overlays to allow patient navigation
	if start_button:
		start_button.show()
	if quit_button:
		quit_button.show()
		
	get_tree().call_group("pipes", "queue_free")
	pipes.clear()
	generate_pipes()
	$Bird.reset()

	# Ensure ground movement is halted while waiting for user initialization
	if $Ground.has_method("stop"):
		$Ground.stop()
	else:
		$Ground.set_process(false)
		
	$Ground.position.x = 0

func _on_start_button_pressed():
	# Hide initial navigation buttons and prompt difficulty options
	if start_button:
		start_button.hide()
	if quit_button:
		quit_button.hide()
		
	if level_selection_menu:
		level_selection_menu.show()

func _on_slow_button_pressed():
	# Configure low scrolling speed and extended spawn delays for warm-up exercises
	scroll_speed = 1.0
	pipe_spawn_delay = 4.0
	start_game()

func _on_medium_button_pressed():
	# Configure balanced pacing suitable for standard cognitive rehabilitation
	scroll_speed = 1.8
	pipe_spawn_delay = 3.0
	start_game()

func _on_fast_button_pressed():
	# Configure elevated speed parameters for advanced motor response training
	scroll_speed = 2.8
	pipe_spawn_delay = 2.0
	start_game()

func _on_quit_button_pressed():
	_return_to_main_menu()

## Navigates the application back to the main menu selection screen
func _return_to_main_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)

func start_game():
	game_running = true
	$Bird.flying = true
	
	# Dismiss the difficulty selection interface upon session activation
	if level_selection_menu:
		level_selection_menu.hide()

	# Resume ground animation processing upon active gameplay initiation
	if $Ground.has_method("start"):
		$Ground.start()
	else:
		$Ground.set_process(true)
	
	# Dismiss start and quit overlay interface during active gameplay
	if start_button:
		start_button.hide()
	if quit_button:
		quit_button.hide()
		
	# Apply configured pipe instantiation delay based on selected level
	$PipeTimer.wait_time = pipe_spawn_delay
	$PipeTimer.start()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if game_running:
		scroll += scroll_speed
		
		# Maintain continuous scrolling velocity without frame loss during reset
		if scroll >= ground_width:
			scroll -= ground_width
			
		$Ground.position.x = -scroll
		for pipe in pipes:
			pipe.position.x -= scroll_speed

func _on_pipe_timer_timeout():
	generate_pipes()

func generate_pipes():
	var pipe = pipe_scene.instantiate()
	pipe.position.x = screen_size.x + PIPE_DELAY
	pipe.position.y = (screen_size.y - ground_height) / 2 + randi_range(-PIPE_RANGE, PIPE_RANGE)
	pipe.hit.connect(bird_hit)
	pipe.scored.connect(scored)
	add_child(pipe)
	pipes.append(pipe)

func scored():
	score += 1
	$ScoreLabel.text = "SCORE: " + str(score)

func check_top():
	if $Bird.position.y < 0:
		$Bird.falling = true
		stop_game()

func stop_game():
	$PipeTimer.stop()
	$GameOver.show()
	$Bird.flying = false
	game_running = false
	game_over = true

	# Terminate ground scrolling activity upon session conclusion
	if $Ground.has_method("stop"):
		$Ground.stop()
	else:
		$Ground.set_process(false)

func bird_hit():
	$Bird.falling = true
	stop_game()

func _on_ground_hit():
	$Bird.falling = false
	stop_game()

func _on_game_over_restart():
	new_game()
```

## bird.gd
```gdscript
extends CharacterBody2D

# Linear movement speed calibrated for physical therapy exercise
const MOVEMENT_SPEED : float = 220.0
var flying : bool = false
var falling : bool = false
const START_POS = Vector2(100, 300)

# Called when the node enters the scene tree for the first time.
func _ready():
	reset()

func reset():
	falling = false
	flying = false
	position = START_POS
	set_rotation(0)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if flying:
		var direction : float = 0.0

		# Intercept key press events simulating knee joint flexion and extension telemetry
		if Input.is_action_pressed("ui_up"):
			direction -= 1.0
		if Input.is_action_pressed("ui_down"):
			direction += 1.0

		# Apply velocity vector
		velocity.y = direction * MOVEMENT_SPEED

		# Play animation during active movement
		if direction != 0.0:
			$AnimatedSprite2D.play()
		else:
			$AnimatedSprite2D.stop()

		# Maintain horizontal orientation
		set_rotation(0)

		# Execute movement translation
		move_and_slide()

		# Constrain vertical bounds within screen dimensions for 720p resolution
		position.y = clamp(position.y, 25.0, 650.0)

	elif falling:
		set_rotation(PI/2)
		$AnimatedSprite2D.stop()
	else:
		$AnimatedSprite2D.stop()

func flap():
	# Retained for main script compatibility
	pass
```

## pipe.gd
```gdscript
extends Area2D

signal hit
signal scored

func _on_body_entered(body):
	hit.emit()

func _on_score_area_body_entered(body):
	scored.emit()
```

## ground.gd
```gdscript
extends Area2D

signal hit

## Operational status flag determining active scrolling animation
var is_moving: bool = true

func _process(_delta: float) -> void:
	# Scrolling logic has been migrated to main.gd for centralized seamless looping
	# This process is intentionally left empty to prevent positional conflicts
	pass

## Halts the infinite scrolling animation during game over state
func stop() -> void:
	is_moving = false

## Resumes the infinite scrolling animation upon game restart
func start() -> void:
	is_moving = true

func _on_body_entered(_body: Node2D) -> void:
	# Emits collision signal to the main game loop for state resolution
	hit.emit()
```

## game_over.gd
```gdscript
extends CanvasLayer

## Signal emitted when the user chooses to exit to the primary menu hub
signal quit

## Signal emitted when the user requests an exercise session restart
signal restart

## Handles restart button interactions
func _on_restart_button_pressed() -> void:
	restart.emit()

## Handles quit button interactions on the game over interface overlay
func _on_quit_button_pressed() -> void:
	quit.emit()
```

