extends Node

var bgm_player: AudioStreamPlayer
var ingame_stream = preload("res://assets/Audio/FMB Ingamever.mp3")
var is_playing_ingame = false
var fade_tween: Tween

func _ready():
	bgm_player = AudioStreamPlayer.new()
	bgm_player.stream = ingame_stream
	bgm_player.pitch_scale = 0.85
	bgm_player.volume_db = -8.0
	bgm_player.finished.connect(func():
		if is_playing_ingame:
			bgm_player.play()
	)
	add_child(bgm_player)

func _process(_delta):
	var current_scene = get_tree().current_scene
	if current_scene:
		var scene_name = current_scene.name
		var scene_path = current_scene.scene_file_path
		
		# Scene Non-Gameplay (Main Menu & Splash Screen)
		if scene_name == "MainMenu" or scene_name == "SplashScreen" or scene_path == "res://MainMenu.tscn" or scene_path == "res://SplashScreen.tscn":
			if is_playing_ingame:
				stop_ingame_bgm()
		else:
			# Scene Gameplay (Beginning, TheBond, Minigame, Jumpscare, Endings, dll.)
			if not is_playing_ingame:
				play_ingame_bgm()

func play_ingame_bgm():
	if is_playing_ingame and bgm_player.playing:
		return
		
	is_playing_ingame = true
	if not bgm_player.playing:
		bgm_player.play()
		
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
		
	fade_tween = create_tween()
	fade_tween.tween_property(bgm_player, "volume_db", -8.0, 1.0)

func stop_ingame_bgm():
	if not is_playing_ingame:
		return
		
	is_playing_ingame = false
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
		
	fade_tween = create_tween()
	fade_tween.tween_property(bgm_player, "volume_db", -50.0, 1.0)
	fade_tween.finished.connect(func():
		if not is_playing_ingame:
			bgm_player.stop()
	)
