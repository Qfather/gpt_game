@tool
extends VBoxContainer

const PoolResource = preload("res://Script/unit/name_pool.gd")

var pool: Resource
var pool_path: String
var pool_name: LineEdit
var fields: Dictionary = {}
var rows: Dictionary = {}
var status: Label
var preview: Label
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()
	var save_button := Button.new()
	save_button.text = "保存名称池"
	save_button.pressed.connect(func() -> void: save_pool())
	add_child(save_button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)
	var note := Label.new()
	note.text = "每行一项。保存后统一用于该类别新生成的角色，已有角色保留原名。\n人类名字为空时随机抽两个备用字；备用字也为空时使用内置字池。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(note)
	pool_name = LineEdit.new()
	pool_name.placeholder_text = "名称池显示名称"
	form.add_child(pool_name)
	for key: String in ["surnames", "given_names", "characters", "full_names"]:
		var row := VBoxContainer.new()
		form.add_child(row)
		rows[key] = row
		var heading := Label.new()
		heading.text = {"surnames": "姓氏池（支持复姓，空时使用默认姓氏）", "given_names": "名字池（填写完整的名，例如青禾、长风）", "characters": "备用字池（每行一个字）", "full_names": "完整名称池（空时使用内置名称）"}[key]
		row.add_child(heading)
		var input := TextEdit.new()
		input.custom_minimum_size.y = 90
		row.add_child(input)
		fields[key] = input
	var random_button := Button.new()
	random_button.text = "随机预览十个名字（无需保存）"
	random_button.pressed.connect(generate_preview)
	form.add_child(random_button)
	preview = Label.new()
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(preview)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)

func edit_pool(path: String) -> void:
	pool_path = path
	pool = load(path).duplicate(true)
	pool_name.text = pool.display_name
	for key: String in fields:
		fields[key].text = "\n".join(pool.get(key))
		rows[key].visible = (key == "full_names") == (pool.mode == PoolResource.Mode.FULL_NAME)
	preview.text = ""
	status.text = pool_path

func _read_fields() -> bool:
	pool.display_name = pool_name.text.strip_edges()
	for key: String in fields: pool.set(key, PoolResource.clean_entries(fields[key].text.split("\n")))
	for letter: String in pool.characters:
		if letter.length() != 1:
			status.text = "备用字池每行只能填写一个字：" + letter
			return false
	return true

func generate_preview() -> void:
	if pool == null or not _read_fields(): return
	var used: Dictionary = {}
	var results := PackedStringArray()
	for i in range(10):
		var generated: String = pool.generate(rng, used)
		used[generated] = true
		results.append(generated)
	preview.text = "、".join(results)

func save_pool() -> bool:
	if pool == null or not _read_fields(): return false
	if ResourceSaver.save(pool, pool_path) != OK:
		status.text = "保存名称池失败：" + pool_path
		return false
	ResourceLoader.load(pool_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if Engine.is_editor_hint(): EditorInterface.get_resource_filesystem().update_file(pool_path)
	status.text = "已保存名称池：" + pool_path
	return true
