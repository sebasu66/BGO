extends RefCounted

const LOG_LEVELS := ["debug", "info", "warning", "error"]
const LOG_LEVEL_PRIORITY := {"debug": 10, "info": 20, "warning": 30, "error": 40}
const MAX_LOG_ENTRIES := 1000

var _output: RichTextLabel
var _level_select: OptionButton
var _search: LineEdit
var _entries: Array[Dictionary] = []
var _minimum_level := "debug"


func configure(
	panel: VBoxContainer,
	output: RichTextLabel,
	level_select: OptionButton,
	search: LineEdit,
	clear_button: Button,
) -> void:
	_output = output
	_level_select = level_select
	_search = search
	var toolbar := HBoxContainer.new()
	toolbar.name = "LogToolbar"
	toolbar.add_theme_constant_override("separation", 8)
	panel.add_child(toolbar)
	for level in LOG_LEVELS:
		level_select.add_item(level.to_upper())
	level_select.item_selected.connect(_on_level_selected)
	toolbar.add_child(level_select)
	search.placeholder_text = "Search logs"
	search.clear_button_enabled = true
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(_on_search_changed)
	toolbar.add_child(search)
	clear_button.text = "Clear"
	clear_button.pressed.connect(clear)
	toolbar.add_child(clear_button)
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(output)


func append(text: Variant, level: String, print_godot: bool) -> void:
	var rendered := str(text)
	_entries.append({"level": level, "text": rendered})
	while _entries.size() > MAX_LOG_ENTRIES:
		_entries.pop_front()
	if _is_visible(_entries[-1]):
		_output.append_text(rendered)
		_output.append_text("\n")
	if print_godot:
		print_rich(rendered.dedent())


func set_level(level: String) -> bool:
	var normalized := level.to_lower()
	if normalized not in LOG_LEVELS:
		return false
	_minimum_level = normalized
	var index := LOG_LEVELS.find(normalized)
	if _level_select.selected != index:
		_level_select.select(index)
	_render()
	return true


func get_level() -> String:
	return _minimum_level


func set_search(query: String) -> void:
	_search.text = query
	_render()


func clear() -> void:
	_entries.clear()
	_output.clear()


func _render() -> void:
	_output.clear()
	for entry in _entries:
		if _is_visible(entry):
			_output.append_text(str(entry.get("text", "")))
			_output.append_text("\n")


func _is_visible(entry: Dictionary) -> bool:
	var level := str(entry.get("level", "debug"))
	if int(LOG_LEVEL_PRIORITY.get(level, 10)) < int(LOG_LEVEL_PRIORITY[_minimum_level]):
		return false
	var query := _search.text.strip_edges().to_lower()
	return query.is_empty() or query in str(entry.get("text", "")).to_lower()


func _on_level_selected(index: int) -> void:
	set_level(_level_select.get_item_text(index))


func _on_search_changed(_query: String) -> void:
	_render()
