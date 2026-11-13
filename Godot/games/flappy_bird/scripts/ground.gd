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
