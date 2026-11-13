extends CharacterBody2D

const START_POS = Vector2(100, 300)
var flying : bool = false
var falling : bool = false

# Target vertical position calculated and driven by main telemetry controller
var target_y : float = 300.0

# Linear interpolation smoothing factor for physiological motion dampening
const INTERPOLATION_WEIGHT : float = 8.0

func _ready():
	reset()

## Restores bird entity parameters to initial state
func reset() -> void:
	falling = false
	flying = false
	position = START_POS
	target_y = START_POS.y
	set_rotation(0)

func _physics_process(delta: float) -> void:
	if flying:
		# Interpolate smoothly towards the calculated vertical telemetry target
		position.y = lerp(position.y, target_y, INTERPOLATION_WEIGHT * delta)
		
		# Constrain movement within screen bounds (leaving room for ground collision)
		position.y = clamp(position.y, 25.0, 650.0)

		# Trigger wing-flapping animation during active kinematic adjustments
		if abs(position.y - target_y) > 2.0:
			$AnimatedSprite2D.play()
		else:
			$AnimatedSprite2D.stop()

		set_rotation(0)

	elif falling:
		set_rotation(PI / 2)
		$AnimatedSprite2D.stop()
	else:
		$AnimatedSprite2D.stop()

func flap() -> void:
	# Retained for interface backwards compatibility
	pass
