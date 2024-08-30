extends Node2D

signal button_remap_ready
signal button_remap_request
signal button_remapped

const APP_ID = "2862070"

# Data that gets saved
var game_data = {
	"current_level": 1,
	"highest_level": 1,
	"time": 0,
	"level_1_no_jump": false,
	"level_10_no_jump": false,
	"beat_game_achieved": false,
	"speedy_achieved": false,
	"efficient_achieved": false,
}

var settings_data = {
	"volume": -75,
	"fullscreen": false,
	"rotation_input": {
		"key": "Z",
		"key_code": 90
	},
	"jump_input": {
		"key": "X",
		"key_code": 88
	},
	"reset_input": {
		"key": "C",
		"key_code": 67
	},
}

var game
var level_num = 1 # Need this for level select
var remapped_key
var time = 0
var remap_ready = false
var close_window_ready = false
var player_jumped = false

# Music
@export var main_theme: AudioStream
@export var bgm1_theme: AudioStream
@export var bgm2_theme: AudioStream
@export var bgm3_theme: AudioStream
@export var credits_theme: AudioStream

# Trophy images
@export var beat_game_trophy:Texture2D
@export var efficient_trophy:Texture2D
@export var speedy_trophy:Texture2D

func _init():
	OS.set_environment("SteamAppID", APP_ID)
	OS.set_environment("SteamGameID", APP_ID)

func _ready():
	Steam.steamInit()
	var isRunning = Steam.isSteamRunning()
	
	if !isRunning:
		print("ERROR: Steam is not running. Achievements may not save.")
	
	load_settings()
	load_game()
	
	$AudioStreamPlayer.volume_db = $Options/VolumeSlider.value/4
	
	if game_data["beat_game_achieved"]:
		$MainMenu/CanvasLayer/TrophiesMenu/BeatGameTrophy/Sprite2D.texture = beat_game_trophy
		$MainMenu/CanvasLayer/TrophiesMenu/BeatGameTrophy/TrophyDescription/WindowInner/Label.text = "You Earned It: Beat the game"
		
	if game_data["efficient_achieved"]:
		$MainMenu/CanvasLayer/TrophiesMenu/EfficientTrophy/Sprite2D.texture = efficient_trophy
		$MainMenu/CanvasLayer/TrophiesMenu/EfficientTrophy/TrophyDescription/WindowInner/Label.text = "Effecient: Don't jump in levels 1 and 10"
		
	if game_data["speedy_achieved"]:
		$MainMenu/CanvasLayer/TrophiesMenu/SpeedyTrophy/Sprite2D.texture = speedy_trophy
		$MainMenu/CanvasLayer/TrophiesMenu/SpeedyTrophy/TrophyDescription/WindowInner/Label.text = "Speedy: Escape in 5 minutes or less"
	
	game = load("res://Game.tscn")
	$MainMenu.show()
	$MainMenu/CanvasLayer/LevelMenu.hide()
	$MainMenu/CanvasLayer/PlayButton.grab_focus()
	$PauseMenu.hide()
	$Options.hide()
	$MainMenu/CanvasLayer/LevelMenu/FailureWindow.hide()
	$AudioStreamPlayer.play() # Need this or audio spikes on boot up

func _process(delta):
	if remap_ready and (Input.is_action_just_released("select") or Input.is_action_just_released("back")):
		remap_ready = false
	
	if get_node_or_null("MainMenu") != null:
		# Need to check both if the KeyRequest window is open AND remap_ready is false, or remapping gets stuck in a loop.
		if Input.is_action_just_pressed("select") and !remap_ready and !$Options/KeyRequest.visible:
			press_button()
		if Input.is_action_just_pressed("back") and !remap_ready and !$Options/KeyRequest.visible:
			_on_back_button_down()
	elif get_node_or_null("MainMenu") == null:		
		if !get_tree().paused:
			game_data["time"] += delta
		if Input.is_action_just_pressed("pause"):
			if !get_tree().paused:
				get_tree().paused = true
				$PauseMenu.visible = true
				$PauseMenu/Resume.grab_focus()
			elif get_tree().paused:
				get_tree().paused = false
				$PauseMenu.visible = false
				$Options.visible = false
		elif get_tree().paused and !remap_ready and Input.is_action_just_pressed("select") and !$Options/KeyRequest.visible:
			press_button()
		if $Options.visible and Input.is_action_just_pressed("back") and !remap_ready and !$Options/KeyRequest.visible:
			$PauseMenu/Resume.grab_focus()
			$Options.hide()
	if close_window_ready and Input.is_anything_pressed():
		$MainMenu/CanvasLayer/LevelMenu/FailureWindow.hide()
		close_window_ready = false

func _input(event):
	if remap_ready and event is InputEventKey and Input.is_anything_pressed():
		remapped_key = event
		button_remapped.emit()

func press_button():
	match get_viewport().gui_get_focus_owner().name:
		"PlayButton":
			_on_play_button_button_down()
		"NewGameButton":
			_on_new_game_button_button_down()
		"Levels":
			_on_levels_button_down()
		"Options":
			_on_options_button_down()
		"Trophies":
			_on_trophies_button_down()
		"QuitButton":
			_on_quit_button_button_down()
		"Back":
			_on_back_button_down()
		"Resume":
			_on_resume_button_down()
		"MainMenuButton":
			_on_main_menu_button_down()
		"FullscreenCheckButton":
			$Options/FullscreenCheckButton.button_pressed = !$Options/FullscreenCheckButton.button_pressed
			_on_fullscreen_check_button_toggled($Options/FullscreenCheckButton.button_pressed)
			save_settings()
		"SpinInput":
			remap_button("rotation", "SpinInput")
		"JumpInput":
			remap_button("jump", "JumpInput")
		"ResetInput":
			remap_button("reset", "ResetInput")
		# default is selecting a level button
		_:
			if get_viewport().gui_get_focus_owner().is_in_group("level_button"):
				_on__button_down(get_viewport().gui_get_focus_owner().name.to_int())

func remap_button(action_string, node_to_reset):
	# Need this delay or remapping triggers immediately
	$Options/RemapDelayTimer.start()
	$Options/KeyRequest.show()
	await button_remapped
	InputMap.action_erase_events(action_string)
	InputMap.action_add_event(action_string, remapped_key)
	settings_data[action_string + "_input"]["key"] = remapped_key.as_text()
	settings_data[action_string + "_input"]["key_code"] = remapped_key.keycode
	# Need the space or fonts gets messed up
	$Options.get_node(node_to_reset).text = " " + str(settings_data[action_string + "_input"]["key"])
	$Options/KeyRequest.hide()
	save_settings()
	if !Input.is_action_pressed("select") and !Input.is_action_pressed("back"):
		remap_ready = false

func _on_play_button_button_down():
	call_deferred("remove_child", $MainMenu)
	var temp = game.instantiate()
	call_deferred("add_child", temp)
	start_next_music(level_num)
	await temp.tree_entered
	var room = temp.get_node("Room")
	room.s_save_game.connect(save_game)
	room.s_game_beat.connect(beat_the_game)

func _on_new_game_button_button_down():
	game_data["time"] = 0
	level_num = 1
	call_deferred("remove_child", $MainMenu)
	var temp = game.instantiate()
	call_deferred("add_child", temp)
	start_next_music(level_num)
	await temp.tree_entered
	var room = temp.get_node("Room")
	room.s_save_game.connect(save_game)
	room.s_player_jumped.connect(update_player_jumped)
	room.s_game_beat.connect(beat_the_game)

func _on_levels_button_down():
	$MainMenu/CanvasLayer/LevelMenu.show()
	$MainMenu/CanvasLayer/LevelMenu.get_node("1").grab_focus()
	$MainMenu/Logo.rotation += PI / 2

func _on_options_button_down():
	if get_node_or_null("MainMenu") != null:
		$MainMenu/Logo.rotation += PI / 2
	$Options.show()
	$Options/VolumeSlider.grab_focus()

func _on_quit_button_button_down():
	get_tree().quit()

func start_next_music(local_level_num):
	# This match is needed to ensure the correct music plays if player chooses from
	# level select
	match local_level_num:
		1,2,3,4,5,6,7,8,9,10:
			$AudioStreamPlayer.stream = bgm1_theme
			$AudioStreamPlayer.play()
		11,12,13,14,15,16,17,18,19,20:
			$AudioStreamPlayer.stream = bgm2_theme
			$AudioStreamPlayer.play()
		21,22,23,24,25,26,27,28,29,30:
			$AudioStreamPlayer.stream = bgm3_theme
			$AudioStreamPlayer.play()
		31:
			$AudioStreamPlayer.stream = credits_theme
			$AudioStreamPlayer.play()
		_:
			print('error')

func save_game():
	# Need to check if player jumped before increasing level number
	if level_num == 1 and !player_jumped:
		game_data["level_1_no_jump"] = true
	elif level_num == 10 and !player_jumped:
		game_data["level_10_no_jump"] = true
		
	level_num = $Game/Room.level_num
	game_data["current_level"] = level_num
		
	# Achievements
	if int(game_data["highest_level"]) < level_num:
		game_data["highest_level"] = level_num
		
	if game_data["level_1_no_jump"] and game_data["level_10_no_jump"]:
		game_data["efficient_achieved"] = true
		add_steam_achievement("ACH_NO_JUMP")
		
	var file = FileAccess.open("user://save_game.dat", FileAccess.WRITE)
	file.store_string(JSON.stringify(game_data))
	file.close()
	
func save_settings():
	var file = FileAccess.open("user://game_settings.dat", FileAccess.WRITE)
	file.store_string(JSON.stringify(settings_data))
	file.close()
	

func load_game():
	var file = FileAccess.open("user://save_game.dat", FileAccess.READ)
	if file != null:
		var stored_data = file.get_as_text()
		var data = JSON.parse_string(stored_data)
		level_num = int(data["current_level"])
		game_data["highest_level"] = int(data["highest_level"])
		game_data["level_1_no_jump"] = data["level_1_no_jump"]
		game_data["level_10_no_jump"] = data["level_10_no_jump"]
		game_data["beat_game_achieved"] = data["beat_game_achieved"]
		game_data["speedy_achieved"] = data["speedy_achieved"]
		game_data["efficient_achieved"] = data["efficient_achieved"]
		file.close()
		
func load_settings():
	var file = FileAccess.open("user://game_settings.dat", FileAccess.READ)
	if file != null:
		var stored_data = file.get_as_text()
		var data = JSON.parse_string(stored_data)
		$Options/VolumeSlider.value = int(data["volume"])
		$Options/FullscreenCheckButton.button_pressed = bool(data["fullscreen"])

		# Rebind keys
		load_remap("rotation", "SpinInput", data["rotation_input"]["key_code"])
		load_remap("jump", "JumpInput", data["jump_input"]["key_code"])
		load_remap("reset", "ResetInput", data["reset_input"]["key_code"])
		save_settings()
		file.close()

# Remaps buttons based on saved settings data
func load_remap(action_string, node_to_reset, keycode):
	var key = InputEventKey.new()
	key.set_keycode(keycode)
	InputMap.action_erase_events(action_string)
	InputMap.action_add_event(action_string, key)
	# Need the space or fonts gets messed up
	$Options.get_node(node_to_reset).text = " " + InputMap.action_get_events(action_string)[0].as_text()
	settings_data[action_string + "_input"]["key"] = key.as_text()
	settings_data[action_string + "_input"]["key_code"] = key.keycode
	
func _on_back_button_down():
	if get_node_or_null("MainMenu"):
		$MainMenu/CanvasLayer/LevelMenu.hide()
		$MainMenu/CanvasLayer/TrophiesMenu.hide()
		$MainMenu/CanvasLayer/PlayButton.grab_focus()
	else:
		$PauseMenu/Resume.grab_focus()
	$Options.hide()
	
func _on_trophies_button_down():
	$MainMenu/CanvasLayer/TrophiesMenu.show()
	$MainMenu/CanvasLayer/TrophiesMenu/Back.grab_focus()


func _on__button_down(num):
	if num > game_data["highest_level"]:
		$MainMenu/CanvasLayer/LevelMenu/FailureWindow.show()
		$MainMenu/FailDelayTimer.start()
	else:
		level_num = num
		game_data["time"] = 5000
		_on_play_button_button_down()


func _on_resume_button_down():
	get_tree().paused = false
	$PauseMenu.visible = false



func _on_main_menu_button_down():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_volume_slider_value_changed(value):
	$AudioStreamPlayer.volume_db = value / 4
	if $Options/VolumeSlider.value <= -80:
		$AudioStreamPlayer.volume_db = -80

	settings_data["volume"] = $Options/VolumeSlider.value
	save_settings()


func _on_fullscreen_check_button_toggled(toggled_on):
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	settings_data["fullscreen"] = $Options/FullscreenCheckButton.button_pressed
	save_settings()


func _on_remap_delay_timer_timeout():
	remap_ready = true


func _on_godot_link_button_down():
	OS.shell_open("https://godotengine.org/")

func _on_nn_link_button_down():
	OS.shell_open("https://neetnectar.com/")

func _on_fail_delay_timer_timeout():
	close_window_ready = true

# Used for achievement checking
func update_player_jumped():
	player_jumped = true
	
func beat_the_game():
	game_data["beat_game_achieved"] = true
	add_steam_achievement("ACH_GAME_BEAT")
	if game_data["time"] < 300:
		game_data["speedy_achieved"] = true
		add_steam_achievement("ACH_BEAT_5_MIN")

# add achievement on steam
func add_steam_achievement(achievement):
	var status = Steam.getAchievement(achievement)
	if !status["achieved"]:
		Steam.setAchievement(achievement)
		Steam.storeStats()
