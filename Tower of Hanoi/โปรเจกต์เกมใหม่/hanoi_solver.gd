extends RefCounted


# All move indices and counts are decimal strings; floats are display-only.
static func normalize(value: String) -> String:
	if value.is_empty():
		return ""
	for character in value:
		if character < "0" or character > "9":
			return ""
	var start := 0
	while start < value.length() - 1 and value[start] == "0":
		start += 1
	return value.substr(start)


static func compare(a: String, b: String) -> int:
	if a.length() != b.length():
		return -1 if a.length() < b.length() else 1
	return 0 if a == b else (-1 if a < b else 1)


static func add(a: String, b: String) -> String:
	var result := ""
	var carry := 0
	for offset in range(maxi(a.length(), b.length())):
		var value := carry
		if offset < a.length():
			value += int(a[a.length() - offset - 1])
		if offset < b.length():
			value += int(b[b.length() - offset - 1])
		result = str(value % 10) + result
		carry = value / 10
	return str(carry) + result if carry > 0 else result


static func subtract(a: String, b: String) -> String:
	assert(compare(a, b) >= 0)
	var result := ""
	var borrow := 0
	for offset in range(a.length()):
		var value := int(a[a.length() - offset - 1]) - borrow
		if offset < b.length():
			value -= int(b[b.length() - offset - 1])
		borrow = 1 if value < 0 else 0
		result = str(posmod(value, 10)) + result
	return normalize(result)


static func multiply_small(a: String, multiplier: int) -> String:
	assert(multiplier >= 0 and multiplier <= 86400000000000)
	var carry := 0
	var result := ""
	for i in range(a.length() - 1, -1, -1):
		var value := int(a[i]) * multiplier + carry
		result = str(value % 10) + result
		carry = value / 10
	if carry > 0:
		result = str(carry) + result
	return normalize(result)


static func divide_small(a: String, divisor: int) -> Dictionary:
	assert(divisor > 0 and divisor <= 86400000000000)
	var remainder := 0
	var result := ""
	for character in a:
		var value := remainder * 10 + int(character)
		result += str(value / divisor)
		remainder = value % divisor
	return {"quotient": normalize(result), "remainder": remainder}


static func total_moves(count: int) -> String:
	var power := "1"
	for i in range(count):
		power = multiply_small(power, 2)
	return subtract(power, "1")


static func divide(a: String, b: String) -> String:
	assert(b != "0")
	var remainder := "0"
	var result := ""
	for digit in a:
		remainder = normalize(remainder + digit)
		var quotient_digit := 0
		while compare(remainder, b) >= 0:
			remainder = subtract(remainder, b)
			quotient_digit += 1
		result += str(quotient_digit)
	return normalize(result)


static func bits_at(index: String, count: int) -> PackedByteArray:
	var bits := PackedByteArray()
	var value := index
	for i in range(count):
		var divided := divide_small(value, 2)
		bits.append(divided.remainder)
		value = divided.quotient
	return bits


static func valid_index(index: String, count: int, allow_zero: bool = true) -> bool:
	return count >= 1 and count <= 100 and normalize(index) != "" \
		and (allow_zero or normalize(index) != "0") \
		and compare(normalize(index), total_moves(count)) <= 0


static func get_hanoi_move(index: String, count: int) -> Dictionary:
	if not valid_index(index, count, false):
		return {"error": "Move index must be in 1..total_moves"}
	index = normalize(index)
	var bits := bits_at(index, count)
	var disk := 1
	while bits[disk - 1] == 0:
		disk += 1
	# floor(k / 2^disk) is the number of previous moves of this disk.
	var previous_mod := 0
	for i in range(count - 1, disk - 1, -1):
		previous_mod = (previous_mod * 2 + bits[i]) % 3
	var direction := -1 if (count - disk) % 2 == 0 else 1
	return {"move": index, "disk": disk,
		"from": posmod(direction * previous_mod, 3),
		"to": posmod(direction * (previous_mod + 1), 3), "total": total_moves(count)}


static func get_move_at(index: String, count: int) -> Dictionary:
	return get_hanoi_move(index, count)


static func state_at(index: String, count: int) -> Array[Array]:
	var towers: Array[Array] = [[], [], []]
	if not valid_index(index, count):
		return towers
	var bits := bits_at(normalize(index), count)
	var quotient_mod := 0
	# The disk has moved floor(k / 2^disk) + bit(disk-1) times.
	for disk in range(count, 0, -1):
		var moves_mod: int = (quotient_mod + bits[disk - 1]) % 3
		var direction := -1 if (count - disk) % 2 == 0 else 1
		towers[posmod(direction * moves_mod, 3)].append(disk)
		quotient_mod = (quotient_mod * 2 + bits[disk - 1]) % 3
	return towers


static func validate_state(towers: Array, count: int) -> bool:
	if towers.size() != 3:
		return false
	var seen := PackedByteArray()
	seen.resize(count + 1)
	var found := 0
	for tower in towers:
		var previous := count + 1
		for disk in tower:
			if disk < 1 or disk > count or disk >= previous or seen[disk] == 1:
				return false
			previous = disk
			seen[disk] = 1
			found += 1
	return found == count


static func valid_move(towers: Array, disk: int, source: int, target: int) -> bool:
	if source < 0 or source > 2 or target < 0 or target > 2 or source == target:
		return false
	return not towers[source].is_empty() and towers[source].back() == disk \
		and (towers[target].is_empty() or towers[target].back() > disk)


static func index_for_time(total: String, elapsed_us: int, duration_us: int) -> String:
	return divide_small(multiply_small(total, clampi(elapsed_us, 0, duration_us)), duration_us).quotient


static func grouped(value: String) -> String:
	var result := ""
	for i in range(value.length()):
		if i > 0 and (value.length() - i) % 3 == 0:
			result += ","
		result += value[i]
	return result
