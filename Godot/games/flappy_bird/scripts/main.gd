extends Node

@export var pipe_scene : PackedScene

var game_running : bool
var game_over : bool
var scroll
var score : int

var scroll_speed : float = 1.5
var pipe_spawn_delay : float = 3.5

var screen_size : Vector2i
var ground_height : int
var ground_width : float

var pipes : Array
const PIPE_DELAY : int = 100
const PIPE_RANGE : int = 150

# Networking telemetry configuration for local loopback reception
var udp_server : PacketPeerUDP
const UDP_PORT : int = 4242

# Clinical range of motion measurement variables
var current_knee_angle : float = 0.0
var min_angle : float = 0.0
var max_angle : float = 90.0
var is_min_calibrated : bool = false
var is_max_calibrated : bool = false

# Active clinical session tracking
var current_patient_name : String = ""

# Resource path definitions
const MAIN_MENU_PATH : String = "res://main_menu/scenes/main_menu.tscn"
const RETRO_FONT_PATH : String = "res://assets/fonts/PressStart2P-Regular.ttf"

# Primary UI navigation references
@onready var start_button: TextureButton = $UI/StartButton
@onready var leaderboard_button: TextureButton = $UI/LeaderboardButton
@onready var quit_button: TextureButton = $UI/QuitButton
@onready var level_selection_menu: VBoxContainer = $UI/LevelSelectionMenu
@onready var slow_button: TextureButton = $UI/LevelSelectionMenu/SlowButton
@onready var medium_button: TextureButton = $UI/LevelSelectionMenu/MediumButton
@onready var fast_button: TextureButton = $UI/LevelSelectionMenu/FastButton

# Clinical calibration interface references
@onready var calibration_menu = $UI/CalibrationMenu
@onready var live_angle_label = $UI/CalibrationMenu/VBoxContainer/LiveAngleLabel
@onready var min_angle_label = $UI/CalibrationMenu/VBoxContainer/MinAngleLabel
@onready var max_angle_label = $UI/CalibrationMenu/VBoxContainer/MaxAngleLabel
@onready var range_progress_bar = $UI/CalibrationMenu/VBoxContainer/RangeProgressBar
@onready var lock_straight_button: TextureButton = $UI/CalibrationMenu/VBoxContainer/LockStraightButton
@onready var lock_bent_button: TextureButton = $UI/CalibrationMenu/VBoxContainer/LockBentButton
@onready var start_exercise_button: TextureButton = $UI/CalibrationMenu/VBoxContainer/StartExerciseButton
@onready var back_button: TextureButton = $UI/CalibrationMenu/VBoxContainer/NavigationRow/BackButton
@onready var home_button: TextureButton = $UI/CalibrationMenu/VBoxContainer/NavigationRow/HomeButton

# Patient registration dialogue references
@onready var patient_dialog = $UI/PatientDialog
@onready var name_input: LineEdit = $UI/PatientDialog/VBoxContainer/NameInput
@onready var status_label: Label = $UI/PatientDialog/VBoxContainer/StatusLabel
@onready var confirm_button: Button = $UI/PatientDialog/VBoxContainer/ConfirmButton
@onready var duplicate_prompt: HBoxContainer = $UI/PatientDialog/VBoxContainer/DuplicatePrompt
@onready var continue_button: Button = $UI/PatientDialog/VBoxContainer/DuplicatePrompt/ContinueButton
@onready var rename_button: Button = $UI/PatientDialog/VBoxContainer/DuplicatePrompt/RenameButton
@onready var back_to_menu_button: Button = $UI/PatientDialog/VBoxContainer/BackToMenuButton

# Leaderboard display interface references
@onready var leaderboard_menu = $UI/LeaderboardMenu
@onready var records_list: VBoxContainer = $UI/LeaderboardMenu/VBoxContainer/ScrollContainer/RecordsList
@onready var close_leaderboard_button: Button = $UI/LeaderboardMenu/VBoxContainer/CloseLeaderboardButton

# Audio management nodes
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer
@onready var wing_sfx_player: AudioStreamPlayer = $WingSFXPlayer

# Randomized wing flap audio pacing variables
var wing_sound_countdown : float = 0.0

func _ready():
	# Terminate any lingering background audio tracks initiated by the main menu template
	for node in get_tree().root.find_children("*", "", true, false):
		if (node is AudioStreamPlayer or node is AudioStreamPlayer2D) and node != bgm_player and node != wing_sfx_player:
			node.stop()

	screen_size = get_window().size
	ground_height = $Ground.get_node("Sprite2D").texture.get_height()
	ground_width = $Ground.get_node("Sprite2D").texture.get_width() * $Ground.scale.x
	
	# Initialize local loopback UDP socket for telemetry ingestion
	udp_server = PacketPeerUDP.new()
	var bind_status = udp_server.bind(UDP_PORT, "127.0.0.1")
	if bind_status == OK:
		print("[NETWORK] UDP listener successfully bound to port: ", UDP_PORT)
	else:
		printerr("[ERROR] Failed to bind UDP listener on port: ", UDP_PORT)

	# Connect primary navigation actions
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
	if leaderboard_button:
		leaderboard_button.pressed.connect(_on_leaderboard_button_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_button_pressed)

	# Connect difficulty selection controls
	if slow_button:
		slow_button.pressed.connect(_on_slow_button_pressed)
	if medium_button:
		medium_button.pressed.connect(_on_medium_button_pressed)
	if fast_button:
		fast_button.pressed.connect(_on_fast_button_pressed)

	# Connect patient profile registration handlers
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_patient_name_pressed)
	if continue_button:
		continue_button.pressed.connect(_on_continue_with_existing_pressed)
	if rename_button:
		rename_button.pressed.connect(_on_rename_pressed)
	if back_to_menu_button:
		back_to_menu_button.pressed.connect(_on_patient_dialog_back_pressed)

	# Connect clinical calibration action controls
	if lock_straight_button:
		lock_straight_button.pressed.connect(_on_lock_straight_pressed)
	if lock_bent_button:
		lock_bent_button.pressed.connect(_on_lock_bent_pressed)
	if start_exercise_button:
		start_exercise_button.pressed.connect(_on_start_exercise_pressed)
	if back_button:
		back_button.pressed.connect(_on_calibration_back_pressed)
	if home_button:
		home_button.pressed.connect(_on_quit_button_pressed)

	# Connect leaderboard closure handler
	if close_leaderboard_button:
		close_leaderboard_button.pressed.connect(_on_close_leaderboard_pressed)

	# Connect Game Over modal signal listeners
	if $GameOver:
		if not $GameOver.restart.is_connected(_on_game_over_restart):
			$GameOver.restart.connect(_on_game_over_restart)
		if $GameOver.has_signal("quit") and not $GameOver.quit.is_connected(_on_game_over_quit):
			$GameOver.quit.connect(_on_game_over_quit)
		if $GameOver.has_signal("show_leaderboard") and not $GameOver.show_leaderboard.is_connected(_on_game_over_leaderboard):
			$GameOver.show_leaderboard.connect(_on_game_over_leaderboard)
		
	new_game()

func new_game():
	game_running = false
	game_over = false
	score = 0
	scroll = 0
	$ScoreLabel.text = "SCORE: " + str(score)
	$GameOver.hide()
	
	# Reset calibration threshold validation states
	is_min_calibrated = false
	is_max_calibrated = false
	if start_exercise_button:
		start_exercise_button.disabled = true
	if min_angle_label:
		min_angle_label.text = "Extension Limit: Not Set"
	if max_angle_label:
		max_angle_label.text = "Flexion Limit: Not Set"

	# Conceal secondary UI containers
	if level_selection_menu:
		level_selection_menu.hide()
	if calibration_menu:
		calibration_menu.hide()
	if patient_dialog:
		patient_dialog.hide()
	if leaderboard_menu:
		leaderboard_menu.hide()

	# Display primary splash controls
	_show_home_controls(true)
		
	get_tree().call_group("pipes", "queue_free")
	pipes.clear()
	generate_pipes()
	$Bird.reset()

	if $Ground.has_method("stop"):
		$Ground.stop()
	else:
		$Ground.set_process(false)
		
	$Ground.position.x = 0

## Controls the visibility of default landing view buttons
func _show_home_controls(is_visible: bool) -> void:
	if start_button:
		start_button.visible = is_visible
	if leaderboard_button:
		leaderboard_button.visible = is_visible
	if quit_button:
		quit_button.visible = is_visible

# ==============================================================================
# PATIENT IDENTIFICATION & REGISTRATION FLOW
# ==============================================================================

func _on_start_button_pressed():
	_show_home_controls(false)
	_open_patient_dialog()

func _open_patient_dialog() -> void:
	if patient_dialog:
		patient_dialog.show()
		name_input.text = ""
		status_label.text = ""
		duplicate_prompt.hide()
		confirm_button.show()
		name_input.grab_focus()

func _on_confirm_patient_name_pressed():
	var candidate_name = name_input.text.strip_edges()
	if candidate_name.is_empty():
		status_label.text = "Please enter a valid patient name."
		return

	# Evaluate database existence for profile deduplication
	var existing_record = LeaderboardManager.find_patient_record(candidate_name)
	if not existing_record.is_empty():
		var prior_score = existing_record.get("high_score", 0)
		status_label.text = "Patient exists (Record: %d pts)!\nContinue or enter a different name?" % prior_score
		confirm_button.hide()
		duplicate_prompt.show()
	else:
		current_patient_name = candidate_name
		_proceed_to_level_selection()

func _on_continue_with_existing_pressed():
	current_patient_name = name_input.text.strip_edges()
	_proceed_to_level_selection()

func _on_rename_pressed():
	duplicate_prompt.hide()
	confirm_button.show()
	status_label.text = ""
	name_input.grab_focus()

func _on_patient_dialog_back_pressed():
	if patient_dialog:
		patient_dialog.hide()
	_show_home_controls(true)

func _proceed_to_level_selection() -> void:
	if patient_dialog:
		patient_dialog.hide()
	if level_selection_menu:
		level_selection_menu.show()

# ==============================================================================
# LEADERBOARD INTERACTION LOGIC
# ==============================================================================

func _on_leaderboard_button_pressed():
	_show_home_controls(false)
	_open_leaderboard_view()

## Opens clinical leaderboard modal directly from Game Over overlay
func _on_game_over_leaderboard() -> void:
	if $GameOver:
		$GameOver.hide()
	_open_leaderboard_view()

## Handles session exit from game over modal directly back to Flappy Bird landing view
func _on_game_over_quit() -> void:
	new_game()

## Renders the leaderboard records with monospaced column alignment and boundary padding
func _open_leaderboard_view() -> void:
	# Purge previously rendered list entries to avoid visual duplicates
	for child in records_list.get_children():
		child.queue_free()

	# Inject top spacer to prevent ScrollContainer from clipping the top glyph outline
	var top_spacer = Control.new()
	top_spacer.custom_minimum_size.y = 12
	records_list.add_child(top_spacer)

	# Apply consistent row separation between records
	records_list.add_theme_constant_override("separation", 14)

	var retro_font = load(RETRO_FONT_PATH)
	var records = LeaderboardManager.get_sorted_records()

	if records.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No patient records registered yet."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if retro_font:
			empty_label.add_theme_font_override("font", retro_font)
			empty_label.add_theme_font_size_override("font_size", 14)
			empty_label.add_theme_color_override("font_color", Color.WHITE)
			empty_label.add_theme_color_override("font_outline_color", Color.BLACK)
			empty_label.add_theme_constant_override("outline_size", 4)
		records_list.add_child(empty_label)
	else:
		var rank = 1
		for entry in records:
			var entry_label = Label.new()
			var p_name = str(entry.get("name", "Unknown")).to_upper()
			
			# Cast explicitly to integer to discard JSON float decimals (.0)
			var p_score = int(entry.get("high_score", 0))
			
			# Construct unified row content
			var rank_text = "#%d" % rank
			var score_text = "%d PTS" % p_score
			var formatted_row = "%-4s %-8s : %s" % [rank_text, p_name.left(8), score_text]
			
			# Pad string to uniform character width so centered alignment produces rigid straight columns
			entry_label.text = formatted_row.rpad(35)
			entry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			
			if retro_font:
				entry_label.add_theme_font_override("font", retro_font)
				entry_label.add_theme_font_size_override("font_size", 15)
				entry_label.add_theme_color_override("font_outline_color", Color("#000000"))
				entry_label.add_theme_constant_override("outline_size", 4)
				
				# Assign podium tier colors
				match rank:
					1:
						entry_label.add_theme_color_override("font_color", Color("#FFD700"))
					2:
						entry_label.add_theme_color_override("font_color", Color("#E2E8F0"))
					3:
						entry_label.add_theme_color_override("font_color", Color("#CD7F32"))
					_:
						entry_label.add_theme_color_override("font_color", Color("#FFFFFF"))

			records_list.add_child(entry_label)
			rank += 1

	if leaderboard_menu:
		leaderboard_menu.show()

func _on_close_leaderboard_pressed():
	if leaderboard_menu:
		leaderboard_menu.hide()

	# Return to Game Over view if session ended, otherwise return to initial landing menu
	if game_over:
		if $GameOver:
			$GameOver.show()
	else:
		_show_home_controls(true)

# ==============================================================================
# CALIBRATION & GAMEPLAY
# ==============================================================================

func _on_slow_button_pressed():
	scroll_speed = 1.0
	pipe_spawn_delay = 4.0
	_open_calibration_session()

func _on_medium_button_pressed():
	scroll_speed = 1.8
	pipe_spawn_delay = 3.0
	_open_calibration_session()

func _on_fast_button_pressed():
	scroll_speed = 2.8
	pipe_spawn_delay = 2.0
	_open_calibration_session()

func _open_calibration_session() -> void:
	if level_selection_menu:
		level_selection_menu.hide()
	if calibration_menu:
		calibration_menu.show()

func _on_calibration_back_pressed() -> void:
	if calibration_menu:
		calibration_menu.hide()
	if level_selection_menu:
		level_selection_menu.show()

func _on_lock_straight_pressed():
	min_angle = current_knee_angle
	is_min_calibrated = true
	min_angle_label.text = "Extension Limit: " + str(snapped(min_angle, 0.1)) + "°"
	_verify_calibration_readiness()

func _on_lock_bent_pressed():
	max_angle = current_knee_angle
	is_max_calibrated = true
	max_angle_label.text = "Flexion Limit: " + str(snapped(max_angle, 0.1)) + "°"
	_verify_calibration_readiness()

func _verify_calibration_readiness() -> void:
	if is_min_calibrated and is_max_calibrated and max_angle > min_angle:
		start_exercise_button.disabled = false

func _on_start_exercise_pressed():
	if calibration_menu:
		calibration_menu.hide()
	start_game()

func _on_quit_button_pressed():
	_return_to_main_menu()

func _return_to_main_menu() -> void:
	# Halt flappy bird soundtrack before transitioning back to the main menu
	if bgm_player:
		bgm_player.stop()
	get_tree().change_scene_to_file(MAIN_MENU_PATH)

func start_game():
	game_running = true
	$Bird.flying = true
	
	# Prime the initial random interval for wing flap audio
	wing_sound_countdown = randf_range(0.8, 1.8)
	
	if $Ground.has_method("start"):
		$Ground.stop()
	else:
		$Ground.set_process(true)
	
	$PipeTimer.wait_time = pipe_spawn_delay
	$PipeTimer.start()

func _process(_delta):
	# Continually ingest telemetry packets from local UDP bridge
	if udp_server and udp_server.is_bound():
		while udp_server.get_available_packet_count() > 0:
			var packet = udp_server.get_packet()
			var payload_string = packet.get_string_from_utf8().strip_edges()
			if payload_string.is_valid_float():
				current_knee_angle = payload_string.to_float()

	# Visual telemetry feedback within calibration view
	if calibration_menu and calibration_menu.visible:
		live_angle_label.text = "Current Angle: " + str(snapped(current_knee_angle, 0.1)) + "°"
		if is_min_calibrated and is_max_calibrated and max_angle > min_angle:
			var normalized_percentage = remap(current_knee_angle, min_angle, max_angle, 0.0, 100.0)
			range_progress_bar.value = clamp(normalized_percentage, 0.0, 100.0)

	if game_running:
		scroll += scroll_speed
		if scroll >= ground_width:
			scroll -= ground_width
			
		$Ground.position.x = -scroll
		for pipe in pipes:
			pipe.position.x -= scroll_speed

		_update_bird_mapping()

		# Decrement countdown and trigger wing sound at randomized intervals
		wing_sound_countdown -= _delta
		if wing_sound_countdown <= 0.0:
			if wing_sfx_player:
				wing_sfx_player.pitch_scale = randf_range(0.95, 1.05)
				wing_sfx_player.play()
			wing_sound_countdown = randf_range(0.7, 1.6)

## Remaps joint range of motion to vertical coordinates (Extension -> Up, Flexion -> Down)
func _update_bird_mapping() -> void:
	var calculated_y = remap(current_knee_angle, min_angle, max_angle, 25.0, 650.0)
	if has_node("Bird"):
		$Bird.target_y = clamp(calculated_y, 25.0, 650.0)

func _on_pipe_timer_timeout():
	generate_pipes()

## Instantiates obstacles with randomized vertical altitude offset
func generate_pipes():
	var pipe = pipe_scene.instantiate()
	pipe.position.x = screen_size.x + PIPE_DELAY
	pipe.position.y = (screen_size.y - ground_height) / 2.0 + randi_range(-PIPE_RANGE, PIPE_RANGE)
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

	# Persist session metrics under active patient identifier
	if not current_patient_name.is_empty():
		LeaderboardManager.record_session_score(current_patient_name, score)

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
