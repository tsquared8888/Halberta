extends Node2D

var rot_speed = 5
var spinning = false
# Called when the node enters the scene tree for the first time.
func _ready():
	$Logo.rotation = 0


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if spinning:
		$Logo.rotation += delta * rot_speed
		if $Logo.rotation > 6:
			spinning = false
			$Logo.rotation = 0
			$LogoSpinTimer.start()


func _on_logo_spin_timer_timeout():
	spinning = true
