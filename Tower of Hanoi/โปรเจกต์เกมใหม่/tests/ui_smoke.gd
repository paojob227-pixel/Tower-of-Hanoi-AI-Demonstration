extends SceneTree

var game: Node
var output := "C:/Users/paojo/Desktop/Tower of Hanoi/"


func _initialize() -> void:
	call_deferred("_run")


func _capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	assert(not picture.is_empty())
	assert(picture.get_pixel(260, 790) != picture.get_pixel(50, 700))
	picture.save_png(output + name + ".png")


func _click(position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	root.push_input(event)
	event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = position
	root.push_input(event)


func _run() -> void:
	game = load("res://hanoi_game.gd").new()
	root.add_child(game)
	await _capture("hanoi_manual")
	_click(Vector2(264, 760))
	_click(Vector2(936, 760))
	assert(game.move_count == "1")
	assert(game.pegs[2] == [1])
	game._on_reset_pressed()
	game._on_start()
	await create_timer(0.15).timeout
	assert(game.animated_disc == 1)
	await _capture("hanoi_visual")
	game._pause_ai()
	var frozen: Vector2 = game.animated_position
	await create_timer(0.15).timeout
	assert(game.animated_position == frozen)
	game._resume_ai()
	await create_timer(0.25).timeout
	game._on_stop()
	game._one_day_experiment()
	game._jump_to("633825300114114700748351602687")
	await _capture("hanoi_ultra")
	game._on_start()
	await create_timer(0.3).timeout
	assert(game.elapsed_us > 43200000000 and game.move_count == "0")
	game._pause_ai()
	game._jump_to(game.best_count)
	await _capture("hanoi_solved")
	assert(game._is_solved())
	game._show_towers()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + "hanoi_tower_state.png")
	for child in game.ui_layer.get_children():
		if child is AcceptDialog:
			child.queue_free()
	await game._run_verification()
	assert(game.status_label.text == "ALL TESTS PASSED")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + "hanoi_verification.png")
	print("PASS: real mouse input, rendered animation, pause/resume, live simulation, final state, screenshots")
	quit()
