extends Node2D

signal s_save_game
signal s_player_jumped
signal s_game_beat

var level_num = 1
var next_level
var level_loaded = true
@export var pink_gate_scene: PackedScene
var pink_gate
var fake_pink_gate
var dialogue_open = false
var dialogue_finished
var dialogue_index = 0

func _ready():
	level_num = get_parent().get_parent().level_num
	$Player.position = Vector2(0, 256)
	next_level = load("res://Levels/level_" + str(level_num) + ".tscn").instantiate()
	next_level.position = Vector2(0,0)
	add_child(next_level)
	get_node("Level").level_complete.connect(load_next_level)
	get_node("Level").level_failed.connect(reset_player)
	$CanvasLayer/DialogueBox.hide()
		
func _process(delta):
	if level_num == 31:
		if $Level/ColorRect/Label.position.y > -216:
			$Level/ColorRect/Label.position.y -= delta * 50
		
	
func load_next_level():
	if level_loaded:
		level_loaded = false
		level_num += 1
		if level_num != 31:
			print('saved')
			s_save_game.emit()
		print(level_num)
		if level_num == 11 or level_num == 21 or level_num == 31:
			# God this is ugly, I should fix
			get_parent().get_parent().start_next_music(level_num)
			
		match level_num:
			17,18,19,20,25,26,27,28,29:
				fake_pink_gate = pink_gate_scene.instantiate()
				fake_pink_gate.position = Vector2(200, -192)
				call_deferred("add_child", fake_pink_gate)
			21,22,23,24,30:
				if pink_gate != null:
					pink_gate.queue_free()
				for child in get_children():
					if child.is_in_group("pink_gate"):
						child.queue_free()
		
		if level_num >= 31:
			s_game_beat.emit()
			next_level = load("res://Levels/credits_room.tscn")
		else:
			next_level = load("res://Levels/level_" + str(level_num) + ".tscn")
		reset_player()
		
		# Remove current level and load next level
		get_node("Level").call_deferred("free")
		next_level = next_level.instantiate() 
		next_level.position = Vector2(0,0)
		call_deferred("add_child", next_level)
		next_level.level_complete.connect(load_next_level)
		
		if level_num == 21:
			call_deferred("remove_child", pink_gate)
			call_deferred("remove_child", fake_pink_gate)
		$LoadTimer.start()

func reset_player():
	$Player.position = Vector2(0, 256)
	print($Player.position)
	$Player.jump_force = 0
	$Player.jumping = false

# Used to delay some operations until level is loaded
func _on_load_timer_timeout():
	level_loaded = true
	# Load pink gate
	match level_num:
		17,18,19,20,25,26,27,28,29:
			if pink_gate == null:
				pink_gate = pink_gate_scene.instantiate()
				pink_gate.position = Vector2(200, -192)
				call_deferred("add_child", pink_gate)
				call_deferred("remove_child", fake_pink_gate)
				print(pink_gate)
			pink_gate.body_entered.connect($Level._on_pink_gate_body_entered)
	
	# Connect level failure/reset signal
	if !get_node("Level").level_failed.is_connected(reset_player):
		get_node("Level").level_failed.connect(reset_player)
	
	if level_num == 31 and get_parent().get_parent().game_data["time"] < 5000:
		var minutes = int(get_parent().get_parent().game_data["time"])/60
		var seconds = int(get_parent().get_parent().game_data["time"]) % 60
		if seconds < 10:
			seconds = "0"+str(seconds)
		$Level/ColorRect/Label.text = "ESCAPED\n\nThanks for playing!\n\nCode and Design:\nAce Nettner\n\nArt:\nTyphlotic Turtle\n\nMusic:\n\nSatangent\n\nTIME:\n" + str(minutes) + ":" + str(seconds) + ""


func _on_player_s_jumped():
	s_player_jumped.emit()
	
