extends Node

signal scene_change_started(scene_path: String)
signal scene_change_completed(scene_path: String)

var _current_scene: Node
var _current_scene_path := ""
var is_transitioning := false


func change_scene(scene_path: String, transition: String = "fade") -> void:
	if is_transitioning or scene_path.is_empty():
		return

	var scene_container := _get_scene_container()
	if scene_container == null:
		push_warning("Scene container not found in Main scene.")
		return

	if not ResourceLoader.exists(scene_path, "PackedScene"):
		push_warning("Scene does not exist: %s" % scene_path)
		return

	is_transitioning = true
	scene_change_started.emit(scene_path)

	var transition_effect := _get_transition_effect()
	await _play_transition_out(transition_effect, transition)
	await get_tree().create_timer(0.3).timeout

	if is_instance_valid(_current_scene):
		var previous_scene := _current_scene
		_current_scene = null
		previous_scene.queue_free()
		await previous_scene.tree_exited

	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		push_warning("Failed to load scene: %s" % scene_path)
		await _play_transition_in(transition_effect, transition)
		is_transitioning = false
		return

	_current_scene = packed_scene.instantiate()
	_current_scene_path = scene_path
	# Start invisible so _ready() default values aren't visible to player
	if _current_scene is CanvasItem:
		_current_scene.modulate.a = 0.0
		_current_scene.visible = false
	scene_container.add_child(_current_scene)

	await _play_transition_in(transition_effect, transition)
	# Fade in the scene content itself (setup should have been called by now)
	if is_instance_valid(_current_scene) and _current_scene is CanvasItem:
		_current_scene.visible = true
		var scene_tween := create_tween()
		scene_tween.tween_property(_current_scene, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	scene_change_completed.emit(scene_path)
	is_transitioning = false


func reload_current_scene() -> void:
	if _current_scene_path.is_empty():
		return

	change_scene(_current_scene_path)


func get_current_scene() -> Node:
	return _current_scene


func _get_scene_container() -> Node:
	var main_scene := get_tree().current_scene
	if main_scene == null:
		return null

	return main_scene.get_node_or_null("CurrentScene")


func _get_transition_effect() -> ColorRect:
	var main_scene := get_tree().current_scene
	if main_scene == null:
		return null

	return main_scene.get_node_or_null("UILayer/TransitionEffect") as ColorRect


func _play_transition_out(transition_effect: ColorRect, transition: String) -> void:
	if transition_effect == null or transition != "fade":
		return

	transition_effect.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(transition_effect, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tween.finished


func _play_transition_in(transition_effect: ColorRect, transition: String) -> void:
	if transition_effect == null or transition != "fade":
		return

	transition_effect.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(transition_effect, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
