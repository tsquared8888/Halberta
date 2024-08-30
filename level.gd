extends Node2D

signal level_complete
signal level_failed
var in_gate = false
var in_spikes = false
var delay_timer
var player

func _process(delta):
	if (in_spikes and not player.rotating) or Input.is_action_pressed("reset"):
		rotation = 0
		in_spikes = false
		level_failed.emit()

func _physics_process(delta):
	if get_node_or_null("GreenGate") != null and $GreenGate.has_overlapping_bodies():
		var bodies = $GreenGate.get_overlapping_bodies()
		for i in len(bodies):
			if bodies[i].name == "Player" and bodies[i].is_grounded and in_gate:
				level_complete.emit()
			

func _on_blue_gate_body_entered(body):
	if body.name == "Player":
		level_complete.emit()


func _on_green_gate_body_entered(body):
	if body.name == "Player":
		in_gate = true

func _on_green_gate_body_exited(body):
	if body.name == "Player":
		in_gate = false

func _on_gold_gate_body_entered(body):
	if body.name == "Player":
		level_complete.emit()


func _on_pink_gate_body_entered(body):
	if body.name == "Player":
		level_complete.emit()

func _on_spikes_body_entered(body):
	if body.name == "Player":
		player = body
		delay_timer = Timer.new()
		add_child(delay_timer)
		delay_timer.timeout.connect(_on_delay_timer_timeout)
		delay_timer.wait_time = 0.025
		delay_timer.one_shot = true
		delay_timer.start()

func _on_spikes_body_exited(body):
	if body.name == "Player":
		in_spikes = false
		
func _on_delay_timer_timeout():
	in_spikes = true
