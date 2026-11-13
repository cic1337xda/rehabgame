extends Node

## File path referencing the universal UI interaction sound effect
## Replace with your actual audio asset path (e.g. "res://assets/audio/click.wav")
const CLICK_SFX_PATH : String = "res://kenney_interface-sounds/Audio/drop_001.ogg"

var click_player : AudioStreamPlayer

func _ready() -> void:
	# Instantiate dedicated non-positional audio player for UI feedback
	click_player = AudioStreamPlayer.new()
	click_player.process_mode = Node.PROCESS_MODE_ALWAYS # Allows playback even if paused
	
	if ResourceLoader.exists(CLICK_SFX_PATH):
		click_player.stream = load(CLICK_SFX_PATH)
	else:
		printerr("[AUDIO] Specified click SFX asset not found at path: ", CLICK_SFX_PATH)
		
	add_child(click_player)

	# Monitor runtime node additions to automatically wire up dynamically created buttons
	get_tree().node_added.connect(_on_node_added)
	
	# Recursively attach listeners to buttons instantiated prior to singleton ready lifecycle
	_bind_existing_buttons(get_tree().root)

## Recursively inspects the active scene tree to bind click events to pre-existing buttons
func _bind_existing_buttons(node: Node) -> void:
	if node is BaseButton:
		_register_button(node)
	for child in node.get_children():
		_bind_existing_buttons(child)

## Signal callback triggered whenever a new node joins the scene tree
func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_register_button(node)

## Connects button press signal to the centralized audio dispatcher
func _register_button(btn: BaseButton) -> void:
	if not btn.pressed.is_connected(_play_click_audio):
		btn.pressed.connect(_play_click_audio)

## Executes sound effect playback with slight pitch variations to prevent audio fatigue
func _play_click_audio() -> void:
	if click_player and click_player.stream:
		# Randomize pitch slightly (0.95 to 1.05) for organic tactile responsiveness
		click_player.pitch_scale = randf_range(0.95, 1.05)
		click_player.play()
