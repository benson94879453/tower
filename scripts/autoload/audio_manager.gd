extends Node

signal bgm_changed(track_name: String)

const SFX_POOL_SIZE := 8

var _bgm_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _current_bgm := ""
var _bgm_tween: Tween
var _next_sfx_index := 0

var bgm_volume: float = 0.8
var sfx_volume: float = 1.0


func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.volume_db = _linear_to_db_safe(bgm_volume)
	add_child(_bgm_player)

	for index in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer%d" % index
		player.volume_db = _linear_to_db_safe(sfx_volume)
		add_child(player)
		_sfx_players.append(player)


func play_bgm(track_name: String, fade_duration: float = 1.0) -> void:
	if track_name.is_empty():
		stop_bgm(fade_duration)
		return

	if _current_bgm == track_name and _bgm_player.playing:
		return

	var stream_path := _get_bgm_path(track_name)
	if not ResourceLoader.exists(stream_path):
		push_warning("Missing BGM stream: %s" % stream_path)
		return

	var stream := load(stream_path) as AudioStream
	if stream == null:
		push_warning("Failed to load BGM stream: %s" % stream_path)
		return

	if _bgm_tween:
		_bgm_tween.kill()

	if _bgm_player.playing and fade_duration > 0.0:
		_bgm_tween = create_tween()
		_bgm_tween.tween_property(_bgm_player, "volume_db", -80.0, fade_duration)
		await _bgm_tween.finished
		_bgm_player.stop()

	_bgm_player.stream = stream
	_bgm_player.volume_db = -80.0 if fade_duration > 0.0 else _linear_to_db_safe(bgm_volume)
	_bgm_player.play()

	if fade_duration > 0.0:
		_bgm_tween = create_tween()
		_bgm_tween.tween_property(_bgm_player, "volume_db", _linear_to_db_safe(bgm_volume), fade_duration)
	else:
		_bgm_player.volume_db = _linear_to_db_safe(bgm_volume)

	_current_bgm = track_name
	bgm_changed.emit(track_name)


func stop_bgm(fade_duration: float = 1.0) -> void:
	if not _bgm_player.playing:
		_current_bgm = ""
		return

	if _bgm_tween:
		_bgm_tween.kill()

	if fade_duration > 0.0:
		_bgm_tween = create_tween()
		_bgm_tween.tween_property(_bgm_player, "volume_db", -80.0, fade_duration)
		await _bgm_tween.finished

	_bgm_player.stop()
	_bgm_player.volume_db = _linear_to_db_safe(bgm_volume)
	_current_bgm = ""


func play_sfx(sfx_name: String) -> void:
	if sfx_name.is_empty():
		return

	var stream_path := _get_sfx_path(sfx_name)
	if not ResourceLoader.exists(stream_path):
		push_warning("Missing SFX stream: %s" % stream_path)
		return

	var stream := load(stream_path) as AudioStream
	if stream == null:
		push_warning("Failed to load SFX stream: %s" % stream_path)
		return

	var player := _get_available_sfx_player()
	player.stream = stream
	player.volume_db = _linear_to_db_safe(sfx_volume)
	player.play()


func set_bgm_volume(volume: float) -> void:
	bgm_volume = clampf(volume, 0.0, 1.0)
	if _bgm_player:
		_bgm_player.volume_db = _linear_to_db_safe(bgm_volume)


func set_sfx_volume(volume: float) -> void:
	sfx_volume = clampf(volume, 0.0, 1.0)
	for player in _sfx_players:
		player.volume_db = _linear_to_db_safe(sfx_volume)


func _get_bgm_path(track_id: String) -> String:
	return "res://assets/audio/bgm/%s.ogg" % track_id


func _get_sfx_path(sfx_id: String) -> String:
	return "res://assets/audio/sfx/%s.ogg" % sfx_id


func _get_available_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player

	var player := _sfx_players[_next_sfx_index]
	_next_sfx_index = (_next_sfx_index + 1) % _sfx_players.size()
	return player


func _linear_to_db_safe(volume: float) -> float:
	if volume <= 0.0:
		return -80.0

	return linear_to_db(volume)
