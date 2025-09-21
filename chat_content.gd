extends TextEdit

func _ready() -> void:
	OllamaClient.ollama_result.connect(_got_answer)
	
func _got_answer(text: String) -> void:
	self.text += text + "\n"
	_on_scroll_to_bottom()

func _on_scroll_to_bottom() -> void:
	if self.get_line_count() > 0:
		var last_line := self.get_line_count() - 1          # 0-based
		self.set_caret_line(last_line)                      # 커서도 마지막 줄로
		self.scroll_vertical = INF
