@tool
extends Resource

enum Mode { SURNAME, FULL_NAME }

const DEFAULT_SURNAMES = ["赵", "钱", "孙", "李", "周", "吴", "郑", "王", "陈", "林", "沈", "叶", "陆", "欧阳", "司马"]
const DEFAULT_CHARACTERS = "青禾长风云山林溪明月星河石川安宁知秋远白松雨晨阳雪竹清言平生"
const DEFAULT_ENEMY_NAMES = ["碎牙", "赤角", "灰爪", "枯灯", "裂骨", "黑鳞", "残火", "石颅"]

@export var display_name: String = "名称池"
@export var mode: Mode = Mode.SURNAME
@export var surnames: PackedStringArray = []
@export var given_names: PackedStringArray = []
@export var characters: PackedStringArray = []
@export var full_names: PackedStringArray = []

func generate(rng: RandomNumberGenerator, used: Dictionary = {}) -> String:
	if mode == Mode.FULL_NAME:
		var names := clean_entries(full_names)
		if names.is_empty(): names = PackedStringArray(DEFAULT_ENEMY_NAMES)
		var available := PackedStringArray()
		for entry: String in names:
			if not used.has(entry): available.append(entry)
		if not available.is_empty(): names = available
		return names[rng.randi_range(0, names.size() - 1)]
	var family := clean_entries(surnames)
	if family.is_empty(): family = PackedStringArray(DEFAULT_SURNAMES)
	var given := clean_entries(given_names)
	var letters := clean_entries(characters)
	if letters.is_empty():
		for index: int in range(DEFAULT_CHARACTERS.length()): letters.append(DEFAULT_CHARACTERS[index])
	var result: String = ""
	for attempt: int in range(64):
		var first: String = family[rng.randi_range(0, family.size() - 1)]
		var last: String = given[rng.randi_range(0, given.size() - 1)] if not given.is_empty() else letters[rng.randi_range(0, letters.size() - 1)] + letters[rng.randi_range(0, letters.size() - 1)]
		result = first + last
		if not used.has(result): return result
	return result

static func clean_entries(values: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	for value: String in values:
		var entry: String = value.strip_edges()
		if not entry.is_empty() and not result.has(entry): result.append(entry)
	return result
