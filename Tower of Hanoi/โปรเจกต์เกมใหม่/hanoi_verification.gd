extends RefCounted

const Solver = preload("res://hanoi_solver.gd")


static func _reference(count: int, source: int, target: int, spare: int, moves: Array[Vector3i]) -> void:
	if count == 0:
		return
	_reference(count - 1, source, spare, target, moves)
	moves.append(Vector3i(count, source, target))
	_reference(count - 1, spare, target, source, moves)


static func verify_small(count: int) -> String:
	var reference: Array[Vector3i] = []
	_reference(count, 0, 2, 1, reference)
	if str(reference.size()) != Solver.total_moves(count):
		return "ERROR: total count mismatch"
	var towers: Array[Array] = [[], [], []]
	for disk in range(count, 0, -1):
		towers[0].append(disk)
	for i in range(reference.size()):
		var move := Solver.get_move_at(str(i + 1), count)
		var expected: Vector3i = reference[i]
		if move.disk != expected.x or move.from != expected.y or move.to != expected.z:
			return "ERROR: move %d mismatch: %s != %s" % [i + 1, str(move), str(expected)]
		if not Solver.valid_move(towers, move.disk, move.from, move.to):
			return "ERROR: illegal move %d: %s, state %s" % [i + 1, str(move), str(towers)]
		towers[move.from].pop_back()
		towers[move.to].append(move.disk)
		if towers != Solver.state_at(str(i + 1), count):
			return "ERROR: direct state mismatch at move %d" % (i + 1)
	if towers[2].size() != count or not Solver.validate_state(towers, count):
		return "ERROR: final state mismatch"
	return "PASS"


static func verify_large(count: int) -> String:
	var totals := {32: "4294967295", 64: "18446744073709551615", 100: "1267650600228229401496703205375"}
	var total := Solver.total_moves(count)
	if total != totals[count]:
		return "ERROR: total mismatch"
	var midpoint: String = Solver.divide_small(Solver.add(total, "1"), 2).quotient
	var samples: Array[String] = ["1", "2", "3", "4", "5", midpoint,
		Solver.subtract(midpoint, "1"), Solver.add(midpoint, "1"),
		Solver.subtract(total, "1"), total]
	if count == 100:
		samples.append("633825300114114700748351602687")
	for index in samples:
		var previous := Solver.state_at(Solver.subtract(index, "1"), count)
		var move := Solver.get_move_at(index, count)
		if not Solver.validate_state(previous, count) or not Solver.valid_move(previous, move.disk, move.from, move.to):
			return "ERROR: move %s invalid: %s, state %s" % [index, str(move), str(previous)]
		previous[move.from].pop_back()
		previous[move.to].append(move.disk)
		if previous != Solver.state_at(index, count):
			return "ERROR: state mismatch at %s" % index
	# Independent structural checks at the largest disk's only move.
	var before := Solver.state_at(Solver.subtract(midpoint, "1"), count)
	var after := Solver.state_at(midpoint, count)
	if before[0] != [count] or before[1].size() != count - 1 or not before[2].is_empty():
		return "ERROR: midpoint structure before largest disk"
	if after[2] != [count] or after[1].size() != count - 1 or not after[0].is_empty():
		return "ERROR: midpoint structure after largest disk"
	var final := Solver.state_at(total, count)
	if final[2].size() != count or not Solver.validate_state(final, count):
		return "ERROR: final state"
	if Solver.index_for_time(total, 43200000000, 86400000000) != Solver.divide_small(total, 2).quotient:
		return "ERROR: exact half-day index"
	if Solver.index_for_time(total, 86400000000, 86400000000) != total:
		return "ERROR: exact one-day final index"
	return "PASS"
