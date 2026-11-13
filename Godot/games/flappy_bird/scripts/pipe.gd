#extends Area2D
#
#signal hit
#signal scored
#
#func _on_body_entered(body):
	#hit.emit()
#
#func _on_score_area_body_entered(body):
	#scored.emit()

extends Area2D

signal hit
signal scored

## Handles incoming physical collision events from player entity
func _on_body_entered(_body: Node2D) -> void:
	hit.emit()

## Tracks passage through scoring boundary between upper and lower obstacles
func _on_score_area_body_entered(_body: Node2D) -> void:
	scored.emit()
