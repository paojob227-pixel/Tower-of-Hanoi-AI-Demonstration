extends SceneTree


func _initialize() -> void:
	var game = load("res://hanoi_game.gd").new()
	root.add_child.call_deferred(game)
	call_deferred("_verify", game)


func _verify(game: Node) -> void:
	game.set_process(false)
	game.animations_enabled = false
	var verified := 0
	for count in range(1, 6):
		var powers: Array[int] = [1]
		for i in range(count):
			powers.append(powers.back() * 3)
		var distances: Array[int] = []
		distances.resize(powers[count])
		distances.fill(-1)
		var goal: int = powers[count] - 1
		distances[goal] = 0
		var queue: Array[int] = [goal]
		var cursor := 0
		# Independent breadth-first search gives the exact distance for every legal board.
		while cursor < queue.size():
			var state: int = queue[cursor]
			cursor += 1
			var tops: Array[int] = [-1, -1, -1]
			for disc in range(count):
				var peg: int = int(state / powers[disc]) % 3
				if tops[peg] == -1:
					tops[peg] = disc
			for source in range(3):
				if tops[source] == -1:
					continue
				for target in range(3):
					if source == target or (tops[target] != -1 and tops[target] < tops[source]):
						continue
					var neighbor: int = state + (target - source) * powers[tops[source]]
					if distances[neighbor] == -1:
						distances[neighbor] = distances[state] + 1
						queue.append(neighbor)
		for state in range(powers[count]):
			game._reset_game(count)
			for peg in game.pegs:
				peg.clear()
			for disc in range(count, 0, -1):
				var peg: int = int(state / powers[disc - 1]) % 3
				game.pegs[peg].append(disc)
			game.move_count = "7"
			game.canonical = false
			assert(game._remaining_count() == str(distances[state]))
			game._on_ai_button_pressed()
			assert(game.move_count == "7")
			var steps := 0
			while game.ai_running:
				var previous: int = int(game.move_count)
				game._play_next_ai_move()
				assert(game.move_count == str(previous + 1))
				steps += 1
				assert(steps <= distances[state])
				assert(game._remaining_count() == str(distances[state] - steps))
			assert(game._is_solved())
			assert(steps == distances[state])
			verified += 1
	game._reset_game(100)
	assert(game._remaining_count() == "1267650600228229401496703205375")
	game._on_ai_button_pressed()
	for step in range(2000):
		game._play_next_ai_move()
		assert(game.move_count == str(step + 1))
		assert(game.ai_moves.size() <= 201)
	game._on_ai_button_pressed()
	assert(game.ai_paused and not game.ai_running)
	game._on_ai_button_pressed()
	assert(game.ai_running)
	print("PASS: %d boards match BFS shortest paths; 100 discs, 2000 moves, pause/resume" % verified)
	quit()
