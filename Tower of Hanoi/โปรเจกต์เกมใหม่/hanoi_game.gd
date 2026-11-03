extends Node2D

const Solver = preload("res://hanoi_solver.gd")
const Verification = preload("res://hanoi_verification.gd")
enum Mode { MANUAL, VISUAL, ULTRA }
const MIN_DISCS := 1
const MAX_DISCS := 100
const START_DISCS := 4

var disc_count := START_DISCS
var pegs: Array[Array] = []
var selected_peg := -1
var move_count := "0"
var best_count := "0"

var ai_moves: Array[Vector3i] = []
var ai_running := false
var ai_paused := false
var ai_timer := 0.0
var ai_step_time := 0.6

var ui_layer: CanvasLayer
var disc_label: Label
var move_label: Label
var status_label: Label
var ai_button: Button
var speed_label: Label
var discs_spin: SpinBox
var speed_slider: HSlider
var mode := Mode.MANUAL
var mode_selector: OptionButton
var duration_selector: OptionButton
var duration_input: SpinBox
var speed_input: SpinBox
var jump_input: LineEdit
var stats_label: Label
var sim_label: Label
var last_label: Label
var simulation_controls: VBoxContainer
var note_label: Label
var canonical := true
var simulated_move := "0"
var duration_us := 86400000000
var elapsed_us := 0
var last_tick_us := 0
var refresh_us := 0
var clock_real := false
var error_message := ""
var last_move: Dictionary = {}
var animation: Tween
var animated_disc := -1
var animated_position := Vector2.ZERO
var animations_enabled := true
var pause_button: Button
var resume_button: Button
var step_button: Button
var verify_button: Button
var verifying := false


func _ready() -> void:
	_build_ui()
	_reset_game(START_DISCS)
	get_viewport().size_changed.connect(queue_redraw)
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if animated_disc > 0:
		queue_redraw()
	if ai_running:
		if mode == Mode.ULTRA:
			var now := Time.get_ticks_usec()
			elapsed_us += now - last_tick_us
			if not clock_real:
				elapsed_us = mini(elapsed_us, duration_us)
			last_tick_us = now
			if now - refresh_us >= 100000 or elapsed_us == duration_us:
				refresh_us = now
				_apply_simulation_index(_time_index())
			return
		ai_timer += delta
		if animation != null and animation.is_running():
			return
		if ai_timer >= ai_step_time:
			ai_timer = 0.0
			_play_next_ai_move()


func _unhandled_input(event: InputEvent) -> void:
	if mode != Mode.MANUAL or ai_running or ai_paused or verifying:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var peg_index := _peg_at_position(event.position)
		if peg_index != -1:
			_handle_peg_click(peg_index)


func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.075, 0.08, 0.085))
	_draw_title_band(size)
	_draw_board(size)


func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(root)

	var rows := VBoxContainer.new()
	rows.position = Vector2(20, 14)
	rows.size = Vector2(1160, 350)
	rows.add_theme_constant_override("separation", 6)
	root.add_child(rows)
	var title := Label.new()
	title.text = "Tower of Hanoi AI Demonstration"
	title.add_theme_font_size_override("font_size", 24)
	rows.add_child(title)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	rows.add_child(top_row)
	top_row.add_child(_button("-", func(): discs_spin.value -= 1))

	discs_spin = SpinBox.new()
	discs_spin.min_value = MIN_DISCS
	discs_spin.max_value = MAX_DISCS
	discs_spin.step = 1
	discs_spin.value = START_DISCS
	discs_spin.custom_minimum_size = Vector2(82, 34)
	discs_spin.value_changed.connect(_on_disc_count_changed)
	top_row.add_child(_labeled_control("Discs", discs_spin))
	top_row.add_child(_button("+", func(): discs_spin.value += 1))
	mode_selector = OptionButton.new()
	for text in ["Manual Mode", "AI Visual Mode", "Ultra Simulation"]:
		mode_selector.add_item(text)
	mode_selector.item_selected.connect(_on_mode_changed)
	top_row.add_child(mode_selector)
	top_row.add_child(_button("Reset", _on_reset_pressed))
	verify_button = _button("Verify AI", _run_verification)
	top_row.add_child(verify_button)
	top_row.add_child(_button("Tower State", _show_towers))
	var ai_row := HBoxContainer.new()
	ai_row.add_theme_constant_override("separation", 8)
	rows.add_child(ai_row)
	ai_button = _button("Start AI", _on_start)
	ai_row.add_child(ai_button)
	pause_button = _button("Pause", _pause_ai)
	ai_row.add_child(pause_button)
	resume_button = _button("Resume", _resume_ai)
	ai_row.add_child(resume_button)
	ai_row.add_child(_button("Stop", _on_stop))
	step_button = _button("Step One Move", _on_step)
	ai_row.add_child(step_button)
	status_label = Label.new()
	status_label.custom_minimum_size.x = 460
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ai_row.add_child(status_label)

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 10)
	rows.add_child(bottom_row)

	speed_slider = HSlider.new()
	speed_slider.min_value = 0.0
	speed_slider.max_value = 2.0
	speed_slider.step = 0.01
	speed_slider.value = ai_step_time
	speed_slider.custom_minimum_size = Vector2(210, 28)
	speed_slider.value_changed.connect(_on_speed_changed)
	bottom_row.add_child(_labeled_control("Seconds / move", speed_slider))
	speed_input = SpinBox.new()
	speed_input.min_value = 0
	speed_input.max_value = 3600
	speed_input.step = 0.001
	speed_input.value = ai_step_time
	speed_input.value_changed.connect(_on_speed_changed)
	bottom_row.add_child(speed_input)
	var presets := OptionButton.new()
	for text in ["Speed preset", "1.0 s", "0.5 s", "0.1 s", "0.05 s", "0.01 s", "Maximum Visual Speed"]:
		presets.add_item(text)
	presets.item_selected.connect(func(index: int):
		if index > 0:
			_on_speed_changed([1.0, 0.5, 0.1, 0.05, 0.01, 0.0][index - 1]))
	bottom_row.add_child(presets)

	speed_label = Label.new()
	speed_label.custom_minimum_size = Vector2(84, 28)
	speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom_row.add_child(speed_label)

	simulation_controls = VBoxContainer.new()
	rows.add_child(simulation_controls)
	var duration_row := HBoxContainer.new()
	simulation_controls.add_child(duration_row)
	duration_selector = OptionButton.new()
	for text in ["Real", "1 minute", "1 hour", "1 Day (24 hours)", "Custom"]:
		duration_selector.add_item(text)
	duration_selector.selected = 3
	duration_selector.item_selected.connect(_on_duration_changed)
	duration_row.add_child(_labeled_control("Simulation Duration", duration_selector))
	duration_input = SpinBox.new()
	duration_input.min_value = 0.001
	duration_input.max_value = 86400000
	duration_input.step = 0.001
	duration_input.value = 86400
	duration_input.value_changed.connect(func(value: float):
		if duration_selector.selected == 4:
			_set_duration(value))
	duration_row.add_child(_labeled_control("Custom seconds", duration_input))
	duration_row.add_child(_button("100 DISK - 24 HOUR SIMULATION", _one_day_experiment))
	var jump_row := HBoxContainer.new()
	simulation_controls.add_child(jump_row)
	jump_input = LineEdit.new()
	jump_input.custom_minimum_size.x = 430
	jump_input.placeholder_text = "0 .. total moves (exact decimal integer)"
	jump_input.text_submitted.connect(func(_text: String): _on_jump())
	jump_row.add_child(_labeled_control("Jump to Move", jump_input))
	jump_row.add_child(_button("Go", _on_jump))
	jump_row.add_child(_button("Final Move", func(): _jump_to(best_count)))
	stats_label = Label.new()
	stats_label.add_theme_font_size_override("font_size", 15)
	rows.add_child(stats_label)
	move_label = Label.new()
	move_label.add_theme_font_size_override("font_size", 15)
	rows.add_child(move_label)
	sim_label = Label.new()
	sim_label.add_theme_font_size_override("font_size", 15)
	rows.add_child(sim_label)
	last_label = Label.new()
	last_label.add_theme_font_size_override("font_size", 15)
	rows.add_child(last_label)
	note_label = Label.new()
	note_label.text = "Ultra Simulation computes the mathematically exact Tower of Hanoi state without physically executing every intermediate move."
	note_label.add_theme_font_size_override("font_size", 13)
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(note_label)
	_update_mode_ui()


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 30
	button.pressed.connect(callback)
	return button


func _labeled_control(text: String, control: Control) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(label)
	box.add_child(control)
	return box


func _reset_game(new_disc_count: int) -> void:
	disc_count = clampi(new_disc_count, MIN_DISCS, MAX_DISCS)
	pegs = [[], [], []]
	for disc in range(disc_count, 0, -1):
		pegs[0].append(disc)
	selected_peg = -1
	move_count = "0"
	simulated_move = "0"
	canonical = true
	elapsed_us = 0
	error_message = ""
	last_move = {}
	_cancel_animation()
	best_count = _optimal_count(disc_count)
	_stop_ai()
	_update_ui("Ready.")
	queue_redraw()


func _handle_peg_click(peg_index: int) -> void:
	if selected_peg == -1:
		if pegs[peg_index].is_empty():
			_update_ui("That tower is empty. Pick a disc first.")
			return
		selected_peg = peg_index
		_update_ui("Selected tower %d. Click a destination." % [peg_index + 1])
		queue_redraw()
		return

	if selected_peg == peg_index:
		selected_peg = -1
		_update_ui("Selection cleared.")
		queue_redraw()
		return

	if _move_disc(selected_peg, peg_index):
		selected_peg = -1
		if _is_solved():
			_update_ui("SOLVED")
		else:
			_update_ui("Good move.")
	else:
		_update_ui("Illegal move: a larger disc cannot go on a smaller disc.")
	queue_redraw()


func _move_disc(from_peg: int, to_peg: int) -> bool:
	if from_peg < 0 or from_peg >= 3 or to_peg < 0 or to_peg >= 3:
		return false
	if pegs[from_peg].is_empty():
		return false

	var disc: int = pegs[from_peg].back()
	if not is_valid_move(disc, from_peg, to_peg):
		return false
	var old_position := _disc_position(from_peg, pegs[from_peg].size() - 1)
	pegs[from_peg].pop_back()
	pegs[to_peg].append(disc)
	move_count = Solver.add(move_count, "1")
	last_move = {"move": Solver.add(simulated_move, "1") if canonical else move_count, "disk": disc, "from": from_peg, "to": to_peg}
	if mode == Mode.MANUAL:
		canonical = false
	if canonical and mode != Mode.ULTRA:
		simulated_move = Solver.add(simulated_move, "1")
	if mode == Mode.VISUAL and animations_enabled and ai_step_time >= 0.05:
		_animate_disc(disc, old_position, _disc_position(to_peg, pegs[to_peg].size() - 1))
	_update_move_label()
	return true


func is_valid_move(disc: int, from_peg: int, to_peg: int) -> bool:
	return Solver.valid_move(pegs, disc, from_peg, to_peg)


func _is_solved() -> bool:
	return pegs[2].size() == disc_count


func _on_disc_count_changed(value: float) -> void:
	_reset_game(int(value))


func _on_reset_pressed() -> void:
	discs_spin.value = disc_count
	_reset_game(disc_count)


func _on_ai_button_pressed() -> void:
	if mode == Mode.MANUAL:
		mode = Mode.VISUAL
		_update_mode_ui()
	if ai_running:
		_pause_ai()
		_update_ui("AI paused.")
		return

	if ai_paused and not ai_moves.is_empty():
		_resume_ai()
		_update_ui("AI resumed.")
		return

	if _is_solved():
		_update_ui("Already solved.")
		return
	if not Solver.validate_state(pegs, disc_count):
		var expected := Solver.get_move_at(Solver.add(simulated_move, "1"), disc_count) if canonical else {"move": Solver.add(move_count, "1"), "disk": -1, "from": -1, "to": -1}
		_fail_move(expected, "Invalid board state")
		return
	ai_moves.clear()
	ai_moves.append(Vector3i(disc_count, -1, 2))
	ai_running = true
	ai_paused = false
	ai_timer = ai_step_time
	selected_peg = -1
	ai_button.text = "Start AI"
	_update_ui("AI taking the shortest route.")
	queue_redraw()


func _disc_peg(disc: int) -> int:
	for peg in range(3):
		if pegs[peg].has(disc):
			return peg
	return -1


func _on_mode_changed(index: int) -> void:
	_on_stop()
	mode = index
	if mode == Mode.ULTRA and not canonical:
		_reset_game(disc_count)
	_update_mode_ui()
	_update_ui("Ready.")
	queue_redraw()


func _update_mode_ui() -> void:
	mode_selector.selected = mode
	simulation_controls.visible = mode == Mode.ULTRA
	note_label.visible = mode == Mode.ULTRA


func _on_start() -> void:
	if verifying or not error_message.is_empty():
		return
	if mode == Mode.MANUAL:
		mode = Mode.VISUAL
		_update_mode_ui()
	if mode == Mode.ULTRA:
		if simulated_move == best_count:
			_finish()
			return
		ai_running = true
		ai_paused = false
		last_tick_us = Time.get_ticks_usec()
		_update_ui("Mathematical simulation running.")
	else:
		if ai_paused:
			_resume_ai()
		elif not ai_running:
			_on_ai_button_pressed()


func _on_stop() -> void:
	_stop_ai()
	_cancel_animation()
	_update_ui("Stopped. Board preserved.")
	queue_redraw()


func _on_step() -> void:
	if verifying or ai_running or not error_message.is_empty():
		return
	_cancel_animation()
	if mode == Mode.ULTRA:
		if simulated_move != best_count:
			_jump_to(Solver.add(simulated_move, "1"))
		return
	if mode == Mode.MANUAL:
		mode = Mode.VISUAL
		_update_mode_ui()
	if _is_solved():
		return
	if ai_moves.is_empty():
		ai_moves.append(Vector3i(disc_count, -1, 2))
	_play_next_ai_move()
	if not _is_solved() and error_message.is_empty():
		ai_paused = true
		_update_ui("One move executed. Paused.")


func _set_duration(seconds: float) -> void:
	_pause_ai()
	clock_real = false
	duration_us = clampi(int(round(seconds * 1000000.0)), 1000, 86400000000000)
	elapsed_us = int(Solver.divide(Solver.multiply_small(simulated_move, duration_us), best_count))
	_update_ui("Simulation duration updated.")


func _on_duration_changed(index: int) -> void:
	if index == 0:
		_pause_ai()
		clock_real = true
		elapsed_us = 0
		_apply_simulation_index("0")
		_update_ui("Real time scale: mathematical state sampling.")
	else:
		var seconds: float = [60.0, 3600.0, 86400.0, duration_input.value][index - 1]
		_set_duration(seconds)
	duration_input.editable = index == 4


func _one_day_experiment() -> void:
	_on_stop()
	discs_spin.set_value_no_signal(100)
	mode = Mode.ULTRA
	duration_selector.selected = 3
	duration_input.set_value_no_signal(86400)
	clock_real = false
	duration_us = 86400000000
	_reset_game(100)
	_update_mode_ui()
	_update_ui("100 DISK - 24 HOUR SIMULATION ready.")


func _time_index() -> String:
	if clock_real:
		var interval_us := maxi(1, int(round(ai_step_time * 1000000.0)))
		var index := str(elapsed_us / interval_us)
		return best_count if Solver.compare(index, best_count) > 0 else index
	return Solver.index_for_time(best_count, elapsed_us, duration_us)


func _on_jump() -> void:
	_jump_to(jump_input.text.strip_edges())


func _jump_to(value: String) -> void:
	var index := Solver.normalize(value)
	if not Solver.valid_index(index, disc_count):
		_update_ui("ERROR: Jump must be a decimal integer in 0..total moves.")
		return
	_pause_ai()
	_cancel_animation()
	if clock_real:
		clock_real = false
		duration_selector.selected = 3
		duration_us = 86400000000
	elapsed_us = int(Solver.divide(Solver.multiply_small(index, duration_us), best_count))
	_apply_simulation_index(index)
	jump_input.text = index
	if error_message.is_empty() and index != best_count:
		_update_ui("Exact state at move %s." % index)


func _apply_simulation_index(index: String) -> void:
	var next_state := Solver.state_at(index, disc_count)
	if not Solver.validate_state(next_state, disc_count):
		_fail_move({"move": index, "disk": -1, "from": -1, "to": -1}, "Invalid simulated state")
		return
	var sampled: Dictionary = {}
	if index != "0":
		sampled = Solver.get_move_at(index, disc_count)
		var previous := Solver.state_at(Solver.subtract(index, "1"), disc_count)
		if not Solver.valid_move(previous, sampled.disk, sampled.from, sampled.to):
			_fail_move(sampled, "Invalid sampled transition")
			return
		previous[sampled.from].pop_back()
		previous[sampled.to].append(sampled.disk)
		if previous != next_state:
			_fail_move(sampled, "Sampled transition/state mismatch")
			return
	pegs = next_state
	simulated_move = index
	canonical = true
	selected_peg = -1
	last_move = sampled
	if index == best_count:
		_finish()
	else:
		_update_move_label()
	queue_redraw()


func _finish() -> void:
	_stop_ai()
	if not _is_solved() or not Solver.validate_state(pegs, disc_count):
		_fail_move(last_move, "Final state mismatch")
		return
	_update_ui("SOLVED - Optimal Solution Verified")


func _fail_move(details: Dictionary, reason: String = "Invalid AI move") -> void:
	_stop_ai()
	_cancel_animation()
	error_message = "ERROR: %s\nMove: %s | disk: %d | source: %d | destination: %d\nA: %s\nB: %s\nC: %s" % [reason, details.get("move", "?"), details.get("disk", -1), details.get("from", -1), details.get("to", -1), str(pegs[0]), str(pegs[1]), str(pegs[2])]
	status_label.text = "ERROR - AI stopped (Tower State for details)"
	status_label.tooltip_text = error_message
	_show_text("AI ERROR", error_message)


func _format_time(seconds: int) -> String:
	return "%02d:%02d:%02d" % [seconds / 3600, (seconds / 60) % 60, seconds % 60]


func _time_remaining() -> String:
	if clock_real:
		return _scientific(float(Solver.subtract(best_count, simulated_move)) * maxf(ai_step_time, 0.000001)) + " seconds"
	return _format_time(maxi(0, (duration_us - elapsed_us) / 1000000))


func _scientific(value: float) -> String:
	if value == 0:
		return "0"
	var exponent := int(floor(log(value) / log(10.0)))
	return "%.6f e%d" % [value / pow(10.0, exponent), exponent]


func _show_text(title: String, content: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = title
	dialog.min_size = Vector2i(740, 480)
	var text := TextEdit.new()
	text.editable = false
	text.text = content
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.add_child(text)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	ui_layer.add_child(dialog)
	dialog.popup_centered()


func _show_towers() -> void:
	_show_text("Exact Tower State (bottom -> top)", "%s\n\nMove: %s\nTotal: %s\nActual executed: %s\n\nTower A: %s\n\nTower B: %s\n\nTower C: %s" % [error_message, simulated_move if canonical else "Manual board", best_count, move_count, str(pegs[0]), str(pegs[1]), str(pegs[2])])


func _run_verification() -> void:
	if verifying:
		return
	_on_stop()
	verifying = true
	verify_button.disabled = true
	var report := "AI VERIFICATION\n\n"
	for count in range(1, 16):
		_update_ui("Verifying %d disks..." % count)
		var result_box: Array[String] = [""]
		var task_id := WorkerThreadPool.add_task(func(): result_box[0] = Verification.verify_small(count))
		while not WorkerThreadPool.is_task_completed(task_id):
			await get_tree().process_frame
		WorkerThreadPool.wait_for_task_completion(task_id)
		var result := result_box[0]
		report += "%d disks: %s\n" % [count, result]
		if result != "PASS":
			break
	if not report.contains("ERROR"):
		for count in [32, 64, 100]:
			var result := Verification.verify_large(count)
			report += "%d disks: %s\n" % [count, result]
		if not report.contains("ERROR"):
			report += "\nALL TESTS PASSED"
	verifying = false
	verify_button.disabled = false
	_update_ui("ALL TESTS PASSED" if not report.contains("ERROR") else "ERROR: verification mismatch")
	_show_text("AI VERIFICATION", report)


func _disc_position(peg: int, level: int) -> Vector2:
	var size := get_viewport_rect().size
	var base_y := size.y - 86
	var height := minf((base_y - 445 - 18) / max(disc_count, 1), 34)
	return Vector2(_peg_positions(size)[peg], base_y - height * (level + 1))


func _animate_disc(disc: int, source: Vector2, target: Vector2) -> void:
	_cancel_animation()
	animated_disc = disc
	animated_position = source
	var travel_time := minf(ai_step_time, 0.4) / 3.0
	animation = create_tween()
	animation.tween_property(self, "animated_position", Vector2(source.x, 436), travel_time)
	animation.tween_property(self, "animated_position", Vector2(target.x, 436), travel_time)
	animation.tween_property(self, "animated_position", target, travel_time)
	animation.step_finished.connect(func(_step: int): queue_redraw())
	animation.finished.connect(func():
		animated_disc = -1
		queue_redraw())
	set_process(true)


func _cancel_animation() -> void:
	if animation != null:
		animation.kill()
	animation = null
	animated_disc = -1


func _add_decimal(left: String, right: String) -> String:
	var result := ""
	var carry := 0
	for offset in range(maxi(left.length(), right.length())):
		var value := carry
		if offset < left.length():
			value += int(left[left.length() - 1 - offset])
		if offset < right.length():
			value += int(right[right.length() - 1 - offset])
		result = str(value % 10) + result
		carry = value / 10
	if carry > 0:
		result = str(carry) + result
	return result


func _remaining_count() -> String:
	# Distances to each complete tower, built from smallest disc upward.
	var distances: Array[String] = ["0", "0", "0"]
	var power := "1"
	for disc in range(1, disc_count + 1):
		var source := _disc_peg(disc)
		var next: Array[String] = []
		for target in range(3):
			if source == target:
				next.append(distances[target])
			else:
				next.append(_add_decimal(distances[3 - source - target], power))
		distances = next
		power = _add_decimal(power, power)
	return distances[2]


func _on_speed_changed(value: float) -> void:
	ai_step_time = value
	if speed_slider != null:
		speed_slider.set_value_no_signal(minf(value, speed_slider.max_value))
	if speed_input != null:
		speed_input.set_value_no_signal(value)
	_update_speed_label()
	if clock_real and mode == Mode.ULTRA:
		_on_duration_changed(0)


func _optimal_count(count: int) -> String:
	return Solver.total_moves(count)


func _play_next_ai_move() -> void:
	if not error_message.is_empty():
		return
	if canonical:
		if simulated_move == best_count:
			_finish()
			return
		var next := Solver.get_move_at(Solver.add(simulated_move, "1"), disc_count)
		if not is_valid_move(next.disk, next.from, next.to):
			_fail_move(next)
			return
		_move_disc(next.from, next.to)
		if _is_solved():
			_finish()
		queue_redraw()
		return
	if ai_moves.is_empty():
		_stop_ai()
		_update_ui("SOLVED")
		queue_redraw()
		return

	# Expand only the next recursive branch, keeping memory proportional to disc count.
	while not ai_moves.is_empty():
		var task: Vector3i = ai_moves.pop_back()
		if task.x <= 0:
			continue
		if task.y == -1:
			var source := _disc_peg(task.x)
			if source == task.z:
				ai_moves.append(Vector3i(task.x - 1, -1, task.z))
			else:
				var temporary: int = 3 - source - task.z
				ai_moves.append(Vector3i(task.x - 1, temporary, task.z))
				ai_moves.append(Vector3i(1, source, task.z))
				ai_moves.append(Vector3i(task.x - 1, -1, temporary))
			continue
		if task.x == 1:
			var disc: int = pegs[task.y].back() if not pegs[task.y].is_empty() else -1
			if not is_valid_move(disc, task.y, task.z):
				_fail_move({"move": Solver.add(move_count, "1"), "disk": disc, "from": task.y, "to": task.z})
				return
			_move_disc(task.y, task.z)
			break
		var spare: int = 3 - task.y - task.z
		ai_moves.append(Vector3i(task.x - 1, spare, task.z))
		ai_moves.append(Vector3i(1, task.y, task.z))
		ai_moves.append(Vector3i(task.x - 1, task.y, spare))
	if _is_solved():
		ai_moves.clear()
		_stop_ai()
		_update_ui("SOLVED - Shortest continuation verified")
	queue_redraw()


func _stop_ai() -> void:
	ai_running = false
	ai_paused = false
	ai_timer = 0.0
	ai_moves.clear()
	if ai_button != null:
		ai_button.text = "Start AI"


func _pause_ai() -> void:
	if not ai_running:
		return
	ai_running = false
	ai_paused = true
	ai_timer = 0.0
	if animation != null:
		animation.pause()
	_update_ui("Paused.")


func _resume_ai() -> void:
	if not ai_paused or not error_message.is_empty():
		return
	ai_running = true
	ai_paused = false
	ai_timer = ai_step_time
	last_tick_us = Time.get_ticks_usec()
	if animation != null:
		animation.play()
	_update_ui("Running.")


func _update_ui(message: String) -> void:
	if disc_label != null:
		disc_label.text = "Discs: %d" % disc_count
	if status_label != null:
		status_label.text = message
		status_label.tooltip_text = message
	_update_move_label()
	_update_speed_label()


func _update_move_label() -> void:
	if move_label != null:
		var remaining := Solver.subtract(best_count, simulated_move) if canonical else _remaining_count()
		stats_label.text = "DISKS: %d    TOTAL MOVES: %s\nACTUAL EXECUTED MOVES: %s    MATHEMATICALLY SIMULATED MOVES: %s" % [disc_count, Solver.grouped(best_count), Solver.grouped(move_count), Solver.grouped(simulated_move) if mode == Mode.ULTRA else "0"]
		move_label.text = "REMAINING MOVES: %s" % Solver.grouped(remaining)
		if mode == Mode.ULTRA:
			var progress_units := int(Solver.divide(Solver.multiply_small(simulated_move, 100000000000), best_count))
			var progress := "%d.%09d" % [progress_units / 1000000000, progress_units % 1000000000]
			var time_left := _time_remaining()
			var speed := str(int(1.0 / maxf(ai_step_time, 0.000001))) if clock_real else Solver.divide(Solver.multiply_small(best_count, 1000000), str(duration_us))
			sim_label.text = "PROGRESS: %s%%    SIMULATED TIME: %s    TIME REMAINING: %s\nSIMULATED SPEED: %s moves/sec (floor)    Time estimates: rounded" % [progress, _format_time(int(round(elapsed_us / 1000000.0))), time_left, Solver.grouped(speed)]
		else:
			var eta := float(remaining) * maxf(ai_step_time, 1.0 / maxf(Engine.get_frames_per_second(), 1.0))
			sim_label.text = "Estimated completion: %s seconds (rounded)" % _scientific(eta)
		if last_move.is_empty():
			last_label.text = "Destination: Tower C"
		else:
			last_label.text = "MOVE %s: disk %d    %s -> %s" % [last_move.move, last_move.disk, "ABC"[last_move.from], "ABC"[last_move.to]]
		pause_button.disabled = not ai_running
		resume_button.disabled = not ai_paused
		step_button.disabled = ai_running or not error_message.is_empty()


func _update_speed_label() -> void:
	if speed_label != null:
		speed_label.text = "Maximum visual" if ai_step_time == 0 else "%.3fs" % ai_step_time


func _peg_at_position(position: Vector2) -> int:
	var size: Vector2 = get_viewport_rect().size
	if position.y < 435:
		return -1
	var peg_positions: Array[float] = _peg_positions(size)
	var closest := -1
	var closest_distance := 999999.0
	for i in range(3):
		var distance: float = abs(position.x - peg_positions[i])
		if distance < closest_distance:
			closest_distance = distance
			closest = i
	if closest_distance <= max(120.0, size.x / 8.0):
		return closest
	return -1


func _peg_positions(size: Vector2) -> Array[float]:
	return [size.x * 0.22, size.x * 0.5, size.x * 0.78]


func _draw_title_band(size: Vector2) -> void:
	draw_rect(Rect2(0, 0, size.x, 430), Color(0.115, 0.12, 0.125))


func _draw_board(size: Vector2) -> void:
	var peg_positions: Array[float] = _peg_positions(size)
	var base_y: float = size.y - 86
	var peg_top := 445.0
	var base_color := Color(0.5, 0.42, 0.31)
	var peg_color := Color(0.78, 0.69, 0.55)

	draw_rect(Rect2(48, base_y, size.x - 96, 18), base_color)

	for i in range(3):
		var x := peg_positions[i]
		var peg_width := 14.0
		draw_rect(Rect2(x - peg_width * 0.5, peg_top, peg_width, base_y - peg_top), peg_color)
		if i == selected_peg:
			draw_arc(Vector2(x, base_y - 20), 86, 0, TAU, 96, Color(1.0, 0.88, 0.34), 4.0)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(x - 65, base_y + 46),
			"Tower %s (%d)" % ["ABC"[i], pegs[i].size()],
			HORIZONTAL_ALIGNMENT_CENTER,
			130,
			16,
			Color(0.78, 0.84, 0.9)
		)

	var usable_width: float = min(size.x * 0.23, 260.0)
	var min_width: float = max(44.0, usable_width * 0.28)
	var disc_height := minf((base_y - peg_top - 18.0) / max(disc_count, 1), 34.0)
	var palette := [
		Color(0.92, 0.28, 0.25),
		Color(0.98, 0.62, 0.22),
		Color(0.96, 0.86, 0.32),
		Color(0.28, 0.76, 0.45),
		Color(0.22, 0.64, 0.92),
		Color(0.36, 0.42, 0.92),
		Color(0.72, 0.36, 0.92),
		Color(0.95, 0.45, 0.72),
		Color(0.55, 0.84, 0.86),
		Color(0.88, 0.88, 0.92)
	]

	for peg_index in range(3):
		for level in range(pegs[peg_index].size()):
			var disc: int = pegs[peg_index][level]
			if disc == animated_disc:
				continue
			var t: float = 0.0 if disc_count == 1 else float(disc - 1) / float(disc_count - 1)
			var width: float = lerpf(min_width, usable_width, t)
			var x: float = peg_positions[peg_index] - width * 0.5
			var y: float = base_y - disc_height * float(level + 1)
			var rect := Rect2(x, y, width, disc_height - minf(2.0, disc_height * 0.15))
			draw_rect(rect, palette[(disc - 1) % palette.size()])
			draw_rect(rect, Color(0.07, 0.08, 0.1), false, minf(2.0, disc_height * 0.15))
			if disc_height >= 18.0:
				draw_string(
					ThemeDB.fallback_font,
					Vector2(rect.position.x, rect.position.y + disc_height * 0.68),
					str(disc),
					HORIZONTAL_ALIGNMENT_CENTER,
					rect.size.x,
					15,
					Color(0.05, 0.06, 0.08)
				)
	if animated_disc > 0:
		var t: float = 0.0 if disc_count == 1 else float(animated_disc - 1) / float(disc_count - 1)
		var width := lerpf(min_width, usable_width, t)
		draw_rect(Rect2(animated_position.x - width * 0.5, animated_position.y, width, disc_height - 1), palette[(animated_disc - 1) % palette.size()])
