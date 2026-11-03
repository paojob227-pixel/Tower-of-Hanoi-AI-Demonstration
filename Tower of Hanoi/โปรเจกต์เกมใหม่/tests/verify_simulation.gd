extends SceneTree

const Solver = preload("res://hanoi_solver.gd")
const Verification = preload("res://hanoi_verification.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for count in range(1, 16):
		var started := Time.get_ticks_msec()
		var result := Verification.verify_small(count)
		print("%d disks: %s (%d ms)" % [count, result, Time.get_ticks_msec() - started])
		if result != "PASS":
			quit(1)
			return
	for count in [32, 64, 100]:
		var result := Verification.verify_large(count)
		print("%d disks: %s" % [count, result])
		if result != "PASS":
			quit(1)
			return
	assert(Solver.normalize("00015") == "15")
	assert(Solver.normalize("1.5") == "")
	assert(Solver.normalize("-1") == "")
	assert(not Solver.valid_index("1267650600228229401496703205376", 100))
	assert(Solver.divide("1267650600228229401496703205375", "86400") == "14671881947085988443248879")
	assert(Solver.add("18446744073709551615", "1") == "18446744073709551616")
	assert(Solver.subtract("1000000000000000000000000000000", "1") == "999999999999999999999999999999")
	var game = load("res://hanoi_game.gd").new()
	root.add_child(game)
	game.set_process(false)
	game.animations_enabled = false
	game._reset_game(3)
	game._handle_peg_click(0)
	game._handle_peg_click(2)
	assert(game.pegs[2] == [1] and game.move_count == "1")
	assert(not game._move_disc(0, 2))
	game._on_start()
	while game.ai_running:
		game._play_next_ai_move()
	assert(game._is_solved() and game.move_count == "7")
	game._reset_game(5)
	game._on_step()
	assert(game.move_count == "1" and game.ai_paused)
	game._resume_ai()
	game._pause_ai()
	assert(game.ai_paused and not game.ai_running)
	game._resume_ai()
	while game.ai_running:
		game._play_next_ai_move()
	assert(game.move_count == "31" and game._is_solved())
	game._one_day_experiment()
	assert(game.disc_count == 100 and game.mode == game.Mode.ULTRA)
	var sample := "633825300114114700748351602687"
	game._jump_to(sample)
	assert(game.simulated_move == sample)
	assert(game.move_count == "0")
	assert(game.pegs == Solver.state_at(sample, 100))
	game._jump_to(Solver.subtract(game.best_count, "1"))
	assert(game.sim_label.text.contains("99.999999999%"))
	game._jump_to(sample)
	game.elapsed_us = 43200000000
	assert(game._time_index() == sample)
	game._on_start()
	game._pause_ai()
	var paused: int = game.elapsed_us
	game._process(1.0)
	assert(game.elapsed_us == paused)
	game._resume_ai()
	assert(game.ai_running)
	game.elapsed_us = game.duration_us
	game._apply_simulation_index(game._time_index())
	assert(game._is_solved() and not game.ai_running)
	assert(game.simulated_move == game.best_count and game.move_count == "0")
	assert(game.status_label.text == "SOLVED - Optimal Solution Verified")
	game._jump_to("0")
	game._jump_to("-1")
	assert(game.simulated_move == "0" and game.status_label.text.begins_with("ERROR"))
	game._on_step()
	assert(game.simulated_move == "1" and game.move_count == "0")
	game._on_duration_changed(1)
	assert(game.duration_us == 60000000)
	game._on_duration_changed(2)
	assert(game.duration_us == 3600000000)
	game._on_duration_changed(3)
	assert(game.duration_us == 86400000000)
	game.duration_selector.selected = 4
	game.duration_input.value = 12.5
	assert(game.duration_us == 12500000)
	game._on_duration_changed(0)
	game._on_speed_changed(0.5)
	game.elapsed_us = 1500000
	assert(game._time_index() == "3")
	# The AI must stop and retain an actionable report if the board is corrupted.
	game._reset_game(3)
	game.mode = game.Mode.VISUAL
	game.pegs[0] = [3, 1, 2]
	game._on_start()
	game._play_next_ai_move()
	assert(not game.ai_running and game.error_message.contains("Move: 1"))
	assert(game.error_message.contains("disk: 1"))
	var start_us := Time.get_ticks_usec()
	for i in range(100):
		Solver.state_at(sample, 100)
	print("100-disk direct state: %.3f ms/query" % ((Time.get_ticks_usec() - start_us) / 100000.0))
	print("ALL TESTS PASSED: recursive 1-15, large samples, manual, visual 3/5, jump, one-day, error stop")
	quit()
